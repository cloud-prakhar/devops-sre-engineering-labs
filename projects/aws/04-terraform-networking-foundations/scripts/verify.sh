#!/usr/bin/env bash
# Verifies AWS 04 after 'terraform apply' of both stacks: remote state hardening, multi-AZ layout,
# routing per NAT mode, tiered security groups, and real packet paths through the test hosts.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform aws ssh jq

BOOT="$HERE/../terraform/bootstrap"
NET="$HERE/../terraform/network"
BUCKET=$(tf_output "$BOOT" bucket)
REGION=$(tf_output "$BOOT" region)
export AWS_REGION=$REGION
net_json=$(terraform -chdir="$NET" output -json)
out() { jq -r ".$1.value" <<<"$net_json"; }
VPC=$(out vpc_id)
NAT_MODE=$(out nat_mode)

info "Remote state (s3://$BUCKET)"
[[ $(aws s3api get-bucket-versioning --bucket "$BUCKET" --query Status --output text) == Enabled ]] \
  && pass "versioning enabled" || fail "versioning not enabled"
pab=$(aws s3api get-public-access-block --bucket "$BUCKET" --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' --output text)
[[ "$pab" == $'True\tTrue\tTrue\tTrue' ]] && pass "all public access blocked" || fail "public access block: $pab"
enc=$(aws s3api get-bucket-encryption --bucket "$BUCKET" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text)
[[ "$enc" == AES256 || "$enc" == aws:kms ]] && pass "default encryption: $enc" || fail "encryption: $enc"
aws s3api head-object --bucket "$BUCKET" --key aws-04/network/terraform.tfstate >/dev/null 2>&1 \
  && pass "network state stored remotely" || fail "state object missing (did you run shared/scripts/tf-init-backend.sh?)"
grep -q 'use_lockfile *= *true' "$NET/backend.hcl" && pass "S3 native locking enabled" || fail "use_lockfile not set"
if aws s3api list-objects-v2 --bucket "$BUCKET" --prefix aws-04/ --query 'Contents[].Key' --output text | grep -q '\.tflock'; then
  warn "a .tflock object exists: another apply is running, or a crashed run left a lock (see troubleshooting #2)"
else
  pass "no stale lock"
fi
if http_code=$(curl -s -o /dev/null -w '%{http_code}' "http://$BUCKET.s3.$REGION.amazonaws.com/aws-04/network/terraform.tfstate"); [[ "$http_code" == 403 ]]; then
  pass "anonymous HTTP read of state refused (403)"
else
  fail "anonymous read returned $http_code"
fi

info "Layout"
azs=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query 'Subnets[].AvailabilityZone' --output text | tr '\t' '\n' | sort -u | wc -l)
(( azs >= 2 )) && pass "subnets span $azs AZs" || fail "subnets in only $azs AZ"
for tier in public private; do
  n=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" "Name=tag:Tier,Values=$tier" --query 'length(Subnets)' --output text)
  (( n >= 2 )) && pass "$n $tier subnets" || fail "only $n $tier subnets"
done
pubip=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query 'Subnets[?MapPublicIpOnLaunch].SubnetId' --output text)
[[ -z "$pubip" ]] && pass "no subnet auto-assigns public IPs" || fail "auto-assign public IP on: $pubip"

info "Routing (nat_mode = $NAT_MODE)"
for rt in $(jq -r '.private_route_table_ids.value[]' <<<"$net_json"); do
  target=$(aws ec2 describe-route-tables --route-table-ids "$rt" --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'] | [0].[NatGatewayId || NetworkInterfaceId || GatewayId]" --output text)
  case "$NAT_MODE" in
    none)     [[ "$target" == None || -z "$target" ]] && pass "$rt: no default route" || fail "$rt: unexpected default route $target" ;;
    gateway)  [[ "$target" == nat-* ]] && pass "$rt: default route via $target" || fail "$rt: default route is $target" ;;
    instance) [[ "$target" == eni-* ]] && pass "$rt: default route via NAT instance $target" || fail "$rt: default route is $target" ;;
  esac
  s3=$(aws ec2 describe-route-tables --route-table-ids "$rt" --query "RouteTables[0].Routes[?starts_with(DestinationPrefixListId || '', 'pl-')] | length(@)" --output text)
  (( s3 >= 1 )) && pass "$rt: S3 gateway endpoint route" || fail "$rt: no S3 endpoint route"
done

info "Security group chain"
sg=$(jq -r '.security_groups.value' <<<"$net_json")
web=$(jq -r .web <<<"$sg"); app=$(jq -r .app <<<"$sg"); db=$(jq -r .db <<<"$sg")
src() { aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$1" --query "SecurityGroupRules[?!IsEgress].[ReferencedGroupInfo.GroupId || CidrIpv4]" --output text | sort -u | tr '\n' ' '; }
[[ $(src "$app") == "$web " ]] && pass "app tier accepts only the web SG" || fail "app tier sources: $(src "$app")"
[[ $(src "$db") == "$app " ]] && pass "db tier accepts only the app SG" || fail "db tier sources: $(src "$db")"

info "Drift"
set +e
terraform -chdir="$NET" plan -detailed-exitcode -input=false -lock=false >/dev/null 2>&1
rc=$?
set -e
case $rc in 0) pass "no drift between code and AWS" ;; 2) warn "plan shows changes (drift or unapplied edits)" ;; *) fail "terraform plan failed" ;; esac

BASTION=$(out bastion_public_ip)
if [[ "$BASTION" == null ]]; then
  warn "enable_test_hosts = false: skipping packet-path tests"
  finish; exit
fi
PRIV=$(out private_host_ip)
info "Packet paths (laptop -> bastion -> private host in another AZ)"
wait_for_ssh "ubuntu@$BASTION"
hop() { ssh "${LAB_SSH_OPTS[@]}" -o "ProxyJump=ubuntu@$BASTION" "ubuntu@$PRIV" "$@"; }
until hop 'cloud-init status --wait >/dev/null' 2>/dev/null; do sleep 5; done
pass "SSH via bastion to private host $PRIV (SG reference allows it)"
code=$(hop "curl -s -o /dev/null -m 8 -w '%{http_code}' https://s3.$REGION.amazonaws.com/" || true)
[[ "$code" =~ ^[2-4][0-9][0-9]$ ]] && pass "private host reaches S3 via gateway endpoint (HTTP $code)" || fail "S3 unreachable from private host ($code)"
egress=$(hop "curl -s -m 8 https://checkip.amazonaws.com" || true)
case "$NAT_MODE" in
  none) [[ -z "$egress" ]] && pass "no internet from private subnet (expected with nat_mode=none)" || fail "private host reached the internet as $egress" ;;
  *)    [[ "$egress" == "$(out nat_public_ip)" ]] && pass "private host egresses via NAT as $egress" || fail "egress IP '$egress', expected $(out nat_public_ip)" ;;
esac
pubip=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=$PRIV" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
[[ "$pubip" == None ]] && pass "private host has no public IP" || fail "private host has public IP $pubip"

finish
