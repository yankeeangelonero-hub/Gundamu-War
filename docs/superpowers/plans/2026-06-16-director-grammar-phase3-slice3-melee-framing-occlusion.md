# Director Grammar — Phase 3, Slice 3: Melee Framing + Aggressive Occlusion

> Status: PROPOSED plan, 2026-06-16. Builds on Phase 3 Slices 1–2. Determinism gate: hash 2543717900.
> Design: spec Spectacle/Composition §; closes the carried seam B2 (melee_cut timing) from the Phase 3
> scope doc; addresses the owner's requirement: aggressively hide foreground buildings in the path of
> the camera and the mech during the melee close-up.

## Goal
Two coupled things for the melee clash close-up (`melee_cut`):
1. **Melee framing — finish the parameters-out work (B2 seam):** the `melee_cut` shot's timing
   (`pre`/`post`/`time_scale`) is still an inline island in `hybrid.gd build_shot_list`; lift it into
   the grammar's Timing block like every other shot parameter.
2. **Aggressive melee occlusion (owner requirement):** a tight orbit around the blade clash gets
   buried when a foreground building drops between the lens and the mechs. Today's occlusion is too
   soft for that: it tests only the thin camera→aim center line and fades occluders *gradually*
   (`lerp 0.18/frame`) to `0.1` alpha (still faintly visible). Make melee_cut hide foreground
   buildings **hard, instant, and on a widened corridor** so the blade always reads.

## What exists today (grounded)
- `hybrid.gd build_shot_list` (~:47-50): a non-lethal `melee` event appends a `melee_cut` shot with
  `t0 = mt - 0.5`, `t1 = mt + 1.7`, `time_scale = 0.5` — three inline literals.
- `director.gd _resolve_occlusion(pos, aim)` (~:298): per building, `occluding = aabb.intersects_segment(pos, aim) != null or aabb.grow(FADE_NEAR=7).has_point(pos)`; then
  `_fade_building(bld, FADE_MIN=0.1 if occluding else 1.0)`. `_fade_building` lerps alpha at `0.18`/
  frame toward the target (gradual) and uses `ALPHA_HASH` transparency. Presentation-only.
- `hybrid.gd _update_camera` melee_cut path calls `_resolve_occlusion(pos, aim)` (~:164) and
  `_cull_near(pos, dist-to-aim - 6)` (~:172). The thin-line test + gradual fade is the gap.

## Design

### 1. Melee timing → grammar (Timing block)
Add to `ShotGrammar`:
```gdscript
@export var melee_cut_pre: float = 0.5     # lead-in before the clash tick
@export var melee_cut_post: float = 1.7    # hold after the clash tick
@export var melee_cut_scale: float = 0.5   # melee close-up slow-mo
```
In `build_shot_list`, replace the three inline literals with `grammar.melee_cut_pre/post/scale`. Same
default values → the golden (no-melee) shot list is byte-identical → **hash 2543717900 unchanged**.

### 2. Aggressive occlusion mode for melee_cut
Extend the occluder pass with an aggressive variant the melee close-up opts into:
```gdscript
# add a grammar param (Composition/occlusion):
@export var melee_occlusion_margin: float = 8.0   # widen the camera→clash corridor for the melee cull

# director.gd — _resolve_occlusion gains optional aggression:
func _resolve_occlusion(pos: Vector3, aim: Vector3, margin := 0.0, instant := false) -> Vector3:
	for bld in get_tree().get_nodes_in_group("kb_building"):
		var aabb: AABB = bld.get_meta("aabb")
		var occluding := aabb.grow(margin).intersects_segment(pos, aim) != null \
			or aabb.grow(FADE_NEAR).has_point(pos)
		_fade_building(bld, FADE_MIN if occluding else 1.0, instant)
	return pos
```
- `margin` grows each building's AABB before the segment test → a **corridor**, not a thin line, so a
  building near (not exactly on) the sightline is caught.
- `instant` makes `_fade_building` snap alpha to the target in one frame (and to a full `0.0` hide for
  the occluder, not the see-through `0.1`) instead of the gradual lerp — so a pop-in clears at once.
`_fade_building(bld, target, instant := false)`: when `instant`, set alpha directly to (target == FADE_MIN ? 0.0 : target) — i.e. occluders snap fully hidden, restores snap back.
The existing non-melee callers pass no extra args → `margin=0, instant=false` → **unchanged behaviour**.

In `hybrid.gd` the **melee_cut** branch calls the aggressive form:
`_resolve_occlusion(pos, aim, grammar.melee_occlusion_margin, true)`; all other shot modes keep the
plain `_resolve_occlusion(pos, aim)`. (The melee branch already also calls `_cull_near` — keep it.)

## Determinism
Both changes are presentation-only (shot timing values are identical defaults; occlusion is material
alpha). The shot LIST for the golden no-melee log is byte-identical → hash `2543717900` MUST hold.

## Tasks
- **S3.1** — grammar params (`melee_cut_pre/post/scale`, `melee_occlusion_margin`) + assert defaults;
  `build_shot_list` reads the three timing params. TDD + the golden hash unchanged.
- **S3.2** — `_resolve_occlusion(pos, aim, margin, instant)` + `_fade_building(..., instant)`; the
  melee_cut branch opts into the aggressive form. Boot + hash. (Non-melee modes unchanged.)
- **S3.3** — regression (all suites + hash) + windowed `--frames` capture on `fight_log_melee` (or
  `fight_log_saber`): confirm the blade clash close-up reads clean — foreground buildings on the
  orbit path vanish instead of burying the blade. Review.

## Open owner decision (surface, don't block)
- Aggressive = **instant full hide** (snap to 0.0) on a **corridor** (margin 8.0). If that reads too
  abrupt/empty in the capture, the fallback is a fast-but-not-instant fade and/or a smaller margin —
  tune from S3.3. (Default proceed with instant + margin 8.)

## Execution method
Subagent-driven (implementer → spec review → quality review), standard guardrails.
