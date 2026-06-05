# Claude Code Task — Mech Bags mobile equipment placement bugfix

You are Claude Code running inside `D:/Claude/Mech Bags`.

User playtest report from mobile browser over Tailscale: “I cannot confirm placement of equipment.”

## Ground rules

- This is a focused bugfix/UX reliability pass, not another visual redesign.
- Preserve the existing “Armored Maintenance Bay” look unless a tiny CSS change is needed for usability.
- Do not commit, push, delete screenshots, or alter unrelated project scaffolding.
- Preserve gameplay/product contract:
  - Five independent body-part bags: Head, Torso, Back, Left Arm, Right Arm.
  - Item placement is unrestricted by anatomy; Beam Rifle in Head remains valid when geometry/rotation permits it.
  - Placement validation is geometry/overlap/out-of-bounds only.
  - Keep deterministic ATB/shop/expansion/adjacency/battle/run behavior.
  - Static no-dependency browser prototype.

## Parent investigation so far

- Desktop JS-click reproduction works: after buying a shop item, selecting/tapping a valid `.bag-cell` calls `onCellClick`, removes item from hand, and places item.
- Current implementation is click/mouse-hover oriented:
  - `app.js` attaches `click`, `mouseenter`, `mouseleave` per `.bag-cell`.
  - Invalid placements silently return in `onCellClick()` with no feedback.
  - Mobile has no hover preview and can easily look like “no confirmation”.
  - CSS has no responsive breakpoint; `#main` stays a horizontal row with board + fixed `#side-panel` width, while body has `overflow-x:hidden`. This is likely poor on phone widths.
- Need root-cause investigation before editing: reproduce/inspect mobile/touch layout and event flow as much as possible.

## Required reading before editing

- `Readme.md`
- `Kanban.md`
- `prototype/README.md`
- `prototype/index.html`
- `prototype/styles.css`
- `prototype/app.js`
- `prototype/game-core.js`
- `agent-handoffs/claude-frontend-design-implementation-report.md`

## What to fix

Make equipment placement confirmable and understandable on mobile/touch without breaking desktop.

Likely acceptable changes:
1. Add explicit placement feedback/status text for touch/mobile:
   - when an item is selected, tell user to tap a grid cell and use Rotate if it does not fit;
   - after invalid placement, show a clear short message like “Does not fit here — rotate or choose another cell”;
   - after successful placement, show a short success/status cue if useful.
2. Add touch-friendly event support if needed (`pointerdown`/`pointerup` or guarded touch handling) while avoiding double-placement from click + pointer events.
3. Add responsive layout breakpoint(s) so mobile can actually use hand/rotate/info/shop and the board without hidden horizontal overflow. Desktop should remain close to current layout.
4. Keep placement rules unchanged. Do not add anatomy restrictions or a modal confirmation flow unless truly necessary.
5. If using CSS media queries, keep the visual language consistent and minimal.

## Verification required

Run:
- `node prototype/tests/core-tests.js`

Also do at least one browser/manual smoke check and document exact steps/results:
- buy an item;
- place it in a valid cell;
- attempt invalid placement and verify visible feedback;
- rotate/tap placement flow for Beam Rifle in Head or another shape-sensitive item;
- check narrow/mobile-ish viewport if you can.

If you can capture updated screenshots, put them under `agent-handoffs/mobile-placement-bugfix-screenshots/`.

## Report required

Write `agent-handoffs/claude-mobile-placement-bugfix-report.md` with:
- root cause found;
- files changed;
- exact behavior changes;
- gameplay invariants preserved;
- verification commands and results;
- remaining risks / recommended next pass.

## Success criteria

- Mobile/touch user can understand whether placement succeeded or failed.
- Valid equipment placement still works.
- Invalid geometry failures are visible, not silent.
- Desktop behavior is not regressed.
- Core tests still pass.
