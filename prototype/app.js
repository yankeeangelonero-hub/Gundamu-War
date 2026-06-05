// app.js — Mech Bags 0.2 DOM controller
// Depends on game-core.js loaded first (window.MechBags)

(function () {
  'use strict';

  const G = window.MechBags;
  const { ITEMS, ENEMY_POOL, BAG_PIECE_DEFS, ECONOMY, PILOT_XP_TABLE, THEATRE_CONFIG } = G;

  // ─── Run state ─────────────────────────────────────────────────────────────
  let state = makeInitialState();

  function makeInitialState() {
    return {
      round:        1,
      wins:         0,
      losses:       0,
      gold:         ECONOMY.startingGold,
      build:        G.initBuild(),
      hand:         [],     // [{instanceId, type:'item'|'bag-piece', itemId?, bagPieceId?}]
      shop:         G.generateShopOffers(1),
      selected:     null,   // {instanceId, type, itemId?, bagPieceId?, relativeCells?, rotation, fromHand}
      hoverPreview: null,   // {cells: [[r,c],...], valid}
      placementMsg: null,
      sortiePhase:  'workshop', // 'workshop' | 'deployed' | 'spectating'
      sortieSeed:   1,
      theatreState: null,
      spectateIdx:  0,
      pilot:        G.makePilotState(),
    };
  }

  // ─── Theatre loop ───────────────────────────────────────────────────────────
  const TICK_MS = 100;
  let theatreInterval = null;

  function startTheatreInterval() {
    clearInterval(theatreInterval);
    theatreInterval = setInterval(() => {
      const prevLen = state.theatreState.results.length;
      G.tickTheatre(state.theatreState, state.build, ENEMY_POOL, TICK_MS);
      renderTheatreStatus();
      if (state.theatreState.results.length > prevLen) {
        renderFightChips();
        renderSortieTally();
      }
    }, TICK_MS);
  }

  function stopTheatreInterval() {
    clearInterval(theatreInterval);
    theatreInterval = null;
  }

  // ─── DOM refs ───────────────────────────────────────────────────────────────
  const $ = id => document.getElementById(id);
  let dom = {};

  function initDOM() {
    dom = {
      round:              $('stat-round'),
      wins:               $('stat-wins'),
      losses:             $('stat-losses'),
      goldDisplay:        $('gold-display'),
      buildBoard:         $('build-board'),
      handList:           $('hand-list'),
      infoBox:            $('info-box'),
      rotateBtn:          $('rotate-btn'),
      shopOffers:         $('shop-offers'),
      rerollBtn:          $('reroll-btn'),
      deployBtn:          $('deploy-btn'),
      battleBtn:          $('battle-btn'),
      battleScreen:       $('battle-screen'),
      skipBtn:            $('skip-btn'),
      leaveSpectateBtn:   $('leave-spectate-btn'),
      bannerMain:         $('banner-main'),
      bannerSub:          $('banner-sub'),
      combatLogWrap:      $('combat-log-wrap'),
      combatLog:          $('combat-log'),
      playerHPFill:       $('player-hp-fill'),
      playerHPText:       $('player-hp-text'),
      enemyHPFill:        $('enemy-hp-fill'),
      enemyHPText:        $('enemy-hp-text'),
      enemyNameLabel:     $('enemy-name-label'),
      playerSprite:       $('player-sprite'),
      enemySprite:        $('enemy-sprite'),
      resultOverlay:      $('result-overlay'),
      resultTitle:        $('result-title'),
      resultSubtitle:     $('result-subtitle'),
      resultHighlights:   $('result-highlights'),
      resultContinueBtn:  $('result-continue-btn'),
      runEndScreen:       $('run-end-screen'),
      endTitle:           $('end-title'),
      endStats:           $('end-stats'),
      newRunBtn:          $('new-run-btn'),
      pilotInfo:          $('pilot-info'),
      sortieScreen:       $('sortie-screen'),
      sortieSubtitle:     $('sortie-subtitle'),
      theatrePhaseLabel:  $('theatre-phase-label'),
      theatreProgressBar: $('theatre-progress-bar'),
      sortieFightGrid:    $('sortie-fight-grid'),
      sortieTally:        $('sortie-tally'),
      spectateBtn:        $('spectate-btn'),
      retreatBtn:         $('retreat-btn'),
      retreatOverlay:     $('retreat-overlay'),
      retreatRecord:      $('retreat-record'),
      retreatLoot:        $('retreat-loot'),
      retreatPilot:       $('retreat-pilot'),
      retreatLearn:       $('retreat-learn'),
      retreatContinueBtn: $('retreat-continue-btn'),
    };

    initCanvasPanel();
  }

  function initCanvasPanel() {
    dom.buildBoard.innerHTML = '';
    const panel = document.createElement('div');
    panel.className = 'canvas-panel';
    panel.innerHTML = '<div class="canvas-label">BUILD CANVAS</div><div class="canvas-grid"></div>';
    dom.buildBoard.appendChild(panel);
  }

  // ─── Render ─────────────────────────────────────────────────────────────────

  function renderAll() {
    renderHeader();
    renderCanvas();
    renderHand();
    renderShop();
    renderInfo();
    renderPilot();
  }

  function renderHeader() {
    dom.round.textContent       = state.round;
    dom.wins.textContent        = state.wins;
    dom.losses.textContent      = state.losses;
    dom.goldDisplay.textContent = state.gold;
  }

  function buildCellMap(canvas) {
    const map = {};
    for (const pi of canvas.items) {
      const cells = G.getAbsoluteCells(pi.row, pi.col,
        G.getRotatedCells(ITEMS[pi.itemId].shape, pi.rotation));
      const sorted = cells.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]);
      const first = sorted[0];
      for (const [r, c] of cells) {
        map[`${r},${c}`] = {
          instanceId: pi.instanceId,
          itemId:     pi.itemId,
          isFirst:    r === first[0] && c === first[1],
          item:       ITEMS[pi.itemId],
        };
      }
    }
    return map;
  }

  function renderCanvas() {
    const canvas = state.build.canvas;
    const panel  = document.querySelector('.canvas-panel');
    if (!panel) return;
    const grid = panel.querySelector('.canvas-grid');
    grid.style.gridTemplateColumns = `repeat(${canvas.cols}, var(--cell-size))`;

    const cellMap  = buildCellMap(canvas);
    const bonuses  = G.getActiveBonuses(canvas.items);
    const bonusIds = new Set(bonuses.map(b => b.sourceId));

    const preview     = state.hoverPreview;
    const previewKeys = preview
      ? new Set(preview.cells.map(([r, c]) => `${r},${c}`)) : new Set();
    const selPlacedId = (state.selected && !state.selected.fromHand)
      ? state.selected.instanceId : null;

    grid.innerHTML = '';
    for (let r = 0; r < canvas.rows; r++) {
      for (let c = 0; c < canvas.cols; c++) {
        const key   = `${r},${c}`;
        const owned = canvas.ownedCells.has(key);
        const cell  = document.createElement('div');
        cell.className = 'canvas-cell' + (owned ? '' : ' unowned');
        cell.dataset.row = r;
        cell.dataset.col = c;

        const info = cellMap[key];
        if (info) {
          cell.style.background = info.item.color;
          cell.style.border     = `1px solid ${lighten(info.item.color)}`;
          if (bonusIds.has(info.instanceId)) cell.classList.add('has-bonus');
          if (selPlacedId === info.instanceId) cell.classList.add('placed-selected');
          if (info.isFirst) {
            const tile = document.createElement('div');
            tile.className = 'item-tile';
            tile.style.background = info.item.color;
            tile.title = info.item.name + '\n' + info.item.desc;
            tile.textContent = abbrev(info.item.name);
            tile.dataset.instanceId = info.instanceId;
            if (selPlacedId === info.instanceId) tile.classList.add('selected');
            cell.appendChild(tile);
          }
          cell.dataset.instanceId = info.instanceId;
        }

        if (previewKeys.has(key)) {
          cell.classList.add(preview.valid ? 'valid-drop' : 'invalid-drop');
        }

        cell.addEventListener('click',      () => onCellClick(r, c));
        cell.addEventListener('mouseenter', () => onCellHover(r, c));
        cell.addEventListener('mouseleave', onCellLeave);
        grid.appendChild(cell);
      }
    }
  }

  function abbrev(name) {
    const words = name.split(' ');
    if (words.length === 1) return name.slice(0, 3).toUpperCase();
    return words.map(w => w[0]).join('').toUpperCase();
  }

  function lighten(hex) {
    try {
      const n = parseInt(hex.slice(1), 16);
      const r = Math.min(255, ((n >> 16) & 0xff) + 60);
      const g = Math.min(255, ((n >> 8)  & 0xff) + 60);
      const b = Math.min(255, (n         & 0xff) + 60);
      return `rgb(${r},${g},${b})`;
    } catch { return hex; }
  }

  function renderHand() {
    dom.handList.innerHTML = '';
    if (state.hand.length === 0) {
      dom.handList.innerHTML =
        '<div style="color:var(--text-dim);font-size:11px;padding:4px">No items in hand</div>';
      return;
    }
    state.hand.forEach((hi, idx) => {
      const isSelected = state.selected && state.selected.instanceId === hi.instanceId;
      const div = document.createElement('div');

      if (hi.type === 'bag-piece') {
        const def = BAG_PIECE_DEFS[hi.bagPieceId];
        div.className = 'hand-item bag-piece' + (isSelected ? ' selected' : '');
        div.innerHTML = `
          <div class="item-dot" style="background:#1a3050;border:1px solid #4da6ff"></div>
          <span class="item-label">${def.name}</span>
          <span class="sell-btn" data-iid="${hi.instanceId}" title="Sell for ${Math.floor(def.cost / 2)}g">$${Math.floor(def.cost / 2)}</span>`;
      } else {
        const item = ITEMS[hi.itemId];
        div.className = 'hand-item' + (isSelected ? ' selected' : '');
        div.innerHTML = `
          <div class="item-dot" style="background:${item.color}"></div>
          <span class="item-label">${item.name}</span>
          <span class="sell-btn" data-iid="${hi.instanceId}" title="Sell for ${Math.floor(item.cost / 2)}g">$${Math.floor(item.cost / 2)}</span>`;
      }

      div.addEventListener('click', e => {
        if (e.target.classList.contains('sell-btn')) sellItem(hi.instanceId);
        else selectHandItem(idx);
      });
      dom.handList.appendChild(div);
    });
  }

  function renderShop() {
    dom.shopOffers.innerHTML = '';
    for (const offer of state.shop) {
      const card = document.createElement('div');
      const cantAfford = state.gold < offer.cost;
      let color, name, desc;
      if (offer.type === 'bag-piece') {
        const def = BAG_PIECE_DEFS[offer.bagPieceId];
        color = '#4da6ff';
        name  = def.name;
        desc  = def.desc;
      } else {
        color = ITEMS[offer.itemId].color;
        name  = ITEMS[offer.itemId].name;
        desc  = ITEMS[offer.itemId].desc;
      }
      card.className = 'shop-card'
        + (cantAfford ? ' cant-afford' : '')
        + (offer.type === 'bag-piece' ? ' bag-piece' : '');
      card.innerHTML = `
        <div class="card-color-bar" style="background:${color}"></div>
        <div class="card-name">${name}</div>
        <div class="card-cost">${offer.cost}g</div>
        <div class="card-desc">${desc}</div>`;
      if (!cantAfford) card.addEventListener('click', () => onShopCardClick(offer));
      dom.shopOffers.appendChild(card);
    }
  }

  function renderInfo() {
    if (!state.selected) {
      dom.infoBox.innerHTML =
        '<span style="color:var(--text-dim)"><strong style="color:var(--text-bright)">How to play:</strong> Buy parts or bag pieces below — they land in your Hand. Select one, then tap the canvas to place it.<br><br>Items require <strong style="color:var(--text-bright)">owned cells</strong>. Buy bag pieces to expand your space. Hit <strong style="color:var(--amber)">&#9876; Deploy</strong> to send your build to the theatre!</span>';
      dom.rotateBtn.disabled = true;
      return;
    }
    dom.rotateBtn.disabled = false;
    const { type, itemId, bagPieceId, rotation, fromHand, instanceId } = state.selected;

    if (type === 'bag-piece') {
      const def = BAG_PIECE_DEFS[bagPieceId];
      let html = `<strong>${def.name}</strong><br>${def.desc}<br><br>`;
      html += `<small style="color:var(--text-dim)">Rotation: ${rotation * 90}° &nbsp; Cost: ${def.cost}g &nbsp; Sell: ${Math.floor(def.cost / 2)}g</small>`;
      if (fromHand) html += `<div class="place-cta">Tap canvas cells to attach. Use &#8635; Rotate to orient.</div>`;
      if (state.placementMsg) html += `<div class="place-error">${state.placementMsg}</div>`;
      dom.infoBox.innerHTML = html;
      return;
    }

    const item = ITEMS[itemId];
    let html = `<strong>${item.name}</strong><br>${item.desc}<br><br>`;
    if (item.damage > 0)    html += `⚔ ${item.damage} dmg | ⏱ ${item.speed} spd | 🎯 ${Math.round(item.accuracy * 100)}% acc<br>`;
    if (item.critChance > 0.05) html += `💥 ${Math.round(item.critChance * 100)}% crit<br>`;
    if (item.hp > 0)        html += `❤ +${item.hp} HP<br>`;
    if (item.blockChance)   html += `🛡 ${Math.round(item.blockChance * 100)}% block<br>`;
    html += `<br>Tags: ${item.tags.join(', ')}<br>`;
    if (item.adjacency && item.adjacency.length > 0) {
      html += '<br>';
      for (const rule of item.adjacency) html += `<span class="bonus-tag">${rule.desc}</span> `;
    }
    html += `<br><small style="color:var(--text-dim)">Rotation: ${rotation * 90}° &nbsp; Cost: ${item.cost}g &nbsp; Sell: ${Math.floor(item.cost / 2)}g</small>`;
    if (fromHand) {
      html += `<div class="place-cta">Tap an owned canvas cell to place. Use &#8635; Rotate if it doesn't fit.</div>`;
    } else {
      html += `<div class="place-cta">Tap another owned cell to move. &#8635; Rotate to turn in place.</div>`;
      html += `<button class="info-sell-btn" data-iid="${instanceId}">Sell for ${Math.floor(item.cost / 2)}g</button>`;
    }
    if (state.placementMsg) html += `<div class="place-error">${state.placementMsg}</div>`;
    dom.infoBox.innerHTML = html;
  }

  function renderPilot() {
    const p        = state.pilot;
    const xpTarget = p.level < PILOT_XP_TABLE.length ? PILOT_XP_TABLE[p.level] : '—';
    const xpPct    = p.level < PILOT_XP_TABLE.length
      ? Math.round((p.xp / PILOT_XP_TABLE[p.level]) * 100) : 100;
    const condClass = p.condition.replace(/\s+/g, '-');

    let skillsHtml = '<div class="pilot-skills">';
    for (const sk of Object.values(p.skills)) {
      let pips = '';
      for (let i = 0; i < sk.max; i++) {
        pips += `<div class="pilot-skill-pip${i < sk.progress ? ' filled' : ''}"></div>`;
      }
      skillsHtml += `<div class="pilot-skill-row">
        <span class="pilot-skill-name">${sk.name}</span>
        <span class="pilot-skill-pips">${pips}</span>
      </div>`;
    }
    skillsHtml += '</div>';

    dom.pilotInfo.innerHTML = `
      <div class="pilot-name">${p.name}</div>
      <div class="pilot-level-row">
        <span class="pilot-level-badge">LVL ${p.level}</span>
        <div class="pilot-xp-bar-wrap">
          <div class="pilot-xp-bar-bg">
            <div class="pilot-xp-bar-fill" style="width:${xpPct}%"></div>
          </div>
          <div class="pilot-xp-text">${p.xp} / ${xpTarget} XP</div>
        </div>
      </div>
      <span class="pilot-condition ${condClass}">${p.condition}</span>
      ${skillsHtml}
      <div class="pilot-sorties">${p.sorties} sortie${p.sorties !== 1 ? 's' : ''} complete</div>`;
  }

  function renderTheatreStatus() {
    const ts = state.theatreState;
    if (!ts) return;
    const pct = ts.phaseDuration > 0
      ? Math.min(100, Math.round((ts.elapsed / ts.phaseDuration) * 100)) : 0;
    const remaining = ((ts.phaseDuration - ts.elapsed) / 1000).toFixed(1);

    let text, cls;
    if (ts.phase === 'fighting') {
      text = `FIGHTING — Fight #${ts.fightIdx + 1} (${remaining}s remaining)`;
      cls  = 'phase-fighting';
    } else if (ts.phase === 'victory-downtime') {
      text = `VICTORY — Resupply downtime (${remaining}s)`;
      cls  = 'phase-victory';
    } else if (ts.phase === 'loss-downtime') {
      text = `DEFEATED — Repair delay (${remaining}s)`;
      cls  = 'phase-loss';
    } else {
      text = 'RETREATED';
      cls  = 'phase-retreated';
    }

    dom.theatrePhaseLabel.textContent = text;
    dom.theatrePhaseLabel.className   = cls;
    dom.theatreProgressBar.style.width = pct + '%';
    dom.theatreProgressBar.className   = cls;
  }

  function renderFightChips() {
    dom.sortieFightGrid.innerHTML = '';
    const results = state.theatreState.results;
    for (let i = 0; i < results.length; i++) {
      const r    = results[i];
      const chip = document.createElement('div');
      chip.className   = `fight-chip ${r.winner === 'player' ? 'win' : 'loss'}`;
      chip.textContent = `${r.winner === 'player' ? '✓' : '✗'} ${r.enemyName}`;
      chip.title       = `Fight #${i + 1}: ${r.enemyName} — ${r.winner === 'player' ? 'Victory' : 'Defeat'} | HP: ${Math.max(0, r.finalPlayerHP)}`;
      const idx = i;
      chip.addEventListener('click', () => onSpectate(idx));
      dom.sortieFightGrid.appendChild(chip);
    }
  }

  function renderSortieTally() {
    const ts = state.theatreState;
    dom.sortieTally.innerHTML =
      `<span class="tally-wins">${ts.wins} W</span> / <span class="tally-losses">${ts.losses} L</span>`;
  }

  // ─── Cell interactions ──────────────────────────────────────────────────────

  function onCellClick(row, col) {
    const canvas  = state.build.canvas;
    const cellMap = buildCellMap(canvas);
    const destInfo = cellMap[`${row},${col}`];

    if (!state.selected) {
      if (destInfo) selectPlacedItem(destInfo.instanceId);
      return;
    }

    const { instanceId, type, itemId, bagPieceId, relativeCells, rotation, fromHand } = state.selected;

    if (type === 'bag-piece') {
      if (!G.canPlaceBagPiece(canvas.rows, canvas.cols, row, col, relativeCells)) {
        state.placementMsg = 'Bag piece goes out of canvas bounds — move anchor or rotate.';
        renderInfo();
        return;
      }
      const hi = state.hand.findIndex(h => h.instanceId === instanceId);
      if (hi !== -1) state.hand.splice(hi, 1);
      G.addBagPiece(state.build, row, col, relativeCells);
      state.selected     = null;
      state.placementMsg = null;
      state.hoverPreview = null;
      renderAll();
      return;
    }

    // type === 'item'
    if (!fromHand) {
      if (destInfo) {
        if (destInfo.instanceId === instanceId) {
          state.selected     = null;
          state.placementMsg = null;
          state.hoverPreview = null;
          renderAll();
        } else {
          selectPlacedItem(destInfo.instanceId);
        }
        return;
      }
    }

    if (!canvas.ownedCells.has(`${row},${col}`)) {
      state.placementMsg = "Can't place on unowned cells — buy a bag piece to expand first.";
      renderInfo();
      return;
    }

    const cells    = G.getRotatedCells(ITEMS[itemId].shape, rotation);
    const occupied = G.buildOccupiedSet(canvas.items, fromHand ? null : instanceId);
    if (!G.canPlace(canvas.rows, canvas.cols, canvas.ownedCells, occupied, row, col, cells)) {
      state.placementMsg = "Doesn't fit here — rotate or try another cell.";
      renderInfo();
      return;
    }

    if (!fromHand) G.removeItem(state.build, instanceId);
    else {
      const hi = state.hand.findIndex(h => h.instanceId === instanceId);
      if (hi !== -1) state.hand.splice(hi, 1);
    }

    G.placeItem(state.build, instanceId, itemId, row, col, rotation);
    state.selected     = null;
    state.placementMsg = null;
    state.hoverPreview = null;
    renderAll();
  }

  function onCellHover(row, col) {
    if (!state.selected) { state.hoverPreview = null; return; }
    const canvas = state.build.canvas;
    const { type, itemId, bagPieceId, relativeCells, rotation, instanceId, fromHand } = state.selected;
    let cells, valid;

    if (type === 'bag-piece') {
      cells = G.getAbsoluteCells(row, col, relativeCells);
      valid = G.canPlaceBagPiece(canvas.rows, canvas.cols, row, col, relativeCells);
    } else {
      const shapeCells = G.getRotatedCells(ITEMS[itemId].shape, rotation);
      cells = G.getAbsoluteCells(row, col, shapeCells);
      const occupied = G.buildOccupiedSet(canvas.items, fromHand ? null : instanceId);
      valid = G.canPlace(canvas.rows, canvas.cols, canvas.ownedCells, occupied, row, col, shapeCells);
    }

    state.hoverPreview = { cells, valid };
    applyPreview();
  }

  function onCellLeave() {
    state.hoverPreview = null;
    applyPreview();
  }

  // Update preview classes on live cells without rebuilding the grid.
  // This keeps click events attached and prevents mobile tap-placement failures.
  function applyPreview() {
    document.querySelectorAll('.canvas-cell.valid-drop, .canvas-cell.invalid-drop')
      .forEach(c => c.classList.remove('valid-drop', 'invalid-drop'));
    const p = state.hoverPreview;
    if (!p) return;
    const cls = p.valid ? 'valid-drop' : 'invalid-drop';
    for (const [r, c] of p.cells) {
      const cell = document.querySelector(
        `.canvas-grid .canvas-cell[data-row="${r}"][data-col="${c}"]`);
      if (cell) cell.classList.add(cls);
    }
  }

  function selectPlacedItem(instanceId) {
    const pi = state.build.canvas.items.find(i => i.instanceId === instanceId);
    if (!pi) return;

    // Backpack Battles-style edit loop: clicking a placed block picks it up
    // into the hand, so R / Rotate always works before choosing a new cell.
    // This avoids the confusing "selected in place but cannot rotate here" state.
    G.removeItem(state.build, instanceId);
    if (!state.hand.some(h => h.instanceId === instanceId)) {
      state.hand.push({ instanceId, type: 'item', itemId: pi.itemId });
    }
    state.selected = {
      instanceId,
      type:     'item',
      itemId:   pi.itemId,
      rotation: pi.rotation,
      fromHand: true,
    };
    state.placementMsg = 'Picked up — press R / Rotate, then tap an owned canvas cell to place.';
    state.hoverPreview = null;
    renderAll();
  }

  function selectHandItem(idx) {
    const hi = state.hand[idx];
    if (state.selected && state.selected.instanceId === hi.instanceId) {
      state.selected = null;
    } else if (hi.type === 'bag-piece') {
      const def  = BAG_PIECE_DEFS[hi.bagPieceId];
      const prev = (state.selected && state.selected.bagPieceId === hi.bagPieceId)
        ? state.selected.rotation : 0;
      state.selected = {
        instanceId:    hi.instanceId,
        type:          'bag-piece',
        bagPieceId:    hi.bagPieceId,
        relativeCells: G.getRotatedCells(def.shape, prev),
        rotation:      prev,
        fromHand:      true,
      };
    } else {
      const prev = (state.selected && state.selected.itemId === hi.itemId)
        ? state.selected.rotation : 0;
      state.selected = { instanceId: hi.instanceId, type: 'item', itemId: hi.itemId, rotation: prev, fromHand: true };
    }
    state.placementMsg = null;
    state.hoverPreview = null;
    renderAll();
  }

  function sellItem(instanceId) {
    const hi = state.hand.findIndex(h => h.instanceId === instanceId);
    if (hi !== -1) {
      const handItem = state.hand[hi];
      state.hand.splice(hi, 1);
      if (handItem.type === 'bag-piece') {
        state.gold += Math.floor(BAG_PIECE_DEFS[handItem.bagPieceId].cost / 2);
      } else {
        state.gold += Math.floor(ITEMS[handItem.itemId].cost / 2);
      }
      if (state.selected && state.selected.instanceId === instanceId) state.selected = null;
      renderAll();
      return;
    }
    const pi = state.build.canvas.items.find(i => i.instanceId === instanceId);
    if (pi) {
      G.removeItem(state.build, instanceId);
      state.gold += Math.floor(ITEMS[pi.itemId].cost / 2);
      if (state.selected && state.selected.instanceId === instanceId) state.selected = null;
      renderAll();
    }
  }

  function onShopCardClick(offer) {
    if (state.gold < offer.cost) return;
    state.gold -= offer.cost;
    state.placementMsg = null;

    if (offer.type === 'bag-piece') {
      const iid = G.nextIid();
      const def = BAG_PIECE_DEFS[offer.bagPieceId];
      state.hand.push({ instanceId: iid, type: 'bag-piece', bagPieceId: offer.bagPieceId });
      state.selected = {
        instanceId:    iid,
        type:          'bag-piece',
        bagPieceId:    offer.bagPieceId,
        relativeCells: def.shape,
        rotation:      0,
        fromHand:      true,
      };
      renderAll();
      return;
    }

    const iid = G.nextIid();
    state.hand.push({ instanceId: iid, type: 'item', itemId: offer.itemId });
    state.selected = { instanceId: iid, type: 'item', itemId: offer.itemId, rotation: 0, fromHand: true };
    renderAll();
  }

  function onRotate() {
    if (!state.selected) return;
    const { type, instanceId, itemId, bagPieceId, fromHand } = state.selected;
    const newRot = (state.selected.rotation + 1) % 4;

    if (type === 'bag-piece') {
      const def = BAG_PIECE_DEFS[bagPieceId];
      state.selected.rotation      = newRot;
      state.selected.relativeCells = G.getRotatedCells(def.shape, newRot);
      state.placementMsg           = null;
      renderInfo();
      if (state.hoverPreview) { state.hoverPreview = null; renderCanvas(); }
      return;
    }

    if (!fromHand) {
      const canvas = state.build.canvas;
      const pi = canvas.items.find(i => i.instanceId === instanceId);
      if (!pi) return;
      const occupied = G.buildOccupiedSet(canvas.items, instanceId);
      if (G.canPlace(canvas.rows, canvas.cols, canvas.ownedCells, occupied, pi.row, pi.col,
                     G.getRotatedCells(ITEMS[itemId].shape, newRot))) {
        pi.rotation                = newRot;
        state.selected.rotation    = newRot;
        state.placementMsg         = null;
      } else {
        state.placementMsg = "Can't rotate here — move it first.";
      }
      state.hoverPreview = null;
      renderCanvas();
      renderInfo();
      return;
    }

    state.selected.rotation = newRot;
    state.placementMsg      = null;
    renderInfo();
    if (state.hoverPreview) { state.hoverPreview = null; renderCanvas(); }
  }

  function onReroll() {
    if (state.gold < ECONOMY.rerollCost) return;
    state.gold -= ECONOMY.rerollCost;
    state.shop  = G.generateShopOffers(state.round);
    renderHeader();
    renderShop();
  }

  // ─── Sortie — real-time theatre ─────────────────────────────────────────────

  function onDeploy() {
    const sortieSeed = ((state.sortieSeed + state.pilot.sorties * 997 + 1) >>> 0) || 1;
    state.sortieSeed   = sortieSeed;
    state.theatreState = G.makeTheatreState(sortieSeed);
    // Prepare the first fight immediately so the UI timer reflects the
    // actual simulated battle length × theatre scale, not a placeholder.
    G.tickTheatre(state.theatreState, state.build, ENEMY_POOL, 0);
    state.sortiePhase  = 'deployed';

    dom.sortieScreen.classList.add('active');
    dom.sortieSubtitle.textContent = `Sortie #${state.pilot.sorties + 1} — seed ${sortieSeed}`;
    dom.sortieFightGrid.innerHTML  = '';
    dom.sortieTally.textContent    = '';
    renderTheatreStatus();
    startTheatreInterval();
  }

  function onSpectate(idx) {
    const results = state.theatreState ? state.theatreState.results : [];
    if (results.length === 0) return;
    const fightIdx = idx !== undefined ? idx : results.length - 1;
    const fight    = results[fightIdx];
    if (!fight) return;

    state.sortiePhase = 'spectating';
    state.spectateIdx = fightIdx;
    dom.sortieScreen.classList.remove('active');

    const enemyData  = ENEMY_POOL[fight.enemyIdx];
    const enemyBuild = G.buildFromEnemyData(enemyData);
    const pMaxHP     = G.computeHP(state.build);
    const eMaxHP     = G.computeHP(enemyBuild);

    battleData = {
      result: {
        winner:         fight.winner,
        finalPlayerHP:  fight.finalPlayerHP,
        finalEnemyHP:   fight.finalEnemyHP,
        events:         fight.events,
      },
      enemyData, enemyBuild, playerMaxHP: pMaxHP, enemyMaxHP: eMaxHP,
      spectateMode: true,
    };
    battleAbort = false;

    dom.enemyNameLabel.textContent = enemyData.name;
    setHPBar(dom.playerHPFill, dom.playerHPText, pMaxHP, pMaxHP);
    setHPBar(dom.enemyHPFill,  dom.enemyHPText,  eMaxHP,  eMaxHP);
    dom.combatLog.innerHTML    = '';
    dom.bannerMain.textContent = `SPECTATING FIGHT #${fightIdx + 1}`;
    dom.bannerSub.textContent  = `vs. ${enemyData.name} — result already determined`;
    dom.battleScreen.classList.add('active');
    dom.leaveSpectateBtn.style.display = '';
    dom.skipBtn.style.display          = '';
    dom.skipBtn.disabled               = false;

    playBattle(fight.events, pMaxHP, eMaxHP);
  }

  function onLeaveSpectate() {
    battleAbort = true;
    state.sortiePhase = 'deployed';
    dom.battleScreen.classList.remove('active');
    dom.resultOverlay.classList.remove('active');
    dom.leaveSpectateBtn.style.display = 'none';
    dom.sortieScreen.classList.add('active');
    renderTheatreStatus();
    renderFightChips();
    renderSortieTally();
  }

  function onRetreat() {
    stopTheatreInterval();
    dom.sortieScreen.classList.remove('active');

    const ts  = state.theatreState;
    const rew = G.computeSortieRewards(ts, state.pilot);
    state.pilot = G.applyPilotRewards(state.pilot, rew);
    state.gold += rew.lootGained;

    const numFights = ts.results.length;
    dom.retreatRecord.innerHTML = `
      <div class="retreat-section">
        <div class="retreat-section-label">Sortie Record</div>
        <div class="retreat-section-body">
          <strong>${ts.wins} wins</strong> / <strong>${ts.losses} losses</strong> — ${numFights} fight${numFights !== 1 ? 's' : ''} completed<br>
          ${ts.results.map(r =>
            `<span class="${r.winner === 'player' ? 'hi-green' : 'hi-red'}">${r.winner === 'player' ? '✓' : '✗'} ${r.enemyName}</span>`
          ).join('  ')}
        </div>
      </div>`;

    dom.retreatLoot.innerHTML = `
      <div class="retreat-section">
        <div class="retreat-section-label">Loot</div>
        <div class="retreat-section-body">
          <span class="hi-amber">+${rew.lootGained}g salvage</span> added<br>
          New balance: <strong>${state.gold}g</strong>
        </div>
      </div>`;

    const p        = state.pilot;
    const xpTarget = p.level < PILOT_XP_TABLE.length ? PILOT_XP_TABLE[p.level] : '—';
    const skillLines = Object.entries(rew.skillProgress).map(([key, delta]) => {
      const sk = p.skills[key];
      return sk ? `<span class="hi-blue">${sk.name}: ${sk.progress}/${sk.max}</span>` : '';
    }).filter(Boolean).join('<br>');

    dom.retreatPilot.innerHTML = `
      <div class="retreat-section">
        <div class="retreat-section-label">Pilot — ${p.name}</div>
        <div class="retreat-section-body">
          <span class="hi-amber">+${rew.xpGained} XP</span> → Level <strong>${p.level}</strong> (${p.xp} / ${xpTarget} XP)<br>
          Condition: <strong>${p.condition}</strong><br>
          ${skillLines || '(No new skill progress this sortie)'}
        </div>
      </div>`;

    dom.retreatLearn.innerHTML = `
      <div class="retreat-section">
        <div class="retreat-section-label">Learning Signal</div>
        <div class="retreat-section-body">${rew.learningSignal}</div>
      </div>`;

    dom.retreatOverlay.classList.add('active');
    renderHeader();
    renderPilot();
  }

  function onRetreatContinue() {
    dom.retreatOverlay.classList.remove('active');
    state.sortiePhase  = 'workshop';
    state.theatreState = null;
    state.round++;
    state.shop = G.generateShopOffers(state.round);
    renderAll();
  }

  // ─── Quick battle (Battle! button) ──────────────────────────────────────────

  let battleData  = null;
  let battleAbort = false;

  function onBattleClick() {
    const enemyIdx   = (state.round - 1) % ENEMY_POOL.length;
    const enemyData  = ENEMY_POOL[enemyIdx];
    const enemyBuild = G.buildFromEnemyData(enemyData);
    const seed       = state.round * 137 + state.wins * 31 + state.losses * 17 + 1;
    const result     = G.simulate(state.build, enemyBuild, seed);
    const pMaxHP     = G.computeHP(state.build);
    const eMaxHP     = G.computeHP(enemyBuild);

    battleData  = { result, enemyData, enemyBuild, playerMaxHP: pMaxHP, enemyMaxHP: eMaxHP };
    battleAbort = false;

    dom.enemyNameLabel.textContent = enemyData.name;
    setHPBar(dom.playerHPFill, dom.playerHPText, pMaxHP, pMaxHP);
    setHPBar(dom.enemyHPFill,  dom.enemyHPText,  eMaxHP, eMaxHP);
    dom.combatLog.innerHTML    = '';
    dom.bannerMain.textContent = 'BATTLE START!';
    dom.bannerSub.textContent  = `Round ${state.round} — vs. ${enemyData.name}`;
    dom.battleScreen.classList.add('active');
    dom.leaveSpectateBtn.style.display = 'none';
    dom.skipBtn.style.display          = '';
    dom.skipBtn.disabled               = false;

    playBattle(result.events, pMaxHP, eMaxHP);
  }

  async function playBattle(events, pMax, eMax) {
    await sleep(700);
    for (const ev of events) {
      if (battleAbort) return;
      await animateEvent(ev, pMax, eMax);
    }
    if (!battleAbort) {
      await sleep(500);
      showResult();
    }
  }

  async function animateEvent(ev, pMax, eMax) {
    dom.bannerMain.textContent = `${ev.itemName} fires!`;
    dom.bannerSub.textContent  = '';

    const isPlayer  = ev.attackerSide === 'player';
    const srcSprite  = isPlayer ? dom.playerSprite : dom.enemySprite;
    const destSprite = isPlayer ? dom.enemySprite  : dom.playerSprite;
    const projType   = projTypeFor(ev.itemId);

    await animateProjectile(
      getAnchor(srcSprite, 'torso'),
      getAnchor(destSprite, 'torso'),
      projType
    );

    const isMiss  = ev.effects.includes('miss');
    const isBlock = ev.effects.includes('blocked');
    const isCrit  = ev.effects.includes('crit');
    const destCenter = getAnchor(destSprite, 'torso');

    if (isMiss) {
      spawnFlash(destCenter, 'miss');
      spawnDmgNum(destCenter, 'MISS', 'miss');
    } else if (isBlock) {
      spawnFlash(destCenter, 'block');
      spawnDmgNum(destCenter, 'BLOCK', 'block');
    } else {
      spawnFlash(destCenter, isCrit ? 'crit' : 'hit');
      spawnDmgNum(destCenter, `-${ev.damage}`, isCrit ? 'crit' : 'normal');
    }

    await sleep(160);
    setHPBar(dom.playerHPFill, dom.playerHPText, ev.playerHP, pMax);
    setHPBar(dom.enemyHPFill,  dom.enemyHPText,  ev.enemyHP,  eMax);

    const entry = document.createElement('div');
    let logCls = isPlayer ? 'player' : 'enemy';
    let logTxt = ev.itemName;
    if (isMiss)       { logCls = 'miss';  logTxt += ' — missed!'; }
    else if (isBlock) { logCls = 'block'; logTxt += ` — BLOCKED! (0 dmg)`; }
    else if (isCrit)  { logCls = 'crit';  logTxt += ` — CRIT! ${ev.damage} dmg`; }
    else              { logTxt += ` dealt ${ev.damage} dmg`; }
    entry.className = `log-entry ${logCls}`;
    entry.textContent = logTxt;
    dom.combatLog.appendChild(entry);
    dom.combatLogWrap.scrollTop = dom.combatLogWrap.scrollHeight;

    await sleep(220);
  }

  function projTypeFor(itemId) {
    const item = ITEMS[itemId];
    if (!item) return 'bullet';
    if (item.tags.includes('beam'))      return 'beam';
    if (item.tags.includes('explosive')) return 'missile';
    return 'bullet';
  }

  function getAnchor(spriteEl, anchorName) {
    return spriteEl.querySelector(`[data-anchor="${anchorName}"]`) || spriteEl;
  }

  function animateProjectile(srcEl, destEl, type) {
    return new Promise(resolve => {
      const proj = document.createElement('div');
      proj.className = `anim-projectile ${type}`;
      document.body.appendChild(proj);

      const sr = srcEl.getBoundingClientRect();
      const dr = destEl.getBoundingClientRect();
      const sx = sr.left + sr.width  / 2;
      const sy = sr.top  + sr.height / 2;
      const dx = dr.left + dr.width  / 2;
      const dy = dr.top  + dr.height / 2;

      proj.style.cssText = `left:${sx}px;top:${sy}px;transform:translate(-50%,-50%)`;
      const dur = type === 'missile' ? 460 : type === 'beam' ? 310 : 270;

      proj.animate(
        [{ left: `${sx}px`, top: `${sy}px`, opacity: 1 },
         { left: `${dx}px`, top: `${dy}px`, opacity: 0.4 }],
        { duration: dur, easing: 'ease-in', fill: 'forwards' }
      ).onfinish = () => { proj.remove(); resolve(); };
    });
  }

  function spawnFlash(el, type) {
    const f = document.createElement('div');
    f.className = `anim-flash ${type}`;
    document.body.appendChild(f);
    const r = el.getBoundingClientRect();
    f.style.cssText = `left:${r.left + r.width / 2}px;top:${r.top + r.height / 2}px`;
    f.animate(
      [{ opacity: 1, transform: 'translate(-50%,-50%) scale(1)' },
       { opacity: 0, transform: 'translate(-50%,-50%) scale(2.2)' }],
      { duration: 380, fill: 'forwards' }
    ).onfinish = () => f.remove();
  }

  function spawnDmgNum(el, text, cls) {
    const n = document.createElement('div');
    n.className   = `damage-number ${cls}`;
    n.textContent = text;
    document.body.appendChild(n);
    const r = el.getBoundingClientRect();
    n.style.cssText = `left:${r.left + r.width / 2}px;top:${r.top - 8}px`;
    setTimeout(() => n.remove(), 850);
  }

  function setHPBar(fillEl, textEl, current, max) {
    const pct = max > 0 ? Math.max(0, current / max) : 0;
    fillEl.style.width  = (pct * 100) + '%';
    fillEl.className = 'hp-bar-fill' + (pct < 0.25 ? ' crit' : pct < 0.5 ? ' low' : '');
    textEl.textContent = Math.max(0, current) + ' / ' + max;
  }

  function onSkipBattle() {
    battleAbort = true;
    dom.skipBtn.disabled = true;
    const { result, playerMaxHP, enemyMaxHP } = battleData;
    setHPBar(dom.playerHPFill, dom.playerHPText, result.finalPlayerHP, playerMaxHP);
    setHPBar(dom.enemyHPFill,  dom.enemyHPText,  result.finalEnemyHP,  enemyMaxHP);
    dom.bannerMain.textContent = result.winner === 'player' ? '⚡ VICTORY!' : '💀 DEFEAT!';
    dom.bannerSub.textContent  = 'Battle resolved instantly.';
    dom.combatLog.innerHTML = '';
    for (const ev of result.events) {
      const isMiss  = ev.effects.includes('miss');
      const isBlock = ev.effects.includes('blocked');
      const isCrit  = ev.effects.includes('crit');
      let t = ev.itemName;
      if (isMiss)       t += ' — missed!';
      else if (isBlock) t += ' — BLOCKED!';
      else if (isCrit)  t += ` — CRIT! ${ev.damage}`;
      else              t += ` dealt ${ev.damage}`;
      const e = document.createElement('div');
      e.className   = 'log-entry ' + (isMiss ? 'miss' : isBlock ? 'block' : isCrit ? 'crit' : ev.attackerSide === 'player' ? 'player' : 'enemy');
      e.textContent = t;
      dom.combatLog.appendChild(e);
    }
    dom.combatLogWrap.scrollTop = dom.combatLogWrap.scrollHeight;
    setTimeout(showResult, 600);
  }

  function showResult() {
    const { result, playerMaxHP, enemyMaxHP, spectateMode } = battleData;
    const won = result.winner === 'player';

    const itemDmg = {};
    for (const ev of result.events) {
      if (ev.attackerSide === 'player' && ev.damage > 0) {
        itemDmg[ev.itemName] = (itemDmg[ev.itemName] || 0) + ev.damage;
      }
    }
    const topItem = Object.entries(itemDmg).sort((a, b) => b[1] - a[1])[0];

    dom.resultTitle.textContent = won ? 'VICTORY!' : 'DEFEAT!';
    dom.resultTitle.className   = `result-title ${won ? 'win' : 'loss'}`;

    if (spectateMode) {
      dom.resultSubtitle.textContent   = 'Spectating resolved fight. Leave to return to sortie.';
      dom.resultContinueBtn.textContent = '← Return to Sortie';
    } else {
      dom.resultSubtitle.textContent   = won
        ? `Enemy mech destroyed! (+${ECONOMY.winReward}g next round)`
        : `Your mech was defeated. (+${ECONOMY.lossReward}g next round)`;
      dom.resultContinueBtn.textContent = 'Continue →';
    }

    let hi = '';
    if (topItem) hi += `Top weapon: <strong>${topItem[0]}</strong> — ${topItem[1]} total damage.<br>`;
    hi += `Final HP: Yours <strong>${Math.max(0, result.finalPlayerHP)}/${playerMaxHP}</strong> — Enemy <strong>${Math.max(0, result.finalEnemyHP)}/${enemyMaxHP}</strong>.<br>`;
    hi += `${result.events.length} attack events.`;
    dom.resultHighlights.innerHTML = hi;
    dom.resultOverlay.classList.add('active');
  }

  function onResultContinue() {
    dom.resultOverlay.classList.remove('active');
    dom.battleScreen.classList.remove('active');
    dom.leaveSpectateBtn.style.display = 'none';

    if (battleData && battleData.spectateMode) {
      onLeaveSpectate();
      return;
    }

    const won = battleData.result.winner === 'player';
    if (won) { state.wins++;   state.gold += ECONOMY.winReward; }
    else     { state.losses++; state.gold += ECONOMY.lossReward; }

    if (state.wins   >= ECONOMY.WIN_THRESHOLD)  { renderHeader(); showRunEnd('win');  return; }
    if (state.losses >= ECONOMY.LOSS_THRESHOLD) { renderHeader(); showRunEnd('loss'); return; }

    state.round++;
    state.shop = G.generateShopOffers(state.round);
    renderAll();
  }

  function showRunEnd(type) {
    dom.endTitle.textContent = type === 'win' ? 'RUN CLEAR!' : 'RUN OVER';
    dom.endTitle.className   = `end-title run-${type}`;
    dom.endStats.innerHTML   = `Round <strong>${state.round}</strong> | Wins <strong>${state.wins}</strong> | Losses <strong>${state.losses}</strong>`;
    dom.runEndScreen.classList.add('active');
  }

  function onNewRun() {
    stopTheatreInterval();
    dom.runEndScreen.classList.remove('active');
    state = makeInitialState();
    initCanvasPanel();
    renderAll();
  }

  function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

  // ─── Keyboard ───────────────────────────────────────────────────────────────

  document.addEventListener('keydown', e => {
    if ((e.key === 'r' || e.key === 'R') && !e.ctrlKey && !e.metaKey) {
      if (state.selected) onRotate();
    }
    if (e.key === 'Escape') {
      state.selected     = null;
      state.placementMsg = null;
      state.hoverPreview = null;
      renderAll();
    }
  });

  // ─── Boot ────────────────────────────────────────────────────────────────────

  document.addEventListener('DOMContentLoaded', () => {
    initDOM();
    dom.rotateBtn.addEventListener('click', onRotate);
    dom.rerollBtn.addEventListener('click', onReroll);
    dom.deployBtn.addEventListener('click', onDeploy);
    dom.battleBtn.addEventListener('click', onBattleClick);
    dom.skipBtn.addEventListener('click', onSkipBattle);
    dom.leaveSpectateBtn.addEventListener('click', onLeaveSpectate);
    dom.resultContinueBtn.addEventListener('click', onResultContinue);
    dom.newRunBtn.addEventListener('click', onNewRun);
    dom.spectateBtn.addEventListener('click', () => onSpectate());
    dom.retreatBtn.addEventListener('click', onRetreat);
    dom.retreatContinueBtn.addEventListener('click', onRetreatContinue);
    dom.infoBox.addEventListener('click', e => {
      const btn = e.target.closest('.info-sell-btn');
      if (btn) sellItem(btn.dataset.iid);
    });
    renderAll();
  });

})();
