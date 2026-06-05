# Sonnet Task — Mech Bags V0.2 single-canvas real-time theatre implementation

You are Claude Code Sonnet running inside `D:/Claude/Mech Bags`.

Xuanyue changed the V0.2 base build surface:

> Dumb down the 5 bags concept. Instead have 1 big canvas and small bags that we can buy each round, exactly similar to Backpack Battles, then iterate from that base.

Hermes killed the previous real-time theatre worker because its prompt assumed the old five-body-part board. Your task is to implement from the updated docs.

## Ground rules

- This is a focused V0.2 prototype iteration.
- Do not commit, push, or run destructive git commands.
- Static no-build browser prototype only.
- Do not add backend, accounts, real async PVP, full warfront map, gear surface, multiple pilots, deep skill tree, live LLM narration, or production art.
- Preserve touch/mobile placement usability from previous fixes: tap select, rotate, move, visible invalid feedback.
- If partially edited files from the killed worker exist, inspect them and either integrate or overwrite carefully; do not assume the current code is clean.

## Required reading before editing

Read:
- `Project Version/Version 0.2/Version 0_2 Project Specifications.md`
- `Research/Research Documents/concept-handoff-2026-06-05-single-canvas-buyable-bags.md`
- `Research/Research Documents/concept-handoff-2026-06-05-real-time-theatre-loop.md`
- `Research/User Journeys.md` Journey 12 and Journey 13
- `agent-handoffs/hermes-v0-2-essential-sortie-loop-verification-note.md`
- `prototype/index.html`
- `prototype/styles.css`
- `prototype/app.js`
- `prototype/game-core.js`
- `prototype/tests/core-tests.js`

## Required product changes

### A. Replace five body-part boards with one canvas

Implement a Backpack Battles-like base:

1. One main build canvas/workbench.
2. Player starts with a small owned area.
3. Shop can sell small bag pieces / canvas expansions.
4. Buying a bag piece adds owned cells or a small shape to the canvas.
5. Items can be placed anywhere on owned canvas cells if geometry permits.
6. Placement rejects only:
   - overlap,
   - out-of-bounds,
   - unowned canvas cells.
7. No Head/Torso/Back/Left Arm/Right Arm body-part boards as the active V0.2 build surface.
8. Keep mech/war flavor through copy/art direction/items/pilot/theatre, not through five boards.

You may retain old constants/functions internally only if refactored cleanly and not user-facing as five separate boards.

### B. Real-time theatre loop

Implement or preserve this loop:

1. Player customizes canvas build.
2. Player clicks Deploy.
3. Suit enters active theatre state.
4. Theatre repeatedly schedules fights against fixed pool of 10 enemy builds.
5. Each fight takes 15–30 seconds in normal runtime.
6. Victory → 5 seconds resupply downtime.
7. Loss → 15 seconds repair/delay lockout where suit cannot fight.
8. Loop continues automatically until retreat.
9. Spectate is optional; leaving spectate does not stop theatre progress.
10. Retreat ends active sortie and claims accumulated results.
11. Player returns to workshop, modifies canvas/build, redeploys.

For tests, use a virtual-time/tick abstraction so tests do not wait real seconds.

### C. Loot + pilot growth

Retreat summary must show:
- fights completed;
- wins/losses;
- loot drops;
- pilot XP and level progress;
- pilot condition;
- skill acquisition/progress.

Keep it small:
- one pilot;
- one or two visible skill tracks/acquisitions;
- simple deterministic loot;
- no deep skill tree or loot economy.

## Tests required

Update/add tests for:
- single canvas owned-cell placement rules;
- bag piece purchase expands owned cells;
- placement invalid on unowned cells;
- rotation/move still works;
- enemy pool has 10 valid builds for the new canvas model;
- theatre scheduler does not resolve all fights instantly;
- fight duration is in 15–30 second range in runtime config;
- victory downtime = 5 seconds;
- loss downtime = 15 seconds;
- loop continues until retreat;
- retreat claims accumulated results only;
- loot deterministic;
- pilot XP/level/skills deterministic and visible in state;
- existing simulation determinism still passes.

Run:

```bash
node prototype/tests/core-tests.js
```

## Browser smoke required

Run a browser/manual smoke if possible:
- canvas visible;
- buy bag piece and see canvas expand;
- place/rotate/move item on canvas;
- invalid placement on unowned cell shows feedback;
- deploy;
- observe active fight countdown/state;
- observe victory resupply or loss repair delay;
- leave spectate and confirm theatre continues;
- retreat after at least one completed fight;
- confirm loot + XP/skill summary;
- return to workshop and redeploy.

Capture screenshots under:

`agent-handoffs/v0-2-single-canvas-theatre-screenshots/`

## Report required

Write:

`agent-handoffs/sonnet-v0-2-single-canvas-theatre-report.md`

Report must include:
1. Files changed.
2. How five-body-part boards were replaced by single canvas + buyable bag pieces.
3. Real-time theatre timing behavior.
4. Loot behavior.
5. Pilot XP/level/skills behavior.
6. Verification results.
7. Browser smoke results and screenshot list.
8. Remaining risks / recommended next pass.
