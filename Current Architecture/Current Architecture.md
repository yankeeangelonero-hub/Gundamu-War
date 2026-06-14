---
project: mech-bags
doc_type: architecture
version: "0.1"
status: as-built
updated: 2026-06-04
---

# Current Architecture — Mech Bags Version 0.1

> Historical, despite the folder name. This documents the superseded Mech Bags v0.1 browser
> prototype (as-built 2026-06-04), not the current build. The current architecture is the Godot
> v0.1 backpack engineering prototype (`godot_director_spike/` plus the M1 design at
> docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md); the JS prototype
> here is kept only as the deterministic-core reference to port. The sibling Actor Flows.md is
> the same era.

## As-built summary (2026-06-04)

Prototype is complete. Entry point: `prototype/index.html` (no server required).

| File | Role |
|---|---|
| `prototype/game-core.js` | Data + simulation module. UMD pattern (works in Node and browser). No DOM. |
| `prototype/app.js` | DOM controller. Manages run state, build board, shop, battle viewer. |
| `prototype/styles.css` | All styling and animations. |
| `prototype/index.html` | Shell; loads CSS then scripts. |
| `prototype/tests/core-tests.js` | 66 Node.js assertions (all pass). |

No dependencies installed. No build step. No localStorage. No backend.

## Overview

Version 0.1 is a single-page browser prototype. All logic runs client-side in plain HTML/CSS/JavaScript. There is no backend, no server, and no persistent storage beyond optional browser `localStorage`.

The system has three conceptually separated layers:

1. **Data layer** — item definitions, enemy build pool, run state
2. **Simulation layer** — ATB event computation (deterministic, no rendering)
3. **Presentation layer** — build board UI, shop UI, battle viewer animation

These layers communicate through plain JavaScript function calls and shared state objects. The simulation layer must not depend on the presentation layer (ARC-001).

---

## Component map

### Build Board

Responsibility: Render five independent body-part bag grids. Accept item placement, rotation, and removal. Compute and display same-bag adjacency bonuses.

- One grid per bag: Head, Torso, Back, Left Arm, Right Arm.
- Grid dimensions are variable per bag (expanded via bag expansion cards).
- Item placement validity: geometry and overlap only. No anatomy check (BEH-001).
- Adjacency bonus display: reads from Item Definition System based on current placements (BEH-003).

Inputs: Player drag/drop/rotate actions, expansion events.
Outputs: Updated bag state (placed items with coordinates), active adjacency bonuses list.

---

### Shop and Run Loop

Responsibility: Manage run progression. Generate shop offers. Handle gold, round counter, wins/losses. Accept player purchases.

- Shop offers a mixture of item cards and body expansion upgrade cards.
- Expansion cards name the target bag explicitly (e.g. "Head Expansion — +1 cell to Head").
- Gold is deducted on purchase. Insufficient gold prevents purchase.
- Round advances after each battle result is read.
- Win/loss thresholds end the run.

Inputs: Player buy/reroll/sell actions, battle result events.
Outputs: Updated run state (gold, round, wins, losses, current shop offers).

---

### Item Definition System

Responsibility: Data store for all item definitions. No runtime logic in the definitions themselves.

Each item definition contains:
- `id` — unique string
- `name` — display name
- `shape` — array of [row, col] offsets from anchor, defining the item's grid footprint
- `stats` — damage, speed, tags, and other numeric values
- `adjacency_rules` — conditions under which a bonus activates (tag match, position, etc.)
- `cost` — gold cost in shop

Items are plain data objects. Adding a new item requires only a new data entry (ARC-004).

---

### ATB Battle Simulator

Responsibility: Take two build states (player + enemy) and a seed, produce a deterministic ordered list of attack events, and return the battle result.

Process:
1. Initialise ATB timers for each item with an attack stat, based on item speed and seed.
2. Advance simulation time to the smallest next-ready timer.
3. Emit an attack event: `{ time, attacker, bag, item, target, damage, effects }`.
4. Reduce the target's HP.
5. Repeat until one side reaches 0 HP or time limit.
6. Return: event list, winner, final HP values.

Constraints:
- Same seed + same builds = byte-equal event list (ARC-001).
- No rendering, DOM, or animation calls inside the simulator.
- Simulator runs synchronously; the battle viewer drives timing externally.

---

### 2D Battle Viewer

Responsibility: Read the pre-computed event list from the ATB Battle Simulator and display it as a timed animation sequence.

Playback loop:
1. Advance display time to the next event's `time` value.
2. Pause display time.
3. Play the weapon animation for the event's bag source (anchored to the body-part origin).
4. Update HP bars and append the event to the combat log.
5. Resume display time after animation completes.
6. If battle is ended (HP = 0), show battle result screen.

Guarantees:
- Only one primary attack animation active at a time (BEH-004).
- HP bars reflect resolved state after each event.
- Event banner names the bag source: "Head Beam Rifle fires!" (ARC-005).

Speed controls (if scoped): fast-forward or skip to result without re-running simulation.

---

### Enemy Build Pool

Responsibility: Provide static prebuilt opponent builds indexed by round number.

Format: Array of build objects, each matching the player's build state schema.

Round matching: enemy pool entry = `pool[roundIndex % pool.length]` or similar simple mapping.

No backend calls. Pool is bundled as a JavaScript data file (ARC-002).

---

### Run State Persistence

Scope: Optional in Version 0.1. If implemented, uses browser `localStorage` only. No backend.

State to persist: current run gold, round, wins, losses, player build (placed items per bag with positions).

This component is gated; Version 0.1 can ship without it if the run is always reset on page reload.

---

## Data flow summary

```
Player Action
    ↓
Build Board / Shop UI (Presentation)
    ↓
Run State (Data)
    ↓
ATB Battle Simulator (Simulation)  ←  Seed + two builds
    ↓
Event List (Data)
    ↓
2D Battle Viewer (Presentation)    →  HP updates, log, result screen
```

---

## Technology decisions for Version 0.1

| Decision | Choice | Rationale |
|---|---|---|
| Language | Plain HTML/CSS/JavaScript | No build step; opens as a file in a browser |
| Renderer | DOM + CSS animations + Web Animations API | No canvas; sufficient for 2D sprites and grid UI |
| Framework | None | Keeps entry barrier low; no npm install |
| Storage | None (page refresh resets run) | localStorage deferred per owner decision |
| Art | CSS-drawn placeholder mech sprites | Production art pipeline is out of scope |
| Module system | UMD in game-core.js | Single pattern supports both Node tests and browser |

---

## Architecture constraints in force

See `High Level Project Specifications.md` for the full ARC list.

| Constraint | Summary |
|---|---|
| ARC-001 | Simulation and animation must be separable |
| ARC-002 | No backend in Version 0.1 |
| ARC-003 | Each bag is an independent grid (no cross-bag adjacency) |
| ARC-004 | Item definitions are data-driven |
| ARC-005 | UI copy uses game terms, not engineering terms |
