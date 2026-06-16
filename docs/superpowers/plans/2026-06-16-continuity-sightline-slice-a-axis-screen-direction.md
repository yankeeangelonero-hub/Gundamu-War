# Continuity-Aware Camera — Slice A: Axis + Screen Direction — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the perspective cut-ins (`hero_os`, `hero_cut`) on one consistent side of the A↔B action axis so the two mechs never swap screen sides on a cut (the 180° rule, F32/F33).

**Architecture:** Key the camera's side of the action axis once at fight start (from the initial camera position). For each cut-in, choose the sign of the authored `lateral` offset so the camera lands on that keyed side — flipping it when the default would cross the line. Pure axis-side math; presentation-only (runtime camera), so the shot list is untouched.

**Tech Stack:** Godot 4.6, GDScript. Godot binary: `godot` on PATH (Godot 4.6.3). Headless test: `godot --headless --path godot_director_spike -s res://tests/<name>.gd` (judge PASS/FAIL lines + exit code; RID/leak warnings on shutdown are noise). A brand-new GDScript needs a `godot --headless --path godot_director_spike --import` pass before its `class_name` registers.

This is **Slice A** of the unified design `docs/superpowers/specs/2026-06-16-continuity-and-sightline-camera-design.md`. Slice B (the sightline occlusion module + clear-pose search + precise fade + iso fallback) is a separate plan that layers onto the same pose pipeline after A ships.

**Guardrails for the implementer:** never run `git checkout`/`switch`/`branch`/`stash`/`reset` (stay on branch `combat-feel-restart`); Godot HEADLESS only; on an "unknown class" error run the `--import` pass once then re-run; no `Co-Authored-By` trailer in commits; repo root is `D:\Claude\Mech Bags` (ignore any `cd /d/claude/Gundamu-War` lines).

---

## File structure

- `godot_director_spike/scripts/director.gd` — base director. Gains: `_axis_keyed_side` member, a static `_axis_side(...)` pure helper, the keying in `start()`, and a static `_keyed_lateral(...)` pure helper used by the cut-ins.
- `godot_director_spike/scripts/directors/hybrid.gd` — the `hero_os` and `hero_cut` cases call `_keyed_lateral(...)` instead of using the raw `fr.lateral`.
- `godot_director_spike/tests/continuity_check.gd` — new headless unit test for `_axis_side` and `_keyed_lateral`.

Determinism note for every task: these changes are in the runtime camera path (`start()` keying + `_update_camera` cut-in poses), NOT in `build_shot_list`. The golden shot-list hash `2543717900` (asserted by `tests/hybrid_check.gd`) MUST stay unchanged.

---

### Task 1: Axis-side helper + keyed side at fight start

**Files:**
- Modify: `godot_director_spike/scripts/director.gd` (add member + `_axis_side` + key in `start()`)
- Test: `godot_director_spike/tests/continuity_check.gd` (new)

- [ ] **Step 1: Write the failing test**

Create `godot_director_spike/tests/continuity_check.gd`:

```gdscript
extends SceneTree
## Headless unit test for the 180° continuity helpers (Slice A): which side of the
## A<->B action axis a camera sits on, and the keyed-lateral sign choice.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func _init() -> void:
	var Director := load("res://scripts/director.gd")
	check(Director != null, "director.gd loads")
	# A at x=-40, B at x=+40 (the standard duel). A camera on the +Z side is one
	# side of the axis; the mirror on -Z is the other.
	var a := Vector3(-40, 0, 0)
	var b := Vector3(40, 0, 0)
	check(Director._axis_side(Vector3(0, 45, 90), a, b) == 1, "+Z camera -> axis side +1")
	check(Director._axis_side(Vector3(0, 45, -90), a, b) == -1, "-Z camera -> axis side -1")
	# Mirroring the point across the axis flips the side.
	check(Director._axis_side(Vector3(13, 20, 50), a, b) == -Director._axis_side(Vector3(13, 20, -50), a, b),
		"mirror across the axis flips the side")

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot_director_spike -s res://tests/continuity_check.gd`
Expected: FAIL — `Invalid call ... '_axis_side'` (method missing), exit 1.

- [ ] **Step 3: Add the member, the `_axis_side` helper, and the keying**

In `godot_director_spike/scripts/director.gd`, add a member near the other director state vars (e.g. by `var shots`/`var camera`):

```gdscript
var _axis_keyed_side := 1   # which side of the A<->B axis the cut-ins stay on (F32)
```

Add this static helper (place it near the other camera helpers, e.g. by `_resolve_occlusion`):

```gdscript
## Which side of the A<->B action axis a point sits on, in the horizontal plane
## (+1 or -1). Pure — used to hold the cut-ins on one side of the 180° line (F32).
static func _axis_side(p: Vector3, a_pos: Vector3, b_pos: Vector3) -> int:
	var axis := b_pos - a_pos
	axis.y = 0.0
	var rel := p - a_pos
	rel.y = 0.0
	return 1 if axis.cross(Vector3.UP).dot(rel) >= 0.0 else -1
```

In `start()`, after `actors = p_actors` / `camera = p_camera` are set (after the existing `if actors.has("A") and actors.has("B"):` combat-face block is fine), add:

```gdscript
	# Key the camera's side of the action axis once, from the opening camera pose
	# (F32/F33): every cut-in is then held on this side so the two mechs never swap
	# screen sides on a cut.
	if actors.has("A") and actors.has("B") and camera != null:
		_axis_keyed_side = _axis_side(camera.position, actors["A"].position, actors["B"].position)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path godot_director_spike -s res://tests/continuity_check.gd`
Expected: `---- ALL PASS`, exit 0. (If the engine reports an unknown class, run `godot --headless --path godot_director_spike --import` once and re-run.)

- [ ] **Step 5: Confirm the shot-list hash is unchanged**

Run: `godot --headless --path godot_director_spike -s res://tests/hybrid_check.gd`
Expected: `---- ALL PASS`, `got hash 2543717900`, exit 0. (This task only adds a keyed member + a pure helper; nothing in `build_shot_list` changed.)

- [ ] **Step 6: Commit**

```bash
git add godot_director_spike/scripts/director.gd godot_director_spike/tests/continuity_check.gd
git commit -m "feat(director): axis-side helper + keyed action-axis side at fight start (F32/F33)"
```

---

### Task 2: Cut-ins stay on the keyed side

**Files:**
- Modify: `godot_director_spike/scripts/director.gd` (add `_keyed_lateral`)
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` (`hero_os`, `hero_cut` use it)
- Test: `godot_director_spike/tests/continuity_check.gd` (append)

- [ ] **Step 1: Write the failing test**

Append to `tests/continuity_check.gd`, before the final `print(...)`/`quit(...)`:

```gdscript
	# --- _keyed_lateral picks the sign that lands on the keyed side ---
	# Focus mech f at A, other at B; a positive lateral offset puts the camera on
	# some side; _keyed_lateral must return whichever sign matches keyed_side.
	var f := Vector3(-40, 0, 0)
	var o := Vector3(40, 0, 0)
	var raw := 9.0   # authored lateral magnitude
	var lat_plus := Director._keyed_lateral(f, o, 2.0, 5.0, raw, a, b, 1)
	var lat_minus := Director._keyed_lateral(f, o, 2.0, 5.0, raw, a, b, -1)
	# The two keyed sides must produce opposite-signed laterals.
	check(signf(lat_plus) == -signf(lat_minus), "keyed sides +1/-1 give opposite lateral signs")
	check(absf(lat_plus) == raw and absf(lat_minus) == raw, "magnitude preserved, only sign flips")
	# And the returned sign actually lands the camera on the requested side.
	_assert_side(Director, f, o, lat_plus, a, b, 1)
	_assert_side(Director, f, o, lat_minus, a, b, -1)
```

Add this helper method to the test (above `_init`), so the side-landing assertion is reusable:

```gdscript
func _assert_side(Director, f: Vector3, o: Vector3, lat: float, a: Vector3, b: Vector3, want: int) -> void:
	var d := (o - f).normalized()
	var p := f - d * 2.0 + d.cross(Vector3.UP) * lat + Vector3(0, 5.0, 0)
	check(Director._axis_side(p, a, b) == want, "keyed_lateral sign lands on side %d" % want)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot_director_spike -s res://tests/continuity_check.gd`
Expected: FAIL — `Invalid call ... '_keyed_lateral'`, exit 1.

- [ ] **Step 3: Add `_keyed_lateral` to director.gd**

In `godot_director_spike/scripts/director.gd`, add (near `_axis_side`):

```gdscript
## The authored lateral offset, signed so a cut-in's camera lands on `keyed_side`
## of the A<->B axis (F32). Flipping the lateral mirrors the camera across the axis
## (the offset is perpendicular to it), so this guarantees the keyed side. Pure.
static func _keyed_lateral(f_pos: Vector3, o_pos: Vector3, pullback: float, height: float, lateral: float, a_pos: Vector3, b_pos: Vector3, keyed_side: int) -> float:
	var d := (o_pos - f_pos).normalized()
	var p := f_pos - d * pullback + d.cross(Vector3.UP) * lateral + Vector3(0, height, 0)
	return lateral if _axis_side(p, a_pos, b_pos) == keyed_side else -lateral
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path godot_director_spike -s res://tests/continuity_check.gd`
Expected: `---- ALL PASS`, exit 0.

- [ ] **Step 5: Use `_keyed_lateral` in the cut-ins**

In `godot_director_spike/scripts/directors/hybrid.gd`, in `_update_camera`, `a` and `b` are already locals (`var a: Node3D = actors["A"]`, `var b: Node3D = actors["B"]`). Change the `hero_os` case: replace its `pos = ...` line

```gdscript
			pos = f.position - d * fr.pullback + d.cross(Vector3.UP) * fr.lateral + Vector3(0, fr.height, 0)
```

with a keyed-lateral version:

```gdscript
			var lat_os := _keyed_lateral(f.position, o.position, fr.pullback, fr.height, fr.lateral, a.position, b.position, _axis_keyed_side)
			pos = f.position - d * fr.pullback + d.cross(Vector3.UP) * lat_os + Vector3(0, fr.height, 0)
```

Change the `hero_cut` case identically: replace its `pos = f.position - d * fr.pullback + d.cross(Vector3.UP) * fr.lateral + Vector3(0, fr.height, 0)` line with:

```gdscript
			var lat_cut := _keyed_lateral(f.position, o.position, fr.pullback, fr.height, fr.lateral, a.position, b.position, _axis_keyed_side)
			pos = f.position - d * fr.pullback + d.cross(Vector3.UP) * lat_cut + Vector3(0, fr.height, 0)
```

(Read both cases first to match the exact existing lines; only the `pos` assignment changes. Leave `aim`, `fov`, `_roll` as they are.)

- [ ] **Step 6: Boot smoke + hash unchanged**

Run: `godot --headless --path godot_director_spike --quit-after 300 -- --director=hybrid --log=fight_log_everything`
Expected: `KM-DIRECTOR-SPIKE boot ok`, no `SCRIPT ERROR`/`Parse Error`, exit 0.
Run: `godot --headless --path godot_director_spike -s res://tests/hybrid_check.gd`
Expected: `---- ALL PASS`, `got hash 2543717900`, exit 0. (Cut-in camera poses are runtime/presentation; the shot list is unchanged.)

- [ ] **Step 7: Commit**

```bash
git add godot_director_spike/scripts/director.gd godot_director_spike/scripts/directors/hybrid.gd godot_director_spike/tests/continuity_check.gd
git commit -m "feat(director): hold hero cut-ins on the keyed axis side (180° rule, F32/F33)"
```

---

### Task 3: Regression + visual confirmation

**Files:** none (verification only).

- [ ] **Step 1: Full headless suite — all green, hash unchanged**

```bash
for t in shot_grammar_check grade_check time_emphasis_check continuity_check hybrid_check director_check; do
  echo "=== $t ==="; godot --headless --path godot_director_spike -s res://tests/$t.gd 2>/dev/null | grep -E "ALL PASS|FAIL|got hash"
done
```
Expected: every suite `---- ALL PASS`; `hybrid_check` prints `got hash 2543717900`.

- [ ] **Step 2: Visual (windowed) — mechs hold their screen sides across cut-ins**

```bash
godot --path godot_director_spike --quit-after 2500 -- --director=hybrid --log=fight_log_everything --armor --frames
```
Open the `tmp/frame_hybrid_*.png` frames that land on `hero_os` / `hero_cut` beats. Confirm: across the opening over-shoulder and the mid-fight cut, the same mech stays on the same screen side (no left/right swap between cuts). The iso/orbit beats are unchanged. (This is the owner's tuning checkpoint — `_axis_keyed_side` is keyed from the opening pose; if the chosen side reads wrong, that's a one-line tuning of the keying, not a logic change.)

- [ ] **Step 3: Done**

Slice A complete. Slice B (sightline occlusion module + clear-pose search on the keyed side + precise fade + iso fallback) is the next plan, layering onto this keyed-side pose pipeline.

---

## Notes for Slice B (not this plan)
- Slice B adds `scripts/director/sightline.gd` (multi-ray AABB occlusion), `_pick_clear_pose` (scores keyed-side candidates by clear-ray count + hysteresis + iso fallback below `iso_fallback_min_clear`), the precise quick fade replacing `_resolve_occlusion`'s thin-line body, and the grammar params (`occlusion_fade_time`, `composition_search_arc`, `iso_fallback_min_clear`). The candidate search reuses this slice's keyed-side constraint — candidates are generated on `_axis_keyed_side` only.
