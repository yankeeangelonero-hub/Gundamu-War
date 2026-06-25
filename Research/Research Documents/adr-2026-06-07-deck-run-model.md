---
artefact: research-document
kind: adr
project: kitbash-mecha
title: deck-run-model-construction
authored: 2026-06-07
frozen: true
supersedes:
supersedes_section:
---

# ADR 2026-06-07 — Behaviour-deck run model: construction

Status: Accepted. Decided in Version 0.4, slice `v0.4-slice-01`, owner-confirmed 2026-06-07.

## Decision needed

The dual-layer wishlist left one mechanic open to playtest
(`Research/Research Documents/wishlist-revision-2026-06-07-dual-layer.md` §Open questions to
settle by testing, not by argument): how the behaviour deck is *consumed at runtime* during a
duel. It blocks the combat-core slice, which must implement exactly one model.

## Options considered

- **Construction** — the whole live deck is the pilot's always-available repertoire; she plays the
  highest-priority applicable card by deck order. No hand, no draw.
- **Draw** — a hand is drawn each turn from a seeded shuffle, with an energy economy.
- **Hybrid** — an always-available core plus a few drawn "opportunity" cards.

## Evaluation criteria

Authored-intent fidelity (does she fight the deck I built); legibility (can the watched fight be
read — the fight is the readout, FEAT-009 / BEH-004); determinism (byte-equal re-simulation for
async-PvP verification, BEH-001); fairness (no luck deciding a competitive result); simplicity of
the runtime contract (ARC-006).

## Evidence

`experiments/dual-layer/runmode-check.cjs` over a fixed four-matchup set versus rival "KESTREL"
at seed `0xC0FFEE`, using the shared core `experiments/dual-layer/sim.js`. Full output:
`Project Version/Version 0.4/Slices/Unit Tests/evidence/runmode-comparison.md`.

- All three models are deterministic (run-twice events byte-identical). The unseeded-shuffle
  negative control produced 5/5 distinct streams under one seed (divergence is detectable); the
  seeded recovery was identical.
- **construction** and **hybrid** play decisive, legible duels (11–18 turns) that track the
  authored deck; the deliberately misaligned saber-body-on-spacing-deck build visibly floundered
  (one dead card, a loss).
- **draw** is degenerate as prototyped: every matchup timed out at 80 turns with 29–39
  hesitations — a 3-card hand drawn from a 5-card deck frequently leaves no card whose trigger
  matches the moment, so the pilot stalls.

## Decision

**Construction.** The whole live deck is the pilot's always-available repertoire. Each turn she
regenerates energy, ticks cooldowns, and plays the highest-priority (lowest deck index) card whose
trigger holds, that she can afford and is off cooldown; if none holds, she hesitates (a logged,
legible event). No hand, no draw, no per-fight shuffle.

## Consequences

- Authored intent is faithful and the watched fight stays legible (FEAT-009, BEH-004).
- No per-fight randomness beyond the seed, so re-simulation is trivially deterministic for the
  async-PvP endgame (BEH-001, ARC-006).
- The runtime contract for the combat-core slice is fixed — see the slice Implementation Record's
  "Proposed runtime contract".
- Anti-solved-meta now rests on body↔deck counterplay and the card pool rather than draw variance;
  watch this as the card library grows.
- Draw's degeneracy was partly an implementation property (small hand, strict triggers, no redraw
  economy). We accept not pursuing a draw redesign because it would add machinery that fights the
  authored-intent goal. Revisit only if construction proves too static once the card pool is large.
