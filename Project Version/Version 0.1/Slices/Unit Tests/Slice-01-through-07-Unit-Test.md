---
project: mech-bags
doc_type: unit-test-record
version: "0.1"
slices: "01-07"
status: verified
updated: 2026-06-04
---

# Unit Test Record — Slices 01–07

## Test command

```
node prototype/tests/core-tests.js
```

**Result: 66 passed, 0 failed.**

---

## Chronological test run — `node prototype/tests/core-tests.js`

### Section [1] Rotation

- **beam-rifle rot1 = horizontal 1×3** `PASS` — base shape `[[0,0],[1,0],[2,0]]` rotated 1× CW produces `[[0,0],[0,1],[0,2]]`. Confirms that a 3-tall item can be placed horizontally in the 2-row Head bag.
- **4× rotation = identity** `PASS` — four successive CW rotations return exactly the original cell set. Confirms rotation is lossless.
- **machine-gun rot1 = vertical 3×1** `PASS` — `[[0,0],[0,1],[0,2]]` rotated CW once → `[[0,0],[1,0],[2,0]]`. Confirms complementary direction.

### Section [2] Placement validation

- **Beam Rifle (rot1) fits head (2×3) at (0,0)** `PASS` — rotated shape `[[0,0],[0,1],[0,2]]` all within 2 rows × 3 cols. No anatomy check.
- **Beam Rifle (rot0, 3 tall) rejected from head (2 rows)** `PASS` — unrotated shape needs 3 rows; head only has 2 rows → `canPlace` returns false.
- **BEH-001: placeItem succeeds for beam-rifle in Head bag** `PASS` — `placeItem(build, 'head', iid, 'beam-rifle', 0, 0, 1)` returns truthy. No anatomical restriction present.
- **Overlap rejection: sensor at (0,0) conflicts with beam-rifle** `PASS` — occupied cells include (0,0); sensor at same cell rejected.
- **Out of bounds rejection at (5,5) in head (2×3)** `PASS` — row 5 exceeds bag bound.
- **sensor placed at (1,2) in head — no conflict** `PASS` — (1,2) is free after beam-rifle at (0,0)–(0,2).
- **After removeItem, beam-rifle can be placed again at (0,0)** `PASS` — occupied set is recomputed from live items; removed item no longer blocks.

### Section [3] Bag expansion (BEH-002)

- **Head rows +1 after expansion** `PASS` — `expandBag(build, 'head')` increments `bags.head.rows` by 1.
- **Torso rows unchanged after Head expansion** `PASS` — `bags.torso.rows` equals `DEFAULT_BAG_SIZES.torso.rows` (3). Confirmed at assertion time.
- **Back rows unchanged** `PASS`
- **LeftArm rows unchanged** `PASS`
- **RightArm rows unchanged** `PASS`

All five invariants verify BEH-002: expansion targets one named bag only.

### Section [4] Adjacency bonuses (BEH-003, ARC-003)

- **Battery adjacency reduces beam-rifle speed** `PASS` — `computeEffectiveStats` for a beam-rifle with adjacent battery returns `stats.speed < 100` (base speed).
- **Battery gives exact −20 speed to beam-rifle** `PASS` — `stats.speed === 80`. Adjacency rule `effect: 'speed-20'` applied correctly.
- **BEH-003: getActiveBonuses lists Battery bonus** `PASS` — returned array contains an entry whose `desc` includes `'Battery'`.
- **BEH-003: bonus gone when beam-rifle moved to different bag** `PASS` — after `removeItem` on beam-rifle from Head and placing it in Back, `getActiveBonuses('head', headItems)` no longer contains the Battery bonus.
- **ARC-003: no cross-bag bonus when items are in different bags** `PASS` — battery in Head and beam-rifle in Back; head bonus list has no entry sourced from the back beam-rifle.

### Section [5] HP computation

- **Empty build = base 80 HP** `PASS` — `computeHP(initBuild()) === 80`.
- **Armor Plate gives +30 HP** `PASS` — `computeHP` after placing armor-plate = 110. `ITEMS['armor-plate'].hp === 30`.
- **Shield gives +10 HP** `PASS` — placing shield (at (0,2), no overlap with 2×2 armor-plate at (0,0)) → total 120.

### Section [6] Deterministic simulation (ARC-001)

- **Simulation produces events** `PASS` — `r1.events.length > 0` with a beam-rifle build vs Starter Balanced.
- **Winner is player or enemy** `PASS` — `r1.winner` is one of two valid strings.
- **Same seed → same event count** `PASS` — `r1.events.length === r2.events.length` for identical inputs.
- **Same seed → same winner** `PASS`
- **Same seed → same final player HP** `PASS`
- **Same seed → same final enemy HP** `PASS`
- **ARC-001: identical events list (byte-equal) with same seed** `PASS` — `JSON.stringify(r1.events) === JSON.stringify(r2.events)`.
- **Different seeds produce different event sequences** `PASS` — seed 42 vs seed 999 produces different event lists.
- **Events in ascending time order** `PASS` — all `events[i].time >= events[i-1].time`.
- **Event has `time` field** `PASS`
- **Event has `attackerSide` field** `PASS`
- **Event has `bag` field** `PASS`
- **Event has `itemId` field** `PASS`
- **Event has `damage` field** `PASS`
- **Event has `effects` array** `PASS`
- **Event has `playerHP` field** `PASS`
- **Event has `enemyHP` field** `PASS`

### Section [7] Enemy builds validity

- **"Starter Balanced" has no placement conflicts** `PASS`
- **"Missile Backpack" has no placement conflicts** `PASS`
- **"Beam Head Goblin" has no placement conflicts** `PASS`
- **"Shield Turtle" has no placement conflicts** `PASS`
- **"Saber Rush" has no placement conflicts** `PASS`
- **"Heavy Cannon Glass Cannon" has no placement conflicts** `PASS`

Validation method: for each enemy build, load it with `buildFromEnemyData`, then iterate every bag and check that no cell appears in two items' absolute footprints, and that no cell falls outside bag bounds.

- **Beam Head Goblin enemy exists** `PASS`
- **BEH-001: Beam Head Goblin has Beam Rifle in Head bag** `PASS` — `goblinData.items.some(i => i.itemId === 'beam-rifle' && i.bag === 'head')` is true.

### Section [8] Run thresholds

- **WIN_THRESHOLD = 5** `PASS`
- **LOSS_THRESHOLD = 3** `PASS`
- **startingGold = 10** `PASS`
- **winReward = 6** `PASS`
- **lossReward = 4** `PASS`
- **rerollCost = 1** `PASS`

### Section [9] Item costs for sell calculation

All 12 items verified: `Math.floor(item.cost / 2) >= 0`. PASS × 12.

---

## Cross-test invariants

- **Determinism** — all simulation tests ran `simulate()` twice from the same inputs; every output field was byte-equal.
- **Bag independence** — every `expandBag` and adjacency test confirmed that bag operations affect only the targeted bag.
- **No anatomy enforcement** — placement tests never blocked based on item type or bag name; rejection reasons are always geometric.

---

## Manual browser smoke checklist (for Hermes/Tifa)

The following cannot be verified by Node tests and require browser validation:

1. **Open `prototype/index.html` directly** — no server, no install. Five bag grids visible immediately.
2. **Buy an item** — gold decrements; item appears in Hand panel.
3. **Select from Hand, hover over bag** — coloured preview cells appear; red for invalid, green for valid.
4. **Rotate with R key** — item footprint changes orientation in preview.
5. **Place item in any bag including Head** — succeeds if it fits; no anatomy rejection.
6. **Buy a bag expansion card** — only the named bag gains a row; others unchanged.
7. **Active adjacency glow** — place Beam Rifle + Battery in the same bag adjacent; green inset glow appears.
8. **Press Battle!** — battle screen appears; event banner names bag + item (`Head Beam Rifle fires!`); one animation at a time; HP bars update after animation.
9. **Skip Battle** — resolves immediately; shows result overlay.
10. **Continue after result** — wins/losses counter updates; new shop appears; player's build carries over.
11. **Run clear (5 wins)** — RUN CLEAR screen appears; Start New Run resets all state.
12. **Run over (3 losses)** — RUN OVER screen appears; Start New Run resets all state.
13. **No network requests** — DevTools Network tab shows zero external requests during full run.
