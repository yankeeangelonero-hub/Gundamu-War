from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

STATES = {"shipped", "in-progress", "ready", "blocked", "decision", "locked", "pending"}
KINDS = {"slice", "milestone", "decision", "future"}


class RoadmapError(ValueError):
    """Raised when roadmap.json is structurally invalid."""


@dataclass
class Roadmap:
    project: dict
    nodes: list[dict]
    canon: dict | None = None
    warnings: list[str] = field(default_factory=list)


def load(path) -> Roadmap:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    return validate(data)


def validate(data) -> Roadmap:
    if not isinstance(data, dict):
        raise RoadmapError("roadmap.json must be a JSON object")
    project = data.get("project")
    if not isinstance(project, dict) or not project.get("name"):
        raise RoadmapError("project.name is required")
    nodes = data.get("nodes")
    if not isinstance(nodes, list):
        raise RoadmapError("nodes must be a list")

    ids: set[str] = set()
    for i, n in enumerate(nodes):
        if not isinstance(n, dict):
            raise RoadmapError(f"node[{i}] must be an object, got {type(n).__name__}")
        nid = n.get("id")
        if not nid:
            raise RoadmapError(f"node[{i}] is missing an id")
        if nid in ids:
            raise RoadmapError(f"duplicate node id: {nid}")
        ids.add(nid)
        if not n.get("title"):
            raise RoadmapError(f"node {nid} is missing a title")
        if n.get("state") not in STATES:
            raise RoadmapError(f"node {nid} has invalid state: {n.get('state')!r}")
        if n.get("kind") not in KINDS:
            raise RoadmapError(f"node {nid} has invalid kind: {n.get('kind')!r}")

    warnings: list[str] = []
    for n in nodes:
        for d in (n.get("deps") or []):
            if d not in ids:
                warnings.append(f"node {n['id']} has dangling dep: {d}")

    return Roadmap(project=project, nodes=nodes, canon=data.get("canon"), warnings=warnings)
