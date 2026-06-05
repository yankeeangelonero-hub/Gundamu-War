# Claude Code Task — Mech Bags mobile placement UX v2

You are Claude Code running inside `D:/Claude/Mech Bags`.

Xuanyue’s live mobile playtest feedback:

> “I think generally ok, but right now on mobile there is no preview so I can’t try rotating my blocks. Better UX should be tap one to put, then rotate can rotate in place, then drag to change block placement”

## Goal

Implement the next UX model for item placement, especially mobile/touch:

1. **Tap one to put**
   - Player buys/selects an item from Hand.
   - Tapping/clicking a valid grid cell places it immediately as a real placed item.
   - This should remain consistent with existing desktop behavior.

2. **Rotate in place**
   - After an item is placed, the player can select that placed item.
   - Pressing/tapping Rotate should rotate the selected placed item **in place** if the rotated shape fits at the same anchor cell.
   - If it does not fit, keep the item as-is and show visible feedback: e.g. “Can’t rotate here — move it or choose more space.”
   - Existing “rotate before placement” from Hand should still work.

3. **Drag / reposition placed blocks**
   - Player should be able to pick up or drag a placed item and move it to a different valid cell/bag.
   - On mobile, dragging is preferred if feasible; a tap-select-then-tap-destination fallback is acceptable and likely necessary for reliability.
   - The user should not lose the item if move/drag destination is invalid.
   - Invalid move should show clear feedback and preserve the original placement.

4. **Mobile preview problem**
   - Mobile cannot rely on hover preview.
   - Provide a touch-friendly preview/feedback model:
     - selected placed/hand item is clearly highlighted;
     - valid/invalid destination is understandable during move attempt where possible;
     - status copy tells the user what to do next: “Tap another cell to move, Rotate to turn in place.”

## Hard invariants

Preserve gameplay/product rules:
- Five independent body-part bags: Head, Torso, Back, Left Arm, Right Arm.
- Items are unrestricted by anatomy; Beam Rifle in Head remains valid when geometry/rotation permits it.
- Placement validation remains geometry/overlap/out-of-bounds only.
- Keep deterministic ATB simulator, shop, expansion, adjacency, battle, result, run-clear/run-over behavior.
- Static no-dependency browser prototype; no backend/accounts/build system.
- Do not commit/push.
- Do not delete existing screenshots/handoffs.

## Required reading before editing

Read:
- `Readme.md`
- `Kanban.md`
- `prototype/README.md`
- `prototype/index.html`
- `prototype/styles.css`
- `prototype/app.js`
- `prototype/game-core.js`
- `agent-handoffs/claude-mobile-placement-bugfix-report.md`
- `agent-handoffs/opus-user-journey-vision-fix-report.md`

Important prior bug lesson:
- Do **not** rebuild grid DOM on hover/preview. Opus found that `grid.innerHTML=''` during hover detached cells and dropped real hover→click placements. Preview/move state should update classes in place.

## Implementation guidance

Think of item interaction as three modes:

### A. Hand item selected
- Rotate button rotates selected hand item before placement.
- Clicking/tapping valid cell places it.
- Invalid placement shows error and keeps item in hand.

### B. Placed item selected for edit
- Clicking/tapping a placed item selects it **without immediately returning it to Hand**.
- Rotate button rotates it in place if valid.
- Clicking/tapping another valid grid cell moves it there.
- Invalid move/rotation keeps original position.
- Provide clear selected styling on placed item and/or occupied cells.

### C. Optional drag
- If practical, support pointer drag from placed item to destination cell.
- It may share logic with selected placed item move.
- Avoid double actions from pointer + click. Use guarded pointer/click handling if needed.
- Do not make drag mandatory for mobile; tap-select/tap-destination fallback must work.

Existing tests may not cover DOM UX. Add lightweight unit tests only if feasible without overbuilding; otherwise use browser/Playwright manual checks and document.

## Verification required

Run:

```bash
node prototype/tests/core-tests.js
```

Browser/vision/manual smoke checks required:
1. Buy an item, tap/click valid cell: item places.
2. Select placed item, Rotate: item rotates in place if it fits.
3. Select placed item, Rotate where it cannot fit: item stays put and visible error appears.
4. Select placed item, tap another valid cell/bag: item moves there.
5. Attempt invalid move: original item remains in original position, visible error appears.
6. On mobile/narrow viewport, buy → place → select placed item → rotate in place → move via tap fallback works.
7. Beam Rifle in Head remains valid when rotated/geometry fits.
8. Adjacency feedback still works after moving/rotating items.
9. Console has no JS errors.

If screenshots are captured, put them under:

`agent-handoffs/mobile-placement-ux-v2-screenshots/`

## Report required

Write:

`agent-handoffs/claude-mobile-placement-ux-v2-report.md`

Report structure:
1. Summary verdict
2. Interaction model implemented
3. Files changed
4. Exact behavior changes
5. Verification steps/results
6. Screenshots captured
7. Gameplay invariants preserved
8. Remaining risks/recommended next pass

## Success criteria

- Xuanyue’s desired UX is implemented: tap to put, rotate placed blocks in place, move placed blocks without losing them.
- Mobile does not depend on hover preview.
- Invalid rotate/move has visible feedback.
- Valid placements and unrestricted body-part placement still work.
- Core tests pass.
