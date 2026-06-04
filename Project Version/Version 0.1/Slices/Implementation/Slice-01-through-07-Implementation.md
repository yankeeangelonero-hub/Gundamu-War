---
project: mech-bags
doc_type: implementation-record
version: "0.1"
slices: "01-07"
status: implemented
updated: 2026-06-04
---

# Implementation Record — Slices 01–07 (combined pass)

All seven Version 0.1 slices were implemented in a single coding session producing four prototype files. No backend, no build tools, no dependencies.

## Files created

| File | Purpose |
|---|---|
| `prototype/index.html` | Entry point; openable directly without a server |
| `prototype/styles.css` | All layout, grid, animation, and overlay styles |
| `prototype/game-core.js` | Data + simulation module (no DOM); UMD pattern for Node/browser |
| `prototype/app.js` | DOM controller: build board, shop, battle viewer, run loop |
| `prototype/tests/core-tests.js` | 66 Node.js assertions |
| `prototype/README.md` | Player and tester guide |

---

## Slice 01 — Static five-bag board shell

**Deliverable met:** Five named bag grids rendered in a mech silhouette layout (Head centred top, Left Arm / Torso / Right Arm middle row, Back below). Bag panels are injected by `app.js:initBagPanels()`.

**Implementation notes:**
- `#build-board` uses CSS Grid with named areas `head / la torso ra / back`.
- Each bag is a `.bag-panel[data-bag]` with a `.bag-label` and a `.bag-grid` inside.
- Bag sizes: Head 2×3, Torso 3×3, Back 3×2, Left Arm 3×2, Right Arm 3×2.
- `app.js:renderBag()` re-renders a bag's cells on any state change.

---

## Slice 02 — Item placement and rotation

**Deliverable met:** Items bought from shop go to Hand; click to select; click grid cell to place; press R or Rotate button to rotate in 90° increments; placed items can be picked up and moved.

**Implementation notes:**
- Shape rotation in `game-core.js:rotateCW()`: `[r,c] → [c, maxRow-r]`, normalised to (0,0).
- `game-core.js:canPlace()` checks bounds and overlap against the occupied set; no anatomy check (BEH-001 enforced).
- Hover preview: `onCellHover()` computes absolute cells for the selected item at hover position; `valid-drop` / `invalid-drop` CSS classes highlight the target cells.
- Placed items are visually colour-coded by item definition; `abbrev()` generates a short label.
- Click a placed item to pick it up (returns to Hand in move mode).
- Escape key deselects.

---

## Slice 03 — Shop and body expansion cards

**Deliverable met:** Shop shows 4 random item cards + 1 expansion card per round. Buying deducts gold. Expansion grows only the named bag. Reroll costs 1g. Sell returns floor(cost/2).

**Implementation notes:**
- `game-core.js:generateShopOffers(round)` uses `Math.random()` (acceptable; does not affect battle determinism).
- `ECONOMY` constants: `startingGold=10`, `winReward=6`, `lossReward=4`, `rerollCost=1`, `expansionCost=4`.
- `game-core.js:expandBag()` increments `bag.rows += 1` for the named bag only; other bags unchanged (BEH-002).
- Gold display updates on every `renderHeader()` call; stale values never shown.
- Can't-afford cards rendered with `.cant-afford` (dimmed, no click handler).

---

## Slice 04 — Data-driven item stats and adjacency preview

**Deliverable met:** 12 items defined as data in `ITEMS` object in `game-core.js`. Adjacency bonuses activate and show green glow when qualifying pairs are in the same bag. Moving items removes the indicator immediately.

**Items implemented:**
Machine Gun, Beam Rifle, Missile Pod, Beam Saber, Heavy Cannon, Battery, Ammo Box, Sensor, Targeting Chip, Booster, Armor Plate, Shield.

**Adjacency rules (receiver-side):**
- Beam Rifle + Battery → −20 speed (charge time)
- Machine Gun + Ammo Box → +8 damage/shot
- Missile Pod + Sensor → +20% accuracy
- Beam Saber + Booster → −15 speed
- Heavy Cannon + Sensor → +15% accuracy
- Shield + Armor Plate → +20% block chance (universal rule in `computeEffectiveStats`)
- Any Weapon + Targeting Chip → +15% crit chance (universal rule)

**Implementation notes:**
- `game-core.js:getAdjacentItems()` uses orthogonal cell adjacency within a single bag.
- `game-core.js:getActiveBonuses(bagName, bagItems)` returns active bonus list for UI display.
- `bag-cell.has-bonus` CSS class adds green inset glow on affected cells.
- Info panel shows item stats, tags, and active adjacency rule descriptions.
- ARC-003 enforced: adjacency check passes only `bagItems` from the same bag.
- ARC-004 enforced: item data lives in `ITEMS`; adding a new key is sufficient to add the item to the shop.

---

## Slice 05 — Deterministic ATB simulator

**Deliverable met:** `game-core.js:simulate(playerBuild, enemyBuild, seed)` returns `{events, winner, finalPlayerHP, finalEnemyHP}`. No DOM. No `Math.random()`. Same inputs → byte-equal output.

**Implementation notes:**
- Seeded PRNG: `makePRNG(seed)` — LCG (`s = imul(1664525,s) + 1013904223`).
- ATB loop: find attacker with minimum `nextFire`; advance clock; roll hit (then crit on hit, or consume slot on miss for determinism); apply shield block on hit; emit event; reset `nextFire += speed`.
- Event schema: `{time, attackerSide, bag, itemId, itemName, damage, effects[], playerHP, enemyHP}`.
- `effects` array: `['crit']`, `['blocked']`, `['miss']`, or `[]`.
- Shield state (lastBlock, cooldown) mutated only within the simulation call; not persisted across calls.
- Guard: max 500 events to prevent infinite loops.
- `rng()` called once extra (crit-slot consume) on miss to keep the sequence deterministic across hit/miss branches.

---

## Slice 06 — 2D battle viewer and paused animation playback

**Deliverable met:** Battle screen shows two CSS mech sprites, HP bars, event banner, combat log, Skip Battle button. One animation plays at a time (BEH-004). HP updates after animation completes.

**Implementation notes:**
- `app.js:playBattle()` is an `async` function that awaits `animateEvent()` for each event in sequence — enforcing BEH-004 at the language level (single await chain, no concurrent animations).
- `animateEvent()`: shows banner → fires projectile (Web Animations API) → spawns flash + damage number → updates HP bars.
- Projectile types: `beam` (blue glow), `bullet` (yellow dot), `missile` (orange pill).
- Animation anchors from `data-anchor` attributes on mech-sprite parts: `[data-anchor="head"]`, `[data-anchor="torso"]`, etc.
- Skip Battle: sets `battleAbort = true`; dumps full log; shows result after 600ms delay.
- `setHPBar()` transitions fill width and changes colour at 50%/25% thresholds.
- After all events: `showResult()` shows win/loss overlay with top-damage-bag highlight, final HP, event count.
- ARC-001 enforced: viewer reads from frozen `result.events` array; no simulator callbacks during playback.

---

## Slice 07 — Short run loop with enemy pool

**Deliverable met:** Full playable run from shop → battle → result → next shop. Enemy pool cycles. 5 wins → run clear. 3 losses → run over. Build persists across rounds.

**6 enemy builds implemented:**

| Enemy | Key feature |
|---|---|
| Starter Balanced | Machine Gun (Back rot=1), Armor Plate (Torso), Sensor (Head) |
| Missile Backpack | Missile Pod fills Back, Beam Saber + Ammo Box in Torso |
| Beam Head Goblin | **Beam Rifle in Head** (rot=1), Battery adjacent in Head |
| Shield Turtle | Shield (Left Arm), Armor Plate (Torso), Heavy Cannon (Right Arm) |
| Saber Rush | Two Beam Sabers (L/R Arms), Booster (Back), Targeting Chip (Torso) |
| Heavy Cannon Glass Cannon | Heavy Cannon (Torso), Targeting Chip adjacent, Sensor (Head) |

**Implementation notes:**
- `onResultContinue()` awards gold, increments wins/losses, checks thresholds, advances round, refreshes shop.
- `onNewRun()` resets state to `makeInitialState()` and re-renders.
- Battle seed: `round * 137 + wins * 31 + losses * 17 + 1` — varies per round and outcome history.
- Enemy pool: `(state.round - 1) % ENEMY_POOL.length`.
- ARC-002: no network calls at any point; all enemy data is static JS objects in `game-core.js`.
- No localStorage used; page refresh resets run (by design per locked decision #2).

---

## Architecture decisions made during implementation

- `game-core.js` is UMD-wrapped so it works identically in Node (tests) and browser (game).
- `app.js` wraps everything in an IIFE to avoid polluting global scope.
- Item placement interaction is click-select + click-place (not HTML5 DnD). The hover preview provides equivalent visual feedback for placement decisions.
- The `buildOccupiedSet(bagItems, excludeId)` API allows move-in-place without double-occupancy errors.
- `generateShopOffers` uses `Math.random()` which is acceptable per the handoff spec (shop randomness does not affect battle determinism).
