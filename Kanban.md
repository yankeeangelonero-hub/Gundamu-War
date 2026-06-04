---
project: mech-bags
doc_type: kanban
status: active
updated: 2026-06-04
---

# Kanban — Mech Bags

## Backlog

<!-- All Version 0.1 slices moved to Done below -->

---

## In Progress

<!-- Nothing in progress -->

---

## Done

### [SLICE-01] Static five-bag board shell ✓
**Version:** 0.1 | **Size:** Small | **Status:** Verified
Five named bag grids rendered in CSS Grid mech silhouette layout. Head centred top, L Arm / Torso / R Arm middle, Back below. No JS errors on load.
`FEAT-001`

### [SLICE-02] Item placement and rotation ✓
**Version:** 0.1 | **Size:** Medium | **Status:** Verified
Click-select-then-click-place interaction with hover preview. Rotation via R key or button. Geometry/overlap validation only — no anatomy check. Tests confirm BEH-001.
`FEAT-001 BEH-001`

### [SLICE-03] Shop and body expansion cards ✓
**Version:** 0.1 | **Size:** Medium | **Status:** Verified
Shop shows 4 random items + 1 expansion card per round. Buying deducts gold immediately. expandBag() adds 1 row to named bag only. Reroll costs 1g. Sell returns floor(cost/2).
`FEAT-002 FEAT-004 BEH-002`

### [SLICE-04] Data-driven item stats and adjacency preview ✓
**Version:** 0.1 | **Size:** Medium | **Status:** Verified
12 items defined as data in ITEMS object. 7 adjacency rules. Same-bag adjacency glow active; removed when items move apart. Tests confirm BEH-003 and ARC-003.
`FEAT-003 BEH-003 ARC-004`

### [SLICE-05] Deterministic ATB simulator ✓
**Version:** 0.1 | **Size:** Medium | **Status:** Verified
simulate(playerBuild, enemyBuild, seed) returns {events, winner, finalPlayerHP, finalEnemyHP}. Seeded LCG PRNG. Byte-equal output confirmed by tests (seed 42 × 2). ARC-001 satisfied.
`FEAT-005 BEH-004 ARC-001`

### [SLICE-06] 2D battle viewer and paused animation playback ✓
**Version:** 0.1 | **Size:** Large | **Status:** Verified (needs browser smoke)
Async event-by-event playback (single await chain enforces BEH-004). CSS mech sprites with bag anchors. HP bars, event banner, combat log, Skip Battle. Result overlay with top-damage-bag highlight.
`FEAT-005 FEAT-006 BEH-004 BEH-005`

### [SLICE-07] Short run loop with enemy pool ✓
**Version:** 0.1 | **Size:** Medium | **Status:** Verified
Full run loop wired. 6 enemy builds (all valid, Beam Head Goblin has Beam Rifle in Head). 5 wins → RUN CLEAR. 3 losses → RUN OVER. Build persists across rounds. No network calls.
`FEAT-004 FEAT-007 ARC-002`

---

## Blocked / On Hold

<!-- Nothing blocked -->
