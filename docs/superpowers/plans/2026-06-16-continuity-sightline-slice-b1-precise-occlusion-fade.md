# Continuity-Aware Camera — Slice B1: Precise Multi-Ray Occlusion Fade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the weak thin-center-line occlusion (gradual fade to a still-visible 0.1 alpha) with a precise multi-ray test that fades **only the buildings actually covering the mech's on-screen silhouette**, fully out and quickly — so a foreground building no longer buries the perspective shot, without emptying the scene.

**Architecture:** A new pure `Sightline.evaluate()` casts a ray from the camera to each of ~5 silhouette sample points around the look target and returns which building AABBs block any ray (exact for boxes). `_resolve_occlusion` (shared by every director) uses it to fade the true occluders to full transparency at a fast rate, restoring the rest. Presentation-only (material alpha); the shot list is untouched.

**Tech Stack:** Godot 4.6, GDScript. Godot binary `godot` on PATH (4.6.3). Headless test: `godot --headless --path godot_director_spike -s res://tests/<name>.gd`. A new GDScript with a `class_name` needs a `godot --headless --path godot_director_spike --import` pass before its class registers.

This is **Slice B1** of `docs/superpowers/specs/2026-06-16-continuity-and-sightline-camera-design.md` — the *reactive* occlusion fix. **Slice B2** (the proactive composition search: keyed-side candidate poses scored by clear-ray count + iso fallback) is a separate plan that layers on after B1 is seen in action. Slice A (axis/screen-direction continuity) already shipped.

**Deviation from the spec, intentional:** the spec floated `occlusion_fade_time` as a grammar param, but the base `director.gd` occlusion uses **consts** (`FADE_NEAR`, `FADE_MIN`) and has no instance grammar. To match that idiom (and avoid a `_grammar`-to-base refactor), the fade rate is a **const** here. Promoting it to the grammar (with a `_grammar`-to-base move) is a later polish if tuning needs it.

**Guardrails for the implementer:** never run `git checkout`/`switch`/`branch`/`stash`/`reset` (stay on `combat-feel-restart`); Godot HEADLESS only; on an "unknown class" error run the `--import` pass once then re-run; no `Co-Authored-By` trailer; repo root `D:\Claude\Mech Bags`.

---

## File structure
- `godot_director_spike/scripts/director/sightline.gd` — NEW. Pure `Sightline.evaluate(cam_pos, subject_points, buildings)`.
- `godot_director_spike/tests/sightline_check.gd` — NEW. Unit test for `evaluate`.
- `godot_director_spike/scripts/director.gd` — MODIFY. `_silhouette_points` helper; rewrite `_resolve_occlusion` body to use `Sightline`; add a `FADE_RATE` const and full-hide (0.0) occluders.

Determinism note (every task): all changes are in the runtime camera/occlusion path (presentation — material alpha). `build_shot_list` is untouched, so the golden hash `2543717900` (`tests/hybrid_check.gd`) MUST stay unchanged.

---

### Task 1: The pure multi-ray sightline test

**Files:**
- Create: `godot_director_spike/scripts/director/sightline.gd`
- Test: `godot_director_spike/tests/sightline_check.gd`

- [ ] **Step 1: Write the failing test** — create `tests/sightline_check.gd`:

```gdscript
extends SceneTree
## Unit test for the multi-ray occlusion test (Slice B1): which buildings block the
## camera->subject silhouette rays, exact ray-vs-AABB.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func _bld(pos: Vector3, size: Vector3) -> Node3D:
	var n := Node3D.new()
	n.set_meta("aabb", AABB(pos, size))
	return n

func _init() -> void:
	var S := load("res://scripts/director/sightline.gd")
	check(S != null, "sightline.gd loads")
	var cam := Vector3(0, 10, 50)
	# 5 silhouette points around a subject at the origin column (feet/upper, +/- shoulders).
	var subj := [Vector3(0, 2, 0), Vector3(0, 10, 0), Vector3(0, 18, 0), Vector3(-6, 10, 0), Vector3(6, 10, 0)]

	var r0: Dictionary = S.evaluate(cam, subj, [])
	check(r0.clear_count == 5, "no buildings -> all 5 rays clear")
	check(r0.occluders.is_empty(), "no buildings -> no occluders")

	var wall := _bld(Vector3(-10, 0, 20), Vector3(20, 30, 4))   # spans the whole column at z~20
	var r1: Dictionary = S.evaluate(cam, subj, [wall])
	check(r1.occluders.has(wall), "center wall is an occluder")
	check(r1.clear_count < 5, "center wall blocks at least one ray")

	var side := _bld(Vector3(40, 0, 20), Vector3(8, 30, 4))     # far to the right, on no ray
	var r2: Dictionary = S.evaluate(cam, subj, [side])
	check(r2.occluders.is_empty(), "off-side building does not occlude")
	check(r2.clear_count == 5, "off-side building leaves all rays clear")

	# The key win over the old thin-center-line: an off-center building covering only
	# the +shoulder ray is still caught.
	var shoulder := _bld(Vector3(3, 0, 20), Vector3(5, 30, 4))  # x:[3,8], catches the +6 ray, misses center
	var r3: Dictionary = S.evaluate(cam, subj, [shoulder])
	check(r3.occluders.has(shoulder), "off-center shoulder occluder caught (multi-ray > thin line)")
	check(r3.clear_count == 4, "exactly the shoulder ray is blocked")

	wall.free(); side.free(); shoulder.free()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
```

- [ ] **Step 2: Run it — expect FAIL**

Run: `godot --headless --path godot_director_spike -s res://tests/sightline_check.gd`
Expected: FAIL — `sightline.gd loads` fails (script missing) / null call, exit 1.

- [ ] **Step 3: Create the module** — `godot_director_spike/scripts/director/sightline.gd`:

```gdscript
extends RefCounted
class_name Sightline
## Multi-ray occlusion test (Slice B1). Casts a ray from the camera to each subject
## silhouette sample point and tests it against the building AABBs (exact for boxes).
## Pure + deterministic. Drives the precise occlusion fade (and later the composition
## search). Spec: docs/superpowers/specs/2026-06-16-continuity-and-sightline-camera-design.md

## Returns { "clear_count": int, "occluders": Array }. clear_count = subject points
## reached with no building between; occluders = buildings blocking >=1 ray (deduped).
static func evaluate(cam_pos: Vector3, subject_points: Array, buildings: Array) -> Dictionary:
	var occluders: Array = []
	var clear := 0
	for sp in subject_points:
		var blocked := false
		for bld in buildings:
			var aabb: AABB = bld.get_meta("aabb")
			if aabb.intersects_segment(cam_pos, sp) != null:
				blocked = true
				if not occluders.has(bld):
					occluders.append(bld)
		if not blocked:
			clear += 1
	return {"clear_count": clear, "occluders": occluders}
```

- [ ] **Step 4: Run it — expect PASS**

Run: `godot --headless --path godot_director_spike -s res://tests/sightline_check.gd`
Expected: `---- ALL PASS`, exit 0. (If "unknown class Sightline", run the `--import` pass once, then re-run.)

- [ ] **Step 5: Commit**

```bash
git add godot_director_spike/scripts/director/sightline.gd godot_director_spike/tests/sightline_check.gd
git commit -m "feat(director): pure multi-ray sightline occlusion test (Slice B1)"
```

---

### Task 2: Use the sightline test in `_resolve_occlusion` (precise full fade)

**Files:**
- Modify: `godot_director_spike/scripts/director.gd` (`_resolve_occlusion`, `_fade_building`, add `_silhouette_points` + a `FADE_RATE` const)

- [ ] **Step 1: Add the silhouette-points helper + a faster fade rate const**

In `godot_director_spike/scripts/director.gd`, near the `FADE_NEAR`/`FADE_MIN` consts (~:317), add:

```gdscript
const FADE_RATE := 0.45    # per-frame lerp toward the occlusion target (faster than the old 0.18 — a quick ~3-frame clear, no hard snap)
```

Add this helper (near `_resolve_occlusion`):

```gdscript
## Silhouette sample points around the look target for the multi-ray occlusion test
## — feet / upper-body / both shoulders — so an off-center building covering the mech
## is caught, not just one dead-center ray. `aim` is the look point.
func _silhouette_points(pos: Vector3, aim: Vector3) -> Array:
	var fwd := aim - pos
	fwd.y = 0.0
	var right := (fwd.cross(Vector3.UP).normalized() if fwd.length() > 0.01 else Vector3.RIGHT)
	return [
		aim,
		aim + Vector3(0, 5.0, 0),    # upper body / head
		aim - Vector3(0, 9.0, 0),    # toward the feet
		aim + right * 5.0,           # one shoulder
		aim - right * 5.0,           # other shoulder
	]
```

- [ ] **Step 2: Rewrite `_resolve_occlusion` to use the sightline test**

Read the current `_resolve_occlusion` (it loops `kb_building`, tests `aabb.intersects_segment(pos, aim)` on the thin line, fades to `FADE_MIN`/1.0). Replace its body with:

```gdscript
func _resolve_occlusion(pos: Vector3, aim: Vector3) -> Vector3:
	var buildings := get_tree().get_nodes_in_group("kb_building")
	var occ: Array = Sightline.evaluate(pos, _silhouette_points(pos, aim), buildings).occluders
	for bld in buildings:
		# A building covering the mech's silhouette (occ) OR one the lens is nearly
		# inside (FADE_NEAR) clears fully; everything else restores.
		var near := (bld.get_meta("aabb") as AABB).grow(FADE_NEAR).has_point(pos)
		_fade_building(bld, 0.0 if (occ.has(bld) or near) else 1.0)
	return pos
```

- [ ] **Step 3: Make `_fade_building` use the faster rate**

In `_fade_building`, change the lerp rate literal `0.18` to `FADE_RATE`. The line currently reads `var a := lerpf(mat.albedo_color.a, target, 0.18)` — change `0.18` to `FADE_RATE`. Leave the rest of `_fade_building` (the transparency selection, the window-pop) unchanged. (Occluders now target `0.0` instead of the old `FADE_MIN` 0.1, so they clear fully; `FADE_MIN` is no longer referenced by `_resolve_occlusion` — leave the const in place, other call sites may use it.)

- [ ] **Step 4: Boot smoke + hash unchanged**

Run: `godot --headless --path godot_director_spike --quit-after 300 -- --director=hybrid --log=fight_log_everything`
Expected: `KM-DIRECTOR-SPIKE boot ok`, no `SCRIPT ERROR`/`Parse Error`, exit 0. (If "unknown class Sightline" — run the `--import` pass once, re-run.)
Run: `godot --headless --path godot_director_spike -s res://tests/hybrid_check.gd`
Expected: `---- ALL PASS`, `got hash 2543717900`, exit 0. (Occlusion is presentation; the shot list is unchanged. If the hash changed, STOP and report BLOCKED.)

- [ ] **Step 5: Commit**

```bash
git add godot_director_spike/scripts/director.gd
git commit -m "feat(director): precise multi-ray occlusion fade replaces the thin-line dissolve (Slice B1)"
```

---

### Task 3: Regression + visual confirmation

**Files:** none (verification only).

- [ ] **Step 1: Full headless suite — all green, hash unchanged**

```bash
for t in shot_grammar_check grade_check time_emphasis_check continuity_check sightline_check hybrid_check director_check; do
  echo "=== $t ==="; godot --headless --path godot_director_spike -s res://tests/$t.gd 2>/dev/null | grep -E "ALL PASS|FAIL|got hash"
done
```
Expected: every suite `---- ALL PASS`; `hybrid_check` prints `got hash 2543717900`.

- [ ] **Step 2: Visual (windowed) — the buildings no longer bury the shot**

```bash
godot --path godot_director_spike --quit-after 2500 -- --director=hybrid --log=fight_log_melee --armor --frames
godot --path godot_director_spike --quit-after 2500 -- --director=hybrid --log=fight_log_everything --armor --frames
```
Open the `tmp/frame_hybrid_*.png` frames on the close/cut beats. Confirm: a foreground building covering the mech now **fades fully out** (not a faint 0.1 ghost), buildings **off** the silhouette stay solid (the city is NOT emptied — contrast with the reverted wide-corridor attempt), and the fade reads quick + smooth (no hard snap). This is the owner's tuning checkpoint — `FADE_RATE` (clear speed) and the silhouette offsets are the dials.

- [ ] **Step 3: Done**

Slice B1 complete. Slice B2 (proactive composition search: generate keyed-side candidate poses, score each with `Sightline.evaluate().clear_count`, pick the clearest with hysteresis, iso fallback below threshold) is the next plan — it reuses this `Sightline` module and Slice A's keyed-side constraint.

---

## Self-review notes
- Spec coverage: B1 implements the precise multi-ray fade (spec "Hide" + the sightline module). Composition search + iso fallback are B2 (scoped out). Determinism gate asserted in Task 2/3.
- The `Sightline.evaluate` signature (`cam_pos, subject_points, buildings) -> {clear_count, occluders}`) is identical in the test (Task 1) and the consumer (`_resolve_occlusion`, Task 2). `_silhouette_points(pos, aim)` defined and used in Task 2. `FADE_RATE` defined (Task 2 Step 1) and used (Task 2 Step 3).
