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

## By cloud

| Cloud | Labs with questions | Count |
|---|---|---|
| AWS | 01, 02, 03 | 21 |
| Azure | — (planned) | 0 |
| GCP | — (planned) | 0 |

Most questions so far are cloud-independent (Linux, Docker, NGINX); AWS-specific ones: IMDSv2, security
groups, SSH builds vs ECR.

## By difficulty

| Level | Questions |
|---|---|
| Beginner | AWS 01 Q1 · AWS 02 Q1 · AWS 03 Q1 |
| Intermediate | AWS 01 Q2, Q3 · AWS 02 Q2, Q3, Q5 · AWS 03 Q2, Q3, Q5 |
| Advanced | AWS 01 Q4, Q7 · AWS 02 Q4, Q7 · AWS 03 Q4, Q7 |
| Scenario | AWS 01 Q5, Q6 · AWS 02 Q6 · AWS 03 Q6 |

## Scenario drills (incident-style)

| Scenario | Where to practise hands-on |
|---|---|
| Server slow, nothing obviously busy | AWS 01 `lab-fault cpu` + CPU credit discussion |
| Disk full but files "not there" | AWS 01 `lab-fault disk`, Q5 |
| Bad release on a single host | AWS 02 exercise 9 "bad release" |
| Database outage: what should restart and what should not | AWS 03 `failure-drill.sh db-down` |
| Restore from backup under pressure | AWS 03 exercise 7, Q6 |

Roles and study plans: [learning paths → interview preparation](../learning-paths/README.md#interview-preparation).
