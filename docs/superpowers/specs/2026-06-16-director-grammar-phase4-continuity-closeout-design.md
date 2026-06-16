# Director Grammar Phase 4 — Soft Continuity Closeout (F34 + F35)

> Status: DESIGN, approved 2026-06-16. Closes the Continuity dimension (F32–F36) of the
> Director Grammar. Authoritative parent spec:
> `docs/superpowers/specs/2026-06-16-director-grammar-design.md` (Continuity §, F32–F36).
> Branch: `combat-feel-restart`.

## Why this is small

Phase 4 sounded like a whole dimension, but the load-bearing parts already shipped:

- **F32 `axis_of_action`** — shipped. `director.gd._axis_side` plus `_axis_keyed_side` (keyed at
  fight start): perspective cut-ins are placed on one side of the A↔B line.
- **F33 `screen_direction`** — shipped. `director.gd._keyed_lateral` fixes each cut-in's lateral
  sign to the keyed side, so the two mechs never swap screen sides across a cut. `continuity_check.gd`
  covers the helpers at unit level.

So this phase produces **no visible change**. It is two things only:

1. **F35 `coherence_over_polish`** — a regression guard in the headless test runner that locks the
   screen-direction invariant against future camera changes. This is the only new code.
2. **F34 `establishing_layout`** — formalization (documentation) of a structure that already exists
   and is already tested. No new code path.

**F36 `split_screen`** is explicitly deferred (YAGNI): nothing in the single-duel showcase needs
parallel simultaneous action.

## The invariant that gates everything

Same as every camera/render change this line of work: the combat sim is pure/deterministic and the
hybrid shot list is frozen by a golden hash. **`tests/hybrid_check.gd` must keep printing
`got hash 2543717900`.** Everything here is presentation-side (a code-dedup refactor with identical
behavior, plus a new test) and must hold that hash.

## F35 — the coherence guard

### What it protects

In the fight, mech A and mech B each hold a persistent screen side (e.g. A frame-left, B
frame-right). When the camera cuts from the iso wide into a `hero_os` / `hero_cut` close shot, the
cut must keep them on those sides — flipping them disorients the viewer (the classic 180° / axis
break). That behavior works today, but only because the inline candidate-pose math in `hybrid.gd`
is written correctly. There is no test that fails if a future edit breaks it; the only signal would
be a human noticing a fight "feels wrong."

### Why a pure-helper guard (and what it rejects)

The whole existing check suite is pure and headless. The handoff explicitly flags driving the
hybrid director through a live headless fight as unreliable (no render server; global shader params
unqueryable in a `-s` run). So the guard tests the **real pose-selection path** by extracting it
into a pure static function, rather than running a live director.

Rejected alternatives:
- *Integration guard* (drive the director through a headless fight, sample poses per frame): higher
  fidelity, but needs a live `SceneTree` + actors and is flagged as flaky. Not worth it here.
- *Extend `continuity_check` with more sampled configs*: only re-tests `_axis_side`/`_keyed_lateral`
  in isolation — not the actual candidate generation the runtime uses. Doesn't catch a regression
  in how `hybrid.gd` builds its candidate poses.

### The refactor (behavior-preserving)

`hero_os` and `hero_cut` in `hybrid.gd` generate their candidate camera poses with **identical**
code (today: lines ~128–130 and ~145–147):

```gdscript
var cands := []
for scale in [0.6, 0.85, 1.0, 1.3, 1.7]:
    cands.append(f.position - d * fr.pullback
        + d.cross(Vector3.UP) * (lat * float(scale))
        + Vector3(0, fr.height, 0))
```

Extract this into a pure static helper on `director.gd`:

```gdscript
## The keyed-side candidate camera poses for a hero cut-in: the shooter position
## pulled back along the firing line, raised, and offset laterally by scaled
## multiples of the keyed lateral. All candidates share the keyed lateral sign,
## so every one lands on the same (keyed) side of the A<->B axis.
static func _hero_candidates(f_pos: Vector3, o_pos: Vector3, pullback: float,
        height: float, lateral_signed: float) -> Array:
    var d := (o_pos - f_pos).normalized()
    var out: Array = []
    for scale in [0.6, 0.85, 1.0, 1.3, 1.7]:
        out.append(f_pos - d * pullback
            + d.cross(Vector3.UP) * (lateral_signed * float(scale))
            + Vector3(0, height, 0))
    return out
```

Both branches call it with the already-keyed `lat` (from `_keyed_lateral`). Behavior is byte-for-byte
identical — `hybrid_check`'s golden hash and the visual must be unchanged.

`melee_cut` is intentionally **not** part of this: it orbits the clash point by angle offsets and may
sit on either side of the axis (both mechs share one tight frame at contact, so the keyed-side rule
does not apply). The guard does not assert anything about melee poses.

### The test — `tests/coherence_check.gd` (new, headless, pure)

Mirrors the structure of `continuity_check.gd`. For a sample matrix of fight geometries (varied A/B
positions and both keyed sides `+1` / `-1`) and a few building layouts:

1. Compute the keyed lateral with `_keyed_lateral` for the geometry + keyed side.
2. Build candidates with `_hero_candidates`.
3. **Assert (a):** every candidate lands on the keyed side — `_axis_side(candidate, a, b) == keyed_side`
   for all five.
4. **Assert (b):** the pose `_pick_clear_pose(candidates, aim, buildings, prev_idx, margin)` selects
   is on the keyed side — i.e. the occlusion search can never pull the camera across the axis, no
   matter which building layout it is dodging.

This is the "line/side check added to the test runner" the parent spec calls for. Added to the
standard suite run alongside the existing checks.

## F34 — establishing layout (formalization only)

The iso/ortho backbone already *is* the establishing layout: the fight opens on the iso wide, closes
on `iso_aftermath`, and the iso base returns between intercuts to re-anchor geography. `hybrid_check.gd`
already asserts all three ("opens on the isometric base view", "closes on the iso aftermath read",
"iso base returns between the intercuts").

Formalizing means making the intent explicit in the code/docs, not adding behavior:
- A short comment in `hybrid.gd` (at the iso shot handling) naming the iso backbone as the F34
  establishing / re-establishing layout that fixes geography.
- This design doc records that the three existing `hybrid_check` assertions *are* the F34 coverage
  (open = establish, between-intercuts = re-establish, aftermath = final establish). No new test.

## Files touched

- `godot_director_spike/scripts/director.gd` — add the `_hero_candidates` static helper.
- `godot_director_spike/scripts/directors/hybrid.gd` — `hero_os` + `hero_cut` call the helper
  (dedup); add the F34 establishing-layout comment.
- `godot_director_spike/tests/coherence_check.gd` — new headless guard.

## Acceptance

- `hybrid_check.gd` still prints `got hash 2543717900` (behavior-preserving refactor).
- `coherence_check.gd` is green: all hero candidates and the picked pose are keyed-side across the
  sampled geometries and building layouts.
- Full suite green: `shot_grammar_check`, `grade_check`, `time_emphasis_check`, `continuity_check`,
  `coherence_check`, `sightline_check`, `hybrid_check`, `director_check`, and the variant checks.
- A live `--director=hybrid --log=fight_log_everything --armor` run looks identical to before
  (no visible change is the intended outcome).

## Out of scope / deferred

- **F36 `split_screen`** — parallel simultaneous-action primitive; deferred (YAGNI).
- The parked camera-search items remain parked (not part of this closeout): the angle-search **iso
  fallback** (cut to iso when no clear same-side pose exists), and the **melee radius/height** search
  extension. Tracked in `2026-06-16-director-grammar-phase3-scope-and-deferred-items.md`.
