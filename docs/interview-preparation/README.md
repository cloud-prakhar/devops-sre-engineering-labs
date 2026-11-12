# Interview question index

Every question in the repository, indexed four ways. Each answer has an interview-length version,
technical depth, a Mermaid diagram with a walkthrough, tradeoffs and follow-up questions.

How to practise: answer aloud before reading; time yourself (2–3 minutes); then answer every follow-up.
Being able to **draw the diagram from memory** is the best sign you understand the answer.

## By technology

| Technology | Question | Level | Lab |
|---|---|---|---|
| Linux / SSH | [What happens when you run `ssh ubuntu@server`?](../../projects/aws/01-linux-server-engineering/docs/interview.md#q1-beginner--what-happens-when-you-run-ssh-ubuntuserver) | Beginner | AWS 01 |
| Linux / performance | [A Linux server "is slow". How do you troubleshoot it?](../../projects/aws/01-linux-server-engineering/docs/interview.md#q2-intermediate--a-linux-server-is-slow-how-do-you-troubleshoot-it) | Intermediate | AWS 01 |
| Linux / systemd | [How does systemd keep a service running, and how would you harden one?](../../projects/aws/01-linux-server-engineering/docs/interview.md#q3-intermediate--how-does-systemd-keep-a-service-running-and-how-would-you-harden-one) | Intermediate | AWS 01 |
| Networking / security | [Security group vs host firewall: why both?](../../projects/aws/01-linux-server-engineering/docs/interview.md#q4-advanced--security-group-vs-host-firewall-why-both) | Advanced | AWS 01 |
| Linux / storage | [`df` says 100% but `du` says 40%](../../projects/aws/01-linux-server-engineering/docs/interview.md#q5-scenario--df-says-the-disk-is-100-full-but-du-adds-up-to-40-what-is-happening) | Scenario | AWS 01 |
| Linux / operations | [Patching 100 servers without outages](../../projects/aws/01-linux-server-engineering/docs/interview.md#q6-scenario--how-do-you-keep-100-linux-servers-patched-without-causing-outages) | Scenario | AWS 01 |
| AWS / security | [IMDSv2 and the hop limit](../../projects/aws/01-linux-server-engineering/docs/interview.md#q7-advanced--what-is-imdsv2-and-why-does-this-lab-set-the-hop-limit-to-1) | Advanced | AWS 01 |
| Containers | [Container vs virtual machine](../../projects/aws/02-dockerized-app-on-vm/docs/interview.md#q1-beginner--what-is-the-difference-between-a-container-and-a-virtual-machine) | Beginner | AWS 02 |
| Docker builds | [Layers, cache and fast Dockerfiles](../../projects/aws/02-dockerized-app-on-vm/docs/interview.md#q2-intermediate--how-do-docker-layers-and-the-build-cache-work-and-how-do-you-write-a-dockerfile-that-builds-fast) | Intermediate | AWS 02 |
| Container security | [Hardening a container at runtime](../../projects/aws/02-dockerized-app-on-vm/docs/interview.md#q3-intermediate--how-do-you-harden-a-container-at-runtime) | Intermediate | AWS 02 |
| Docker networking | [Port 80 reachable although ufw denies it](../../projects/aws/02-dockerized-app-on-vm/docs/interview.md#q4-advanced--port-80-is-reachable-even-though-ufw-denies-it-why) | Advanced | AWS 02 |
| Reliability | [Liveness vs readiness](../../projects/aws/02-dockerized-app-on-vm/docs/interview.md#q5-intermediate--liveness-vs-readiness-why-does-taskboard-have-both-healthz-and-readyz) | Intermediate | AWS 02 |
| Delivery | [Recovering from a bad deploy on one host](../../projects/aws/02-dockerized-app-on-vm/docs/interview.md#q6-scenario--a-deploy-broke-production-on-a-single-docker-host-walk-me-through-recovery-and-prevention) | Scenario | AWS 02 |
| Delivery / supply chain | [SSH builds vs a registry](../../projects/aws/02-dockerized-app-on-vm/docs/interview.md#q7-advanced--why-does-this-lab-build-images-on-the-vm-over-ssh-instead-of-pushing-to-a-registry-when-is-that-wrong) | Advanced | AWS 02 |
| Edge / NGINX | [What a reverse proxy does](../../projects/aws/03-multi-service-docker-app/docs/interview.md#q1-beginner--what-does-a-reverse-proxy-do-and-why-put-one-in-front-of-the-api) | Beginner | AWS 03 |
| Docker networking | [Service discovery in Compose](../../projects/aws/03-multi-service-docker-app/docs/interview.md#q2-intermediate--how-do-containers-in-a-compose-project-find-each-other) | Intermediate | AWS 03 |
| Compose | [Why `depends_on` is not enough](../../projects/aws/03-multi-service-docker-app/docs/interview.md#q3-intermediate--why-does-depends_on-not-guarantee-the-database-is-available) | Intermediate | AWS 03 |
| Network security | [Isolating and proving database isolation](../../projects/aws/03-multi-service-docker-app/docs/interview.md#q4-advanced--how-did-you-isolate-the-database-and-how-would-you-prove-it) | Advanced | AWS 03 |
| Secrets | [Secrets in Compose deployments](../../projects/aws/03-multi-service-docker-app/docs/interview.md#q5-intermediate--how-do-you-handle-secrets-in-a-compose-deployment) | Intermediate | AWS 03 |
| Data / DR | [Corrupted DB volume: recovery, RPO, RTO](../../projects/aws/03-multi-service-docker-app/docs/interview.md#q6-scenario--the-database-volume-is-corrupted-walk-through-recovery-and-what-rporto-you-can-promise) | Scenario | AWS 03 |
| Architecture | [When to move off Compose](../../projects/aws/03-multi-service-docker-app/docs/interview.md#q7-advanced--when-would-you-move-this-stack-off-compose-and-to-what) | Advanced | AWS 03 |
| Networking | [What makes a subnet public or private in AWS?](../../projects/aws/04-terraform-networking-foundations/docs/interview.md#q1-beginner--what-makes-a-subnet-public-or-private-in-aws) | Beginner | AWS 04 |
| Networking / cost | [NAT Gateway or NAT instance? How many?](../../projects/aws/04-terraform-networking-foundations/docs/interview.md#q2-intermediate--nat-gateway-or-nat-instance-how-many) | Intermediate | AWS 04 |
| Networking / security | [Security groups vs network ACLs](../../projects/aws/04-terraform-networking-foundations/docs/interview.md#q3-intermediate--security-groups-vs-network-acls) | Intermediate | AWS 04 |
| Networking / security | [Why does the database security group reference the app security group instead of a CIDR?](../../projects/aws/04-terraform-networking-foundations/docs/interview.md#q4-intermediate--why-does-the-database-security-group-reference-the-app-security-group-instead-of-a-cidr) | Intermediate | AWS 04 |
| Terraform state | [How do you share Terraform state safely between people and pipelines?](../../projects/aws/04-terraform-networking-foundations/docs/interview.md#q5-intermediate--how-do-you-share-terraform-state-safely-between-people-and-pipelines) | Intermediate | AWS 04 |
| Terraform / incident | [`terraform apply` failed halfway and now everyone gets "Error acquiring the state lock". What do you do?](../../projects/aws/04-terraform-networking-foundations/docs/interview.md#q6-scenario--terraform-apply-failed-halfway-and-now-everyone-gets-error-acquiring-the-state-lock-what-do-you-do) | Scenario | AWS 04 |
| Architecture | [Design the network for a three-tier app that must survive an AZ failure](../../projects/aws/04-terraform-networking-foundations/docs/interview.md#q7-advanced--design-the-network-for-a-three-tier-app-that-must-survive-an-az-failure) | Advanced | AWS 04 |
| Reliability | [What is the difference between high availability and fault tolerance?](../../projects/aws/05-highly-available-server-app/docs/interview.md#q1-beginner--what-is-the-difference-between-high-availability-and-fault-tolerance) | Beginner | AWS 05 |
| Reliability / AWS | [Walk through what happens when an instance in the Auto Scaling group dies.](../../projects/aws/05-highly-available-server-app/docs/interview.md#q2-intermediate--walk-through-what-happens-when-an-instance-in-the-auto-scaling-group-dies) | Intermediate | AWS 05 |
| Reliability / design | [The database goes down. Your load balancer health check is `/readyz`. What happens, and is that what you want?](../../projects/aws/05-highly-available-server-app/docs/interview.md#q3-advanced--the-database-goes-down-your-load-balancer-health-check-is-readyz-what-happens-and-is-that-what-you-want) | Advanced | AWS 05 |
| Delivery | [How do you deploy a new version to an Auto Scaling group without downtime?](../../projects/aws/05-highly-available-server-app/docs/interview.md#q4-intermediate--how-do-you-deploy-a-new-version-to-an-auto-scaling-group-without-downtime) | Intermediate | AWS 05 |
| Secrets / Terraform | [How does the database password get to the instances, and where can it leak?](../../projects/aws/05-highly-available-server-app/docs/interview.md#q5-advanced--how-does-the-database-password-get-to-the-instances-and-where-can-it-leak) | Advanced | AWS 05 |
| AWS / incident | [Instances keep being replaced every few minutes and the service never stabilises. How do you debug it?](../../projects/aws/05-highly-available-server-app/docs/interview.md#q6-scenario--instances-keep-being-replaced-every-few-minutes-and-the-service-never-stabilises-how-do-you-debug-it) | Scenario | AWS 05 |
| Architecture / security | [This design keeps app instances in public subnets. Defend it, then describe the production version.](../../projects/aws/05-highly-available-server-app/docs/interview.md#q7-advanced--this-design-keeps-app-instances-in-public-subnets-defend-it-then-describe-the-production-version) | Advanced | AWS 05 |
| CI/CD | [What are the stages of a CI/CD pipeline for a containerised service, and why in that order?](../../projects/aws/06-secure-cicd-container-registry/docs/interview.md#q1-beginner--what-are-the-stages-of-a-cicd-pipeline-for-a-containerised-service-and-why-in-that-order) | Beginner | AWS 06 |
| CI/CD / security | [How does GitHub Actions get AWS credentials without storing access keys?](../../projects/aws/06-secure-cicd-container-registry/docs/interview.md#q2-intermediate--how-does-github-actions-get-aws-credentials-without-storing-access-keys) | Intermediate | AWS 06 |
| Supply chain | [Why deploy by digest instead of by tag?](../../projects/aws/06-secure-cicd-container-registry/docs/interview.md#q3-intermediate--why-deploy-by-digest-instead-of-by-tag) | Intermediate | AWS 06 |
| Supply chain | [What do an SBOM and a provenance attestation give you that a vulnerability scan does not?](../../projects/aws/06-secure-cicd-container-registry/docs/interview.md#q4-advanced--what-do-an-sbom-and-a-provenance-attestation-give-you-that-a-vulnerability-scan-does-not) | Advanced | AWS 06 |
| CI/CD / incident | [The vulnerability gate blocks an urgent fix. What do you do?](../../projects/aws/06-secure-cicd-container-registry/docs/interview.md#q5-scenario--the-vulnerability-gate-blocks-an-urgent-fix-what-do-you-do) | Scenario | AWS 06 |
| Delivery / security | [Push-based deployment over SSH vs pull-based via an agent: which and why?](../../projects/aws/06-secure-cicd-container-registry/docs/interview.md#q6-advanced--push-based-deployment-over-ssh-vs-pull-based-via-an-agent-which-and-why) | Advanced | AWS 06 |
| Supply chain / incident | [A pipeline was compromised and pushed a malicious image. How would you detect it, limit the damage and recover?](../../projects/aws/06-secure-cicd-container-registry/docs/interview.md#q7-scenario--a-pipeline-was-compromised-and-pushed-a-malicious-image-how-would-you-detect-it-limit-the-damage-and-recover) | Scenario | AWS 06 |
| Kubernetes / EKS | [What does EKS manage for you, and what do you still own?](../../projects/aws/07-managed-kubernetes-foundations/docs/interview.md#q1-beginner--what-does-eks-manage-for-you-and-what-do-you-still-own) | Beginner | AWS 07 |
| Kubernetes networking | [How do pods get IP addresses on EKS, and why can a t3.small only run 11 pods?](../../projects/aws/07-managed-kubernetes-foundations/docs/interview.md#q2-intermediate--how-do-pods-get-ip-addresses-on-eks-and-why-can-a-t3small-only-run-11-pods) | Intermediate | AWS 07 |
| Kubernetes | [Walk through what happens between `kubectl apply -f deployment.yaml` and a Ready pod.](../../projects/aws/07-managed-kubernetes-foundations/docs/interview.md#q3-intermediate--walk-through-what-happens-between-kubectl-apply--f-deploymentyaml-and-a-ready-pod) | Intermediate | AWS 07 |
| Kubernetes security | [How do you control who can do what in an EKS cluster?](../../projects/aws/07-managed-kubernetes-foundations/docs/interview.md#q4-advanced--how-do-you-control-who-can-do-what-in-an-eks-cluster) | Advanced | AWS 07 |
| Kubernetes / IAM | [How should a pod get AWS permissions, and what is wrong with using the node role?](../../projects/aws/07-managed-kubernetes-foundations/docs/interview.md#q5-advanced--how-should-a-pod-get-aws-permissions-and-what-is-wrong-with-using-the-node-role) | Advanced | AWS 07 |
| Kubernetes / incident | [Pods are stuck in `Pending` after a deployment scaled up. Diagnose it.](../../projects/aws/07-managed-kubernetes-foundations/docs/interview.md#q6-scenario--pods-are-stuck-in-pending-after-a-deployment-scaled-up-diagnose-it) | Scenario | AWS 07 |
| Kubernetes / cost | [Your manager asks why the Kubernetes bill is higher than the old VMs. Break it down and cut it.](../../projects/aws/07-managed-kubernetes-foundations/docs/interview.md#q7-scenario--your-manager-asks-why-the-kubernetes-bill-is-higher-than-the-old-vms-break-it-down-and-cut-it) | Scenario | AWS 07 |
| Kubernetes networking | [ClusterIP, NodePort, LoadBalancer, Ingress: when do you use each?](../../projects/aws/08-kubernetes-networking-autoscaling/docs/interview.md#q1-beginner--clusterip-nodeport-loadbalancer-ingress-when-do-you-use-each) | Beginner | AWS 08 |
| Kubernetes / AWS | [Explain `target-type: ip` vs `instance` on the AWS Load Balancer Controller.](../../projects/aws/08-kubernetes-networking-autoscaling/docs/interview.md#q2-intermediate--explain-target-type-ip-vs-instance-on-the-aws-load-balancer-controller) | Intermediate | AWS 08 |
| Kubernetes autoscaling | [How does the HPA decide how many replicas to run?](../../projects/aws/08-kubernetes-networking-autoscaling/docs/interview.md#q3-intermediate--how-does-the-hpa-decide-how-many-replicas-to-run) | Intermediate | AWS 08 |
| Kubernetes security | [Design NetworkPolicies for a namespace. What goes wrong most often?](../../projects/aws/08-kubernetes-networking-autoscaling/docs/interview.md#q4-advanced--design-networkpolicies-for-a-namespace-what-goes-wrong-most-often) | Advanced | AWS 08 |
| Kubernetes / delivery | [How do you get zero-downtime deployments and node maintenance on Kubernetes?](../../projects/aws/08-kubernetes-networking-autoscaling/docs/interview.md#q5-intermediate--how-do-you-get-zero-downtime-deployments-and-node-maintenance-on-kubernetes) | Intermediate | AWS 08 |
| Kubernetes / incident | [After a change, the ALB returns 502 for every request but all pods are Running and Ready. Debug it.](../../projects/aws/08-kubernetes-networking-autoscaling/docs/interview.md#q6-scenario--after-a-change-the-alb-returns-502-for-every-request-but-all-pods-are-running-and-ready-debug-it) | Scenario | AWS 08 |
| Kubernetes / cost | [Kubernetes created an ALB. Who owns it, and how do you avoid leaks and surprises?](../../projects/aws/08-kubernetes-networking-autoscaling/docs/interview.md#q7-advanced--kubernetes-created-an-alb-who-owns-it-and-how-do-you-avoid-leaks-and-surprises) | Advanced | AWS 08 |
| GitOps | [What is GitOps, and how is it different from a CI pipeline running `kubectl apply`?](../../projects/aws/09-helm-argocd-gitops/docs/interview.md#q1-beginner--what-is-gitops-and-how-is-it-different-from-a-ci-pipeline-running-kubectl-apply) | Beginner | AWS 09 |
| GitOps / Argo CD | [Explain Argo CD's architecture. What happens between a commit and running pods?](../../projects/aws/09-helm-argocd-gitops/docs/interview.md#q2-intermediate--explain-argo-cds-architecture-what-happens-between-a-commit-and-running-pods) | Intermediate | AWS 09 |
| Helm | [How do you manage multiple environments with one Helm chart?](../../projects/aws/09-helm-argocd-gitops/docs/interview.md#q3-intermediate--how-do-you-manage-multiple-environments-with-one-helm-chart) | Intermediate | AWS 09 |
| GitOps / Terraform | [How do you bootstrap Argo CD with Terraform without a chicken-and-egg problem?](../../projects/aws/09-helm-argocd-gitops/docs/interview.md#q4-advanced--how-do-you-bootstrap-argo-cd-with-terraform-without-a-chicken-and-egg-problem) | Advanced | AWS 09 |
| GitOps / incident | [A bad release reached production through GitOps. How do you roll back, and what must you not do?](../../projects/aws/09-helm-argocd-gitops/docs/interview.md#q5-scenario--a-bad-release-reached-production-through-gitops-how-do-you-roll-back-and-what-must-you-not-do) | Scenario | AWS 09 |
| GitOps security | [How do you secure Argo CD itself?](../../projects/aws/09-helm-argocd-gitops/docs/interview.md#q6-advanced--how-do-you-secure-argo-cd-itself) | Advanced | AWS 09 |
| GitOps / incident | [During an incident, an engineer scales the prod Deployment by hand and Argo CD keeps putting it back. What is the right process?](../../projects/aws/09-helm-argocd-gitops/docs/interview.md#q7-scenario--during-an-incident-an-engineer-scales-the-prod-deployment-by-hand-and-argo-cd-keeps-putting-it-back-what-is-the-right-process) | Scenario | AWS 09 |

## By cloud

| Cloud | Labs with questions | Count |
|---|---|---|
| AWS | 01–09 | 63 |
| Azure | — (planned) | 0 |
| GCP | — (planned) | 0 |

Most questions so far are cloud-independent (Linux, Docker, NGINX); AWS-specific ones: IMDSv2, security
groups, SSH builds vs ECR, VPC/NAT design, ALB + Auto Scaling, RDS secrets.

## By difficulty

| Level | Questions |
|---|---|
| Beginner | AWS 01 Q1 · AWS 02 Q1 · AWS 03 Q1 · AWS 04 Q1 · AWS 05 Q1 · AWS 06 Q1 · AWS 07 Q1 · AWS 08 Q1 · AWS 09 Q1 |
| Intermediate | AWS 01 Q2, Q3 · AWS 02 Q2, Q3, Q5 · AWS 03 Q2, Q3, Q5 · AWS 04 Q2, Q3, Q4, Q5 · AWS 05 Q2, Q4 · AWS 06 Q2, Q3 · AWS 07 Q2, Q3 · AWS 08 Q2, Q3, Q5 · AWS 09 Q2, Q3 |
| Advanced | AWS 01 Q4, Q7 · AWS 02 Q4, Q7 · AWS 03 Q4, Q7 · AWS 04 Q7 · AWS 05 Q3, Q5, Q7 · AWS 06 Q4, Q6 · AWS 07 Q4, Q5 · AWS 08 Q4, Q7 · AWS 09 Q4, Q6 |
| Scenario | AWS 01 Q5, Q6 · AWS 02 Q6 · AWS 03 Q6 · AWS 04 Q6 · AWS 05 Q6 · AWS 06 Q5, Q7 · AWS 07 Q6, Q7 · AWS 08 Q6 · AWS 09 Q5, Q7 |

## Scenario drills (incident-style)

| Scenario | Where to practise hands-on |
|---|---|
| Server slow, nothing obviously busy | AWS 01 `lab-fault cpu` + CPU credit discussion |
| Disk full but files "not there" | AWS 01 `lab-fault disk`, Q5 |
| Bad release on a single host | AWS 02 exercise 9 "bad release" |
| Database outage: what should restart and what should not | AWS 03 `failure-drill.sh db-down` |
| Restore from backup under pressure | AWS 03 exercise 7, Q6 |
| Stale Terraform lock after a crashed apply | AWS 04 exercise 6, Q6 |
| NACL silently breaking outbound traffic | AWS 04 exercise 4 |
| Instance loss behind a load balancer | AWS 05 `failure-drill.sh terminate` + `probe.sh` |
| Database outage with readiness health checks (fail open) | AWS 05 exercise 7, Q3 |
| Replacement loop in an Auto Scaling group | AWS 05 Q6, troubleshooting #5 |
| Vulnerability gate blocks an urgent release | AWS 06 exercise 3, Q5 |
| Compromised pipeline pushed an image | AWS 06 Q7, exercise 7 (provenance) |
| Pods stuck Pending (Too many pods) | AWS 07 exercise 2, Q6 |
| Node lost: drain, reschedule, replace | AWS 07 exercise 9 |
| ALB returns 502 while pods are Ready (NetworkPolicy) | AWS 08 drill break-policy, Q6 |
| Drain blocked by a PodDisruptionBudget | AWS 08 exercise 5 |
| Bad release in GitOps: roll back through Git only | AWS 09 exercise 7, Q5 |
| Manual change keeps being reverted (self-heal) during an incident | AWS 09 Q7, exercise 5 |

Roles and study plans: [learning paths → interview preparation](../learning-paths/README.md#interview-preparation).
