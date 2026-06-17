# Fight Event-Log Contract (sim ↔ presentation interface)

> Status: DESIGN, approved 2026-06-17. The frozen interface between the deterministic combat
> sim and the presentation stack (choreography → Director Grammar). First link in the chain
> `build → sim → log → director`. Branch: `combat-feel-restart`.
>
> Companion specs (out of scope here, but bounded by this contract):
> - Director Grammar: `docs/superpowers/specs/2026-06-16-director-grammar-design.md` (consumer).
> - Backpack engineering / weapon definitions: `docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md` (producer of weapon→motif/tier/travel data).
> - FeelProfile is per-BUILD and is **not** part of this per-FIGHT log — separate spec, kept separate on purpose.

## What this freezes (and what it doesn't)

This freezes the **shape and meaning of the fight event log** — the single artifact the sim
emits and the presentation stack consumes. It does **not** specify the sim's internal resolution
rules (Backpack-Battles mechanics), the weapon definitions, or the renderer. Those are separate
specs that target this contract from either side.

The log today is hand-authored (`godot_director_spike/data/fight_log_*.json`) and the director
hard-matches weapon-specific kinds (`fire_beam`, `fire_buster`, …). This contract replaces that
with a small structural vocabulary plus a data-driven presentation channel, so a new weapon — a
giant laser cannon, anything — is **data + art, never a director or sim-dispatch code change.**

## The model in one paragraph

The sim is a **deterministic outcome engine**, not a projectile simulator. From two builds and a
seed it resolves the whole duel forward into a fixed timeline of **shots** — every discharge, hit
*and* miss. Each shot lands its outcome at an **impact tick**; that impact is the truth (damage,
kill, HP). The *firing* animation is back-calculated for presentation: `fire_tick = impact_tick −
travel`. Misses resolve to no damage and read as suppressive fire / ricochets — there is no
separate fabricated cosmetic layer, the volume is real resolved shots that missed.

## Two layers: combat-truth and presentation

The log file carries two layers, with a hard boundary between them:

- **Combat-truth layer** — produced by the **sim**, a pure function of `(builds, seed)`, and the
  thing PvP verification re-simulates and checks. It is: the root `result`, and the events `spawn`
  (HP only), `shot`, `melee`, `destroyed`, each with `seq`. This is small and stable.
- **Presentation layer** — produced by the **choreographer** (a later stage), derived from the
  truth layer but *not* verified: the positional `spawn {x,z}` placement and `advance` movement, and
  any animation-timing decoration. Two replays may stage positions differently without ever changing
  who-hit-whom-for-how-much.

`motif` and `tier` are an exception worth stating plainly: they are *deterministic from the build*
(so they re-sim identically and ride in the truth layer) but they are *cosmetic* (verification
ignores them). Everything else is cleanly one layer or the other. This split is what lets
INV-DET demand an identical truth layer while presentation stays free to evolve.

## Invariants this contract carries

These are load-bearing. Implementations on either side must hold them.

- **INV-DET — determinism.** The **combat-truth layer** (see "Two layers" below) is a pure function
  of `(builds, seed)`: a headless re-sim produces an identical truth layer. This is the async-PvP
  enabler (a stored result is re-verifiable). Per `CLAUDE.md`. "Identical" means equal under a
  **canonical serialization** (sorted keys, integer fields as integers) — not raw file bytes, since
  the presentation layer may be regenerated. The sim's arithmetic must be pinned so re-sim matches
  across implementations: **uint32-wrapping LCG, integer tick math, round-half-up damage rounding**
  (see the sim spec). The presentation layer is reproducible-but-not-verified.
- **INV-CLOCKS — two clocks.** The **sim tick timeline** is the deterministic truth. The
  **playback/wall-clock timeline** is what the viewer experiences and is freely dilated by the
  director (bullet-time, hitstop, slow-mo). Determinism lives *only* on the tick timeline.
  Animation and particle visuals live *only* on playback. **Consequence:** a motif's visual can be
  arbitrarily elaborate or long — the sim never looks at it, so it cannot perturb determinism. The
  *only* way visuals could break INV-DET is if their length were sourced non-deterministically
  (wall clock, frame rate, un-seeded RNG, live physics) *and* fed back into outcome timing. Any
  timing that affects outcomes must be a deterministic stat.
- **INV-IMPACT — truth on impacts.** `damage`, `lethal`, `hp_after` exist only on a shot that
  *connects and changes HP*. Misses and **post-decision** shots (those landing after the fight is
  decided — see `post_decision`) carry no damage fields; their `outcome` is still present.
- **INV-VERIFY — what re-sim checks.** Verification compares the **outcome projection** of the
  combat-truth layer: per truth event `(tick, seq, actor, kind, outcome, damage, lethal, hp_after,
  post_decision)` plus the root `result`. It **excludes** `motif`/`tier` (deterministic-from-build
  but cosmetic — they ride in the truth layer and re-sim identically, but are not asserted) and
  **all presentation-layer events/fields** (`spawn {x,z}`, `advance`). Two stored fights match iff
  their outcome projections are equal.
- **INV-FEASIBLE — `impact = fire + travel`, feasibility on the fire side.** The relation can be
  read either direction, but a weapon cannot fire before it spawns or before it is reloaded. The
  sim runs forward, so it never emits an impossible impact: a weapon's earliest impact is
  `first_fire_tick + travel` (and `first_fire_tick = spawn_tick + cooldown`). `travel ≥ 1` always,
  so a shot's fire and impact never share a tick. Travel time is thus a real **tempo lever** —
  heavy slow weapons resolve late, light weapons trade early.
- **INV-ORDER — frozen total order.** Every combat-truth event carries a `seq` (a monotonic integer
  in sim emit order). The canonical order is `(tick, seq)` — never `tick` alone, because ties on a
  tick are combat-truth (which of two simultaneous impacts kills first). The loader **asserts** this
  order; it must not re-sort with an unstable comparator (Godot's `sort_custom` is not stable).
  Within a tick the sim resolves **impacts (and melee contacts) before fires** (a mech killed at
  tick T cannot fire at T); `destroyed` immediately follows its lethal `shot`. Because `travel ≥ 1`,
  no fire shares a tick with the impact it produces. Presentation-layer events (`advance`) are
  slotted by tick when merged and are not part of the verified projection (INV-VERIFY).

## Event shape

Root:

```jsonc
{
  "schema": "km-fight-log-v2",
  "tick_seconds": 0.1,
  "seed": 0,                          // re-sim seed (INV-DET); 0 until the sim lands
  "builds": ["A-ref", "B-ref"],       // build identity for PvP re-verification
  "result": { "winner": "A",          // "A" | "B" | "draw"  (combat-truth)
              "cause": "kill" },       // "kill" | "cap" (tick/event cap) | "stalemate" (no attackers)
                                        // on cap/stalemate, winner = higher current HP (draw if equal)
  "events": [ /* in canonical (tick, seq) order */ ]
}
```

Every event: `{ "tick": int, "seq": int, "actor": "A"|"B", "kind": <enum>, "payload": {} }`.
`tick` is the **impact tick** for shots, the structural-event tick for the rest; `seq` is the
sim's monotonic emit index (the tie-break — see INV-ORDER).

**Kind vocabulary — closed and structural** (the four weapon-specific `fire_*` kinds collapse into
one `shot`). The **layer** column marks combat-truth (T) vs presentation (P):

| kind | layer | tick means | payload |
|---|---|---|---|
| `spawn` | T `hp` / P `x,z` | placement | `{hp}` (truth) + `{x, z}` (presentation) |
| `advance` | P | move start | `{to_x, to_y?, to_z?, end_tick, boost?}` — choreographer-supplied |
| `shot` | T | **impact** | see below |
| `melee` | T | contact | `{motif, tier, outcome("hit"|"miss"), result?("lock"|"knockback"), lethal?, damage?, hp_after?}` |
| `destroyed` | T | death | `{}` (`actor` = the destroyed mech; immediately follows its lethal `shot`) |

`melee` stays its own kind: ~0 travel and distinct framing (`melee_cut`). Everything ranged is a
`shot`.

**`shot` payload:**

```jsonc
{
  "motif": "giant_beam",   // OPEN registry id → VFX/SFX primitive. New weapon = new row + art.
  "tier": 3,               // spectacle scalar 1–3 → kill-blast size, grade weight, shake.
  "travel": 8,             // ticks of flight (≥ 1); fire_tick = tick − travel (here: impact 128 → fire 120).
  "outcome": "hit",        // "hit" | "miss"  (a "miss" reads as suppressive fire / ricochet — renderer's choice by motif)
  "damage": 140, "lethal": true, "hp_after": 0   // present ONLY on a connecting hit that changed HP
  // "post_decision": true  // set when the shot lands after the fight is already decided:
  //                        // keep its rolled `outcome`, OMIT damage/lethal/hp_after (no HP change).
}
```

**v1 grain — one round per activation.** A `shot` is a single resolved discharge: `outcome` is
`hit` or `miss`, no `rounds`/`hits` aggregate. Multi-round bursts (`rounds:6, hits:2` in one event,
with per-round rolls and aggregated damage) are **deferred** — added later as an explicit extension,
not assumed now (YAGNI).

### The three decoupled channels

This is the foundation that makes weapon variety free:

- **`kind`** — structural, **closed**. The sim's and director's high-level dispatch. Grows only on
  a deliberate grammar change, never for a new weapon.
- **`motif`** — presentation, **open registry**. A string id into a motif→VFX and motif→SFX table
  read *only* by the presentation layer (`garnish`, `spike_audio`), via a lookup with a safe
  fallback — never a hard `match`. A genuinely new look (charge-up beam, spread cannon) = one new
  registry row + art. No sim, contract, or director change.
- **`tier`** — spectacle scalar (1–3). The existing `ShotGrammar.yield_tier` promoted from a
  `kind`-string lookup to an explicit field. Drives kill-blast, grade, shake — property-based, so
  it never branches per weapon.

The weapon→`(motif, tier, travel)` mapping lives in **weapon definitions** (data, out of scope
here). The sim copies those onto each shot; they are deterministic-but-cosmetic (INV-IMPACT).

### Rhythm is derived, not declared

The director needs no hand-maintained "firing rhythm" enum: it derives rhythm from `travel`. Long
`travel` → anticipation + track-the-projectile + impact beats; `travel: 0` → a single hitscan beat.
One field, not a parallel vocabulary.

## Migration & the gating invariant

The current spike logs and director read the legacy kind-based v1 shape. Graduating to v2 is
**presentation-side churn** and is governed by the same golden hash as all combat-feel work:
**`tests/hybrid_check.gd` must keep printing its golden hash** once logs are regenerated in the v2
shape and the director reads `motif`/`tier`/`outcome` instead of `match fire_*`. If the hash moves,
something leaked. The migration is its own plan step, not part of this design.

The director currently special-cases the literal string `fire_beam` to choose the "first exchange"
over-shoulder and the "killcam-worthy" shot. Those picks must be re-expressed against the structural
fields, not a weapon kind: **first exchange** = the first `shot`/`melee` event; **killcam-worthy** =
`lethal: true` (kill cam) or high `tier` (hero beat). This replacement is the load-bearing part of
the migration — without it a new motif silently loses the over-shoulder/killcam it should inherit.

## Files this contract will touch (at implementation time — not now)

- `scripts/fight_log.gd` — `REQUIRED`/`KINDS` updated to the v2 vocabulary; assert `schema`, the
  root `result`, the `seq` field, and the `shot` payload fields; **assert** `(tick, seq)` canonical
  order rather than re-sorting (INV-ORDER).
- `scripts/director.gd`, `scripts/directors/*.gd`, `scripts/director/grade.gd` — dispatch off
  `kind` + `outcome` + `tier` instead of literal `fire_*` strings.
- `scripts/garnish.gd`, `scripts/spike_audio.gd` — read `motif` through a registry lookup with a
  safe fallback.
- `scripts/director/shot_grammar.gd` — `yield_by_class`/`yield_tier` retired in favour of the
  explicit `tier` field.
- `data/fight_log_*.json` — regenerated in the v2 shape.

## Out of scope / deferred

- **Sim internals** (Backpack-Battles resolution, fire-rate/accuracy/cooldown rules) — next spec.
- **Weapon definitions** and the motif/tier/travel data — backpack spec.
- **FeelProfile** (per-build lean) — separate spec; explicitly not in this per-fight log.
- **`overkill`** and other derivable fields — left out (derive from `damage` vs HP if ever needed);
  YAGNI.
- **Multi-round bursts** (`rounds`/`hits` aggregate, per-round rolls) — deferred; v1 is one resolved
  discharge per `shot`.
- **Per-part / target-node damage** — rejected for v1; combat is whole-mech HP, target is implicitly
  the other actor (no `target_id`). Revisit only if location damage returns.
- **Per-tick position streams** — rejected. Positions stay event-driven (`spawn` + `advance`
  interpolation); the sim emits beats, not frames.
