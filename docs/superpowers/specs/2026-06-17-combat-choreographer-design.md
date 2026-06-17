# Combat Choreographer — staging the combat-truth log for the camera

> Status: DESIGN, approved 2026-06-17. The presentation-layer producer between the sim and the
> director: third link in `build → sim → log → CHOREOGRAPHER → director`. Branch: `combat-feel-restart`.
>
> Targets the contract: `docs/superpowers/specs/2026-06-17-fight-event-log-contract-design.md`
> (the two-layer split — this stage emits the presentation layer). Upstream:
> `docs/superpowers/specs/2026-06-17-combat-sim-internals-design.md`. Consumer: the proven director
> (`scripts/director.gd` + `directors/hybrid.gd`), which already reads `advance` / `_engage` and
> drives `mech_actor`.

## What this is

The sim emits a **positionless** combat-truth log — *who hit whom, when, for how much* — but no
geometry. The director films a 3D scene. The **choreographer is the stage manager between them**: it
places the two mechs and moves them, so there *is* a scene to film. It replaces today's
hand-authored positions in `data/fight_log_*.json`.

It is a **pure function**: `(combat-truth log, presentation seed) → presentation events`, merged
into the log. Deterministic and reproducible, but **not verified** — it is exactly the presentation
layer the contract's INV-VERIFY excludes. Same fight always stages the same way; the staging never
changes who-hit-whom.

**Boundary (three owners, no overlap):**
- **Choreographer** — where the mechs *are* and how they *move* (world staging): `spawn {x,z}` +
  `advance` beats.
- **Director** — where the *camera* is and how it cuts (already built, locked).
- **`mech_actor`** — the *locomotion animation* (walk/strafe/boost/face). The choreographer emits
  high-level "be here by tick T" beats; `mech_actor` executes them.

## Inputs and outputs

- **Reads** (combat-truth): `spawn` (hp), `shot` (`tick`, `actor`, `travel`, `tier`, `outcome`,
  `lethal`, `damage`, `hp_after`), `melee`, `destroyed`, root `result`.
- **Emits** (presentation): `spawn {x,z}` placement, and `advance {to_x, to_y, to_z, end_tick,
  boost}` beats — the shape the director already consumes. Slotted by tick; not part of the verified
  projection (INV-ORDER).
- **Determinism:** a presentation seed derived from the fight seed (`seed ^ PRESENTATION_SALT`)
  drives all randomized staging, using the same pinned uint32 LCG as the sim. Same `(log, seed)` →
  identical presentation events. Reproducible, not verified.

## Position model & event merge

The choreographer keeps its **own deterministic position model** — each mech's path as the sequence
of `(from, to, start_tick, end_tick)` advance beats it has emitted, evaluated by linear interpolation
between targets. This is the choreographer's internal source of truth for "where is the enemy at tick
T," used to place ring targets and to test the in-ring invariant. It need not match the runtime
exactly (the director interpolates and `_engage`-clamps at dispatch); it only needs to be a
self-consistent, deterministic staging model. `_engage` remains a **runtime guard**, not something
the choreography relies on for correctness.

**Merge order.** The output log is the input combat-truth events in their canonical `(tick, seq)`
order, with presentation events (`advance`, and the `{x,z}` fields on `spawn`) inserted at their
tick **after** all truth events of that tick, ordered by actor (`A` before `B`). Presentation
`advance` events do **not** carry `seq` (they are outside the verified projection); the loader keeps
them after truth at equal tick. This is deterministic and makes `_advance_active_at` / runtime
dispatch see a fixed order.

## Hash impact — position-value-neutral, but the golden hash is re-baselined

The director's static shot list (`build_shot_list`, the golden-hash target) does **not** read
position *values* (`to_x/to_z` are runtime-camera-only) — so the choreographer choosing different
*coordinates* is hash-neutral. But `build_shot_list` calls `_advance_active_at`, which reads each
`advance`'s `tick`, `end_tick`, and `actor` to pick `dolly` vs `two_shot` filler. So the **presence,
timing, and actor** of generated `advance` beats *do* feed the shot list. The choreographer's
cadence will differ from the hand-authored logs, so the golden hash **is re-baselined** when staging
is generated — at the same v2 cutover that already re-baselines it for the `fire_beam`→`shot` kind
migration. Net: only `to_x/to_z` are truly hash-neutral; advance *timing* is part of the deliberate,
hash-gated cutover, not a silent leak.

## The movement model — ambient base + a few reactive triggers

### Ambient base (reproduces the proven look)

- **Fixed mirrored spawn:** A at `(-SPAWN_X, 0)`, B at `(+SPAWN_X, 0)` (today's `±40`).
- **Reposition cadence:** every `STRIDE` ticks (~10), each mech gets an `advance` to a new point on
  the **duel ring** — a seeded bearing around the enemy at radius in `[ENGAGE_MIN, ENGAGE_MAX]`
  (34–80). Reads as circling / strafing.
- **Periodic boost:** every `K`-th stride (seeded), the beat is `boost:true` with a small `to_y`
  hop — the airborne dash.

The choreographer produces in-ring targets directly, so the director's `_engage` clamp becomes a
harmless safety guard (left in place; not churned).

### Reactive triggers (layered on the base)

Reading the combat-truth log, these moments adjust the ambient staging. All are **cosmetic** — they
never change a sim outcome (an evade around a shot the sim says *hit* still shows the hit; the weave
is staged around it). A shared guard applies to all three: **skip any actor that is already
`destroyed`**, and read damage fields only where the contract guarantees them.

1. **Boost-evade on an incoming heavy/lethal shot.** Trigger when a `shot` inbound to a mech has
   high `tier` *or* `lethal: true`, **and is not `post_decision`**. Insert an **off-cadence** `boost`
   advance for the target: `tick = impact_tick − travel` (the fire), `end_tick = impact_tick`, so the
   weave spans the whole flight. Skip if `travel` is below a minimum (`EVADE_MIN_TRAVEL` — no room to
   read a dodge) or if `impact_tick − travel` precedes the target's spawn. This is the only place the
   choreographer derives a fire tick. *(Note: this deliberately reacts to **future** truth — the shot
   hasn't landed yet — which is fine for a cinematic-only stage; it is non-causal presentation, not
   sim feedback.)*
2. **Step-back stagger on a heavy hit landing.** Trigger only when `outcome == "hit"`, `damage`
   is present and `≥ STAGGER_DAMAGE` (or high `tier`), and **not `post_decision`**. Insert a short
   knockback `advance` for the struck mech away from the shooter, starting at the impact tick. On a
   `lethal` hit, **suppress** the stagger — the `destroyed` beat owns that tick.
3. **Close the range as HP drops.** A discrete radius bias: when a hit drops a mech's `hp_after`
   below `LOW_HP_FRAC` of its spawn HP, all of that mech's **subsequent** ambient ring targets
   (beats starting after that tick) use a reduced max radius. Not a continuous function and not its
   own beat — just a smaller ring from that hit onward.

Triggers are deterministic functions of the log. Precedence when an evade and a stagger would land
on the same beat: **evade > stagger > ambient**. An evade may insert an off-cadence beat (it is not
limited to overriding the next stride); the next ambient stride resumes after it. Range-tightening
is a standing modifier on the ambient radius and never conflicts.

### Fire timing is derived, not emitted

The choreographer does **not** materialize fire events. `fire_tick = impact_tick − travel` is
derived by the director when it schedules anticipation/track/impact beats (and internally by the
choreographer to time an evade). The presentation layer stays positions-only.

## Parameters

A small staging param set (consts, or a tiny resource if it grows), separate from `ShotGrammar`
(that is camera craft; this is world staging): `SPAWN_X`, `STRIDE`, `ENGAGE_MIN`/`ENGAGE_MAX`,
boost frequency `K`, hop height, and the trigger thresholds: `EVADE_MIN_TRAVEL` (min flight to read
a dodge), the `tier`/`damage` bar for evade & stagger (`STAGGER_DAMAGE`), and `LOW_HP_FRAC` (the HP
fraction below which the ring tightens). Defaults match the proven authored cadence.

## Files (at implementation time — not now)

- New `godot_director_spike/scripts/sim/choreographer.gd` — pure: `(combat-truth events, seed) →
  presentation events`. No scene/render dependencies.
- New `godot_director_spike/tests/choreographer_check.gd` — determinism (same `(log, seed)` →
  identical presentation events), the **in-ring invariant** (every `advance` target within
  `[ENGAGE_MIN, ENGAGE_MAX]` of the enemy's position **in the choreographer's own model** at that
  beat), trigger correctness (evade is an off-cadence beat with `tick = impact−travel`,
  `end_tick = impact`; stagger at the heavy-hit tick and suppressed on a lethal; ring radius reduced
  after a low-HP hit), guard correctness (no movement for a `destroyed` actor; no stagger/evade on
  `post_decision`/miss shots), and **truth pass-through** (combat-truth events emitted unchanged —
  the choreographer only adds).
- Migration: the hand-authored positions in `data/fight_log_*.json` are replaced by choreographer
  output at the **v2 director cutover** (this stage assumes a v2-consuming director — see below);
  `_engage` stays as a runtime guard. The golden hash is re-baselined at that cutover (advance
  cadence feeds the shot list — see "Hash impact").

## Acceptance

- Same `(combat-truth log, seed)` → identical presentation events.
- Every `advance` target lies within the duel ring of the enemy's modeled position at that beat.
- A high-`tier`/`lethal` inbound produces an off-cadence `boost` evade spanning `[impact−travel,
  impact]` (skipped when `travel < EVADE_MIN_TRAVEL`); a heavy non-lethal hit produces a step-back at
  the impact tick (suppressed on a lethal); a low-HP hit reduces that mech's ring radius thereafter.
- A `destroyed` actor gets no further beats; `post_decision`/miss shots trigger no stagger or evade.
- Combat-truth events pass through unchanged (the choreographer adds, never edits) — verified by
  re-projecting the staged log to the outcome projection and matching the input.
- After the v2 director migration, a staged log drives the director with no further code change.

## Out of scope / deferred

- **Fully combat-driven positioning** (continuous aggression/range AI) — deferred; v1 is ambient +
  the three triggers.
- **Terrain/cover interaction** (F18 — movement reacting to buildings) — separate concern; the
  choreographer stages in open space, the director's occlusion handling films around buildings.
- **`mech_actor` locomotion** (how a walk/boost/strafe animates) — already owned by `mech_actor`,
  not redesigned here.
- **Camera / cut decisions** — the director's domain, untouched.
- **Multi-mech / >2 actors** — the duel is 1v1; staging assumes two actors.
