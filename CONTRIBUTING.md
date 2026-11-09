# Contributing

Thanks for improving the labs. The bar is: someone can **learn from it, deploy from it, troubleshoot
with it, practise it repeatedly, and explain it in an interview**. Read
[docs/conventions.md](docs/conventions.md) first.

## Kinds of contribution

| Change | Where | Notes |
|---|---|---|
| Fix a broken step or wrong explanation | the lab's README or `docs/` | Include the command output that shows the problem |
| Add a troubleshooting incident | `docs/troubleshooting.md` | Must be reproducible on the lab, with diagnosis and prevention |
| Add an interview question | `docs/interview.md` | Use the [template](docs/templates/interview-question.md); keep 5–8 per lab |
| Implement a planned project | `projects/<cloud>/<NN>-<slug>/` | Follow the definition of done below; update the catalog |
| Record a real deployment test | `catalog/projects.yaml` | See "Recording a deployment test" |

## Definition of done for a project

A project may be marked `implemented` only when all of these hold:

- [ ] Infrastructure or deployment configuration exists (Terraform, Compose, manifests, scripts).
- [ ] Instructions are reproducible from a clean checkout; every command block runs as written.
- [ ] README follows the [project template](docs/templates/project-readme.md): problem, architecture,
      component table, concepts, deploy, verify, cleanup, repeat practice, self-assessment.
- [ ] At least two Mermaid diagrams in the README, coloured with the palette, each explained.
- [ ] Concepts link to `docs/concepts/` (add a guide if a new concept is introduced).
- [ ] At least one ADR using the [ADR template](docs/templates/adr.md).
- [ ] `docs/cost.md` with region, resources, rates with sources, formula, free-tier fit, pricing date,
      exclusions and cleanup. Unverified prices are labelled as such.
- [ ] `verify.sh` with positive and negative checks; expected results documented.
- [ ] `docs/troubleshooting.md` with ≥ 5 realistic incidents.
- [ ] `docs/interview.md` with 5–8 questions, each with a diagram, walkthrough and follow-ups; added
      to the [interview index](docs/interview-preparation/README.md).
- [ ] Cleanup instructions that leave no billable resources; resources tagged.
- [ ] `scripts/validate.sh` passes.
- [ ] Catalog entry updated and tracker regenerated (`python3 scripts/catalog.py tracker --write`).

Live deployment is tracked separately and is **not** required for `implemented`.

## Validation

```bash
scripts/validate.sh                 # all local checks; uses Docker images for linters you lack
python3 scripts/catalog.py validate
projects/aws/<lab>/scripts/local-test.sh   # where the lab has one
```

CI runs the same static checks on every pull request. CI never deploys to a cloud.

## Recording a deployment test

Only after you actually ran it in your own account:

1. `terraform apply`, the lab's `deploy.sh`, then `verify.sh` — save the output.
2. `terraform destroy` and `shared/scripts/aws-find-lab-resources.sh` (no resources left).
3. In `catalog/projects.yaml` set `validation.deployment: passed`, `status: deployment-tested`, and add:

```yaml
deployment_record:
  date: 2026-11-20
  region: us-east-1
  terraform_version: 1.15.6
  provider_versions: { aws: 6.x.y }
  verify_output: "All checks passed."   # or a link to a gist with the full output
  tester: your-github-handle
```

4. Regenerate the tracker. A failed deployment is just as useful: record `failed` with the error.

## Pull requests

- One lab or one topic per PR.
- Explain *why*, link the issue, and paste the validation output.
- Never commit `terraform.tfvars`, state files, `.env`, `secrets/` or keys (`.gitignore` covers them;
  gitleaks runs in CI).
- New diagrams must pass `scripts/validate.sh mermaid`.

## Code of conduct

Be respectful and constructive. Assume good intent; critique ideas, not people.
