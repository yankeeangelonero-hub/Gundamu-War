---
artefact: slice-specification
slice_id: v0.4-slice-02
version: 0.4
slice_number: 2
slice_name: backpack-system-comparator
kind: enabling
status: review
supersedes:
patches:
delivers: []
cites_stories: [US-001]
created_under_schema_version: 0.3.0
cites_behaviours: [BEH-001, BEH-004]
cites_constraints: [ARC-001, ARC-003]
cites_decisions: []
cites_actor_flows: []
cites_research:
  - "Research/Research Documents/test-brief-2026-06-08-comparable-backpack-system.md"
  - "Research/Research Documents/wishlist-revision-2026-06-07-dual-layer.md §The essential version (discipline)"
authored: 2026-06-08
---

# Slice 02 — backpack-system-comparator

## 0. Parent change proposals

None yet. This is a branch-local comparator spec, not a canonical pivot. If the backpack system
wins the test, the follow-up is a cross-version routing event: write an ADR, then supersede the
current dual-layer direction through `vouse-managing-versions` / `vouse-project-docs` instead of
silently editing the high-level spec.

## 1. What this slice is

This slice specifies a throwaway, web-first Backpack Battles-style comparator for the current
dual-layer combat prototype. The goal is not to build the full backpack game. The goal is to test
whether one spatial backpack surface can carry the same authorship, determinism, and legible
debrief load that the current body-plus-behaviour-deck prototype carries.

The player remains the engineer and does not pilot in real time. Instead of authoring a body and a
separate behaviour deck, they place shaped items into one backpack canvas. Item footprints,
adjacency rules, tags, ATB timers, and power draw determine how the machine fights. The duel is
watched, deterministic, and followed by a debrief that explains the outcome through spatial causes:
activated adjacencies, missing partners, energy starvation, blocked space, and attack timing.

This is an **enabling comparison** slice. Its durable output is evidence for a product-direction
choice, not production architecture. It should be cheap enough to throw away if the backpack
system loses.

## 2. Vocabulary

- **Backpack canvas** — a single grid where the player places shaped items. This replaces the
  body/deck split for the comparator.
- **Item footprint** — the occupied cells of an item, represented as offsets from an anchor and
  rotated in 90-degree increments.
- **Adjacency rule** — a data-defined condition such as "if adjacent to Battery, reduce cooldown by
  1 tick" or "if adjacent to Shield, gain block before firing."
- **ATB item timer** — deterministic next-fire timing per active item. The next item to fire is the
  smallest next-fire timestamp; ties use a deterministic item-order tie-break.
- **Placement debrief** — post-fight explanation that names board-level causes, not hidden AI
  judgment.

## 3. Behaviour

The actor is the **Engineer (Player)** acting as playtester.

1. The playtester opens the comparator harness and sees one small backpack canvas, a fixed rival,
   a seed field, an item palette, and a deploy button.
2. They place a small set of shaped items into the canvas. Items can be rotated. Invalid placement
   is rejected when any occupied cell would leave the canvas or overlap an existing item.
3. The board previews active adjacency rules before deployment. Every active synergy highlights
   both source and target items and has a short tooltip-style reason.
4. The playtester deploys. The simulator resolves the duel deterministically from `{bag, rival,
   seed}`. Items fire through ATB timers; defensive and support items apply only through data-defined
   effects.
5. The event log records each meaningful event with item names and causes: fire, hit, block,
   adjacency bonus, energy starvation, cooldown change, and tie-break.
6. The debrief states why the result happened in placement terms. Examples: "Railgun fired slowly
   because it had no Battery neighbor," "Shield Loop absorbed three attacks," "two weapons competed
   for the same power budget," or "Short Blade never reached before the rival's rifle killed it."
7. The playtester repeats at least three fixed builds against the same rival: an aligned burst
   build, a defensive sustain build, and a misbuilt/cluttered build. The evidence compares whether
   the outcomes differ for visible placement reasons.

Failure/recovery paths:

- If the same `{bag, rival, seed}` produces different event logs, the simulator fails BEH-001 and
  the harness blocks the backpack option until nondeterminism is fixed.
- If an item rule affects the duel but is not visible in board preview, event log, or debrief, the
  comparator fails the legibility requirement even if the duel result is deterministic.
- If the canvas can be filled with strictly better items without tradeoff, the system fails the
  sidegrade/comparison intent and should not be read as evidence that backpack placement is fun.

## 4. Surfaces and controls

Minimum comparator surface:

- one backpack canvas, recommended start size `6×5`;
- item palette with 10–14 items covering weapons, shield/armor, battery/power, mobility, and one
  conditional combo item;
- rotate control before placement;
- remove/move item control after placement;
- active-adjacency preview on hover or selection;
- build summary with power use, attack sources, and active synergies;
- fixed rival card;
- seed input;
- deploy button;
- combat log;
- debrief panel;
- optional run-mode note: the comparator has no deck run model; the backpack itself is the authored
  program.

No shop, reroll, lock, inventory persistence, or growth screen is in scope.

## 5. Data and integration notes

The harness should be data-driven:

- `items`: id, name, tags, footprint offsets, power draw, cooldown/ATB speed, range, damage/block,
  effects, adjacency rules;
- `bag`: placed item id, anchor cell, rotation;
- `rival`: same data shape as player bag, injected like any other opponent source;
- `simulate(bagA, bagB, seed)`: pure function returning an event list, result, and debrief facts;
- no DOM reads, wall-clock time, `Math.random`, animation callbacks, or renderer state inside the
  simulation core.

Evidence should live under
`Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/` if this slice is
built.

## 6. Acceptance checks

### AC-1 — Spatial placement enforces real constraints
- **Setup:** Open the comparator harness with the default empty `6×5` canvas and item palette.
- **Action:** Place at least five shaped items, including one rotated item; attempt one overlap and one out-of-bounds placement.
- **Observable signal:** Board state dump listing item id, anchor, rotation, and occupied cells; UI/log rejection for invalid placements.
- **Expected value:** Valid items occupy the expected cells; overlap and out-of-bounds placements are rejected without changing the prior board state.
- **Evidence artifact:** `Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/placement.json` plus a screenshot or text board dump.

### AC-2 — Adjacency rules are previewable before combat
- **Setup:** Build a board with at least two active adjacency bonuses and one item missing its desired neighbor.
- **Action:** Inspect/select the relevant items before deployment.
- **Observable signal:** Preview output names each active bonus and the participating item pair; missing-neighbor item is shown as inactive or unboosted.
- **Expected value:** Every active bonus that can affect combat is visible before deployment; no hidden synergy affects the fight without a preview entry.
- **Evidence artifact:** `Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/adjacency-preview.md`.

### AC-3 — Backpack combat is deterministic
- **Setup:** Fixed player bag, fixed rival bag, fixed seed.
- **Action:** Run `simulate(playerBag, rivalBag, seed)` twice and normalize the event logs.
- **Observable signal:** Byte diff of the two normalized logs.
- **Expected value:** The logs are byte-identical. If a negative-control unseeded branch is included, the diff detects divergence and the seeded recovery passes.
- **Evidence artifact:** Paired logs and diff under `Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/determinism/`.

### AC-4 — Debrief explains outcome through placement causes
- **Setup:** Run three fixed builds against the same rival: burst, sustain, and clutter/misbuild.
- **Action:** Capture event log, result, and debrief for each build.
- **Observable signal:** Debrief text plus event-log facts for active bonuses, item fires, blocks, energy starvation, misses, and inactive synergies.
- **Expected value:** Each result has at least two concrete placement/item causes cited by the debrief, and each cited cause can be found in the event log.
- **Evidence artifact:** `Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/debrief-comparison.md`.

### AC-5 — Comparator decision evidence is sufficient
- **Setup:** AC-1 through AC-4 have evidence.
- **Action:** Write a short comparison note against the dual-layer prototype on legibility, authorship fidelity, cognitive load, determinism, and counter-build depth.
- **Observable signal:** A comparison table and recommendation: backpack wins, dual-layer wins, or hybrid path.
- **Expected value:** Recommendation cites evidence from this slice and `v0.4-slice-01`; unresolved questions are named as follow-up slices, not hidden.
- **Evidence artifact:** `Project Version/Version 0.4/Slices/Unit Tests/evidence/backpack-comparator/comparison.md`; if the owner accepts the recommendation, a follow-up ADR in `Research/Research Documents/`.

## 7. Out of scope

- Production Godot implementation.
- Shop, reroll, lock, economy, unlocks, salvage, or long-term progression.
- Multi-opponent war theatre or networked PvP.
- Large item library or balance pass.
- Rewriting the High Level Project Specifications before evidence exists.
- Importing the old five body-part bags; this comparator uses one canvas.

## 8. Open questions

Non-blocking for draft:

1. Exact item list and board dimensions. Recommendation: start with `6×5`, 10–14 items, and three
   fixed builds.
2. Whether the comparator should be a new HTML harness or a fork of `dual-layer-deck-combat.html`.
   Recommendation: new harness, reusing only sim/test patterns, so the comparison stays clean.
3. Whether power budget remains separate from space. Recommendation: yes, but keep it small; space
   should be the main constraint.

Blocking before `ready`:

Resolved 2026-06-08: owner acknowledged that the §6 acceptance checks match the intended backpack
test. Build may proceed on this branch when requested.
