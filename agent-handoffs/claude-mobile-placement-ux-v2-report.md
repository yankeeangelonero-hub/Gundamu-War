---
project: mech-bags
doc_type: handoff-report
agent: claude-sonnet-4-6 (mobile placement UX v2)
date: 2026-06-05
server: python http.server :8474 (prototype/)
testing: node core-tests + Playwright (pure element.click(), no hover dependency — mobile path)
---

# Mobile Placement UX v2 Report — Mech Bags 0.1

## 1. Summary Verdict

All three UX goals from Xuanyue's feedback are implemented and verified:

- **Tap one to put** — unchanged; buying auto-selects from hand, tap empty cell places.
- **Rotate in place** — tapping a placed item selects it for edit; pressing Rotate tries the new rotation at the same anchor without picking it up to hand. Fails gracefully with visible error if shape doesn't fit.
- **Move placed blocks via tap-select/tap-destination** — tap a placed item to select it (amber highlight, board stays intact), tap a valid destination to move it, tap invalid destination shows error and preserves original position.

Mobile no longer depends on hover preview at any step. Interaction is driven entirely by tap + info-box feedback.

Core tests: **66/66 pass**. Browser console: **0 errors**.

---

## 2. Interaction Model Implemented

### Mode A — Hand item selected (unchanged)
- Buying or clicking a hand item selects it with `fromHand: true`.
- Rotate button cycles the shape before placement.
- Tapping a valid cell places it and clears selection.
- Tapping an invalid cell shows "Doesn't fit here — rotate or try another cell."
- Info box shows: **"Tap a cell to place it. Use ↻ Rotate if it doesn't fit."**

### Mode B — Placed item selected for edit (new)
- Tapping a placed item calls `selectPlacedItem`: sets `fromHand: false`, item stays on the board.
- All cells of the selected item get the `.placed-selected` amber highlight.
- The item tile on the first cell gets the existing `.item-tile.selected` amber outline.
- Info box shows: **"Tap another cell to move. ↻ Rotate to turn in place."** plus a **Sell for Xg** button.
- **Rotate**: validates the rotated shape at the same anchor. On success: mutates `pi.rotation` in-place and syncs `state.selected.rotation`. On failure: shows "Can't rotate here — move it first or try a bigger bag." Item stays at original rotation.
- **Tap empty cell** (same or different bag): validates placement. On success: `G.removeItem` + `G.placeItem`, selection cleared. On failure: "Doesn't fit here" error, item stays.
- **Tap same item**: deselects, returns to idle.
- **Tap different placed item**: switches selection to that item.
- **Sell button**: calls `sellItem(instanceId)` directly from the info panel (no hand required).
- **ESC**: clears selection, re-renders board.

### No pick-up-to-hand on tap
`pickUpItem` was removed. Items no longer auto-migrate to hand when tapped. Sell from the board is via the info-panel sell button.

---

## 3. Files Changed

| File | Change |
|---|---|
| `prototype/app.js` | Removed `pickUpItem`. Added `selectPlacedItem`. Rewrote `onCellClick` for new interaction model. Extended `onRotate` to try in-place rotation for `fromHand:false`. Updated `renderBag` to add `.placed-selected` and `.item-tile.selected` for selected placed items. Updated `renderInfo` to differentiate CTA text and add sell button for placed items. `selectHandItem` and ESC handler now call `renderAll()` to clear stale board highlights. Added event delegation for `.info-sell-btn` in `initDOM`. |
| `prototype/styles.css` | Added `.bag-cell.placed-selected` (amber highlight, positioned before `.valid-drop`/`.invalid-drop` so preview classes win cascade when both apply). Added `.info-sell-btn` and `.info-sell-btn:hover` styles. |
| `prototype/game-core.js` | **Not touched.** |

---

## 4. Exact Behavior Changes

### New CSS classes

`.bag-cell.placed-selected` — amber tint (`rgba(245,197,24,0.14)`) + amber border + amber inset glow, applied to all cells occupied by the selected placed item. Positioned before `.valid-drop` / `.invalid-drop` in stylesheet so hover preview overrides it when both are present.

`.info-sell-btn` — red-bordered mono button rendered inside info box when a placed item is selected. Clicking it calls `sellItem(instanceId)` via delegation on `#info-box`.

### onCellClick (rewritten)

```
tap cell with nothing selected:
  → destInfo exists → selectPlacedItem(iid, bag)
  → destInfo absent → no-op

tap cell with hand item selected (fromHand:true):
  → canPlace → place + clear selection
  → !canPlace → show error

tap cell with placed item selected (fromHand:false):
  → destInfo.iid == selected.iid → deselect
  → destInfo.iid != selected.iid → switch selection
  → no destInfo + canPlace → removeItem + placeItem + clear selection
  → no destInfo + !canPlace → show error
```

### onRotate (extended)

```
fromHand:false (placed item):
  newRot = (rotation + 1) % 4
  G.buildOccupiedSet(bag.items, instanceId)  ← excludes self
  G.canPlace at same anchor with newRot:
    success → pi.rotation = newRot, state.selected.rotation = newRot, clear error
    fail    → state.placementMsg = "Can't rotate here…"
  renderBuildBoard() + renderInfo()

fromHand:true (existing hand-rotate behavior unchanged)
```

### No hover required
All placement feedback (CTA, error, selection highlight) is rendered by the info box and board cell classes on click/tap. Touch devices get identical feedback to mouse.

---

## 5. Verification Steps and Results

### Core test suite
```
node prototype/tests/core-tests.js
Results: 66 passed, 0 failed
All tests passed.
```

### Browser smoke (Playwright, localhost:8474)

**Desktop (1280×800):**

- **Step 1** — Buy Beam Rifle (4g), auto-selected in Hand. Info shows "Tap a cell to place it" CTA, hand item amber-pulsing. `fromHand:true` confirmed. ✓
- **Step 2** — Rotate to 90° (1×3 horizontal), hover Head(0,0), click Head(0,0). "BR" tile placed, hand empty, info returns to how-to-play. ✓
- **Step 3** — Click Head(0,0) (Beam Rifle). 3 cells get `.placed-selected`, tile gets `.item-tile.selected`, info shows "Tap another cell to move. ↻ Rotate to turn in place." + "Sell for 2g" button. Hand still empty (item not picked up). ✓ [screenshot 01]
- **Step 4** — Click Rotate with BR at 90° in Head. 180° = 3×1 vertical, Head only 2 rows → can't fit. Error: "Can't rotate here — move it first or try a bigger bag." Rotation stays 90°, item stays in Head. ✓
- **Step 5** — Click Torso(0,0) (valid destination for 1×3 at 90°). BR moves Head → Torso. Selection clears. Head empty, Torso shows "BR". ✓
- **Step 6** — Select BR in Torso. Rotate: 90° → 180° (3×1 vertical, fits 3-row Torso). No error. Rotation advances. Item stays selected. ✓ [screenshot 02]
- **Step 7** — Click Head(0,0) with BR at 180° (3 tall). Head only 2 rows → invalid move. Error: "Doesn't fit here". Item stays in Torso, still selected. ✓ [screenshot 03]
- **Step 8** — Click BR cell in Torso again → deselects. Info returns to how-to-play. ✓
- **Step 9** — Buy Battery (reroll), place adjacent to BR in Torso(0,1). 3 `has-bonus` cells on BR confirmed. Adjacency bonus still working. ✓
- **Step 10** — Select BR in Torso, tap Back(0,0) → BR moves to Back. Battery remains in Torso. `has-bonus` on Torso drops to 0 (adjacency cross-bag separation correct). ✓
- **Step 11** — Select Battery in Torso, click "Sell for 1g" in info panel. Gold +1g, Battery removed from board. ✓

**Mobile (375×667, fresh load):**

- **Step 12** — Buy Beam Saber (3g, 2×1 vertical). Places in Head(0,0). Hand empty. ✓
- **Step 13** — Tap Head(0,0). 2 cells `.placed-selected`, info shows "Tap another cell to move. ↻ Rotate to turn in place." — no hover needed. ✓
- **Step 14** — Rotate: 0° (2×1) → 90° (1×2). Valid in Head (2 rows, 3 cols). No error, rotation advances, still selected. ✓
- **Step 15** — Tap LeftArm(0,0). Saber moves Head → Left Arm, selection clears. ✓ [screenshot 04]
- **Step 16** — Battle button → battle screen active. Skip → result overlay active. Title "DEFEAT!" or "VICTORY!". ✓

**Console:** `window.__errors = []` — 0 errors.

---

## 6. Screenshots

All in `agent-handoffs/mobile-placement-ux-v2-screenshots/`:

| File | What it shows |
|---|---|
| `01-placed-item-selected.png` | Desktop — Beam Rifle selected in Head bag; 3 cells amber, tile outlined, "move" CTA + sell button in info |
| `02-rotate-in-place-valid.png` | Desktop — BR rotated 90°→180° in Torso; 3 cells still amber, no error |
| `03-invalid-move-error.png` | Desktop — BR (180°, 3 tall) rejected from Head (2 rows); error shown, item preserved in Torso |
| `04-mobile-move-complete.png` | Mobile 375px — Beam Saber moved from Head to Left Arm via tap-select + tap-destination |

---

## 7. Gameplay Invariants Preserved

- **Five independent bags** Head/Torso/Back/Left Arm/Right Arm — unchanged.
- **No anatomy restrictions** — Beam Rifle placed and rotated in Head bag verified live (BEH-001).
- **Placement validation is geometry/overlap/out-of-bounds only** — `canPlace` untouched; new interaction only changes when/how it is called.
- **Adjacency bonuses** — verified: bonus appears when Battery adjacent to Beam Rifle, bonus clears when item moved to different bag (BEH-003, ARC-003).
- **Expansion adds exactly +1 row to named bag only** — not touched (BEH-002).
- **Deterministic ATB simulation** — `game-core.js` not modified; same build+seed → same events.
- **Shop / economy / reroll / sell / run thresholds / ATB animation / run-clear / run-over** — unchanged.
- **Static no-dependency browser prototype** — no backend, accounts, network, or new deps.

---

## 8. Remaining Risks / Recommended Next Pass

1. **No drag support yet.** The task called drag "optional" and the tap-select/tap-destination fallback was implemented. A future pass could add `pointerdown`/`pointermove`/`pointerup` drag on `.item-tile` elements for desktop UX parity. The `selectPlacedItem` + move path is the correct foundation to build drag on top of.

2. **Hover preview shows for placed-item-selected moves (desktop only).** When a placed item is selected and the mouse hovers a destination cell, `onCellHover` fires and shows the green/red preview. This works correctly (occupied set excludes the moving item). Touch devices never see this, but they get the CTA instruction and post-tap error instead.

3. **Cross-bag hover preview only shows in destination bag.** When moving an item from bag X to bag Y, the hover preview appears in bag Y. The source bag X shows the amber `.placed-selected` highlight for the item being moved. This is visually clear but could be improved by also showing a "lift" state on source cells during hover.

4. **"Pick up to hand" mechanic removed.** Items no longer auto-migrate to hand on tap. Sell from the board now goes through the info-panel sell button. If future design requires a "hold item in hand before deciding where to place" flow, `selectPlacedItem` can be extended to optionally call `pickUpItem` on a second tap (double-tap-to-lift pattern).

5. **No touch drag implementation.** For a production pass, a pointer-event drag starting from `.item-tile` with `touch-action: none` would give mobile users a more intuitive drag-to-move experience. The current tap-select/tap-destination model is reliable and works, but feels less direct than physical dragging on a touchscreen.

6. **Fonts require a network on first load** (Google Fonts CDN) — carried from prior passes.
