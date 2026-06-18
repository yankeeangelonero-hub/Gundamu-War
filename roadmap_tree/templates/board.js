// board.js — interactive dependency-tree view, ported from the prototype
// (Roadmap Tree.dc.html). Self-contained vanilla JS: no framework.
//
// Data is injected as JSON in <script id="rt-data">; the prototype's `code`
// field is named `id` in our data — read n.id everywhere the prototype read
// n.code (and the displayed "code" is n.id).
(function () {
  'use strict';

  // ---------------------------------------------------------------------------
  // Injected data + project meta
  // ---------------------------------------------------------------------------
  var DATA = JSON.parse(document.getElementById('rt-data').textContent);
  var PROJECT = DATA.project || {};
  var PROJ_NAME = PROJECT.name || 'project';
  var PROJ_REPO = PROJECT.repo || '';

  // State colours/labels (carried over verbatim).
  var STATES = {
    shipped:       { label: 'SHIPPED',           color: '#6F9DB8' },
    'in-progress': { label: 'IN PROGRESS',       color: '#78BDE8' },
    ready:         { label: 'READY',             color: '#5BD49B' },
    blocked:       { label: 'BLOCKED',           color: '#D07A5E' },
    decision:      { label: 'AWAITING DECISION', color: '#E3AE4A' },
    locked:        { label: 'LOCKED',            color: '#5C5A50' },
    pending:       { label: 'DRAFT',             color: '#B98BE0' }
  };

  // ---------------------------------------------------------------------------
  // Module state (replaces this.state) + render loop (replaces setState)
  // ---------------------------------------------------------------------------
  var state = {
    filter: 'all',
    layoutMode: 'dep',
    compact: false,
    showFuture: true,
    hoverId: null,
    selectedId: null,
    branchDesc: '',
    copied: false,
    ghosts: [],
    ghostSeq: 0,
    zoom: 1
  };

  var scrollEl = null;    // #rt-canvas-scroll (set in render)
  var copiedTimer = null;
  var panState = null;
  var nodeEls = {};   // id -> node box element, for in-place hover dimming (no rebuild)
  var edgeEls = [];   // { el, a, b, op } per edge path, for in-place hover dimming

  function setState(patch, cb) {
    Object.assign(state, patch);
    render();
    if (cb) cb();
  }

  // ---------------------------------------------------------------------------
  // Pure data helpers (carried over verbatim, code -> id rename)
  // ---------------------------------------------------------------------------
  function allNodes() {
    var ns = DATA.nodes.concat(state.ghosts);
    if (!state.showFuture) ns = ns.filter(function (n) { return n.kind !== 'future'; });
    return ns;
  }
  function codeMap() {
    var m = {};
    allNodes().forEach(function (n) { m[n.id] = n; });
    return m;
  }
  function depsOf(n) {
    var m = codeMap();
    return (n.deps || []).map(function (c) { return m[c]; }).filter(Boolean);
  }
  function descendantsOf(n) {
    var all = allNodes(); var out = []; var seen = {};
    var walk = function (code) {
      all.forEach(function (x) {
        if ((x.deps || []).indexOf(code) !== -1 && !seen[x.id]) { seen[x.id] = 1; out.push(x); walk(x.id); }
      });
    };
    walk(n.id); return out;
  }
  function ancestorsOf(n) {
    var m = codeMap(); var out = []; var seen = {};
    var walk = function (node) {
      (node.deps || []).forEach(function (c) {
        var p = m[c]; if (p && !seen[c]) { seen[c] = 1; out.push(p); walk(p); }
      });
    };
    walk(n); return out;
  }
  function chainOf(code) {
    var m = codeMap(); var n = m[code]; if (!n) return {};
    var set = {}; set[code] = 1;
    ancestorsOf(n).forEach(function (x) { set[x.id] = 1; });
    descendantsOf(n).forEach(function (x) { set[x.id] = 1; });
    return set;
  }
  function computeDepths(all) {
    var m = {}; all.forEach(function (n) { m[n.id] = n; });
    var memo = {}, stack = {};
    var dep = function (code) {
      if (memo[code] != null) return memo[code];
      if (stack[code]) return 0;
      stack[code] = 1;
      var n = m[code]; var d = 0;
      ((n && n.deps) || []).forEach(function (c) { if (m[c]) d = Math.max(d, dep(c) + 1); });
      stack[code] = 0; memo[code] = d; return d;
    };
    all.forEach(function (n) { dep(n.id); });
    return memo;
  }
  function rawPos(n, depth, maxd, row, techXVal) {
    var compact = state.compact, draft = n.state === 'pending';
    var gy = row || 0;
    var W = draft ? 230 : (compact ? 104 : 220), H = draft ? 150 : (compact ? 104 : 112);
    if (state.layoutMode === 'tech') {
      var tx = (techXVal != null) ? techXVal : (70 + gy * 280);
      return { x: tx, y: 70 + ((maxd || 7) - depth) * 150, W: W, H: H };
    }
    return { x: 70 + depth * 264, y: 70 + gy * 158, W: W, H: H };
  }
  function matchFilter(n) {
    var f = state.filter; return f === 'all' ? true : n.state === f;
  }
  function draftTitle(desc) {
    var t = (desc || '').trim().split('\n')[0];
    return t ? (t.length > 52 ? t.slice(0, 52) + '…' : t) : 'New branch — describe it';
  }
  function updateGhost(code, val) {
    // Re-render so the draft title, the cleanup brief, and both textareas reflect
    // the edit. render() preserves focus, caret, and scroll, so typing is smooth.
    setState({ ghosts: state.ghosts.map(function (g) {
      return g.id === code ? Object.assign({}, g, { desc: val }) : g;
    }) });
  }

  // ---------------------------------------------------------------------------
  // Clipboard brief generators (carried over verbatim, code -> id, name wired)
  // ---------------------------------------------------------------------------
  function handoff(n) {
    var deps = depsOf(n).map(function (d) {
      return '- ' + d.id + ' — ' + d.title + '  ·  ' + STATES[d.state].label;
    }).join('\n') || '- (none — entry point)';
    return [
      '# Claude Code handoff',
      '## ' + n.id + ' — ' + n.title,
      '',
      'Project: ' + PROJ_NAME + '   ·   repo: ' + PROJ_REPO,
      'Roadmap node: ' + n.id + '   ·   state: ' + STATES[n.state].label + '   ·   target: ' + n.version,
      '',
      '### Goal',
      n.goal,
      '',
      '### Definition of done',
      n.doneWhen,
      '',
      '### Upstream — must be in place first',
      deps,
      '',
      '### Current status / next step',
      n.next,
      '',
      '### Read first',
      '- ' + n.spec,
      '- Version Log.md',
      '',
      '---',
      'When this slice ships: open the roadmap tree, set node ' + n.id + ' to SHIPPED, recompute downstream (flip any now-unblocked node to READY), and note the commit SHA on the node.'
    ].join('\n');
  }
  function branchHandoff(n, desc) {
    var impact = descendantsOf(n).map(function (d) {
      return '- ' + d.id + ' ' + d.title + ' (' + STATES[d.state].label + ')';
    }).join('\n') || '- (no downstream nodes yet)';
    var d = (desc || '').trim() || '(describe the new requirement / client decision / change here)';
    return [
      '# Claude Code — branch proposal review',
      '## Fork off ' + n.id + ' — ' + n.title,
      '',
      'Project: ' + PROJ_NAME + '   ·   repo: ' + PROJ_REPO,
      '',
      '### Proposed change',
      d,
      '',
      '### Branch point',
      n.id + ' — ' + n.title + '  (' + STATES[n.state].label + ', ' + n.version + ')',
      '',
      '### Potentially impacted downstream',
      impact,
      '',
      '### Do this',
      '1. Assess feasibility + impact of the proposed change against the current roadmap.',
      '2. Identify which downstream slices it blocks, changes, or makes obsolete.',
      '3. Propose new / edited tree nodes (id, title, deps, done-when) — do NOT graft them until I approve.',
      '4. Return the proposed tree edits as a diff I can apply to the roadmap.'
    ].join('\n');
  }
  function cleanupHandoff(g) {
    var parent = depsOf(g)[0];
    var impact = parent
      ? (descendantsOf(parent).filter(function (d) { return d.id !== g.id; }).map(function (d) {
          return '- ' + d.id + ' ' + d.title + ' (' + STATES[d.state].label + ')';
        }).join('\n') || '- (none yet)')
      : '- (none)';
    var desc = (g.desc || '').trim() || '(not described yet — fill in the requirement on the node)';
    return [
      '# Claude Code — clean up a drafted branch',
      '## New branch off ' + (parent ? parent.id + ' — ' + parent.title : '(root)'),
      '',
      'Project: ' + PROJ_NAME + '   ·   repo: ' + PROJ_REPO,
      'The PM grafted a rough branch onto the roadmap and described the requirement below.',
      'Turn it into proper roadmap node(s) and wire it into the tree.',
      '',
      '### Forks from',
      parent ? (parent.id + ' — ' + parent.title + '  (' + STATES[parent.state].label + ', ' + parent.version + ')') : '(root)',
      '',
      '### Requirement (as drafted)',
      desc,
      '',
      '### Potentially impacted downstream',
      impact,
      '',
      '### Do this',
      '1. Refine the requirement into one or more concrete slices (title, deps, done-when).',
      '2. Slot them into the tree with correct dependencies; flag what they block, change, or make obsolete.',
      '3. Replace this draft node with the cleaned-up node(s) and report the tree edits.'
    ].join('\n');
  }
  function syncText() {
    return [
      '## Roadmap sync — read on every commit',
      '',
      'The shippable roadmap lives in `roadmap.json` (rendered to `roadmap.html` by `python -m roadmap_tree .`).',
      'Node states: shipped · in-progress · ready · blocked · decision · locked · pending.',
      '',
      '- BEFORE starting work: open the tree, find the READY node, copy its handoff prompt.',
      '- ON a commit that advances a node: edit that node\'s `state` in `roadmap.json` — set `shipped`',
      '  when its done-when is met and tests pass, or `in-progress` while it is still partial. Then',
      '  recompute downstream: flip any node whose deps are now all shipped from `blocked` to `ready`.',
      '  Re-run `python -m roadmap_tree . --sync` to re-stamp canon to HEAD.',
      '- WHEN a new requirement or decision arrives: add a `decision` or `pending` node and do NOT graft',
      '  it until reviewed and approved (use "Branch here" to draft it).',
      '- If commits land without a re-sync, the board shows "OUT OF SYNC — N commits ahead"; click',
      '  "Session Diff" to copy a brief that reconciles the tree from the real git diff.',
      '',
      'States are never derived — the board shows exactly what `roadmap.json` says. Keep it the source of',
      'truth for what is left to ship, not just git history.'
    ].join('\n');
  }
  // NEW: diff-vs-canon brief.
  function diffVsCanonBrief() {
    var sha = (DATA.canon && DATA.canon.sha) ? DATA.canon.sha : '(no canon stamped yet)';
    return [
      '# Reconcile the roadmap tree from the real diff',
      '',
      'Canon (last synced commit): ' + sha,
      '',
      'Do this:',
      '1. Run: git diff ' + sha + '..HEAD   (and check the working tree).',
      '2. For each roadmap node whose work the diff touches, advance its state in roadmap.json:',
      '   mark shipped what is done (done-when met, tests pass); set in-progress what is partial;',
      '   flip any node whose deps are now all shipped from blocked to ready.',
      '3. Re-run the renderer with --sync to re-stamp canon to HEAD.',
      '4. Report the node state changes you made.'
    ].join('\n');
  }

  function copy(text) {
    try { navigator.clipboard.writeText(text); } catch (e) {}
    state.copied = true;
    render();
    clearTimeout(copiedTimer);
    copiedTimer = setTimeout(function () { state.copied = false; render(); }, 1600);
  }

  // ---------------------------------------------------------------------------
  // Zoom + pan (carried over; this._el -> scrollEl)
  // ---------------------------------------------------------------------------
  function applyZoom(z, cx, cy) {
    z = Math.max(0.4, Math.min(2.2, Math.round(z * 100) / 100));
    var el = scrollEl, old = state.zoom;
    if (!el) { setState({ zoom: z }); return; }
    var r = el.getBoundingClientRect();
    var px = cx == null ? r.width / 2 : cx - r.left;
    var py = cy == null ? r.height / 2 : cy - r.top;
    var contentX = (el.scrollLeft + px) / old, contentY = (el.scrollTop + py) / old;
    setState({ zoom: z }, function () {
      var e2 = scrollEl;
      if (e2) { e2.scrollLeft = contentX * z - px; e2.scrollTop = contentY * z - py; }
    });
  }
  function onCanvasDown(e) {
    if (e.button !== 0) return;
    if (e.target && e.target.closest && e.target.closest('[data-node]')) return;
    var sc = e.currentTarget;
    panState = { x: e.clientX, y: e.clientY, sl: sc.scrollLeft, st: sc.scrollTop, el: sc };
    sc.style.cursor = 'grabbing';
    var move = function (ev) {
      if (!panState) return;
      panState.el.scrollLeft = panState.sl - (ev.clientX - panState.x);
      panState.el.scrollTop = panState.st - (ev.clientY - panState.y);
    };
    var up = function () {
      if (panState) panState.el.style.cursor = 'grab';
      panState = null;
      window.removeEventListener('mousemove', move);
      window.removeEventListener('mouseup', up);
    };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
  }

  // ---------------------------------------------------------------------------
  // el() helper: create an element, apply a style object, set props/handlers.
  // styleObj is the camelCased style object the prototype already produces.
  // ---------------------------------------------------------------------------
  function el(tag, styleObj, props) {
    var node = document.createElement(tag);
    if (styleObj) {
      for (var k in styleObj) {
        if (Object.prototype.hasOwnProperty.call(styleObj, k)) node.style[k] = styleObj[k];
      }
    }
    if (props) {
      for (var p in props) {
        if (!Object.prototype.hasOwnProperty.call(props, p)) continue;
        var v = props[p];
        if (p === 'text') node.textContent = v;
        else if (p === 'html') node.innerHTML = v;
        else if (p === 'class') node.className = v;
        else if (p.indexOf('on') === 0 && typeof v === 'function') {
          node.addEventListener(p.slice(2).toLowerCase(), v);
        } else if (v != null) {
          node.setAttribute(p, v);
        }
      }
    }
    return node;
  }
  function svgEl(tag, attrs) {
    var node = document.createElementNS('http://www.w3.org/2000/svg', tag);
    if (attrs) {
      for (var k in attrs) {
        if (Object.prototype.hasOwnProperty.call(attrs, k)) node.setAttribute(k, attrs[k]);
      }
    }
    return node;
  }

  // ---------------------------------------------------------------------------
  // renderVals(): compute every value object the view needs (carried over,
  // code -> id; setState calls become setState(...) helpers).
  // ---------------------------------------------------------------------------
  function renderVals() {
    var S = STATES, st = state;
    var compact = st.compact;
    var all = allNodes();
    var depthMap = computeDepths(all);
    var maxDepth = 0; for (var k in depthMap) if (depthMap[k] > maxDepth) maxDepth = depthMap[k];

    // Row auto-placement: gy is an optional hint (spec §4). Within each depth column,
    // honor any explicit gy, then assign remaining nodes the lowest free rows so
    // same-depth siblings never overlap. Deterministic by node array order.
    var rowMap = {};
    var byDepth = {};
    all.forEach(function (n) { (byDepth[depthMap[n.id]] = byDepth[depthMap[n.id]] || []).push(n); });
    Object.keys(byDepth).forEach(function (d) {
      var group = byDepth[d], used = {};
      group.forEach(function (n) { if (typeof n.gy === 'number' && isFinite(n.gy)) { rowMap[n.id] = n.gy; used[n.gy] = 1; } });
      var next = 0;
      group.forEach(function (n) { if (rowMap[n.id] == null) { while (used[next]) next++; rowMap[n.id] = next; used[next] = 1; next++; } });
    });

    // Tech-tree: center each depth tier horizontally around a common axis (so a single
    // node sits centered, not hugged to the left corner) with generous spacing.
    var techX = null;
    if (st.layoutMode === 'tech') {
      techX = {};
      var techGap = 280, widest = 0;
      Object.keys(byDepth).forEach(function (d) { if (byDepth[d].length > widest) widest = byDepth[d].length; });
      var axis = 70 + (widest - 1) / 2 * techGap;
      Object.keys(byDepth).forEach(function (d) {
        var grp = byDepth[d].slice().sort(function (a, b) { return rowMap[a.id] - rowMap[b.id]; });
        var count = grp.length;
        grp.forEach(function (n, i) { techX[n.id] = axis + (i - (count - 1) / 2) * techGap; });
      });
    }

    // positions + normalize bounds
    var pos = {}; var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
    all.forEach(function (n) {
      var p = rawPos(n, depthMap[n.id], maxDepth, rowMap[n.id], techX ? techX[n.id] : null);
      pos[n.id] = p;
      minX = Math.min(minX, p.x); minY = Math.min(minY, p.y);
      maxX = Math.max(maxX, p.x + p.W); maxY = Math.max(maxY, p.y + p.H);
    });
    var offX = 60 - minX, offY = 60 - minY;
    all.forEach(function (n) { pos[n.id].x += offX; pos[n.id].y += offY; });
    var canvasW = (maxX + offX) + 120, canvasH = (maxY + offY) + 120;

    // version bands (x-axis) + separators, dep layout only
    var gridChrome = [];
    if (st.layoutMode === 'dep') {
      var colX = function (c) { return 70 + c * 264 + offX; };
      var mains = all.filter(function (n) { return n.state !== 'pending' && n.kind !== 'future'; });
      var verByDepth = {};
      mains.forEach(function (n) { var d = depthMap[n.id]; if (verByDepth[d] == null) verByDepth[d] = n.version; });
      var ds = Object.keys(verByDepth).map(Number).sort(function (a, b) { return a - b; });
      var bands = [];
      ds.forEach(function (d) {
        var v = verByDepth[d]; var last = bands[bands.length - 1];
        if (last && last.ver === v && d === last.b + 1) last.b = d; else bands.push({ ver: v, a: d, b: d });
      });
      bands.forEach(function (bnd, i) {
        if (i > 0) gridChrome.push({ style: { position: 'absolute', left: (colX(bnd.a) - 22) + 'px', top: '0px', width: '1px', height: canvasH + 'px', background: 'rgba(255,255,255,.06)', pointerEvents: 'none' }, text: '' });
        gridChrome.push({ style: { position: 'absolute', left: colX(bnd.a) + 'px', top: '8px', fontFamily: 'var(--font-mono)', fontSize: '11px', letterSpacing: '.12em', textTransform: 'uppercase', color: '#807c6c', whiteSpace: 'nowrap', pointerEvents: 'none' }, text: bnd.ver });
      });
      var futs = all.filter(function (n) { return n.kind === 'future'; });
      if (futs.length) {
        var fa = Math.min.apply(null, futs.map(function (n) { return depthMap[n.id]; }));
        var fy = 70 + Math.min.apply(null, futs.map(function (n) { return rowMap[n.id]; })) * 158 + offY - 26;
        gridChrome.push({ style: { position: 'absolute', left: colX(fa) + 'px', top: fy + 'px', fontFamily: 'var(--font-mono)', fontSize: '10px', letterSpacing: '.12em', textTransform: 'uppercase', color: '#6a6757', whiteSpace: 'nowrap', pointerEvents: 'none' }, text: 'v0.2+ · future (deferred)' });
      }
    }

    var hover = st.hoverId, hoverChain = hover ? chainOf(hover) : null;
    var filterOn = st.filter !== 'all';
    var nodeDim = function (n) { return (hoverChain && !hoverChain[n.id]) || (filterOn && !matchFilter(n)); };

    var nodes = all.map(function (n) {
      var p = pos[n.id], meta = S[n.state], dim = nodeDim(n), sel = st.selectedId === n.id;
      var c = meta.color;
      var isDraft = n.state === 'pending';
      var isOrb = compact && !isDraft;
      var isCard = !compact && !isDraft;
      var cardLike = !isOrb;
      var box = {
        position: 'absolute', left: p.x + 'px', top: p.y + 'px', width: p.W + 'px',
        boxSizing: 'border-box', cursor: 'pointer', zIndex: sel ? 6 : (dim ? 1 : 3),
        opacity: dim ? 0.16 : 1, transition: 'opacity .22s var(--ease), box-shadow .2s, border-color .2s',
        fontFamily: 'var(--font-body)'
      };
      if (cardLike) {
        box.minHeight = p.H + 'px'; box.padding = '11px 13px'; box.borderRadius = '5px';
        box.background = isDraft ? 'rgba(24,20,33,.96)' : (n.state === 'shipped' ? 'rgba(111,157,184,.08)' : (n.state === 'locked' ? 'rgba(255,255,255,.015)' : '#16150F'));
        box.border = isDraft ? '1.5px dashed #8a6bb0' : ('1.5px solid ' + (n.state === 'locked' ? '#34332a' : c));
        if (n.state === 'locked') box.borderStyle = 'dashed';
      } else {
        box.height = p.H + 'px'; box.display = 'flex'; box.alignItems = 'center'; box.justifyContent = 'center'; box.background = 'transparent';
      }
      if (sel) { box.border = '2px solid var(--accent)'; box.boxShadow = '0 0 0 3px rgba(120,189,232,.25)'; box.animation = 'none'; }
      else if (!dim && n.state === 'ready' && cardLike) box.animation = 'rtReadyGlow 1.9s ease-in-out infinite';
      else if (!dim && n.state === 'in-progress' && cardLike) box.animation = 'rtProgGlow 2.3s ease-in-out infinite';
      else if (n.state === 'pending') box.animation = 'rtGhost 1.6s ease-in-out infinite';

      var pill = {
        display: 'inline-flex', alignItems: 'center', gap: '5px', flex: 'none',
        fontFamily: 'var(--font-mono)', fontSize: '8.5px', letterSpacing: '.06em', textTransform: 'uppercase',
        color: c, background: 'color-mix(in srgb,' + c + ' 16%, transparent)', borderRadius: '3px', padding: '3px 6px', whiteSpace: 'nowrap'
      };
      var pillDot = { width: '6px', height: '6px', borderRadius: '50%', background: c, flex: 'none', boxShadow: (n.state === 'ready' || n.state === 'in-progress') ? '0 0 6px ' + c : 'none' };

      var orbCircle = {
        width: '88px', height: '88px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: '6px', textAlign: 'center',
        border: '2px solid ' + (n.state === 'locked' ? '#3a382e' : c),
        borderStyle: n.state === 'locked' ? 'dashed' : 'solid',
        background: n.state === 'shipped' ? 'rgba(111,157,184,.12)' : '#131209',
        boxShadow: sel ? '0 0 0 3px rgba(120,189,232,.3)' : (n.state === 'ready' ? '0 0 20px -2px rgba(91,212,155,.7)' : (n.state === 'in-progress' ? '0 0 18px -3px rgba(120,189,232,.6)' : 'none')),
        animation: (!dim && n.state === 'ready') ? 'rtReadyGlow 1.9s ease-in-out infinite' : ((!dim && n.state === 'in-progress') ? 'rtProgGlow 2.3s ease-in-out infinite' : (n.state === 'pending' ? 'rtGhost 1.6s ease-in-out infinite' : 'none'))
      };

      var dcount = (n.deps || []).length;
      return {
        id: n.id, title: isDraft ? draftTitle(n.desc) : n.title, version: n.version, stateLabel: meta.label,
        icon: n.kind === 'decision' ? '◆ ' : (n.kind === 'future' ? '○ ' : ''),
        depLabel: dcount ? ('needs ' + dcount) : 'entry',
        isCard: isCard, isOrb: isOrb, isDraft: isDraft, desc: n.desc || '',
        box: box, pill: pill, pillDot: pillDot, orbCircle: orbCircle,
        onDescInput: function (e) { updateGhost(n.id, e.target.value); },
        onClick: function () { setState({ selectedId: n.id }); },
        onEnter: function () { state.hoverId = n.id; applyDim(); },
        onLeave: function () { state.hoverId = null; applyDim(); }
      };
    });

    // edges
    var edges = [];
    all.forEach(function (tgt) {
      (tgt.deps || []).forEach(function (sc) {
        var src = pos[sc]; if (!src) return;
        var sp = pos[sc], tp = pos[tgt.id];
        var d;
        if (st.layoutMode === 'tech') {
          var sx = sp.x + sp.W / 2, sy = sp.y, tx = tp.x + tp.W / 2, ty = tp.y + tp.H, my = (sy + ty) / 2;
          d = 'M ' + sx + ' ' + sy + ' C ' + sx + ' ' + my + ', ' + tx + ' ' + my + ', ' + tx + ' ' + ty;
        } else {
          var sx2 = sp.x + sp.W, sy2 = sp.y + sp.H / 2, tx2 = tp.x, ty2 = tp.y + tp.H / 2, mx = (sx2 + tx2) / 2;
          d = 'M ' + sx2 + ' ' + sy2 + ' C ' + mx + ' ' + sy2 + ', ' + mx + ' ' + ty2 + ', ' + tx2 + ' ' + ty2;
        }
        var srcN = codeMap()[sc];
        var dim = (hoverChain && !(hoverChain[sc] && hoverChain[tgt.id])) || (filterOn && !(matchFilter(srcN) && matchFilter(tgt)));
        var ts = tgt.state;
        var style = { fill: 'none', strokeLinecap: 'round' };
        var animated = false, dashed = false, col = '#3a3930', w = 1.6, op = 0.9;
        if (ts === 'ready') { col = '#5BD49B'; animated = true; w = 2; }
        else if (ts === 'in-progress') { col = '#78BDE8'; animated = true; w = 2; }
        else if (ts === 'shipped') { col = '#5b7a8e'; op = 0.55; }
        else if (ts === 'pending') { col = '#b98be0'; animated = true; dashed = true; w = 1.8; }
        else if (ts === 'blocked') { col = '#7a5a4e'; dashed = true; op = 0.5; }
        else if (ts === 'decision') { col = '#8a7440'; dashed = true; op = 0.6; }
        else { col = '#3a3930'; dashed = true; op = 0.4; } // locked / future
        style.stroke = col; style.strokeWidth = w; style.opacity = dim ? 0.07 : op;
        if (animated && !dim) { style.strokeDasharray = '2 8'; style.animation = 'rtFlow .9s linear infinite'; }
        else if (dashed) style.strokeDasharray = '5 7';
        edges.push({ d: d, style: style, a: sc, b: tgt.id, op: op });
      });
    });

    // selected / drawer
    var sel = st.selectedId ? codeMap()[st.selectedId] : null;
    var selParent = sel ? depsOf(sel)[0] : null;
    var selView = sel ? (function () {
      var meta = S[sel.state], c = meta.color, draft = sel.state === 'pending';
      return {
        id: sel.id, title: draft ? draftTitle(sel.desc) : sel.title, version: sel.version, goal: sel.goal, doneWhen: sel.doneWhen,
        next: sel.next, spec: sel.spec, stateLabel: meta.label,
        parentLabel: selParent ? (selParent.id + ' — ' + selParent.title) : '(root)',
        icon: sel.kind === 'decision' ? '◆ ' : (sel.kind === 'future' ? '○ ' : (draft ? '⏎ ' : '')),
        pill: { display: 'inline-flex', alignItems: 'center', gap: '6px', fontFamily: 'var(--font-mono)', fontSize: '10px', letterSpacing: '.08em', textTransform: 'uppercase', color: c, background: 'color-mix(in srgb,' + c + ' 18%, transparent)', borderRadius: '4px', padding: '5px 9px' },
        pillDot: { width: '7px', height: '7px', borderRadius: '50%', background: c }
      };
    })() : null;
    var selDeps = sel ? depsOf(sel).map(function (d) {
      var c = S[d.state].color;
      return { id: d.id, title: d.title, label: S[d.state].label, color: c, dot: { width: '8px', height: '8px', borderRadius: '50%', background: c, flex: 'none' } };
    }) : [];

    var chips = [
      { key: 'all', label: 'All' }, { key: 'ready', label: 'Ready' }, { key: 'in-progress', label: 'In progress' },
      { key: 'blocked', label: 'Blocked' }, { key: 'decision', label: 'Decision' }, { key: 'shipped', label: 'Shipped' }
    ].map(function (c) {
      var active = st.filter === c.key;
      var count = c.key === 'all' ? all.length : all.filter(function (n) { return n.state === c.key; }).length;
      return {
        label: c.label, count: count,
        onClick: function () { setState({ filter: c.key }); },
        style: { display: 'inline-flex', alignItems: 'center', gap: '7px', height: '30px', padding: '0 12px', borderRadius: '6px', cursor: 'pointer', fontSize: '12.5px', fontWeight: active ? 700 : 500, fontFamily: 'var(--font-body)', border: '1px solid ' + (active ? 'var(--accent)' : '#34332a'), background: active ? 'rgba(120,189,232,.12)' : 'transparent', color: active ? 'var(--accent)' : '#b7b3a3' },
        countStyle: { fontFamily: 'var(--font-mono)', fontSize: '10px', color: active ? 'var(--accent)' : '#7c7868' }
      };
    });

    var legendKeys = ['ready', 'in-progress', 'blocked', 'decision', 'shipped', 'locked'];
    var legend = legendKeys.map(function (k) {
      return { label: S[k].label, dot: { width: '9px', height: '9px', borderRadius: k === 'decision' ? '1px' : '50%', transform: k === 'decision' ? 'rotate(45deg)' : 'none', background: S[k].color, flex: 'none', boxShadow: (k === 'ready' || k === 'in-progress') ? '0 0 7px ' + S[k].color : 'none', border: k === 'locked' ? '1px dashed ' + S[k].color : 'none', backgroundColor: k === 'locked' ? 'transparent' : S[k].color } };
    });

    var toggleBtn = function (on) { return { height: '34px', padding: '0 14px', border: '0', cursor: 'pointer', fontSize: '12.5px', fontWeight: on ? 700 : 500, fontFamily: 'var(--font-body)', background: on ? 'rgba(120,189,232,.14)' : 'transparent', color: on ? 'var(--accent)' : '#9b9787' }; };
    var secLabel = { fontFamily: 'var(--font-mono)', fontSize: '10px', letterSpacing: '.14em', textTransform: 'uppercase', color: '#7c7868', marginBottom: '7px' };
    var copyBtn = { height: '26px', padding: '0 12px', borderRadius: '4px', border: '1px solid #34332a', background: 'transparent', color: '#b7b3a3', fontSize: '11px', fontWeight: 600, cursor: 'pointer' };

    var disc = DATA.discrepancy || {};
    var canonSha = (DATA.canon && DATA.canon.sha) || disc.canon || null;
    var headSha = disc.head || null;
    var syncChip;
    if (!headSha) syncChip = { text: '○ version check off — not a git repo', color: '#7c7868' };
    else if (!canonSha) syncChip = { text: '⚠ never synced — run: python -m roadmap_tree . --sync', color: '#E3AE4A' };
    else if (disc.out_of_sync) syncChip = { text: '⚠ version mismatch · roadmap canon ' + canonSha.slice(0, 7) + ' vs git HEAD ' + headSha.slice(0, 7) + ' · ' + disc.count + ' ahead', color: '#D07A5E' };
    else syncChip = { text: '✓ in sync · canon ' + canonSha.slice(0, 7), color: '#5BD49B' };

    return {
      canvasW: canvasW, canvasH: canvasH, syncChip: syncChip,
      // Extra right-hand scroll room while the drawer is open so the rightmost
      // column can be scrolled out from under the 418px detail panel.
      sizerStyle: { position: 'relative', width: (canvasW * st.zoom + (st.selectedId ? 460 : 0)) + 'px', height: (canvasH * st.zoom) + 'px', minWidth: '100%', minHeight: '100%' },
      canvasStyle: { position: 'relative', width: canvasW + 'px', height: canvasH + 'px', transform: 'scale(' + st.zoom + ')', transformOrigin: '0 0' },
      zoomPct: Math.round(st.zoom * 100),
      zoomIn: function () { applyZoom(state.zoom * 1.2); },
      zoomOut: function () { applyZoom(state.zoom / 1.2); },
      zoomReset: function () { applyZoom(1); },
      nodes: nodes, edges: edges, gridChrome: gridChrome,
      selected: selView, selDeps: selDeps, noDeps: sel ? depsOf(sel).length === 0 : false,
      isNode: !!sel && sel.state !== 'pending',
      isDraft: !!sel && sel.state === 'pending',
      handoffText: sel ? handoff(sel) : '',
      cleanupText: sel && sel.state === 'pending' ? cleanupHandoff(sel) : '',
      branchDesc: sel && sel.state === 'pending' ? sel.desc : '',
      copied: st.copied,
      chips: chips, legend: legend, secLabel: secLabel, copyBtn: copyBtn,
      depBtnStyle: toggleBtn(st.layoutMode === 'dep'), techBtnStyle: toggleBtn(st.layoutMode === 'tech'),
      cardsBtnStyle: toggleBtn(!st.compact), orbsBtnStyle: toggleBtn(st.compact),
      // handlers
      setDep: function () { setState({ layoutMode: 'dep' }); }, setTech: function () { setState({ layoutMode: 'tech' }); },
      setCards: function () { setState({ compact: false }); }, setOrbs: function () { setState({ compact: true }); },
      onCanvasDown: onCanvasDown,
      stop: function (e) { e.stopPropagation(); },
      closeDrawer: function () { setState({ selectedId: null }); },
      copyHandoff: function () { copy(handoff(sel)); },
      copyCleanup: function () { var g = codeMap()[state.selectedId]; if (g) copy(cleanupHandoff(g)); },
      copySync: function () { copy(syncText()); },
      copyInstall: function () { copy(installText()); },
      copyDiff: function () { copy(diffVsCanonBrief()); },
      copyArchitecture: function () { copy(architectureBrief()); },
      editDesc: function (e) { if (sel) updateGhost(sel.id, e.target.value); },
      branchHere: function () {
        if (!sel) return;
        var seq = state.ghostSeq + 1;
        // No explicit gy: row auto-placement (see rowMap in renderVals) appends the
        // ghost to the next free row at its depth, so it never displaces an existing card.
        var ghost = {
          id: 'B' + seq + '·' + sel.id.replace(/[^A-Za-z0-9]/g, '').slice(0, 4),
          state: 'pending', kind: 'pending', version: 'branch · draft',
          deps: [sel.id], desc: '',
          goal: 'A drafted fork awaiting refinement.', doneWhen: 'Pending — Claude refines it into the tree.',
          next: 'Describe the requirement, then copy the cleanup brief to Claude.', spec: 'branch draft'
        };
        setState({ ghosts: state.ghosts.concat([ghost]), ghostSeq: seq, selectedId: ghost.id });
      },
      discardGhost: function () {
        if (!sel) return;
        setState({ ghosts: state.ghosts.filter(function (g) { return g.id !== sel.id; }), selectedId: null });
      }
    };
  }

  // ---------------------------------------------------------------------------
  // render(): rebuild #rt-root from renderVals(). Replaces the <x-dc> markup.
  // ---------------------------------------------------------------------------
  function architectureBrief() {
    return [
      '# Architecture design / review — plan the road to a shippable product',
      '',
      'Project: ' + PROJ_NAME,
      '',
      'Build roadmap.json as the FULL road from where this project is now to the intended',
      'shippable product — including the steps that do NOT exist yet. Do not just map the',
      'current repo. Use this to plan a new project and whenever the direction changes.',
      '',
      'Do this, in order:',
      '1. Grill me on the destination. Ask ONE question at a time, in plain language, until the',
      '   intended product is concrete and unambiguous. Cover at least:',
      '   - What is the shippable product — what can a user actually do in v1, and how do we know',
      '     it has shipped (the concrete proof)?',
      '   - Who is the user and what is the core value? What is explicitly OUT of scope for v1?',
      '   - What order do I want to ship in, and what are the hard constraints (dates, tech, deps)?',
      '   Keep asking until there are no fuzzy answers, then restate the destination back to me.',
      '2. Establish current reality: explore the codebase and its documentation (README, docs/,',
      '   specs, ADRs, CHANGELOG, TODOs, module layout) and git history — what already exists,',
      '   what is shipped, what is in flight.',
      '3. Find the gap and fill it. Compare the destination against current reality and enumerate',
      '   the MISSING work between them — the milestones, slices, decisions, and enabling steps',
      '   that are not started or documented yet. This in-between work is usually most of the tree.',
      '4. (Re)design roadmap.json: one node per meaningful unit of work (milestone / slice /',
      '   decision / future). Set state from reality — shipped/in-progress for what exists,',
      '   ready/blocked/locked for what is ahead, decision for open choices. deps = the shipping',
      '   order. Preserve shipped history; on a re-architecture, name what the new direction',
      '   re-sequences or makes obsolete.',
      '5. Follow roadmap_tree/roadmap.schema.json. Show me the proposed tree — the destination,',
      '   what already exists, and the in-between steps you added — and let me approve before you',
      '   write roadmap.json.'
    ].join('\n');
  }

  function installText() {
    return [
      '## Install roadmap auto-sync (one-time setup)',
      '',
      'Set this project up so the roadmap board stays current automatically.',
      '',
      '1. Build the initial tree as the road to the shippable product — not just a map of the repo.',
      '   First grill me, ONE question at a time, on the intended product: what shipping v1 looks',
      '   like and how we know it shipped, the core user and value, and what is out of scope. Then',
      '   explore the codebase and its documentation (README, docs/, specs, ADRs, CHANGELOG, TODOs,',
      '   layout) and git history for what already exists. Then fill the GAP between destination and',
      '   reality: enumerate the missing milestones / slices / decisions / enabling steps, set each',
      '   node\'s state from reality (shipped / in-progress for what exists; ready / blocked / locked /',
      '   decision for what is ahead), deps = shipping order. Follow roadmap_tree/roadmap.schema.json.',
      '   Show me the draft and let me correct it before continuing.',
      '2. Add a Claude Code PostToolUse hook (in .claude/settings.json) on the Bash tool,',
      '   gated to `git commit`: it runs `python -m roadmap_tree .` to re-render the board',
      '   and reminds Claude to reconcile node states in roadmap.json from the commit diff.',
      '3. Append the "Roadmap sync — read on every commit" block (the Sync instructions in',
      '   this dialog) to the project\'s CLAUDE.md, so every session treats roadmap.json as',
      '   the source of truth.',
      '4. Run `python -m roadmap_tree . --sync` once to stamp the current commit as canon.',
      '',
      'After this: commits made through Claude keep the tree in sync; commits made outside',
      'Claude surface the "OUT OF SYNC" banner until the next sync.'
    ].join('\n');
  }

  // In-place hover dimming: adjust node/edge opacity without rebuilding the DOM,
  // so a hover never replaces the element you're about to click (and never resets scroll).
  function applyDim() {
    var hoverChain = state.hoverId ? chainOf(state.hoverId) : null;
    var filterOn = state.filter !== 'all';
    var cm = codeMap();
    for (var id in nodeEls) {
      if (!Object.prototype.hasOwnProperty.call(nodeEls, id)) continue;
      var ndim = (hoverChain && !hoverChain[id]) || (filterOn && cm[id] && !matchFilter(cm[id]));
      nodeEls[id].style.opacity = ndim ? '0.16' : '1';
    }
    edgeEls.forEach(function (e) {
      var edim = (hoverChain && !(hoverChain[e.a] && hoverChain[e.b])) ||
        (filterOn && cm[e.a] && cm[e.b] && !(matchFilter(cm[e.a]) && matchFilter(cm[e.b])));
      e.el.style.opacity = edim ? '0.07' : String(e.op);
    });
  }

  function render() {
    var v = renderVals();
    nodeEls = {}; edgeEls = [];
    var root = document.getElementById('rt-root');
    // Preserve focus, caret, and scroll across the rebuild (e.g. while typing a draft).
    var _active = document.activeElement;
    var _focusKey = (_active && _active.getAttribute) ? _active.getAttribute('data-rt-focus') : null;
    var _caretS = null, _caretE = null;
    if (_focusKey) { try { _caretS = _active.selectionStart; _caretE = _active.selectionEnd; } catch (e) {} }
    var _scroll = scrollEl ? { l: scrollEl.scrollLeft, t: scrollEl.scrollTop } : null;
    root.textContent = '';

    // NEW: discrepancy banner. Remove any prior one so re-renders don't stack.
    var priorBar = document.querySelector('.rt-stale');
    if (priorBar) priorBar.parentNode.removeChild(priorBar);
    if (DATA.discrepancy && DATA.discrepancy.out_of_sync) {
      var bar = el('div', null, { class: 'rt-stale' });
      var dd = DATA.discrepancy;
      var cc = dd.canon ? dd.canon.slice(0, 7) : '—', hh = dd.head ? dd.head.slice(0, 7) : '—';
      bar.textContent = '⚠ VERSION MISMATCH — roadmap canon ' + cc + ' vs git HEAD ' + hh +
        ' · ' + dd.count + ' commit(s) ahead · click “Session Diff” to reconcile';
      document.body.appendChild(bar);
    }

    var shell = el('div', { height: '100vh', display: 'flex', flexDirection: 'column', overflow: 'hidden', background: 'var(--surface-dark)', color: 'var(--on-dark)', fontFamily: 'var(--font-body)', position: 'relative' });

    // ---- Header ----
    var header = el('header', { flex: 'none', borderBottom: '1px solid #26251d', background: 'linear-gradient(180deg,#121109,#0E0E0C)' });
    var topRow = el('div', { display: 'flex', alignItems: 'center', gap: '18px', padding: '16px 24px 12px' });
    var titleCol = el('div', { display: 'flex', flexDirection: 'column', gap: '3px', minWidth: '0' });
    var titleLine = el('div', { display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' });
    titleLine.appendChild(el('span', { fontFamily: 'var(--font-display)', fontWeight: '600', fontSize: '20px', letterSpacing: '-.01em', color: 'var(--on-dark)' }, { text: PROJ_NAME }));
    if (PROJ_REPO) titleLine.appendChild(el('span', { fontFamily: 'var(--font-mono)', fontSize: '11px', letterSpacing: '.08em', color: '#8e8a78', border: '1px solid #34332a', borderRadius: '4px', padding: '3px 7px' }, { text: 'repo · ' + PROJ_REPO }));
    var verText = [PROJECT.version, PROJECT.subtitle].filter(Boolean).join(' — ');
    if (verText) titleLine.appendChild(el('span', { fontFamily: 'var(--font-mono)', fontSize: '11px', letterSpacing: '.1em', textTransform: 'uppercase', color: 'var(--accent)' }, { text: verText }));
    titleCol.appendChild(titleLine);
    var subtitle = 'Shippable roadmap tree · what’s done in git, what’s still ahead' + (PROJECT.updated ? ' · updated ' + PROJECT.updated : '');
    titleCol.appendChild(el('span', { fontSize: '12.5px', color: '#7c7868' }, { text: subtitle }));
    titleCol.appendChild(el('span', { fontFamily: 'var(--font-mono)', fontSize: '11px', fontWeight: '600', letterSpacing: '.02em', color: v.syncChip.color, marginTop: '3px' }, { text: v.syncChip.text }));
    topRow.appendChild(titleCol);

    var actions = el('div', { marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: '8px', flex: 'none' });
    var layoutGroup = el('div', { display: 'flex', border: '1px solid #34332a', borderRadius: '6px', overflow: 'hidden' });
    layoutGroup.appendChild(el('button', v.depBtnStyle, { text: 'Dependency', onClick: v.setDep }));
    layoutGroup.appendChild(el('button', v.techBtnStyle, { text: 'Tech-tree', onClick: v.setTech }));
    actions.appendChild(layoutGroup);
    var styleGroup = el('div', { display: 'flex', border: '1px solid #34332a', borderRadius: '6px', overflow: 'hidden' });
    styleGroup.appendChild(el('button', v.cardsBtnStyle, { text: 'Cards', onClick: v.setCards }));
    styleGroup.appendChild(el('button', v.orbsBtnStyle, { text: 'Orbs', onClick: v.setOrbs }));
    actions.appendChild(styleGroup);
    // Design / re-architect — plan a new project or re-evaluate the whole architecture.
    actions.appendChild(el('button', { display: 'inline-flex', alignItems: 'center', gap: '7px', height: '34px', padding: '0 14px', borderRadius: '6px', border: '1px solid #6a4b8f', background: 'rgba(185,139,224,.08)', color: '#cba9e8', fontSize: '13px', fontWeight: '600', cursor: 'pointer' }, { text: 'Design / re-architect', onClick: v.copyArchitecture }));
    // Session Diff — reconcile the tree from the real git diff since canon.
    actions.appendChild(el('button', { display: 'inline-flex', alignItems: 'center', gap: '7px', height: '34px', padding: '0 14px', borderRadius: '6px', border: '1px solid #34332a', background: 'transparent', color: '#b7b3a3', fontSize: '13px', fontWeight: '600', cursor: 'pointer' }, { text: 'Session Diff', onClick: v.copyDiff }));
    actions.appendChild(el('button', { display: 'inline-flex', alignItems: 'center', gap: '7px', height: '34px', padding: '0 14px', borderRadius: '6px', border: '1px solid #34332a', background: 'transparent', color: '#b7b3a3', fontSize: '13px', fontWeight: '600', cursor: 'pointer' }, { text: 'Sync', onClick: v.copySync }));
    var installBtn = el('button', { display: 'inline-flex', alignItems: 'center', gap: '7px', height: '34px', padding: '0 14px', borderRadius: '6px', border: '1px solid var(--accent)', background: 'transparent', color: 'var(--accent)', fontSize: '13px', fontWeight: '600', cursor: 'pointer' }, { onClick: v.copyInstall });
    installBtn.appendChild(el('span', { width: '7px', height: '7px', borderRadius: '50%', background: 'var(--accent)', boxShadow: '0 0 8px var(--accent)' }));
    installBtn.appendChild(document.createTextNode('Install'));
    actions.appendChild(installBtn);
    topRow.appendChild(actions);
    header.appendChild(topRow);

    var chipRow = el('div', { display: 'flex', alignItems: 'center', gap: '14px', padding: '0 24px 14px', flexWrap: 'wrap' });
    var chipsWrap = el('div', { display: 'flex', gap: '6px', flexWrap: 'wrap' });
    v.chips.forEach(function (chip) {
      var b = el('button', chip.style, { onClick: chip.onClick, text: chip.label });
      b.appendChild(el('span', chip.countStyle, { text: String(chip.count) }));
      chipsWrap.appendChild(b);
    });
    chipRow.appendChild(chipsWrap);
    var legendWrap = el('div', { marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: '14px', flexWrap: 'wrap' });
    v.legend.forEach(function (lg) {
      var span = el('span', { display: 'inline-flex', alignItems: 'center', gap: '6px', fontFamily: 'var(--font-mono)', fontSize: '10px', letterSpacing: '.08em', textTransform: 'uppercase', color: '#8e8a78' });
      span.appendChild(el('span', lg.dot));
      span.appendChild(document.createTextNode(lg.label));
      legendWrap.appendChild(span);
    });
    chipRow.appendChild(legendWrap);
    header.appendChild(chipRow);
    shell.appendChild(header);

    // ---- Canvas ----
    var canvasScroll = el('div', { flex: '1', overflow: 'auto', position: 'relative', cursor: 'grab', background: 'var(--surface-dark)', backgroundImage: 'radial-gradient(rgba(255,255,255,.045) 1px,transparent 1px)', backgroundSize: '28px 28px' }, { class: 'rt-scroll', id: 'rt-canvas-scroll', onMouseDown: v.onCanvasDown });
    var sizer = el('div', v.sizerStyle);
    var canvas = el('div', v.canvasStyle);

    v.gridChrome.forEach(function (g) {
      canvas.appendChild(el('div', g.style, { text: g.text }));
    });

    var svg = svgEl('svg', { width: v.canvasW, height: v.canvasH });
    svg.style.position = 'absolute'; svg.style.left = '0'; svg.style.top = '0';
    svg.style.overflow = 'visible'; svg.style.pointerEvents = 'none';
    v.edges.forEach(function (e) {
      var path = svgEl('path', { d: e.d, fill: 'none' });
      for (var sk in e.style) { if (Object.prototype.hasOwnProperty.call(e.style, sk)) path.style[sk] = e.style[sk]; }
      edgeEls.push({ el: path, a: e.a, b: e.b, op: e.op });
      svg.appendChild(path);
    });
    canvas.appendChild(svg);

    v.nodes.forEach(function (n) {
      var box = el('div', n.box, { 'data-node': '1', onClick: n.onClick, onMouseEnter: n.onEnter, onMouseLeave: n.onLeave });
      nodeEls[n.id] = box;
      if (n.isCard) {
        var head = el('div', { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px', marginBottom: '7px' });
        head.appendChild(el('span', { fontFamily: 'var(--font-mono)', fontSize: '11px', letterSpacing: '.04em', color: '#a9a594', whiteSpace: 'nowrap' }, { text: n.icon + n.id }));
        var pill = el('span', n.pill);
        pill.appendChild(el('span', n.pillDot));
        pill.appendChild(document.createTextNode(n.stateLabel));
        head.appendChild(pill);
        box.appendChild(head);
        box.appendChild(el('div', { fontFamily: 'var(--font-display)', fontWeight: '600', fontSize: '14.5px', lineHeight: '1.22', letterSpacing: '-.01em', color: 'var(--on-dark)', textWrap: 'pretty' }, { text: n.title }));
        var foot = el('div', { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px', marginTop: '9px' });
        foot.appendChild(el('span', { fontFamily: 'var(--font-mono)', fontSize: '10px', letterSpacing: '.06em', color: '#6f6c5d' }, { text: n.version }));
        foot.appendChild(el('span', { fontSize: '11px', color: '#6f6c5d' }, { text: n.depLabel }));
        box.appendChild(foot);
      } else if (n.isOrb) {
        var circle = el('div', n.orbCircle);
        circle.appendChild(el('span', { fontFamily: 'var(--font-mono)', fontSize: '11px', letterSpacing: '.02em', textAlign: 'center', lineHeight: '1.1', color: 'var(--on-dark)' }, { text: n.icon + n.id }));
        box.appendChild(circle);
        box.appendChild(el('div', { position: 'absolute', top: '112px', left: '50%', transform: 'translateX(-50%)', width: '180px', textAlign: 'center', fontFamily: 'var(--font-display)', fontWeight: '500', fontSize: '12px', lineHeight: '1.2', color: '#c7c3b3', pointerEvents: 'none' }, { text: n.title }));
      } else if (n.isDraft) {
        var dhead = el('div', { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px', marginBottom: '7px' });
        dhead.appendChild(el('span', { fontFamily: 'var(--font-mono)', fontSize: '11px', letterSpacing: '.04em', color: '#cba9e8', whiteSpace: 'nowrap' }, { text: '⎇ ' + n.id }));
        var dpill = el('span', n.pill);
        dpill.appendChild(el('span', n.pillDot));
        dpill.appendChild(document.createTextNode(n.stateLabel));
        dhead.appendChild(dpill);
        box.appendChild(dhead);
        var ta = el('textarea', { width: '100%', minHeight: '54px', resize: 'none', boxSizing: 'border-box', background: 'rgba(185,139,224,.07)', border: '1px dashed #6a4b8f', borderRadius: '4px', color: 'var(--on-dark)', fontFamily: 'var(--font-body)', fontSize: '12.5px', lineHeight: '1.4', padding: '7px 8px', outline: 'none' }, { placeholder: 'Describe the requirement / change / client ask…', onInput: n.onDescInput, onMouseDown: v.stop, onClick: v.stop, 'data-rt-focus': 'node-desc-' + n.id });
        ta.value = n.desc;
        box.appendChild(ta);
        box.appendChild(el('div', { marginTop: '7px', fontFamily: 'var(--font-mono)', fontSize: '9px', letterSpacing: '.07em', color: '#7c7868', textTransform: 'uppercase' }, { text: 'Draft · Claude refines this into the tree' }));
      }
      canvas.appendChild(box);
    });

    sizer.appendChild(canvas);
    canvasScroll.appendChild(sizer);
    shell.appendChild(canvasScroll);

    // ---- Zoom controls ----
    var zoomBar = el('div', { position: 'absolute', left: '18px', bottom: '18px', zIndex: '30', display: 'flex', alignItems: 'center', gap: '2px', background: '#121109', border: '1px solid #2c2b21', borderRadius: '8px', padding: '4px', boxShadow: '0 8px 24px rgba(0,0,0,.45)' });
    zoomBar.appendChild(el('button', { width: '32px', height: '30px', border: '0', borderRadius: '6px', background: 'transparent', color: '#cfcbbb', fontSize: '20px', lineHeight: '1', cursor: 'pointer' }, { text: '−', title: 'Zoom out', onClick: v.zoomOut }));
    zoomBar.appendChild(el('button', { minWidth: '52px', height: '30px', border: '0', borderRadius: '6px', background: 'transparent', color: '#cfcbbb', fontFamily: 'var(--font-mono)', fontSize: '12px', cursor: 'pointer' }, { text: v.zoomPct + '%', title: 'Reset to 100%', onClick: v.zoomReset }));
    zoomBar.appendChild(el('button', { width: '32px', height: '30px', border: '0', borderRadius: '6px', background: 'transparent', color: '#cfcbbb', fontSize: '18px', lineHeight: '1', cursor: 'pointer' }, { text: '+', title: 'Zoom in', onClick: v.zoomIn }));
    shell.appendChild(zoomBar);

    // ---- Detail / branch drawer ----
    if (v.selected) {
      var sv = v.selected;
      var drawer = el('div', { position: 'absolute', top: '0', right: '0', bottom: '0', width: '418px', background: '#121109', borderLeft: '1px solid #2c2b21', boxShadow: '-30px 0 60px rgba(0,0,0,.45)', overflow: 'auto', zIndex: '40', display: 'flex', flexDirection: 'column' }, { class: 'rt-scroll' });
      var dHead = el('div', { padding: '22px 24px 18px', borderBottom: '1px solid #24231b', position: 'sticky', top: '0', background: '#121109', zIndex: '2' });
      var dTopRow = el('div', { display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: '10px' });
      var headPill = el('span', sv.pill);
      headPill.appendChild(el('span', sv.pillDot));
      headPill.appendChild(document.createTextNode(sv.stateLabel));
      dTopRow.appendChild(headPill);
      dTopRow.appendChild(el('button', { background: 'transparent', border: '0', color: '#7c7868', fontSize: '22px', lineHeight: '1', cursor: 'pointer', padding: '0 2px' }, { text: '×', onClick: v.closeDrawer }));
      dHead.appendChild(dTopRow);
      dHead.appendChild(el('div', { fontFamily: 'var(--font-mono)', fontSize: '11px', letterSpacing: '.06em', color: '#8e8a78', marginTop: '14px' }, { text: sv.icon + sv.id + ' · ' + sv.version }));
      dHead.appendChild(el('div', { fontFamily: 'var(--font-display)', fontWeight: '600', fontSize: '21px', lineHeight: '1.18', letterSpacing: '-.01em', color: 'var(--on-dark)', marginTop: '4px', textWrap: 'pretty' }, { text: sv.title }));
      drawer.appendChild(dHead);

      var depRow = function (d) {
        var rowEl = el('div', { display: 'flex', alignItems: 'center', gap: '9px', padding: '8px 10px', border: '1px solid #28271e', borderRadius: '4px' });
        rowEl.appendChild(el('span', d.dot));
        rowEl.appendChild(el('span', { fontFamily: 'var(--font-mono)', fontSize: '10.5px', color: '#a9a594' }, { text: d.id }));
        rowEl.appendChild(el('span', { fontSize: '12.5px', color: '#bdb9a8', flex: '1', minWidth: '0' }, { text: d.title }));
        rowEl.appendChild(el('span', { fontFamily: 'var(--font-mono)', fontSize: '9.5px', letterSpacing: '.06em', color: d.color }, { text: d.label }));
        return rowEl;
      };
      var section = function (label, text) {
        var s = el('div');
        s.appendChild(el('div', v.secLabel, { text: label }));
        s.appendChild(el('p', { margin: '0', fontSize: '13.5px', lineHeight: '1.5', color: '#cbc7b6' }, { text: text }));
        return s;
      };

      if (v.isNode) {
        var body = el('div', { padding: '20px 24px 28px', display: 'flex', flexDirection: 'column', gap: '18px' });
        body.appendChild(section('Goal', sv.goal));
        body.appendChild(section('Done when', sv.doneWhen));
        body.appendChild(section('Status · next step', sv.next));

        var upstream = el('div');
        upstream.appendChild(el('div', v.secLabel, { text: 'Upstream — must be in place' }));
        var upList = el('div', { display: 'flex', flexDirection: 'column', gap: '6px' });
        v.selDeps.forEach(function (d) { upList.appendChild(depRow(d)); });
        if (v.noDeps) upList.appendChild(el('div', { fontSize: '12.5px', color: '#6f6c5d', fontStyle: 'italic' }, { text: 'Entry point — no upstream dependencies.' }));
        upstream.appendChild(upList);
        body.appendChild(upstream);

        var readFirst = el('div');
        readFirst.appendChild(el('div', v.secLabel, { text: 'Read first' }));
        readFirst.appendChild(el('code', { display: 'block', fontFamily: 'var(--font-mono)', fontSize: '11px', color: '#9fc9e6', background: '#0c0c0a', border: '1px solid #24231b', borderRadius: '4px', padding: '8px 10px', wordBreak: 'break-all' }, { text: sv.spec }));
        body.appendChild(readFirst);

        var handoffSec = el('div', { borderTop: '1px solid #24231b', paddingTop: '16px' });
        var hsHead = el('div', { display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' });
        hsHead.appendChild(el('div', v.secLabel, { text: 'Claude handoff prompt' }));
        hsHead.appendChild(el('button', v.copyBtn, { text: 'Copy', onClick: v.copyHandoff }));
        handoffSec.appendChild(hsHead);
        handoffSec.appendChild(el('pre', { margin: '0', maxHeight: '220px', overflow: 'auto', fontFamily: 'var(--font-mono)', fontSize: '11px', lineHeight: '1.5', color: '#bcdcef', background: '#0c0c0a', border: '1px solid #24231b', borderRadius: '4px', padding: '12px', whiteSpace: 'pre-wrap' }, { class: 'rt-scroll', text: v.handoffText }));
        body.appendChild(handoffSec);

        var btnRow = el('div', { display: 'flex', gap: '10px' });
        btnRow.appendChild(el('button', { flex: '1', height: '42px', borderRadius: '5px', border: '0', background: 'var(--accent)', color: '#0E0E0C', fontWeight: '700', fontSize: '13.5px', cursor: 'pointer' }, { text: 'Copy handoff for Claude', onClick: v.copyHandoff }));
        btnRow.appendChild(el('button', { height: '42px', padding: '0 16px', borderRadius: '5px', border: '1.5px solid #6a4b8f', background: 'rgba(185,139,224,.08)', color: '#cba9e8', fontWeight: '600', fontSize: '13px', cursor: 'pointer', whiteSpace: 'nowrap' }, { text: '⎇ Branch here', onClick: v.branchHere }));
        body.appendChild(btnRow);
        drawer.appendChild(body);
      }

      if (v.isDraft) {
        var dbody = el('div', { padding: '20px 24px 28px', display: 'flex', flexDirection: 'column', gap: '16px' });
        var intro = el('div', { fontSize: '12.5px', lineHeight: '1.5', color: '#bdb9a8' });
        intro.appendChild(document.createTextNode('Drafted off '));
        intro.appendChild(el('b', { color: 'var(--on-dark)' }, { text: sv.parentLabel }));
        intro.appendChild(document.createTextNode(". Write what this branch needs — straight on the node or here. It's grafted live as a draft; Claude can refine it into proper slices later."));
        dbody.appendChild(intro);

        var reqSec = el('div');
        reqSec.appendChild(el('div', v.secLabel, { text: 'Requirements / what changed' }));
        var reqTa = el('textarea', { width: '100%', minHeight: '120px', resize: 'vertical', background: '#0c0c0a', border: '1.5px solid #4a3866', borderRadius: '5px', color: 'var(--on-dark)', fontSize: '13px', lineHeight: '1.5', padding: '11px 12px', outline: 'none' }, { placeholder: 'e.g. Client wants a daily-challenge mode — fixed seed, shared leaderboard — shippable before the gauntlet.', onInput: v.editDesc, 'data-rt-focus': 'drawer-desc' });
        reqTa.value = v.branchDesc || '';
        reqSec.appendChild(reqTa);
        dbody.appendChild(reqSec);

        var forkSec = el('div');
        forkSec.appendChild(el('div', v.secLabel, { text: 'Forks from' }));
        var forkList = el('div', { display: 'flex', flexDirection: 'column', gap: '6px' });
        v.selDeps.forEach(function (d) { forkList.appendChild(depRow(d)); });
        forkSec.appendChild(forkList);
        dbody.appendChild(forkSec);

        var cleanupSec = el('div', { borderTop: '1px solid #24231b', paddingTop: '16px' });
        var csHead = el('div', { display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' });
        csHead.appendChild(el('div', v.secLabel, { text: 'Cleanup brief for Claude' }));
        csHead.appendChild(el('button', v.copyBtn, { text: 'Copy', onClick: v.copyCleanup }));
        cleanupSec.appendChild(csHead);
        cleanupSec.appendChild(el('pre', { margin: '0', maxHeight: '230px', overflow: 'auto', fontFamily: 'var(--font-mono)', fontSize: '11px', lineHeight: '1.5', color: '#d7c2ef', background: '#0c0c0a', border: '1px solid #24231b', borderRadius: '4px', padding: '12px', whiteSpace: 'pre-wrap' }, { class: 'rt-scroll', text: v.cleanupText }));
        dbody.appendChild(cleanupSec);

        dbody.appendChild(el('button', { height: '42px', borderRadius: '5px', border: '0', background: '#b98be0', color: '#0E0E0C', fontWeight: '700', fontSize: '13px', cursor: 'pointer' }, { text: 'Copy cleanup brief for Claude', onClick: v.copyCleanup }));
        dbody.appendChild(el('button', { height: '38px', borderRadius: '5px', border: '1px solid #4a2e2e', background: 'transparent', color: '#d07a5e', fontWeight: '600', fontSize: '12.5px', cursor: 'pointer' }, { text: 'Discard this draft branch', onClick: v.discardGhost }));
        drawer.appendChild(dbody);
      }
      shell.appendChild(drawer);
    }


    // ---- Copied toast ----
    if (v.copied) {
      shell.appendChild(el('div', { position: 'absolute', bottom: '28px', left: '50%', transform: 'translateX(-50%)', zIndex: '80', background: '#5BD49B', color: '#0a1f16', fontWeight: '700', fontSize: '13px', padding: '11px 20px', borderRadius: '6px', boxShadow: '0 12px 30px rgba(0,0,0,.4)', animation: 'rtToast .22s var(--ease)', fontFamily: 'var(--font-body)' }, { text: 'Copied to clipboard ✓' }));
    }

    root.appendChild(shell);

    // Re-bind the scroll element + wheel listener after each render.
    scrollEl = document.getElementById('rt-canvas-scroll');
    if (scrollEl) {
      scrollEl.addEventListener('wheel', function (e) {
        if (e.ctrlKey || e.metaKey) { e.preventDefault(); applyZoom(state.zoom * Math.exp(-e.deltaY * 0.0016), e.clientX, e.clientY); }
      }, { passive: false });
    }
    if (_scroll && scrollEl) { scrollEl.scrollLeft = _scroll.l; scrollEl.scrollTop = _scroll.t; }
    if (_focusKey) {
      var _nf = document.querySelector('[data-rt-focus="' + _focusKey + '"]');
      if (_nf) { _nf.focus(); if (_caretS != null && _nf.setSelectionRange) { try { _nf.setSelectionRange(_caretS, _caretE); } catch (e) {} } }
    }
  }

  // ---------------------------------------------------------------------------
  // Boot (replaces componentDidMount).
  // ---------------------------------------------------------------------------
  render();
})();
