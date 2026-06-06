// game-core.js - Kitbash Mecha v0.3
// Pure data, build-tree, stat resolution, and deterministic ATB simulation.
// UMD pattern: works in Node.js tests and in the browser as window.MechBags.

(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = factory();
  } else {
    root.MechBags = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const MAX_DEPTH = 4; // levels below frame; allows hand -> rack -> missile -> warhead.
  const BASE_HP = 120;
  const MAX_BATTLE_TICKS = 1800;
  const MAX_EVENTS = 120;

  const ECONOMY = {
    startingGold: 12,
    winReward: 5,
    lossReward: 2,
    rerollCost: 1,
    shopSize: 4,
    salvageChoices: 2,
  };

  function stats(values) {
    return Object.assign({
      hp: 0,
      weight: 0,
      damage: 0,
      cooldown: 100,
      accuracy: 1,
      initiative: 0,
    }, values || {});
  }

  const PART_DEFS = {
    frame: {
      defId: 'frame',
      name: 'Core Frame',
      socketTypeIn: null,
      hardpoints: [
        { hpId: 'head', type: 'sensor-mount', view: 'front', schematicPos: [50, 11], rigPivot: [50, 8] },
        { hpId: 'torso', type: 'armor-mount', view: 'front', schematicPos: [50, 36], rigPivot: [50, 38] },
        { hpId: 'shoulder.L', type: 'shoulder-mount', view: 'front', schematicPos: [25, 28], rigPivot: [30, 28] },
        { hpId: 'shoulder.R', type: 'shoulder-mount', view: 'front', schematicPos: [75, 28], rigPivot: [70, 28] },
        { hpId: 'hand.L', type: 'hand-grip', view: 'front', schematicPos: [18, 63], rigPivot: [22, 64] },
        { hpId: 'hand.R', type: 'hand-grip', view: 'front', schematicPos: [82, 63], rigPivot: [78, 64] },
        { hpId: 'leg.L', type: 'leg-mount', view: 'front', schematicPos: [40, 86], rigPivot: [42, 84] },
        { hpId: 'leg.R', type: 'leg-mount', view: 'front', schematicPos: [60, 86], rigPivot: [58, 84] },
        { hpId: 'backpack', type: 'backpack-mount', view: 'rear', schematicPos: [50, 38], rigPivot: [50, 35] },
      ],
      stats: stats({ hp: BASE_HP, weight: 16 }),
      tags: ['frame'],
      token: 'FR',
      color: '#d8dee9',
      mountView: 'both',
      depthPlane: 0,
    },

    'missile-rack': {
      defId: 'missile-rack',
      name: 'Missile Rack',
      socketTypeIn: 'hand-grip',
      hardpoints: [
        { hpId: 'p0', type: 'missile', view: 'front', schematicPos: [38, 37], rigPivot: [36, 38] },
        { hpId: 'p1', type: 'missile', view: 'front', schematicPos: [62, 37], rigPivot: [64, 38] },
      ],
      stats: stats({ weight: 6, initiative: 4 }),
      tags: ['rack', 'weapon-mount'],
      synergyRules: ['rack-load'],
      token: 'RK',
      color: '#f59e0b',
      depthPlane: 2,
    },

    'micro-missile': {
      defId: 'micro-missile',
      name: 'Micro Missile',
      socketTypeIn: 'missile',
      hardpoints: [
        { hpId: 'warhead', type: 'warhead', view: 'front', schematicPos: [50, 18], rigPivot: [50, 18] },
      ],
      stats: stats({ damage: 10, cooldown: 92, accuracy: 0.86, weight: 2, initiative: 8 }),
      tags: ['weapon', 'missile'],
      token: 'MS',
      clip: 'fire',
      color: '#ef4444',
      depthPlane: 3,
    },

    'he-warhead': {
      defId: 'he-warhead',
      name: 'HE Warhead',
      socketTypeIn: 'warhead',
      hardpoints: [],
      stats: stats({ damage: 14, weight: 1 }),
      tags: ['payload', 'explosive'],
      token: 'HE',
      color: '#fb7185',
      depthPlane: 4,
    },

    'emp-warhead': {
      defId: 'emp-warhead',
      name: 'EMP Warhead',
      socketTypeIn: 'warhead',
      hardpoints: [],
      stats: stats({ damage: 8, weight: 1, initiative: 2 }),
      tags: ['payload', 'emp'],
      token: 'EM',
      color: '#22d3ee',
      depthPlane: 4,
    },

    'shoulder-cannon': {
      defId: 'shoulder-cannon',
      name: 'Shoulder Cannon',
      socketTypeIn: 'shoulder-mount',
      hardpoints: [],
      stats: stats({ damage: 34, cooldown: 126, accuracy: 0.82, weight: 8, initiative: 3 }),
      tags: ['weapon', 'ballistic'],
      token: 'CN',
      clip: 'fire',
      color: '#60a5fa',
      depthPlane: 2,
    },

    'backpack-thruster': {
      defId: 'backpack-thruster',
      name: 'Backpack Thruster',
      socketTypeIn: 'backpack-mount',
      hardpoints: [
        { hpId: 'aux.L', type: 'utility-mount', view: 'rear', schematicPos: [36, 64], rigPivot: [35, 66] },
        { hpId: 'aux.R', type: 'utility-mount', view: 'rear', schematicPos: [64, 64], rigPivot: [65, 66] },
      ],
      stats: stats({ weight: 6, initiative: 12 }),
      tags: ['mobility', 'rear'],
      synergyRules: ['balanced-thrust'],
      token: 'TH',
      color: '#34d399',
      mountView: 'rear',
      depthPlane: -1,
    },

    'hand-adapter': {
      defId: 'hand-adapter',
      name: 'Hand Adapter',
      socketTypeIn: 'hand-grip',
      hardpoints: [
        { hpId: 'mount', type: 'shoulder-mount', view: 'front', schematicPos: [50, 40], rigPivot: [50, 39] },
        { hpId: 'grip', type: 'hand-grip', view: 'front', schematicPos: [50, 70], rigPivot: [50, 70] },
      ],
      stats: stats({ weight: 2 }),
      tags: ['adapter'],
      isAdapter: true,
      token: 'AD',
      color: '#a78bfa',
      depthPlane: 2,
    },

    'armor-plate': {
      defId: 'armor-plate',
      name: 'Armor Plate',
      socketTypeIn: 'armor-mount',
      hardpoints: [],
      stats: stats({ hp: 38, weight: 7 }),
      tags: ['armor'],
      token: 'AR',
      color: '#94a3b8',
      depthPlane: 1,
    },

    'targeting-sensor': {
      defId: 'targeting-sensor',
      name: 'Targeting Sensor',
      socketTypeIn: 'sensor-mount',
      hardpoints: [],
      stats: stats({ weight: 2, initiative: 6 }),
      tags: ['sensor'],
      token: 'SN',
      color: '#2dd4bf',
      depthPlane: 2,
    },

    'pulse-blade': {
      defId: 'pulse-blade',
      name: 'Pulse Blade',
      socketTypeIn: 'hand-grip',
      hardpoints: [],
      stats: stats({ damage: 22, cooldown: 92, accuracy: 0.93, weight: 5, initiative: 24 }),
      tags: ['weapon', 'melee'],
      token: 'BL',
      clip: 'melee',
      color: '#f472b6',
      depthPlane: 3,
    },
  };

  const BUYABLE_DEF_IDS = [
    'missile-rack',
    'micro-missile',
    'he-warhead',
    'emp-warhead',
    'shoulder-cannon',
    'backpack-thruster',
    'hand-adapter',
    'armor-plate',
    'targeting-sensor',
    'pulse-blade',
  ];

  const ENEMY_POOL = [
    {
      id: 'racked-line',
      name: 'Rack Line Test Frame',
      plan: [
        { parentNodeId: 'frame', hpId: 'hand.R', defId: 'missile-rack' },
        { parentNodeId: 'frame/hand.R', hpId: 'p0', defId: 'micro-missile' },
        { parentNodeId: 'frame/hand.R/p0', hpId: 'warhead', defId: 'he-warhead' },
        { parentNodeId: 'frame/hand.R', hpId: 'p1', defId: 'micro-missile' },
        { parentNodeId: 'frame/hand.R/p1', hpId: 'warhead', defId: 'emp-warhead' },
        { parentNodeId: 'frame', hpId: 'shoulder.L', defId: 'shoulder-cannon' },
        { parentNodeId: 'frame', hpId: 'torso', defId: 'armor-plate' },
      ],
    },
    {
      id: 'adapter-gunner',
      name: 'Adapter Gunner Frame',
      plan: [
        { parentNodeId: 'frame', hpId: 'hand.L', defId: 'hand-adapter' },
        { parentNodeId: 'frame/hand.L', hpId: 'mount', defId: 'shoulder-cannon' },
        { parentNodeId: 'frame', hpId: 'hand.R', defId: 'pulse-blade' },
        { parentNodeId: 'frame', hpId: 'backpack', defId: 'backpack-thruster' },
        { parentNodeId: 'frame', hpId: 'head', defId: 'targeting-sensor' },
      ],
    },
  ];

  const STARTER_PLAN = [
    { parentNodeId: 'frame', hpId: 'hand.R', defId: 'missile-rack' },
    { parentNodeId: 'frame/hand.R', hpId: 'p0', defId: 'micro-missile' },
    { parentNodeId: 'frame/hand.R/p0', hpId: 'warhead', defId: 'he-warhead' },
    { parentNodeId: 'frame/hand.R', hpId: 'p1', defId: 'micro-missile' },
    { parentNodeId: 'frame/hand.R/p1', hpId: 'warhead', defId: 'emp-warhead' },
    { parentNodeId: 'frame', hpId: 'shoulder.L', defId: 'shoulder-cannon' },
    { parentNodeId: 'frame', hpId: 'backpack', defId: 'backpack-thruster' },
    { parentNodeId: 'frame', hpId: 'torso', defId: 'armor-plate' },
    { parentNodeId: 'frame', hpId: 'head', defId: 'targeting-sensor' },
  ];

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function makePRNG(seed) {
    let s = (seed >>> 0) || 1;
    return function () {
      s = (Math.imul(1664525, s) + 1013904223) >>> 0;
      return s / 4294967296;
    };
  }

  function hashString(value) {
    const text = String(value);
    let hash = 2166136261 >>> 0;
    for (let i = 0; i < text.length; i++) {
      hash ^= text.charCodeAt(i);
      hash = Math.imul(hash, 16777619) >>> 0;
    }
    return hash >>> 0;
  }

  function stableRank(seed, side, nodeId) {
    return hashString(`${seed}|${side}|${nodeId}`);
  }

  let ownedCounter = 0;
  function nextOwnedInstanceId(prefix) {
    ownedCounter += 1;
    return `${prefix || 'owned'}-${ownedCounter}`;
  }

  function getDef(defId) {
    return PART_DEFS[defId] || null;
  }

  function requireDef(defId) {
    const def = getDef(defId);
    if (!def) throw new Error(`Unknown part definition: ${defId}`);
    return def;
  }

  function createBuildTree() {
    return {
      nodeId: 'frame',
      defId: 'frame',
      parentHpId: null,
      ownedInstanceId: null,
      children: {},
    };
  }

  function createOwnedPart(defId, ownedInstanceId, children) {
    requireDef(defId);
    return {
      ownedInstanceId: ownedInstanceId || nextOwnedInstanceId('owned'),
      defId,
      children: children ? clone(children) : {},
    };
  }

  function makeInventory(defIds, prefix) {
    return defIds.map((defId, index) =>
      createOwnedPart(defId, `${prefix || 'owned'}-${index + 1}`));
  }

  function hardpointIndex(defId, hpId) {
    const def = requireDef(defId);
    const idx = def.hardpoints.findIndex(hp => hp.hpId === hpId);
    return idx === -1 ? Number.MAX_SAFE_INTEGER : idx;
  }

  function sortedChildHpIds(node) {
    return Object.keys(node.children || {}).sort((a, b) => {
      const ai = hardpointIndex(node.defId, a);
      const bi = hardpointIndex(node.defId, b);
      if (ai !== bi) return ai - bi;
      return a.localeCompare(b);
    });
  }

  function pathDepth(nodeId) {
    if (nodeId === 'frame') return 0;
    return nodeId.split('/').length - 1;
  }

  function getHardpoint(defOrId, hpId) {
    const def = typeof defOrId === 'string' ? requireDef(defOrId) : defOrId;
    return (def.hardpoints || []).find(hp => hp.hpId === hpId) || null;
  }

  function getNode(tree, nodeId) {
    if (!tree || nodeId === undefined || nodeId === null) return null;
    if (nodeId === 'frame') return tree.nodeId === 'frame' ? tree : null;
    const parts = String(nodeId).split('/');
    if (parts[0] !== 'frame') return null;
    let node = tree;
    for (let i = 1; i < parts.length; i++) {
      if (!node.children || !node.children[parts[i]]) return null;
      node = node.children[parts[i]];
    }
    return node;
  }

  function listNodes(tree) {
    const out = [];
    function walk(node) {
      out.push(node);
      for (const hpId of sortedChildHpIds(node)) walk(node.children[hpId]);
    }
    walk(tree);
    return out;
  }

  function ownedSubtreeDepth(ownedPart) {
    const children = ownedPart.children || {};
    const keys = Object.keys(children);
    if (keys.length === 0) return 0;
    return Math.max(...keys.map(hpId => 1 + ownedSubtreeDepth(children[hpId])));
  }

  function mountedSubtreeDepth(node) {
    const keys = Object.keys(node.children || {});
    if (keys.length === 0) return 0;
    return Math.max(...keys.map(hpId => 1 + mountedSubtreeDepth(node.children[hpId])));
  }

  function ownedToBuildNode(ownedPart, parentHpId, nodeId) {
    const node = {
      nodeId,
      defId: ownedPart.defId,
      parentHpId,
      ownedInstanceId: ownedPart.ownedInstanceId,
      children: {},
    };
    for (const hpId of Object.keys(ownedPart.children || {})) {
      node.children[hpId] = ownedToBuildNode(
        ownedPart.children[hpId],
        hpId,
        `${nodeId}/${hpId}`
      );
    }
    return node;
  }

  function buildToOwned(node) {
    const owned = {
      ownedInstanceId: node.ownedInstanceId || nextOwnedInstanceId('detached'),
      defId: node.defId,
      children: {},
    };
    for (const hpId of sortedChildHpIds(node)) {
      owned.children[hpId] = buildToOwned(node.children[hpId]);
    }
    return owned;
  }

  function remapOwnedIds(ownedPart, prefix) {
    let counter = 0;
    function walk(part, path) {
      counter += 1;
      const out = {
        ownedInstanceId: `${prefix}-${counter}${path ? `-${path}` : ''}`,
        defId: part.defId,
        children: {},
      };
      for (const hpId of Object.keys(part.children || {}).sort()) {
        out.children[hpId] = walk(part.children[hpId], hpId.replace(/[^A-Za-z0-9]/g, ''));
      }
      return out;
    }
    return walk(ownedPart, '');
  }

  function canAttach(tree, parentNodeId, hpId, ownedPart, options) {
    const maxDepth = options && options.maxDepth !== undefined ? options.maxDepth : MAX_DEPTH;
    const parent = getNode(tree, parentNodeId);
    if (!parent) return { ok: false, reason: `Parent node not found: ${parentNodeId}` };

    const parentDef = requireDef(parent.defId);
    const hp = getHardpoint(parentDef, hpId);
    if (!hp) return { ok: false, reason: `${parent.nodeId} has no hardpoint named ${hpId}.` };
    if (parent.children && parent.children[hpId]) {
      return { ok: false, reason: `${parent.nodeId}/${hpId} is already occupied.` };
    }
    if (!ownedPart) return { ok: false, reason: 'Select an owned part first.' };

    const childDef = getDef(ownedPart.defId);
    if (!childDef) return { ok: false, reason: `Unknown owned part definition: ${ownedPart.defId}` };
    if (hp.type !== childDef.socketTypeIn) {
      return {
        ok: false,
        reason: `${childDef.name} needs ${childDef.socketTypeIn}, but ${parent.nodeId}/${hpId} accepts ${hp.type}.`,
      };
    }

    const childDepth = pathDepth(parent.nodeId) + 1;
    const deepest = childDepth + ownedSubtreeDepth(ownedPart);
    if (deepest > maxDepth) {
      return {
        ok: false,
        reason: `Depth cap ${maxDepth} would be exceeded by mounting ${childDef.name} at ${parent.nodeId}/${hpId}.`,
      };
    }

    return {
      ok: true,
      reason: `${childDef.name} can mount at ${parent.nodeId}/${hpId}.`,
      nodeId: `${parent.nodeId}/${hpId}`,
      hardpoint: hp,
    };
  }

  function attachOwnedPart(tree, inventory, parentNodeId, hpId, ownedInstanceId, options) {
    const idx = inventory.findIndex(part => part.ownedInstanceId === ownedInstanceId);
    if (idx === -1) return { ok: false, tree, inventory, reason: `Owned part not found: ${ownedInstanceId}` };

    const ownedPart = inventory[idx];
    const check = canAttach(tree, parentNodeId, hpId, ownedPart, options);
    if (!check.ok) return { ok: false, tree, inventory, reason: check.reason };

    const nextTree = clone(tree);
    const nextInventory = inventory.slice(0, idx).concat(inventory.slice(idx + 1)).map(clone);
    const parent = getNode(nextTree, parentNodeId);
    parent.children[hpId] = ownedToBuildNode(ownedPart, hpId, `${parent.nodeId}/${hpId}`);
    return {
      ok: true,
      tree: nextTree,
      inventory: nextInventory,
      nodeId: `${parent.nodeId}/${hpId}`,
      reason: check.reason,
    };
  }

  function attachPartByDef(tree, parentNodeId, hpId, defId, ownedInstanceId, options) {
    const owned = createOwnedPart(defId, ownedInstanceId || nextOwnedInstanceId('mounted'));
    const result = attachOwnedPart(tree, [owned], parentNodeId, hpId, owned.ownedInstanceId, options);
    if (!result.ok) throw new Error(result.reason);
    return result.tree;
  }

  function detachNode(tree, inventory, nodeId) {
    if (nodeId === 'frame') return { ok: false, tree, inventory, reason: 'The core frame cannot be detached.' };
    const mounted = getNode(tree, nodeId);
    if (!mounted) return { ok: false, tree, inventory, reason: `Mounted node not found: ${nodeId}` };

    const parts = nodeId.split('/');
    const hpId = parts[parts.length - 1];
    const parentNodeId = parts.slice(0, -1).join('/');
    const nextTree = clone(tree);
    const parent = getNode(nextTree, parentNodeId);
    const detachedNode = parent.children[hpId];
    delete parent.children[hpId];

    const owned = buildToOwned(detachedNode);
    const nextInventory = inventory.map(clone).concat([owned]);
    return {
      ok: true,
      tree: nextTree,
      inventory: nextInventory,
      ownedPart: owned,
      reason: `${requireDef(detachedNode.defId).name} detached with ${countOwnedSubtree(owned)} owned part(s).`,
    };
  }

  function countOwnedSubtree(ownedPart) {
    let total = 1;
    for (const hpId of Object.keys(ownedPart.children || {})) total += countOwnedSubtree(ownedPart.children[hpId]);
    return total;
  }

  function validateTree(tree, options) {
    const maxDepth = options && options.maxDepth !== undefined ? options.maxDepth : MAX_DEPTH;
    const errors = [];
    const seen = new Set();

    function walk(node, expectedNodeId, parentDef, parentHpId) {
      const def = getDef(node.defId);
      if (!def) errors.push(`${node.nodeId} uses unknown definition ${node.defId}.`);
      if (node.nodeId !== expectedNodeId) {
        errors.push(`${node.defId} has nodeId ${node.nodeId}, expected ${expectedNodeId}.`);
      }
      if (seen.has(node.nodeId)) errors.push(`Duplicate nodeId ${node.nodeId}.`);
      seen.add(node.nodeId);
      if (pathDepth(node.nodeId) > maxDepth) errors.push(`${node.nodeId} exceeds depth cap ${maxDepth}.`);

      if (parentDef && parentHpId) {
        const hp = getHardpoint(parentDef, parentHpId);
        if (!hp) {
          errors.push(`${expectedNodeId} is mounted on missing parent hardpoint ${parentHpId}.`);
        } else if (def && hp.type !== def.socketTypeIn) {
          errors.push(`${node.nodeId} needs ${def.socketTypeIn}, parent hardpoint accepts ${hp.type}.`);
        }
      }

      if (!def) return;
      for (const hpId of sortedChildHpIds(node)) {
        walk(node.children[hpId], `${node.nodeId}/${hpId}`, def, hpId);
      }
    }

    walk(tree, 'frame', null, null);
    return { ok: errors.length === 0, errors };
  }

  function findEligibleSockets(tree, ownedPart, options) {
    const sockets = [];
    for (const node of listNodes(tree)) {
      const def = requireDef(node.defId);
      for (const hp of def.hardpoints) {
        if (node.children && node.children[hp.hpId]) {
          sockets.push({
            parentNodeId: node.nodeId,
            hpId: hp.hpId,
            nodeId: `${node.nodeId}/${hp.hpId}`,
            view: hp.view,
            type: hp.type,
            ok: false,
            occupied: true,
            reason: 'Socket already occupied.',
          });
        } else {
          const check = canAttach(tree, node.nodeId, hp.hpId, ownedPart, options);
          sockets.push({
            parentNodeId: node.nodeId,
            hpId: hp.hpId,
            nodeId: `${node.nodeId}/${hp.hpId}`,
            view: hp.view,
            type: hp.type,
            ok: check.ok,
            occupied: false,
            reason: check.reason,
          });
        }
      }
    }
    return sockets;
  }

  function statValue(def, field) {
    return def.stats && typeof def.stats[field] === 'number' ? def.stats[field] : 0;
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function collectTags(node) {
    const tags = new Set();
    function walk(n) {
      for (const tag of requireDef(n.defId).tags || []) tags.add(tag);
      for (const hpId of sortedChildHpIds(n)) walk(n.children[hpId]);
    }
    walk(node);
    return Array.from(tags).sort();
  }

  function sumSubtreeStat(node, field) {
    const def = requireDef(node.defId);
    let total = statValue(def, field);
    for (const hpId of sortedChildHpIds(node)) total += sumSubtreeStat(node.children[hpId], field);
    return total;
  }

  function topBranch(nodeId) {
    const parts = nodeId.split('/');
    return parts[1] || 'frame';
  }

  function resolve(tree) {
    const nodeStats = {};
    const activeSynergies = [];
    const actionModifiers = {};
    const nodes = listNodes(tree);

    function ensureModifier(nodeId) {
      if (!actionModifiers[nodeId]) actionModifiers[nodeId] = { cooldownMult: 1, damageBonus: 0, accuracyBonus: 0 };
      return actionModifiers[nodeId];
    }

    function aggregate(node) {
      const def = requireDef(node.defId);
      let hp = statValue(def, 'hp');
      let weight = statValue(def, 'weight');
      let damage = statValue(def, 'damage');
      let initiative = statValue(def, 'initiative');

      for (const hpId of sortedChildHpIds(node)) {
        const child = aggregate(node.children[hpId]);
        hp += child.hp;
        weight += child.weight;
        damage += child.damage;
        initiative += child.initiative;
      }

      nodeStats[node.nodeId] = {
        nodeId: node.nodeId,
        defId: node.defId,
        name: def.name,
        hp,
        weight,
        damage,
        initiative,
        tags: collectTags(node),
      };
      return nodeStats[node.nodeId];
    }

    aggregate(tree);

    for (const node of nodes) {
      const def = requireDef(node.defId);

      if (def.synergyRules && def.synergyRules.includes('rack-load')) {
        const missileChildren = sortedChildHpIds(node)
          .map(hpId => node.children[hpId])
          .filter(child => (requireDef(child.defId).tags || []).includes('missile'));
        if (missileChildren.length > 0) {
          for (const child of missileChildren) ensureModifier(child.nodeId).cooldownMult *= 0.7;
          activeSynergies.push({
            id: `rack-load:${node.nodeId}`,
            name: 'Loaded rack rails',
            description: 'Direct missiles mounted under this rack fire 30% faster.',
            causingNodeIds: [node.nodeId].concat(missileChildren.map(child => child.nodeId)),
          });
        }
      }
    }

    const frameDef = requireDef('frame');
    const branchWeights = {};
    for (const hp of frameDef.hardpoints) branchWeights[hp.hpId] = 0;
    for (const hpId of sortedChildHpIds(tree)) {
      branchWeights[hpId] = nodeStats[tree.children[hpId].nodeId].weight;
    }

    const leftWeight = Object.keys(branchWeights)
      .filter(hpId => hpId.endsWith('.L'))
      .reduce((sum, hpId) => sum + branchWeights[hpId], 0);
    const rightWeight = Object.keys(branchWeights)
      .filter(hpId => hpId.endsWith('.R'))
      .reduce((sum, hpId) => sum + branchWeights[hpId], 0);
    const rearWeight = branchWeights.backpack || 0;
    const balanceDelta = Math.abs(leftWeight - rightWeight);

    const thrusterNodes = nodes.filter(node => (requireDef(node.defId).tags || []).includes('mobility'));
    const sensorNodes = nodes.filter(node => (requireDef(node.defId).tags || []).includes('sensor'));
    const globalCooldownBonus = thrusterNodes.length * 5;
    const globalAccuracyBonus = Math.min(0.12, sensorNodes.length * 0.04);

    if (thrusterNodes.length > 0 && balanceDelta <= 4) {
      activeSynergies.push({
        id: 'balanced-thrust',
        name: 'Balanced thrust',
        description: 'A rear thruster with balanced arm weight trims 5 ticks from weapon cooldowns.',
        causingNodeIds: thrusterNodes.map(node => node.nodeId),
      });
    }

    const attackers = nodes
      .filter(node => {
        const def = requireDef(node.defId);
        return (def.tags || []).includes('weapon') && sumSubtreeStat(node, 'damage') > 0;
      })
      .map(node => {
        const def = requireDef(node.defId);
        const modifier = ensureModifier(node.nodeId);
        const branch = topBranch(node.nodeId);
        const branchWeight = branchWeights[branch] || 0;
        const branchPenalty = 1 + branchWeight * 0.01;
        const balancedBonus = thrusterNodes.length > 0 && balanceDelta <= 4 ? globalCooldownBonus : 0;
        const baseCooldown = statValue(def, 'cooldown') || 100;
        const cooldown = Math.max(28, Math.round(baseCooldown * branchPenalty * modifier.cooldownMult - balancedBonus));
        const damage = Math.max(1, sumSubtreeStat(node, 'damage') + modifier.damageBonus);
        const accuracy = clamp((def.stats.accuracy || 1) + globalAccuracyBonus + modifier.accuracyBonus, 0.05, 0.98);
        const initiative = Math.round((1000 / cooldown) * 1000 + statValue(def, 'initiative'));
        const tags = collectTags(node);
        const effects = [];
        if (tags.includes('emp')) effects.push('emp');
        if (tags.includes('explosive')) effects.push('blast');

        return {
          nodeId: node.nodeId,
          defId: node.defId,
          name: def.name,
          damage,
          cooldown,
          accuracy,
          initiative,
          branch,
          branchWeight,
          clip: def.clip || 'fire',
          effects,
        };
      })
      .sort((a, b) => a.nodeId.localeCompare(b.nodeId));

    const targetableNodeIds = nodes.map(node => node.nodeId);

    return {
      totalHP: nodeStats.frame.hp,
      totalWeight: nodeStats.frame.weight,
      branchWeights,
      balance: {
        leftWeight,
        rightWeight,
        rearWeight,
        delta: balanceDelta,
        label: balanceDelta <= 4 ? 'balanced' : leftWeight > rightWeight ? 'left-heavy' : 'right-heavy',
      },
      activeSynergies,
      attackers,
      nodeStats,
      targetableNodeIds,
      maxDepth: MAX_DEPTH,
    };
  }

  function actionTime(action) {
    if (typeof action.nextFire === 'number') return action.nextFire;
    if (typeof action.t === 'number') return action.t;
    if (typeof action.time === 'number') return action.time;
    return 0;
  }

  function actionLexical(action) {
    return `${action.side || ''}|${action.nodeId || ''}`;
  }

  function orderReadyAttackers(actions, seed) {
    return actions.slice().sort((a, b) => {
      const at = actionTime(a);
      const bt = actionTime(b);
      if (at !== bt) return at - bt;
      if ((b.initiative || 0) !== (a.initiative || 0)) return (b.initiative || 0) - (a.initiative || 0);
      const ar = stableRank(seed, a.side, a.nodeId);
      const br = stableRank(seed, b.side, b.nodeId);
      if (ar !== br) return ar - br;
      return actionLexical(a).localeCompare(actionLexical(b));
    });
  }

  function chooseTargetNode(resolved, seed, eventIndex, source) {
    const ids = resolved.targetableNodeIds.length ? resolved.targetableNodeIds : ['frame'];
    const rank = stableRank(`${seed}|target|${eventIndex}`, source.side, source.nodeId);
    return ids[rank % ids.length];
  }

  function simulate(playerTree, enemyTree, seed) {
    const rng = makePRNG(seed);
    const player = resolve(playerTree);
    const enemy = resolve(enemyTree);
    let playerHP = player.totalHP;
    let enemyHP = enemy.totalHP;

    const attackers = player.attackers.map(attacker => Object.assign({}, attacker, {
      side: 'player',
      nextFire: attacker.cooldown,
    })).concat(enemy.attackers.map(attacker => Object.assign({}, attacker, {
      side: 'enemy',
      nextFire: attacker.cooldown,
    })));

    if (attackers.length === 0) {
      return {
        events: [],
        winner: playerHP >= enemyHP ? 'player' : 'enemy',
        finalPlayerHP: playerHP,
        finalEnemyHP: enemyHP,
        resolved: { player, enemy },
      };
    }

    const events = [];
    let clock = 0;

    while (playerHP > 0 && enemyHP > 0 && clock <= MAX_BATTLE_TICKS && events.length < MAX_EVENTS) {
      const liveAttackers = attackers.filter(attacker =>
        attacker.side === 'player' ? enemyHP > 0 : playerHP > 0);
      const nextTime = Math.min(...liveAttackers.map(attacker => attacker.nextFire));
      const ready = liveAttackers.filter(attacker => attacker.nextFire === nextTime);
      const ordered = orderReadyAttackers(ready, seed);

      for (const attacker of ordered) {
        if (playerHP <= 0 || enemyHP <= 0) break;
        clock = attacker.nextFire;

        const targetSide = attacker.side === 'player' ? 'enemy' : 'player';
        const targetResolved = targetSide === 'player' ? player : enemy;
        const targetTree = targetSide === 'player' ? playerTree : enemyTree;
        const targetNodeId = chooseTargetNode(targetResolved, seed, events.length, attacker);
        const targetNode = getNode(targetTree, targetNodeId) || getNode(targetTree, 'frame');

        const hit = rng() <= attacker.accuracy;
        let damage = 0;
        const effects = [];
        if (hit) {
          const variance = 0.92 + rng() * 0.16;
          damage = Math.max(1, Math.round(attacker.damage * variance));
          for (const effect of attacker.effects) effects.push(effect);
          if (effects.includes('emp')) effects.push('slow');
          if (targetSide === 'player') playerHP = Math.max(0, playerHP - damage);
          else enemyHP = Math.max(0, enemyHP - damage);
        } else {
          effects.push('miss');
          rng(); // consume the variance slot so hit/miss branches remain stable in shape.
        }

        events.push({
          t: clock,
          source: { side: attacker.side, nodeId: attacker.nodeId },
          target: { side: targetSide, nodeId: targetNode.nodeId },
          clip: attacker.clip,
          damage,
          hit,
          effects,
          playerHP,
          enemyHP,
          sourceDefId: attacker.defId,
          sourceName: attacker.name,
          targetDefId: targetNode.defId,
        });

        attacker.nextFire += attacker.cooldown;
      }
    }

    return {
      events,
      winner: playerHP === enemyHP ? 'draw' : playerHP > enemyHP ? 'player' : 'enemy',
      finalPlayerHP: playerHP,
      finalEnemyHP: enemyHP,
      resolved: { player, enemy },
    };
  }

  function buildTreeFromPlan(plan, prefix) {
    let tree = createBuildTree();
    plan.forEach((step, index) => {
      tree = attachPartByDef(
        tree,
        step.parentNodeId,
        step.hpId,
        step.defId,
        step.ownedInstanceId || `${prefix || 'plan'}-${index + 1}`
      );
    });
    return tree;
  }

  function buildEnemyTree(index) {
    const enemy = ENEMY_POOL[index % ENEMY_POOL.length];
    return {
      id: enemy.id,
      name: enemy.name,
      tree: buildTreeFromPlan(enemy.plan, `enemy-${enemy.id}`),
    };
  }

  function createStarterState() {
    return {
      round: 1,
      wins: 0,
      losses: 0,
      gold: ECONOMY.startingGold,
      tree: buildTreeFromPlan(STARTER_PLAN, 'starter-mounted'),
      inventory: makeInventory([
        'missile-rack',
        'micro-missile',
        'he-warhead',
        'emp-warhead',
        'hand-adapter',
        'hand-adapter',
        'hand-adapter',
        'hand-adapter',
        'hand-adapter',
        'shoulder-cannon',
        'pulse-blade',
        'armor-plate',
      ], 'owned'),
      shop: generateShopOffers(1, 101),
    };
  }

  function generateShopOffers(round, seed) {
    const baseSeed = (seed === undefined ? 1 : seed) + round * 1009;
    return BUYABLE_DEF_IDS
      .slice()
      .sort((a, b) => stableRank(baseSeed, 'shop', a) - stableRank(baseSeed, 'shop', b))
      .slice(0, ECONOMY.shopSize)
      .map((defId, index) => {
        const def = requireDef(defId);
        return {
          offerId: `shop-${round}-${index}-${defId}`,
          defId,
          name: def.name,
          cost: def.cost || Math.max(2, Math.ceil((statValue(def, 'damage') + statValue(def, 'hp') / 8 + statValue(def, 'weight')) / 6)),
        };
      });
  }

  function collectSalvage(tree, prefix) {
    return listNodes(tree)
      .filter(node => node.nodeId !== 'frame')
      .map((node, index) => remapOwnedIds(buildToOwned(node), `${prefix || 'salvage'}-${index + 1}`));
  }

  return {
    MAX_DEPTH,
    BASE_HP,
    MAX_BATTLE_TICKS,
    MAX_EVENTS,
    ECONOMY,
    PART_DEFS,
    BUYABLE_DEF_IDS,
    ENEMY_POOL,
    STARTER_PLAN,

    clone,
    makePRNG,
    hashString,
    stableRank,
    nextOwnedInstanceId,

    getDef,
    getHardpoint,
    createBuildTree,
    createOwnedPart,
    makeInventory,
    getNode,
    listNodes,
    pathDepth,
    ownedSubtreeDepth,
    mountedSubtreeDepth,
    countOwnedSubtree,

    canAttach,
    attachOwnedPart,
    attachPartByDef,
    detachNode,
    validateTree,
    findEligibleSockets,

    resolve,
    orderReadyAttackers,
    simulate,

    buildTreeFromPlan,
    buildEnemyTree,
    createStarterState,
    generateShopOffers,
    collectSalvage,
  };
});
