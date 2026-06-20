# Handoff — Combat Choreographer: pure staging function (cf-choreographer)

Branch: `combat-feel-restart`. All work **uncommitted**, ready for review and commit.
Slice: roadmap node `cf-choreographer`. Design: `docs/superpowers/specs/2026-06-17-combat-choreographer-design.md`.

## What this slice is

The choreographer is the stage manager in `build → sim → log → CHOREOGRAPHER → director`. The sim
emits a **positionless** combat-truth log (who hit whom, when, for how much); the director films a 3D
scene. The choreographer is the pure function between them — it decides where the two mechs *are* and
how they *move*, so there is a scene to film. It replaces the hand-authored positions in
`data/fight_log_*.json`.

It is `stage(truth_events, seed) → merged log`: deterministic, reproducible, and **never verified** —
exactly the presentation layer the contract's INV-VERIFY excludes. It only *adds* (spawn `{x,z}` +
`advance` beats); combat-truth passes through untouched.

## What landed (2 files, TDD, 39 assertions green)

- **`godot_director_spike/scripts/sim/choreographer.gd`** — pure, no scene/render deps:
  - **Ambient base:** fixed mirrored spawn (A at `-40`, B at `+40`); a `STRIDE`-tick (10) reposition
    cadence onto the duel ring (`ENGAGE_MIN..MAX` = 34..80) around the enemy's modeled position; a
    periodic boost hop (`to_y`) every `BOOST_EVERY`-th stride.
  - **Three reactive triggers** read off the truth log: **boost-evade** on an incoming heavy
    (`tier ≥ 3`) or `lethal` *hit*, spanning `[impact−travel, impact]`, skipped when
    `travel < EVADE_MIN_TRAVEL`; **step-back stagger** on a heavy non-lethal hit at the impact tick,
    suppressed on a lethal hit; **ring-tighten** — after a hit drops a mech below `LOW_HP_FRAC` (0.35)
    of spawn HP, its later ambient strides use a reduced outer radius.
  - **Guards:** a destroyed mech gets no further beats; `post_decision`/miss shots stage no reaction;
    damage read only where the contract guarantees it.
  - **Pinned uint32 LCG** + order-independent per-beat hash RNG (`seed ^ PRESENTATION_SALT`). The sim
    (m0) will reuse this LCG family.
  - **`position_at(events, actor, tick)`** — the choreographer's own layered position model
    (latest-started-beat wins on overlap; precedence evade > stagger > ambient). Single source of
    truth for the in-ring invariant and the trace.
  - **`movement_trace(events) → [{tick, actor, x, y, z, dist_to_enemy, speed, bearing_deg, boost}]`**
    — per-tick, per-mech resample for comparing the technical cinematography quality of different
    builds/seeds (requested addition). Pure; `x/z` always agree with `position_at`.
- **`godot_director_spike/tests/choreographer_check.gd`** — two fixtures: an ambient-only duel
  (Cycle 1) and a reactive duel exercising each trigger + guard in isolation (Cycle 2).

## Key implementation decision

Every beat (ambient + reactive) is realized in **nondecreasing start-tick order against the model
already built**. A later beat never perturbs an earlier tick's position, and a beat's `from` only
sees earlier-started beats — so the **in-ring invariant holds by construction** for *every* beat
(reactive included), and cross-actor placement stays consistent (when A places a beat at tick T, B's
own reactive beats with start ≤ T are already realized). This is why the in-ring check passes for
evade/stagger and not just ambient.

## How to run

```
cd godot_director_spike
godot --headless --path . --script res://tests/choreographer_check.gd   # 39 PASS
```
Godot 4.6.3 stable. Test harness is the project's `extends SceneTree` check pattern.

## Scope boundary — what is NOT done

The pure stage is built and tested; it is **not yet wired into the director**. The v2 director cutover
is a deliberate, separate, golden-hash-gated migration (it depends on `m0-sim` emitting real v2 logs):
regenerate `data/fight_log_*.json` from `stage()`, switch the director/garnish/grade dispatch off
`kind`+`tier`+`outcome` instead of literal `fire_*`, retire `fight_log.gd`'s v1 vocabulary, and
**re-baseline** `hybrid_check.gd`'s golden hash (advance *cadence* feeds the shot list). Because the
choreographer is pure and unwired, the director golden hash is **unchanged** (`2543717900`) and
`director_check` is green — verified this slice introduced no regression.

## Roadmap

`cf-choreographer` is advanced but not closed: its `doneWhen` ("a contract-valid log staged into
positions the director *films*") only fully closes after the v2 cutover above. On commit, set the node
to `in-progress` (not `shipped`) and re-run `python -m roadmap_tree . --sync`.

## Suggested next

1. Commit this slice.
2. **v2 director cutover** (the migration above) — the step that actually feeds `stage()` to the
   director, with the golden-hash re-baseline as the gate.
3. **`cf-feel-consumers`** — bias the ambient ring radius / boost cadence by each build's `FeelProfile`
   so a gun-heavy loadout films differently from a melee one. `movement_trace` is the before/after
   measuring stick for that.

## Note

Every Bash call from inside `godot_director_spike/` prints a harmless `roadmap_sync.py` "No such file"
error — the post-commit hook resolves its path relative to cwd and only matters at the repo root on
`git commit`. Worth fixing the hook to an absolute path.
