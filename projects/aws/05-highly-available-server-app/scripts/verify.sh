#!/usr/bin/env bash
# Verifies AWS 05 after apply: healthy targets in two AZs, load spread across instances, shared
# state in RDS, nothing but the ALB reachable, and the DB password absent from Terraform state.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform aws curl jq

TF="$HERE/../terraform"
ALB=$(tf_output "$TF" alb_dns_name)
TG=$(tf_output "$TF" target_group_arn)
ASG=$(tf_output "$TF" asg_name)
DB=$(tf_output "$TF" db_identifier)
export AWS_REGION=${AWS_REGION:-$(terraform -chdir="$TF" console <<<'var.aws_region' | tr -d '"')}

info "Waiting for healthy targets (first boot takes 3-5 minutes)"
for _ in $(seq 1 60); do
  healthy=$(aws elbv2 describe-target-health --target-group-arn "$TG" --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" --output text)
  (( healthy >= 2 )) && break
  sleep 10
done
(( healthy >= 2 )) && pass "$healthy healthy targets" || fail "only $healthy healthy target(s)"

info "High availability layout"
azs=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
  --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].AvailabilityZone' --output text | tr '\t' '\n' | sort -u | wc -l)
(( azs >= 2 )) && pass "in-service instances span $azs AZs" || fail "instances in only $azs AZ"
hc=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" --query 'AutoScalingGroups[0].HealthCheckType' --output text)
[[ "$hc" == ELB ]] && pass "ASG replaces instances that fail load balancer health checks" || fail "health check type: $hc"

info "Traffic through the load balancer"
declare -A seen=()
for _ in $(seq 1 20); do
  h=$(curl -fsS -m 5 "http://$ALB/api/info" | jq -r .hostname) && seen[$h]=1
done
(( ${#seen[@]} >= 2 )) && pass "requests served by ${#seen[@]} different instances" || fail "only ${#seen[@]} instance answered"
[[ $(curl -fsS -m 5 "http://$ALB/readyz" | jq -r .backend) == postgresql ]] && pass "readiness checks RDS" || fail "readyz"
title="verify-$(date +%s)"
curl -fsS -m 5 -X POST "http://$ALB/api/tasks" -H 'content-type: application/json' -d "{\"title\":\"$title\"}" >/dev/null
found=0
for _ in $(seq 1 6); do curl -fsS -m 5 "http://$ALB/api/tasks" | grep -q "$title" && found=$((found + 1)); done
(( found == 6 )) && pass "every instance sees the same data (state lives in RDS, not on instances)" || fail "task visible in $found/6 reads"

info "Exposure"
ips=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" --query 'AutoScalingGroups[0].Instances[].InstanceId' --output text \
  | xargs aws ec2 describe-instances --query 'Reservations[].Instances[].PublicIpAddress' --output text --instance-ids)
for ip in $ips; do
  if curl -s -m 5 "http://$ip:8000/healthz" >/dev/null; then fail "instance $ip:8000 reachable directly"; else pass "instance $ip:8000 not reachable (only via ALB)"; fi
done
pub=$(aws rds describe-db-instances --db-instance-identifier "$DB" --query 'DBInstances[0].[PubliclyAccessible,StorageEncrypted,MultiAZ]' --output text)
[[ "$pub" == $'False\tTrue\tFalse' ]] && pass "RDS private, encrypted, single-AZ (free-tier shape)" || fail "RDS settings: $pub"

info "Secrets"
if terraform -chdir="$TF" show -json | jq -e '[.. | objects | select(has("password")) | .password] | map(select(. != null and . != "")) | length == 0' >/dev/null; then
  pass "no database password stored in Terraform state (write-only arguments)"
else
  fail "a password value is present in Terraform state"
fi

finish
