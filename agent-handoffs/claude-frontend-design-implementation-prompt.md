# Claude Code Task — Mech Bags frontend design implementation pass

You are Claude Code running inside `D:/Claude/Mech Bags`.

Xuanyue asked: “Ask Claude to design and implement using frontend design skill.”

## Ground rules

- This is implementation work on the existing browser prototype, not a new app/repo.
- Target prototype files live under `prototype/`.
- Do not commit, push, delete screenshots, or alter unrelated project scaffolding.
- Preserve the gameplay/product contract:
  - Backpack Battles-style five-bag mech builder.
  - Five independent body-part bags: Head, Torso, Back, Left Arm, Right Arm.
  - Item placement is unrestricted by anatomy; a Beam Rifle in Head remains valid.
  - Placement validation is geometry/overlap/out-of-bounds only.
  - Keep existing deterministic ATB simulator, shop, expansion, adjacency, battle, run-clear/run-over behavior.
  - No backend/network/accounts/licensed Gundam assets.
- Maintain a lightweight no-dependency static browser prototype unless there is a strong reason otherwise.
- Record what changed and any remaining issues in a handoff report at `agent-handoffs/claude-frontend-design-implementation-report.md`.

## Required project reading before editing

Read at least:
- `Readme.md`
- `Kanban.md`
- `prototype/README.md`
- `prototype/index.html`
- `prototype/styles.css`
- `prototype/app.js`
- `prototype/game-core.js`
- the recent Opus/playtest handoff if useful: `agent-handoffs/opus-playtest-visual-analysis-report.md`

## Use this frontend design skill guidance

Apply a distinctive, production-grade frontend design pass. Do not produce generic AI-purple-gradient UI. Pick a clear visual direction and execute it with precision.

Suggested direction for Mech Bags:
- “tactical garage / diecast mech kit / armored workbench” — industrial, toy-like, chunky, readable, energetic.
- UI should feel like arranging physical mech modules on a maintenance table before a combat test.
- Strong surface hierarchy, crisp panels, readable body-part grids, satisfying item cards, and clear battle telemetry.
- Typography should be characterful and game-like if web-safe/imported safely; avoid default Arial/Inter/Roboto/system-only blandness where possible. If using Google Fonts, ensure the page still degrades acceptably offline; no runtime build step.
- Use CSS variables for palette/type/elevation.
- Use purposeful motion: selection, hover preview, adjacency glow, battle event pulse, result overlay, run status.
- Add contextual details: grid texture, rivets/bolts, warning stripes, schematic labels, metallic panels, energy accents, silhouette composition.
- Keep it playable, not just pretty. Clarity beats decoration.

## Implementation expectations

1. Inspect the current UI and code contracts before modifying.
2. Design and implement the visual pass in actual files, mainly `prototype/styles.css` and HTML structure only where needed. Touch JS only if necessary for better state classes/labels/accessibility and without changing gameplay rules.
3. Improve responsiveness enough that desktop is the main target but narrow screens remain usable.
4. Preserve accessibility basics: contrast, focus states, button affordances, readable text, no motion that blocks play.
5. Do not weaken or remove tests.
6. Run verification:
   - `node prototype/tests/core-tests.js`
   - If possible, inspect/render in a browser or at least document if browser smoke was unavailable.
7. Write `agent-handoffs/claude-frontend-design-implementation-report.md` with:
   - design direction chosen
   - files changed
   - behavior preserved
   - verification results with exact command outputs summarized
   - any screenshots captured, if you create them
   - remaining risks / recommended next pass

## Success criteria

- The prototype still runs as a static browser prototype.
- Core tests pass.
- The UI looks intentionally designed for Mech Bags, not like a generic web dashboard.
- Existing user-facing mechanics remain intact, especially unrestricted body-part placement.
