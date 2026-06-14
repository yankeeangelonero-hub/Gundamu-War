# KM-M0-SIM — Build→Fight Sim Core — Feature Specification

Spec ID: KM-M0-SIM
Date: 2026-06-14
Owner: Xuanyue
Branch: backpack-system-test
Status: Implemented 2026-06-14. build_fight_sim.gd + opponent_source.gd + data/ghost_builds.json
+ event-contract `overload` kind; tests/build_fight_sim_check.gd passes all §6 checks (21/21);
M1 + director checks unaffected. KM-M0-VIEWER (playback wiring) is the remaining M0 slice.
Parent: docs/superpowers/specs/2026-06-14-m0-build-fight-sim-high-level-spec-and-work-map.md
Consumes (M1, implemented): scripts/build/build_resolver.gd, build_mounts.gd, build_grid.gd,
build_data.gd; data/build_items.json.
Renderer contract: godot_director_spike/data/event-contract.md.

## 0. Parent change proposals

None. The one new event kind this spec emits (`overload`) is pre-authorized by root §6
ALW-M0-1. The base-HP and sudden-death parameters are pre-authorized by ALW-M0-4. The opponent
stub is folded into this slice per the owner's instruction at root approval.

## 1. Overview

This feature is the deterministic core of the M0 fight: a pure function that takes two resolved
backpack builds and a seed and produces the event log the proven combat viewer plays. It owns
the per-tick power-battery economy, weapon firing, damage, the sudden-death overload, and a
small seeded opponent source so there is a real build to fight.

It is renderer-agnostic: no Godot nodes, no camera, no colours. Its only output is an ordered
event array in the existing `km-director-spike-fight-log-v1` schema plus one additive `overload`
kind. The same {buildA, buildB, seed} always produces the identical array.

What this slice does NOT do: play the fight in the viewer or wire DEPLOY to it (that is
KM-M0-VIEWER). This slice ends at "a correct, deterministic, viewer-loadable log is produced and
checked headless."

## 2. Vocabulary

- **tick / tick_seconds** — integer simulation step; `tick_seconds = 0.1` (matches the contract).
- **resolved build** — the per-side input the sim consumes (see §5): `hp`, `pool`, `regen`, and
  a `weapons` list of `{ id, damage, cost, cadence, mount }`.
- **pool / power / regen** — `pool` is the battery capacity; `power` is the current charge,
  refilled by `regen` per second up to `pool`.
- **cadence** — seconds a weapon waits between shots (from its def).
- **cooldown+cost gate** — a weapon fires only when its cadence has elapsed AND `power ≥ cost`.
- **power-starved** — a build whose weapons collectively demand more power than `regen` sustains;
  some weapons sit idle waiting for charge.
- **sudden death / overload** — after `sudden_death_tick`, an exponentially escalating
  damage-over-time applied to both sides until one dies.
- **ghost build** — an opponent build served by the opponent source.
- **event log** — the ordered `{tick, actor, kind, payload}` array.

## 3. User-facing behavior

There is no direct UI in this slice — the "user" is the build screen (later) and the headless
checks (now). The observable behavior is the *fight that the log describes*:

When a fight is simulated:

- Both mechs spawn at full HP (A on the left, B on the right), reactors full.
- Each weapon fires as soon as its cadence has elapsed and the reactor has enough power for its
  effective cost. Firing drains that cost from the pool and deals the weapon's effective damage
  to the enemy. The reactor refills steadily at its regen rate.
- A build that mounted more or hungrier guns than its reactor can feed **visibly fires fewer
  shots**: starved weapons skip their turn and wait, leaving gaps in that side's fire events
  while its pool sits near empty. A lean, well-fed build fires steadily.
- The first mech whose HP reaches 0 is destroyed; the shot that did it is marked lethal, and the
  fight ends. Everything after the terminal event is epilogue.
- If neither mech has died by the sudden-death time, a reactor **overload** begins: every tick
  both mechs take overload damage that grows exponentially, so within a couple of seconds one
  mech dies. The mech that built better effective survivability (more HP headroom / better
  sustain, so it entered overload less hurt) outlasts the other. No fight stalls.

Determinism: simulating the same two builds with the same seed always yields the identical
sequence of events. Outcomes are RNG-free (every weapon shot hits for its full effective damage)
so underperformance reads as an engineering choice, never as luck (CON-D05). The seed threads
through for reproducibility and any future stochastic/cosmetic use; it does not change combat
outcomes in M0.

## 4. Surfaces and controls

New code, all under `godot_director_spike/`:

- `scripts/build/build_fight_sim.gd` — the pure sim. Static entry
  `simulate(build_a: Dictionary, build_b: Dictionary, seed: int) -> Array` returning the event
  log. No node tree.
- `scripts/build/opponent_source.gd` — the KM-OPP source. `get_ghost(index_or_seed) -> Dictionary`
  returns a *placement* (an array of `{def_id, rot, anchor}`) drawn from the ghost pool; a helper
  resolves a placement to a resolved build via the M1 resolver + mount cascade so the sim consumes
  it identically to the player's build.
- `data/ghost_builds.json` — the static ghost pool (placements as data, per CON-D06).
- `tests/build_fight_sim_check.gd` — headless determinism, termination, power-starvation, and
  schema-compatibility checks.

Additive change to the existing contract doc `data/event-contract.md`: document the `overload`
kind (this spec does not change any existing kind).

No build-screen, scene, camera, or director changes in this slice.

## 5. Data, API, and integration notes

### Resolved-build input shape (the sim's per-side input)

```
{
  "hp": float,            # base HP at spawn (default 100.0)
  "pool": float,          # reactor capacity = BuildResolver totals.pool
  "regen": float,         # power per second = BuildResolver totals.regen
  "weapons": [            # one per spender, in mount-assignment order
    { "id": String,       # the placed item's iid (stable label)
      "damage": float,    # effective_damage from BuildResolver
      "cost": float,      # effective_cost from BuildResolver
      "cadence": float,   # seconds between shots, from the def
      "mount": String }   # hardpoint from BuildMounts.assign (presentation only)
  ]
}
```

Building this shape from a placement (used by the opponent source now, and the build screen in
KM-M0-VIEWER): run `BuildResolver.resolve(placed)` for `pool`/`regen` and each weapon's
`damage`/`cost`; read `cadence` from `BuildData.get_def`; run `BuildMounts.assign(placed)` for
`mount`; set `hp` to the default base HP. A weapon with no reactor in the build still has a
`cost`; if `pool` is 0 it simply never fires (a legible dead build).

### Tunable constants (data/consts in the sim; defaults from root §12 OQ-M0-1)

- `TICK_SECONDS = 0.1`
- `BASE_HP = 100.0`
- `SUDDEN_DEATH_TICK = 450` (45 s)
- `OVERLOAD_BASE = 1.0`, `OVERLOAD_GROWTH = 1.12` (per tick after sudden death)
- `MAX_TICKS = 3000` (safety cap; the overload must end the fight well before this)

### The per-tick algorithm (deterministic)

1. **Setup.** For each side: `power = pool`, `hp = base_hp`, every weapon `next_fire_tick = 0`.
   Emit `spawn` for A `{x: -40, hp}` and B `{x: +40, hp}` at tick 0 (positions match the combat
   scene's spawn). Emit a small fixed set of cosmetic `advance` events so the mechs are not frozen
   (e.g. each closes partway to mid-field over the first ~1.5 s); these are presentation
   scaffolding, fully determined, and carry no combat meaning.
2. **Per tick, in fixed actor order [A, B]:**
   a. `power = min(pool, power + regen * TICK_SECONDS)`.
   b. For each weapon in order, if `tick >= next_fire_tick`:
      - if `power >= cost`: `power -= cost`; `enemy.hp -= damage`; `lethal = enemy.hp <= 0`;
        emit `fire_beam {actor, hit: true, damage, hp_after: max(0, enemy.hp), lethal,
        overkill: max(0, -enemy.hp)}`; set `next_fire_tick = tick + round(cadence / TICK_SECONDS)`.
        If `lethal`: emit `destroyed {actor: enemy}` and STOP the whole sim.
      - else (power-starved): do nothing — the weapon stays due and retries next tick (this is
        the visible idle gun; `next_fire_tick` is not advanced).
   c. After both actors act, if `tick >= SUDDEN_DEATH_TICK`: compute
      `dot = OVERLOAD_BASE * pow(OVERLOAD_GROWTH, tick - SUDDEN_DEATH_TICK)`; for each side in
      order [A, B] apply `hp -= dot`, emit `overload {actor, damage: dot, hp_after: max(0, hp),
      lethal: hp <= 0}`; if that side died, emit `destroyed {actor: side}` and STOP.
3. **Stop conditions.** Exactly one `destroyed` ends the sim. `MAX_TICKS` is a safety backstop
   that should never trigger (assert/log if it does).

Tie-breaks are deterministic by the fixed [A, B] processing order: on a tick where both could
reach 0, A acts first, so A wins simultaneous exchanges. (The player will be side A.)

### Event kinds emitted

`spawn`, `advance` (cosmetic only), `fire_beam`, `overload` (new), `destroyed`. `fire_burst` is
out of scope for M0 — every weapon shot is a single `fire_beam`.

### New contract kind to document in `data/event-contract.md`

| kind | payload | notes |
|---|---|---|
| `overload` | `damage`, `hp_after`, `lethal` | sudden-death reactor-overload self-damage; `actor` is the mech taking it; escalates each tick after `SUDDEN_DEATH_TICK` |

### Opponent source (KM-OPP)

`opponent_source.gd` exposes `get_ghost(pick: int) -> Array` returning a placement from
`ghost_builds.json` (a few hand-authored builds: e.g. a lean go-wide gunline, a hungry go-tall
cannon, a slow tank-ish reactor brick). Selection is deterministic from `pick` (e.g. seed modulo
pool size). The source returns only a build; it knows nothing of provenance (CON-D03), so the
same interface later serves designer or real-player ghosts unchanged.

## 6. Acceptance checks

Headless, in `tests/build_fight_sim_check.gd` (same SceneTree pattern as the other checks):

1. **Determinism.** `simulate(A, B, seed)` called twice returns arrays of equal length with
   identical `{tick, actor, kind, payload}` at every index. (GATE-M0-1)
2. **Single terminal.** Every simulated fight contains exactly one `destroyed` event, preceded by
   a `lethal` event (a `fire_beam` or `overload` with `lethal: true`), and no events for any
   actor after that actor is destroyed. (INV-M0-3)
3. **Termination via overload.** Two deliberately even, durable builds reach a `destroyed` within
   `MAX_TICKS`, and the killing event is an `overload` with `lethal: true` at a tick
   `>= SUDDEN_DEATH_TICK`. (GATE-M0-2, INV-M0-6)
4. **Power-starvation bites.** For a build whose summed `cost/cadence` exceeds `regen`, the count
   of its `fire_beam` events over a fixed window is strictly less than the count produced by the
   same build given effectively unlimited `pool`/`regen`. The economy demonstrably limits fire.
   (GATE-M0-3, INV-M0-5)
5. **Reactor matters.** A build with a reactor fires more total shots before sudden death than the
   identical weapons with `pool = regen = 0` (which fire zero). Confirms power gating.
6. **Schema compatibility.** A sim-produced log is accepted by the existing renderer contract:
   `FightLog.duration_sec(events)` returns the last tick's seconds, and
   `Hybrid.build_shot_list(events, dur)` returns a non-empty shot list without error. (Surfaces,
   for KM-M0-VIEWER, whether the director needs `overload`/lethal-any handling — but this check
   only requires no crash and ≥1 shot.)
7. **Opponent source.** `get_ghost` returns a placement that resolves (via the M1 resolver +
   mounts) to a valid resolved build the sim runs to a clean terminal; two different `pick` values
   yield different builds. (GATE-M0-6)
8. **Non-regression.** The existing M1 and director/combat headless checks still pass unchanged.

Manual/visual acceptance (a power-starved mech going visibly quiet, the overload finish) is part
of KM-M0-VIEWER, not this slice.

## 7. Out of scope

- Playing the fight in the viewer and wiring DEPLOY to it (KM-M0-VIEWER).
- Spatial gameplay: ranges, approach/retreat as mechanics, melee/saber, blocks, dodges. M0
  movement is cosmetic `advance` scaffolding only.
- `fire_burst` emission (single `fire_beam` per shot in M0).
- Armor / HP multipliers and the tank vector's defensive math (M2). Base HP is a flat constant.
- The shop, gauntlet, lives, gold, bag expansions, recipes, pilot unique items (M2/M3).
- Any backend, persistence, or networked opponent (root ARC-M0-4).

## 8. Open questions

- OQ-1 (non-blocking) — Exact tuning of `BASE_HP`, `SUDDEN_DEATH_TICK`, `OVERLOAD_BASE/GROWTH`
  and the cosmetic advance choreography. Defaults in §5 are safe starting values; tune in play
  during/after KM-M0-VIEWER.
- OQ-2 (non-blocking) — Whether `overload` damage should scale with elapsed time only (current
  design) or also with how power-starved a mech is (thematic "reactor overloads because it's
  pushed"). Default: time-only, simplest and legible. Revisit if the finish feels arbitrary.

No blocking questions.

## 9. Spec self-check

- [x] §0 present; no parent change proposals (overload + params pre-authorized by parent §6/§4 —
  verified against the root spec file).
- [x] Behavior is concrete and user-action/event ordered (§3, §5 algorithm).
- [x] Input shape fully specified so the builder need not invent it (§5), sourced from the
  implemented M1 `BuildResolver`/`BuildMounts`/`BuildData` (verified in repo).
- [x] Output schema cited against `data/event-contract.md` (verified in repo); the one new kind is
  tabled explicitly.
- [x] Acceptance checks are concrete and testable headless (§6), mapped to parent GATE/INV IDs.
- [x] Out-of-scope explicit (§7) so the builder doesn't drift into VIEWER/M2/M3.
- [x] Must-not-touch inherited from parent §18 (combat feel, MechActor combat path, M1 math) —
  this slice adds only new files + an additive contract-doc entry.
- [x] Open questions are non-blocking tuning only (§8).
- [x] Haiku-buildable: a builder can implement the algorithm, data shapes, and tests without
  deciding product intent, ownership, or acceptance criteria.
