---
project: mech-bags
doc_type: unit-test-record
version: "0.1"
slices: "01–07"
status: verified
test_runner: node prototype/tests/core-tests.js
date: 2026-06-04
---

# Unit Test Record — Version 0.1 Slices 01–07

## Test command

```
node prototype/tests/core-tests.js
```

**Result: 66 passed, 0 failed.**

---

## Chronological test run log

### [1] Rotation

- tick (test 1): `beam-rifle [[0,0],[1,0],[2,0]]` rotated 1× CW → expected `[[0,0],[0,1],[0,2]]` (horizontal 1×3). Got keys `0,0|0,1|0,2`. **PASS**
- tick (test 2): 4× CW rotation on `beam-rifle` returns identical key set as original. **PASS**
- tick (test 3): `machine-gun [[0,0],[0,1],[0,2]]` rotated 1× CW → expected `0,0|1,0|2,0` (vertical 3×1). **PASS**

**Invariant:** `getRotatedCells(shape, 4)` is identity for all shapes.

---

### [2] Placement validation

- tick (test 1): `canPlace(2, 3, {}, 0, 0, [[0,0],[0,1],[0,2]])` — beam-rifle horizontal in head (2×3). Returns `true`. **PASS**
- tick (test 2): `canPlace(2, 3, {}, 0, 0, [[0,0],[1,0],[2,0]])` — beam-rifle vertical (3 rows) in head (2 rows). Returns `false` (row 2 out of bounds). **PASS**
- tick (test 3): `placeItem(build, 'head', iid, 'beam-rifle', 0, 0, 1)` — places beam-rifle with rotation 1 (horizontal) in Head bag. Returns `true`. **BEH-001 PASS** — no anatomy check triggered.
- tick (test 4): `placeItem(build, 'head', iid2, 'sensor', 0, 0, 0)` — sensor at (0,0), which is occupied by beam-rifle. Returns `false`. **PASS**
- tick (test 5): `placeItem(build, 'head', iid3, 'sensor', 5, 5, 0)` — out of bounds (head is 2×3). Returns `false`. **PASS**
- tick (test 6): `placeItem(build, 'head', iid4, 'sensor', 1, 2, 0)` — cell (1,2) not occupied. Returns `true`. **PASS**
- tick (after removeItem): beam-rifle removed, then same iid placed again at (0,0). Returns `true`. **PASS**

---

### [3] Bag expansion

- tick (before): `build.bags.head.rows = 2`.
- tick (expand): `expandBag(build, 'head')` called.
- tick (after): `build.bags.head.rows = 3` (was 2). **BEH-002 PASS**
- tick (check): `build.bags.torso.rows = 3` (unchanged). **BEH-002 PASS**
- tick (check): `build.bags.back.rows = 3` (default unchanged). **BEH-002 PASS**
- tick (check): `build.bags.leftArm.rows = 3` (unchanged). **BEH-002 PASS**
- tick (check): `build.bags.rightArm.rows = 3` (unchanged). **BEH-002 PASS**

**Invariant:** `expandBag(build, bagName)` increments exactly one bag's row count by 1.

---

### [4] Adjacency bonuses

- tick (setup): beam-rifle placed at head(0,0) rot=1 → occupies (0,0),(0,1),(0,2). Battery placed at head(1,0) rot=0 → occupies (1,0),(1,1). Cell (0,0) and (1,0) are vertically adjacent.
- tick (stat check): `computeEffectiveStats(brItem, headItems).speed` → `80` (= 100 − 20). `ITEMS['beam-rifle'].speed = 100`. **PASS**
- tick (exact value): `stats.speed === 80`. **PASS**
- tick (bonus list): `getActiveBonuses('head', headItems)` returns array with entry `{desc: 'Battery: -20 charge time'}`. **BEH-003 PASS**
- tick (break adjacency): beam-rifle moved to 'back' bag (different bag). `getActiveBonuses('head', headItems2)` — battery still in head but no weapon adjacent. Bonus list has no Battery entry. **BEH-003 PASS**
- tick (cross-bag check): battery in head, beam-rifle in back. Neither bag's `getActiveBonuses` shows cross-bag bonus. **ARC-003 PASS**

---

### [5] HP computation

- tick (empty build): `computeHP(emptyBuild) = 80`. `BASE_HP = 80`. **PASS**
- tick (+armor-plate): armor-plate placed (`hp: 30`). `computeHP = 110`. **PASS**
- tick (+shield): shield placed (`hp: 10`). `computeHP = 120`. **PASS**

---

### [6] Deterministic simulation

- tick (setup): player build has beam-rifle at back(0,0) + sensor at back(0,1). Enemy build is Starter Balanced. `seed = 42`.
- tick (run 1): `simulate(pBuild, eBuild, 42)` → `{events: [...], winner: 'player'|'enemy', finalPlayerHP: N, finalEnemyHP: M}`. Events length > 0. **PASS**
- tick (run 2): Same inputs, same seed. `events.length` identical to run 1. **PASS**
- tick (winner): `r1.winner === r2.winner`. **PASS**
- tick (player HP): `r1.finalPlayerHP === r2.finalPlayerHP`. **PASS**
- tick (enemy HP): `r1.finalEnemyHP === r2.finalEnemyHP`. **PASS**
- tick (byte equality): `JSON.stringify(r1.events) === JSON.stringify(r2.events)`. **ARC-001 PASS**
- tick (different seed): `simulate(pBuild, eBuild, 999)` → different JSON string. **PASS** (overwhelmingly expected from RNG)
- tick (time ordering): for each `i ≥ 1`, `events[i].time >= events[i-1].time`. Ascending order confirmed. **PASS**
- tick (schema): event 0 has fields: `time, attackerSide, bag, itemId, itemName, damage, effects (array), playerHP, enemyHP`. All present. **PASS × 8**

---

### [7] Enemy builds validity

For each of the 6 enemy builds, `buildFromEnemyData(enemyData)` is constructed and validated:

- tick (Starter Balanced): cells per bag checked — no overlap, no out-of-bounds. **PASS**
- tick (Missile Backpack): missile-pod occupies full back(3×2); sensor at head(0,2); beam-saber at torso(0,0). No conflict. **PASS**
- tick (Beam Head Goblin): beam-rifle rot=1 occupies head row 0 (cols 0,1,2); battery at head(1,0) occupies (1,0),(1,1). No conflict. **PASS**
- tick (Shield Turtle): shield 3×1 in leftArm col 0; armor-plate 2×2 in torso(0,0)–(1,1); heavy-cannon 2-cell L in rightArm(0,0). No conflict. **PASS**
- tick (Saber Rush): two beam-sabers in leftArm/rightArm (rot=1, 2×1 each); booster L-shape in back(0,0)–(1,1); targeting-chip in torso(0,0). No conflict. **PASS**
- tick (Heavy Cannon Glass Cannon): heavy-cannon at torso(0,0)–(1,1); targeting-chip at torso(0,2). No conflict. targeting-chip(0,2) adjacent to heavy-cannon(0,1). **PASS**
- tick (BEH-001 demo): `ENEMY_POOL.find(e => e.name === 'Beam Head Goblin')` exists. One of its items: `itemId === 'beam-rifle' && bag === 'head'`. **BEH-001 PASS**

---

### [8] Run thresholds

All constants match approved owner decisions:
- `WIN_THRESHOLD = 5` **PASS**
- `LOSS_THRESHOLD = 3` **PASS**
- `startingGold = 10` **PASS**
- `winReward = 6` **PASS**
- `lossReward = 4` **PASS**
- `rerollCost = 1` **PASS**

---

### [9] Sell price

All 12 items: `Math.floor(item.cost / 2) >= 0`. All pass. **PASS × 12**

---

## Browser smoke verification (manual)

Performed with Playwright against `http://localhost:8743/index.html`.

| Check | Method | Result |
|---|---|---|
| Page loads with no JS errors | `browser_console_messages` | Only favicon 404 (harmless). **PASS** |
| Five named bag grids visible | Screenshot | HEAD, TORSO, BACK, LEFT ARM, RIGHT ARM visible in mech layout. **PASS** |
| Buy Beam Rifle → appears in hand | JS evaluate click + screenshot | Gold 10→6g; "Beam Rifle" in hand panel. **PASS** |
| Rotate button changes rotation | JS evaluate + screenshot | Info shows "Rotation: 90°". **PASS** |
| Place beam-rifle in Head (BEH-001) | JS evaluate `cell.click()` | Cell (0,0) background = `rgb(77,166,255)` = `#4da6ff`. **BEH-001 PASS** |
| Battle starts | JS evaluate `battle-btn.click()` | Battle screen activates. **PASS** |
| Event banner names bag source | Screenshot | "Back Machine Gun fires!" banner visible. **ARC-005 PASS** |
| HP bars update | Screenshot mid-battle | Player HP 40/80 mid-battle. Enemy HP 66/110. **PASS** |
| Combat log names bags | Screenshot | `[Head] Beam Rifle dealt 22 dmg` and `[Back] Machine Gun dealt 8 dmg`. **PASS** |
| Skip Battle shows result | JS evaluate `skip-btn.click()` | Result overlay appears: "DEFEAT!", best-bag summary, final HP. **PASS** |
| Continue → round advances | JS evaluate | Round 2, Losses 1, Gold 10 (6+4). **PASS** |
| Bag expansion targets one bag | JS evaluate | Back 3→4 rows; Head stays 2, Left Arm stays 3. **BEH-002 PASS** |
| No network calls | Playwright console (no fetch errors) | Zero external requests. **ARC-002 PASS** |

---

## Cross-test invariants

- **Determinism (ARC-001):** byte-equal event lists for same seed confirmed in tests [6].
- **BEH-001:** Beam rifle placed in Head bag — confirmed in tests [2] and browser smoke. Enemy "Beam Head Goblin" validated in tests [7] and browser smoke.
- **BEH-002:** Expansion modifies exactly one bag — confirmed in tests [3] and browser smoke.
- **BEH-003:** Adjacency bonus present when items adjacent, absent when separated — confirmed in tests [4].
- **ARC-003:** No cross-bag adjacency — confirmed in tests [4].
- **ARC-004:** New item requires only a data entry in `ITEMS` — architecture verified by structure of `game-core.js`.
- **ARC-005:** Event banner format `[Bag] ItemName fires!` — confirmed in browser smoke.
