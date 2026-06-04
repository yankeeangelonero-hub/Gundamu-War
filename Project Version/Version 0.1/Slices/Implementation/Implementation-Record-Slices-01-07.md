---
project: mech-bags
doc_type: implementation-record
version: "0.1"
slices: "01–07"
status: implemented
implemented_by: Claude Sonnet 4.6 (code build agent)
date: 2026-06-04
---

# Implementation Record — Version 0.1 Slices 01–07

Combined record. All 7 slices implemented in a single pass. Architecture decisions and files created are cross-referenced to each slice.

---

## Files created

| File | Role | Slices |
|---|---|---|
| `prototype/index.html` | App shell, static structure | 01, 06 |
| `prototype/styles.css` | All styling and CSS animations | 01, 06 |
| `prototype/game-core.js` | Data, placement logic, simulator (UMD) | 02, 04, 05, 07 |
| `prototype/app.js` | DOM controller, run state, battle viewer | 02, 03, 06, 07 |
| `prototype/tests/core-tests.js` | 66 Node.js assertions | 02–07 |

No existing files modified. No dependencies installed. No backend code.

---

## Slice 01 — Static five-bag board shell

**Deliverable:** Five named bag grids in CSS Grid mech silhouette layout.

**How implemented:**
- `index.html` has a `<div id="build-board">` that `app.js` populates dynamically on `DOMContentLoaded`.
- `initBagPanels()` in `app.js` creates `.bag-panel[data-bag="X"]` divs for each of the 5 bags, each containing a label and `.bag-grid`.
- CSS Grid uses `grid-template-areas` to arrange: head centered top, left-arm/torso/right-arm in the middle row, back below torso.
- Default bag sizes defined in `game-core.js`: head 2×3, torso 3×3, back 3×2, leftArm 3×2, rightArm 3×2.
- `renderBag()` in `app.js` uses `style.gridTemplateColumns: repeat(cols, var(--cell-size))` for each bag.

**Architecture notes:**
- Bag panels injected by JS (not in HTML) so they can be rebuilt on new run.
- Cell size is `--cell-size: 38px` CSS variable.

---

## Slice 02 — Item placement and rotation

**Deliverable:** Click-to-select, click-to-place interaction with geometry/overlap validation only.

**How implemented:**
- `state.selected` holds `{instanceId, itemId, rotation, fromHand}`. Set by `selectHandItem()` or `pickUpItem()`.
- Placing: `onCellClick(bagName, row, col)` computes rotated cells, builds occupied set (excluding the item being moved), calls `G.canPlace()`, then `G.placeItem()`.
- Rotation: `onRotate()` increments `state.selected.rotation % 4`. Also triggered by `R` key.
- Hover preview: `onCellHover(bagName, row, col)` sets `state.hoverPreview` and calls `renderBag()` to show `valid-drop` / `invalid-drop` classes.
- Click on placed item: `onCellClick` with no selection picks up item via `pickUpItem()` (removes from bag, adds to hand, selects it).

**Rotation formula (in `game-core.js`):**
```js
function rotateCW(cells) {
  const maxRow = Math.max(...cells.map(([r]) => r));
  const rotated = cells.map(([r, c]) => [c, maxRow - r]);
  // normalize to (0,0) origin
  ...
}
```

**BEH-001 compliance:** `canPlace()` checks only geometry. No tag/anatomy check anywhere in the codebase.

**Note on interaction model:** The spec mentions "drag" but this prototype uses click-to-select + click-to-place with a hover preview. Drag-and-drop was deferred: the cell re-render during `mouseenter` (triggered by hover preview) interferes with HTML5 DnD in the Playwright test harness. Click-to-place achieves the same semantic outcome (place any item in any bag if it fits).

---

## Slice 03 — Shop and body expansion cards

**Deliverable:** Shop row, expansion cards, gold tracking.

**How implemented:**
- `generateShopOffers(round)` in `game-core.js` shuffles item IDs with `Math.random()` (shop randomness permitted, not battle-determinism-sensitive), takes 4, and adds 1 random expansion card.
- `renderShop()` in `app.js` renders `div.shop-card` elements; greys out if `state.gold < offer.cost`.
- `onShopCardClick(offer)` deducts gold, either calls `G.expandBag(build, bag)` (adds 1 row to named bag only) or adds item to `state.hand` and auto-selects it.
- Sell: `sellItem(instanceId)` finds item in hand or bag, removes it, adds `Math.floor(ITEMS[id].cost / 2)` gold.
- Reroll: `onReroll()` costs 1g, calls `generateShopOffers(round)`.

**Economy constants (in `game-core.js`):**
```js
ECONOMY = {
  startingGold: 10, winReward: 6, lossReward: 4,
  rerollCost: 1, expansionCost: 4, SHOP_SIZE: 4,
  WIN_THRESHOLD: 5, LOSS_THRESHOLD: 3,
}
```

---

## Slice 04 — Data-driven item stats and adjacency preview

**Deliverable:** 12 item definitions as data, adjacency rules, visual bonus indicators.

**How implemented:**
- `ITEMS` object in `game-core.js` — 12 entries. Each has: `id, name, shape, cost, tags, damage, speed, accuracy, critChance, hp, color, adjacency[]`.
- Adjacency rule format: `{ requires: itemId|tag, tagMatch: bool, effect: string, desc: string }`.
  - `effect` format: `'field+value'` or `'field-value'` (e.g. `'speed-20'`, `'accuracy+0.2'`).
- `getAdjacentItems(bagItems, targetItem)`: expands both items' absolute cells, finds neighbor keys, returns items with any overlapping neighbor.
- `computeEffectiveStats(placedItem, bagItems)`: applies adjacency rules, plus two universal rules (targeting-chip → +crit to adjacent weapons; armor-plate → +block to adjacent shield).
- `getActiveBonuses(bagName, bagItems)`: same logic, returns display-ready bonus list for UI.
- `renderBag()` in `app.js` adds `has-bonus` class (glowing border) to cells belonging to items with active bonuses.

**Items with adjacency rules:**
| Item | Rule |
|---|---|
| Machine Gun | +8 dmg if Ammo Box adjacent |
| Beam Rifle | −20 speed if Battery adjacent |
| Missile Pod | +20% accuracy if Sensor adjacent |
| Beam Saber | −15 speed if Booster adjacent |
| Heavy Cannon | +15% accuracy if Sensor adjacent |
| Armor Plate | Shield adjacent → Shield gets +20% block |
| Targeting Chip | Any adjacent weapon gets +15% crit |

**ARC-004 compliance:** Adding a new item requires only a new `ITEMS` entry — zero logic changes.

---

## Slice 05 — Deterministic ATB simulator

**Deliverable:** `simulate(playerBuild, enemyBuild, seed)` pure function.

**How implemented:**
- `makePRNG(seed)` — LCG: `s = (1664525 * s + 1013904223) >>> 0`.
- `getAttackers(build, side)` — collects items with `damage > 0` from all bags, calls `computeEffectiveStats` for each.
- `getShields(build, side)` — collects shield items with effective `blockChance` and `blockCooldown`.
- Main loop: find attacker with min `nextFire`, advance clock, roll hit (RNG < accuracy), roll crit (RNG < critChance), check shields (if clock − lastBlock ≥ cooldown, roll block). Apply damage.
- RNG consumed deterministically: hit roll always consumed; crit roll consumed on hit AND on miss (dummy consume to keep sequence aligned).
- Events emitted: `{time, attackerSide, bag, itemId, itemName, damage, effects[], playerHP, enemyHP}`.
- Guard: `MAX_BATTLE_TICKS = 30000`, max 500 events — prevents infinite loop on all-passive builds.

**Determinism guarantee verified by test:**
```
seed=42 run 1 → events (JSON.stringify)
seed=42 run 2 → identical string  ✓
seed=999      → different string  ✓
```

---

## Slice 06 — 2D battle viewer and paused animation playback

**Deliverable:** Battle screen overlay with one-at-a-time animations, HP bars, combat log, Skip Battle.

**How implemented:**
- `#battle-screen` is a `position:fixed` overlay, shown with `.active` class.
- `playBattle(events, pMax, eMax)` is an `async function` that awaits each `animateEvent()` call — this is the structural guarantee of BEH-004 (only one `await` chain, no parallel animations).
- `animateEvent(ev, pMax, eMax)`:
  1. Updates `#event-banner` with `[Bag] ItemName fires!`
  2. Calls `animateProjectile(srcAnchor, destAnchor, projType)` — returns a Promise resolved when Web Animations API `onfinish` fires.
  3. Shows flash and damage number at target.
  4. `await sleep(160)` then updates HP bars.
  5. Appends to combat log.
  6. `await sleep(220)`.
- Projectile types: `beam`, `missile`, `bullet` — different colors and durations (310ms, 460ms, 270ms).
- Mech sprites: CSS-drawn boxes with `data-anchor` elements for each of the 5 bag regions. Animation origins are looked up by `getAnchor(sprite, bag)`.
- Skip Battle: sets `battleAbort = true`, dumps full event log synchronously, calls `showResult()` after 600ms.
- Result overlay: shows win/loss title, best-bag summary, final HP, event count.

**BEH-004 compliance:** The `async/await` single-chain structure means only one `animateEvent` runs at a time. There is no `Promise.all` or parallel animation dispatch.

---

## Slice 07 — Short run loop with enemy pool

**Deliverable:** Complete playable run from round 1 to win/loss screen.

**How implemented:**
- `state` object: `{round, wins, losses, gold, build, hand, shop, selected, hoverPreview}`.
- `onBattleClick()`: selects enemy `ENEMY_POOL[(round - 1) % ENEMY_POOL.length]`, converts to build via `buildFromEnemyData()`, generates seed `round*137 + wins*31 + losses*17 + 1`, calls `simulate()`, then `playBattle()`.
- `onResultContinue()`: increments wins/losses, adds gold reward, checks thresholds, increments round, calls `generateShopOffers()` for new shop.
- `showRunEnd(type)`: shows `#run-end-screen` overlay with win/loss banner.
- `onNewRun()`: resets `state = makeInitialState()`, reinitialises bag panels, re-renders.
- Build persists across rounds: `state.build` is not reset between rounds, only on new run.
- No network calls: enemy pool is static data in `game-core.js`; no `fetch()` anywhere.

**6 enemy builds (all valid, all tested):**
- Starter Balanced: Machine Gun (Back/rot1) + Armor Plate (Torso) + Sensor (Head)
- Missile Backpack: Missile Pod (Back) + Sensor (Head) + Beam Saber (Torso)
- Beam Head Goblin: Beam Rifle (Head/rot1) + Battery (Head) — **demonstrates BEH-001**
- Shield Turtle: Shield (Left Arm) + Armor Plate (Torso) + Heavy Cannon (Right Arm)
- Saber Rush: 2× Beam Saber (Arms/rot1) + Booster (Back) + Targeting Chip (Torso)
- Heavy Cannon Glass Cannon: Heavy Cannon (Torso) + Targeting Chip (Torso/adjacent) + Sensor (Head)

---

## Architecture decisions made during implementation

| Decision | Choice | Rationale |
|---|---|---|
| Bag panel creation | JS-injected on load, not in HTML | Allows `onNewRun()` to fully reset DOM state |
| Item placement interaction | Click-to-select + click-to-place | Hover preview re-renders cells on `mouseenter`; pure DnD unreliable in this pattern |
| Sell mechanic | Included (`floor(cost/2)`) | Owner approved; trivial to add |
| Shield block | Cooldown-gated chance (every 120 ticks) | Prevents permanent full immunity; allows meaningful adjacency buff from Armor Plate |
| RNG crit-roll on miss | Consumed (dummy) even on miss | Keeps RNG sequence aligned so seed → outcome is consistent regardless of hit/miss path |
| `gold-display2` | Removed | Header already shows gold; duplicate ID was unused |

---

## Known gaps and deferred items

- **Drag-and-drop:** Click-to-place is the interaction model. HTML5 drag-and-drop would require `mouseenter` to not re-render the hovered bag, which needs a more targeted rendering strategy (only re-render preview cells, not full grid). Deferred.
- **Speed multiplier:** Skip Battle is present. Speed control (0.5×/2×) was deferred per owner decision.
- **Reroll cost display:** Reroll button shows "(1g)" inline; no persistent display of reroll cost if ECONOMY changes.
- **localStorage:** No persistence. Page refresh resets run. Deferred per owner decision.
- **Mobile polish:** Layout works at 1024×768+. Not optimised for small screens.
