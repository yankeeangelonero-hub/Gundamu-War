from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import gitinfo, model

TPL = Path(__file__).parent / "templates"


def compute_discrepancy(root, canon) -> dict:
    """Compare the graph's stamped canon.sha to current HEAD.

    Returns {out_of_sync: bool, count: int|None, canon: sha|None, head: sha|None}.
    The renderer never guesses node state — this is the only staleness signal, and
    it is git-derived only. `canon`/`head` let the board show the two versions.
    """
    sha = (canon or {}).get("sha")
    head = gitinfo.head_sha(root)
    if not sha or not head:
        return {"out_of_sync": False, "count": None, "canon": sha, "head": head}
    if sha == head:
        return {"out_of_sync": False, "count": 0, "canon": sha, "head": head}
    count = gitinfo.commits_between(root, sha, "HEAD")
    return {"out_of_sync": bool(count), "count": count, "canon": sha, "head": head}


def resolve_tokens(root) -> str:
    """A project's own tokens.css if present, else the bundled default theme."""
    proj = Path(root) / "tokens.css"
    if proj.exists():
        return proj.read_text(encoding="utf-8")
    return (TPL / "default-tokens.css").read_text(encoding="utf-8")


def _starter_roadmap(root) -> str:
    """A one-node seed graph. The seed's handoff (and the board's Design /
    re-architect brief) drives Claude to explore scope + code and build the real tree."""
    name = Path(root).resolve().name or "new-project"
    data = {
        "project": {
            "name": name,
            "subtitle": "New roadmap — open the board and hand the 'Design / re-architect' brief to Claude",
        },
        "nodes": [
            {
                "id": "PLAN",
                "title": "Design this project's architecture",
                "state": "decision",
                "kind": "decision",
                "deps": [],
                "goal": "Nothing is planned yet. Use the 'Design / re-architect' brief to have Claude "
                        "grill you on the intended shippable product, read the codebase, and plan the "
                        "full road to ship — including the in-between steps that don't exist yet.",
                "doneWhen": "roadmap.json holds the real milestones, slices and decisions and this seed "
                            "node is replaced.",
                "next": "Open the board, click 'Design / re-architect', paste the brief into Claude, "
                        "approve the proposed tree.",
                "spec": "roadmap_tree/roadmap.schema.json",
            }
        ],
    }
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="roadmap_tree",
                                 description="Render roadmap.json into a self-contained board.html")
    ap.add_argument("root", help="project root containing roadmap.json")
    ap.add_argument("--sync", action="store_true",
                    help="stamp canon.sha = HEAD into roadmap.json (the deliberate manual sync)")
    ap.add_argument("--init", action="store_true",
                    help="write a starter roadmap.json (architecture seed) if none exists, then render")
    ap.add_argument("--name", metavar="NAME",
                    help="set the project name in roadmap.json")
    args = ap.parse_args(argv)

    root = Path(args.root).resolve()
    rj = root / "roadmap.json"

    if args.init:
        if rj.exists():
            print(f"error: roadmap.json already exists in {root}", file=sys.stderr)
            return 2
        root.mkdir(parents=True, exist_ok=True)
        rj.write_text(_starter_roadmap(root), encoding="utf-8")
        print(f"wrote starter {rj}", file=sys.stderr)

    if not rj.exists():
        print(f"error: no roadmap.json in {root}", file=sys.stderr)
        return 2

    rm = model.load(rj)
    for w in rm.warnings:
        print(f"warning: {w}", file=sys.stderr)

    if args.name:
        data = json.loads(rj.read_text(encoding="utf-8"))
        data.setdefault("project", {})["name"] = args.name
        rj.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        rm = model.load(rj)
        print(f"set project name to {args.name!r}", file=sys.stderr)

    if args.sync:
        head = gitinfo.head_sha(root)
        if head:
            data = json.loads(rj.read_text(encoding="utf-8"))
            data["canon"] = {"sha": head, "ref": "HEAD"}
            rj.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            rm = model.load(rj)
            print(f"synced canon to {head[:10]}", file=sys.stderr)
        else:
            print("warning: not a git repo — cannot stamp canon", file=sys.stderr)

    disc = compute_discrepancy(root, rm.canon)
    board_js = (TPL / "board.js").read_text(encoding="utf-8")
    html = build_html(rm, disc, resolve_tokens(root), board_js)
    # Keep the project root clean: if the tool folder is here (the drop-in case),
    # write the board inside it; otherwise write it next to roadmap.json.
    pkg_dir = root / "roadmap_tree"
    out = (pkg_dir / "roadmap.html") if pkg_dir.is_dir() else (root / "roadmap.html")
    out.write_text(html, encoding="utf-8")
    print(f"wrote {out}", file=sys.stderr)
    return 0


def build_html(rm, discrepancy: dict, tokens_css: str, board_js: str) -> str:
    payload = {
        "project": rm.project,
        "canon": rm.canon or {},
        "nodes": rm.nodes,
        "discrepancy": discrepancy,
    }
    data_json = json.dumps(
        payload, ensure_ascii=False, indent=2, sort_keys=True
    ).replace("</", "<\\/")
    shell = (TPL / "board.html").read_text(encoding="utf-8")
    return (
        shell
        .replace("/*__TOKENS__*/", tokens_css)
        .replace("/*__BOARD_JS__*/", board_js)
        .replace('"__ROADMAP_DATA__"', data_json)
    )
