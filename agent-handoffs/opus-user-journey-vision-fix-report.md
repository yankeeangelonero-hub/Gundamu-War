---
project: mech-bags
doc_type: handoff-report
agent: claude-opus-4-8 (user-journey vision playtest + fix pass)
date: 2026-06-04
server: python http.server :8475 (prototype/)
testing: Playwright (real hover+click and pure-tap event paths), full-page + viewport screenshots
---

# User-Journey Vision Playtest + Fix Report — Mech Bags 0.1

## 1. Summary verdict

All six user journeys were exercised through hands-on browser interaction (vision + DOM
inspection) at desktop (1280×800) and phone (375×667, 390×844) viewports. The build is in
good shape: buy → place → battle → result → continue → run-end all work, the
"Armored Maintenance Bay" visual language is intact, and gameplay invariants hold.

Vision testing surfaced **one genuine, previously-hidden defect** plus three
journey-clarity gaps. All four were fixed with small, targeted edits to `app.js`,
`styles.css`, and (no change needed to) `index.html`.

- **Root-cause bug (fixed):** every cell `mouseenter` rebuilt the entire bag's DOM
  (`grid.innerHTML=''`), detaching the cell mid-interaction. Under the real hover→click
  event path this **silently dropped placements** — both valid and invalid — leaving the
  player clicking a cell with nothing happening. This is the Journey-1/Journey-6 "feels
  broken" risk, made real. It was invisible to the prior mobile pass because that pass
  verified placement only via programmatic `element.click()` (which skips the hover
  re-render). Fixed by updating preview classes in place instead of rebuilding.
- **Journey-clarity gaps (fixed):** silent expansion purchase (J4), no first-run "what is
  this game" framing (J1) / no statement that parts fit any bag (J2), and an adjacency glow
  too faint to read over colored tiles (J3).

No core-simulation, economy, or rule changes were made. `game-core.js` was not touched.
Tests: **66/66 pass** before and after.

Verdict per journey: **J1 PASS (after fix), J2 PASS, J3 PASS (after fix), J4 PASS (after
fix), J5 PASS, J6 PASS (after fix).**

---

## 2. User-journey results

| # | Journey | Status | Evidence | Issue found | Fix applied |
|---|---|---|---|---|---|
| 1 | First-time player | **PASS** (was PARTIAL) | Buy Beam Rifle → hand+stats+CTA shown; battle→VICTORY overlay reads clearly | (a) hover→click dropped placements; (b) empty-state info text assumed you already held an item, no "what is this game" cue | Fix A (placement) + Fix C (onboarding copy) |
| 2 | Experimenter — any bag | **PASS** | Beam Rifle rotated and placed in **Head** (blue tile), no error/restriction (BEH-001) | Unrestricted placement worked but was never stated to the player | Fix C copy now says "Parts fit **any** bag — only shape & space limit you" |
| 3 | Optimizer — adjacency | **PASS** (was PARTIAL) | Beam Rifle+Battery and Machine Gun+Ammo Box → `.has-bonus` applied; bonus-tag in Item Info | Green glow too subtle over colored item tiles | Fix D — stronger green border + outer halo |
| 4 | Expansion planner | **PASS** (was FAIL on feedback) | Head 6→9 cells, Right Arm 6→8 cells; correct bag only (BEH-002) | **Zero feedback** — row added silently, info box unchanged, player can't tell what 4g bought | Fix B — bag pulse + "✓ <Bag> expanded — +1 row added" |
| 5 | Short-run player | **PASS** | Round1 win → +6g, Round 2, build persisted (BR+BAT), header stats correct; result shows reward, best-bag, final HP, event count | none | none |
| 6 | Mobile player | **PASS** (after fix) | 375/390px: header wraps, all 5 bags visible, Hand+Rotate row, Info full-width row, Reroll+Battle row, shop 2-per-row, all reachable by scroll; Missile Pod placed in Back via real tap | hover→click drop also affected touch under rapid taps; otherwise layout sound | Fix A (placement) |

---

## 2a. Chronological playthrough evidence

### Desktop journey (1280×800), pre-fix discovery

- **load** — fresh build screen renders: 5 bags with per-bag accent borders (Head blue,
  Torso amber, Back orange, Arms green), workshop-floor grid, shop of 5 offers, Gold `10g`.
  Item Info reads "Select an item from your hand, then tap a cell" while the **Hand is
  empty** — no cue to look at the shop first (J1 onboarding gap noted).
- **buy "Beam Rifle"** — Gold `10g → 6g`; Beam Rifle appears in Hand, amber-pulsing,
  auto-selected; Item Info shows `⚔22 dmg | ⏱100 spd | 🎯90% acc`, tag `Battery: -20
  charge time`, `Rotation 0° Cost 4g Sell 2g`, and amber place-CTA. (J1 buy ✓)
- **click Head(0,0), rifle vertical** — hover preview lights 2 red `invalid-drop` cells
  (3-tall rifle can't fit 2-row Head). **Bug:** `info-box .place-error` is **absent**
  (`hasError:false`) — the click was dropped by the hover re-render. Pure programmatic
  click on the same cell *does* set the error ("Doesn't fit here…") → isolates the cause.
- **press Rotate, click Head(0,0) horizontal** — should place; **Beam Rifle stays in Hand,
  Head empty (0 tiles)** — a *valid* placement was also dropped. `browser_hover` on the
  cell logged **13 × "element was detached from the DOM, retrying"** — every mouseenter
  rebuilt the bag. Pure programmatic click then places it ("BR" tile, hand empty),
  confirming the handler logic is correct and only the DOM-rebuild timing is at fault.
- **adjacency** — bought Battery, placed below the rifle in Head; `has-bonus` on the 3
  rifle cells, but the glow was hard to see against the blue tile (J3 subtlety noted).
- **battle (Round 1 vs Starter Balanced)** — opaque arena, color-coded log (blue player /
  orange enemy), HP `32/80` vs `44/110` mid-fight, banner "BACK MACHINE GUN FIRES!",
  projectile in flight. Resolves to **VICTORY!** — "Enemy mech destroyed! (+6g next
  round) · Your Head was your best bag — 110 total damage · Final HP 4/80 — 0/110 · 14
  attack events." (J5 result ✓)
- **Continue** — Round `2`, Wins `1`, Losses `0`, Gold `3 → 9` (+6); build persisted
  (BR+BAT still in Head, still 6 cells). (J5 continuation ✓)
- **buy Head Expansion** — Head `6 → 9` cells, Gold `9 → 5`; **info box unchanged**,
  no message, shop card still present — player gets no confirmation of what changed
  (J4 gap confirmed).

### Mobile baseline (375×667), pre-fix

- header wraps to a tight 2-line bar; all 5 bags render in the anatomical grid; below the
  board, Hand+Rotate share row 1 and Item Info takes a full-width row 2; Reroll+Battle
  full-width row; shop cards 2-per-row. DOM rects: board → side-panel(596–798) →
  shop(806–1178); body is the scroll container (`scrollTop` reaches 511 = bottom).
  Everything reachable by vertical scroll — standard mobile pattern, no horizontal overflow.

### Post-fix re-verification (real hover+click event path)

- **desktop reload** — Item Info now opens with the "**How to play:** Buy a part from the
  shop below… Tap it, then tap any bag to place it. Parts fit **any** bag — only shape &
  space limit you… hit ⚔ Battle!" explainer. (J1/J2 ✓)
- **buy Beam Saber, real-click Torso(0,0)** — places first try: "BS" in Torso, hand empty,
  Gold `10 → 7`. The exact interaction that failed pre-fix now works. (Fix A ✓)
- **buy Machine Gun, real-click Torso(0,2)** — 3-wide gun spills out of bounds: red
  `invalid-drop` cell **and** `info-box .place-error` = "Doesn't fit here — rotate or try
  another cell." both present; gun retained in Hand. (Fix A + mobile-pass feedback now fire
  on the real path)
- **Machine Gun + Ammo Box adjacency** — 3 `has-bonus` cells on the gun render a bright,
  unmistakable green halo; Beam Saber and Ammo Box correctly do not glow. (Fix D ✓)
- **buy Right Arm Expansion** — `.just-expanded` class applied to the **rightArm** panel
  (pulse), Right Arm grows to 4 rows, Item Info shows green "✓ Right Arm bag expanded —
  +1 row added. More room for parts & adjacency." (Fix B ✓)
- **mobile 390×844, buy Missile Pod, real-tap Back(0,0)** — L-shape "MP" placed in Back,
  hand empty. Real-tap placement reliable on touch viewport. (Fix A on mobile ✓)
- **console** — 0 errors, 0 warnings across the session.

---

## 3. Files changed

| File | Change |
|---|---|
| `prototype/app.js` | **Fix A:** new `applyPreview()` toggles `valid-drop`/`invalid-drop` on existing cells; `onCellHover`/`onCellLeave`/`clearPreview` route through it instead of `renderBag` (no more `innerHTML` wipe on hover). **Fix B:** `onShopCardClick` expansion branch calls new `flashExpansion(bag)` (pulse class + info-box confirmation). **Fix C:** rewrote the no-selection Item-Info copy into a how-to-play / unrestricted-placement explainer. |
| `prototype/styles.css` | **Fix B:** `.bag-panel.just-expanded` + `@keyframes expandFlash`. **Fix D:** strengthened `.bag-cell.has-bonus` (solid green border + `0 0 12px 3px` halo, raised `z-index`). |
| `prototype/index.html` | No change this pass (already carried prior passes' edits). |

`prototype/game-core.js` — **untouched** (simulation, economy, placement rules, PRNG all
unchanged → determinism preserved).

---

## 4. Screenshots captured

Saved under `agent-handoffs/opus-user-journey-screenshots/`:

| File | State |
|---|---|
| `01-fresh-build.png` | Fresh build screen (J1) |
| `02-item-bought.png` | Beam Rifle bought, hand + stats + CTA (J1) |
| `03-invalid-placement.png` | Vertical rifle vs 2-row Head — red preview (pre-fix discovery) |
| `04-adjacency-glow.png` | Rifle+Battery adjacency, **old** subtle glow (J3 pre-fix) |
| `05-battle-mid.png` | Mid-combat: banner, color-coded log, HP bars, projectile (J5) |
| `06-battle-result.png` | VICTORY! overlay with reward/best-bag/HP/events (J5) |
| `07-expansion-no-feedback.png` | Head 6→9 cells, **no** feedback (J4 pre-fix) |
| `08-mobile-build.png` | Mobile 375px board + Hand/Rotate (J6) |
| `09-mobile-shop-scrolled.png` | Mobile shop 2-per-row, Info row, controls (J6) |
| `10-fixed-onboarding.png` | New how-to-play / "any bag" copy (Fix C) |
| `11-fixed-invalid-realclick.png` | Real-click invalid: red cell + error text (Fix A) |
| `12-fixed-adjacency-glow.png` | Machine Gun green halo — **new** stronger glow (Fix D) |
| `13-fixed-expansion-feedback.png` | Right Arm grown + green confirmation (Fix B) |
| `14-fixed-mobile-placed.png` | Mobile real-tap placement of Missile Pod in Back (Fix A) |

---

## 5. Gameplay invariants preserved

- **Five independent bags** Head/Torso/Back/Left Arm/Right Arm — unchanged.
- **No anatomy restrictions** — Beam Rifle placed in Head verified live; Fix C copy
  actively *teaches* unrestricted placement rather than implying limits (BEH-001).
- **Placement validation is geometry/overlap/out-of-bounds only** — `canPlace` untouched;
  Fix A only changes how the preview is painted, not what is valid.
- **Expansion adds exactly +1 row to the named bag only** — verified Head and Right Arm
  grew, others did not (BEH-002).
- **Adjacency bonuses** — `getActiveBonuses`/`computeEffectiveStats` untouched; Fix D is
  cosmetic (BEH-003).
- **Deterministic ATB simulation** — `game-core.js` not modified; same build+seed → same
  events.
- **Shop / economy / reroll / sell / run thresholds / ATB animation queue / run-clear /
  run-over** — unchanged.
- **Static no-dependency browser prototype** — no backend, accounts, network, or new deps.

---

## 6. Verification commands / results

```
$ node prototype/tests/core-tests.js
Results: 66 passed, 0 failed
All tests passed.
```
(66/66 before edits and after edits — app.js/styles.css changes are DOM/presentation only;
the suite exercises game-core logic.)

Browser console during full post-fix journey run: **0 errors, 0 warnings.**

Live re-verification through the **real hover+click event path** (the path that exposed the
bug): valid placement ✓, invalid placement error ✓ (desktop and mobile), expansion feedback
✓, adjacency glow ✓, onboarding copy ✓.

---

## 7. Remaining risks / recommended next pass

1. **Hover preview after rotate (cosmetic).** `onRotate` still does a one-shot `renderBag`
   and clears the live preview; the green/red preview only reappears on the next
   `mouseenter`. Single discrete action, no detachment risk — left as-is to keep the change
   minimal. A future pass could route rotate through `applyPreview()` for instant
   re-preview under a stationary cursor.
2. **Item Info shows *potential* adjacency tags, not *active* ones.** A selected hand item
   lists all its adjacency rules as bonus-tags regardless of whether a partner is adjacent.
   The board `has-bonus` glow is the source of truth for "active"; the panel tags are
   "possible synergies." Consider relabeling the panel tags ("Synergies:") or marking
   active ones, so the two surfaces don't read as contradictory.
3. **Mobile buy↔place scroll friction (not a bug).** On a 375px phone the shop sits below
   the fold, so buy (scroll down) then place (scroll up) is a round-trip. Standard mobile
   pattern; a future pass could pin Reroll/Battle to the viewport bottom.
4. **Layout dead-space at large viewports (carried from prior pass).** The board floats
   center-top leaving ~30% empty workspace at ≥1440px. Cosmetic; out of scope here.
5. **Run-end screen not re-screenshotted this pass.** RUN CLEAR/RUN OVER logic is verified
   correct at code level (and in the prior opus playtest's `08-run-clear.png`); the C2
   header-stat-before-run-end fix from the design pass remains in place. A full 5-win /
   3-loss playthrough screenshot would round out J5 documentation.
6. **Fonts require a network on first load** (Google Fonts CDN). Degrades to Arial
   Narrow / Courier New offline. Self-host for production (carried).

---

### Cross-cutting note for future agents

When verifying placement in this prototype, drive it through the **real hover+click**
event path (Playwright `.click()` after a separate hover, or a physical click), not only
programmatic `element.click()`. The latter skips `mouseenter` and will mask any
hover-coupled rendering defect — which is exactly how the dropped-placement bug survived
the prior pass.
