from __future__ import annotations

import subprocess


def _git(root, *args) -> str | None:
    """Run a git command in `root`. Return stripped stdout, or None on any failure."""
    try:
        out = subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True, text=True, check=True,
        )
        return out.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError, OSError):
        return None


def head_sha(root) -> str | None:
    return _git(root, "rev-parse", "HEAD")


def commits_between(root, base: str, head: str = "HEAD") -> int | None:
    out = _git(root, "rev-list", "--count", f"{base}..{head}")
    if out is None:
        return None
    try:
        return int(out)
    except ValueError:
        return None
