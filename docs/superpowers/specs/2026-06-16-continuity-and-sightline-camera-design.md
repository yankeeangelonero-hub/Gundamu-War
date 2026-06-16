# Continuity-Aware Sightline Camera — Design (Phase 4 + Occlusion/Composition)

> Status: APPROVED design (owner, 2026-06-16). **Supersedes**
> `docs/superpowers/specs/2026-06-16-sightline-aware-camera-composition-occlusion-design.md` — that
> spec's occlusion + composition design is folded in here, now unified with the Director Grammar's
> Phase 4 continuity constraints (F32–F36), because both gate the same camera-pose-selection step.
> Director Grammar line; pairs with `docs/superpowers/specs/2026-06-16-director-grammar-design.md`
> (Continuity §, Composition §). Determinism gate: shot-list hash `2543717900` unchanged.

## Why combined
Phase 4 (continuity: stay on the right side of the 180° line, hold each mech's screen side) and the
sightline work (pick an occlusion-clear pose, fade true occluders) both modify **which camera pose a
perspective cut takes**. Building them separately would touch the same pose code twice and risk one
undoing the other. This spec defines **one pose-selection layer** that satisfies both: it searches for
the clearest pose **on the keyed side of the axis**, falling back to the iso backbone when no
same-side pose works, then precisely fades whatever still occludes.

## Problem recap
- **Occlusion:** the perspective close/medium cuts get buried — a foreground building fills the frame
  (observed `fight_log_melee` frame 07). Current handling is blind (camera ignores building layout)
  and weak (thin-center-line test, gradual fade to a still-visible 0.1).
- **Continuity:** the cut-ins are placed with no cross-cut consistency — the pose formula's
  `d.cross(UP)*lateral` term is always positive, so when a cut's *focus* switches mechs the camera
  flips to the other side of the axis and the two mechs **swap screen sides** (the "jump the line"
  error). Nothing keys a persistent screen direction.

## Goals
1. **Screen direction (F33):** each mech keyed a persistent screen side at fight start, held across all
   cut-ins.
2. **Axis of action / 180° (F32):** cut-in poses stay on the keyed side of the A↔B line — never swap
   the mechs' sides on a cut.
3. **Composition search:** within each shot's identity, bias the pose toward a **clear sightline** to
   the subject (occlusion-aware), bounded (no free flight / bounce).
4. **Precise occlusion fade:** fade **only the true silhouette occluders**, fully out, quickly &
   smoothly (~0.1s); never a corridor, never a hard snap; surrounding city untouched.
5. **Coherence over polish (F35):** when continuity and a clear shot conflict, continuity wins — use
   the iso fallback rather than cross the line. Plus a line/side check in the test runner.
6. Preserve determinism (AABB math only, presentation-only) and the shot list (hash unchanged).

## Non-goals (YAGNI / scope)
- No physics colliders / physics raycasts (buildings are boxes; ray-vs-AABB is exact + deterministic).
- No screen-space-projection occlusion (heavier, behind-camera edge cases).
- No hard camera-solver rebuild — continuity is a **soft constraint on placement** (flip-safe + iso
  fallback), the proven camera math stays.
- **`split_screen` (F36)** — deferred (optional parallel-action primitive; not in v1).
- No change to the `iso`/`iso_aftermath` backbone except its role as the established geography
  (F34 — already does this) and the safe fallback target.

## Architecture

### Shared sightline test (pure)
`scripts/director/sightline.gd` — `static func evaluate(cam_pos, subject_points, buildings) ->
{clear_count:int, occluders:Array}`. Casts one ray cam→each subject silhouette sample point
(`feet/torso/head/L+R shoulder`; for `melee_cut` sampled around the clash), tests each against the
building AABBs (exact for boxes). `clear_count` scores a pose; `occluders` is the set to fade. Pure,
deterministic, unit-testable. Drives **both** the composition search and the fade.

### Screen direction + axis (new, on the director)
- At fight start (`start(...)`): key `screen_side` per mech from initial world-X — the lower-X mech is
  screen-left, the other screen-right. Stored on the director, immutable for the fight.
- The **axis** is the A↔B line (`a.position`, `b.position`), recomputed per frame. A candidate pose is
  "on the keyed side" iff the focus mech projects to its keyed half — determined by the sign of
  `(o.position - f.position).cross(UP) · (cam_pos - mid)` (the existing `lateral` cross term). The
  pose's lateral sign is **chosen from the keyed direction + which mech is the focus**, replacing the
  always-positive literal.

### The pick — unified pose selection (applies to the **cut-in** shots: `hero_os`, `hero_cut`)
1. Generate a small candidate set by perturbing the shot's free parameter (lateral/pullback) within
   `composition_search_arc`, **constrained to the keyed side** (the lateral sign is fixed to the keyed
   side; candidates vary magnitude/pullback/height, never crossing the axis).
2. Score each via `sightline.evaluate`.
3. Pick the highest `clear_count`, tie-broken toward the authored pose; **hysteresis** holds the
   current pick unless a candidate beats it by ≥ 2 clear rays (no jitter).
4. **Fallback:** if the best same-side candidate's `clear_count` is below `iso_fallback_min_clear`
   (a tunable; start = 2 of ~5), the director **substitutes the iso backbone** pose for this beat
   rather than cross the line — coherence over polish.

### Orbits (`melee_cut`, `bullet_time`) — sightline only, no hard side rule
The 180° rule governs **cuts**, not continuous moves. The orbits are continuous camera motion the eye
tracks; crossing the axis mid-orbit is correct and intended. So orbits get the **composition bias**
(perturb the orbit *angle* toward higher `clear_count`, with hysteresis) and the **precise fade**, but
**not** the keyed-side constraint and **not** the iso fallback (an orbit is its own shot). This keeps
their motion intact.

### Hide (all perspective shots)
After the final pose is set, run `sightline.evaluate` from it; the returned `occluders` fade alpha to
**0** over `occlusion_fade_time` (~0.1s, fast+smooth), restoring at the same rate when clear. Replaces
the thin-line `_resolve_occlusion`. Precise occluders only — no corridor.

### Establishing layout (F34) + coherence check (F35)
`establishing_layout` is the existing `iso`/ortho backbone (geography-fixing) — no new code, just
named as such. `coherence_over_polish` is realized by the conflict rule (continuity wins) **plus** a
new **line/side assertion in the test runner**.

## Components / files
- **Create** `scripts/director/sightline.gd` (+uid) — pure `evaluate(...)`.
- **Create** `tests/sightline_check.gd` — multi-ray occlusion unit test (clear line / dead-center /
  off-center-shoulder occluder) + the pose-picker chooses the clearest same-side candidate + hysteresis.
- **Create** `tests/continuity_check.gd` — the line/side check: given keyed screen directions and a set
  of cut-in poses (or a fight log run), assert no cut-in places the camera on the wrong side of the
  axis (mechs never swap sides on a cut).
- **Modify** `scripts/director.gd` — key `screen_side` in `start()`; add `_pick_clear_pose(...)`
  (candidate scoring + hysteresis + iso-fallback signal); replace `_resolve_occlusion` body with the
  sightline fade; `_fade_building` gains the fast/full path (`occlusion_fade_time`); a `_subject_points(focus, mode)` helper.
- **Modify** `scripts/directors/hybrid.gd` — cut-ins (`hero_os`/`hero_cut`) constrain to the keyed side
  + run the pick (+ iso fallback); orbits (`melee_cut`/`bullet_time`) run the sightline composition
  bias + fade (no side rule). `iso` unchanged.
- **Modify** `scripts/director/shot_grammar.gd` — add `occlusion_fade_time` (~0.1), `composition_search_arc`,
  `iso_fallback_min_clear` (~2). Assert defaults in `shot_grammar_check.gd`.

## Determinism
All AABB math; no physics, no RNG. Screen-side key + axis + pose choice derive only from deterministic
mech/building state and are presentation-only — never fed to the sim or the shot list. Hash
`2543717900` must hold (regression gate).

## Testing
- **`sightline_check.gd`** — known geometry → expected occluders + clear_count (clear / dead-center /
  off-center-shoulder); `_pick_clear_pose` picks the higher-clear same-side candidate; hysteresis
  holds on a small margin.
- **`continuity_check.gd`** — keyed directions + cut-in poses → assert all cut-ins are on the correct
  side (no side-swap); the iso fallback triggers when same-side clear_count is below threshold.
- **Regression:** full headless suite + `hybrid_check.gd` hash `2543717900` unchanged.
- **Visual (owner-gated windowed):** `fight_log_melee` + `fight_log_everything` `--frames` — close-ups
  read clean (no building filling the frame), city intact, mechs hold their screen sides across the
  hero cut-ins, no camera bounce/jitter, orbits still orbit.

## Open questions for the implementation plan
1. `composition_search_arc` units differ per family (radians for orbit angle vs world-units for hero
   lateral/pullback) — a small per-family constant table vs one normalized strength. Lean: per-family
   table; revisit if tuning needs it.
2. Candidate count (3 vs 5), hysteresis margin (≥2 rays), and `iso_fallback_min_clear` (2 of 5) are
   starting values to tune from the capture; expose only if needed.
3. Subject silhouette sample set per shot (single focus mech for hero cuts vs both mechs at the clash
   for `melee_cut`) — a shared `_subject_points(focus, mode)` helper; confirm the points per mode.
4. Sequencing: likely two slices — (A) screen-direction + axis + the keyed-side pose + continuity test
   (Phase 4 core), (B) the sightline module + composition search + precise fade + iso fallback
   (occlusion). They share `_pick_clear_pose`; build A's keyed-side gating first, then B layers the
   clear-score + fade onto the same candidate pipeline. The plan decides the exact split.
