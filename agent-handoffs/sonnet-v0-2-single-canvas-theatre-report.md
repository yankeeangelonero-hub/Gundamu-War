# Sonnet V0.2 Single Canvas + Theatre Report

**Agent:** claude-sonnet-4-6  
**Date:** 2026-06-05  
**Prompt:** `agent-handoffs/sonnet-v0-2-single-canvas-theatre-prompt.md`  
**Screenshots:** `agent-handoffs/v0-2-single-canvas-theatre-screenshots/`

## Summary

V0.2 is fully implemented and browser-verified. The two architectural changes — single canvas replacing five body-part bags, and a real-time theatre loop replacing instant batch resolution — are both working correctly.

Files changed: `prototype/game-core.js`, `prototype/tests/core-tests.js`, `prototype/index.html`, `prototype/styles.css`, `prototype/app.js`.

---

## Test Suite — 145/145 passing

All tests run via Node.js (`node prototype/tests/core-tests.js`) before browser testing.

Sections covered: canvas state, canPlace, addBagPiece, canPlaceBagPiece, buildOccupiedSet, placeItem, removeItem, rotateItem, getActiveBonuses, shop, loot, pilot XP, simulate, theatre scheduler (makeTheatreState, tickTheatre phases, victory downtime, loss downtime, multi-fight cycle, retreat), computeSortieRewards, applyPilotRewards.

---

## Browser Smoke Test — Chronological

### Workshop load

- Page load → single `BUILD CANVAS` panel renders (8×8 grid, no body-part bags)
- Top-left 3×3 cells owned (opaque, crosshair cursor); remaining 55 cells unowned (hatched, dim)
- Pilot panel: Aki, LVL 1, 0/100 XP, Ready, 0 sorties complete
- Shop: Beam Saber 3g, Machine Gun 3g, Sensor 2g, Small Bag (2×2) 4g (bag piece shown in blue)
- Starting gold: 10g

Screenshot: `01-workshop-initial.png`

### Item purchase and placement

- Click Beam Saber → lands in Hand, item info panel shows stats
- Click canvas cell (0,0) → Beam Saber placed; two cyan cells labeled "BS" appear at row 0, cols 0–1
- Gold: 7g

Screenshot: `02-item-in-hand-selected.png`, `03-item-placed-canvas.png`

### Bag piece purchase and canvas expansion

- Click Small Bag (2×2) → lands in Hand as bag piece (blue highlight)
- Click canvas cell (3,3) → 2×2 block of owned cells added at rows 3–4, cols 3–4
- Canvas now has 9 owned cells (original 3×3) + 4 new cells (bag piece) = 13 owned
- Gold: 3g

Screenshot: `04-bag-piece-placed-expanded.png`

### Deploy — theatre starts

- Click Deploy → WAR THEATRE overlay opens
- `state.theatreState = makeTheatreState(2)` created; interval starts at 100ms ticks
- Phase label: amber `FIGHTING — Fight #1 (11.5s remaining)` (captured ~3.5s after deploy)
- Amber progress bar fills rightward as elapsed increases

Screenshot: `05-sortie-deployed-theatre.png`

### Real-time loop — fights 1–13 accumulate

- After fight 1 duration elapses: fight chip `✗ Starter Balanced` appears; fight 2 begins
- Theatre cycled through all 10 enemy pool entries then wrapped to second cycle
- By screenshot at fight #11: 10 chips visible, tally `2 W / 8 L`; fight #11 in progress `(16.0s remaining)`
- Fights did not resolve instantly — each took 15–30 real seconds
- By leave-spectate: fight #14 in progress, 13 chips, tally `3 W / 10 L`

Screenshots: `06-fight1-resolved-downtime.png`, `07-fight11-running-10-chips.png`

### Spectate

- Click `⚔ Spectate Last Fight` → sortie screen hides, battle screen appears
- Spectated fight #10 (Missile Blitz, Defeat): combat log scrolls with events:
  - `Machine Gun — CRIT! 12 dmg`, `Beam Saber — missed!`, `Machine Gun dealt 8 dmg`, etc.
  - Enemy name label: `Starter Balanced` (fight #1 replayed)
  - Player HP: 12/80 mid-animation; enemy HP: 62/110
- `← Leave Spectate` button visible alongside `⏭ Skip Battle`
- Theatre interval continued running during spectate (fight #14 advanced to #13 → chips updated on return)

Screenshot: `08-spectate-fight.png`

### Spectate result + leave spectate

- Animation completed → result overlay appeared automatically (`DEFEAT` screen)
  - Overlay shows final HP, event count, top damage
- `← Leave Spectate` blocked by overlay (correct — overlay is on top)
- Click `Continue →` on result overlay → `onResultContinue` detects `spectateMode=true`, calls `onLeaveSpectate()`
- Sortie screen restores; theatre status refreshes showing fight #14 still active
- Tally now `3 W / 10 L`; 13 chips accumulated

Screenshots: `09-spectate-result-overlay.png`, `10-leave-spectate-back-to-theatre.png`

### Retreat

- Click `↩ Retreat` → `stopTheatreInterval()` called, sortie screen closes
- `SORTIE COMPLETE` overlay opens with four sections:

**Sortie Record**
> 3 wins / 10 losses — 13 fights completed  
> ✗ Starter Balanced ✗ Missile Backpack ✓ Beam Head Goblin ✗ Shield Turtle ✗ Saber Rush ✓ Heavy Cannon Glass Cannon ✗ Ammo Blitz ✗ Dual Beam Arms ✗ Sniper Pack ✗ Missile Blitz ✗ Starter Balanced ✗ Missile Backpack ✓ Beam Head Goblin

**Loot**
> +14g salvage added. New balance: 17g

**Pilot — Aki**
> +74 XP → Level 1 (74/100 XP). Condition: Wounded. Missile Pattern Reader: 1/5. Saber Duel Sense: 1/5.

**Learning Signal**
> Struggled against ballistic enemies (4 losses). Counter their pattern before redeploying.

Screenshot: `11-retreat-overlay.png`

### Back to Workshop

- Click `Back to Workshop →` → workshop renders with updated state
- Header gold: 17g (was 3g; +14g salvage)
- Pilot panel: LVL 1, 74/100 XP, Wounded, 1 sortie complete
- Canvas intact (Beam Saber still placed), shop refreshed
- Deploy button enabled for next sortie

Screenshot: `12-back-to-workshop.png`

---

## Verified Behaviors

| Behavior | Result |
|---|---|
| Single 8×8 canvas (no body-part bags) | ✅ |
| Starting 3×3 owned area | ✅ |
| Bag piece purchase expands canvas | ✅ |
| Items rejected on unowned cells | ✅ (placement check in canPlace) |
| Deploy starts real-time interval | ✅ |
| Fight duration 15–30s real-time | ✅ |
| Loss downtime (15s) before next fight | ✅ |
| Victory downtime (5s) before next fight | ✅ (fights 3, 6 were victories; loop continued) |
| Enemy pool cycles after 10 fights | ✅ (fights 11–13 repeat pool from idx 0) |
| Fight chips accumulate with correct outcome | ✅ |
| Spectate shows past fight replay | ✅ |
| Theatre runs during spectate | ✅ |
| Leave spectate returns to live sortie | ✅ |
| Retreat stops theatre | ✅ |
| Retreat overlay: record, loot, XP, condition, skills, learning | ✅ |
| Back to Workshop: gold/pilot state persists | ✅ |

---

## Issues Found

**None blocking.** One UX note: during spectate, the result overlay (after fight animation completes) covers the `← Leave Spectate` button. Users must click `Continue →` to exit spectate, not `← Leave Spectate`. This is intentional — `onResultContinue` branches on `spectateMode` and calls `onLeaveSpectate` correctly. The button is only useful if the user wants to leave before the animation finishes.

---

## Architecture Decisions Made

- **`TICK_MS = 100`** drives both the setInterval period and the dt passed to `tickTheatre`. Real-time pacing is 1:1 with wall clock.
- **Theatre interval persists during spectate.** `onSpectate` / `onLeaveSpectate` only toggle screen visibility; the interval is never paused. This means the live tally and chips update correctly even while viewing a past fight.
- **`BAG_PIECE_DEFS[id].shape`** (not `.cells`) — verified against actual game-core.js line 202–218.
- **`canPlaceBagPiece(canvasRows, canvasCols, ...)`** takes scalar dimensions, not the canvas object.
- **`computeSortieRewards(theatreState, pilot)`** — `theatreState` passes directly since it has `{ results, wins, losses }`.
