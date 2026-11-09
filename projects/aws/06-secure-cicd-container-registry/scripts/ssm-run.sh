#!/usr/bin/env bash
# Runs one shell command on an instance through SSM Run Command, waits for it, prints its output and
# exits with its status. Used by the pipeline's deploy job and usable from a laptop.
# Usage: ssm-run.sh <instance-id> <command> [timeout-seconds]
set -euo pipefail
INSTANCE=${1:?usage: ssm-run.sh <instance-id> <command> [timeout-seconds]}
CMD=${2:?missing command}
TIMEOUT=${3:-600}

params=$(jq -cn --arg c "$CMD" '{commands: [$c]}')   # JSON-encode: no shell or JSON injection
id=$(aws ssm send-command --instance-ids "$INSTANCE" --document-name AWS-RunShellScript \
  --comment "devops-sre-engineering-labs aws-06" --parameters "$params" \
  --timeout-seconds "$TIMEOUT" --query Command.CommandId --output text)
echo "ssm command $id on $INSTANCE: $CMD"

status=Pending
for _ in $(seq 1 $((TIMEOUT / 5))); do
  sleep 5
  status=$(aws ssm get-command-invocation --command-id "$id" --instance-id "$INSTANCE" \
    --query Status --output text 2>/dev/null || echo Pending)
  case "$status" in Pending|InProgress|Delayed) continue ;; *) break ;; esac
done

aws ssm get-command-invocation --command-id "$id" --instance-id "$INSTANCE" \
  --query '[StandardOutputContent, StandardErrorContent]' --output text
echo "status: $status"
[[ "$status" == Success ]]
