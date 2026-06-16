# X-Ray Window Occlusion — Design

> Status: APPROVED design (owner, 2026-06-16). Replaces the building-FADE approach to occlusion
> (the precise multi-ray fade in `_resolve_occlusion` and the iso top-down `_fade_for_iso`) with a
> GPU "x-ray window": a soft hole punched through whatever stands between the camera and a mech, so
> the real mech is always visible. Supersedes the occlusion-fade portions of
> `docs/superpowers/specs/2026-06-16-continuity-and-sightline-camera-design.md`; the screen-side
> continuity and camera-angle-search portions of that spec stay in force (they handle framing, not
> visibility). Determinism gate: the golden shot-list hash `2543717900` is unaffected (GPU/render only).

## Problem
Fading whole buildings to reveal an occluded mech reads as inelegant — buildings blink out, and a
boxed-in close shot can empty the scene or still bury the mech. We want the mechs **always visible
when occluded**, without removing the buildings: a soft round x-ray window cut through only the wall
that is directly in front of a mech, revealing the real mech behind it. The rest of the wall — and
every wall behind the mech — stays solid, so the city still reads.

## Goal
A per-building GPU shader that, for each surface point, dissolves that point with a soft edge **iff**
it lies within a set distance of a mech **and** is closer to the camera than that mech (i.e. it is
between the lens and the mech). One mechanism, applied to every camera (the perspective cuts and the
iso top-down view), replacing both existing occlusion fades.

## What this keeps (unchanged)
- **Screen-side continuity** (`_axis_keyed_side`, `_keyed_lateral`) — cut-ins stay on one side of the
  180° line so the mechs never swap screen sides. Framing, not occlusion.
- **Camera-angle search** (`Sightline.evaluate` + `_pick_clear_pose`) — the camera still scores
  candidate angles by the building-AABB ray test and picks a clearer one. This frames a *nicer* shot
  (less wall in view); the x-ray is the *visibility guarantee* underneath. They do not conflict, and
  the `Sightline` ray module is unrelated to the x-ray shader (it stays as-is).

## What this replaces / removes
- `director.gd _resolve_occlusion` (the per-building cinematic fade) — removed; its call sites just
  set the camera pose directly.
- `director.gd _fade_building` and `FADE_NEAR`/`FADE_MIN`/`FADE_RATE` consts — removed (no caller
  left once the fades are gone).
- `_fade_for_iso` (the iso top-down see-through fade, in `iso.gd` / `hybrid.gd`) — removed; the x-ray
  shader covers the iso camera too.
- All other directors (`blend`/`broadcast`/`witness`) that called `_resolve_occlusion` drop the call;
  they inherit the x-ray via the building shader (it is camera-agnostic).

## Architecture

### The building shader (`scripts/shaders/xray_occluder.gdshader` — NEW)
A `spatial` shader replacing the buildings' `StandardMaterial3D`. It reproduces the buildings' current
flat look and adds the x-ray cut:
- **Per-material uniform** `albedo : Color` — the building's base colour (also the target the
  destruction/darken tween animates; see below). One `ShaderMaterial` instance per building so each
  keeps its own colour and can be darkened independently.
- **Global shader parameters** (one set, read by every building):
  - `xray_mech_a : vec3`, `xray_mech_b : vec3` — the two mechs' world positions (the look-at
    height-centre, ~`mech.position + (0, 9, 0)`), updated each frame by the director.
  - `xray_radius : float` — the world-space window radius around a mech (the feel dial, default ~16).
  - `xray_softness : float` — the soft-edge width (default ~6): full transparency within
    `radius - softness`, ramping to opaque at `radius`.
- **Fragment logic** (in world space; `CAMERA_POSITION_WORLD` is a built-in):
  - For each mech `m` in {a, b}: `d_m = distance(world_vertex, m)`; treat `m` as an occlusion source
    only if the fragment is **in front of** it: `distance(CAMERA_POSITION_WORLD, world_vertex) <
    distance(CAMERA_POSITION_WORLD, m)`.
  - `cut = max over qualifying m of smoothstep(radius, radius - softness, d_m)` → 0 outside the
    window, 1 in the clear centre, soft ramp on the edge.
  - `ALPHA = 1.0 - cut`. Use **alpha-hash** dithered transparency (`render_mode` alpha-hash, or a
    hashed `discard` when `ALPHA < hash`) so the cut is order-independent and needs no depth sorting —
    matching the look the old fade used (`TRANSPARENCY_ALPHA_HASH`).
- **`world_vertex`**: pass the vertex world position from the vertex shader (`VERTEX` transformed by
  `MODEL_MATRIX`) to the fragment as a varying.

This yields a soft spherical window per mech, cutting only the near side (in front of the mech), on
any camera. (World-space sphere, not a flat screen circle: simpler in a spatial shader, deterministic,
and reads as a soft hole. The on-screen size varies a little with mech distance, acceptable for these
shots; revisit if it reads inconsistently.)

### Feeding the shader (director)
At startup, register the three global shader parameters (e.g. `RenderingServer.global_shader_parameter_add`)
with sane defaults. Each frame in the director's `_process`/`_update_camera`, set `xray_mech_a` /
`xray_mech_b` from the live mech positions (skip a dead mech, or leave its last position — a dead mech
needs no window; resolve in the plan). `xray_radius`/`xray_softness` come from the grammar (new Lens
params) so they are tunable.

### Building creation (`city_builder.gd`)
Where buildings currently get a `StandardMaterial3D`, assign a `ShaderMaterial` using the x-ray shader,
with the per-building `albedo` set to the colour the building used. The `kb_building` group + the
`aabb` meta stay (the camera-angle search still uses the AABBs). The pop-out window child meshes stay.

### Destruction adaptation
`_smash_building` / `_detonate_building` currently tween `mat.albedo_color` toward a charred dark.
Re-point those tweens at the shader's colour: `tween_property(mat, "shader_parameter/albedo", <dark>, t)`.
Collapse transforms (scale/position/rotation) are unchanged.

### Grammar params (Lens block)
- `xray_radius : float = 16.0`
- `xray_softness : float = 6.0`
(These feed the global shader params each frame; tunable from the visual capture.)

## Determinism
The shader is pure GPU rendering; the per-frame global-param update reads deterministic mech positions
and writes only render state. Nothing touches the simulation, the event sequence, or `build_shot_list`.
The golden hash `2543717900` must stay unchanged. The camera-angle search still uses the (unchanged)
`Sightline` AABB test, which is also deterministic.

## Testing
A fragment shader cannot be unit-tested headlessly (no rendering), so verification leans on boot +
visual + the unaffected suites:
- **Shader compiles / no load errors:** a render boot (`godot --path ... -- --director=hybrid
  --log=fight_log_melee`) prints `boot ok` with no shader-compile or script errors. (Godot reports
  shader errors at material load.)
- **Globals registered + fed:** a small headless check that the three global shader parameters exist
  after the director starts (`RenderingServer.global_shader_parameter_get` returns the set value), and
  that the director updates `xray_mech_a/b` to the mech positions on a `_process` step. (Render not
  required — this checks the wiring, not the pixels.)
- **Determinism:** `hybrid_check.gd` → `got hash 2543717900` unchanged.
- **Regression:** `shot_grammar_check` (new params), `continuity_check`, `sightline_check`,
  `director_check`, `grade_check`, `time_emphasis_check` all green (none depend on the removed fades;
  if any asserted on `_resolve_occlusion`/`_fade_building`, update it).
- **Visual (owner-gated windowed):** `fight_log_melee` + `fight_log_everything` `--frames` — a wall in
  front of a mech now shows a soft round window with the real mech inside; the rest of the wall and
  the background stay solid; the iso top-down view shows the same; no buildings wholesale-vanish.

## Open questions for the implementation plan
1. **Dead mech:** when a mech dies, does its window stop (set its `xray_mech_*` far away / a sentinel)
   or persist on the wreck? Lean: move the dead mech's source out of range so its window closes.
2. **Global-param registration:** `RenderingServer.global_shader_parameter_add` at runtime vs project
   `[shader_globals]` in `project.godot`. Lean: runtime add in the director's `start()` (self-contained,
   no project-file edit), guarded so a re-add is harmless.
3. **Shader look fidelity:** the buildings' current `StandardMaterial3D` settings (roughness, any
   shading) must be reproduced in the shader so non-occluded buildings look the same as today. Capture
   a before/after of an unoccluded building to confirm parity. If they used only flat albedo, the
   shader is trivial; if they used lit shading, match `diffuse`/`roughness`.
4. **Alpha-hash vs smooth alpha:** alpha-hash (dither) is order-independent (no sorting) and matches
   the old look; a smooth alpha would need transparency sorting. Lean: alpha-hash.
5. **Removal sequencing:** remove `_resolve_occlusion`/`_fade_building`/`_fade_for_iso` and their call
   sites in the same change that adds the shader, so there is never a frame with neither mechanism.
   The plan sequences: add shader + wiring first (behind the still-present fade), then remove the fade.
