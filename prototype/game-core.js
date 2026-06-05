// game-core.js — Mech Bags 0.2
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
  const CANVAS_ROWS = 8;
  const CANVAS_COLS = 8;

  // Starting owned area: 3×3 block at top-left
  const STARTING_OWNED_COORDS = [
    [0,0],[0,1],[0,2],
    [1,0],[1,1],[1,2],
    [2,0],[2,1],[2,2],
  ];

  const ECONOMY = {
    startingGold:   10,
    winReward:       6,
    lossReward:      4,
    rerollCost:      1,
    WIN_THRESHOLD:   5,
    LOSS_THRESHOLD:  3,
    SHOP_SIZE:       4,
  };

  const THEATRE_CONFIG = {
    FIGHT_DURATION_MIN:  15000,
    FIGHT_DURATION_MAX:  30000,
    VICTORY_DOWNTIME:     5000,
    LOSS_DOWNTIME:       15000,
  };

  const BASE_HP            = 80;
  const MAX_BATTLE_TICKS   = 30000;
  const CRIT_MULTIPLIER    = 1.5;

  // ─── Seeded PRNG (LCG) ────────────────────────────────────────────────────
  function makePRNG(seed) {
    let s = (seed >>> 0) || 1;
    return function () {
      s = (Math.imul(1664525, s) + 1013904223) >>> 0;
      return s / 4294967296;
    };
  }

  // ─── Shape utilities ──────────────────────────────────────────────────────
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

  // ─── Item definitions ─────────────────────────────────────────────────────
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

  // ─── Bag piece definitions ────────────────────────────────────────────────
  // Buyable canvas expansions: add owned cells to the player's canvas.
  const BAG_PIECE_DEFS = {
    'bag-2x2': {
      id: 'bag-2x2', name: 'Small Bag (2×2)',
      shape: [[0,0],[0,1],[1,0],[1,1]],
      cost: 4, desc: 'Adds a 2×2 patch of owned canvas space.',
    },
    'bag-1x3': {
      id: 'bag-1x3', name: 'Strip Bag (1×3)',
      shape: [[0,0],[0,1],[0,2]],
      cost: 3, desc: 'Adds a 1×3 horizontal strip of owned space.',
    },
    'bag-L': {
      id: 'bag-L', name: 'L-Bag',
      shape: [[0,0],[1,0],[2,0],[2,1]],
      cost: 3, desc: 'Adds an L-shaped patch of owned canvas space.',
    },
  };

  // ─── Enemy pool (10 builds, canvas coordinates) ───────────────────────────
  const ENEMY_POOL = [
    {
      name: 'Starter Balanced',
      archetype: 'ballistic',
      items: [
        { itemId: 'machine-gun',  row: 0, col: 0, rotation: 1 },  // vertical 3×1
        { itemId: 'armor-plate',  row: 0, col: 2, rotation: 0 },  // 2×2
        { itemId: 'sensor',       row: 3, col: 3, rotation: 0 },
      ],
    },
    {
      name: 'Missile Backpack',
      archetype: 'missile',
      items: [
        { itemId: 'missile-pod',  row: 0, col: 0, rotation: 0 },  // L: (0,0)(1,0)(2,0)(2,1)
        { itemId: 'sensor',       row: 2, col: 2, rotation: 0 },  // adjacent to (2,1) → accuracy bonus
        { itemId: 'beam-saber',   row: 4, col: 0, rotation: 0 },
      ],
    },
    {
      name: 'Beam Head Goblin',
      archetype: 'beam',
      items: [
        { itemId: 'beam-rifle',     row: 0, col: 0, rotation: 1 }, // horizontal 1×3
        { itemId: 'battery',        row: 1, col: 0, rotation: 0 }, // adjacent to beam-rifle → speed bonus
        { itemId: 'targeting-chip', row: 2, col: 0, rotation: 0 },
      ],
    },
    {
      name: 'Shield Turtle',
      archetype: 'defense',
      items: [
        { itemId: 'shield',       row: 0, col: 0, rotation: 0 },  // 3×1 vertical
        { itemId: 'armor-plate',  row: 0, col: 1, rotation: 0 },  // adjacent to shield → block bonus
        { itemId: 'heavy-cannon', row: 3, col: 0, rotation: 0 },
      ],
    },
    {
      name: 'Saber Rush',
      archetype: 'melee',
      items: [
        { itemId: 'beam-saber',     row: 0, col: 0, rotation: 0 },
        { itemId: 'beam-saber',     row: 0, col: 3, rotation: 0 },
        { itemId: 'booster',        row: 1, col: 0, rotation: 0 }, // adjacent to first saber → speed bonus
        { itemId: 'targeting-chip', row: 1, col: 3, rotation: 0 }, // adjacent to second saber → crit bonus
      ],
    },
    {
      name: 'Heavy Cannon Glass Cannon',
      archetype: 'ballistic',
      items: [
        { itemId: 'heavy-cannon',   row: 0, col: 0, rotation: 0 }, // L: (0,0)(0,1)(1,0)
        { itemId: 'targeting-chip', row: 0, col: 2, rotation: 0 }, // adjacent to (0,1) → crit bonus
        { itemId: 'sensor',         row: 2, col: 0, rotation: 0 }, // adjacent to (1,0) → accuracy bonus
      ],
    },
    {
      name: 'Ammo Blitz',
      archetype: 'ballistic',
      items: [
        { itemId: 'machine-gun',  row: 0, col: 0, rotation: 1 }, // vertical 3×1
        { itemId: 'ammo-box',     row: 0, col: 1, rotation: 0 }, // adjacent to machine-gun → damage bonus
        { itemId: 'heavy-cannon', row: 3, col: 0, rotation: 0 },
        { itemId: 'sensor',       row: 5, col: 0, rotation: 0 }, // adjacent to heavy-cannon (4,0)→ accuracy bonus
      ],
    },
    {
      name: 'Dual Beam Arms',
      archetype: 'beam',
      items: [
        { itemId: 'beam-rifle',  row: 0, col: 0, rotation: 0 }, // vertical 3×1
        { itemId: 'beam-rifle',  row: 0, col: 2, rotation: 0 }, // vertical 3×1
        { itemId: 'beam-saber',  row: 3, col: 0, rotation: 0 },
        { itemId: 'battery',     row: 4, col: 0, rotation: 0 }, // adjacent to saber → speed bonus
      ],
    },
    {
      name: 'Sniper Pack',
      archetype: 'ballistic',
      items: [
        { itemId: 'heavy-cannon',   row: 0, col: 0, rotation: 0 }, // L: (0,0)(0,1)(1,0)
        { itemId: 'targeting-chip', row: 0, col: 2, rotation: 0 }, // adjacent to (0,1) → crit bonus
        { itemId: 'sensor',         row: 2, col: 0, rotation: 0 }, // adjacent to (1,0) → accuracy bonus
        { itemId: 'shield',         row: 3, col: 0, rotation: 0 },
      ],
    },
    {
      name: 'Missile Blitz',
      archetype: 'missile',
      items: [
        { itemId: 'missile-pod',    row: 0, col: 0, rotation: 0 }, // L: (0,0)(1,0)(2,0)(2,1)
        { itemId: 'sensor',         row: 2, col: 2, rotation: 0 }, // adjacent to (2,1) → accuracy bonus
        { itemId: 'beam-saber',     row: 4, col: 0, rotation: 0 },
        { itemId: 'targeting-chip', row: 4, col: 2, rotation: 0 }, // adjacent to saber (4,1)→ crit bonus
      ],
    },
  ];

  // ─── Canvas placement helpers ─────────────────────────────────────────────

  // Placement valid only on owned cells with no overlap or out-of-bounds.
  function canPlace(canvasRows, canvasCols, ownedCells, occupiedSet, anchorRow, anchorCol, relativeCells) {
    for (const [r, c] of getAbsoluteCells(anchorRow, anchorCol, relativeCells)) {
      if (r < 0 || r >= canvasRows || c < 0 || c >= canvasCols) return false;
      if (!ownedCells.has(`${r},${c}`)) return false;
      if (occupiedSet.has(`${r},${c}`)) return false;
    }
    return true;
  }

  // Bag piece placement valid if all cells are in canvas bounds (can overlap owned or unowned).
  function canPlaceBagPiece(canvasRows, canvasCols, anchorRow, anchorCol, relativeCells) {
    for (const [r, c] of getAbsoluteCells(anchorRow, anchorCol, relativeCells)) {
      if (r < 0 || r >= canvasRows || c < 0 || c >= canvasCols) return false;
    }
    return true;
  }

  function buildOccupiedSet(canvasItems, excludeId) {
    const set = new Set();
    for (const pi of canvasItems) {
      if (pi.instanceId === excludeId) continue;
      const cells = getAbsoluteCells(pi.row, pi.col, getRotatedCells(ITEMS[pi.itemId].shape, pi.rotation));
      for (const [r, c] of cells) set.add(`${r},${c}`);
    }
    return set;
  }

  // ─── Adjacency helpers ────────────────────────────────────────────────────
  // Adjacency now works across all canvas items (not per-bag).
  function getAdjacentItems(canvasItems, targetItem) {
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

    return canvasItems.filter(pi => {
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

  function computeEffectiveStats(placedItem, canvasItems) {
    const def = ITEMS[placedItem.itemId];
    const stats = {
      damage:        def.damage,
      speed:         def.speed,
      accuracy:      def.accuracy,
      critChance:    def.critChance,
      blockChance:   def.blockChance || 0,
      blockCooldown: def.blockCooldown || 120,
    };

    const adjacent = getAdjacentItems(canvasItems, placedItem);

    for (const rule of def.adjacency) {
      const match = rule.tagMatch
        ? adjacent.some(a => ITEMS[a.itemId].tags.includes(rule.requires))
        : adjacent.some(a => a.itemId === rule.requires);
      if (match) applyEffect(stats, rule.effect);
    }

    if (def.id === 'shield') {
      if (adjacent.some(a => a.itemId === 'armor-plate')) {
        stats.blockChance = Math.min(1.0, stats.blockChance + 0.2);
      }
    }

    if (def.tags.includes('weapon')) {
      if (adjacent.some(a => a.itemId === 'targeting-chip')) {
        stats.critChance = Math.min(1.0, stats.critChance + 0.15);
      }
    }

    return stats;
  }

  function getActiveBonuses(canvasItems) {
    const bonuses = [];
    for (const pi of canvasItems) {
      const def = ITEMS[pi.itemId];
      const adjacent = getAdjacentItems(canvasItems, pi);

      for (const rule of def.adjacency) {
        const match = rule.tagMatch
          ? adjacent.some(a => ITEMS[a.itemId].tags.includes(rule.requires))
          : adjacent.some(a => a.itemId === rule.requires);
        if (match) bonuses.push({ sourceId: pi.instanceId, sourceName: def.name, desc: rule.desc });
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
    const ownedCells = new Set(STARTING_OWNED_COORDS.map(([r, c]) => `${r},${c}`));
    return { canvas: { rows: CANVAS_ROWS, cols: CANVAS_COLS, items: [], ownedCells } };
  }

  function buildFromEnemyData(enemyData) {
    const ownedCells = new Set();
    const items = [];
    for (const pi of enemyData.items) {
      const cells = getAbsoluteCells(pi.row, pi.col,
        getRotatedCells(ITEMS[pi.itemId].shape, pi.rotation));
      for (const [r, c] of cells) ownedCells.add(`${r},${c}`);
      items.push({ instanceId: nextIid(), itemId: pi.itemId, row: pi.row, col: pi.col, rotation: pi.rotation });
    }
    return { canvas: { rows: CANVAS_ROWS, cols: CANVAS_COLS, items, ownedCells } };
  }

  // Place an item on the canvas. No bag name — canvas only.
  function placeItem(build, instanceId, itemId, row, col, rotation) {
    const { canvas } = build;
    const cells = getRotatedCells(ITEMS[itemId].shape, rotation);
    const occupied = buildOccupiedSet(canvas.items, null);
    if (!canPlace(canvas.rows, canvas.cols, canvas.ownedCells, occupied, row, col, cells)) return false;
    canvas.items.push({ instanceId, itemId, row, col, rotation });
    return true;
  }

  function removeItem(build, instanceId) {
    const idx = build.canvas.items.findIndex(i => i.instanceId === instanceId);
    if (idx !== -1) { build.canvas.items.splice(idx, 1); return true; }
    return false;
  }

  // Add owned cells to canvas at anchor position. Only fails if out of bounds.
  function addBagPiece(build, anchorRow, anchorCol, relativeCells) {
    const { canvas } = build;
    const abs = getAbsoluteCells(anchorRow, anchorCol, relativeCells);
    for (const [r, c] of abs) {
      if (r < 0 || r >= canvas.rows || c < 0 || c >= canvas.cols) return false;
    }
    for (const [r, c] of abs) canvas.ownedCells.add(`${r},${c}`);
    return true;
  }

  // ─── HP calculation ───────────────────────────────────────────────────────
  function computeHP(build) {
    let hp = BASE_HP;
    for (const pi of build.canvas.items) hp += ITEMS[pi.itemId].hp;
    return hp;
  }

  // ─── ATB Simulation ───────────────────────────────────────────────────────
  function getAttackers(build, side) {
    const attackers = [];
    const { items } = build.canvas;
    for (const pi of items) {
      const def = ITEMS[pi.itemId];
      if (def.damage <= 0) continue;
      const stats = computeEffectiveStats(pi, items);
      attackers.push({
        instanceId: pi.instanceId,
        itemId:     pi.itemId,
        name:       def.name,
        side,
        stats,
        nextFire:   stats.speed,
      });
    }
    return attackers;
  }

  function getShields(build, side) {
    const shields = [];
    const { items } = build.canvas;
    for (const pi of items) {
      if (pi.itemId !== 'shield') continue;
      const stats = computeEffectiveStats(pi, items);
      shields.push({
        instanceId:    pi.instanceId,
        side,
        blockChance:   stats.blockChance,
        blockCooldown: stats.blockCooldown,
        lastBlock:     -9999,
      });
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
      let next = allAttackers[0];
      for (const a of allAttackers) {
        if (a.nextFire < next.nextFire) next = a;
      }
      clock = next.nextFire;

      const hitRoll = rng();
      const hit = hitRoll < next.stats.accuracy;
      let damage = 0;
      const effects = [];

      if (hit) {
        const critRoll = rng();
        const isCrit = critRoll < next.stats.critChance;
        damage = Math.floor(next.stats.damage * (isCrit ? CRIT_MULTIPLIER : 1.0));
        if (isCrit) effects.push('crit');

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
        time:         clock,
        attackerSide: next.side,
        itemId:       next.itemId,
        itemName:     next.name,
        damage,
        effects,
        playerHP:     pHP,
        enemyHP:      eHP,
      });

      next.nextFire += next.stats.speed;

      if (pHP <= 0 || eHP <= 0) break;
    }

    const winner = pHP > 0 ? 'player' : 'enemy';
    return { events, winner, finalPlayerHP: pHP, finalEnemyHP: eHP };
  }

  // ─── Theatre scheduler ────────────────────────────────────────────────────
  // Virtual-time tick-based scheduler. Real-time UI drives it with setInterval.
  // Tests drive it with large dt values.

  function _fightDuration(sortieSeed, fightIdx, config) {
    const rng = makePRNG(((sortieSeed ^ (fightIdx * 1000007)) >>> 0) || 1);
    return config.FIGHT_DURATION_MIN +
      Math.floor(rng() * (config.FIGHT_DURATION_MAX - config.FIGHT_DURATION_MIN));
  }

  function makeTheatreState(sortieSeed, config) {
    config = config || THEATRE_CONFIG;
    return {
      phase:         'fighting',   // 'fighting' | 'victory-downtime' | 'loss-downtime' | 'retreated'
      fightIdx:      0,
      elapsed:       0,
      phaseDuration: _fightDuration(sortieSeed, 0, config),
      results:       [],
      sortieSeed,
      wins:          0,
      losses:        0,
    };
  }

  // Advance theatre by dtMs. Mutates state in place.
  function tickTheatre(state, playerBuild, enemyPool, dtMs, config) {
    if (state.phase === 'retreated') return;
    config = config || THEATRE_CONFIG;

    state.elapsed += dtMs;

    if (state.phase === 'fighting' && state.elapsed >= state.phaseDuration) {
      const enemyIdx = state.fightIdx % enemyPool.length;
      const fightSeed = ((state.sortieSeed * 1000 + state.fightIdx * 137 + 1) >>> 0) || 1;
      const enemyBuild = buildFromEnemyData(enemyPool[enemyIdx]);
      const simResult  = simulate(playerBuild, enemyBuild, fightSeed);

      state.results.push({
        enemyIdx,
        enemyName:      enemyPool[enemyIdx].name,
        enemyArchetype: enemyPool[enemyIdx].archetype,
        winner:         simResult.winner,
        finalPlayerHP:  simResult.finalPlayerHP,
        finalEnemyHP:   simResult.finalEnemyHP,
        events:         simResult.events,
      });
      state.fightIdx++;

      if (simResult.winner === 'player') {
        state.wins++;
        state.phase         = 'victory-downtime';
        state.phaseDuration = config.VICTORY_DOWNTIME;
      } else {
        state.losses++;
        state.phase         = 'loss-downtime';
        state.phaseDuration = config.LOSS_DOWNTIME;
      }
      state.elapsed = 0;
      return;
    }

    if ((state.phase === 'victory-downtime' || state.phase === 'loss-downtime')
        && state.elapsed >= state.phaseDuration) {
      state.phase         = 'fighting';
      state.elapsed       = 0;
      state.phaseDuration = _fightDuration(state.sortieSeed, state.fightIdx, config);
    }
  }

  // ─── Pilot system ────────────────────────────────────────────────────────
  const PILOT_CONDITIONS = ['Ready', 'Fatigued', 'Wounded', 'Out of Service'];

  const PILOT_XP_TABLE = [0, 100, 220, 380, 580, 820];

  function makePilotState() {
    return {
      name:      'Aki',
      level:     1,
      xp:        0,
      condition: 'Ready',
      skills: {
        missilePatternReader: { name: 'Missile Pattern Reader', progress: 0, max: 5 },
        saberDuelSense:       { name: 'Saber Duel Sense',       progress: 0, max: 5 },
        emergencyEgress:      { name: 'Emergency Egress',       progress: 0, max: 5 },
      },
      sorties: 0,
    };
  }

  // ─── Sortie resolver (batch mode — used for V0.1 Battle and reward calc) ──
  function runSortie(playerBuild, enemyPool, sortieSeed) {
    const results = [];
    for (let i = 0; i < enemyPool.length; i++) {
      const fightSeed = ((sortieSeed * 1000 + i * 137 + 1) >>> 0) || 1;
      const enemyData = enemyPool[i];
      const enemyBuild = buildFromEnemyData(enemyData);
      const simResult = simulate(playerBuild, enemyBuild, fightSeed);
      results.push({
        enemyIdx:       i,
        enemyName:      enemyData.name,
        enemyArchetype: enemyData.archetype || 'unknown',
        winner:         simResult.winner,
        finalPlayerHP:  simResult.finalPlayerHP,
        finalEnemyHP:   simResult.finalEnemyHP,
        events:         simResult.events,
      });
    }
    const wins   = results.filter(r => r.winner === 'player').length;
    const losses = results.filter(r => r.winner === 'enemy').length;
    return { results, wins, losses, sortieSeed, poolSize: enemyPool.length };
  }

  function computeSortieRewards(sortieResult, pilot) {
    const { results, wins, losses } = sortieResult;

    const xpBase     = 20;
    const xpPerWin   = 15;
    const xpSurvival = results.filter(r => r.finalPlayerHP > 0).length * 3;
    const xpGained   = xpBase + wins * xpPerWin + xpSurvival;

    const lootGained = 3 + wins * 2 + Math.floor(losses * 0.5);

    const lossRatio = losses / Math.max(1, results.length);
    let newCondition;
    if (pilot.condition === 'Out of Service') {
      newCondition = 'Wounded';
    } else if (lossRatio >= 0.7) {
      newCondition = 'Wounded';
    } else if (lossRatio >= 0.4) {
      newCondition = 'Fatigued';
    } else {
      newCondition = 'Ready';
    }

    const missileEncounters = results.filter(r =>
      r.events.some(ev => ev.itemId === 'missile-pod' && ev.attackerSide === 'enemy')
    ).length;
    const saberEncounters = results.filter(r =>
      r.events.some(ev => ev.itemId === 'beam-saber' && ev.attackerSide === 'enemy')
    ).length;

    const skillProgress = {};
    if (missileEncounters >= 3) skillProgress.missilePatternReader = 1;
    if (saberEncounters   >= 2) skillProgress.saberDuelSense       = 1;

    const lossCounts = {};
    for (const r of results) {
      if (r.winner === 'enemy') {
        lossCounts[r.enemyArchetype] = (lossCounts[r.enemyArchetype] || 0) + 1;
      }
    }
    const hardestArchetype = Object.entries(lossCounts).sort((a, b) => b[1] - a[1])[0];
    const learningSignal = hardestArchetype
      ? `Struggled against ${hardestArchetype[0]} enemies (${hardestArchetype[1]} losses). Counter their pattern before redeploying.`
      : wins === results.length && results.length > 0
        ? 'Swept the pool. The theatre will adapt — consider changing your build.'
        : 'Solid sortie. Keep refining the build based on close fights.';

    return { xpGained, lootGained, newCondition, skillProgress, learningSignal };
  }

  function applyPilotRewards(pilot, rewards) {
    const p = JSON.parse(JSON.stringify(pilot));
    const { xpGained, newCondition, skillProgress } = rewards;

    p.condition = newCondition;
    p.xp        += xpGained;
    p.sorties   += 1;

    while (p.level < PILOT_XP_TABLE.length && p.xp >= PILOT_XP_TABLE[p.level]) {
      p.xp    -= PILOT_XP_TABLE[p.level];
      p.level += 1;
    }
    if (p.level >= PILOT_XP_TABLE.length) {
      p.xp = Math.min(p.xp, PILOT_XP_TABLE[PILOT_XP_TABLE.length - 1] - 1);
    }

    for (const [key, delta] of Object.entries(skillProgress)) {
      if (p.skills[key]) {
        p.skills[key].progress = Math.min(p.skills[key].max, p.skills[key].progress + delta);
      }
    }

    return p;
  }

  // ─── Shop generation ──────────────────────────────────────────────────────
  function generateShopOffers(round) {
    const itemIds = Object.keys(ITEMS);
    const shuffled = itemIds.slice().sort(() => Math.random() - 0.5);
    const items = shuffled.slice(0, ECONOMY.SHOP_SIZE - 1).map(id => ({
      offerId: `offer-${Math.random().toString(36).slice(2)}`,
      type:    'item',
      itemId:  id,
      cost:    ITEMS[id].cost,
    }));
    const bagPieceIds = Object.keys(BAG_PIECE_DEFS);
    const bpId = bagPieceIds[Math.floor(Math.random() * bagPieceIds.length)];
    const bp   = BAG_PIECE_DEFS[bpId];
    return [...items, {
      offerId:    `bp-offer-${Math.random().toString(36).slice(2)}`,
      type:       'bag-piece',
      bagPieceId: bpId,
      name:       bp.name,
      desc:       bp.desc,
      cost:       bp.cost,
      shape:      bp.shape,
    }];
  }

  // ─── Public API ───────────────────────────────────────────────────────────
  return {
    CANVAS_ROWS,
    CANVAS_COLS,
    STARTING_OWNED_COORDS,
    ECONOMY,
    THEATRE_CONFIG,
    BASE_HP,
    ITEMS,
    BAG_PIECE_DEFS,
    ENEMY_POOL,
    PILOT_CONDITIONS,
    PILOT_XP_TABLE,

    makePRNG,
    rotateCW,
    getRotatedCells,
    getAbsoluteCells,
    canPlace,
    canPlaceBagPiece,
    buildOccupiedSet,

    getAdjacentItems,
    computeEffectiveStats,
    getActiveBonuses,

    initBuild,
    buildFromEnemyData,
    placeItem,
    removeItem,
    addBagPiece,
    computeHP,
    nextIid,

    simulate,
    makeTheatreState,
    tickTheatre,
    runSortie,
    computeSortieRewards,
    applyPilotRewards,
    makePilotState,
    generateShopOffers,
  };
});
