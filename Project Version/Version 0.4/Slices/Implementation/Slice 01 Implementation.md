---
artefact: slice-implementation
slice_id: v0.4-slice-01
version: 0.4
slice_number: 1
slice_name: deck-run-model
status: done
authored: 2026-06-07
files_changed:
  - experiments/dual-layer/sim.js
  - experiments/dual-layer/runmode-check.cjs
  - Project Version/Version 0.4/Slices/Unit Tests/evidence/runmode-comparison.md
  - Project Version/Version 0.4/Slices/Unit Tests/evidence/draw-aligned-run1.json
  - Project Version/Version 0.4/Slices/Unit Tests/evidence/draw-aligned-run2.json
architecture_sections_updated: []
---

# Slice 01 Implementation — deck-run-model

## What was built

The dual-layer combat core was extracted from the throwaway browser harness into a single shared
module, `experiments/dual-layer/sim.js` — a pure, deterministic engine (seeded `mulberry32` PCG,
the body/weapon/support data, the card set, `makeCombatant`, `setupCards`/`drawUp`, and
`simulate(A, B, seed, mode)`). It supports all three run models behind the `mode` argument
(`construction` / `draw` / `hybrid`) and an `opts.brokenShuffle` negative-control switch used only
by the check.

A headless check, `experiments/dual-layer/runmode-check.cjs`, requires that same module and runs
the comparison the decision needs: per-model determinism (run twice, byte-compare the event
stream), a negative control (an unseeded shuffle must produce divergent streams under one seed),
and a comparison table across a fixed four-matchup set (aligned-melee, misaligned-kite,
counter-ranged, heavy-bruiser) versus the fixed rival "KESTREL". It writes evidence to
`Project Version/Version 0.4/Slices/Unit Tests/evidence/` and exits non-zero on any failure.

## Key decisions

- **Single source of truth.** The check imports the same `sim.js` the harness will load, so the
  determinism evidence reflects the code that actually runs — no second copy to drift.
- **Negative control for AC-5.** Rather than assert "it's deterministic," the check proves the
  diff *can catch* non-determinism by deliberately breaking the shuffle and showing 5/5 distinct
  streams, then showing the seeded shuffle is identical (the recovery).
- **Quantitative legibility signals.** The comparison records dead-cards, whiffs, and hesitations
  per run, so "alignment" is measured, not just asserted.

## Deviations from the spec

The existing self-contained harness (`experiments/dual-layer-deck-combat.html`) was left working
as-is for the owner's in-browser feel pass (AC-1); it still carries an inline copy of the core
identical to `sim.js`. Replacing that inline copy with a `<script src>` to `sim.js` is deferred to
the next time the harness is touched (the combat-core slice unifies it in Godot regardless). This
keeps the owner's playtest tool from breaking during this decision slice.

## Architecture updates

None. This is an enabling decision slice; it adds no product (Godot) architecture. `sim.js` lives
under `experiments/` as a throwaway feel-test, not the shipping core. The chosen model's runtime
contract (below) is the input to the combat-core slice, which *will* write Current Architecture.

## Revisions

None.

## What to know before changing this

- `simulate` must stay pure and seed-driven (BEH-001). All randomness flows through the passed
  seed; no `Math.random`, no time, no DOM. The negative-control path is the only place `Math.random`
  appears, and only when `opts.brokenShuffle` is set by the check.
- The card `when` predicates and the priority-by-deck-order selection are the heart of behaviour;
  changing them changes every outcome in the comparison.

## Headline finding (feeds the AC-4 decision)

- All three models are deterministic; divergence is detectable (AC-2, AC-5 PASS).
- **construction** and **hybrid** play clean, decisive, legible duels that track the authored deck.
- **draw** is degenerate *as prototyped*: a 3-card hand drawn from a 5-card deck frequently leaves
  no card whose trigger matches the moment, so the pilot hesitates 30–39 times and the duel times
  out at 80 turns. This is partly an implementation property (small hand, strict triggers, no
  redraw economy) — but fixing it would add machinery that fights the core goal ("she fights the
  deck I authored").
- **hybrid** mostly equals construction (its always-available core covers the common cases) but
  inherits draw's stall risk for non-core cards (see heavy-bruiser timing out).
- **Recommendation: construction.** It is the most faithful to authored intent, the most legible
  (the fight is the readout), the simplest deterministic contract, and it carries no luck into a
  competitive async-PvP result.

## Proposed runtime contract for the chosen model (construction)

The whole live deck is the pilot's always-available repertoire. Each turn: regen energy, tick
cooldowns, then play the highest-priority (lowest deck index) card whose `when` predicate holds and
whose cost is affordable and not on cooldown; if none, the pilot hesitates (a logged, legible
event). No hand, no draw, no shuffle — so there is no per-fight RNG at all beyond the seed used for
any future tie-breaks. This is what the combat-core slice should implement.

## Files changed

See frontmatter `files_changed`.
