# Sightline-Aware Camera: Composition + Precise Occlusion — Design

> Status: **SUPERSEDED** (2026-06-16) by
> `docs/superpowers/specs/2026-06-16-continuity-and-sightline-camera-design.md`, which folds this
> spec's occlusion + composition design into the unified continuity-aware pose-selection layer
> (Phase 4 + occlusion together). Kept for history; do not implement from this file.
>
> Status (original): APPROVED design (owner, 2026-06-16). Successor to the reverted Phase 3 Slice 3 melee
> occlusion experiment (which hard-snapped a wide corridor and emptied the scene, breaking the battle
> choreography). Part of the Director Grammar line; pairs with the spec
> `docs/superpowers/specs/2026-06-16-director-grammar-design.md` (Composition F6/F4 + the occlusion
> assertion). Determinism gate: the golden shot-list hash `2543717900` must stay unchanged.

## Problem
In the free-roaming destructible city, the perspective close/medium cuts get **buried**: a foreground
building drops between the lens and the mech and fills the frame (observed on `fight_log_melee`,
frame 07). The current handling is too weak and too blind:
- The camera solve is **blind to building layout** — e.g. `melee_cut` orbits the clash on a purely
  time-driven angle (`ang = PI*0.25 + _wall*0.6`) and can orbit straight into a wall.
- Occlusion is **reactive and imprecise**: `_resolve_occlusion` tests only the *thin center line*
  (`aabb.intersects_segment(pos, aim)`) and *gradually* fades occluders to a still-visible `0.1`
  alpha (`lerp 0.18/frame`). A building just off-center, or a fast orbit pop-in, isn't cleared in time.

The reverted experiment over-corrected (instant hard-hide of a wide grown-AABB corridor) and emptied
the city around the fight — losing the sense of place/scale that the choreography needs.

## Goals
1. **Proactive composition:** aim the camera at a clear line *first*, so most burials never happen —
   but only by adjusting *within* the authored shot's identity (bounded search, not free flight; no
   "camera bounce").
2. **Precise occlusion cleanup:** for whatever still occludes, fade **only the true occluders** (the
   buildings actually covering the mech's on-screen silhouette) **fully out, quickly and smoothly**
   (~0.1s) — never a wide corridor, never a hard snap. The surrounding skyline is untouched.
3. Preserve determinism (no physics; AABB math only) and the proven shot list (hash unchanged).

## Non-goals (YAGNI / scope boundaries)
- No physics colliders / physics raycasts — buildings are boxes; ray-vs-AABB is exact and
  deterministic. (Considered and rejected: adds a physics layer, collider teardown on collapse, and a
  determinism caveat for no benefit on box geometry.)
- No screen-space projection occlusion (more "composition-true" but heavier, with behind-camera
  projection edge cases). (Considered and rejected for now.)
- No change to the `iso` top-down backbone (it sees the whole city; its `_fade_for_iso` pass stays).
- No change to the shot LIST / timing / event sequence. Camera pose + building alpha are presentation
  only.

## Architecture

### One shared sightline test (the core)
A new pure module `godot_director_spike/scripts/director/sightline.gd`. Given a candidate camera
position, the subject's **silhouette sample points**, and the building AABBs, it casts one ray per
sample point (camera → point) and returns a result:
- `clear_count: int` — number of rays that reach the subject unobstructed → the **pose score**.
- `occluders: Array` — the building nodes whose AABB any ray passes through → the set to **fade**.

```gdscript
# sightline.gd (pure; unit-tested)
# subject_points: Array[Vector3] — the silhouette samples (world space)
# buildings: Array — nodes in group "kb_building", each with meta "aabb"
# Returns { "clear_count": int, "occluders": Array }  (occluders deduped)
static func evaluate(cam_pos: Vector3, subject_points: Array, buildings: Array) -> Dictionary
```
Exact for boxes, pure, deterministic. The same call drives both consumers below, so composition and
hiding never disagree about "what's blocking."

**Silhouette sample points** (the subject): for a single mech, `{feet, torso (≈+H*0.6), head (≈+H),
left shoulder, right shoulder}` — ~5 points spanning the on-screen silhouette so a building covering
*any* meaningful part counts as an occluder (not just the dead-center line). For `melee_cut` the
subject is the **clash point** (both mechs meet there) — sample around the contact + each mech's
upper body. Point count is a fixed small constant (≈5–6); not a tunable.

### Consumer 1 — Composition (bounded candidate search)
Each perspective cut computes its pose from one **free parameter**:
- `melee_cut`, `bullet_time` → the orbit **angle**.
- `hero_os`, `hero_cut` → the **lateral / pullback** offset.

Instead of taking the single authored pose blindly, the solve:
1. Generates a **small candidate set** by perturbing the free parameter within
   `± grammar.composition_search_arc` (e.g. orbit `ang, ang±arc/2, ang±arc`) — staying inside the
   shot's identity.
2. Scores each candidate with `sightline.evaluate` (its `clear_count`).
3. Picks the candidate with the **highest clear_count**, tie-broken toward the **authored** pose
   (smallest deviation) so the shot stays faithful.
4. **Hysteresis:** keep the current direction unless a candidate beats it by a clear margin
   (≥ `2` more clear rays). Prevents per-frame flip-flop / jitter.
The camera still **lerps** toward the chosen pose (existing smoothing) — the search changes the
*target*, not the motion model, so there is no snap.

### Consumer 2 — Hide (precise quick fade)
After the final pose is set, run `sightline.evaluate` once from that pose. The returned `occluders`
(only true silhouette occluders) fade their material alpha to **0.0** over `grammar.occlusion_fade_time`
(~0.1s, fast but smooth); buildings not in the set restore toward 1.0 at the same rate. This replaces
the thin-center-line `_resolve_occlusion`. No grown corridor; the rest of the city is never touched.
A per-frame fade step of `clampf(delta / occlusion_fade_time, 0, 1)` toward the target reaches full in
~0.1s and is frame-rate independent.

## Components / files
- **Create** `scripts/director/sightline.gd` — the pure `evaluate(...)` ray-vs-AABB test. + uid.
- **Create** `tests/sightline_check.gd` — unit test (known geometry → expected `occluders` +
  `clear_count`; the pose-picker chooses the clearest candidate; pure/deterministic).
- **Modify** `scripts/director.gd` — replace `_resolve_occlusion`'s thin-line body with the sightline
  occluder fade (precise, quick); add a small `_pick_clear_pose(candidates, subject_points)` helper
  that scores candidates via `sightline.evaluate` and applies the hysteresis. `_fade_building` gains a
  fast/full fade path driven by `occlusion_fade_time` (the gradual-0.1 default stays for any caller
  not opting in — but the perspective cuts now use the precise full fade).
- **Modify** `scripts/directors/hybrid.gd` — the perspective-cut arms (`hero_os`, `hero_cut`,
  `melee_cut`, `bullet_time`) build their candidate set + call `_pick_clear_pose`; build the subject
  silhouette points; the final pose feeds the hide. `iso` unchanged.
- **Modify** `scripts/director/shot_grammar.gd` — add `occlusion_fade_time: float = 0.1` and
  `composition_search_arc` (angle in radians for orbit shots / offset for hero shots — see Open
  question 1) to a Composition/occlusion block. + assert defaults in `shot_grammar_check.gd`.
- The other directors (`blend`, `broadcast`, `witness`, `iso`) keep calling the existing occlusion
  path unchanged (or are migrated only if trivial — out of scope for v1).

## Determinism
All ray-vs-AABB math; no physics; no RNG. The camera pose is selected from deterministic building +
mech state and is presentation-only — it never feeds the sim or the shot list. Therefore the golden
hash `2543717900` MUST remain unchanged (regression gate). Building alpha is presentation-only.

## Testing
- **Unit (`sightline_check.gd`):** construct a camera, subject points, and a few building AABBs with
  known geometry; assert `evaluate` returns the expected occluder set and `clear_count` for: a clear
  line (0 occluders, all rays clear), a dead-center block (1 occluder, clear_count drops), an
  off-center block that covers a shoulder but not center (caught by the silhouette rays — the key
  improvement over the thin line). Assert `_pick_clear_pose` selects the higher-clear_count candidate
  and that hysteresis holds the current pick on a tie/small margin.
- **Regression:** full headless suite + `hybrid_check.gd` hash `2543717900` unchanged.
- **Visual (owner-gated windowed):** `fight_log_melee` and `fight_log_everything` `--frames` captures —
  the close-ups read clean (no building filling the frame), the city stays intact around the fight,
  and the camera doesn't visibly bounce/jitter.

## Open questions for the implementation plan
1. `composition_search_arc` units differ per shot family (radians for orbit `melee_cut`/`bullet_time`
   vs world-units for hero lateral/pullback). Resolve in the plan: either one normalized "search
   strength" mapped per family, or two params (`composition_search_arc` for orbits +
   `composition_search_offset` for hero shots). Lean: one small per-family constant table to avoid a
   param sprawl; revisit if tuning needs it.
2. Candidate count (3 vs 5) and the hysteresis margin (≥2 rays) are starting values to tune from the
   visual capture; expose only if the capture shows jitter or sluggishness.
3. The subject silhouette points for `melee_cut` (both mechs at the clash) vs a single-focus hero cut
   — confirm the sample set per shot in the plan (a shared `_subject_points(focus, mode)` helper).
