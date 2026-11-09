#!/usr/bin/env bash
# Opt-in failure drills for AWS 05. They act only on this lab's Auto Scaling group and database.
# Run scripts/probe.sh in a second terminal to measure availability while a drill runs.
#
#   scripts/failure-drill.sh list | terminate | stop-app | cpu | db-reboot | refresh
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform aws

TF="$HERE/../terraform"
ASG=$(tf_output "$TF" asg_name)
DB=$(tf_output "$TF" db_identifier)
first_instance() {
  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId | [0]' --output text
}
ssm_run() { # ssm_run <instance-ids> <shell command>
  aws ssm send-command --document-name AWS-RunShellScript --instance-ids $1 \
    --parameters "commands=[\"$2\"]" --query Command.CommandId --output text
}

case "${1:-list}" in
  list)
    cat <<'LIST'
terminate  Terminate one instance (AZ/instance failure). Expect: no or a few failed requests, ASG launches a replacement.
stop-app   Stop the app on one instance via SSM. Expect: target unhealthy in ~20 s, ASG replaces it (ELB health check).
cpu        Burn CPU on every instance for 8 minutes. Expect: CPU target tracking scales out.
db-reboot  Reboot the RDS instance. Expect: /readyz 503 everywhere; ALB fails open; recovery in 1-3 minutes.
refresh    Start an instance refresh (rolling replacement). Expect: zero failed requests.
LIST
    ;;
  terminate)
    id=$(first_instance)
    aws autoscaling terminate-instance-in-auto-scaling-group --instance-id "$id" --no-should-decrement-desired-capacity >/dev/null
    pass "terminating $id; watch: aws autoscaling describe-scaling-activities --auto-scaling-group-name $ASG --max-items 3"
    ;;
  stop-app)
    id=$(first_instance)
    ssm_run "$id" "systemctl stop taskboard" >/dev/null
    pass "stopped taskboard on $id; watch: aws elbv2 describe-target-health --target-group-arn $(tf_output "$TF" target_group_arn)"
    ;;
  cpu)
    ids=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" --query 'AutoScalingGroups[0].Instances[].InstanceId' --output text)
    # systemd-run: the burners outlive the SSM command (plain "&" children are killed with it).
    ssm_run "$ids" "for i in 1 2; do systemd-run --collect timeout 480 sh -c 'while :; do :; done'; done" >/dev/null
    pass "CPU load started on: $ids (stops by itself after 8 minutes)"
    ;;
  db-reboot)
    aws rds reboot-db-instance --db-instance-identifier "$DB" >/dev/null
    pass "rebooting $DB"
    ;;
  refresh)
    aws autoscaling start-instance-refresh --auto-scaling-group-name "$ASG" \
      --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":120}' --query InstanceRefreshId --output text
    pass "instance refresh started; watch: aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG"
    ;;
  *) die "unknown drill: $1 (try: list)" ;;
esac
