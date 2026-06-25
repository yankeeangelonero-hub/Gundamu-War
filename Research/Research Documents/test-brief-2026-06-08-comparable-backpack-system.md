---
project: kitbash-mecha
repo: gundamu-war
artefact: research-document
doc_type: test-brief
kind: finding
status: draft
created: 2026-06-08
source_request: "Owner request in Discord: branch it, use Vouse skills to spec a comparable backpack system to test instead"
compares_against:
  - Research/Research Documents/wishlist-revision-2026-06-07-dual-layer.md
  - experiments/dual-layer-deck-combat.html
---

# Test Brief 2026-06-08 — Comparable Backpack System

This branch tests whether a Backpack Battles-style build surface can compete with the current
body-plus-mind direction on the same evidence standard. It does not overturn the dual-layer
wishlist. It creates a comparable, throwaway test target: same deterministic duel, same debrief
expectation, same small scope, but with the player's authorship expressed through spatial item
placement rather than a separate behaviour deck.

## Hypothesis

A single backpack canvas may deliver the build-fighter fantasy with less cognitive load than the
body-plus-mind split. The player places shaped parts/items into one expandable grid; item tags,
adjacency, orientation, and active timers define how the machine fights. The fight remains watched
and deterministic. The debrief names placement reasons: which adjacency bonuses activated, which
items starved for energy, which tags had no partner, and which attack timing lost the matchup.

## Comparable test shape

The test should be comparable to `experiments/dual-layer-deck-combat.html`, not a full game:

- one build canvas, initially small enough to force tradeoffs;
- a small item set with shaped footprints, tags, ATB speed, power draw, and adjacency rules;
- one rival build source with a fixed seed;
- deterministic item-timer combat that emits an ordered event log;
- a debrief that explains outcome through placement and item interactions;
- a headless check that reruns the same `{bag, rival, seed}` and byte-compares the event log.

## Backpack system rules to test

- **One canvas, not five bags.** The old five-bag body-part split is not the test. The comparator is
  a single Backpack Battles-like board whose shape can later expand through buyable bag pieces.
- **Items are both gear and program.** There is no separate behaviour deck. Attack cadence, defense,
  buffs, and conditional effects come from placed items and their adjacency/tag rules.
- **Spatial constraints do real work.** Item shape, rotation, and adjacency create tradeoffs that
  the weight/power budget currently creates in the dual-layer prototype.
- **Readable synergy beats hidden math.** Every active bonus must be previewable on the board and
  named in the event log/debrief.
- **Constrained escalation, not flat sidegrades.** Backpack-style games can use visible item
  upgrading and stronger late pieces. The comparator should test that escalation, but every power
  step must stay legible and counterable through cost, footprint, heat, cooldown, dependency, or
  matchup weakness — not become an invisible stat treadmill.

## Evaluation criteria

The backpack comparator passes only if it can answer these questions with evidence:

1. **Legibility:** Can a tester understand why the build won or lost from board highlights, event
   log lines, and the debrief without reading the implementation?
2. **Authorship fidelity:** Does the machine fight like the placement says it should, or does the
   player feel the simulator is inventing behaviour offscreen?
3. **Cognitive load:** Is one spatial surface easier to grasp than body-plus-deck, or does it become
   a cluttered spreadsheet of tiny item rules?
4. **Determinism:** Does the same `{bag, rival, seed}` reproduce byte-identical logs?
5. **Counter-build depth:** Can at least three fixed builds produce meaningfully different outcomes
   against the same rival for reasons visible in the debrief?

## Non-goals

This branch does not need a shop, economy, unlocks, Godot port, production art, networked PvP,
war theatre, or a large item library. It only needs enough surface to compare the backpack grammar
against the dual-layer grammar.

## Decision output

The test should end in an ADR with one of three outcomes:

- **Backpack wins:** adopt the single-canvas backpack system as the near-term build surface and
  supersede the dual-layer body/mind split in a later version transition.
- **Dual-layer wins:** keep the current body-plus-mind direction and record why the backpack grammar
  was weaker.
- **Hybrid path:** keep body-plus-mind as the thesis, but import specific backpack mechanics such as
  spatial item placement, adjacency highlights, or buyable canvas expansion.
