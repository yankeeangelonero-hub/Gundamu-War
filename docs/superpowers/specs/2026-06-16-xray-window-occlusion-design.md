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
- **Global shader parameters** (FOUR, one set, read by every building — declared in `project.godot`
  `[shader_globals]` so they exist when the building shaders compile; the director only *sets* them):
  - `xray_mech_a : vec3`, `xray_mech_b : vec3` — the two mechs' world positions (the look-at
    height-centre, ~`mech.position + (0, 9, 0)`), updated each frame by the director. **Both are fed
    every frame whether the mech is alive or dead** — the cameras still frame a wrecked mech in the
    aftermath/orbit beats, so its window must stay open (a dead mech is NOT special-cased off).
  - `xray_radius : float` — the window radius around the camera→mech sightline (feel dial, default ~14).
  - `xray_softness : float` — the soft-edge width (default ~5): full cut within `radius - softness` of
    the sightline, ramping to no-cut at `radius`.
- **Fragment logic — a soft capsule along the camera→mech SIGHTLINE** (not a sphere around the mech;
  a sphere would miss a wall that sits between the lens and the mech but far from the mech). In world
  space, with `cam = CAMERA_POSITION_WORLD`, fragment world position `p`, and each mech `m`:
  - Project `p` onto the camera→mech segment: `seg = m - cam`; `t = dot(p - cam, seg) / dot(seg, seg)`.
    The fragment is between the lens and the mech iff `0.0 < t < 1.0` (this also covers the camera
    embedded in / very close to a wall: at small `t` the capsule still includes near-lens fragments —
    so it subsumes the old `FADE_NEAR` near-lens case).
  - Closest point on the segment `proj = cam + t * seg`; perpendicular distance `perp = distance(p, proj)`.
  - `cut_m = (t > 0.0 && t < 1.0) ? (1.0 - smoothstep(radius - softness, radius, perp)) : 0.0`
    → 1 (full cut) on the sightline core, 0 outside `radius`, soft ramp between. (Note the smoothstep
    order: `edge0 = radius - softness < edge1 = radius`; `clamp` softness below radius.)
  - `cut = max(cut_a, cut_b)`.
  - **Dissolve via a deterministic hashed `discard`** (order-independent, no transparency sorting):
    `if (cut > hash(SCREEN_UV or FRAGCOORD)) discard;` — i.e. discard fragments inside the window with
    a dither proportional to `cut`. (Do NOT rely on an `alpha_hash` render_mode — validate the exact
    Godot 4.6 transparency syntax in the boot; the hashed-discard path needs no render_mode and matches
    the dithered look the old fade used.)
- **Lit look parity:** set `ALBEDO = albedo.rgb` and `ROUGHNESS = 0.7` and keep the default lit
  (Burley/GGX) pipeline — buildings today are lit `StandardMaterial3D` with `roughness = 0.7`
  (`city_builder.gd:63`). Do NOT use `unshaded`; a non-occluded building must look the same as today
  (capture a before/after of an unoccluded building to confirm).
- **`p` (fragment world position):** pass the vertex world position from the vertex shader
  (`VERTEX` × `MODEL_MATRIX`) to the fragment as a varying.

This yields a soft round window along each camera→mech sightline, cutting any wall in front of a mech
(at any depth, including one hugging the lens), on any camera (perspective cuts and the iso top-down).

### Feeding the shader (director)
The four globals are declared in `project.godot` `[shader_globals]` with sane defaults (so they exist
at shader-compile time — buildings are materialized in `city_builder` before `director.start()`).
Each frame in the director's `_process`/`_update_camera`, set `xray_mech_a` / `xray_mech_b` (both
mechs, alive or dead) via `RenderingServer.global_shader_parameter_set(...)`. `xray_radius` /
`xray_softness` are set from the grammar (new Lens params) once at `start()` (and could be re-set if
tuned live), so they are tunable.

### Building creation (`city_builder.gd`)
Where buildings currently get a `StandardMaterial3D`, assign a `ShaderMaterial` using the x-ray shader,
with the per-building `albedo` set to the colour the building used. The `kb_building` group + the
`aabb` meta stay (the camera-angle search still uses the AABBs).

**The pop-out window child meshes also get the x-ray shader.** Buildings have emissive window child
meshes with their own `StandardMaterial3D` (`city_builder.gd:39`); the old fade hid them when the
parent's alpha dropped. If only the parent building changes, the window strips would float over the
x-ray hole. Give the window meshes the **same x-ray shader** (an emissive variant — an `emission`
uniform / brighter albedo), so they are cut by the identical global sightline test and dissolve with
the wall. (They read the same four globals; no extra wiring.)

### Destruction adaptation
`_smash_building` / `_detonate_building` currently type the building material as `StandardMaterial3D`
and tween `mat.albedo_color` toward a charred dark (`garnish.gd:122`, `garnish.gd:227`). Change the
type to `ShaderMaterial` and tween the shader colour uniform: `tween_property(mat,
"shader_parameter/albedo", <dark>, t)` (or a `tween_method` calling `set_shader_parameter("albedo", c)`).
Collapse transforms (scale/position/rotation) are unchanged; the window-mesh hide-on-collapse stays.

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
- **Globals registered + fed:** a small headless check that the four global shader parameters exist
  (declared in `project.godot`) and that the director updates `xray_mech_a/b` to the mech positions on
  a `_process` step (`RenderingServer.global_shader_parameter_get` returns them). (Render not required —
  this checks the wiring, not the pixels.)
- **Determinism:** `hybrid_check.gd` → `got hash 2543717900` unchanged.
- **Regression:** `shot_grammar_check` (new params), `continuity_check`, `sightline_check`,
  `director_check`, `grade_check`, `time_emphasis_check` all green (none depend on the removed fades;
  if any asserted on `_resolve_occlusion`/`_fade_building`, update it).
- **Visual (owner-gated windowed):** `fight_log_melee` + `fight_log_everything` `--frames` — a wall in
  front of a mech now shows a soft round window with the real mech inside; the rest of the wall and
  the background stay solid; the iso top-down view shows the same; no buildings wholesale-vanish.

## Decisions settled by the codex spec review (2026-06-16) — no longer open
1. **Sightline capsule, not a mech-sphere** (was the core flaw): the cut is along the camera→mech
   segment (perpendicular distance), so a wall anywhere between lens and mech is cleared, including one
   at the lens — see the fragment logic above. This is the load-bearing correction.
2. **Globals in `project.godot` `[shader_globals]`**, not a runtime `global_shader_parameter_add` — they
   must exist when the building shaders compile (buildings are built before `director.start()`); the
   director only `set`s them.
3. **Atomic swap:** the material swap to `ShaderMaterial` and the removal of `_resolve_occlusion` /
   `_fade_building` / `_fade_for_iso` happen in the SAME change — never "add behind the old fade then
   remove" (the old fade hard-casts `StandardMaterial3D` and would crash on a `ShaderMaterial`). The
   plan sequences: (a) shader + project globals + city_builder material swap + director feed + destruction
   cast change, then (b) delete the dead fade code, in close succession with a boot between.
4. **Window child meshes get the x-ray shader too** (emissive variant) so they dissolve with the wall.
5. **Dead mechs keep their window** (both positions fed every frame) — the aftermath/orbit beats frame
   the wreck.
6. **Lit parity required:** `ROUGHNESS = 0.7`, lit pipeline — not an open question, a build requirement.
7. **Hashed `discard`** for the dissolve (no `alpha_hash` render_mode dependency); validate the exact
   transparency syntax at the first boot.

## Remaining open question for the implementation plan
- **Window-mesh emissive in the shader:** the window meshes currently use an emissive
  `StandardMaterial3D`. The x-ray variant needs an `emission`/brightness uniform to keep their glow.
  Confirm the exact emissive values from `city_builder.gd` when authoring the shader variant so the
  lit windows look unchanged when not occluded.
