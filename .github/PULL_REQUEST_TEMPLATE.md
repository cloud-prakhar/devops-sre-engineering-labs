## What and why

<!-- Link the issue. Explain the problem this change solves. -->

## Projects affected

<!-- e.g. aws-02, shared/sample-apps/taskboard -->

## Validation

<!-- Paste output. Do not claim checks you did not run. -->

- [ ] `scripts/validate.sh` passes
- [ ] `local-test.sh` passes (if the lab has one)
- [ ] Deployed to a real account: **yes / no** (if yes, `deployment_record` added to the catalog)
- [ ] Tracker regenerated (`python3 scripts/catalog.py tracker --write`)

## Checklist

- [ ] Diagrams are Mermaid with the colour palette
- [ ] No secrets, state files or `terraform.tfvars` committed
- [ ] Costs stated with assumptions and date; cleanup instructions updated
- [ ] Definition of done in CONTRIBUTING.md met for any project marked `implemented`
