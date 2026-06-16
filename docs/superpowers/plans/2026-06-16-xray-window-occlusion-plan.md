# X-Ray Window Occlusion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace the building-fade occlusion with a GPU "x-ray window" — a soft round hole cut through whatever stands between the camera and a mech, along the camera→mech sightline, so the real mech is always visible. One mechanism for every camera; the per-building fades are removed.

**Architecture:** A `spatial` shader on every building (and its window child meshes) reads four global shader params (the two mechs' world positions + window radius/softness). For each fragment it projects onto the camera→mech segment and dissolves (hashed `discard`) fragments within `radius` of that sightline and in front of the mech. The director sets the globals each frame. Spec: `docs/superpowers/specs/2026-06-16-xray-window-occlusion-design.md`.

**Tech Stack:** Godot 4.6.3, GDScript + a `.gdshader` spatial shader, `project.godot` `[shader_globals]`, `RenderingServer.global_shader_parameter_set`. `godot` on PATH.

**Guardrails:** never run `git checkout`/`switch`/`branch`/`stash`/`reset` (stay on `combat-feel-restart`); Godot HEADLESS for logic, a render boot (no `--headless`) only where noted to validate the shader compiles; on "unknown class" run `godot --headless --path godot_director_spike --import` once; no `Co-Authored-By` trailer; repo root `D:\Claude\Mech Bags`. Determinism gate: golden hash `2543717900` (`hybrid_check.gd`) stays unchanged (GPU/render only).

**KEEP (do not touch):** screen-side continuity (`_axis_keyed_side`/`_keyed_lateral`), the camera-angle search (`Sightline`/`_pick_clear_pose`), the lens compression, the grade, the time-emphasis arbiter, the staggered blast.

---

## File structure
- `godot_director_spike/scripts/shaders/xray_occluder.gdshader` — NEW spatial shader.
- `godot_director_spike/project.godot` — add `[shader_globals]` (4 globals).
- `godot_director_spike/scripts/director/shot_grammar.gd` — `xray_radius`, `xray_softness`.
- `godot_director_spike/scripts/city_builder.gd` — buildings + window meshes use the x-ray `ShaderMaterial`.
- `godot_director_spike/scripts/director.gd` — feed the globals each frame; REMOVE `_resolve_occlusion`/`_fade_building`/`FADE_*`.
- `godot_director_spike/scripts/directors/hybrid.gd`, `blend.gd`, `broadcast.gd`, `witness.gd`, `iso.gd` — drop `_resolve_occlusion`/`_fade_for_iso` calls.
- `godot_director_spike/scripts/garnish.gd` — destruction casts `StandardMaterial3D` → `ShaderMaterial`.
- `godot_director_spike/tests/xray_check.gd` — NEW headless wiring test.

---

### Task 1: The x-ray shader + project globals

**Files:** Create `godot_director_spike/scripts/shaders/xray_occluder.gdshader`; modify `godot_director_spike/project.godot`.

- [ ] **Step 1: Create the shader**

```glsl
shader_type spatial;
// X-ray occluder (spec 2026-06-16): dissolves wall fragments along the camera->mech
// sightline so the real mech shows through a soft round window. Lit, roughness 0.7,
// to match the buildings' StandardMaterial3D. Order-independent hashed discard.

global uniform vec3 xray_mech_a;
global uniform vec3 xray_mech_b;
global uniform float xray_radius;
global uniform float xray_softness;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 emission_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Soft cut for one camera->mech sightline: 1 on the sightline core, 0 outside radius,
// only where the fragment is between the lens and the mech (0 < t < 1).
float sightline_cut(vec3 p, vec3 cam, vec3 m, float radius, float softness) {
	vec3 seg = m - cam;
	float seg2 = dot(seg, seg);
	if (seg2 < 0.0001) { return 0.0; }
	float t = dot(p - cam, seg) / seg2;
	if (t <= 0.0 || t >= 1.0) { return 0.0; }
	vec3 proj = cam + t * seg;
	float perp = distance(p, proj);
	return 1.0 - smoothstep(radius - softness, radius, perp);
}

float hash12(vec2 v) {
	return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	float cut = max(
		sightline_cut(world_pos, cam, xray_mech_a, xray_radius, xray_softness),
		sightline_cut(world_pos, cam, xray_mech_b, xray_radius, xray_softness));
	if (cut > hash12(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.7;
	EMISSION = emission_col.rgb * emission_energy;
}
```

- [ ] **Step 2: Declare the four globals in `project.godot`**

Read `godot_director_spike/project.godot` first. Add a `[shader_globals]` section (if one exists, merge):

```
[shader_globals]

xray_mech_a={
"type": "vec3",
"value": Vector3(0, -10000, 0)
}
xray_mech_b={
"type": "vec3",
"value": Vector3(0, -10000, 0)
}
xray_radius={
"type": "float",
"value": 14.0
}
xray_softness={
"type": "float",
"value": 5.0
}
```
(Default mech positions sit far below the city so nothing is cut until the director feeds real positions — no spurious window at the origin on the first frames.)

- [ ] **Step 3: Reimport so the project + shader register**

Run: `godot --headless --path godot_director_spike --import 2>&1 | tail -5`
Expected: completes; no fatal error. (The shader isn't assigned to anything yet, so no compile happens until Task 3 — that's fine; this step just registers the new files + globals.)

- [ ] **Step 4: Commit**

```bash
git add godot_director_spike/scripts/shaders/xray_occluder.gdshader godot_director_spike/project.godot
git commit -m "feat(render): x-ray occluder shader + project shader globals (occlusion redesign)"
```

---

### Task 2: Grammar params for the window

**Files:** `godot_director_spike/scripts/director/shot_grammar.gd` + `tests/shot_grammar_check.gd`.

- [ ] **Step 1: Failing test** — append to `tests/shot_grammar_check.gd` (reuse `g`):

```gdscript
	# --- X-ray window occlusion ---
	check(is_equal_approx(g.xray_radius, 14.0), "xray_radius == 14.0")
	check(is_equal_approx(g.xray_softness, 5.0), "xray_softness == 5.0")
```

- [ ] **Step 2: Run — expect FAIL**

`godot --headless --path godot_director_spike -s res://tests/shot_grammar_check.gd` → FAIL `Invalid access ... 'xray_radius'`, exit 1.

- [ ] **Step 3: Add the params** — in `shot_grammar.gd`, in the Lens block (near `compression_*`):

```gdscript
# --- Lens: x-ray window occlusion ---
@export var xray_radius: float = 14.0     # window radius around the camera->mech sightline (world units)
@export var xray_softness: float = 5.0    # soft-edge width of the window
```

- [ ] **Step 4: Run — expect PASS**

`godot --headless --path godot_director_spike -s res://tests/shot_grammar_check.gd` → `---- ALL PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot_director_spike/scripts/director/shot_grammar.gd godot_director_spike/tests/shot_grammar_check.gd
git commit -m "feat(grammar): xray_radius + xray_softness window params"
```

---

### Task 3: The atomic swap — buildings use the shader, director feeds it, fades removed

This is one cohesive change (per the spec's atomic-swap requirement): the moment buildings become `ShaderMaterial`, the old `_fade_building` (which hard-casts `StandardMaterial3D`) must no longer run on them, or it crashes. So the material swap, the director feed, the destruction cast change, and removing the fade CALL SITES happen together.

**Files:** `city_builder.gd`, `director.gd`, `hybrid.gd`, `blend.gd`, `broadcast.gd`, `witness.gd`, `iso.gd`, `garnish.gd`.

- [ ] **Step 1: city_builder — buildings + windows get the x-ray ShaderMaterial**

In `city_builder.gd`, add a shader preload at top of the script:
```gdscript
const XRAY_SHADER := preload("res://scripts/shaders/xray_occluder.gdshader")
```
In `_building(...)` (~:63), replace the `StandardMaterial3D` with the x-ray `ShaderMaterial`:
```gdscript
	var mat := ShaderMaterial.new()
	mat.shader = XRAY_SHADER
	mat.set_shader_parameter("albedo", col)
```
(Keep `box.material = mat`, the groups, the `aabb` meta.)
For the window meshes (~:42-46), replace their `StandardMaterial3D` with the x-ray shader carrying the emissive look:
```gdscript
	var wmat := ShaderMaterial.new()
	wmat.shader = XRAY_SHADER
	var wcol: Color = Color(0.9, 0.6, 0.25) if rng.randf() < 0.5 else Color(0.4, 0.7, 0.9)
	wmat.set_shader_parameter("albedo", Color(1, 1, 1))
	wmat.set_shader_parameter("emission_col", wcol)
	wmat.set_shader_parameter("emission_energy", 5.0)
```

- [ ] **Step 2: director — feed the globals each frame**

In `director.gd start()`, after actors are set, set the static window dials once (the director has no `_grammar`; read defaults — use the spec values directly, or accept the project-global defaults). Simpler: set radius/softness from the project defaults already in `project.godot`; the director only updates the mech positions. So in `_process(delta)` (while `playing`), add:
```gdscript
	if actors.has("A") and actors.has("B"):
		RenderingServer.global_shader_parameter_set("xray_mech_a", actors["A"].position + Vector3(0, 9, 0))
		RenderingServer.global_shader_parameter_set("xray_mech_b", actors["B"].position + Vector3(0, 9, 0))
```
(Both fed every frame, alive or dead. Radius/softness keep the project-global defaults of 14/5; a later task can drive them from the grammar if tuning needs it — keep this task minimal.)

- [ ] **Step 3: garnish — destruction casts to ShaderMaterial**

In `garnish.gd` `_smash_building` (~:122) and `_detonate_building` (~:227), the `var mat: StandardMaterial3D = (b as MeshInstance3D).mesh.material` cast becomes `var mat: ShaderMaterial = (b as MeshInstance3D).mesh.material`, and the albedo tween `tw.tween_property(mat, "albedo_color", Color(...), t)` becomes `tw.tween_property(mat, "shader_parameter/albedo", Color(...), t)`. Read both sites; change only the cast + the tween property path.

- [ ] **Step 4: Remove the fade CALL SITES (so the old fade never runs on a ShaderMaterial)**

- In `hybrid.gd _update_camera`: delete the line `pos = _resolve_occlusion(pos, aim)` (the perspective path) — `pos` is used as-is. Delete the `_fade_for_iso(...)` call in the iso branch.
- In `iso.gd`, `blend.gd`, `broadcast.gd`, `witness.gd`: delete their `pos = _resolve_occlusion(pos, aim)` / `_fade_for_iso(...)` calls (read each; remove the occlusion-fade call only, keep the pose).
- Do NOT delete the `_resolve_occlusion`/`_fade_building`/`_fade_for_iso` FUNCTION definitions yet (Task 4) — just stop calling them.

- [ ] **Step 5: Render boot — the shader compiles + cuts; no crash from the old fade**

Run (RENDER boot, no `--headless`, so the shader actually compiles): `godot --path godot_director_spike --quit-after 400 -- --director=hybrid --log=fight_log_melee 2>&1 | grep -iE "boot ok|SHADER|ERROR|error"`
Expected: `KM-DIRECTOR-SPIKE boot ok`, NO shader-compile errors, NO `StandardMaterial3D` cast errors, exit 0. If a shader error appears, fix the shader syntax (validate `global uniform`, `CAMERA_POSITION_WORLD`, `FRAGCOORD`, `discard` against Godot 4.6) and re-run. **This is the shader-validation gate — iterate here until clean.**

- [ ] **Step 6: Hash unchanged**

`godot --headless --path godot_director_spike -s res://tests/hybrid_check.gd` → `---- ALL PASS`, `got hash 2543717900`.

- [ ] **Step 7: Commit**

```bash
git add godot_director_spike/scripts/city_builder.gd godot_director_spike/scripts/director.gd godot_director_spike/scripts/directors/hybrid.gd godot_director_spike/scripts/directors/iso.gd godot_director_spike/scripts/directors/blend.gd godot_director_spike/scripts/directors/broadcast.gd godot_director_spike/scripts/directors/witness.gd godot_director_spike/scripts/garnish.gd
git commit -m "feat(render): swap buildings to x-ray shader, feed sightline globals, drop fade calls (atomic)"
```

---

### Task 4: Delete the now-dead fade code

**Files:** `director.gd` (+ `hybrid.gd`/`iso.gd` if `_fade_for_iso` lives there).

- [ ] **Step 1: Delete the unused functions + consts**

Confirm there are no remaining callers: `grep -rn "_resolve_occlusion\|_fade_building\|_fade_for_iso\|FADE_NEAR\|FADE_MIN\|FADE_RATE" godot_director_spike/scripts/` should show only the definitions. Delete: `_resolve_occlusion`, `_fade_building`, the `FADE_NEAR`/`FADE_MIN`/`FADE_RATE` consts (in `director.gd`), and `_fade_for_iso` (wherever defined). Leave `_silhouette_points` and `Sightline` (the camera-angle search still uses them).

- [ ] **Step 2: Render boot + hash**

`godot --path godot_director_spike --quit-after 300 -- --director=hybrid --log=fight_log_everything 2>&1 | grep -iE "boot ok|ERROR"` → `boot ok`, no errors.
`godot --headless --path godot_director_spike -s res://tests/hybrid_check.gd` → `got hash 2543717900`, `ALL PASS`.

- [ ] **Step 3: Commit**

```bash
git add godot_director_spike/scripts/director.gd godot_director_spike/scripts/directors/hybrid.gd godot_director_spike/scripts/directors/iso.gd
git commit -m "refactor(render): delete the dead building-fade code (replaced by x-ray)"
```

---

### Task 5: Wiring test + regression + visual

**Files:** Create `godot_director_spike/tests/xray_check.gd`.

- [ ] **Step 1: Wiring test** — create `tests/xray_check.gd` (headless; checks the globals are fed, not pixels):

```gdscript
extends SceneTree
## X-ray wiring (headless): the director sets the mech-position globals each frame.
var fails := 0
func check(c: bool, l: String) -> void:
	if c: print("PASS  %s" % l)
	else: print("FAIL  %s" % l); fails += 1
func _init() -> void:
	# The four globals exist (declared in project.godot).
	check(typeof(RenderingServer.global_shader_parameter_get("xray_radius")) == TYPE_FLOAT, "xray_radius global exists")
	check(typeof(RenderingServer.global_shader_parameter_get("xray_mech_a")) == TYPE_VECTOR3, "xray_mech_a global exists")
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
```
Run: `godot --headless --path godot_director_spike -s res://tests/xray_check.gd` → `ALL PASS`, exit 0. (If a global reads null, the `project.godot` `[shader_globals]` block is wrong — fix it.) Commit it:
```bash
git add godot_director_spike/tests/xray_check.gd
git commit -m "test(render): x-ray global-shader-param wiring check"
```

- [ ] **Step 2: Full regression — all green, hash unchanged**

```bash
for t in shot_grammar_check grade_check time_emphasis_check continuity_check sightline_check xray_check hybrid_check director_check; do
  echo "=== $t ==="; godot --headless --path godot_director_spike -s res://tests/$t.gd 2>/dev/null | grep -E "ALL PASS|FAIL|got hash"
done
```
Expected: every suite `---- ALL PASS`; `hybrid_check` `got hash 2543717900`.

- [ ] **Step 3: Visual (windowed) — the x-ray window reads**

```bash
godot --path godot_director_spike --quit-after 1800 -- --director=hybrid --log=fight_log_melee --armor --frames
godot --path godot_director_spike --quit-after 2500 -- --director=hybrid --log=fight_log_everything --armor --frames
```
Open the `tmp/frame_hybrid_*.png` frames: a wall in front of a mech shows a soft round window with the real mech inside; the rest of the wall + the background stay solid; the iso top-down view shows the same; no buildings wholesale-vanish; non-occluded buildings look the same as before (lit, roughness 0.7). Tuning dials: `xray_radius` (14) / `xray_softness` (5) in `project.godot` (or the grammar). **This is the owner's review point.**

- [ ] **Step 4: Done** — report for owner comment.

---

## Self-review
- Spec coverage: shader (capsule sightline cut, hashed discard, lit parity) Task 1; window params Task 2; material swap + feed + destruction cast + fade-call removal (atomic) Task 3; dead-code delete Task 4; wiring test + regression + visual Task 5. Window child meshes get the shader (Task 3 Step 1). Dead mechs keep their window (both fed every frame, Task 3 Step 2).
- Determinism gate (`hash 2543717900`) asserted in Tasks 3, 4, 5.
- Risk: the shader is the one un-unit-testable piece — Task 3 Step 5 is the explicit compile-validation gate (render boot), iterate there.
