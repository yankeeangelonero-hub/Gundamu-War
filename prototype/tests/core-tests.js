// core-tests.js — Node.js tests for Mech Bags game-core.js
// Run: node prototype/tests/core-tests.js

const MechBags = require('../game-core.js');

const {
  ITEMS, ENEMY_POOL, ECONOMY, PILOT_XP_TABLE,
  CANVAS_ROWS, CANVAS_COLS, STARTING_OWNED_COORDS, THEATRE_CONFIG,
  BAG_PIECE_DEFS,
  makePRNG, getRotatedCells, getAbsoluteCells,
  canPlace, canPlaceBagPiece, buildOccupiedSet,
  getAdjacentItems, computeEffectiveStats, getActiveBonuses,
  initBuild, buildFromEnemyData, placeItem, removeItem, addBagPiece,
  computeHP, nextIid, simulate,
  makeTheatreState, tickTheatre,
  runSortie, computeSortieRewards, applyPilotRewards, makePilotState,
} = MechBags;

let passed = 0;
let failed = 0;

function assert(condition, label) {
  if (condition) {
    console.log(`  PASS  ${label}`);
    passed++;
  } else {
    console.error(`  FAIL  ${label}`);
    failed++;
  }
}

function assertEqual(a, b, label) {
  const ok = JSON.stringify(a) === JSON.stringify(b);
  if (ok) {
    console.log(`  PASS  ${label}`);
    passed++;
  } else {
    console.error(`  FAIL  ${label}  got=${JSON.stringify(a)}  want=${JSON.stringify(b)}`);
    failed++;
  }
}

// Helper: build an ownedCells set covering given [r,c] pairs
function makeOwned(...coords) {
  return new Set(coords.map(([r, c]) => `${r},${c}`));
}

// Helper: owned cells covering a rectangle
function ownedRect(r0, c0, rows, cols) {
  const s = new Set();
  for (let r = r0; r < r0 + rows; r++)
    for (let c = c0; c < c0 + cols; c++)
      s.add(`${r},${c}`);
  return s;
}

// ─── 1. Rotation ─────────────────────────────────────────────────────────────
console.log('\n[1] Rotation');

{
  const base = [[0,0],[1,0],[2,0]];
  const rot1 = getRotatedCells(base, 1);
  const rot1Keys = rot1.map(([r,c]) => `${r},${c}`).sort().join('|');
  assertEqual(rot1Keys, '0,0|0,1|0,2', 'beam-rifle rot1 = horizontal 1×3');

  const rot4 = getRotatedCells(base, 4);
  const rot4Keys = rot4.map(([r,c]) => `${r},${c}`).sort().join('|');
  const baseKeys = base.map(([r,c]) => `${r},${c}`).sort().join('|');
  assertEqual(rot4Keys, baseKeys, '4× rotation = identity');

  const mg = [[0,0],[0,1],[0,2]];
  const mgRot1 = getRotatedCells(mg, 1);
  const mgRot1Keys = mgRot1.map(([r,c]) => `${r},${c}`).sort().join('|');
  assertEqual(mgRot1Keys, '0,0|1,0|2,0', 'machine-gun rot1 = vertical 3×1');
}

// ─── 2. Canvas placement validation ──────────────────────────────────────────
console.log('\n[2] Canvas placement validation');

{
  const build = initBuild();
  // Starting owned = 3×3 at (0,0)–(2,2)
  const owned = build.canvas.ownedCells;

  // beam-rifle rot1 (horizontal 1×3) fits in owned (0,0)
  const brCells = getRotatedCells(ITEMS['beam-rifle'].shape, 1);
  assert(canPlace(CANVAS_ROWS, CANVAS_COLS, owned, new Set(), 0, 0, brCells),
    'Beam Rifle (rot1) fits owned canvas at (0,0)');

  // beam-rifle rot0 (vertical 3×1) fits in owned col 0 rows 0-2
  const brV = getRotatedCells(ITEMS['beam-rifle'].shape, 0);
  assert(canPlace(CANVAS_ROWS, CANVAS_COLS, owned, new Set(), 0, 0, brV),
    'Beam Rifle (rot0, vertical 3×1) fits in owned 3×3');

  // Reject placement on unowned cell
  const unownedCells = getRotatedCells(ITEMS['sensor'].shape, 0); // 1×1
  assert(!canPlace(CANVAS_ROWS, CANVAS_COLS, owned, new Set(), 5, 5, unownedCells),
    'Placement rejected on unowned cell (5,5)');

  // Place sensor at (0,0)
  const iid = nextIid();
  const placed = placeItem(build, iid, 'sensor', 0, 0, 0);
  assert(placed, 'placeItem succeeds on owned canvas cell');

  // Overlap rejection
  const iid2 = nextIid();
  assert(!placeItem(build, iid2, 'sensor', 0, 0, 0), 'Overlap rejected');

  // Out of bounds rejection
  assert(!canPlace(CANVAS_ROWS, CANVAS_COLS, owned, new Set(), 10, 10, unownedCells),
    'Out-of-bounds placement rejected');

  // Remove and re-place
  removeItem(build, iid);
  assert(placeItem(build, nextIid(), 'sensor', 0, 0, 0), 'After removeItem, cell is free again');
}

// ─── 3. Bag piece purchase expands owned cells ────────────────────────────────
console.log('\n[3] Bag piece — addBagPiece expands owned cells');

{
  const build = initBuild();
  const beforeCount = build.canvas.ownedCells.size;

  // Place 2×2 bag piece at (3,0) — all in bounds
  const shape2x2 = BAG_PIECE_DEFS['bag-2x2'].shape;
  const ok = addBagPiece(build, 3, 0, shape2x2);
  assert(ok, 'addBagPiece returns true for in-bounds placement');
  assert(build.canvas.ownedCells.size === beforeCount + 4, 'Owned cells grew by 4 after 2×2 bag piece');
  assert(build.canvas.ownedCells.has('3,0'), 'Cell (3,0) now owned');
  assert(build.canvas.ownedCells.has('4,1'), 'Cell (4,1) now owned');

  // L-bag
  const shapeL = BAG_PIECE_DEFS['bag-L'].shape;
  const beforeL = build.canvas.ownedCells.size;
  const okL = addBagPiece(build, 5, 0, shapeL);
  assert(okL, 'addBagPiece (L-bag) returns true');
  assert(build.canvas.ownedCells.size === beforeL + 4, 'Owned cells grew by 4 after L-bag');

  // Out of bounds rejected
  const outOk = addBagPiece(build, 7, 7, shape2x2);
  assert(!outOk, 'addBagPiece rejected when shape goes out of canvas bounds');
}

// ─── 4. Placement rejected on unowned cells ───────────────────────────────────
console.log('\n[4] Placement rejected on unowned cells');

{
  const build = initBuild();
  // Try placing in row 5 (unowned)
  const iid = nextIid();
  const placed = placeItem(build, iid, 'sensor', 5, 5, 0);
  assert(!placed, 'placeItem rejected on unowned cell (5,5)');

  // After buying bag piece at (5,5), placement succeeds
  addBagPiece(build, 5, 5, [[0,0]]);
  const placed2 = placeItem(build, iid, 'sensor', 5, 5, 0);
  assert(placed2, 'placeItem succeeds after addBagPiece adds (5,5) to owned');

  // canPlaceBagPiece: in bounds = valid, out of bounds = invalid
  assert(canPlaceBagPiece(CANVAS_ROWS, CANVAS_COLS, 0, 0, [[0,0],[0,1]]), 'Bag piece in-bounds valid');
  assert(!canPlaceBagPiece(CANVAS_ROWS, CANVAS_COLS, 7, 7, [[0,0],[0,1]]), 'Bag piece out-of-bounds invalid');
}

// ─── 5. Rotation and move still work on canvas ────────────────────────────────
console.log('\n[5] Rotation and move on canvas');

{
  const build = initBuild();
  // Place beam-rifle rot0 (vertical) at (0,0)
  const iid = nextIid();
  assert(placeItem(build, iid, 'beam-rifle', 0, 0, 0), 'beam-rifle placed rot0 at (0,0)');

  // Rotate in place to rot1 (horizontal 1×3) — owned 0-2 covers it
  removeItem(build, iid);
  const newRot = 1;
  const rotCells = getRotatedCells(ITEMS['beam-rifle'].shape, newRot);
  const occupied = buildOccupiedSet(build.canvas.items, null);
  assert(canPlace(CANVAS_ROWS, CANVAS_COLS, build.canvas.ownedCells, occupied, 0, 0, rotCells),
    'beam-rifle rot1 fits at (0,0) on owned 3×3');
  placeItem(build, iid, 'beam-rifle', 0, 0, newRot);

  // Move to different owned cell
  const { items } = build.canvas;
  const pi = items.find(i => i.instanceId === iid);
  assert(pi !== undefined, 'placed item found in canvas.items');

  // Move: remove then place at (1,0) rot1 — row 1 col 0,1,2 all owned
  removeItem(build, iid);
  const movedOccupied = buildOccupiedSet(build.canvas.items, null);
  assert(canPlace(CANVAS_ROWS, CANVAS_COLS, build.canvas.ownedCells, movedOccupied, 1, 0, rotCells),
    'beam-rifle rot1 can move to (1,0)');
}

// ─── 6. Adjacency bonuses (canvas-wide) ──────────────────────────────────────
console.log('\n[6] Adjacency bonuses');

{
  const build = initBuild();
  // Expand owned to cover more cells
  addBagPiece(build, 3, 0, [[0,0],[0,1],[0,2],[1,0],[1,1],[1,2]]);

  // beam-rifle rot1 at (0,0): cells (0,0)(0,1)(0,2)
  placeItem(build, 'br-iid', 'beam-rifle', 0, 0, 1);
  // battery rot0 at (1,0): cells (1,0)(1,1) — adjacent to beam-rifle (0,0)
  placeItem(build, 'bat-iid', 'battery', 1, 0, 0);

  const items = build.canvas.items;
  const brItem = items.find(i => i.itemId === 'beam-rifle');
  const stats = computeEffectiveStats(brItem, items);
  assert(stats.speed < ITEMS['beam-rifle'].speed, 'Battery adjacency reduces beam-rifle speed');
  assertEqual(stats.speed, ITEMS['beam-rifle'].speed - 20, 'Battery gives exact -20 speed');

  const bonuses = getActiveBonuses(items);
  assert(bonuses.some(b => b.desc.includes('Battery')), 'getActiveBonuses lists Battery bonus');

  // Moving beam-rifle away removes bonus
  removeItem(build, 'br-iid');
  // Expand to row 3 col 3 area
  addBagPiece(build, 3, 3, [[0,0]]);
  placeItem(build, 'br-iid2', 'beam-rifle', 3, 3, 0);
  const items2 = build.canvas.items;
  const bonuses2 = getActiveBonuses(items2);
  assert(!bonuses2.some(b => b.desc.includes('Battery')), 'Bonus gone when beam-rifle is no longer adjacent');
}

// ─── 7. HP computation ───────────────────────────────────────────────────────
console.log('\n[7] HP computation');

{
  const build = initBuild();
  assertEqual(computeHP(build), 80, 'Empty canvas = base 80 HP');

  placeItem(build, nextIid(), 'armor-plate', 0, 0, 0); // 2×2 at (0,0): cells (0,0)(0,1)(1,0)(1,1)
  assertEqual(computeHP(build), 110, 'Armor Plate gives +30 HP');

  // shield: 3×1 vertical — place at (0,2)… but owned is 3×3 so (0,2)(1,2)(2,2) all owned
  placeItem(build, nextIid(), 'shield', 0, 2, 0);
  assertEqual(computeHP(build), 120, 'Shield gives +10 HP');
}

// ─── 8. Deterministic simulation ─────────────────────────────────────────────
console.log('\n[8] Deterministic simulation');

{
  const pBuild = initBuild();
  addBagPiece(pBuild, 3, 0, [[0,0],[1,0],[2,0],[3,0]]);
  placeItem(pBuild, nextIid(), 'beam-rifle', 0, 0, 0);
  placeItem(pBuild, nextIid(), 'sensor', 3, 0, 0);

  const eBuild = buildFromEnemyData(ENEMY_POOL[0]);
  const seed = 42;
  const r1 = simulate(pBuild, eBuild, seed);
  const r2 = simulate(pBuild, eBuild, seed);

  assert(r1.events.length > 0, 'Simulation produces events');
  assert(r1.winner === 'player' || r1.winner === 'enemy', 'Winner is player or enemy');
  assertEqual(r1.events.length, r2.events.length, 'Same seed → same event count');
  assertEqual(r1.winner, r2.winner, 'Same seed → same winner');
  assertEqual(r1.finalPlayerHP, r2.finalPlayerHP, 'Same seed → same final player HP');
  assertEqual(r1.finalEnemyHP,  r2.finalEnemyHP,  'Same seed → same final enemy HP');

  assert(JSON.stringify(r1.events) === JSON.stringify(r2.events),
    'ARC-007: identical events list (byte-equal) with same seed');

  const r3 = simulate(pBuild, eBuild, 999);
  assert(JSON.stringify(r1.events) !== JSON.stringify(r3.events),
    'Different seeds produce different event sequences');

  let ascending = true;
  for (let i = 1; i < r1.events.length; i++) {
    if (r1.events[i].time < r1.events[i - 1].time) { ascending = false; break; }
  }
  assert(ascending, 'Events are in ascending time order');

  const e0 = r1.events[0];
  assert('time'         in e0, 'Event has time field');
  assert('attackerSide' in e0, 'Event has attackerSide field');
  assert('itemId'       in e0, 'Event has itemId field');
  assert('damage'       in e0, 'Event has damage field');
  assert(Array.isArray(e0.effects), 'Event has effects array');
  assert('playerHP'     in e0, 'Event has playerHP field');
  assert('enemyHP'      in e0, 'Event has enemyHP field');
}

// ─── 9. Enemy builds validity (canvas model) ──────────────────────────────────
console.log('\n[9] Enemy builds validity');

{
  assertEqual(ENEMY_POOL.length, 10, 'ENEMY_POOL has exactly 10 builds');

  for (const enemyData of ENEMY_POOL) {
    const eBuild = buildFromEnemyData(enemyData);
    const { items, ownedCells } = eBuild.canvas;
    let valid = true;

    const seen = new Set();
    for (const pi of items) {
      const cells = getAbsoluteCells(pi.row, pi.col,
        getRotatedCells(ITEMS[pi.itemId].shape, pi.rotation));
      for (const [r, c] of cells) {
        const key = `${r},${c}`;
        if (seen.has(key)) { valid = false; break; }
        if (r < 0 || r >= CANVAS_ROWS || c < 0 || c >= CANVAS_COLS) { valid = false; break; }
        if (!ownedCells.has(key)) { valid = false; break; }
        seen.add(key);
      }
    }
    assert(valid, `Enemy build "${enemyData.name}" has no conflicts and all items on owned cells`);
    assert(typeof enemyData.archetype === 'string', `Enemy "${enemyData.name}" has archetype field`);
  }
}

// ─── 10. Run threshold constants ─────────────────────────────────────────────
console.log('\n[10] Run thresholds and economy');

{
  assertEqual(ECONOMY.WIN_THRESHOLD,  5,  'WIN_THRESHOLD = 5');
  assertEqual(ECONOMY.LOSS_THRESHOLD, 3,  'LOSS_THRESHOLD = 3');
  assertEqual(ECONOMY.startingGold,   10, 'startingGold = 10');
  assertEqual(ECONOMY.winReward,      6,  'winReward = 6');
  assertEqual(ECONOMY.lossReward,     4,  'lossReward = 4');
  assertEqual(ECONOMY.rerollCost,     1,  'rerollCost = 1');
}

// ─── 11. Item sell prices ─────────────────────────────────────────────────────
console.log('\n[11] Item sell prices');

{
  for (const [id, item] of Object.entries(ITEMS)) {
    assert(Math.floor(item.cost / 2) >= 0, `${item.name} sell price >= 0`);
  }
}

// ─── 12. Sortie resolver — determinism ────────────────────────────────────────
console.log('\n[12] Sortie resolver — determinism');

{
  const pBuild = initBuild();
  addBagPiece(pBuild, 3, 0, [[0,0],[1,0],[2,0]]);
  placeItem(pBuild, nextIid(), 'beam-rifle', 0, 0, 0);
  placeItem(pBuild, nextIid(), 'sensor', 3, 0, 0);

  const seed = 42;
  const s1 = runSortie(pBuild, ENEMY_POOL, seed);
  const s2 = runSortie(pBuild, ENEMY_POOL, seed);

  assertEqual(s1.poolSize,  10, 'Sortie resolves against all 10 enemies');
  assertEqual(s1.results.length, 10, 'results has 10 entries');
  assertEqual(s1.wins + s1.losses, 10, 'wins + losses = 10');
  assertEqual(s1.sortieSeed, seed, 'Sortie preserves seed');
  assertEqual(s1.wins,   s2.wins,   'Same seed → same wins');
  assertEqual(s1.losses, s2.losses, 'Same seed → same losses');
  assertEqual(
    JSON.stringify(s1.results.map(r => ({ w: r.winner, e: r.enemyName }))),
    JSON.stringify(s2.results.map(r => ({ w: r.winner, e: r.enemyName }))),
    'Same seed → identical per-fight winners'
  );

  const r0 = s1.results[0];
  assert('enemyIdx'       in r0, 'Result has enemyIdx');
  assert('enemyName'      in r0, 'Result has enemyName');
  assert('enemyArchetype' in r0, 'Result has enemyArchetype');
  assert('winner'         in r0, 'Result has winner');
  assert('finalPlayerHP'  in r0, 'Result has finalPlayerHP');
  assert('finalEnemyHP'   in r0, 'Result has finalEnemyHP');
  assert(Array.isArray(r0.events), 'Result has events array');
}

// ─── 13. Theatre scheduler — not instant ─────────────────────────────────────
console.log('\n[13] Theatre scheduler — real-time pacing');

{
  const pBuild = initBuild();
  addBagPiece(pBuild, 3, 0, [[0,0],[1,0],[2,0]]);
  placeItem(pBuild, nextIid(), 'beam-rifle', 0, 0, 0);

  const FIXED_CONFIG = {
    FIGHT_DURATION_MIN: 15000,
    FIGHT_DURATION_MAX: 15000, // fixed for deterministic tests
    VICTORY_DOWNTIME:    5000,
    LOSS_DOWNTIME:      15000,
  };

  const ts = makeTheatreState(42, FIXED_CONFIG);
  assertEqual(ts.phase, 'fighting', 'Theatre starts in fighting phase');
  assertEqual(ts.results.length, 0, 'No results yet at start');

  // Before fight ends: no result
  tickTheatre(ts, pBuild, ENEMY_POOL, 5000, FIXED_CONFIG);
  assertEqual(ts.results.length, 0, 'No result after 5s (fight not done)');
  assert(ts.phase === 'fighting', 'Still fighting after 5s');

  // Advance to just past fight duration: fight resolves
  tickTheatre(ts, pBuild, ENEMY_POOL, 10001, FIXED_CONFIG);
  assertEqual(ts.results.length, 1, 'Fight resolves after 15s elapsed');
  assert(ts.phase === 'victory-downtime' || ts.phase === 'loss-downtime',
    'In downtime phase after first fight');

  const firstResult = ts.results[0];
  assert(firstResult.winner === 'player' || firstResult.winner === 'enemy',
    'Fight has a valid winner');
}

// ─── 14. Theatre — fight duration range ──────────────────────────────────────
console.log('\n[14] Theatre — fight duration in 15–30s range');

{
  const pBuild = initBuild();
  placeItem(pBuild, nextIid(), 'machine-gun', 0, 0, 0);

  // Run 5 sorties and check fight durations fall in range
  for (let seed = 1; seed <= 5; seed++) {
    const ts = makeTheatreState(seed); // default THEATRE_CONFIG
    assert(ts.phaseDuration >= THEATRE_CONFIG.FIGHT_DURATION_MIN &&
           ts.phaseDuration <= THEATRE_CONFIG.FIGHT_DURATION_MAX,
      `Fight duration for seed ${seed} is in [15000, 30000] range (got ${ts.phaseDuration})`);
  }
}

// ─── 15. Theatre — victory/loss downtime values ───────────────────────────────
console.log('\n[15] Theatre — victory/loss downtime');

{
  // Stronger build that can win some fights
  const pBuild = initBuild();
  addBagPiece(pBuild, 3, 0, [[0,0],[1,0]]);
  placeItem(pBuild, nextIid(), 'beam-rifle', 0, 0, 0);
  placeItem(pBuild, nextIid(), 'armor-plate', 0, 1, 0);
  addBagPiece(pBuild, 0, 1, [[0,0],[0,1],[1,0],[1,1]]);
  placeItem(pBuild, nextIid(), 'sensor', 3, 0, 0);

  const FIXED_CONFIG = {
    FIGHT_DURATION_MIN: 15000,
    FIGHT_DURATION_MAX: 15000,
    VICTORY_DOWNTIME:    5000,
    LOSS_DOWNTIME:      15000,
  };

  let sawVictoryDowntime = false;
  let sawLossDowntime    = false;

  for (let seed = 1; seed <= 50 && (!sawVictoryDowntime || !sawLossDowntime); seed++) {
    const ts = makeTheatreState(seed, FIXED_CONFIG);
    tickTheatre(ts, pBuild, ENEMY_POOL, 15001, FIXED_CONFIG);
    if (ts.phase === 'victory-downtime') {
      assertEqual(ts.phaseDuration, 5000, `Victory downtime = 5000ms (seed ${seed})`);
      sawVictoryDowntime = true;
    } else if (ts.phase === 'loss-downtime') {
      assertEqual(ts.phaseDuration, 15000, `Loss downtime = 15000ms (seed ${seed})`);
      sawLossDowntime = true;
    }
  }
  assert(sawVictoryDowntime, 'Observed at least one victory downtime across seeds 1-50');
  assert(sawLossDowntime,    'Observed at least one loss downtime across seeds 1-50');
}

// ─── 16. Theatre — loop continues until retreat ───────────────────────────────
console.log('\n[16] Theatre — loop until retreat');

{
  const pBuild = initBuild();
  placeItem(pBuild, nextIid(), 'beam-saber', 0, 0, 0);

  const FAST_CONFIG = {
    FIGHT_DURATION_MIN: 1,
    FIGHT_DURATION_MAX: 1,
    VICTORY_DOWNTIME:   1,
    LOSS_DOWNTIME:      1,
  };

  const ts = makeTheatreState(7, FAST_CONFIG);
  // Advance 10 fight-cycles worth of virtual time
  for (let i = 0; i < 30; i++) {
    tickTheatre(ts, pBuild, ENEMY_POOL, 10, FAST_CONFIG);
  }
  assert(ts.results.length >= 3, `Theatre ran multiple fights (got ${ts.results.length})`);
  assert(ts.phase !== 'retreated', 'Loop still active — not retreated');

  // Retreat
  ts.phase = 'retreated';
  const countBefore = ts.results.length;
  tickTheatre(ts, pBuild, ENEMY_POOL, 10000, FAST_CONFIG);
  assertEqual(ts.results.length, countBefore, 'No new fights added after retreat');
}

// ─── 17. Theatre — retreat claims accumulated results ─────────────────────────
console.log('\n[17] Theatre — retreat claims accumulated results');

{
  const pBuild = initBuild();
  addBagPiece(pBuild, 3, 0, [[0,0],[1,0]]);
  placeItem(pBuild, nextIid(), 'beam-rifle', 0, 0, 0);
  placeItem(pBuild, nextIid(), 'sensor', 3, 0, 0);

  const FAST_CONFIG = {
    FIGHT_DURATION_MIN: 1,
    FIGHT_DURATION_MAX: 1,
    VICTORY_DOWNTIME:   1,
    LOSS_DOWNTIME:      1,
  };

  const ts = makeTheatreState(99, FAST_CONFIG);
  for (let i = 0; i < 50; i++) tickTheatre(ts, pBuild, ENEMY_POOL, 10, FAST_CONFIG);

  assert(ts.results.length > 0, 'Theatre accumulated results before retreat');
  assert(ts.wins + ts.losses === ts.results.length, 'wins + losses = total fights');

  // Compute rewards from accumulated results (same API as batch sortie)
  const pilot = makePilotState();
  const rewards = computeSortieRewards(ts, pilot);
  assert(typeof rewards.xpGained   === 'number' && rewards.xpGained   >= 0, 'xpGained is non-negative');
  assert(typeof rewards.lootGained === 'number' && rewards.lootGained  > 0, 'lootGained is positive');
  assert(['Ready','Fatigued','Wounded','Out of Service'].includes(rewards.newCondition),
    'newCondition is a valid condition');
}

// ─── 18. Loot deterministic ───────────────────────────────────────────────────
console.log('\n[18] Loot deterministic');

{
  const pBuild = initBuild();
  placeItem(pBuild, nextIid(), 'beam-rifle', 0, 0, 0);
  const sortie = runSortie(pBuild, ENEMY_POOL, 55);
  const pilot  = makePilotState();
  const r1 = computeSortieRewards(sortie, pilot);
  const r2 = computeSortieRewards(sortie, pilot);
  assertEqual(r1.xpGained,     r2.xpGained,     'computeSortieRewards deterministic — xp');
  assertEqual(r1.lootGained,   r2.lootGained,   'computeSortieRewards deterministic — loot');
  assertEqual(r1.newCondition, r2.newCondition,  'computeSortieRewards deterministic — condition');
}

// ─── 19. Pilot XP / level / skills ───────────────────────────────────────────
console.log('\n[19] Pilot XP, level, skills');

{
  const pBuild = initBuild();
  placeItem(pBuild, nextIid(), 'beam-rifle', 0, 0, 0);

  const pilot  = makePilotState();
  const sortie = runSortie(pBuild, ENEMY_POOL, 77);
  const rew    = computeSortieRewards(sortie, pilot);

  assert(typeof rew.xpGained    === 'number' && rew.xpGained    >= 0, 'xpGained non-negative');
  assert(typeof rew.lootGained  === 'number' && rew.lootGained   > 0, 'lootGained positive');
  assert(typeof rew.newCondition === 'string', 'newCondition is string');
  assert(typeof rew.learningSignal === 'string' && rew.learningSignal.length > 0,
    'learningSignal non-empty');

  const newPilot = applyPilotRewards(pilot, rew);
  assert(newPilot.xp >= 0,                       'Pilot XP non-negative after rewards');
  assert(newPilot.level >= pilot.level,           'Pilot level >= initial');
  assert(newPilot.sorties === pilot.sorties + 1,  'Sortie count incremented');
  assert(newPilot.condition === rew.newCondition, 'Condition matches reward');

  // XP table is strictly ascending
  for (let i = 1; i < PILOT_XP_TABLE.length; i++) {
    assert(PILOT_XP_TABLE[i] > PILOT_XP_TABLE[i - 1], `XP table level ${i} > level ${i-1}`);
  }

  // Level-up works
  const levelPilot = makePilotState();
  const bigReward  = { xpGained: PILOT_XP_TABLE[1], lootGained: 5, newCondition: 'Ready', skillProgress: {} };
  const leveled    = applyPilotRewards(levelPilot, bigReward);
  assertEqual(leveled.level, 2, 'Pilot levels up when XP crosses threshold');
  assert(leveled.xp >= 0, 'Pilot XP non-negative after level-up');
}

// ─── 20. Existing simulation determinism unchanged ────────────────────────────
console.log('\n[20] Simulation determinism preserved');

{
  const p = initBuild();
  addBagPiece(p, 3, 0, [[0,0],[1,0]]);
  placeItem(p, nextIid(), 'machine-gun',  0, 0, 0);
  placeItem(p, nextIid(), 'ammo-box',     1, 0, 0);
  placeItem(p, nextIid(), 'armor-plate',  0, 1, 0);

  // Expand owned for armor-plate at (0,1)(0,2)(1,1)(1,2)
  addBagPiece(p, 0, 1, [[0,0],[0,1],[1,0],[1,1]]);

  const e = buildFromEnemyData(ENEMY_POOL[4]); // Saber Rush
  const r1 = simulate(p, e, 12345);
  const r2 = simulate(p, e, 12345);
  assert(JSON.stringify(r1) === JSON.stringify(r2),
    'Identical simulate() output for same seed (byte-equal)');
}

// ─── Summary ─────────────────────────────────────────────────────────────────
console.log(`\n${'─'.repeat(50)}`);
console.log(`Results: ${passed} passed, ${failed} failed`);
if (failed > 0) {
  process.exit(1);
} else {
  console.log('All tests passed.');
}
