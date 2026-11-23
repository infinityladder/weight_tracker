"""
Dated screenshot generations.

    <screenshots root>/2026-11-15/raw/<format>/...        captures
    <screenshots root>/2026-11-15/marketing/<format>/...  slides built from them

A generation is one complete set, named by the date it was started (a set shot over a few
weeks is still one folder). Scripts read the NEWEST generation unless SHOT_SET names
another, and a named set that does not exist is an error -- never a silent fallback.

    from shot_sets import current, new
    root = Path("store-listing/screenshots")
    gen = current(root)            # newest, or $SHOT_SET
    gen = new(root)                # today's, created if needed (start a new generation)
"""
import os
import re
from datetime import date
from pathlib import Path

_DATED = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def generations(root):
    root = Path(root)
    if not root.is_dir():
        return []
    return sorted(p for p in root.iterdir() if p.is_dir() and _DATED.match(p.name))


def current(root):
    root = Path(root)
    want = os.environ.get("SHOT_SET")
    if want:
        p = root / want
        if not p.is_dir():
            have = ", ".join(g.name for g in generations(root)) or "none"
            raise SystemExit(f"no generation {want!r} under {root}; have: {have}")
        return p
    sets = generations(root)
    if not sets:
        raise SystemExit(f"no dated generation under {root}")
    return sets[-1]


def new(root):
    p = Path(root) / date.today().isoformat()
    p.mkdir(parents=True, exist_ok=True)
    return p
