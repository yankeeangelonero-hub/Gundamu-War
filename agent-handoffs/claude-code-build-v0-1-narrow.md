# Claude Code Continuation — Implement Minimal Playable Mech Bags 0.1 Now

The prior broad Vouse build prompt spent too long reading specs and produced no prototype files. Continue from the project root `D:/Claude/Mech Bags`, but now execute this narrow implementation task immediately.

## Deliverable

Create a playable no-dependency browser prototype under `prototype/`:

- `prototype/index.html` openable directly with a browser (no server required)
- `prototype/styles.css`
- `prototype/game-core.js` usable in browser and Node (`module.exports` when available)
- `prototype/app.js`
- `prototype/tests/core-tests.js`
- `prototype/README.md`

Also write/update only these Vouse/docs artifacts after implementation:

- `agent-handoffs/claude-code-build-v0-1-report.md`
- `Project Version/Version 0.1/Version 0_1 Project Specifications.md` to record locked decisions as resolved
- `Current Architecture/Current Architecture.md` concise as-built update
- `Kanban.md` honest status update
- `Project Version/Version 0.1/Slices/Implementation/Slice-01-through-07-Implementation.md`
- `Project Version/Version 0.1/Slices/Unit Tests/Slice-01-through-07-Unit-Test.md`

Do not spend more time reading every slice file. Use the contract below.

## Locked contract

Build Backpack Battles-like five-bag mech prototype:

- Bags: Head, Torso, Back, Left Arm, Right Arm.
- Items can go in any bag. No anatomy restrictions. Reject placement only for geometry/overlap/bounds.
- Same-bag adjacency only.
- Body expansion cards expand one targeted bag only.
- Run ends at 5 wins or 3 losses.
- No required persistence/localStorage.
- Include Skip Battle. Defer speed multiplier.
- Economy: start 10 gold; win +6; loss +4; reroll 1; sell floor(cost/2) if sell exists.
- 12 items: Machine Gun, Beam Rifle, Missile Pod, Beam Saber, Heavy Cannon, Battery, Ammo Box, Sensor, Targeting Chip, Booster, Armor Plate, Shield.
- 6 enemies: Starter Balanced, Missile Backpack, Beam Head Goblin, Shield Turtle, Saber Rush, Heavy Cannon Glass Cannon.
- Beam Head Goblin must demonstrate Beam Rifle in Head.
- ATB simulation: deterministic event queue from builds + seed. Advance time to next ready attack; animation layer plays one attack at a time. Simulation and animation separable.

## UI minimum

- Display shop, gold, wins/losses, round.
- Five grids visibly named and arranged roughly like a mech.
- Click/select item in shop, click grid cell to place; rotate button or keyboard `R`; drag/drop optional but not required if click placement works clearly.
- Show item shapes, placement preview/feedback, active synergies.
- Start battle button.
- Battle view with two 2D/CSS mech sprites, HP bars, current event, combat log, Skip Battle.
- Result screen after battle and run end.

## Core tests required

`node prototype/tests/core-tests.js` must pass and cover:

1. Beam Rifle can be placed in Head.
2. Overlap/bounds placement rejected.
3. Same build + same seed gives same ATB event sequence.
4. Expanding Head changes only Head cells.
5. Run threshold is 5 wins or 3 losses.
6. Enemy pool includes Beam Head Goblin with Beam Rifle in Head.

## Final report

Run the node test. Then write `agent-handoffs/claude-code-build-v0-1-report.md` with files changed, test command/result, prototype entry point, slice status, known gaps.

Do not install dependencies. Do not commit or push. Start writing files now.
