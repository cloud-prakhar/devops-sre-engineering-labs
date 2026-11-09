# Concept guides

Each guide explains one concept once — what it is, why it is needed, how it works, where this repository
uses it, common mistakes, troubleshooting commands and official references. Labs link here instead of
repeating the material.

| Area | Guide | Used by |
|---|---|---|
| Linux | [SSH](linux-ssh.md) | AWS 01–03 |
| Linux | [Users, groups, sudo, permissions](linux-users-permissions.md) | AWS 01–03 |
| Linux | [systemd and journald](linux-systemd.md) | AWS 01 |
| Linux / networking | [Networking, DNS, ports, firewalls](linux-networking-firewalls.md) | AWS 01–03 |
| Linux | [Performance troubleshooting (USE method)](linux-performance-troubleshooting.md) | AWS 01–03 |
| Cloud | [EC2 fundamentals](aws-ec2-fundamentals.md) | AWS 01–03 |
| IaC | [Terraform fundamentals](terraform-fundamentals.md) | all cloud labs |
| Containers | [Images, layers, multi-stage builds](docker-images-and-builds.md) | AWS 02–03 |
| Containers | [Container security](container-security.md) | AWS 02–03 |
| Containers | [Networking and storage](docker-networking-and-storage.md) | AWS 02–03 |
| Containers | [Docker Compose](docker-compose.md) | AWS 03 |
| Reliability | [Health checks: liveness and readiness](health-checks.md) | AWS 02–03 |
| Edge | [Reverse proxies and TLS](reverse-proxy-and-tls.md) | AWS 03 |
| Cloud networking | [AWS VPC design: subnets, routing, NAT, endpoints](aws-vpc-design.md) | AWS 04–05 |
| IaC | [Terraform remote state and locking](terraform-state-and-locking.md) | AWS 04–05 |
| Reliability | [Load balancing, health checks and autoscaling](load-balancing-and-autoscaling.md) | AWS 05 |

New guides are added together with the first lab that needs them (Kubernetes, observability and SRE
guides arrive with AWS 07, 11 and 14).
