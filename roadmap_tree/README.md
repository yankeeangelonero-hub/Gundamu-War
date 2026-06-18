# Roadmap Tree

Render a `roadmap.json` dependency graph into a single self-contained, offline-openable `roadmap.html` board. No server, no dependencies.

## Drop into any project

Copy this `roadmap_tree/` folder into your repo root. A ready-to-open board ships inside it at `roadmap_tree/roadmap.html` — **open it right away** (no Python needed) and click **Install** to copy a setup brief for Claude, which explores your repo, builds the real tree, and wires up auto-sync.

To drive it yourself: requires only Python 3 (stdlib — no `pip install`). Run from the repo root (the folder containing `roadmap_tree/`), e.g. `python -m roadmap_tree . --init`. The generated board is written to `roadmap_tree/roadmap.html` (kept inside the tool folder so your project root stays clean); add `roadmap.html` to your `.gitignore`.

## Start a project

    python -m roadmap_tree <project-root> --init

Writes a starter `roadmap.json` with one seed node, then renders. Open the board and click **Design / re-architect** to copy a brief that has Claude explore your scope + codebase and build the real tree. Use that same button any time the project direction changes and the whole architecture needs rethinking.

Rename the project at any time:

    python -m roadmap_tree <project-root> --name "My Project"

## Author a roadmap by hand

Create `roadmap.json` at your project root (see `roadmap_tree/roadmap.schema.json` for the contract). Each node: `id`, `title`, `state` (`shipped|in-progress|ready|blocked|decision|locked|pending`), `kind` (`slice|milestone|decision|future`), `deps` (node ids), and the detail fields `goal`/`doneWhen`/`next`/`spec`.

## Render

    python -m roadmap_tree <project-root>

Writes the board to `<project-root>/roadmap_tree/roadmap.html` when the tool folder is present (otherwise `<project-root>/roadmap.html`). Open it in a browser.

## Staleness

States are never derived — the board shows exactly what `roadmap.json` says. When you reconcile the graph against the code, run:

    python -m roadmap_tree <project-root> --sync

This stamps `canon.sha = HEAD`. Afterwards, if new commits land without a re-sync, the board shows a "VERSION MISMATCH — roadmap canon … vs git HEAD …" banner (and a persistent header chip) until you sync again. Click **Session Diff** on the board to copy a brief that tells Claude to reconcile node states from the real `git diff`.

## Board handoffs

Every "smart" action is a copy-paste brief for Claude — no server, no skills required:

- **Design / re-architect** — plan a new project, or re-evaluate the whole architecture on a direction change.
- **Session Diff** — reconcile node states from the diff since canon.
- **Sync** — the on-every-commit rules to drop into CLAUDE.md.
- **Install** — one-time setup: explore the repo to build the tree, install the auto-sync hook, add the CLAUDE.md block, stamp canon.
- Per-node **Copy handoff** and **Branch here** — start work on a slice, or draft a new branch.
