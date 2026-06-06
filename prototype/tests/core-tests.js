// core-tests.js - Node.js tests for Kitbash Mecha v0.3 core.
// Run: node prototype/tests/core-tests.js

const G = require('../game-core.js');

let passed = 0;
let failed = 0;

function assert(condition, label) {
  if (condition) {
    console.log(`  PASS  ${label}`);
    passed += 1;
  } else {
    console.error(`  FAIL  ${label}`);
    failed += 1;
  }
}

function assertEqual(actual, expected, label) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (ok) {
    console.log(`  PASS  ${label}`);
    passed += 1;
  } else {
    console.error(`  FAIL  ${label}  got=${JSON.stringify(actual)}  want=${JSON.stringify(expected)}`);
    failed += 1;
  }
}

function section(label) {
  console.log(`\n[${label}]`);
}

function mountByDef(state, defId, parentNodeId, hpId) {
  const part = state.inventory.find(item => item.defId === defId);
  assert(!!part, `inventory has ${defId}`);
  const result = G.attachOwnedPart(state.tree, state.inventory, parentNodeId, hpId, part.ownedInstanceId);
  assert(result.ok, `attach ${defId} to ${parentNodeId}/${hpId}: ${result.reason}`);
  state.tree = result.tree;
  state.inventory = result.inventory;
  return { nodeId: result.nodeId, ownedInstanceId: part.ownedInstanceId };
}

section('1. Recursive typed build tree and canonical nodeIds');

const buildState = {
  tree: G.createBuildTree(),
  inventory: G.makeInventory([
    'missile-rack',
    'micro-missile',
    'micro-missile',
    'he-warhead',
    'emp-warhead',
    'shoulder-cannon',
    'backpack-thruster',
    'armor-plate',
    'targeting-sensor',
  ], 'test-owned'),
};

const rackMount = mountByDef(buildState, 'missile-rack', 'frame', 'hand.R');
const missile0 = mountByDef(buildState, 'micro-missile', 'frame/hand.R', 'p0');
const he = mountByDef(buildState, 'he-warhead', 'frame/hand.R/p0', 'warhead');
const missile1 = mountByDef(buildState, 'micro-missile', 'frame/hand.R', 'p1');
const emp = mountByDef(buildState, 'emp-warhead', 'frame/hand.R/p1', 'warhead');
mountByDef(buildState, 'shoulder-cannon', 'frame', 'shoulder.L');
mountByDef(buildState, 'backpack-thruster', 'frame', 'backpack');
mountByDef(buildState, 'armor-plate', 'frame', 'torso');
mountByDef(buildState, 'targeting-sensor', 'frame', 'head');

assertEqual(rackMount.nodeId, 'frame/hand.R', 'rack canonical nodeId is a hardpoint path');
assertEqual(missile0.nodeId, 'frame/hand.R/p0', 'first missile nodeId uses p0');
assertEqual(missile1.nodeId, 'frame/hand.R/p1', 'second missile nodeId uses p1');
assertEqual(he.nodeId, 'frame/hand.R/p0/warhead', 'HE warhead reaches depth 4');
assertEqual(emp.nodeId, 'frame/hand.R/p1/warhead', 'EMP warhead reaches depth 4');
assert(G.getNode(buildState.tree, missile0.nodeId).defId === G.getNode(buildState.tree, missile1.nodeId).defId,
  'duplicate micro missiles share defId');
assert(missile0.nodeId !== missile1.nodeId, 'duplicate defIds have distinct mounted nodeIds');
assert(G.validateTree(buildState.tree).ok, 'assembled tree validates');

section('2. Owned inventory identity survives detach and remount');

const rackBeforeDetach = G.getNode(buildState.tree, 'frame/hand.R');
const mountedOwnedIds = [
  rackBeforeDetach.ownedInstanceId,
  rackBeforeDetach.children.p0.ownedInstanceId,
  rackBeforeDetach.children.p1.ownedInstanceId,
  rackBeforeDetach.children.p0.children.warhead.ownedInstanceId,
  rackBeforeDetach.children.p1.children.warhead.ownedInstanceId,
];

const detached = G.detachNode(buildState.tree, buildState.inventory, 'frame/hand.R');
assert(detached.ok, `detach rack subtree: ${detached.reason}`);
assertEqual(detached.ownedPart.ownedInstanceId, mountedOwnedIds[0], 'detached root keeps ownedInstanceId');
assertEqual(detached.ownedPart.children.p0.ownedInstanceId, mountedOwnedIds[1], 'p0 missile keeps ownedInstanceId');
assertEqual(detached.ownedPart.children.p1.ownedInstanceId, mountedOwnedIds[2], 'p1 missile keeps ownedInstanceId');
assertEqual(detached.ownedPart.children.p0.children.warhead.ownedInstanceId, mountedOwnedIds[3],
  'p0 warhead keeps ownedInstanceId');
assert(!detached.inventory.some(part => part.ownedInstanceId.startsWith('frame/')),
  'inventory ownedInstanceIds are not mounted nodeIds');
assertEqual(G.countOwnedSubtree(detached.ownedPart), 5, 'detached inventory entry contains full subtree');

const remount = G.attachOwnedPart(
  detached.tree,
  detached.inventory,
  'frame',
  'hand.L',
  detached.ownedPart.ownedInstanceId
);
assert(remount.ok, 'detached rack subtree can remount elsewhere');
assertEqual(G.getNode(remount.tree, 'frame/hand.L').ownedInstanceId, mountedOwnedIds[0],
  'remounted subtree keeps ownership identity');
assertEqual(G.getNode(remount.tree, 'frame/hand.L/p0').ownedInstanceId, mountedOwnedIds[1],
  'remounted child gets new canonical path and old owned id');
assert(!G.getNode(remount.tree, 'frame/hand.R'), 'old mounted path is gone after detach/remount');

section('3. Incompatible sockets and depth cap rejection');

{
  const tree = G.createBuildTree();
  const badInventory = G.makeInventory(['shoulder-cannon'], 'bad');
  const bad = G.canAttach(tree, 'frame', 'hand.R', badInventory[0]);
  assert(!bad.ok, 'shoulder cannon cannot mount directly to hand grip');
  assert(bad.reason.includes('needs shoulder-mount') && bad.reason.includes('accepts hand-grip'),
    'incompatible attachment reason is readable');
}

{
  const state = {
    tree: G.createBuildTree(),
    inventory: G.makeInventory([
      'hand-adapter',
      'hand-adapter',
      'hand-adapter',
      'hand-adapter',
      'hand-adapter',
    ], 'depth'),
  };
  mountByDef(state, 'hand-adapter', 'frame', 'hand.L');
  mountByDef(state, 'hand-adapter', 'frame/hand.L', 'grip');
  mountByDef(state, 'hand-adapter', 'frame/hand.L/grip', 'grip');
  mountByDef(state, 'hand-adapter', 'frame/hand.L/grip/grip', 'grip');
  const fifth = state.inventory.find(part => part.defId === 'hand-adapter');
  const cap = G.canAttach(state.tree, 'frame/hand.L/grip/grip/grip', 'grip', fifth);
  assert(!cap.ok, 'fifth adapter would exceed depth cap');
  assert(cap.reason.includes('Depth cap 4'), 'depth cap rejection names the cap');
}

section('4. Resolve is deterministic and reports synergies and branch weight');

const resolved1 = G.resolve(buildState.tree);
const resolved2 = G.resolve(buildState.tree);
assertEqual(resolved1, resolved2, 'resolve(tree) is byte-equal for same tree');
assert(resolved1.totalHP > G.BASE_HP, 'armor contributes to total HP');
assert(resolved1.branchWeights['hand.R'] > 0, 'hand.R branch weight is tracked');
assert(typeof resolved1.balance.delta === 'number', 'balance delta is numeric');
const rackSynergy = resolved1.activeSynergies.find(s => s.id.startsWith('rack-load:frame/hand.R'));
assert(!!rackSynergy, 'loaded rack synergy is active');
assertEqual(
  rackSynergy.causingNodeIds,
  ['frame/hand.R', 'frame/hand.R/p0', 'frame/hand.R/p1'],
  'rack synergy lists causing nodeIds'
);
assert(resolved1.attackers.some(a => a.nodeId === 'frame/hand.R/p0'), 'p0 missile is an attacker');
assert(resolved1.attackers.some(a => a.nodeId === 'frame/hand.R/p1'), 'p1 missile is an attacker');

section('5. simulate() deterministic output and event payload shape');

{
  const enemy = G.buildEnemyTree(0);
  const originalRandom = Math.random;
  Math.random = () => { throw new Error('simulate used Math.random'); };
  let sim1;
  let sim2;
  try {
    sim1 = G.simulate(buildState.tree, enemy.tree, 4242);
    sim2 = G.simulate(buildState.tree, enemy.tree, 4242);
  } finally {
    Math.random = originalRandom;
  }

  assert(sim1.events.length > 0, 'simulation emits attack events');
  assertEqual(sim1, sim2, 'same trees and seed produce byte-equal simulation result');

  const sim3 = G.simulate(buildState.tree, enemy.tree, 4243);
  assert(JSON.stringify(sim1.events) !== JSON.stringify(sim3.events),
    'different seed changes deterministic hit/target/damage sequence');

  const event = sim1.events[0];
  assert(typeof event.t === 'number', 'event has t');
  assert(['player', 'enemy'].includes(event.source.side), 'event source has side');
  assert(typeof event.source.nodeId === 'string', 'event source has nodeId');
  assert(['player', 'enemy'].includes(event.target.side), 'event target has side');
  assert(typeof event.target.nodeId === 'string', 'event target has nodeId');
  assert('sourceDefId' in event && 'targetDefId' in event, 'event carries visual def anchors');

  if (event.damage > 0 && event.source.side === 'player') {
    assertEqual(event.enemyHP, sim1.resolved.enemy.totalHP - event.damage,
      'target.nodeId is visual only; damage applies to total enemy HP');
  } else if (event.damage > 0 && event.source.side === 'enemy') {
    assertEqual(event.playerHP, sim1.resolved.player.totalHP - event.damage,
      'target.nodeId is visual only; damage applies to total player HP');
  }
}

section('6. Same-time ATB tie-break ordering');

{
  const ready = [
    { side: 'player', nodeId: 'frame/hand.R', nextFire: 100, initiative: 10 },
    { side: 'enemy', nodeId: 'frame/hand.L', nextFire: 100, initiative: 25 },
    { side: 'player', nodeId: 'frame/shoulder.L', nextFire: 90, initiative: 1 },
  ];
  const ordered = G.orderReadyAttackers(ready, 777);
  assertEqual(ordered.map(a => a.nodeId), ['frame/shoulder.L', 'frame/hand.L', 'frame/hand.R'],
    'tie-break sorts by time first, then higher initiative');
}

{
  const equalInit = [
    { side: 'player', nodeId: 'frame/hand.R/p1', nextFire: 100, initiative: 10 },
    { side: 'player', nodeId: 'frame/hand.R/p0', nextFire: 100, initiative: 10 },
    { side: 'enemy', nodeId: 'frame/hand.R/p0', nextFire: 100, initiative: 10 },
  ];
  const expected = equalInit.slice().sort((a, b) => {
    const rankDelta = G.stableRank(123, a.side, a.nodeId) - G.stableRank(123, b.side, b.nodeId);
    if (rankDelta !== 0) return rankDelta;
    return `${a.side}|${a.nodeId}`.localeCompare(`${b.side}|${b.nodeId}`);
  });
  const ordered = G.orderReadyAttackers(equalInit, 123);
  assertEqual(ordered.map(a => `${a.side}:${a.nodeId}`), expected.map(a => `${a.side}:${a.nodeId}`),
    'equal-time/equal-initiative order uses seeded stable rank, then lexical fallback');
}

section('7. Starter and enemy builds validate');

{
  const starter = G.createStarterState();
  assert(G.validateTree(starter.tree).ok, 'starter build validates');
  assert(!!G.getNode(starter.tree, 'frame/hand.R/p0/warhead'), 'starter has hand -> rack -> missile -> warhead');
  assert(starter.inventory.every(part => part.ownedInstanceId && part.ownedInstanceId !== part.defId),
    'starter inventory uses stable owned ids distinct from defIds');

  for (let i = 0; i < G.ENEMY_POOL.length; i++) {
    const enemy = G.buildEnemyTree(i);
    assert(G.validateTree(enemy.tree).ok, `enemy ${enemy.name} validates`);
  }
}

section('8. Eligible socket list exposes compatibility detail');

{
  const state = G.createStarterState();
  const shoulder = state.inventory.find(part => part.defId === 'shoulder-cannon');
  const sockets = G.findEligibleSockets(state.tree, shoulder);
  assert(sockets.some(s => s.nodeId === 'frame/hand.R' && s.occupied), 'eligible list marks occupied sockets');
  assert(sockets.some(s => s.nodeId === 'frame/hand.L' && !s.ok && s.reason.includes('needs shoulder-mount')),
    'eligible list includes incompatible open sockets with readable reason');
  assert(sockets.some(s => s.nodeId === 'frame/shoulder.R' && s.ok),
    'eligible list includes compatible shoulder.R socket');
}

section('9. Shop and salvage use owned ids, not mounted nodeIds');

{
  const offers1 = G.generateShopOffers(2, 88);
  const offers2 = G.generateShopOffers(2, 88);
  assertEqual(offers1, offers2, 'shop offers are deterministic for round and seed');

  const enemy = G.buildEnemyTree(1);
  const salvage = G.collectSalvage(enemy.tree, 'draft');
  assert(salvage.length > 0, 'salvage pool is produced from enemy mounted tree');
  assert(salvage.every(part => !part.ownedInstanceId.startsWith('frame/')),
    'salvage mints inventory ids instead of preserving enemy nodeIds');
  assert(salvage.some(part => G.countOwnedSubtree(part) > 1), 'salvage can include nested subtrees');
}

console.log(`\n${'-'.repeat(50)}`);
console.log(`Results: ${passed} passed, ${failed} failed`);
if (failed > 0) {
  process.exit(1);
} else {
  console.log('All tests passed.');
}
