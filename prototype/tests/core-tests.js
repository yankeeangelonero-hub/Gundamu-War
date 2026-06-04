// core-tests.js — Node.js tests for Mech Bags game-core.js
// Run: node prototype/tests/core-tests.js

const MechBags = require('../game-core.js');

const {
  ITEMS, ENEMY_POOL, BAG_NAMES, DEFAULT_BAG_SIZES, ECONOMY,
  makePRNG, getRotatedCells, canPlace, buildOccupiedSet,
  getAdjacentItems, computeEffectiveStats, getActiveBonuses,
  initBuild, buildFromEnemyData, placeItem, removeItem, expandBag,
  computeHP, nextIid, simulate,
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

// ─── 1. Rotation ─────────────────────────────────────────────────────────────
console.log('\n[1] Rotation');

{
  // beam-rifle [[0,0],[1,0],[2,0]] rotated 1x CW should become [[0,0],[0,1],[0,2]]
  const base = [[0,0],[1,0],[2,0]];
  const rot1 = getRotatedCells(base, 1);
  const rot1Keys = rot1.map(([r,c]) => `${r},${c}`).sort().join('|');
  assertEqual(rot1Keys, '0,0|0,1|0,2', 'beam-rifle rot1 = horizontal 1x3');

  // 4 rotations returns to original
  const rot4 = getRotatedCells(base, 4);
  const rot4Keys = rot4.map(([r,c]) => `${r},${c}`).sort().join('|');
  const baseKeys = base.map(([r,c]) => `${r},${c}`).sort().join('|');
  assertEqual(rot4Keys, baseKeys, '4x rotation = identity');

  // machine-gun [[0,0],[0,1],[0,2]] rot1 = [[0,0],[1,0],[2,0]]
  const mg = [[0,0],[0,1],[0,2]];
  const mgRot1 = getRotatedCells(mg, 1);
  const mgRot1Keys = mgRot1.map(([r,c]) => `${r},${c}`).sort().join('|');
  assertEqual(mgRot1Keys, '0,0|1,0|2,0', 'machine-gun rot1 = vertical 3x1');
}

// ─── 2. Placement validation ──────────────────────────────────────────────────
console.log('\n[2] Placement validation');

{
  const build = initBuild();

  // Place beam-rifle (rot=1 = horizontal [[0,0],[0,1],[0,2]]) in head (2x3)
  const brCells = getRotatedCells(ITEMS['beam-rifle'].shape, 1);
  assert(canPlace(2, 3, new Set(), 0, 0, brCells), 'Beam Rifle (rot1) fits head (2x3) at (0,0)');

  // beam-rifle vertical (rot=0, 3x1) does NOT fit in head (only 2 rows)
  const brV = getRotatedCells(ITEMS['beam-rifle'].shape, 0);
  assert(!canPlace(2, 3, new Set(), 0, 0, brV), 'Beam Rifle (rot0, 3 tall) rejected from head (2 rows)');

  // BEH-001: beam-rifle CAN be placed in Head with correct rotation
  const iid = nextIid();
  const placed = placeItem(build, 'head', iid, 'beam-rifle', 0, 0, 1);
  assert(placed, 'BEH-001: placeItem succeeds for beam-rifle in Head bag (no anatomy check)');

  // Overlap rejection
  const iid2 = nextIid();
  const placed2 = placeItem(build, 'head', iid2, 'sensor', 0, 0, 0);
  assert(!placed2, 'Overlap rejection: sensor at (0,0) conflicts with beam-rifle');

  // Out of bounds rejection
  const iid3 = nextIid();
  const placed3 = placeItem(build, 'head', iid3, 'sensor', 5, 5, 0);
  assert(!placed3, 'Out of bounds rejection at (5,5) in head (2x3)');

  // Non-overlap cell in same bag succeeds
  const iid4 = nextIid();
  const placed4 = placeItem(build, 'head', iid4, 'sensor', 1, 2, 0);
  assert(placed4, 'sensor placed at (1,2) in head — no conflict');

  // Remove item and verify bag is no longer occupied at those cells
  removeItem(build, iid);
  const afterRemove = placeItem(build, 'head', nextIid(), 'beam-rifle', 0, 0, 1);
  assert(afterRemove, 'After removeItem, beam-rifle can be placed again at (0,0)');
}

// ─── 3. Bag expansion ────────────────────────────────────────────────────────
console.log('\n[3] Bag expansion');

{
  const build = initBuild();
  const headBefore = build.bags.head.rows;
  const torsoBefore = build.bags.torso.rows;

  expandBag(build, 'head');

  assert(build.bags.head.rows === headBefore + 1, 'BEH-002: Head rows +1 after expansion');
  assert(build.bags.torso.rows === torsoBefore, 'BEH-002: Torso rows unchanged after Head expansion');
  assert(build.bags.back.rows === DEFAULT_BAG_SIZES.back.rows, 'BEH-002: Back rows unchanged');
  assert(build.bags.leftArm.rows === DEFAULT_BAG_SIZES.leftArm.rows, 'BEH-002: LeftArm rows unchanged');
  assert(build.bags.rightArm.rows === DEFAULT_BAG_SIZES.rightArm.rows, 'BEH-002: RightArm rows unchanged');
}

// ─── 4. Adjacency bonuses ────────────────────────────────────────────────────
console.log('\n[4] Adjacency bonuses');

{
  const build = initBuild();
  // Place beam-rifle (rot1 = [[0,0],[0,1],[0,2]]) at head(0,0)
  // Place battery (rot0 = [[0,0],[0,1]]) at head(1,0)
  // beam-rifle cell (0,0) is vertically adjacent to battery cell (1,0) → bonus activates
  placeItem(build, 'head', 'br-iid', 'beam-rifle', 0, 0, 1);
  placeItem(build, 'head', 'bat-iid', 'battery', 1, 0, 0);

  const bagItems = build.bags.head.items;
  const brItem = bagItems.find(i => i.itemId === 'beam-rifle');
  const stats = computeEffectiveStats(brItem, bagItems);

  assert(stats.speed < ITEMS['beam-rifle'].speed, 'Battery adjacency reduces beam-rifle speed');
  assertEqual(stats.speed, ITEMS['beam-rifle'].speed - 20, 'Battery gives exact -20 speed to beam-rifle');

  // Active bonus list includes Battery bonus
  const bonuses = getActiveBonuses('head', bagItems);
  assert(bonuses.some(b => b.desc.includes('Battery')), 'BEH-003: getActiveBonuses lists Battery bonus');

  // BEH-003: moving beam-rifle away from battery removes bonus
  removeItem(build, 'br-iid');
  placeItem(build, 'back', 'br-iid2', 'beam-rifle', 0, 0, 0); // different bag
  const headItems2 = build.bags.head.items;
  const bonuses2 = getActiveBonuses('head', headItems2);
  assert(!bonuses2.some(b => b.desc.includes('Battery')), 'BEH-003: bonus gone when beam-rifle moved to different bag');

  // ARC-003: cross-bag items don't give adjacency bonus
  const batInHead = build.bags.head.items.find(i => i.itemId === 'battery');
  const brInBack = build.bags.back.items.find(i => i.itemId === 'beam-rifle');
  if (batInHead && brInBack) {
    const headBonuses = getActiveBonuses('head', build.bags.head.items);
    const backBonuses = getActiveBonuses('back', build.bags.back.items);
    assert(!headBonuses.some(b => b.sourceId === brInBack.instanceId),
      'ARC-003: no cross-bag bonus when items are in different bags');
  }
}

// ─── 5. HP computation ───────────────────────────────────────────────────────
console.log('\n[5] HP computation');

{
  const build = initBuild();
  assert(computeHP(build) === 80, 'Empty build = base 80 HP');

  placeItem(build, 'torso', nextIid(), 'armor-plate', 0, 0, 0); // +30 HP
  assert(computeHP(build) === 110, 'Armor Plate gives +30 HP');

  placeItem(build, 'torso', nextIid(), 'shield', 0, 2, 0); // +10 HP (col 2, no overlap with 2x2 armor-plate)
  assert(computeHP(build) === 120, 'Shield gives +10 HP');
}

// ─── 6. Deterministic simulation ────────────────────────────────────────────
console.log('\n[6] Deterministic simulation (ARC-001 / BEH-005)');

{
  // Build player: beam-rifle in back, sensor adjacent
  const pBuild = initBuild();
  placeItem(pBuild, 'back', nextIid(), 'beam-rifle', 0, 0, 0);  // 3×1 in back col 0
  placeItem(pBuild, 'back', nextIid(), 'sensor', 0, 1, 0);       // sensor at (0,1)

  // Enemy: Starter Balanced
  const eBuild = buildFromEnemyData(ENEMY_POOL[0]);

  const seed = 42;
  const r1 = simulate(pBuild, eBuild, seed);
  const r2 = simulate(pBuild, eBuild, seed);

  assert(r1.events.length > 0, 'Simulation produces events');
  assert(r1.winner === 'player' || r1.winner === 'enemy', 'Winner is player or enemy');
  assertEqual(r1.events.length, r2.events.length, 'Same seed → same event count');
  assertEqual(r1.winner, r2.winner, 'Same seed → same winner');
  assertEqual(r1.finalPlayerHP, r2.finalPlayerHP, 'Same seed → same final player HP');
  assertEqual(r1.finalEnemyHP, r2.finalEnemyHP, 'Same seed → same final enemy HP');

  // Byte-equal events
  const eventsEqual = JSON.stringify(r1.events) === JSON.stringify(r2.events);
  assert(eventsEqual, 'ARC-001: identical events list (byte-equal) with same seed');

  // Different seed → different events (overwhelmingly likely)
  const r3 = simulate(pBuild, eBuild, 999);
  const sameAsDiff = JSON.stringify(r1.events) === JSON.stringify(r3.events);
  assert(!sameAsDiff, 'Different seeds produce different event sequences');

  // Events in ascending time order
  let ascending = true;
  for (let i = 1; i < r1.events.length; i++) {
    if (r1.events[i].time < r1.events[i - 1].time) { ascending = false; break; }
  }
  assert(ascending, 'Events are in ascending time order');

  // Event schema check
  const e0 = r1.events[0];
  assert('time' in e0, 'Event has time field');
  assert('attackerSide' in e0, 'Event has attackerSide field');
  assert('bag' in e0, 'Event has bag field');
  assert('itemId' in e0, 'Event has itemId field');
  assert('damage' in e0, 'Event has damage field');
  assert('effects' in e0 && Array.isArray(e0.effects), 'Event has effects array');
  assert('playerHP' in e0, 'Event has playerHP field');
  assert('enemyHP' in e0, 'Event has enemyHP field');
}

// ─── 7. Enemy builds validity ────────────────────────────────────────────────
console.log('\n[7] Enemy builds validity');

{
  for (const enemyData of ENEMY_POOL) {
    const eBuild = buildFromEnemyData(enemyData);
    // Validate no placement conflicts by checking occupied sets
    let valid = true;
    for (const bagName of BAG_NAMES) {
      const bag = eBuild.bags[bagName];
      const seen = new Set();
      for (const pi of bag.items) {
        const cells = MechBags.getAbsoluteCells(pi.row, pi.col, getRotatedCells(ITEMS[pi.itemId].shape, pi.rotation));
        for (const [r, c] of cells) {
          const key = `${r},${c}`;
          if (seen.has(key) || r < 0 || r >= bag.rows || c < 0 || c >= bag.cols) {
            valid = false;
          }
          seen.add(key);
        }
      }
    }
    assert(valid, `Enemy build "${enemyData.name}" has no placement conflicts`);
  }

  // Beam Head Goblin must have a beam-rifle in the Head bag (BEH-001 demo)
  const goblinData = ENEMY_POOL.find(e => e.name === 'Beam Head Goblin');
  assert(goblinData !== undefined, 'Beam Head Goblin enemy exists');
  if (goblinData) {
    const hasBeamInHead = goblinData.items.some(i => i.itemId === 'beam-rifle' && i.bag === 'head');
    assert(hasBeamInHead, 'BEH-001: Beam Head Goblin has Beam Rifle in Head bag');
  }
}

// ─── 8. Run threshold constants ──────────────────────────────────────────────
console.log('\n[8] Run thresholds');

{
  assertEqual(ECONOMY.WIN_THRESHOLD, 5, 'WIN_THRESHOLD = 5');
  assertEqual(ECONOMY.LOSS_THRESHOLD, 3, 'LOSS_THRESHOLD = 3');
  assertEqual(ECONOMY.startingGold, 10, 'startingGold = 10');
  assertEqual(ECONOMY.winReward, 6, 'winReward = 6');
  assertEqual(ECONOMY.lossReward, 4, 'lossReward = 4');
  assertEqual(ECONOMY.rerollCost, 1, 'rerollCost = 1');
}

// ─── 9. Sell price ───────────────────────────────────────────────────────────
console.log('\n[9] Item costs for sell calculation');

{
  for (const [id, item] of Object.entries(ITEMS)) {
    const sellPrice = Math.floor(item.cost / 2);
    assert(sellPrice >= 0, `${item.name} sell price (floor(cost/2)) = ${sellPrice} >= 0`);
  }
}

// ─── Summary ─────────────────────────────────────────────────────────────────
console.log(`\n${'─'.repeat(50)}`);
console.log(`Results: ${passed} passed, ${failed} failed`);
if (failed > 0) {
  process.exit(1);
} else {
  console.log('All tests passed.');
}
