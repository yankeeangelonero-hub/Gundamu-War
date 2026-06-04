---
project: mech-bags
doc_type: readme
status: draft
updated: 2026-06-04
---

# Mech Bags

> A browser-based HTML prototype for a Backpack Battles-style async autobattler where players arrange shaped mech parts across five body-part bags, upgrade individual bag sizes, then watch 2D sprite battles resolve through a paused ATB animation queue.

## What it is

Mech Bags is shamelessly inspired by Backpack Battles, but with a twist: instead of one backpack, the player's inventory is split across five mech body parts — **Head**, **Torso**, **Back**, **Left Arm**, and **Right Arm**. Each is an independent grid where shaped items can be placed freely.

Bag expansions add cells to a specific body part, making expansion choices part of build strategy. Items have no anatomical restrictions; a beam rifle on the Head bag is valid.

Between rounds, the player shops for new items and expansion upgrades. When ready, the battle is resolved as a deterministic ATB event sequence: simulation time advances until a weapon is ready, pauses while its animation plays, then resumes.

Version 0.1 is a prototype — no backend, no accounts, no real matchmaking.

## Version 0.1 goal

A player can complete a short browser prototype run: buy shaped items and body-part expansions, arrange them across five unrestricted bags, launch battles against prebuilt enemy builds, and watch deterministic ATB sprite playback until a win/loss result.

## Project structure

```
Mech Bags/
├── CLAUDE.md                          # Agent instructions
├── Readme.md                          # This file
├── High Level Project Specifications.md
├── Roadmap.md
├── Version Log.md
├── Kanban.md
├── Current Architecture/
│   ├── Current Architecture.md
│   └── Actor Flows.md
├── Research/
│   ├── Research Catalogue.md
│   ├── wishlist.md
│   ├── flows/
│   │   ├── run-loop-flow.md
│   │   └── atb-battle-flow.md
│   └── UI Design Requirements.md     # (produced by Design agent)
├── Project Version/
│   └── Version 0.1/
│       ├── Version 0_1 Project Specifications.md
│       └── Slices/
│           ├── Slice-01-static-five-bag-board-shell.md
│           ├── Slice-02-item-placement-and-rotation.md
│           ├── Slice-03-shop-and-body-expansion-cards.md
│           ├── Slice-04-data-driven-item-stats-and-adjacency.md
│           ├── Slice-05-deterministic-atb-simulator.md
│           ├── Slice-06-2d-battle-viewer-and-animation-playback.md
│           └── Slice-07-short-run-loop-with-enemy-pool.md
└── agent-handoffs/
    ├── claude-design-ui-requirements.md
    └── claude-code-vouse-scaffold-report.md
```

## Out of scope for Version 0.1

- Real Gundam IP or licensed assets
- Complex mech simulation (limb HP, heat, weight, ammo, pilots)
- Item placement restrictions by body part
- Networking, accounts, or real async matchmaking
- 3D combat
- Production-grade art pipeline
