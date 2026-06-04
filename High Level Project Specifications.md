---
project: mech-bags
doc_type: high-level-spec
status: draft
updated: 2026-06-04
---

# High Level Project Specifications — Mech Bags

## Project statement

Mech Bags is a browser-based HTML prototype for a Backpack Battles-style async autobattler where players arrange shaped mech parts across five body-part bags, upgrade individual bag sizes, then watch 2D sprite battles resolve through a paused ATB animation queue.

## Primary actors

| Actor | Role |
|---|---|
| `Player` | Enters the browser prototype, buys/places parts, expands bags, launches battles, and reads results. |
| `Opponent Build Pool` | Supplies deterministic saved/prebuilt builds for async battles in Version 0.1. |
| `Battle Simulator` | Resolves builds into an ATB event sequence and battle result. |
| `Design Reviewer` | Uses the prototype and UI handoff to judge whether the bag layout, shop flow, and animation readability support the concept. |

## Major components

| Component | Responsibility |
|---|---|
| `Build Board` | Five independent body-part bag grids; item placement, rotation, adjacency preview. |
| `Shop and Run Loop` | Item offers, reroll/lock if included, gold, wins/losses, bag expansion cards. |
| `Item Definition System` | Shaped parts, stats, tags, adjacency rules, costs. |
| `ATB Battle Simulator` | Deterministic event queue, hit/damage resolution, pause-for-animation sequence. |
| `2D Battle Viewer` | Sprites, HP bars, attack animations, event log, speed/skip controls if scoped. |
| `Enemy Build Pool` | Static/prebuilt opponent builds matched by round. |
| `Run State Persistence` | Local browser state only if included; no backend. |

---

## Features (FEAT)

### FEAT-001 — Five-bag mech builder
Player can place shaped parts into Head, Torso, Back, Left Arm, and Right Arm bags with no body-part item restrictions. Each bag is an independent grid. Placement validity is determined only by geometry (shape, overlap, bounds).

### FEAT-002 — Body-part bag expansion
Player can buy upgrade cards that add cells to a specific named body-part bag. The choice of which bag to expand is a build decision. Expansion must visibly affect only the targeted bag.

### FEAT-003 — Backpack-style item synergies
Items provide adjacency and tag-based bonuses readable from their placement within a single bag. Effects are visible while building. Cross-bag adjacency is out of scope for Version 0.1.

### FEAT-004 — Shop-based run progression
Player advances through a short run by visiting a shop between rounds: buying, rerolling, and selling items, and optionally buying bag expansion upgrades. Gold is the resource. Rounds end in a battle against an opponent from the pool.

### FEAT-005 — ATB battle playback
Battles resolve as a deterministic queue: simulation time advances until the earliest ready attack event; time pauses; the weapon animation plays; the effect resolves (damage, status); time resumes until the next ready event. Only one primary attack animation plays at a time.

### FEAT-006 — 2D sprite readability
The battle viewer communicates attacks, hits/misses, blocks, HP changes, and key trigger events through 2D sprite animations, HP bars, event banners, and a combat log. No 3D required.

### FEAT-007 — Prototype enemy pool
Version 0.1 can fight prebuilt/saved opponent builds without networking. Enemy builds are matched to round number from a static pool. No backend required.

---

## Behaviour invariants (BEH)

These are checkable conditions that must hold throughout the prototype. They are not test cases — they are requirements the implementation is always expected to satisfy.

### BEH-001 — No anatomical restrictions
Any item that fits geometrically can be placed in any of the five bags. The system must not reject a beam rifle on Head or a reactor on Right Arm because of anatomy. Rejection must only happen for geometric reasons (overlap, out-of-bounds).

### BEH-002 — Bag expansion targets one bag only
Bag expansion must target a named body-part bag and visibly increase only that bag's available cell count. The other four bags must be unchanged after a single expansion card is applied.

### BEH-003 — Adjacency bonuses are in-bag only and visible
Adjacency bonuses must be explainable from visible item placement inside a single bag. The player must be able to see which items are causing a bonus without reading hidden state.

### BEH-004 — One attack animation at a time
Battle playback must show one primary ready-attack animation at a time. Simulation time must not advance during that animation. Concurrent attack animations competing for attention must not occur in Version 0.1.

### BEH-005 — Post-battle result is readable
After a battle, the player must be able to understand the main reason for win/loss from HP bars, the event log, and/or the battle report without inspecting simulation internals.

---

## Architecture constraints (ARC)

These constrain how the system is built. They apply across versions unless explicitly superseded.

### ARC-001 — Simulation and animation are separable
Simulation state and animation playback must be architecturally separable. Battles must be skippable and replayable from the same build/seed without re-running the simulation.

### ARC-002 — No backend dependency in Version 0.1
Version 0.1 stores opponent builds locally/statically. The prototype must not depend on backend matchmaking, accounts, or external APIs at any point during normal play.

### ARC-003 — Build board is five independent grids
The build board treats each body-part bag as an independent grid. Cross-bag adjacency bonus calculation is out of scope for Version 0.1.

### ARC-004 — Item definitions are data-driven
Item definitions (shape, stats, tags, adjacency rules, cost) must be stored as data rather than hard-coded into battle logic. Adding a new item should require only a data change, not a logic rewrite.

### ARC-005 — UI copy uses game terms, not engineering terms
UI copy, event banners, and battle reports must use prototype/game language. Do not use realistic engineering claims (e.g., "weapon overheated due to thermal load"). Prefer playful mechanical language (e.g., "Beam Rifle overheated!").

---

## Out of scope for Version 0.1

The following are explicitly excluded from the current prototype. They may be reconsidered in later versions.

- Real Gundam IP, names, factions, or licensed assets
- Limb HP, heat management, weight limits, ammo explosions
- Targeting specific body parts in combat
- Pilots, campaign mode
- Realistic hardware mounting constraints
- Item placement restrictions by body part
- Networking, accounts, persistent ladder, real async matchmaking
- 3D combat or rendering
- Production-grade art pipeline
- Mobile polish beyond basic responsive layout

---

## Design and UI requirements

Visual and UI requirements are maintained in the Design agent handoff:

`agent-handoffs/claude-design-ui-requirements.md`

Any agent working on UI must read that document before making visual decisions. The design output document (when produced) will live at:

`Research/UI Design Requirements.md`
