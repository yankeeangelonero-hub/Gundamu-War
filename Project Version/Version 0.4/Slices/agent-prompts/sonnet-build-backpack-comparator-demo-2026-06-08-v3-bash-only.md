# Sonnet build packet v3 — bash-write only

The two previous print-mode runs failed because Claude tried to emit a huge response before writing files. For this run, do not read files and do not explain. Use Bash only to create the demo files. Your first action must be a Bash command that runs a Python script to write files. Do not paste file contents into chat.

Workdir: D:/Claude/Mech Bags. Branch: backpack-system-test.

Rules: no git commit/push/stage/reset/restore/clean/checkout/revert. Do not touch existing dual-layer files. Only create/edit these paths:
- experiments/backpack-comparator.html
- experiments/backpack-comparator/backpack-core.js
- experiments/backpack-comparator/backpack-check.cjs
- Project Version/Version 0.4/Slices/Slice 02 Specification.md only status ready->review if checks pass
- Project Version/Version 0.4/Slices/Implementation/Slice 02 Implementation.md
- Project Version/Version 0.4/Slices/Unit Tests/Slice 02 Unit Test.md
- Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/**
- Kanban.md only to mark Slice 02 Review if checks pass

Build a no-dependency backpack comparator demo:
- 6x5 grid, item palette, rotate, place, reject overlap/out-of-bounds.
- Items: Pulse Core, Power Conduit, Capacitor Cell, Thermal Sink, Beam Lance, Razor Saber Pair, Arc Rifle, Rail Javelin, Missile Hive, Reactive Plate, Prism Shield, Vector Thruster, Targeting Fin.
- Presets: Dawn Knife, Bastion Choir, Choir Breaker, Bad Lab Rig.
- Active adjacency preview + inactive/missing-neighbor notes.
- Seed input, deploy, event log, debrief.
- Pure deterministic JS core exports placement helpers, preview, simulate, presets.
- Node check script writes evidence: placement.json, adjacency-preview.md, determinism logs/diff note, debrief-comparison.md, comparison.md.
- Run `node experiments/backpack-comparator/backpack-check.cjs`.
- Write concise Vouse Implementation and Unit Test records.
- If checks pass, set Slice 02 spec status to review and Kanban card to Review.

Final response under 300 words. No code blocks. Say files created, command result, demo path, known gaps, final status.
