#!/usr/bin/env python3
"""PostToolUse hook: when a shell tool runs `git commit`, re-render the roadmap
board and remind Claude to reconcile node states in roadmap.json from the commit
diff. Wired in .claude/settings.json on the Bash + PowerShell tools.

The hook only RE-RENDERS; it never edits states or re-stamps canon — reconciling
states is Claude's judgment call (see the "Roadmap sync" block in CLAUDE.md), and
the board will show "OUT OF SYNC" until Claude re-runs `python -m roadmap_tree . --sync`.
"""
import json
import subprocess
import sys


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return  # No/!malformed stdin: nothing to gate on.

    command = (payload.get("tool_input") or {}).get("command", "") or ""
    if "git commit" not in command:
        return  # Only react to commits.

    # Re-render the board from roadmap.json (cwd is the project root for hooks).
    try:
        subprocess.run(
            [sys.executable, "-m", "roadmap_tree", "."],
            check=False,
            capture_output=True,
        )
    except Exception:
        pass  # A render failure must never block the commit flow.

    reminder = (
        "Roadmap: a commit just landed. Reconcile node states in roadmap.json from "
        "the commit diff — mark a node `shipped` when its done-when is met and tests "
        "pass (or `in-progress` if partial), then flip any node whose deps are now all "
        "shipped from `blocked` to `ready`. When done, run "
        "`python -m roadmap_tree . --sync` to re-stamp canon to HEAD."
    )
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": reminder,
        }
    }))


if __name__ == "__main__":
    main()
