// game-core.js — Mech Bags 0.1
// Pure game logic: data, simulation, placement. No DOM, no Math.random() inside simulate().
// UMD pattern: works in Node.js (tests) and browser (global MechBags).

(function (root, factory) {
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = factory();
  } else {
    root.MechBags = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // ─── Constants ─────────────────────────────────────────────────────────────
  const BAG_NAMES = ['head', 'torso', 'back', 'leftArm', 'rightArm'];

  const BAG_LABELS = {
    head: 'Head', torso: 'Torso', back: 'Back',
    leftArm: 'Left Arm', rightArm: 'Right Arm',
  };

  const DEFAULT_BAG_SIZES = {
    head:     { rows: 2, cols: 3 },
    torso:    { rows: 3, cols: 3 },
    back:     { rows: 3, cols: 2 },
    leftArm:  { rows: 3, cols: 2 },
    rightArm: { rows: 3, cols: 2 },
  };

  const ECONOMY = {
    startingGold:   10,
    winReward:       6,
    lossReward:      4,
    rerollCost:      1,
    expansionCost:   4,
    WIN_THRESHOLD:   5,
    LOSS_THRESHOLD:  3,
    SHOP_SIZE:       4,
  };

  const BASE_HP            = 80;
  const MAX_BATTLE_TICKS   = 30000;
  const CRIT_MULTIPLIER    = 1.5;

  // ─── Seeded PRNG (LCG) ────────────────────────────────────────────────────
  // Returns a function that produces [0, 1) deterministically from seed.
  // No Math.random() allowed inside simulate().
  function makePRNG(seed) {
    let s = (seed >>> 0) || 1;
    return function () {
      s = (Math.imul(1664525, s) + 1013904223) >>> 0;
      return s / 4294967296;
    };
  }

  // ─── Shape utilities ──────────────────────────────────────────────────────
  // cells: array of [row, col] relative offsets

  function rotateCW(cells) {
    const maxRow = Math.max(...cells.map(([r]) => r));
    const rotated = cells.map(([r, c]) => [c, maxRow - r]);
    const minR = Math.min(...rotated.map(([r]) => r));
    const minC = Math.min(...rotated.map(([, c]) => c));
    return rotated.map(([r, c]) => [r - minR, c - minC]);
  }

  function getRotatedCells(baseCells, rotation) {
    let cells = baseCells.map(c => [...c]);
    for (let i = 0; i < (rotation % 4); i++) cells = rotateCW(cells);
    return cells;
  }

  function getAbsoluteCells(anchorRow, anchorCol, relativeCells) {
    return relativeCells.map(([r, c]) => [anchorRow + r, anchorCol + c]);
  }

  function canPlace(bagRows, bagCols, occupiedSet, anchorRow, anchorCol, relativeCells) {
    for (const [r, c] of getAbsoluteCells(anchorRow, anchorCol, relativeCells)) {
      if (r < 0 || r >= bagRows || c < 0 || c >= bagCols) return false;
      if (occupiedSet.has(`${r},${c}`)) return false;
    }
    return true;
  }

  function buildOccupiedSet(bagItems, excludeId) {
    const set = new Set();
    for (const pi of bagItems) {
      if (pi.instanceId === excludeId) continue;
      const cells = getAbsoluteCells(pi.row, pi.col, getRotatedCells(ITEMS[pi.itemId].shape, pi.rotation));
      for (const [r, c] of cells) set.add(`${r},${c}`);
    }
    return set;
  }

  // ─── Item definitions (ARC-004) ──────────────────────────────────────────
  // adjacency: rules on THIS item — "if adjacent to X, I gain Y"
  // tagMatch: if true, `requires` is a tag to match (not an itemId)
  const ITEMS = {
    'machine-gun': {
      id: 'machine-gun', name: 'Machine Gun',
      shape: [[0,0],[0,1],[0,2]],
      cost: 3, tags: ['weapon','ballistic'],
      damage: 8, speed: 40, accuracy: 1.0, critChance: 0.05, hp: 0,
      desc: 'Fast repeating ballistic weapon.',
      color: '#e84343',
      adjacency: [
        { requires: 'ammo-box', tagMatch: false, effect: 'damage+8', desc: 'Ammo Box: +8 dmg/shot' },
      ],
    },
    'beam-rifle': {
      id: 'beam-rifle', name: 'Beam Rifle',
      shape: [[0,0],[1,0],[2,0]],
      cost: 4, tags: ['weapon','beam'],
      damage: 22, speed: 100, accuracy: 0.9, critChance: 0.05, hp: 0,
      desc: 'Accurate beam weapon. Battery reduces charge.',
      color: '#4da6ff',
      adjacency: [
        { requires: 'battery', tagMatch: false, effect: 'speed-20', desc: 'Battery: -20 charge time' },
      ],
    },
    'missile-pod': {
      id: 'missile-pod', name: 'Missile Pod',
      shape: [[0,0],[1,0],[2,0],[2,1]],
      cost: 5, tags: ['weapon','explosive'],
      damage: 28, speed: 150, accuracy: 0.75, critChance: 0.05, hp: 0,
      desc: 'Burst weapon. Low accuracy without Sensor.',
      color: '#ff8c00',
      adjacency: [
        { requires: 'sensor', tagMatch: false, effect: 'accuracy+0.2', desc: 'Sensor: +20% accuracy' },
      ],
    },
    'beam-saber': {
      id: 'beam-saber', name: 'Beam Saber',
      shape: [[0,0],[0,1]],
      cost: 3, tags: ['weapon','melee','beam'],
      damage: 16, speed: 60, accuracy: 0.95, critChance: 0.1, hp: 0,
      desc: 'Fast melee beam. Booster reduces cooldown.',
      color: '#66ccff',
      adjacency: [
        { requires: 'booster', tagMatch: false, effect: 'speed-15', desc: 'Booster: -15 attack time' },
      ],
    },
    'heavy-cannon': {
      id: 'heavy-cannon', name: 'Heavy Cannon',
      shape: [[0,0],[0,1],[1,0]],
      cost: 5, tags: ['weapon','ballistic'],
      damage: 48, speed: 200, accuracy: 0.8, critChance: 0.05, hp: 0,
      desc: 'Slow massive hit. Sensor improves accuracy.',
      color: '#cc4400',
      adjacency: [
        { requires: 'sensor', tagMatch: false, effect: 'accuracy+0.15', desc: 'Sensor: +15% accuracy' },
      ],
    },
    'battery': {
      id: 'battery', name: 'Battery',
      shape: [[0,0],[0,1]],
      cost: 2, tags: ['power'],
      damage: 0, speed: 0, accuracy: 1.0, critChance: 0, hp: 0,
      desc: 'Speeds up adjacent beam weapons.',
      color: '#ffe066',
      adjacency: [],
    },
    'ammo-box': {
      id: 'ammo-box', name: 'Ammo Box',
      shape: [[0,0],[1,0]],
      cost: 2, tags: ['power','ballistic'],
      damage: 0, speed: 0, accuracy: 1.0, critChance: 0, hp: 0,
      desc: 'Boosts adjacent ballistic weapons.',
      color: '#cc9900',
      adjacency: [],
    },
    'sensor': {
      id: 'sensor', name: 'Sensor',
      shape: [[0,0]],
      cost: 2, tags: ['sensor'],
      damage: 0, speed: 0, accuracy: 1.0, critChance: 0, hp: 0,
      desc: 'Improves accuracy of adjacent weapons.',
      color: '#44cc88',
      adjacency: [],
    },
    'targeting-chip': {
      id: 'targeting-chip', name: 'Targeting Chip',
      shape: [[0,0],[1,0]],
      cost: 2, tags: ['sensor'],
      damage: 0, speed: 0, accuracy: 1.0, critChance: 0, hp: 5,
      desc: '+15% crit chance to adjacent weapons.',
      color: '#33bb66',
      adjacency: [],
    },
    'booster': {
      id: 'booster', name: 'Booster',
      shape: [[0,0],[1,0],[1,1]],
      cost: 3, tags: ['power'],
      damage: 0, speed: 0, accuracy: 1.0, critChance: 0, hp: 0,
      desc: 'Speeds up adjacent melee weapons.',
      color: '#ff9933',
      adjacency: [],
    },
    'armor-plate': {
      id: 'armor-plate', name: 'Armor Plate',
      shape: [[0,0],[0,1],[1,0],[1,1]],
      cost: 4, tags: ['armor'],
      damage: 0, speed: 0, accuracy: 1.0, critChance: 0, hp: 30,
      desc: '+30 max HP. Buffs adjacent Shield block.',
      color: '#888888',
      adjacency: [
        { requires: 'shield', tagMatch: false, effect: 'blockChance+0.2', desc: 'Shield: +20% block' },
      ],
    },
    'shield': {
      id: 'shield', name: 'Shield',
      shape: [[0,0],[1,0],[2,0]],
      cost: 3, tags: ['armor'],
      damage: 0, speed: 0, accuracy: 1.0, critChance: 0, hp: 10,
      desc: 'Periodically blocks incoming damage.',
      color: '#aaaaaa',
      blockChance: 0.3,
      blockCooldown: 120,
      adjacency: [],
    },
  };

  // ─── Enemy pool (6 prebuilt builds) ──────────────────────────────────────
  const ENEMY_POOL = [
    {
      name: 'Starter Balanced',
      items: [
        { itemId: 'machine-gun', bag: 'back',     row: 0, col: 0, rotation: 1 },
        { itemId: 'armor-plate', bag: 'torso',    row: 0, col: 0, rotation: 0 },
        { itemId: 'sensor',      bag: 'head',     row: 0, col: 0, rotation: 0 },
      ],
    },
    {
      name: 'Missile Backpack',
      items: [
        { itemId: 'missile-pod', bag: 'back',    row: 0, col: 0, rotation: 0 },
        { itemId: 'sensor',      bag: 'head',    row: 0, col: 2, rotation: 0 },
        { itemId: 'beam-saber',  bag: 'torso',   row: 0, col: 0, rotation: 0 },
      ],
    },
    {
      // Demonstrates BEH-001: Beam Rifle in Head bag
      name: 'Beam Head Goblin',
      items: [
        { itemId: 'beam-rifle',     bag: 'head',  row: 0, col: 0, rotation: 1 },
        { itemId: 'battery',        bag: 'head',  row: 1, col: 0, rotation: 0 },
        { itemId: 'targeting-chip', bag: 'torso', row: 0, col: 0, rotation: 0 },
      ],
    },
    {
      name: 'Shield Turtle',
      items: [
        { itemId: 'shield',       bag: 'leftArm',  row: 0, col: 0, rotation: 0 },
        { itemId: 'armor-plate',  bag: 'torso',    row: 0, col: 0, rotation: 0 },
        { itemId: 'heavy-cannon', bag: 'rightArm', row: 0, col: 0, rotation: 0 },
      ],
    },
    {
      name: 'Saber Rush',
      items: [
        { itemId: 'beam-saber',     bag: 'leftArm',  row: 0, col: 0, rotation: 1 },
        { itemId: 'beam-saber',     bag: 'rightArm', row: 0, col: 0, rotation: 1 },
        { itemId: 'booster',        bag: 'back',     row: 0, col: 0, rotation: 0 },
        { itemId: 'targeting-chip', bag: 'torso',    row: 0, col: 0, rotation: 0 },
      ],
    },
    {
      name: 'Heavy Cannon Glass Cannon',
      items: [
        { itemId: 'heavy-cannon',   bag: 'torso', row: 0, col: 0, rotation: 0 },
        { itemId: 'targeting-chip', bag: 'torso', row: 0, col: 2, rotation: 0 },
        { itemId: 'sensor',         bag: 'head',  row: 0, col: 0, rotation: 0 },
      ],
    },
  ];

  // ─── Expansion card definitions ───────────────────────────────────────────
  const EXPANSION_CARDS = BAG_NAMES.map(bag => ({
    id: `expand-${bag}`,
    type: 'expansion',
    bag,
    label: `${BAG_LABELS[bag]} Expansion`,
    desc: `+1 row to ${BAG_LABELS[bag]}`,
    cost: ECONOMY.expansionCost,
  }));

  // ─── Adjacency helpers ────────────────────────────────────────────────────
  function getAdjacentItems(bagItems, targetItem) {
    const targetCells = getAbsoluteCells(
      targetItem.row, targetItem.col,
      getRotatedCells(ITEMS[targetItem.itemId].shape, targetItem.rotation)
    );
    const neighborKeys = new Set();
    for (const [r, c] of targetCells) {
      neighborKeys.add(`${r - 1},${c}`);
      neighborKeys.add(`${r + 1},${c}`);
      neighborKeys.add(`${r},${c - 1}`);
      neighborKeys.add(`${r},${c + 1}`);
    }
    const selfKeys = new Set(targetCells.map(([r, c]) => `${r},${c}`));

    return bagItems.filter(pi => {
      if (pi.instanceId === targetItem.instanceId) return false;
      const cells = getAbsoluteCells(pi.row, pi.col, getRotatedCells(ITEMS[pi.itemId].shape, pi.rotation));
      return cells.some(([r, c]) => neighborKeys.has(`${r},${c}`) && !selfKeys.has(`${r},${c}`));
    });
  }

  function applyEffect(stats, effect) {
    const m = effect.match(/^(\w+)([+-])(\d*\.?\d+)$/);
    if (!m) return;
    const [, field, op, valStr] = m;
    const val = parseFloat(valStr);
    if (op === '+') stats[field] = (stats[field] || 0) + val;
    else            stats[field] = Math.max(0, (stats[field] || 0) - val);
  }

  // Returns effective combat stats for a placed item, considering same-bag adjacency.
  function computeEffectiveStats(placedItem, bagItems) {
    const def = ITEMS[placedItem.itemId];
    const stats = {
      damage:      def.damage,
      speed:       def.speed,
      accuracy:    def.accuracy,
      critChance:  def.critChance,
      blockChance: def.blockChance || 0,
      blockCooldown: def.blockCooldown || 120,
    };

    const adjacent = getAdjacentItems(bagItems, placedItem);

    // Rules on this item ("if I'm next to X, I gain Y")
    for (const rule of def.adjacency) {
      const match = rule.tagMatch
        ? adjacent.some(a => ITEMS[a.itemId].tags.includes(rule.requires))
        : adjacent.some(a => a.itemId === rule.requires);
      if (match) applyEffect(stats, rule.effect);
    }

    // Universal: adjacent armor-plate buffs shield's blockChance
    if (def.id === 'shield') {
      if (adjacent.some(a => a.itemId === 'armor-plate')) {
        stats.blockChance = Math.min(1.0, stats.blockChance + 0.2);
      }
    }

    // Universal: adjacent targeting-chip gives any weapon +15% crit
    if (def.tags.includes('weapon')) {
      if (adjacent.some(a => a.itemId === 'targeting-chip')) {
        stats.critChance = Math.min(1.0, stats.critChance + 0.15);
      }
    }

    return stats;
  }

  // Returns all active adjacency bonus descriptions for display on the build board.
  function getActiveBonuses(bagName, bagItems) {
    const bonuses = [];
    for (const pi of bagItems) {
      const def = ITEMS[pi.itemId];
      const adjacent = getAdjacentItems(bagItems, pi);

      for (const rule of def.adjacency) {
        const match = rule.tagMatch
          ? adjacent.some(a => ITEMS[a.itemId].tags.includes(rule.requires))
          : adjacent.some(a => a.itemId === rule.requires);
        if (match) {
          bonuses.push({ sourceId: pi.instanceId, sourceName: def.name, desc: rule.desc });
        }
      }

      if (def.id === 'shield' && adjacent.some(a => a.itemId === 'armor-plate')) {
        bonuses.push({ sourceId: pi.instanceId, sourceName: def.name, desc: 'Armor Plate: +20% block' });
      }

      if (def.tags.includes('weapon') && adjacent.some(a => a.itemId === 'targeting-chip')) {
        bonuses.push({ sourceId: pi.instanceId, sourceName: def.name, desc: 'Targeting Chip: +15% crit' });
      }
    }
    return bonuses;
  }

  // ─── Build helpers ────────────────────────────────────────────────────────
  let _iidCounter = 0;
  function nextIid() { return `iid-${++_iidCounter}`; }

  function initBuild() {
    const bags = {};
    for (const bag of BAG_NAMES) {
      const { rows, cols } = DEFAULT_BAG_SIZES[bag];
      bags[bag] = { rows, cols, items: [] };
    }
    return { bags };
  }

  function buildFromEnemyData(enemyData) {
    const build = initBuild();
    for (const pi of enemyData.items) {
      build.bags[pi.bag].items.push({
        instanceId: nextIid(),
        itemId: pi.itemId,
        row: pi.row,
        col: pi.col,
        rotation: pi.rotation,
      });
    }
    return build;
  }

  function placeItem(build, bagName, instanceId, itemId, row, col, rotation) {
    const bag = build.bags[bagName];
    const cells = getRotatedCells(ITEMS[itemId].shape, rotation);
    const occupied = buildOccupiedSet(bag.items, null);
    if (!canPlace(bag.rows, bag.cols, occupied, row, col, cells)) return false;
    bag.items.push({ instanceId, itemId, row, col, rotation });
    return true;
  }

  function removeItem(build, instanceId) {
    for (const bag of BAG_NAMES) {
      const items = build.bags[bag].items;
      const idx = items.findIndex(i => i.instanceId === instanceId);
      if (idx !== -1) { items.splice(idx, 1); return true; }
    }
    return false;
  }

  function expandBag(build, bagName) {
    build.bags[bagName].rows += 1;
  }

  // ─── HP calculation ───────────────────────────────────────────────────────
  function computeHP(build) {
    let hp = BASE_HP;
    for (const bag of BAG_NAMES) {
      for (const pi of build.bags[bag].items) {
        hp += ITEMS[pi.itemId].hp;
      }
    }
    return hp;
  }

  // ─── ATB Simulation ───────────────────────────────────────────────────────
  function getAttackers(build, side) {
    const attackers = [];
    for (const bagName of BAG_NAMES) {
      const bag = build.bags[bagName];
      for (const pi of bag.items) {
        const def = ITEMS[pi.itemId];
        if (def.damage <= 0) continue;
        const stats = computeEffectiveStats(pi, bag.items);
        attackers.push({
          instanceId: pi.instanceId,
          itemId: pi.itemId,
          name: def.name,
          bag: bagName,
          side,
          stats,
          nextFire: stats.speed,
        });
      }
    }
    return attackers;
  }

  function getShields(build, side) {
    const shields = [];
    for (const bagName of BAG_NAMES) {
      const bag = build.bags[bagName];
      for (const pi of bag.items) {
        if (pi.itemId !== 'shield') continue;
        const stats = computeEffectiveStats(pi, bag.items);
        shields.push({
          instanceId: pi.instanceId,
          bag: bagName,
          side,
          blockChance: stats.blockChance,
          blockCooldown: stats.blockCooldown,
          lastBlock: -9999,
        });
      }
    }
    return shields;
  }

  function simulate(playerBuild, enemyBuild, seed) {
    const rng = makePRNG(seed);

    let pHP = computeHP(playerBuild);
    let eHP = computeHP(enemyBuild);

    const pAttackers = getAttackers(playerBuild, 'player');
    const eAttackers = getAttackers(enemyBuild, 'enemy');
    const allAttackers = [...pAttackers, ...eAttackers];

    const pShields = getShields(playerBuild, 'player');
    const eShields = getShields(enemyBuild, 'enemy');

    if (allAttackers.length === 0) {
      return { events: [], winner: 'player', finalPlayerHP: pHP, finalEnemyHP: eHP };
    }

    const events = [];
    let clock = 0;

    while (pHP > 0 && eHP > 0 && clock < MAX_BATTLE_TICKS && events.length < 500) {
      // Find attacker with earliest nextFire
      let next = allAttackers[0];
      for (const a of allAttackers) {
        if (a.nextFire < next.nextFire) next = a;
      }
      clock = next.nextFire;

      // Hit/miss roll
      const hitRoll = rng();
      const hit = hitRoll < next.stats.accuracy;
      let damage = 0;
      const effects = [];

      if (hit) {
        const critRoll = rng();
        const isCrit = critRoll < next.stats.critChance;
        damage = Math.floor(next.stats.damage * (isCrit ? CRIT_MULTIPLIER : 1.0));
        if (isCrit) effects.push('crit');

        // Shield check on defending side
        const defShields = next.side === 'player' ? eShields : pShields;
        let blocked = false;
        for (const sh of defShields) {
          if (clock - sh.lastBlock >= sh.blockCooldown) {
            if (rng() < sh.blockChance) {
              blocked = true;
              sh.lastBlock = clock;
              effects.push('blocked');
              break;
            }
          }
        }

        if (!blocked) {
          if (next.side === 'player') eHP = Math.max(0, eHP - damage);
          else                         pHP = Math.max(0, pHP - damage);
        } else {
          damage = 0;
        }
      } else {
        effects.push('miss');
        rng(); // consume crit roll slot for determinism
      }

      events.push({
        time: clock,
        attackerSide: next.side,
        bag: next.bag,
        itemId: next.itemId,
        itemName: next.name,
        damage,
        effects,
        playerHP: pHP,
        enemyHP: eHP,
      });

      next.nextFire += next.stats.speed;

      if (pHP <= 0 || eHP <= 0) break;
    }

    const winner = pHP > 0 ? 'player' : 'enemy';
    return { events, winner, finalPlayerHP: pHP, finalEnemyHP: eHP };
  }

  // ─── Shop generation ──────────────────────────────────────────────────────
  // Uses Math.random() — shop offers do not affect battle determinism.
  function generateShopOffers(round) {
    const itemIds = Object.keys(ITEMS);
    const shuffled = itemIds.slice().sort(() => Math.random() - 0.5);
    const items = shuffled.slice(0, ECONOMY.SHOP_SIZE).map(id => ({
      offerId: `offer-${Math.random().toString(36).slice(2)}`,
      type: 'item',
      itemId: id,
      cost: ITEMS[id].cost,
    }));
    // Pick one random expansion card
    const expansionBag = BAG_NAMES[Math.floor(Math.random() * BAG_NAMES.length)];
    const expansion = EXPANSION_CARDS.find(c => c.bag === expansionBag);
    return [...items, { ...expansion, offerId: `expand-offer-${Math.random().toString(36).slice(2)}` }];
  }

  // ─── Public API ───────────────────────────────────────────────────────────
  return {
    BAG_NAMES,
    BAG_LABELS,
    DEFAULT_BAG_SIZES,
    ECONOMY,
    BASE_HP,
    ITEMS,
    ENEMY_POOL,
    EXPANSION_CARDS,

    makePRNG,
    rotateCW,
    getRotatedCells,
    getAbsoluteCells,
    canPlace,
    buildOccupiedSet,

    getAdjacentItems,
    computeEffectiveStats,
    getActiveBonuses,

    initBuild,
    buildFromEnemyData,
    placeItem,
    removeItem,
    expandBag,
    computeHP,
    nextIid,

    simulate,
    generateShopOffers,
  };
});
