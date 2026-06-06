// app.js - Kitbash Mecha v0.3 DOM controller
// Depends on game-core.js loaded first as window.MechBags.

(function () {
  'use strict';

  const G = window.MechBags;
  if (!G) throw new Error('MechBags core was not loaded.');

  const $ = id => document.getElementById(id);

  const dom = {};
  const auto = { timer: null };

  let state = makeInitialState();

  function makeInitialState() {
    const starter = G.createStarterState();
    const enemy = G.buildEnemyTree(0);
    return {
      round: starter.round,
      wins: starter.wins,
      losses: starter.losses,
      gold: starter.gold,
      tree: starter.tree,
      inventory: starter.inventory,
      shop: starter.shop,
      shopSeed: 101,
      enemy,
      selectedOwnedId: null,
      selectedNodeId: 'frame',
      status: 'Ready.',
      salvage: G.collectSalvage(enemy.tree, 'salvage-r1').slice(0, G.ECONOMY.salvageChoices),
      salvageTaken: 0,
      duel: null,
    };
  }

  function initDOM() {
    Object.assign(dom, {
      round: $('stat-round'),
      wins: $('stat-wins'),
      losses: $('stat-losses'),
      gold: $('stat-gold'),
      selectFrameBtn: $('select-frame-btn'),
      detachBtn: $('detach-btn'),
      resetBtn: $('reset-btn'),
      statusLine: $('status-line'),
      frontLabel: $('front-node-label'),
      rearLabel: $('rear-node-label'),
      frontBlueprint: $('front-blueprint'),
      rearBlueprint: $('rear-blueprint'),
      mountedTree: $('mounted-tree'),
      treeCount: $('tree-count'),
      inventoryList: $('inventory-list'),
      inventoryCount: $('inventory-count'),
      eligibleList: $('eligible-list'),
      selectedPartLabel: $('selected-part-label'),
      selectedNodeLabel: $('selected-node-label'),
      nodeInspector: $('node-inspector'),
      resolveHp: $('resolve-hp'),
      synergyList: $('synergy-list'),
      branchList: $('branch-list'),
      attackerList: $('attacker-list'),
      enemyLabel: $('enemy-label'),
      seedInput: $('seed-input'),
      runDuelBtn: $('run-duel-btn'),
      stepEventBtn: $('step-event-btn'),
      autoPlayBtn: $('auto-play-btn'),
      playerHpFill: $('player-hp-fill'),
      enemyHpFill: $('enemy-hp-fill'),
      playerHpText: $('player-hp-text'),
      enemyHpText: $('enemy-hp-text'),
      playerRig: $('player-rig'),
      enemyRig: $('enemy-rig'),
      eventBanner: $('event-banner'),
      eventLog: $('event-log'),
      rerollShopBtn: $('reroll-shop-btn'),
      shopList: $('shop-list'),
      salvageLimit: $('salvage-limit'),
      salvageList: $('salvage-list'),
    });
  }

  function bindEvents() {
    dom.selectFrameBtn.addEventListener('click', () => {
      state.selectedNodeId = 'frame';
      state.status = 'Core frame selected.';
      renderAll();
    });

    dom.detachBtn.addEventListener('click', onDetachSelected);
    dom.resetBtn.addEventListener('click', () => {
      stopAuto();
      state = makeInitialState();
      renderAll();
    });
    dom.rerollShopBtn.addEventListener('click', onRerollShop);
    dom.runDuelBtn.addEventListener('click', () => runDuel(true));
    dom.stepEventBtn.addEventListener('click', stepDuel);
    dom.autoPlayBtn.addEventListener('click', toggleAuto);

    document.addEventListener('keydown', event => {
      if (event.key === 'Escape') {
        state.selectedOwnedId = null;
        state.status = 'Selection cleared.';
        renderAll();
      }
    });
  }

  function renderAll() {
    const resolved = G.resolve(state.tree);
    renderStats();
    renderInventory();
    renderBlueprint('front', resolved);
    renderBlueprint('rear', resolved);
    renderMountedTree();
    renderEligibleSockets();
    renderNodeInspector(resolved);
    renderResolve(resolved);
    renderShop();
    renderSalvage();
    renderCombat();
    dom.statusLine.textContent = state.status;
  }

  function renderStats() {
    dom.round.textContent = state.round;
    dom.wins.textContent = state.wins;
    dom.losses.textContent = state.losses;
    dom.gold.textContent = state.gold;
  }

  function renderInventory() {
    clear(dom.inventoryList);
    dom.inventoryCount.textContent = `${state.inventory.length} owned`;

    if (state.inventory.length === 0) {
      dom.inventoryList.appendChild(emptyMessage('No loose parts.'));
      return;
    }

    state.inventory.forEach(part => {
      const def = G.getDef(part.defId);
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'part-card inventory-card';
      if (part.ownedInstanceId === state.selectedOwnedId) card.classList.add('selected');
      card.style.setProperty('--part-color', def.color || '#94a3b8');
      card.innerHTML = `
        <span class="part-token">${escapeHtml(def.token || def.name.slice(0, 2))}</span>
        <span class="part-copy">
          <strong>${escapeHtml(def.name)}</strong>
          <small>${escapeHtml(def.socketTypeIn || 'root')} in | ${G.countOwnedSubtree(part)} part${G.countOwnedSubtree(part) === 1 ? '' : 's'}</small>
        </span>
      `;
      card.title = `${def.name}\n${formatDefStats(def)}\n${part.ownedInstanceId}`;
      card.addEventListener('click', () => {
        state.selectedOwnedId = part.ownedInstanceId;
        state.status = `${def.name} selected. Choose an eligible socket.`;
        renderAll();
      });
      dom.inventoryList.appendChild(card);
    });
  }

  function renderBlueprint(view) {
    const container = view === 'front' ? dom.frontBlueprint : dom.rearBlueprint;
    const label = view === 'front' ? dom.frontLabel : dom.rearLabel;
    const selectedPart = getSelectedOwnedPart();
    const sockets = G.findEligibleSockets(state.tree, selectedPart)
      .filter(socket => socket.view === view);

    clear(container);

    let openCount = 0;
    let occupiedCount = 0;
    sockets.forEach(socket => {
      if (socket.occupied) occupiedCount += 1;
      else openCount += 1;
    });
    label.textContent = `${occupiedCount} mounted / ${openCount} open`;

    if (sockets.length === 0) {
      container.appendChild(emptyMessage(`No ${view} sockets.`));
      return;
    }

    sockets.forEach(socket => {
      const parent = G.getNode(state.tree, socket.parentNodeId);
      const parentDef = G.getDef(parent.defId);
      const child = G.getNode(state.tree, socket.nodeId);
      const childDef = child ? G.getDef(child.defId) : null;
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'socket-card';
      if (socket.occupied) card.classList.add('occupied');
      else if (socket.ok) card.classList.add('eligible');
      else card.classList.add('blocked');
      if (state.selectedNodeId === socket.nodeId) card.classList.add('selected');
      card.addEventListener('click', () => onSocketClick(socket));

      const action = socket.occupied
        ? 'Select'
        : socket.ok
          ? 'Attach'
          : selectedPart
            ? 'Blocked'
            : 'Open';

      card.innerHTML = `
        <span class="socket-meta">${escapeHtml(parentDef.name)} / ${escapeHtml(socket.hpId)}</span>
        <span class="socket-main">
          <strong>${childDef ? escapeHtml(childDef.name) : escapeHtml(socket.type)}</strong>
          <small>${escapeHtml(socket.nodeId)}</small>
        </span>
        <span class="socket-action">${action}</span>
      `;
      card.title = socket.reason;
      container.appendChild(card);
    });
  }

  function onSocketClick(socket) {
    if (socket.occupied) {
      state.selectedNodeId = socket.nodeId;
      const node = G.getNode(state.tree, socket.nodeId);
      state.status = `${G.getDef(node.defId).name} selected.`;
      renderAll();
      return;
    }

    const selectedPart = getSelectedOwnedPart();
    if (!selectedPart) {
      state.status = 'Select an inventory part before attaching to an open socket.';
      renderAll();
      return;
    }

    if (!socket.ok) {
      state.status = socket.reason;
      renderAll();
      return;
    }

    attachSelectedPart(socket.parentNodeId, socket.hpId);
  }

  function attachSelectedPart(parentNodeId, hpId) {
    const selectedPart = getSelectedOwnedPart();
    if (!selectedPart) {
      state.status = 'Select an inventory part first.';
      renderAll();
      return;
    }

    const result = G.attachOwnedPart(
      state.tree,
      state.inventory,
      parentNodeId,
      hpId,
      selectedPart.ownedInstanceId
    );

    if (!result.ok) {
      state.status = result.reason;
      renderAll();
      return;
    }

    state.tree = result.tree;
    state.inventory = result.inventory;
    state.selectedOwnedId = null;
    state.selectedNodeId = result.nodeId;
    state.duel = null;
    state.status = result.reason;
    renderAll();
  }

  function renderMountedTree() {
    clear(dom.mountedTree);
    const nodes = G.listNodes(state.tree);
    dom.treeCount.textContent = `${nodes.length} nodes`;
    dom.mountedTree.appendChild(renderTreeNode(state.tree, 0));
  }

  function renderTreeNode(node, depth) {
    const def = G.getDef(node.defId);
    const wrap = document.createElement('div');
    wrap.className = 'mounted-node-wrap';
    wrap.style.setProperty('--depth', depth);

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'mounted-node';
    if (node.nodeId === state.selectedNodeId) button.classList.add('selected');
    button.style.setProperty('--part-color', def.color || '#94a3b8');
    button.innerHTML = `
      <span class="part-token">${escapeHtml(def.token || def.name.slice(0, 2))}</span>
      <span>
        <strong>${escapeHtml(def.name)}</strong>
        <small>${escapeHtml(node.nodeId)}</small>
      </span>
    `;
    button.addEventListener('click', () => {
      state.selectedNodeId = node.nodeId;
      state.status = `${def.name} selected.`;
      renderAll();
    });
    wrap.appendChild(button);

    const childIds = sortedChildHpIds(node);
    if (childIds.length > 0) {
      const children = document.createElement('div');
      children.className = 'mounted-children';
      childIds.forEach(hpId => children.appendChild(renderTreeNode(node.children[hpId], depth + 1)));
      wrap.appendChild(children);
    }
    return wrap;
  }

  function renderEligibleSockets() {
    clear(dom.eligibleList);
    const selectedPart = getSelectedOwnedPart();
    if (!selectedPart) {
      dom.selectedPartLabel.textContent = 'None';
      dom.eligibleList.appendChild(emptyMessage('Select an inventory part.'));
      return;
    }

    const def = G.getDef(selectedPart.defId);
    const sockets = G.findEligibleSockets(state.tree, selectedPart);
    const compatible = sockets.filter(socket => socket.ok);
    dom.selectedPartLabel.textContent = `${def.name}: ${compatible.length} eligible`;

    if (compatible.length === 0) {
      dom.eligibleList.appendChild(emptyMessage('No legal socket for this part.'));
    }

    sockets.forEach(socket => {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'eligible-row';
      if (socket.ok) row.classList.add('eligible');
      else row.classList.add('blocked');
      row.disabled = !socket.ok;
      row.innerHTML = `
        <strong>${escapeHtml(socket.nodeId)}</strong>
        <small>${escapeHtml(socket.occupied ? 'occupied' : socket.reason)}</small>
      `;
      row.title = socket.reason;
      row.addEventListener('click', () => attachSelectedPart(socket.parentNodeId, socket.hpId));
      dom.eligibleList.appendChild(row);
    });
  }

  function renderNodeInspector(resolved) {
    const selectedNode = G.getNode(state.tree, state.selectedNodeId) || state.tree;
    state.selectedNodeId = selectedNode.nodeId;
    const def = G.getDef(selectedNode.defId);
    const stats = resolved.nodeStats[selectedNode.nodeId];
    const childIds = sortedChildHpIds(selectedNode);

    dom.selectedNodeLabel.textContent = selectedNode.nodeId;
    dom.detachBtn.disabled = selectedNode.nodeId === 'frame';

    clear(dom.nodeInspector);
    dom.nodeInspector.appendChild(detailBlock(def.name, [
      ['Node', selectedNode.nodeId],
      ['Owned', selectedNode.ownedInstanceId || 'fixed frame'],
      ['Input', def.socketTypeIn || 'root'],
      ['Tags', (def.tags || []).join(', ') || 'none'],
      ['Subtree HP', stats.hp],
      ['Subtree Weight', stats.weight],
      ['Subtree Damage', stats.damage],
      ['Subtree Initiative', stats.initiative],
    ]));

    const sockets = document.createElement('div');
    sockets.className = 'inspector-sockets';
    const heading = document.createElement('h4');
    heading.textContent = 'Hardpoints';
    sockets.appendChild(heading);

    if (!def.hardpoints.length) {
      sockets.appendChild(emptyMessage('No child sockets.'));
    } else {
      def.hardpoints.forEach(hp => {
        const child = selectedNode.children[hp.hpId];
        const row = document.createElement('button');
        row.type = 'button';
        row.className = 'inspector-socket';
        row.disabled = !child;
        row.innerHTML = `
          <strong>${escapeHtml(hp.hpId)}</strong>
          <span>${child ? escapeHtml(G.getDef(child.defId).name) : escapeHtml(hp.type)}</span>
        `;
        if (child) {
          row.addEventListener('click', () => {
            state.selectedNodeId = child.nodeId;
            state.status = `${G.getDef(child.defId).name} selected.`;
            renderAll();
          });
        }
        sockets.appendChild(row);
      });
    }

    if (childIds.length > 0) {
      const childNote = document.createElement('p');
      childNote.className = 'micro-copy';
      childNote.textContent = `${childIds.length} mounted child socket${childIds.length === 1 ? '' : 's'} below this node.`;
      sockets.appendChild(childNote);
    }

    dom.nodeInspector.appendChild(sockets);
  }

  function renderResolve(resolved) {
    dom.resolveHp.textContent =
      `HP ${resolved.totalHP} | Weight ${resolved.totalWeight} | ${resolved.balance.label}`;

    clear(dom.synergyList);
    if (resolved.activeSynergies.length === 0) {
      dom.synergyList.appendChild(emptyMessage('No active synergies.'));
    } else {
      resolved.activeSynergies.forEach(synergy => {
        const card = document.createElement('div');
        card.className = 'data-card synergy-card';
        card.innerHTML = `
          <strong>${escapeHtml(synergy.name)}</strong>
          <span>${escapeHtml(synergy.description)}</span>
          <small>${escapeHtml(synergy.causingNodeIds.join(' + '))}</small>
        `;
        dom.synergyList.appendChild(card);
      });
    }

    clear(dom.branchList);
    Object.entries(resolved.branchWeights).forEach(([hpId, weight]) => {
      const row = document.createElement('div');
      row.className = 'metric-row';
      row.innerHTML = `<span>${escapeHtml(hpId)}</span><strong>${weight}</strong>`;
      dom.branchList.appendChild(row);
    });
    const balance = document.createElement('div');
    balance.className = 'data-card';
    balance.innerHTML = `
      <strong>${escapeHtml(resolved.balance.label)}</strong>
      <span>L ${resolved.balance.leftWeight} / R ${resolved.balance.rightWeight} / Rear ${resolved.balance.rearWeight}</span>
      <small>Delta ${resolved.balance.delta}</small>
    `;
    dom.branchList.appendChild(balance);

    clear(dom.attackerList);
    if (resolved.attackers.length === 0) {
      dom.attackerList.appendChild(emptyMessage('No weapons mounted.'));
    } else {
      resolved.attackers.forEach(attacker => {
        const card = document.createElement('button');
        card.type = 'button';
        card.className = 'attacker-card';
        if (attacker.nodeId === state.selectedNodeId) card.classList.add('selected');
        card.innerHTML = `
          <strong>${escapeHtml(attacker.name)}</strong>
          <span>${attacker.damage} dmg / ${attacker.cooldown} cd / ${Math.round(attacker.accuracy * 100)}% acc</span>
          <small>${escapeHtml(attacker.nodeId)}</small>
        `;
        card.addEventListener('click', () => {
          state.selectedNodeId = attacker.nodeId;
          state.status = `${attacker.name} selected from attackers.`;
          renderAll();
        });
        dom.attackerList.appendChild(card);
      });
    }
  }

  function renderShop() {
    clear(dom.shopList);
    state.shop.forEach(offer => {
      const def = G.getDef(offer.defId);
      const card = document.createElement('div');
      card.className = 'shop-card';
      if (state.gold < offer.cost) card.classList.add('cant-afford');
      card.style.setProperty('--part-color', def.color || '#94a3b8');
      card.innerHTML = `
        <span class="part-token">${escapeHtml(def.token || def.name.slice(0, 2))}</span>
        <span class="shop-copy">
          <strong>${escapeHtml(def.name)}</strong>
          <small>${formatDefStats(def)}</small>
        </span>
        <button type="button" ${state.gold < offer.cost ? 'disabled' : ''}>Buy ${offer.cost}g</button>
      `;
      card.querySelector('button').addEventListener('click', () => buyOffer(offer.offerId));
      dom.shopList.appendChild(card);
    });
  }

  function renderSalvage() {
    clear(dom.salvageList);
    dom.salvageLimit.textContent = `${state.salvageTaken}/${G.ECONOMY.salvageChoices} drafted`;

    if (state.salvage.length === 0) {
      dom.salvageList.appendChild(emptyMessage('No salvage available.'));
      return;
    }

    state.salvage.forEach(part => {
      const def = G.getDef(part.defId);
      const card = document.createElement('div');
      card.className = 'salvage-card';
      card.style.setProperty('--part-color', def.color || '#94a3b8');
      card.innerHTML = `
        <span class="part-token">${escapeHtml(def.token || def.name.slice(0, 2))}</span>
        <span class="shop-copy">
          <strong>${escapeHtml(def.name)}</strong>
          <small>${G.countOwnedSubtree(part)} part${G.countOwnedSubtree(part) === 1 ? '' : 's'} from ${escapeHtml(part.ownedInstanceId)}</small>
        </span>
        <button type="button" ${state.salvageTaken >= G.ECONOMY.salvageChoices ? 'disabled' : ''}>Draft</button>
      `;
      card.querySelector('button').addEventListener('click', () => draftSalvage(part.ownedInstanceId));
      dom.salvageList.appendChild(card);
    });
  }

  function renderCombat() {
    const enemy = state.duel ? state.duel.enemy : state.enemy;
    const playerResolved = state.duel ? state.duel.result.resolved.player : G.resolve(state.tree);
    const enemyResolved = state.duel ? state.duel.result.resolved.enemy : G.resolve(enemy.tree);
    const currentEvent = getCurrentEvent();

    dom.enemyLabel.textContent = enemy.name;
    renderRig(dom.playerRig, state.tree, 'player', currentEvent);
    renderRig(dom.enemyRig, enemy.tree, 'enemy', currentEvent);

    const playerHP = state.duel ? state.duel.playerHP : playerResolved.totalHP;
    const enemyHP = state.duel ? state.duel.enemyHP : enemyResolved.totalHP;
    setHp(dom.playerHpFill, dom.playerHpText, playerHP, playerResolved.totalHP);
    setHp(dom.enemyHpFill, dom.enemyHpText, enemyHP, enemyResolved.totalHP);

    renderEventLog();
    dom.autoPlayBtn.textContent = auto.timer ? 'Stop' : 'Auto';
  }

  function renderRig(container, tree, side, currentEvent) {
    clear(container);
    container.appendChild(renderRigNode(tree, side, currentEvent, 0));
  }

  function renderRigNode(node, side, currentEvent, depth) {
    const def = G.getDef(node.defId);
    const wrap = document.createElement('div');
    wrap.className = 'rig-node-wrap';

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'rig-node';
    button.style.setProperty('--part-color', def.color || '#94a3b8');
    button.style.setProperty('--depth', depth);

    if (currentEvent && currentEvent.source.side === side && currentEvent.source.nodeId === node.nodeId) {
      button.classList.add('source-active');
    }
    if (currentEvent && currentEvent.target.side === side && currentEvent.target.nodeId === node.nodeId) {
      button.classList.add('target-active');
    }
    if (side === 'player' && node.nodeId === state.selectedNodeId) button.classList.add('selected');

    button.innerHTML = `
      <span class="part-token">${escapeHtml(def.token || def.name.slice(0, 2))}</span>
      <span>
        <strong>${escapeHtml(def.name)}</strong>
        <small>${escapeHtml(node.nodeId)}</small>
      </span>
    `;

    if (side === 'player') {
      button.addEventListener('click', () => {
        state.selectedNodeId = node.nodeId;
        state.status = `${def.name} selected from combat rig.`;
        renderAll();
      });
    }

    wrap.appendChild(button);
    const childIds = sortedChildHpIds(node);
    if (childIds.length > 0) {
      const children = document.createElement('div');
      children.className = 'rig-children';
      childIds.forEach(hpId => children.appendChild(renderRigNode(node.children[hpId], side, currentEvent, depth + 1)));
      wrap.appendChild(children);
    }
    return wrap;
  }

  function renderEventLog() {
    clear(dom.eventLog);
    if (!state.duel) {
      dom.eventBanner.textContent = 'No duel loaded.';
      dom.eventLog.appendChild(emptyMessage('Run a duel to load events.'));
      return;
    }

    const events = state.duel.result.events;
    const shown = events.slice(0, state.duel.eventIndex + 1);

    if (state.duel.completed) {
      dom.eventBanner.textContent =
        `${winnerLabel(state.duel.result.winner)} | Final ${state.duel.result.finalPlayerHP}-${state.duel.result.finalEnemyHP}`;
    } else if (state.duel.eventIndex < 0) {
      dom.eventBanner.textContent = `${state.duel.enemy.name} loaded. Step through ${events.length} events.`;
    } else {
      const event = events[state.duel.eventIndex];
      dom.eventBanner.textContent =
        `t${event.t}: ${event.source.side} ${event.sourceName} ${event.hit ? `deals ${event.damage}` : 'misses'}`;
    }

    if (shown.length === 0) {
      dom.eventLog.appendChild(emptyMessage('No events stepped yet.'));
      return;
    }

    shown.forEach((event, index) => {
      const row = document.createElement('div');
      row.className = `event-row ${event.source.side}`;
      if (!event.hit) row.classList.add('miss');
      row.innerHTML = `
        <strong>#${index + 1} t${event.t}</strong>
        <span>${escapeHtml(event.source.side)} ${escapeHtml(event.sourceName)} -> ${escapeHtml(event.target.side)} ${escapeHtml(event.target.nodeId)}</span>
        <small>${event.hit ? `${event.damage} damage; HP ${event.playerHP}/${event.enemyHP}` : 'miss'} ${escapeHtml(event.effects.join(', '))}</small>
      `;
      dom.eventLog.appendChild(row);
    });
    dom.eventLog.scrollTop = dom.eventLog.scrollHeight;
  }

  function onDetachSelected() {
    if (state.selectedNodeId === 'frame') {
      state.status = 'The core frame cannot be detached.';
      renderAll();
      return;
    }

    const result = G.detachNode(state.tree, state.inventory, state.selectedNodeId);
    if (!result.ok) {
      state.status = result.reason;
      renderAll();
      return;
    }

    state.tree = result.tree;
    state.inventory = result.inventory;
    state.selectedNodeId = 'frame';
    state.selectedOwnedId = result.ownedPart.ownedInstanceId;
    state.duel = null;
    state.status = result.reason;
    renderAll();
  }

  function onRerollShop() {
    if (state.gold < G.ECONOMY.rerollCost) {
      state.status = `Need ${G.ECONOMY.rerollCost}g to reroll.`;
      renderAll();
      return;
    }

    state.gold -= G.ECONOMY.rerollCost;
    state.shopSeed += 1;
    state.shop = G.generateShopOffers(state.round, state.shopSeed);
    state.status = 'Shop rerolled.';
    renderAll();
  }

  function buyOffer(offerId) {
    const offer = state.shop.find(item => item.offerId === offerId);
    if (!offer) return;
    if (state.gold < offer.cost) {
      state.status = 'Not enough gold for that part.';
      renderAll();
      return;
    }

    const owned = G.createOwnedPart(offer.defId);
    state.gold -= offer.cost;
    state.inventory = state.inventory.concat([owned]);
    state.shop = state.shop.filter(item => item.offerId !== offerId);
    state.selectedOwnedId = owned.ownedInstanceId;
    state.status = `${G.getDef(offer.defId).name} bought and selected.`;
    renderAll();
  }

  function draftSalvage(ownedInstanceId) {
    if (state.salvageTaken >= G.ECONOMY.salvageChoices) {
      state.status = 'Salvage draft limit reached.';
      renderAll();
      return;
    }

    const idx = state.salvage.findIndex(part => part.ownedInstanceId === ownedInstanceId);
    if (idx === -1) return;
    const part = state.salvage[idx];
    state.inventory = state.inventory.concat([G.clone(part)]);
    state.salvage = state.salvage.slice(0, idx).concat(state.salvage.slice(idx + 1));
    state.salvageTaken += 1;
    state.selectedOwnedId = part.ownedInstanceId;
    state.status = `${G.getDef(part.defId).name} drafted into inventory.`;
    renderAll();
  }

  function runDuel(resetLog) {
    stopAuto();
    const seed = parseInt(dom.seedInput.value, 10) || 1;
    const enemy = state.enemy;
    const result = G.simulate(state.tree, enemy.tree, seed);
    state.duel = {
      enemy,
      seed,
      result,
      eventIndex: -1,
      playerHP: result.resolved.player.totalHP,
      enemyHP: result.resolved.enemy.totalHP,
      completed: false,
    };
    if (resetLog) {
      state.status = `Duel loaded against ${enemy.name} with seed ${seed}.`;
    }
    if (result.events.length === 0) finishDuel();
    renderAll();
  }

  function stepDuel() {
    if (!state.duel || state.duel.completed) {
      runDuel(false);
      return;
    }

    const nextIndex = state.duel.eventIndex + 1;
    if (nextIndex >= state.duel.result.events.length) {
      finishDuel();
      renderAll();
      return;
    }

    const event = state.duel.result.events[nextIndex];
    state.duel.eventIndex = nextIndex;
    state.duel.playerHP = event.playerHP;
    state.duel.enemyHP = event.enemyHP;
    state.status = `${event.source.side} ${event.sourceName}: ${event.hit ? `${event.damage} damage` : 'miss'}.`;
    renderAll();
  }

  function toggleAuto() {
    if (auto.timer) {
      stopAuto();
      renderAll();
      return;
    }

    if (!state.duel || state.duel.completed) runDuel(false);
    auto.timer = setInterval(() => {
      if (!state.duel || state.duel.completed) {
        stopAuto();
        renderAll();
        return;
      }
      stepDuel();
    }, 650);
    stepDuel();
    renderAll();
  }

  function stopAuto() {
    if (auto.timer) {
      clearInterval(auto.timer);
      auto.timer = null;
    }
  }

  function finishDuel() {
    if (!state.duel || state.duel.completed) return;
    state.duel.completed = true;
    state.duel.playerHP = state.duel.result.finalPlayerHP;
    state.duel.enemyHP = state.duel.result.finalEnemyHP;
    stopAuto();

    const won = state.duel.result.winner === 'player';
    if (won) {
      state.wins += 1;
      state.gold += G.ECONOMY.winReward;
    } else {
      state.losses += 1;
      state.gold += G.ECONOMY.lossReward;
    }

    const defeatedEnemy = state.duel.enemy;
    state.salvage = G.collectSalvage(defeatedEnemy.tree, `salvage-r${state.round}`)
      .slice(0, G.ECONOMY.salvageChoices);
    state.salvageTaken = 0;
    state.round += 1;
    state.shopSeed += 17;
    state.shop = G.generateShopOffers(state.round, state.shopSeed);
    state.enemy = G.buildEnemyTree((state.round - 1) % G.ENEMY_POOL.length);
    state.status = won
      ? `Victory. +${G.ECONOMY.winReward}g and salvage available.`
      : `Defeat. +${G.ECONOMY.lossReward}g recovery scrap available.`;
  }

  function getSelectedOwnedPart() {
    return state.inventory.find(part => part.ownedInstanceId === state.selectedOwnedId) || null;
  }

  function getCurrentEvent() {
    if (!state.duel || state.duel.eventIndex < 0) return null;
    return state.duel.result.events[state.duel.eventIndex] || null;
  }

  function setHp(fill, text, current, max) {
    const safeMax = Math.max(1, max);
    const safeCurrent = Math.max(0, current);
    const pct = Math.max(0, Math.min(1, safeCurrent / safeMax));
    fill.style.width = `${Math.round(pct * 100)}%`;
    fill.classList.toggle('low', pct <= 0.5 && pct > 0.25);
    fill.classList.toggle('critical', pct <= 0.25);
    text.textContent = `${safeCurrent} / ${max}`;
  }

  function sortedChildHpIds(node) {
    const def = G.getDef(node.defId);
    const order = new Map((def.hardpoints || []).map((hp, index) => [hp.hpId, index]));
    return Object.keys(node.children || {}).sort((a, b) => {
      const ai = order.has(a) ? order.get(a) : Number.MAX_SAFE_INTEGER;
      const bi = order.has(b) ? order.get(b) : Number.MAX_SAFE_INTEGER;
      if (ai !== bi) return ai - bi;
      return a.localeCompare(b);
    });
  }

  function detailBlock(title, rows) {
    const block = document.createElement('div');
    block.className = 'detail-block';
    const h = document.createElement('h3');
    h.textContent = title;
    block.appendChild(h);
    rows.forEach(([label, value]) => {
      const row = document.createElement('div');
      row.className = 'detail-row';
      const key = document.createElement('span');
      key.textContent = label;
      const val = document.createElement('strong');
      val.textContent = value;
      row.append(key, val);
      block.appendChild(row);
    });
    return block;
  }

  function emptyMessage(text) {
    const el = document.createElement('div');
    el.className = 'empty-message';
    el.textContent = text;
    return el;
  }

  function formatDefStats(def) {
    const parts = [];
    if (def.stats.hp) parts.push(`HP +${def.stats.hp}`);
    if (def.stats.damage) parts.push(`${def.stats.damage} dmg`);
    if (def.stats.weight) parts.push(`${def.stats.weight} wt`);
    if (def.stats.initiative) parts.push(`${def.stats.initiative} init`);
    if (def.stats.cooldown && def.stats.damage) parts.push(`${def.stats.cooldown} cd`);
    return parts.length ? parts.join(' | ') : 'utility';
  }

  function winnerLabel(winner) {
    if (winner === 'player') return 'Player victory';
    if (winner === 'enemy') return 'Enemy victory';
    return 'Draw';
  }

  function clear(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  document.addEventListener('DOMContentLoaded', () => {
    initDOM();
    bindEvents();
    renderAll();
  });
})();
