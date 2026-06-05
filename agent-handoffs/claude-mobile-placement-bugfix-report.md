---
project: mech-bags
doc_type: handoff-report
agent: claude-sonnet-4-6 (mobile placement bugfix)
date: 2026-06-04
---

# Mobile Placement Bugfix Report — Mech Bags 0.1

## Root Causes Found

### Primary — Layout inaccessible on mobile

`#main` is a horizontal flex row with `#side-panel: width: 234px; flex-shrink: 0`. On a 375px phone viewport, the side panel consumed most of the available space and the board was crushed to ~100px wide. With `overflow-x: hidden` on `body`, the side panel content (Hand list, Rotate button, Item Info) was either clipped or completely off-screen. The player had no way to select an item from their hand, so placement could never begin.

### Secondary — Silent invalid placement

`onCellClick()` silently `return`ed on `!canPlace` with zero feedback. On desktop, hover preview (`mouseenter`/`mouseleave`) shows green/red cell highlights before a click, so players see validity before committing. On mobile, `mouseenter` never fires. A tap on an invalid cell produced absolutely no change: no visual, no message, nothing. The item stayed selected with no indication of why.

### Tertiary — No "tap to place" affordance

When an item was selected (including auto-selection after buying), the info panel showed item stats with no instruction to tap a grid cell. On desktop, the hover glow teaches this implicitly. On mobile, first-time users had no cue that tapping the board was the next action.

---

## Files Changed

| File | Change |
|---|---|
| `prototype/styles.css` | Added `touch-action: manipulation` to interactive elements; added `.place-cta` / `.place-error` styles; added `@media (max-width: 700px)` responsive breakpoint |
| `prototype/app.js` | Added `placementMsg: null` to state; updated `renderInfo()` to show CTA + error text; added placement failure feedback in `onCellClick()`; cleared `placementMsg` in all state transitions |

---

## Exact Behavior Changes

### Layout (CSS)

- At ≤700px viewport: `--cell-size` drops from 42px to 36px. Board width narrows to ~344px (fits in 360px+). `#main` switches to `flex-direction: column` — board on top, side panel below.
- `#side-panel` becomes full-width row wrap: Hand + Rotate in row 1 (90px tall), Item Info panel in its own full-width row 2 (max-height 120px, scrollable internally).
- `#shop-area` gains `flex-wrap: wrap`: Reroll + Battle buttons become a full-width row, shop cards become 2-per-row (50% width each).
- `touch-action: manipulation` added to `.bag-cell`, `.hand-item`, `.shop-card`, `.ctrl-btn`, `#rotate-btn`, `.item-tile` — eliminates residual tap-delay on older browsers.
- Desktop at >700px: no layout change, all values unchanged.

### Placement Feedback (app.js)

- `renderInfo()` when item selected: appends amber `.place-cta` box — "Tap a cell to place it. Use ↻ Rotate if it doesn't fit." — below item stats.
- `onCellClick()` invalid path: sets `state.placementMsg = "Doesn't fit here — rotate or try another cell."` and calls `renderInfo()` immediately, rendering a red `.place-error` box below the CTA.
- `onCellClick()` success path: `state.placementMsg = null` before `renderAll()` — error clears on placement.
- No-selection info text updated: "click a bag cell" → "tap a cell", "Press R" → "Use ↻ Rotate or press R".
- `state.placementMsg` cleared in: `selectHandItem`, `onRotate`, `onShopCardClick`, `pickUpItem`, Escape key handler.

---

## Gameplay Invariants Preserved

- All five bags remain independent; no anatomy restrictions added.
- Placement validation is geometry/overlap/out-of-bounds only — unchanged.
- Beam Rifle in Head bag still valid when rotation permits (BEH-001 unchanged).
- Bag expansion still adds exactly 1 row to the named bag only (BEH-002).
- Adjacency bonuses unaffected (BEH-003).
- Battle simulation determinism unaffected — only `app.js` UI code changed; `game-core.js` not touched.
- Shop, economy, run thresholds, ATB animation — all unchanged.

---

## Verification Commands and Results

### Core test suite
```
node prototype/tests/core-tests.js
Results: 66 passed, 0 failed
All tests passed.
```

### Browser smoke (Playwright, localhost:8474)

**Desktop (1280×800):**

1. Initial load — board visible, info box shows "Select an item…tap a cell to place it"
2. Buy Beam Saber → hand shows item with amber pulse; info box shows stats + amber CTA
3. Click head cell (row=0, col=2) — invalid for 2-wide saber anchored at col 2 (spills to col 3). Red `.place-error` box appears: "Doesn't fit here — rotate or try another cell." Item stays in hand.
4. Click head cell (row=0, col=0) — valid. Item placed. Hand empty. Info box returns to "Select an item". `place-error` cleared.
5. Buy Shield → placed in Torso (row=0, col=0). Three cells (0,0), (1,0), (2,0) colored. Hand empty. `place-error` null. ✓

**Mobile (375×667, Chrome):**

1. `--cell-size: 36px` confirmed via `getComputedStyle`. Board width 350px < 375px viewport — no horizontal overflow.
2. `#main` flex-direction: column confirmed. Side panel below board at y=557, full-width (359px).
3. Item Info box: `max-height: none` on desktop, `max-height: 120px` on mobile — confirmed via `getComputedStyle`.
4. Side panel heights (item selected): Hand 90px, Rotate 90px, Info 176px in two-row layout (not 537px stretched).
5. Shop at y=839 — scrollable via `document.body.scrollTop`. 5 offers rendered, cards 172.5px wide (2 per row). Reroll + Battle buttons in full-width row.
6. `place-cta` and `place-error` confirmed in DOM via native `element.click()` and `innerHTML` inspection.

---

## Screenshots

All screenshots in `agent-handoffs/mobile-placement-bugfix-screenshots/`:

| File | What it shows |
|---|---|
| `01-desktop-initial.png` | Desktop initial state — updated info text |
| `02-item-bought-cta.png` | Item bought and auto-selected; amber place-cta visible in info panel |
| `03-invalid-placement-error.png` | Red place-error after tapping invalid cell; item still in hand |
| `04-mobile-375-initial.png` | Mobile layout — board on top, Hand/Rotate/Info below, all accessible |
| `05-mobile-item-selected.png` | Mobile item selected state |
| `06-mobile-layout-fixed.png` | Mobile two-row side panel (Hand+Rotate / Info) |
| `07-mobile-shop-scrolled.png` | Mobile shop — 2-per-row cards, Reroll+Battle in row, accessible by scroll |

---

## Remaining Risks / Recommended Next Pass

### Body scroll on iOS Safari (low risk for prototype)

`html, body { height: 100%; overflow-x: hidden }` causes `overflow-y: auto` to be set on both elements. The scroll container is `body`, not `document`. Touch scrolling on the body element works in modern iOS Safari (13+) and Android Chrome. However, on older iOS or some edge cases with address-bar height changes, momentum scroll may behave unexpectedly. For a production build, switching to `html { height: 100% } body { min-height: 100%; height: auto; }` and ensuring `overflow-y: visible` on html would be cleaner.

### Mobile placement flow requires scrolling between board and shop

On a 375px phone, the board occupies ~480px and the side panel ~274px, pushing the shop to y=839. The player buys an item (scroll down to shop), then needs to scroll back up to tap a bag cell. This is a UX friction point but not a bug — standard mobile pattern. A future pass could pin the shop controls (Reroll/Battle) to the bottom of the viewport.

### Hover preview absent on touch

`mouseenter/mouseleave` preview (green/red cells lighting up before tap) still does not fire on touch devices. The `place-cta` and `place-error` messages compensate, but the preview-before-commit interaction is desktop-only. A future pass could implement a long-press preview or a two-tap confirm flow.

### Placement error persists across bag switches

`state.placementMsg` is cleared on rotate, deselect, new selection, and successful placement — but NOT if the player taps a cell in a different bag that also fails. In that case the message updates (new error from second tap). This is intentional and correct; no bug here.

### No affordance for "tap here to pick up an already-placed item"

If a player taps a cell that has an item already on it (without anything selected), the item is picked up into hand. There is no visible indication that placed items are re-selectable. This is the same on desktop and is not a regression.
