---
project: mech-bags
artefact: research-document
kind: concept-handoff
status: frozen
created: 2026-06-05
source: xuanyue
supersedes: Research/Research Documents/concept-handoff-2026-06-05-real-time-theatre-loop.md
supersedes_section: "five-body-part-grid build surface"
---

# Single Canvas and Buyable Bags — Concept Handoff

**Status:** Owner correction for the build surface. This supersedes the five body-part bag assumption for the next iteration while preserving the real-time theatre, retreat, loot, and pilot-growth loop.

---

## Owner correction

The five-bag body-part concept should be dumbed down.

Instead of Head / Torso / Back / Left Arm / Right Arm as separate grids, the game should start from a structure much closer to Backpack Battles:

- one big build canvas;
- small bag/grid pieces that the player can buy each round;
- items placed spatially inside the owned bag space;
- iterate from that simpler base.

The goal is to reduce concept load and use the familiar Backpack Battles grammar first, then layer mech/war/pilot identity on top.

## Revised build-surface direction

The next implementation should test:

1. A single main canvas/workbench.
2. Starting bag space on that canvas.
3. Shop offers include small bag expansions/pieces.
4. Buying a bag adds owned cells/shape to the canvas.
5. Items can be placed anywhere in owned canvas cells if geometry allows.
6. Placement remains spatial/shape-based: out-of-bounds/overlap/unowned-cell failures only.
7. No body-part anatomy restrictions are introduced.

## What this replaces

The prior Version 0.1 identity was:

> five independent body-part bags: Head, Torso, Back, Left Arm, Right Arm.

The revised base identity is:

> one expandable backpack/canvas for a mech-war autobattler.

The mech fantasy can return through item art, pilot, theatre, enemy archetypes, loot, and possibly later bag/module theming. It should not start by requiring five named body-part boards.

## Why this matters

The five-bag concept created a novel mech silhouette, but it also added explanation burden and mobile interaction complexity. A single canvas with buyable bags is easier for players to understand, easier to compare to Backpack Battles, and likely a better foundation for testing the theatre loop.

The immediate test becomes:

> Does the theatre deployment loop work when the build surface is the simplest Backpack-style canvas?

not:

> Can players understand five body-part boards while also learning war theatre, pilot XP, loot, and retreat timing?

## Scope guardrails

This correction does not add gear/mech hardpoints, multiple canvases, limb targeting, full mech simulation, backend, real PVP, or a full loot economy. It narrows the build surface, not the theatre loop.

The next version should preserve:

- real-time theatre fights;
- 15–30 second fights;
- victory resupply delay;
- loss repair/delay;
- retreat boundary;
- loot drops;
- pilot XP/level/skill acquisition;
- deterministic local prototype behaviour.
