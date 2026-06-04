---
project: mech-bags
doc_type: version-spec
version: "0.1"
status: draft
updated: 2026-06-04
---

# Version 0.1 Project Specifications — Mech Bags

## Version goal

A player can complete a short browser prototype run: buy shaped items and body-part expansions, arrange them across five unrestricted bags, launch battles against prebuilt enemy builds, and watch deterministic ATB sprite playback until a win/loss result.

## Scope boundary

Version 0.1 is a browser/HTML prototype. No backend. No accounts. No real matchmaking. All game state lives in the browser tab.

### In scope

| Feature | Ref |
|---|---|
| Five-bag mech builder (Head, Torso, Back, Left Arm, Right Arm) | FEAT-001 |
| Body-part bag expansion cards | FEAT-002 |
| Backpack-style item synergies (same-bag adjacency only) | FEAT-003 |
| Shop-based run progression | FEAT-004 |
| ATB battle playback (one animation at a time) | FEAT-005 |
| 2D sprite battle viewer | FEAT-006 |
| Static prebuilt enemy pool | FEAT-007 |

### Explicitly out of scope

- Real Gundam IP, licensed assets
- Limb HP, heat, weight, ammo explosions, targeting body parts
- Item placement restrictions by body part (BEH-001 must hold)
- Networking, accounts, real async matchmaking
- 3D combat
- Production-grade art
- Cross-bag adjacency bonuses (ARC-003)
- Persistent server-side state

## Slices

Version 0.1 is delivered through 7 slices. Each slice must be independently demoable and deliver a visible, checkable outcome. Slices build on each other roughly in order.

| # | Title | Depends on | Status |
|---|---|---|---|
| 01 | Static five-bag board shell | — | Verified |
| 02 | Item placement and rotation | 01 | Verified |
| 03 | Shop and body expansion cards | 01 | Verified |
| 04 | Data-driven item stats and adjacency preview | 02 | Verified |
| 05 | Deterministic ATB simulator | 04 | Verified |
| 06 | 2D battle viewer and paused animation playback | 05 | Verified (needs browser smoke) |
| 07 | Short run loop with enemy pool | 03, 06 | Verified (needs browser smoke) |

Full slice specs are in `Slices/`.

## Acceptance criteria for Version 0.1

Version 0.1 is complete when all of the following are true:

1. A tester can open a single HTML file in a browser (no server required) and see the five named bag grids.
2. The tester can place shaped items into any bag and rotate them. Placement is rejected for geometry/overlap only.
3. The tester can buy at least one body expansion card that increases only the targeted bag.
4. Item adjacency bonuses activate and are visible on the build board.
5. The tester can launch a battle. The battle runs without a network call.
6. The battle viewer shows one attack animation at a time with HP bar updates and a combat log.
7. The run ends with a win or loss screen after reaching the win/loss threshold.
8. Re-running the same battle with the same build and seed produces the same event sequence.

## Behaviour invariants active in Version 0.1

All BEH-NNN entries from `High Level Project Specifications.md` are in force:

- **BEH-001** — No anatomical restrictions on item placement
- **BEH-002** — Bag expansion targets one named bag only
- **BEH-003** — Adjacency bonuses visible from in-bag placement only
- **BEH-004** — One primary attack animation at a time
- **BEH-005** — Post-battle result explains win/loss to the player

## Architecture constraints active in Version 0.1

All ARC-NNN entries from `High Level Project Specifications.md` are in force:

- **ARC-001** — Simulation and animation are separable
- **ARC-002** — No backend dependency
- **ARC-003** — Build board is five independent grids
- **ARC-004** — Item definitions are data-driven
- **ARC-005** — UI copy uses game terms

## Design and UI reference

Visual and UI requirements are in:
`agent-handoffs/claude-design-ui-requirements.md`

The design output document (when produced by the Design agent) will be at:
`Research/UI Design Requirements.md`

Do not make significant visual decisions without consulting the design handoff.

## Open decisions — RESOLVED 2026-06-04

All decisions resolved by owner (Xuanyue) in build handoff. Implemented as specified.

| Decision | Resolution |
|---|---|
| Win/loss thresholds | **5 wins or 3 losses** — `ECONOMY.WIN_THRESHOLD=5`, `ECONOMY.LOSS_THRESHOLD=3` |
| localStorage persistence | **Deferred** — page refresh resets the run. No localStorage in 0.1. |
| Speed/skip controls | **Skip Battle included; speed multiplier deferred.** |
| Starting gold / rewards | **Start 10g; win +6g; loss +4g; reroll 1g; sell floor(cost/2)** |
| First item set | **12 items:** Machine Gun, Beam Rifle, Missile Pod, Beam Saber, Heavy Cannon, Battery, Ammo Box, Sensor, Targeting Chip, Booster, Armor Plate, Shield |
| Enemy pool | **6 builds:** Starter Balanced, Missile Backpack, Beam Head Goblin, Shield Turtle, Saber Rush, Heavy Cannon Glass Cannon |
