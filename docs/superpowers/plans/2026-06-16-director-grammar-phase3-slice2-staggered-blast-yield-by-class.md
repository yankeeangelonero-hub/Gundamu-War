# Director Grammar — Phase 3, Slice 2: Staggered Blast + Yield-by-Class

> Status: PROPOSED plan, 2026-06-16. Builds on Phase 3 Slice 1. Determinism gate: hash 2543717900.
> Design: `docs/superpowers/specs/2026-06-16-director-grammar-design.md` (Spectacle §, F16/F17/F39).

## Goal
The spec's Spectacle dimension: **`staggered_blast` (F16)** — on a lethal/capital-tier hit, emit a
*series* of explosions at varied distances rather than one; and **`yield_by_class` (F17)** — the
weapon class maps to staging intensity (+ a "fear beat" for capital-tier), so a capital/payload
discharge gets outsized treatment and a sidearm does not. Together: **the kill spectacle scales with
the weapon that landed the kill.**

## What exists today (grounded)
- `garnish._explosion(pos)` is a SINGLE kill blast: flash light + fireball + smoke + ring + hitstop +
  `director.shake_strength = 2.0`.
- The `destroyed` event handler calls `_explosion(...)` + `_wreck_smoke(...)`. The `destroyed` event
  payload is `{}` — it does NOT carry the killing weapon.
- The killing weapon is the preceding lethal `fire_*` event (`fire_beam`/`fire_burst`/`fire_missiles`/
  `fire_buster`/`melee`, with `payload.lethal == true`). garnish already handles those events.

## Design

**Yield tiers (F17), authored in the grammar as data:**
A `yield_by_class` Dictionary mapping event kind → an integer intensity tier (1 = sidearm, 3 =
capital). Recommended defaults:
- `fire_buster` → 3 (capital/payload — the fear beat)
- `fire_missiles` → 2, `fire_beam` → 2, `melee` → 2
- `fire_burst` → 1 (gatling sidearm)
- unknown kind → 1 (safe floor)
Exposed via a pure `yield_tier(kind: String) -> int` method on `ShotGrammar` (data + lookup live
together; unit-testable).

**Staggered blast (F16):** `_staggered_blast(pos, tier)` emits a short SERIES of explosions instead
of one — `tier` blasts (tier 1 = a single blast ≈ today; tier 3 = a 3-blast chain) staggered ~0.18s
apart at varied offsets/distances around `pos`, with `director.shake_strength` and the first blast
scaled up by tier (the tier-3 "fear beat" = the biggest shake + widest spread). Each blast reuses the
existing `_explosion`-style FX (flash/fireball/smoke) so no new FX primitives — it's a *staging*
change, not new art.

**Trigger / wiring (garnish "reads outcomes, never decides"):**
- When garnish handles a `fire_*`/`melee` event with `payload.lethal == true`, record
  `_last_kill_class = e.kind` (a read, not a decision).
- On the `destroyed` event, replace the single `_explosion` with
  `_staggered_blast(pos, grammar.yield_tier(_last_kill_class))`. `_wreck_smoke` stays.
- Reset `_last_kill_class` to "" on setup; if somehow unset at a kill, `yield_tier("")` → 1 (a single
  blast, the current behaviour) — safe fallback.

This keeps the kill spectacle a single owned beat (no double-explosion: the lethal `fire_*` path does
NOT also explode — only `destroyed` stages the kill, now scaled by the recorded class).

## Determinism
`yield_by_class` is data; `_staggered_blast` is FX with seeded `rng` for offsets. The shot list is
untouched — golden hash `2543717900` MUST hold. (Use the existing `rng` for varied offsets so the
spectacle stays deterministic per seed.)

## Tasks
- **S2.1** — add `yield_by_class` Dictionary + `yield_tier(kind)` to `ShotGrammar`; assert defaults +
  the lookup (incl. unknown→1) in `shot_grammar_check.gd`. TDD headless.
- **S2.2** — `garnish._staggered_blast(pos, tier)` (the series, shake-by-tier, seeded offsets);
  track `_last_kill_class` on lethal `fire_*`/`melee`; route `destroyed` through the staggered blast.
  Boot smoke + hash.
- **S2.3** — regression (all suites + hash) + windowed `--frames` visual capture: a sidearm-ish kill
  vs a buster kill should read at clearly different spectacle scale. Review.

## Open owner decision (surface, don't block)
- **Tier defaults** above are a recommendation; the visual capture in S2.3 is the taste check — tune
  the tiers / blast count / shake from it. (Default proceed with the recommended map.)

## Execution method
Subagent-driven (implementer → spec review → quality review), with the standard guardrails
(no branch-changing git, headless-only, import-on-unknown-class).
