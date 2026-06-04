// app.js — Mech Bags 0.1 DOM controller
// Depends on game-core.js loaded first (window.MechBags)

(function () {
  'use strict';

  const G = window.MechBags;
  const { ITEMS, ENEMY_POOL, BAG_NAMES, BAG_LABELS, ECONOMY } = G;

  // ─── Run state ─────────────────────────────────────────────────────────────
  let state = makeInitialState();

  function makeInitialState() {
    return {
      round:    1,
      wins:     0,
      losses:   0,
      gold:     ECONOMY.startingGold,
      build:    G.initBuild(),
      hand:     [],           // [{instanceId, itemId}]
      shop:     G.generateShopOffers(1),
      selected: null,         // {instanceId, itemId, rotation, fromHand}
      hoverPreview: null,     // {bagName, cells, valid}
    };
  }

  // ─── DOM refs ───────────────────────────────────────────────────────────────
  const $ = id => document.getElementById(id);
  let dom = {};

  function initDOM() {
    dom = {
      round:             $('stat-round'),
      wins:              $('stat-wins'),
      losses:            $('stat-losses'),
      goldDisplay:       $('gold-display'),
      buildBoard:        $('build-board'),
      handList:          $('hand-list'),
      infoBox:           $('info-box'),
      rotateBtn:         $('rotate-btn'),
      shopOffers:        $('shop-offers'),
      rerollBtn:         $('reroll-btn'),
      battleBtn:         $('battle-btn'),
      battleScreen:      $('battle-screen'),
      skipBtn:           $('skip-btn'),
      bannerMain:        $('banner-main'),
      bannerSub:         $('banner-sub'),
      combatLogWrap:     $('combat-log-wrap'),
      combatLog:         $('combat-log'),
      playerHPFill:      $('player-hp-fill'),
      playerHPText:      $('player-hp-text'),
      enemyHPFill:       $('enemy-hp-fill'),
      enemyHPText:       $('enemy-hp-text'),
      enemyNameLabel:    $('enemy-name-label'),
      playerSprite:      $('player-sprite'),
      enemySprite:       $('enemy-sprite'),
      resultOverlay:     $('result-overlay'),
      resultTitle:       $('result-title'),
      resultSubtitle:    $('result-subtitle'),
      resultHighlights:  $('result-highlights'),
      resultContinueBtn: $('result-continue-btn'),
      runEndScreen:      $('run-end-screen'),
      endTitle:          $('end-title'),
      endStats:          $('end-stats'),
      newRunBtn:         $('new-run-btn'),
    };

    initBagPanels();
  }

  function initBagPanels() {
    dom.buildBoard.innerHTML = '';
    for (const bagName of BAG_NAMES) {
      const panel = document.createElement('div');
      panel.className = 'bag-panel';
      panel.dataset.bag = bagName;
      panel.innerHTML = `<div class="bag-label">${BAG_LABELS[bagName]}</div><div class="bag-grid"></div>`;
      dom.buildBoard.appendChild(panel);
    }
  }

  // ─── Render ─────────────────────────────────────────────────────────────────

  function renderAll() {
    renderHeader();
    renderBuildBoard();
    renderHand();
    renderShop();
    renderInfo();
  }

  function renderHeader() {
    dom.round.textContent  = state.round;
    dom.wins.textContent   = state.wins;
    dom.losses.textContent = state.losses;
    dom.goldDisplay.textContent = state.gold;
  }

  function renderBuildBoard() {
    for (const bagName of BAG_NAMES) renderBag(bagName);
  }

  function buildCellMap(bag) {
    const map = {};
    for (const pi of bag.items) {
      const cells = G.getAbsoluteCells(pi.row, pi.col,
        G.getRotatedCells(ITEMS[pi.itemId].shape, pi.rotation));
      const sorted = cells.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]);
      const first = sorted[0];
      for (const [r, c] of cells) {
        map[`${r},${c}`] = {
          instanceId: pi.instanceId,
          itemId: pi.itemId,
          isFirst: r === first[0] && c === first[1],
          item: ITEMS[pi.itemId],
        };
      }
    }
    return map;
  }

  function renderBag(bagName) {
    const panel = document.querySelector(`.bag-panel[data-bag="${bagName}"]`);
    if (!panel) return;
    const bag = state.build.bags[bagName];
    const cellMap = buildCellMap(bag);

    const bonuses = G.getActiveBonuses(bagName, bag.items);
    const bonusedIds = new Set(bonuses.map(b => b.sourceId));

    const grid = panel.querySelector('.bag-grid');
    grid.style.gridTemplateColumns = `repeat(${bag.cols}, var(--cell-size))`;
    grid.innerHTML = '';

    const preview = state.hoverPreview && state.hoverPreview.bagName === bagName
      ? state.hoverPreview : null;
    const previewKeys = preview
      ? new Set(preview.cells.map(([r, c]) => `${r},${c}`)) : new Set();

    for (let r = 0; r < bag.rows; r++) {
      for (let c = 0; c < bag.cols; c++) {
        const cell = document.createElement('div');
        cell.className = 'bag-cell';
        cell.dataset.bag = bagName;
        cell.dataset.row = r;
        cell.dataset.col = c;

        const info = cellMap[`${r},${c}`];
        if (info) {
          cell.style.background = info.item.color;
          cell.style.border = `1px solid ${lighten(info.item.color)}`;
          if (bonusedIds.has(info.instanceId)) cell.classList.add('has-bonus');
          if (info.isFirst) {
            const tile = document.createElement('div');
            tile.className = 'item-tile';
            tile.style.background = info.item.color;
            tile.title = info.item.name + '\n' + info.item.desc;
            tile.textContent = abbrev(info.item.name);
            tile.dataset.instanceId = info.instanceId;
            cell.appendChild(tile);
          }
          cell.dataset.instanceId = info.instanceId;
        }

        if (previewKeys.has(`${r},${c}`)) {
          cell.classList.add(preview.valid ? 'valid-drop' : 'invalid-drop');
        }

        cell.addEventListener('click', () => onCellClick(bagName, r, c));
        cell.addEventListener('mouseenter', () => onCellHover(bagName, r, c));
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
    // Simple hex lightener for border color
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
      dom.handList.innerHTML = '<div style="color:var(--text-dim);font-size:11px;padding:4px">No items in hand</div>';
      return;
    }
    state.hand.forEach((hi, idx) => {
      const item = ITEMS[hi.itemId];
      const isSelected = state.selected && state.selected.instanceId === hi.instanceId;
      const div = document.createElement('div');
      div.className = 'hand-item' + (isSelected ? ' selected' : '');
      div.innerHTML = `
        <div class="item-dot" style="background:${item.color}"></div>
        <span class="item-label">${item.name}</span>
        <span class="sell-btn" data-iid="${hi.instanceId}" title="Sell for ${Math.floor(item.cost / 2)}g">$${Math.floor(item.cost / 2)}</span>
      `;
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
      card.className = 'shop-card'
        + (cantAfford ? ' cant-afford' : '')
        + (offer.type === 'expansion' ? ' expansion' : '');

      const color = offer.type === 'item' ? ITEMS[offer.itemId].color : '#4da6ff';
      const name  = offer.type === 'item' ? ITEMS[offer.itemId].name  : offer.label;
      const desc  = offer.type === 'item' ? ITEMS[offer.itemId].desc  : offer.desc;

      card.innerHTML = `
        <div class="card-color-bar" style="background:${color}"></div>
        <div class="card-name">${name}</div>
        <div class="card-cost">${offer.cost}g</div>
        <div class="card-desc">${desc}</div>
      `;
      if (!cantAfford) card.addEventListener('click', () => onShopCardClick(offer));
      dom.shopOffers.appendChild(card);
    }
  }

  function renderInfo() {
    if (!state.selected) {
      dom.infoBox.innerHTML = '<span style="color:var(--text-dim)">Select an item from your hand, then click a bag cell to place it.<br>Press <strong>R</strong> to rotate.</span>';
      dom.rotateBtn.disabled = true;
      return;
    }
    dom.rotateBtn.disabled = false;
    const item = ITEMS[state.selected.itemId];
    const rot = state.selected.rotation;
    let html = `<strong>${item.name}</strong><br>${item.desc}<br><br>`;
    if (item.damage > 0) html += `⚔ ${item.damage} dmg | ⏱ ${item.speed} spd | 🎯 ${Math.round(item.accuracy * 100)}% acc<br>`;
    if (item.critChance > 0.05) html += `💥 ${Math.round(item.critChance * 100)}% crit<br>`;
    if (item.hp > 0) html += `❤ +${item.hp} HP<br>`;
    if (item.blockChance) html += `🛡 ${Math.round(item.blockChance * 100)}% block<br>`;
    html += `<br>Tags: ${item.tags.join(', ')}<br>`;
    const allRules = [...item.adjacency];
    if (item.id === 'targeting-chip') allRules.push({ desc: 'Adjacent weapons: +15% crit' });
    if (item.id === 'shield') allRules.push({ desc: 'Armor Plate adj: +20% block' });
    if (allRules.length > 0) {
      html += '<br>';
      for (const rule of allRules) html += `<span class="bonus-tag">${rule.desc}</span> `;
    }
    html += `<br><small style="color:var(--text-dim)">Rotation: ${rot * 90}° &nbsp; Cost: ${item.cost}g &nbsp; Sell: ${Math.floor(item.cost / 2)}g</small>`;
    dom.infoBox.innerHTML = html;
  }

  // ─── Interactions ───────────────────────────────────────────────────────────

  function selectHandItem(idx) {
    const hi = state.hand[idx];
    if (state.selected && state.selected.instanceId === hi.instanceId) {
      state.selected = null;
    } else {
      const prevRot = (state.selected && state.selected.itemId === hi.itemId)
        ? state.selected.rotation : 0;
      state.selected = { instanceId: hi.instanceId, itemId: hi.itemId, rotation: prevRot, fromHand: true };
    }
    clearPreview();
    renderHand();
    renderInfo();
  }

  function onCellClick(bagName, row, col) {
    if (!state.selected) {
      const bag = state.build.bags[bagName];
      const info = buildCellMap(bag)[`${row},${col}`];
      if (info) pickUpItem(info.instanceId, bagName);
      return;
    }
    const { instanceId, itemId, rotation, fromHand } = state.selected;
    const bag = state.build.bags[bagName];
    const cells = G.getRotatedCells(ITEMS[itemId].shape, rotation);
    const occupied = G.buildOccupiedSet(bag.items, fromHand ? null : instanceId);
    if (!G.canPlace(bag.rows, bag.cols, occupied, row, col, cells)) return;

    // If re-placing a board item, remove from current position first
    if (!fromHand) G.removeItem(state.build, instanceId);
    else {
      const idx = state.hand.findIndex(h => h.instanceId === instanceId);
      if (idx !== -1) state.hand.splice(idx, 1);
    }

    G.placeItem(state.build, bagName, instanceId, itemId, row, col, rotation);
    state.selected = null;
    clearPreview();
    renderAll();
  }

  function onCellHover(bagName, row, col) {
    if (!state.selected) { state.hoverPreview = null; return; }
    const { itemId, rotation, instanceId, fromHand } = state.selected;
    const cells = G.getRotatedCells(ITEMS[itemId].shape, rotation);
    const absCells = G.getAbsoluteCells(row, col, cells);
    const bag = state.build.bags[bagName];
    const occupied = G.buildOccupiedSet(bag.items, fromHand ? null : instanceId);
    const valid = G.canPlace(bag.rows, bag.cols, occupied, row, col, cells);
    const prev = state.hoverPreview?.bagName;
    state.hoverPreview = { bagName, cells: absCells, valid };
    if (prev && prev !== bagName) renderBag(prev);
    renderBag(bagName);
  }

  function onCellLeave() {
    const prev = state.hoverPreview?.bagName;
    state.hoverPreview = null;
    if (prev) renderBag(prev);
  }

  function clearPreview() {
    const prev = state.hoverPreview?.bagName;
    state.hoverPreview = null;
    if (prev) renderBag(prev);
  }

  function pickUpItem(instanceId, bagName) {
    const pi = state.build.bags[bagName].items.find(i => i.instanceId === instanceId);
    if (!pi) return;
    G.removeItem(state.build, instanceId);
    state.hand.push({ instanceId, itemId: pi.itemId });
    state.selected = { instanceId, itemId: pi.itemId, rotation: pi.rotation, fromHand: true };
    renderAll();
  }

  function sellItem(instanceId) {
    let itemId = null;
    const hi = state.hand.findIndex(h => h.instanceId === instanceId);
    if (hi !== -1) {
      itemId = state.hand[hi].itemId;
      state.hand.splice(hi, 1);
    } else {
      for (const bag of BAG_NAMES) {
        const pi = state.build.bags[bag].items.find(i => i.instanceId === instanceId);
        if (pi) { itemId = pi.itemId; G.removeItem(state.build, instanceId); break; }
      }
    }
    if (!itemId) return;
    state.gold += Math.floor(ITEMS[itemId].cost / 2);
    if (state.selected?.instanceId === instanceId) state.selected = null;
    renderAll();
  }

  function onShopCardClick(offer) {
    if (state.gold < offer.cost) return;
    state.gold -= offer.cost;
    if (offer.type === 'expansion') {
      G.expandBag(state.build, offer.bag);
    } else {
      const iid = G.nextIid();
      state.hand.push({ instanceId: iid, itemId: offer.itemId });
      state.selected = { instanceId: iid, itemId: offer.itemId, rotation: 0, fromHand: true };
    }
    renderAll();
  }

  function onRotate() {
    if (!state.selected) return;
    state.selected.rotation = (state.selected.rotation + 1) % 4;
    renderInfo();
    if (state.hoverPreview) {
      const bagName = state.hoverPreview.bagName;
      state.hoverPreview = null;
      renderBag(bagName);
    } else {
      renderBuildBoard();
    }
  }

  function onReroll() {
    if (state.gold < ECONOMY.rerollCost) return;
    state.gold -= ECONOMY.rerollCost;
    state.shop = G.generateShopOffers(state.round);
    renderHeader();
    renderShop();
  }

  // ─── Battle ──────────────────────────────────────────────────────────────────

  let battleData  = null;
  let battleAbort = false;

  function onBattleClick() {
    const enemyIdx  = (state.round - 1) % ENEMY_POOL.length;
    const enemyData = ENEMY_POOL[enemyIdx];
    const enemyBuild = G.buildFromEnemyData(enemyData);
    const seed = state.round * 137 + state.wins * 31 + state.losses * 17 + 1;
    const result = G.simulate(state.build, enemyBuild, seed);
    const playerMaxHP = G.computeHP(state.build);
    const enemyMaxHP  = G.computeHP(enemyBuild);

    battleData  = { result, enemyData, enemyBuild, playerMaxHP, enemyMaxHP };
    battleAbort = false;

    dom.enemyNameLabel.textContent = enemyData.name;
    setHPBar(dom.playerHPFill, dom.playerHPText, playerMaxHP, playerMaxHP);
    setHPBar(dom.enemyHPFill,  dom.enemyHPText,  enemyMaxHP,  enemyMaxHP);
    dom.combatLog.innerHTML   = '';
    dom.bannerMain.textContent = 'BATTLE START!';
    dom.bannerSub.textContent  = `Round ${state.round} — vs. ${enemyData.name}`;
    dom.battleScreen.classList.add('active');
    dom.skipBtn.disabled = false;

    playBattle(result.events, playerMaxHP, enemyMaxHP);
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
    const bagLabel = BAG_LABELS[ev.bag];
    dom.bannerMain.textContent = `${bagLabel} ${ev.itemName} fires!`;
    dom.bannerSub.textContent  = '';

    const isPlayer  = ev.attackerSide === 'player';
    const srcSprite  = isPlayer ? dom.playerSprite : dom.enemySprite;
    const destSprite = isPlayer ? dom.enemySprite  : dom.playerSprite;
    const projType   = projTypeFor(ev.itemId);

    await animateProjectile(
      getAnchor(srcSprite, ev.bag),
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
    let logTxt = `[${bagLabel}] ${ev.itemName}`;
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
    if (item.tags.includes('beam'))     return 'beam';
    if (item.tags.includes('explosive')) return 'missile';
    return 'bullet';
  }

  function getAnchor(spriteEl, bag) {
    return spriteEl.querySelector(`[data-anchor="${bag}"]`) || spriteEl;
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
    f.style.cssText = `left:${r.left + r.width/2}px;top:${r.top + r.height/2}px`;
    f.animate(
      [{ opacity: 1, transform: 'translate(-50%,-50%) scale(1)' },
       { opacity: 0, transform: 'translate(-50%,-50%) scale(2.2)' }],
      { duration: 380, fill: 'forwards' }
    ).onfinish = () => f.remove();
  }

  function spawnDmgNum(el, text, cls) {
    const n = document.createElement('div');
    n.className = `damage-number ${cls}`;
    n.textContent = text;
    document.body.appendChild(n);
    const r = el.getBoundingClientRect();
    n.style.cssText = `left:${r.left + r.width/2}px;top:${r.top - 8}px`;
    setTimeout(() => n.remove(), 850);
  }

  function setHPBar(fillEl, textEl, current, max) {
    const pct = max > 0 ? Math.max(0, current / max) : 0;
    fillEl.style.width = (pct * 100) + '%';
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
      const bl = BAG_LABELS[ev.bag];
      let t = `[${bl}] ${ev.itemName}`;
      if (isMiss)       t += ' — missed!';
      else if (isBlock) t += ' — BLOCKED!';
      else if (isCrit)  t += ` — CRIT! ${ev.damage}`;
      else              t += ` dealt ${ev.damage}`;
      const e = document.createElement('div');
      e.className = 'log-entry ' + (isMiss ? 'miss' : isBlock ? 'block' : isCrit ? 'crit' : ev.attackerSide === 'player' ? 'player' : 'enemy');
      e.textContent = t;
      dom.combatLog.appendChild(e);
    }
    dom.combatLogWrap.scrollTop = dom.combatLogWrap.scrollHeight;
    setTimeout(showResult, 600);
  }

  function showResult() {
    const { result, playerMaxHP, enemyMaxHP } = battleData;
    const won = result.winner === 'player';

    // Compute top damage source
    const bagDmg = {};
    for (const ev of result.events) {
      if (ev.attackerSide === 'player' && ev.damage > 0) {
        bagDmg[ev.bag] = (bagDmg[ev.bag] || 0) + ev.damage;
      }
    }
    const topBag = Object.entries(bagDmg).sort((a, b) => b[1] - a[1])[0];

    dom.resultTitle.textContent = won ? 'VICTORY!' : 'DEFEAT!';
    dom.resultTitle.className   = `result-title ${won ? 'win' : 'loss'}`;
    dom.resultSubtitle.textContent = won
      ? `Enemy mech destroyed! (+${ECONOMY.winReward}g next round)`
      : `Your mech was defeated. (+${ECONOMY.lossReward}g next round)`;

    let hi = '';
    if (topBag) hi += `Your <strong>${BAG_LABELS[topBag[0]]}</strong> was your best bag — ${topBag[1]} total damage.<br>`;
    hi += `Final HP: Yours <strong>${Math.max(0, result.finalPlayerHP)}/${playerMaxHP}</strong> — Enemy <strong>${Math.max(0, result.finalEnemyHP)}/${enemyMaxHP}</strong>.<br>`;
    hi += `${result.events.length} attack events.`;
    dom.resultHighlights.innerHTML = hi;
    dom.resultOverlay.classList.add('active');
  }

  function onResultContinue() {
    dom.resultOverlay.classList.remove('active');
    dom.battleScreen.classList.remove('active');

    const won = battleData.result.winner === 'player';
    if (won) { state.wins++;   state.gold += ECONOMY.winReward;  }
    else     { state.losses++; state.gold += ECONOMY.lossReward; }

    if (state.wins   >= ECONOMY.WIN_THRESHOLD)  { showRunEnd('win');  return; }
    if (state.losses >= ECONOMY.LOSS_THRESHOLD) { showRunEnd('loss'); return; }

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
    dom.runEndScreen.classList.remove('active');
    state = makeInitialState();
    initBagPanels();
    renderAll();
  }

  function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

  // ─── Keyboard ───────────────────────────────────────────────────────────────

  document.addEventListener('keydown', e => {
    if ((e.key === 'r' || e.key === 'R') && !e.ctrlKey && !e.metaKey) {
      if (state.selected) onRotate();
    }
    if (e.key === 'Escape') {
      state.selected = null;
      clearPreview();
      renderHand();
      renderInfo();
    }
  });

  // ─── Boot ────────────────────────────────────────────────────────────────────

  document.addEventListener('DOMContentLoaded', () => {
    initDOM();
    dom.rotateBtn.addEventListener('click', onRotate);
    dom.rerollBtn.addEventListener('click', onReroll);
    dom.battleBtn.addEventListener('click', onBattleClick);
    dom.skipBtn.addEventListener('click', onSkipBattle);
    dom.resultContinueBtn.addEventListener('click', onResultContinue);
    dom.newRunBtn.addEventListener('click', onNewRun);
    renderAll();
  });

})();
