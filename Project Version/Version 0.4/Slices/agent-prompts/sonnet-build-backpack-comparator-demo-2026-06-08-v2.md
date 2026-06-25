# Sonnet build packet v2 — backpack comparator demo

Previous run failed before writing files because Claude attempted an overlong response after reading context. This run must be quiet: write files with tools, do not paste code or long logs into chat. Final response under 700 words.

Workdir: `D:/Claude/Mech Bags`
Branch: `backpack-system-test`

## Task

Build the ready Vouse slice `v0.4-slice-02 — backpack-system-comparator` as a small no-dependency web demo.

Read only these first, and do not print their contents:
- `Project Version/Version 0.4/Slices/Slice 02 Specification.md`
- `Research/Research Documents/design-spec-2026-06-08-seed-inspired-items-machines-skills-upgrades.md`
- `Research/Research Documents/test-brief-2026-06-08-comparable-backpack-system.md`

Do NOT read `experiments/dual-layer/sim.js` or existing large prototype files. Build a new clean comparator from the specs.

## Dirty repo rules

No commit, push, stage, reset, restore, checkout, revert, clean, or deletion. Do not touch existing dual-layer files or images. Do not edit High Level Spec, Roadmap, Version Log, User Stories, old docs, or research except this prompt if needed.

Allowed create/edit paths only:
- `experiments/backpack-comparator.html`
- `experiments/backpack-comparator/backpack-core.js`
- `experiments/backpack-comparator/backpack-check.cjs`
- `Project Version/Version 0.4/Slices/Slice 02 Specification.md` only for status `ready` -> `review` if build reaches review
- `Project Version/Version 0.4/Slices/Implementation/Slice 02 Implementation.md`
- `Project Version/Version 0.4/Slices/Unit Tests/Slice 02 Unit Test.md`
- `Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/**`
- `Kanban.md` only to mark Slice 02 Review if the build/checks pass

## Minimum demo

Implement:
- `6x5` grid.
- Palette items: Pulse Core, Power Conduit, Capacitor Cell, Thermal Sink, Beam Lance, Razor Saber Pair, Arc Rifle, Rail Javelin, Missile Hive, Reactive Plate, Prism Shield, Vector Thruster, Targeting Fin.
- Select, rotate, place; reject overlap/out-of-bounds.
- Preset buttons: Dawn Knife, Bastion Choir, Choir Breaker, Bad Lab Rig.
- Adjacency preview listing active bonuses and inactive/missing-neighbor notes.
- Seed input, deploy, event log, debrief.
- Pure deterministic core exported for Node: placement helpers, preview, simulate, presets.
- ATB-ish deterministic simulation sufficient to produce different readable outcomes for the presets.

## Required verification script

Create and run:

`node experiments/backpack-comparator/backpack-check.cjs`

It must write:
- `Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/placement.json`
- `Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/adjacency-preview.md`
- determinism paired logs/diff note under `.../determinism/`
- `.../debrief-comparison.md`
- `.../comparison.md`

## Vouse records

Write concise records:
- `Project Version/Version 0.4/Slices/Implementation/Slice 02 Implementation.md`
- `Project Version/Version 0.4/Slices/Unit Tests/Slice 02 Unit Test.md`

If checks pass, set Slice 02 spec status to `review`. Do not mark done.

## Final response

Final response must be concise and contain only:
- files changed/created
- command run + result
- demo path
- evidence paths
- known gaps
- final git status summary

Do not include code blocks longer than 20 lines. Do not paste full file contents or full logs.
