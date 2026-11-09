#!/usr/bin/env python3
"""Checks every relative Markdown link: the target file or directory must exist and, when the link has
a #fragment pointing at a Markdown file, the heading must exist (GitHub anchor rules).

External http(s) links are not checked here (CI runs lychee for those).
Usage: python3 scripts/check-links.py [root]     exit code 1 on broken links
"""

from __future__ import annotations

import re
import sys
from functools import lru_cache
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent).resolve()
SKIP = {".git", "node_modules", ".terraform", "templates"}  # templates link relative to their copy target
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
FENCE = re.compile(r"^(```|~~~)")


def strip_fences(text: str) -> str:
    """Blank out fenced code blocks (keeps line numbers)."""
    out, in_fence = [], False
    for line in text.splitlines():
        if FENCE.match(line.strip()):
            in_fence = not in_fence
            out.append("")
            continue
        out.append("" if in_fence else line)
    return "\n".join(out)


def strip_code(text: str) -> str:
    """Remove fenced blocks and inline code so example links are not checked."""
    return re.sub(r"`[^`]*`", "", strip_fences(text))


def slug(heading: str) -> str:
    """GitHub-style heading anchor: lowercase, drop punctuation, spaces to hyphens."""
    text = re.sub(r"<[^>]+>", "", heading)              # inline HTML
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)  # links keep their text
    text = text.strip().lower()
    text = re.sub(r"[^\w\- ]", "", text, flags=re.UNICODE)
    return text.replace(" ", "-")


@lru_cache(maxsize=None)
def anchors(path: Path) -> set[str]:
    found: dict[str, int] = {}
    result = set()
    # Headings keep inline-code text in their anchors, so only fenced blocks are removed here.
    for line in strip_fences(path.read_text(encoding="utf-8")).splitlines():
        m = re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line)
        if not m:
            continue
        base = slug(m.group(1))
        n = found.get(base, 0)
        result.add(base if n == 0 else f"{base}-{n}")
        found[base] = n + 1
    return result


def main() -> int:
    broken = []
    files = [p for p in ROOT.rglob("*.md") if not SKIP.intersection(p.relative_to(ROOT).parts)]
    for md in files:
        for lineno, line in enumerate(strip_code(md.read_text(encoding="utf-8")).splitlines(), 1):
            for target in LINK.findall(line):
                if re.match(r"^[a-z][a-z0-9+.-]*:", target):     # http:, https:, mailto:
                    continue
                path_part, _, frag = target.partition("#")
                dest = md if not path_part else (md.parent / unquote(path_part)).resolve()
                where = f"{md.relative_to(ROOT)}:{lineno}"
                if not dest.exists():
                    broken.append(f"{where}  missing target: {target}")
                    continue
                if frag and dest.is_file() and dest.suffix == ".md" and frag not in anchors(dest):
                    broken.append(f"{where}  missing anchor: {target}")
    for b in broken:
        print(f"FAIL {b}")
    print(f"{len(files)} Markdown file(s) checked, {len(broken)} broken link(s)")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
