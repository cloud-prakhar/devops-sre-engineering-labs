# AWS 08 — Kubernetes Networking and Autoscaling

| | |
|---|---|
| **Project ID** | `aws-08` |
| **Cloud** | AWS (EKS from AWS 07, AWS Load Balancer Controller, Application Load Balancer, IAM, Pod Identity) |
| **Difficulty** | Intermediate |
| **Build time** | 3–4 h first attempt (on a running AWS 07 cluster) |
| **Rebuild time** | 15 min (plus AWS 07) |
| **Free tier** | **No**: runs on the billed AWS 07 cluster and adds an ALB — see [cost](docs/cost.md) (≈ +$0.12 per 3-hour session) |
| **Depends on** | [AWS 07](../07-managed-kubernetes-foundations/) (cluster with `enable_network_policy = true`), [AWS 06](../06-secure-cicd-container-registry/) (image) |
| **Status** | Implemented · static checks passed (Terraform, manifests vs Kubernetes 1.37 schemas) · deployment **not tested** ([tracker](../../../docs/progress/implementation-tracker.md)) |

## The problem this lab solves

At the end of AWS 07 the app ran on Kubernetes but only you could reach it, through `kubectl
port-forward`. Every pod could talk to every other pod in the cluster, two replicas were fixed whatever the
load, and nothing stopped a node drain from taking both replicas at once.

This lab turns the Deployment into a service: an **Ingress** that the AWS Load Balancer Controller turns
into an ALB sending traffic straight to pod IPs; a **default-deny NetworkPolicy** model with explicit
allows; a **HorizontalPodAutoscaler** driven by metrics-server; a **PodDisruptionBudget**; and a rolling
update strategy that never reduces capacity. Then you load it, drain nodes, roll it out and break a policy
while watching what users see.

**Skills learned:** Service vs Ingress vs LoadBalancer · AWS Load Balancer Controller, IngressClass,
annotations, `ip` vs `instance` targets · controller IAM via Pod Identity · NetworkPolicy semantics and
default deny · HPA algorithm, requests and stabilisation · PDBs and drains · `maxSurge`/`maxUnavailable` ·
kustomize overlays and patches · orphaned cloud resources created by Kubernetes.

**Expected outcome:** `scripts/verify.sh` passes — controller ready with Pod Identity credentials, the ALB
answering from your IP and spreading over pods, HPA reading CPU, PDB in force, `maxUnavailable: 0`, and
NetworkPolicy allowing exactly the load-generator and ALB flows while denying others.

## Architecture

```mermaid
flowchart TB
    user([You · ALLOWED_HTTP_CIDR]):::client
    subgraph vpc[AWS 07 VPC 10.70.0.0/16]
        subgraph pub[Public subnets 10.70.0.0/23]
            alb[ALB · HTTP 80<br/>inbound-cidrs = your IP<br/>health check /readyz]:::net
        end
        subgraph cluster[EKS cluster lab07-eks]
            subgraph ks[kube-system]
                lbc[aws-load-balancer-controller ×2<br/>Helm chart 3.6.2]:::k8s
                ms[metrics-server]:::obs
                cni[aws-node + network policy agent]:::sec
            end
            subgraph ns[namespace taskboard · PSA restricted]
                ing[Ingress taskboard<br/>class alb]:::k8s
                svc[Service ClusterIP]:::k8s
                hpa[HPA 2-6 · CPU 60%]:::k8s
                pdb{{PDB minAvailable 1}}:::sec
                np{{NetworkPolicies<br/>default deny · DNS · ALB · load-generator}}:::sec
                pods[taskboard pods<br/>maxSurge 1 · maxUnavailable 0]:::app
                lg[load-generator Job<br/>drill only]:::risk
            end
        end
    end
    iam[IAM role + official policy v3.6.2<br/>Pod Identity association]:::sec
    user --> alb -->|pod IPs :8000| pods
    lbc -. reconciles Ingress → ALB, target groups, rules .-> alb
    lbc -. credentials .-> iam
    ing --> svc --> pods
    ms --> hpa --> pods
    lg --> svc
    classDef client fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a
    classDef net fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a
    classDef k8s fill:#ede9fe,stroke:#6d28d9,color:#4c1d95
    classDef obs fill:#ccfbf1,stroke:#0f766e,color:#134e4a
    classDef sec fill:#ffedd5,stroke:#c2410c,color:#7c2d12
    classDef app fill:#dcfce7,stroke:#15803d,color:#14532d
    classDef risk fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d
```

| Component | Why it is there | Defined in |
|---|---|---|
| IAM role + policy + Pod Identity association | Controller manages ALBs with its own credentials, not the node role | [main.tf](terraform/main.tf), [policy v3.6.2](terraform/policies/aws-load-balancer-controller-v3.6.2.json) |
| AWS Load Balancer Controller | Turns Ingress objects into ALBs, listeners, target groups | [install-controller.sh](scripts/install-controller.sh) |
| Ingress | `internet-facing`, `target-type: ip`, `/readyz` health check, your CIDR only, repository tags | [ingress.yaml](k8s/ingress.yaml) |
| HPA | 2–6 replicas at 60% of the CPU request; fast scale-up, slow scale-down | [hpa.yaml](k8s/hpa.yaml) |
| PDB | Drains keep at least one ready replica | [pdb.yaml](k8s/pdb.yaml) |
| NetworkPolicies | Default deny in/out; DNS, ALB subnets and load-generator explicitly allowed | [networkpolicy.yaml](k8s/networkpolicy.yaml) |
| Kustomization | Reuses AWS 07's base; removes `replicas`, adds the surge strategy | [kustomization.yaml](k8s/kustomization.yaml) |
| Network policy agent | VPC CNI enforcement switched on in AWS 07 (`enable_network_policy`) | [AWS 07 addons.tf](../07-managed-kubernetes-foundations/terraform/addons.tf) |

### From `kubectl apply` to a working ALB

```mermaid
sequenceDiagram
    autonumber
    participant K as kubectl
    participant A as API server
    participant C as LB controller (Pod Identity)
    participant E as ELB / EC2 APIs
    participant P as taskboard pods
    K->>A: apply Ingress (class alb)
    C->>A: watch Ingress, Service, EndpointSlices
    C->>E: create ALB in subnets tagged kubernetes.io/role/elb
    C->>E: security group allowing inbound-cidrs on :80
    C->>E: target group (ip), register ready pod IPs
    C->>A: status.loadBalancer.hostname
    E->>P: health check GET /readyz from ALB ENIs (allowed by NetworkPolicy)
    Note over C,P: pod becomes Ready/NotReady → controller updates targets
```

### Load, rollout and drain

```mermaid
stateDiagram-v2
    [*] --> Steady: 2 replicas, CPU low
    Steady --> ScaledOut: load > 60% of request → HPA +2 pods per 30 s (max 6)
    ScaledOut --> Steady: idle 120 s → HPA −1 pod per 60 s
    Steady --> Rolling: new version → +1 new pod, then −1 old (maxUnavailable 0)
    Rolling --> Steady: all new pods Ready
    Steady --> Draining: kubectl drain node
    Draining --> Steady: evictions allowed only while 1 replica stays Ready (PDB)
    Steady --> Broken: allow-alb policy deleted → targets unhealthy
    Broken --> Steady: policy restored
```

## Concepts used

| Concept | Where in this lab | Guide |
|---|---|---|
| Services, Ingress, NetworkPolicy, HPA, PDB, rollouts | All manifests | [kubernetes-traffic-and-scaling](../../../docs/concepts/kubernetes-traffic-and-scaling.md) |
| Pod Identity, RBAC | Controller credentials | [eks-access-and-identity](../../../docs/concepts/eks-access-and-identity.md) |
| Readiness vs liveness | ALB health check `/readyz` | [health-checks](../../../docs/concepts/health-checks.md) |
| Load balancing, autoscaling (EC2 view) | Comparison with AWS 05 | [load-balancing-and-autoscaling](../../../docs/concepts/load-balancing-and-autoscaling.md) |
| VPC subnets and tags | ALB placement | [aws-vpc-design](../../../docs/concepts/aws-vpc-design.md) |

Architecture decisions: [ADR-0001 ALB Ingress with IP targets](docs/adr/0001-alb-ingress-ip-targets.md) ·
[ADR-0002 HPA on CPU with PDB and surge rollouts](docs/adr/0002-hpa-cpu-pdb-surge.md) ·
[ADR-0003 default-deny NetworkPolicy with the VPC CNI](docs/adr/0003-default-deny-networkpolicy-vpc-cni.md).

## Deploy

> Runs on the AWS 07 cluster, which is billed per hour. Do AWS 07 and 08 in one session.

### 1. Prerequisites

```bash
cd projects/aws/08-kubernetes-networking-autoscaling
kubectl config current-context                     # lab07-admin
aws eks describe-addon --cluster-name lab07-eks --addon-name vpc-cni --query addon.configurationValues
#   -> {"enableNetworkPolicy":"true"}   (AWS 07 default; re-apply AWS 07 if missing)
helm version                                       # v3.14+ or v4
```

### 2. Controller IAM and installation

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
../../../shared/scripts/tf-init-backend.sh terraform
terraform -chdir=terraform plan -out=lab08.tfplan   # 4 resources
terraform -chdir=terraform apply lab08.tfplan
scripts/install-controller.sh
```

### 3. Deploy and verify

```bash
scripts/deploy-workloads.sh                 # your current public IP becomes the ALB's allowed CIDR
scripts/verify.sh
```

| Check | Expected |
|---|---|
| Controller | ≥ 1 ready replica; `AWS_CONTAINER_CREDENTIALS_FULL_URI` in its env (Pod Identity) |
| Ingress | ALB hostname; `/readyz` answers from your IP; ≥ 2 pods seen; ≥ 2 healthy targets |
| HPA | current CPU utilisation reported |
| Rollout strategy | `maxUnavailable: 0` |
| PDB | ≥ 1 disruption allowed |
| NetworkPolicy | load-generator → taskboard allowed; unlabelled pod and other namespace denied |

### 4. Exercises and drills

[docs/exercises.md](docs/exercises.md) and `scripts/failure-drill.sh list` (load, drain, rollout,
break-policy, restore-policy).

### 5. Clean up — order matters

```bash
kubectl delete -k k8s/.generated                    # deletes the Ingress → the controller deletes the ALB
aws elbv2 describe-load-balancers --query 'LoadBalancers[?starts_with(LoadBalancerName,`k8s-taskboar`)].LoadBalancerName'   # wait until empty
helm uninstall aws-load-balancer-controller -n kube-system
terraform -chdir=terraform destroy
# then AWS 07's cleanup
```

If you destroy the cluster first, the ALB, its security groups and target groups are orphaned and keep
billing; `aws-find-lab-resources.sh` finds them by the tags set in the Ingress.

## Troubleshooting, cost and interview material

- [Troubleshooting playbook](docs/troubleshooting.md) — 7 incidents
- [Cost estimate](docs/cost.md)
- [Interview preparation](docs/interview.md) — 7 questions

## Repeat practice

| Attempt | Goal | Guidance |
|---|---|---|
| 1 | Guided build | Follow this README and the exercises |
| 2 | Reduced guidance | Predict the replica count, PDB status and probe results before each drill |
| 3 | Rebuild from objectives | Write the NetworkPolicies yourself from the "who may talk to whom" list; pass `verify.sh` |
| 4 | Failure drills | Someone runs a drill or deletes one policy without telling you; find it from symptoms |
| 5 | Defend the design | Answer the [interview questions](docs/interview.md); argue `instance` targets or NLB and lose |

### Self-assessment

- [ ] I can explain the path of a request from my laptop to a pod, naming every component.
- [ ] I can explain why the Deployment must not set `replicas` when an HPA exists.
- [ ] I can compute what the HPA will do from current CPU and requests.
- [ ] I can explain why the ALB needs its own NetworkPolicy allow, and from which CIDR.
- [ ] I drained a node and can explain what the PDB did.
- [ ] I can list the AWS resources the controller created that Terraform does not know about.

**Done when:** `verify.sh` passes, all drills ran, the self-assessment is complete, and cleanup left no
`k8s-taskboar*` load balancers or tagged resources.

## References

- [AWS Load Balancer Controller documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)
- [EKS network policies](https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy.html)
- [Kubernetes HPA walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [EKS Best Practices — Networking](https://docs.aws.amazon.com/eks/latest/best-practices/networking.html)
