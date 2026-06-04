# Claude Code Handoff — Build and Verify Mech Bags Version 0.1

Date: 2026-06-04
Owner: Xuanyue
Target root: `D:/Claude/Mech Bags`

## Mission

Build the playable Mech Bags Version 0.1 prototype using the repo-local Vouse suite/specs. You are the implementation worker; Hermes/Tifa is the orchestrator and will independently test after you finish.

Read these first, in order:

1. `CLAUDE.md`
2. `High Level Project Specifications.md`
3. `Project Version/Version 0.1/Version 0_1 Project Specifications.md`
4. all 7 slice specs under `Project Version/Version 0.1/Slices/`
5. `agent-handoffs/claude-design-ui-requirements.md`
6. `Research/flows/run-loop-flow.md`
7. `Research/flows/atb-battle-flow.md`

Use the Vouse slice lifecycle discipline as you work: treat the 7 slice specs as the build contract, update implementation records and unit test records, update Current Architecture, and update Kanban statuses. If installed Claude Code/Vouse skills are available, invoke them naturally. If not, reproduce the Vouse outputs faithfully.

## Locked owner decisions

Xuanyue approved these 0.1 decisions. Patch the Version 0.1 spec / relevant docs as needed so they are no longer listed as unresolved.

1. Run threshold: `5 wins or 3 losses` ends the run.
2. Persistence: no required localStorage in 0.1; a page refresh may reset the run. Optional debug JSON export/import only if cheap, but do not let it delay the build.
3. Battle controls: include `Skip Battle`; defer speed multiplier unless trivial.
4. Economy: starting gold `10`; win reward `+6`; loss reward `+4`; reroll cost `1`; sell returns `floor(cost / 2)` if sell is implemented.
5. First item set: exactly these 12 core items for 0.1 unless a spec conflict requires a parent change proposal:
   - Machine Gun
   - Beam Rifle
   - Missile Pod
   - Beam Saber
   - Heavy Cannon
   - Battery
   - Ammo Box
   - Sensor
   - Targeting Chip
   - Booster
   - Armor Plate
   - Shield
6. Enemy pool: 6 prebuilt enemies:
   - Starter Balanced
   - Missile Backpack
   - Beam Head Goblin
   - Shield Turtle
   - Saber Rush
   - Heavy Cannon Glass Cannon

The `Beam Head Goblin` enemy is important: it must visibly demonstrate that a beam rifle can be placed in the Head bag. No anatomy restrictions.

## Implementation constraints

- Build a browser/HTML prototype. Prefer plain HTML/CSS/JavaScript with no build step and no dependencies.
- The main playable file should be openable directly as `prototype/index.html` without requiring a server.
- Do not use real Gundam IP or licensed assets.
- Use 2D CSS/HTML placeholder sprites/effects; no 3D.
- No backend, accounts, real matchmaking, or network calls.
- No localStorage requirement.
- No body-part item restrictions. Placement rejects geometry/overlap/bounds only.
- Same-bag adjacency only. No cross-bag adjacency.
- Keep simulation and animation separable. The deterministic simulator should be callable without DOM animation.
- Include a deterministic seeded battle path so re-running the same battle with the same builds and seed produces the same event sequence.

## Recommended code shape

Avoid an overbuilt framework. A good minimal structure:

- `prototype/index.html` — single playable page.
- `prototype/styles.css` — all styling/effects.
- `prototype/game-core.js` — data definitions, shape rotation, placement validation, adjacency calculation, economy, enemy pool, deterministic ATB simulation. Make this usable both in browser and Node tests (UMD/CommonJS export pattern is fine).
- `prototype/app.js` — DOM/UI controller, drag/drop/click placement, shop/run state, battle playback.
- `prototype/tests/core-tests.js` — Node-based deterministic tests for core logic.
- Optional: `prototype/README.md` — how to open/test.

If you choose a different structure, keep it equally simple and explain why in the Implementation Record.

## Minimal gameplay requirements

### Build/shop

- Show five named bags: Head, Torso, Back, Left Arm, Right Arm.
- Each bag is an independent grid with uneven shapes/sizes.
- Items can be placed in any bag if the shape fits.
- Items can rotate.
- Show/preview active adjacency bonuses within a bag.
- Shop offers item cards and body expansion cards.
- Bag expansion cards target one named bag and visibly add space only to that bag.
- Show gold, wins, losses, round, reroll button, battle button.

### Items

Implement the 12 locked items with readable shapes/costs/stats/synergies. Use the recommendation if no better balance is obvious:

- Machine Gun: fast basic weapon; adjacent Ammo Box adds shot.
- Beam Rifle: medium beam weapon; adjacent Battery reduces charge time.
- Missile Pod: burst weapon; adjacent Sensor improves accuracy; 2 volleys.
- Beam Saber: melee/simple high accuracy; adjacent Booster reduces charge time.
- Heavy Cannon: slow big hit; adjacent Sensor improves accuracy.
- Battery: supports adjacent beam weapons.
- Ammo Box: supports adjacent ballistic/missile weapons.
- Sensor: adjacent weapon accuracy.
- Targeting Chip: adjacent weapon crit chance.
- Booster: melee speed and small dodge/global speed if simple.
- Armor Plate: max HP/armor; buffs adjacent Shield.
- Shield: periodic block.

### Battle / ATB

- Battle starts from current player build vs selected prebuilt enemy.
- Event-driven ATB: advance simulation time until next weapon ready; pause for that weapon's animation; resolve; resume.
- One primary attack animation at a time.
- Animations originate from the bag/body anchor (`Head Beam Rifle`, `Back Missile Pod`, etc.).
- HP bars update; event log names bag + item, e.g. `Head Beam Rifle fires`.
- Include `Skip Battle` to instantly resolve and show result/report.
- Battle result advances the run: win +6 gold, loss +4 gold, run ends at 5 wins or 3 losses.

### Enemy builds

Implement the 6 locked prebuilt enemies. They do not need perfect balance, but they must be valid builds under the same placement rules. `Beam Head Goblin` must place Beam Rifle in Head with Battery/Targeting Chip support if geometrically possible.

## Vouse documentation outputs required

Before finishing, write/update:

- Implementation Records under `Project Version/Version 0.1/Slices/Implementation/` for the implemented slices. If you implement all 7 in one pass, create one record per slice or a clearly cross-referenced combined record that still maps files changed and architecture updates to each slice.
- Unit Test Records under `Project Version/Version 0.1/Slices/Unit Tests/` with chronological logs/evidence for acceptance checks.
- `Current Architecture/Current Architecture.md` to describe as-built prototype structure.
- `Current Architecture/Actor Flows.md` if flow steps became concrete.
- `Kanban.md` to show implemented/verified statuses honestly.
- `Project Version/Version 0.1/Version 0_1 Project Specifications.md` to resolve the six approved decisions.
- `agent-handoffs/claude-code-build-v0-1-report.md` as your final report.

Do not mark slices `Done` if your verification is incomplete. `review`/`verified` is acceptable; be honest.

## Verification requirements for you

Run these at minimum:

1. Node test command for core deterministic logic, e.g. `node prototype/tests/core-tests.js`.
2. Verify `prototype/index.html` exists and can be opened without build tooling.
3. Verify no network/backend dependency exists.
4. Verify deterministic replay: same build + same seed gives same ATB event sequence.
5. Verify placement allows Beam Rifle in Head and rejects only geometry/overlap/bounds.
6. Verify bag expansion changes only the targeted bag.
7. Verify run threshold: 5 wins or 3 losses.

If you cannot run browser automation yourself, write a manual browser-smoke checklist in the Unit Test Record. Hermes/Tifa will perform browser smoke after your run.

## Final report requirements

Write `agent-handoffs/claude-code-build-v0-1-report.md` with:

- files created/changed
- prototype entry point
- exact commands run and results
- status of each of the 7 slices
- unresolved issues/known gaps
- whether Vouse skills were actually available/invoked or whether you reproduced the workflow from docs
- no secrets; no commits/pushes

Do not commit, push, or install dependencies unless absolutely necessary. If you believe dependency install is necessary, stop and record why instead of doing it.
