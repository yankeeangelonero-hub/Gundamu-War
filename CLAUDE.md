# CLAUDE.md — Mech Bags

Project slug: `mech-bags`
Owner: Xuanyue
Root: `D:/Claude/Mech Bags`
Started: 2026-06-04

## What this project is

Mech Bags is a browser-based HTML prototype for a Backpack Battles-style async autobattler. Players arrange shaped mech parts across five body-part bags (Head, Torso, Back, Left Arm, Right Arm), upgrade individual bag sizes, then watch 2D sprite battles resolve through a paused ATB animation queue.

## Context for agents

- **Version 0.1 is a browser prototype only.** No backend, accounts, or real matchmaking. All work stays in plain HTML/CSS/JavaScript (single page preferred).
- **No anatomy police.** Items can go in any bag. Do not add placement restrictions by body part.
- **Simulation and animation are separate concerns.** Keep them architecturally distinct.
- **Determinism is required.** Battle simulation must produce the same event sequence from the same build + seed every time.
- **Enemy builds are static.** Opponent pool is prebuilt data, not networked.

## Key documents

| Document | Purpose |
|---|---|
| `High Level Project Specifications.md` | FEAT, BEH, ARC entries — source of truth for requirements |
| `Roadmap.md` | Milestones and delivery targets |
| `Kanban.md` | Slice-level work status |
| `Project Version/Version 0.1/Version 0_1 Project Specifications.md` | V0.1 scope, slices, and acceptance checks |
| `Current Architecture/Current Architecture.md` | System design for the prototype |
| `agent-handoffs/claude-design-ui-requirements.md` | Visual/UI design requirements — read before touching UI |

## Agents should not

- Create backend code, databases, or network endpoints.
- Add item placement restrictions based on body part.
- Add real Gundam IP, licensed names, or lore.
- Introduce 3D rendering.
- Commit, push, or install dependencies without explicit instruction.

## Naming conventions

- Slices: `Slice-NN-kebab-name`
- Features: `FEAT-NNN`
- Behaviour invariants: `BEH-NNN`
- Architecture constraints: `ARC-NNN`
