#!/usr/bin/env python3
"""Validate catalog/projects.yaml against the repository and generate the progress tracker.

    python3 scripts/catalog.py validate          # exit 1 on any problem
    python3 scripts/catalog.py tracker           # print the tracker table
    python3 scripts/catalog.py tracker --write   # update docs/progress/implementation-tracker.md

For every project marked "implemented" the validator enforces the repository's project standard:
required files, at least one ADR, 5-8 interview questions each with a Mermaid diagram, at least five
troubleshooting entries, a cost estimate with a formula and a cleanup section.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "catalog" / "projects.yaml"
TRACKER = ROOT / "docs" / "progress" / "implementation-tracker.md"
BEGIN, END = "<!-- tracker:begin -->", "<!-- tracker:end -->"

CLOUDS = ("aws", "azure", "gcp")
STATUSES = {"planned", "implemented", "deployment-tested"}
VALIDATION = {"passed", "failed", "not-run", "not-tested", "n/a"}
FREE_TIER = {"fits", "partial", "no"}
README_SECTIONS = ("## Architecture", "## Concepts used", "## Deploy", "## Repeat practice", "Clean up")


def load() -> list[dict]:
    with CATALOG.open(encoding="utf-8") as fh:
        return yaml.safe_load(fh)["projects"]


def mermaid_blocks(text: str) -> int:
    return len(re.findall(r"^```mermaid\s*$", text, flags=re.M))


def project_checks(p: dict) -> dict[str, bool]:
    """Structural checks for one implemented project. Keys become tracker columns."""
    base = ROOT / p["path"]
    readme = base / "README.md"
    interview = base / "docs" / "interview.md"
    trouble = base / "docs" / "troubleshooting.md"
    cost = base / "docs" / "cost.md"
    adrs = sorted((base / "docs" / "adr").glob("*.md")) if (base / "docs" / "adr").is_dir() else []

    readme_text = readme.read_text(encoding="utf-8") if readme.exists() else ""
    interview_text = interview.read_text(encoding="utf-8") if interview.exists() else ""
    trouble_text = trouble.read_text(encoding="utf-8") if trouble.exists() else ""
    cost_text = cost.read_text(encoding="utf-8") if cost.exists() else ""

    questions = len(re.findall(r"^## Q\d+", interview_text, flags=re.M))
    incidents = len(re.findall(r"^## \d+\.", trouble_text, flags=re.M))

    return {
        "docs": readme.exists() and all(s in readme_text for s in README_SECTIONS),
        "iac": (base / "terraform").is_dir() and any((base / "terraform").glob("*.tf")),
        "app": (base / "scripts").is_dir() and any((base / "scripts").glob("*.sh")),
        "diagrams": mermaid_blocks(readme_text) >= 2,
        "adr": len(adrs) >= 1 and all("## Decision" in a.read_text(encoding="utf-8") for a in adrs),
        "cost": "## Formula" in cost_text and "## Cleanup" in cost_text,
        "troubleshooting": incidents >= 5,
        "interview": 5 <= questions <= 8 and mermaid_blocks(interview_text) >= questions,
    }


def validate() -> int:
    errors: list[str] = []
    projects = load()
    ids = [p["id"] for p in projects]
    if len(ids) != len(set(ids)):
        errors.append("duplicate project ids")
    for cloud in CLOUDS:
        nums = sorted(p["number"] for p in projects if p["cloud"] == cloud)
        if nums != list(range(1, 16)):
            errors.append(f"{cloud}: expected projects 1-15, found {nums}")
    known = set(ids)
    for p in projects:
        pid = p["id"]
        if p["status"] not in STATUSES:
            errors.append(f"{pid}: unknown status {p['status']}")
        for key, value in p["validation"].items():
            if value not in VALIDATION:
                errors.append(f"{pid}: validation.{key} has unknown value {value}")
        if p["free_tier"]["fit"] not in FREE_TIER:
            errors.append(f"{pid}: free_tier.fit must be one of {sorted(FREE_TIER)}")
        for dep in p["depends_on"]:
            if dep not in known:
                errors.append(f"{pid}: depends on unknown project {dep}")
        if p["status"] == "planned":
            if "path" in p:
                errors.append(f"{pid}: planned projects must use planned_path, not path")
            if p["validation"]["deployment"] != "not-tested":
                errors.append(f"{pid}: planned project cannot have deployment validation")
            if (ROOT / p["planned_path"]).exists():
                errors.append(f"{pid}: {p['planned_path']} exists but status is planned")
            continue
        if not (ROOT / p.get("path", "")).is_dir():
            errors.append(f"{pid}: path {p.get('path')} does not exist")
            continue
        failed = [k for k, ok in project_checks(p).items() if not ok]
        if failed:
            errors.append(f"{pid}: does not meet the project standard: {', '.join(failed)}")
        if p["status"] == "deployment-tested" and p["validation"]["deployment"] != "passed":
            errors.append(f"{pid}: deployment-tested requires validation.deployment = passed")
        if p["validation"]["deployment"] == "passed" and not p.get("deployment_record"):
            errors.append(f"{pid}: deployment passed but no deployment_record (date, region, verify output)")

    for e in errors:
        print(f"FAIL {e}")
    implemented = sum(p["status"] != "planned" for p in projects)
    print(f"{len(projects)} projects in catalog, {implemented} implemented, {len(errors)} problem(s)")
    return 1 if errors else 0


def mark(ok: bool | None) -> str:
    return "—" if ok is None else ("✅" if ok else "❌")


def vmark(value: str) -> str:
    return {"passed": "✅ passed", "failed": "❌ failed", "not-run": "—", "not-tested": "⏳ not tested", "n/a": "n/a"}[value]


def tracker() -> str:
    cols = ["docs", "iac", "app", "diagrams", "adr", "cost", "troubleshooting", "interview"]
    lines = []
    for cloud in CLOUDS:
        lines += [f"### {cloud.upper()}", "",
                  "| ID | Project | Free tier | Status | Docs | IaC | App/scripts | Diagrams | ADR | Cost | Troubleshooting | Interview | Static | Local | Cloud deploy |",
                  "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
        for p in (x for x in load() if x["cloud"] == cloud):
            checks = project_checks(p) if p["status"] != "planned" else dict.fromkeys(cols)
            title = f"[{p['title']}](../../{p['path']}/)" if "path" in p else p["title"]
            row = [p["id"], title, p["free_tier"]["fit"], p["status"], *[mark(checks[c]) for c in cols],
                   *(("—", "—", "—") if p["status"] == "planned" else
                     (vmark(p["validation"]["static"]), vmark(p["validation"]["local"]), vmark(p["validation"]["deployment"])))]
            lines.append("| " + " | ".join(row) + " |")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def write_tracker() -> int:
    text = TRACKER.read_text(encoding="utf-8")
    start, end = text.index(BEGIN) + len(BEGIN), text.index(END)
    TRACKER.write_text(text[:start] + "\n" + tracker() + text[end:], encoding="utf-8")
    print(f"updated {TRACKER.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "validate"
    if cmd == "validate":
        sys.exit(validate())
    if cmd == "tracker":
        if "--write" in sys.argv:
            sys.exit(write_tracker())
        print(tracker())
        sys.exit(0)
    print(__doc__)
    sys.exit(2)
