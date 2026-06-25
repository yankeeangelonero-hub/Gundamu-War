# Sonnet build packet — v0.4-slice-02 backpack-system-comparator demo

You are Claude Code Sonnet acting as Builder for the Vouse project at `D:/Claude/Mech Bags` on branch `backpack-system-test`.

## Mission

Build a small, no-dependency web demo for `v0.4-slice-02 — backpack-system-comparator`: a single-canvas Backpack Battles-style mecha build surface with placement, rotation, adjacency preview, deterministic combat, and placement-cause debrief.

This is a branch-local comparator demo. Do not pivot the canonical project direction. Do not commit or push.

## Read first

Read these files before editing:

1. `CLAUDE.md`
2. `Project Version/Version 0.4/Slices/Slice 02 Specification.md`
3. `Research/Research Documents/test-brief-2026-06-08-comparable-backpack-system.md`
4. `Research/Research Documents/design-spec-2026-06-08-seed-inspired-items-machines-skills-upgrades.md`
5. `Project Version/Version 0.4/Version 0_4 Project Specifications.md`
6. `Current Architecture/Current Architecture.md` if present

## Dirty-repo guardrails

The repo is already dirty with parked dual-layer/Vouse work. Do not clean, reset, restore, checkout, revert, stage, commit, push, or delete anything.

Do not touch existing parked files except the explicitly allowed paths below. In particular, do not modify existing dual-layer prototype files or images:

- `experiments/dual-layer-deck-combat.html`
- `experiments/dual-layer/**`
- `dual-layer-*.png`
- `design_dump.bin`
- `design_handoff/**`
- any docs under `docs/wishlist/**` or `docs/pilot-and-war-front-high-level-spec-and-work-map.md`
- `High Level Project Specifications.md`, `Roadmap.md`, `Version Log.md`, `Research/User Journeys.md`, `User Stories/**`, unless you discover a hard Vouse routing blocker — in that case stop and write a BLOCKED note instead of editing them.

Allowed paths to create/edit:

- `experiments/backpack-comparator.html`
- `experiments/backpack-comparator/**`
- `Project Version/Version 0.4/Slices/Slice 02 Specification.md` only for status transitions required by Vouse build mode (`ready` -> `in-progress` -> `review`) and a small revision note if needed
- `Project Version/Version 0.4/Slices/Implementation/Slice 02 Implementation.md`
- `Project Version/Version 0.4/Slices/Unit Tests/Slice 02 Unit Test.md`
- `Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/**`
- `Current Architecture/Current Architecture.md` only if you add an as-built section for the branch-local comparator demo
- `Kanban.md` only if you update the slice card from Ready to Review after build/verification
- this prompt file only if you need to append a brief execution note

## Demo requirements

Build the smallest working demo that satisfies the slice acceptance checks:

### Surface

- Single `6x5` backpack canvas.
- Item palette using the design spec's Aster Frame starter library. Implement 12–14 items if feasible; minimum viable: Pulse Core, Power Conduit, Capacitor Cell, Thermal Sink, Beam Lance, Razor Saber Pair, Arc Rifle, Rail Javelin, Missile Hive, Reactive Plate, Prism Shield, Vector Thruster, Targeting Fin.
- Select item, rotate, place on grid.
- Reject overlap and out-of-bounds placement without changing board state.
- Move/remove item if cheap; otherwise provide reset and preset buttons.
- Show active adjacency preview before deploy: connected conduits, adjacent reactor/beam/sensor/shield interactions, missing desired neighbor notes.
- Presets: Dawn Knife, Bastion Choir, Choir Breaker, Bad Lab Rig.
- Fixed rival build is acceptable; if time permits include one selector.
- Seed input.
- Deploy button.
- Event log.
- Debrief panel.

### Simulation

Implement a pure deterministic simulation core. Prefer a shared JS module under `experiments/backpack-comparator/` plus the HTML importing it, but a single HTML is acceptable if tests can import the core or run through a Node-friendly file.

Rules:

- Input: `{playerBag, rivalBag, seed}`.
- No DOM reads, wall-clock time, animation callbacks, or `Math.random` inside simulation.
- Derive active adjacency, conduit connectivity, power pressure, heat, timers, and deterministic tie-breaks.
- ATB-style item timers: next event is smallest timestamp; same-time tie-break by sensor priority / anchor row / anchor column / item id.
- Log item fire, hit, block/shield, adjacency bonus, power starvation, heat skip, range failure, and tie-break when relevant.
- Stop on HP <= 0 or max event count.
- Emit normalized event list and structured debrief facts.

### Debrief

The debrief should cite 2–4 concrete causes from structured facts, e.g.:

- `Beam Lance fired with Core conduit cooldown bonus.`
- `Prism Shield reduced Beam damage but overloaded.`
- `Arc Rifle starved for power 3 times.`
- `Capacitor Cell had no adjacent Beam item; no bonus applied.`
- `Rail Javelin pierced armor block.`

### Verification

Create a Node test/check script, e.g. `experiments/backpack-comparator/backpack-check.cjs`, that writes evidence under:

`Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/`

It must cover:

1. Placement dump with valid rotated item and rejected overlap/out-of-bounds.
2. Adjacency preview markdown or JSON for active and inactive bonuses.
3. Determinism: same `{bag, rival, seed}` run twice yields byte-identical normalized logs.
4. Debrief comparison for Dawn Knife, Bastion Choir, Choir Breaker, Bad Lab Rig.
5. Comparison note against dual-layer prototype using current evidence, not a final product pivot.

Run the check script and record command/output.

## Vouse records

After building and running checks, write:

- `Project Version/Version 0.4/Slices/Implementation/Slice 02 Implementation.md`
- `Project Version/Version 0.4/Slices/Unit Tests/Slice 02 Unit Test.md`

Use Vouse style: frontmatter, what was built, key decisions, deviations, files changed, verification log, per-AC results, known gaps.

If all ACs pass, set implementation/unit-test status accordingly and leave the slice spec in `review`. If something is incomplete, be honest: status should reflect gaps.

## Final response required

When done, print:

- files changed/created
- commands run and pass/fail
- demo path
- evidence paths
- known gaps
- final `git status --short`

If blocked by a spec contradiction or an invariant/routing issue, stop, do not improvise, and write a BLOCKED report under `Project Version/Version 0.4/Slices/Implementation/Slice 02 Implementation.md` if appropriate.
