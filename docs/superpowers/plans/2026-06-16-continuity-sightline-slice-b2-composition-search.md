# Continuity-Aware Camera — Slice B2: Composition Search — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Proactively aim the perspective close shots at a clear sightline — search a few candidate camera poses, score each by how many of the mech's silhouette rays are unobstructed (the Slice-B1 `Sightline` test), and use the clearest, with hysteresis to avoid jitter. Fixes the residual "camera angle pointed at a wall" burial (the melee close-up frame-07 case) that the reactive fade alone can't.

**Architecture:** A pure `_pick_clear_pose(candidates, aim, buildings, prev_idx, margin)` scores an ordered set of candidate camera positions via `Sightline.evaluate().clear_count` and returns the best index, keeping the previous pick unless another beats it by `margin` (hysteresis). `melee_cut` generates candidates by perturbing its orbit ANGLE within `composition_search_arc`; `hero_os`/`hero_cut` generate candidates by scaling their (keyed-side, from Slice A) LATERAL offset. `bullet_time` (the kill cam) and `iso` are untouched. Presentation-only → shot list / hash unchanged.

**Tech Stack:** Godot 4.6, GDScript. `godot` on PATH (4.6.3). Headless test: `godot --headless --path godot_director_spike -s res://tests/<name>.gd`.

This is **Slice B2** of `docs/superpowers/specs/2026-06-16-continuity-and-sightline-camera-design.md`. Builds on Slice A (keyed-side cut-ins) + Slice B1 (the `Sightline` module + precise fade). **Deferred to a later B2b:** the iso fallback (cut to the iso backbone when no same-side cut-in pose clears) — for now a cut-in uses its best same-side candidate. **Out of scope:** `bullet_time` (the proven kill cam; CLAUDE.md: "do not displace the bullet-time kill") and `iso`.

**Guardrails for the implementer:** never run `git checkout`/`switch`/`branch`/`stash`/`reset` (stay on `combat-feel-restart`); Godot HEADLESS only; on an "unknown class" error run `godot --headless --path godot_director_spike --import` once then re-run; no `Co-Authored-By` trailer; repo root `D:\Claude\Mech Bags`.

Determinism note (every task): the pose search is presentation-only (`Sightline` is pure AABB math; building positions are deterministic; `_pick_idx` is deterministic state). `build_shot_list` is untouched → golden hash `2543717900` (`tests/hybrid_check.gd`) MUST stay unchanged.

---

## File structure
- `godot_director_spike/scripts/director.gd` — make `_silhouette_points` static; add `_pick_clear_pose` (static) + a `_pick_idx` member reset on shot change.
- `godot_director_spike/scripts/director/shot_grammar.gd` — add `composition_search_arc`.
- `godot_director_spike/scripts/directors/hybrid.gd` — `melee_cut` orbit-angle search; `hero_os`/`hero_cut` lateral-magnitude search; reset `_pick_idx` when the shot changes.
- `godot_director_spike/tests/shot_grammar_check.gd` — assert the new param.
- `godot_director_spike/tests/sightline_check.gd` — append `_pick_clear_pose` unit tests.

---

### Task 1: Grammar param + make `_silhouette_points` static

**Files:**
- Modify: `godot_director_spike/scripts/director/shot_grammar.gd` + `tests/shot_grammar_check.gd`
- Modify: `godot_director_spike/scripts/director.gd` (`_silhouette_points` → `static`)

- [ ] **Step 1: Write the failing test** — append to `tests/shot_grammar_check.gd`, with the other checks (reuse `g`):

```gdscript
	# --- Phase 4/Slice B2: composition search ---
	check(is_equal_approx(g.composition_search_arc, 0.6), "composition_search_arc == 0.6 rad")
```

- [ ] **Step 2: Run — expect FAIL**

`godot --headless --path godot_director_spike -s res://tests/shot_grammar_check.gd` → FAIL `Invalid access ... 'composition_search_arc'`, exit 1.

- [ ] **Step 3: Add the param + make the helper static**

In `shot_grammar.gd`, add to the Composition area (near `framing` or the iso block):
```gdscript
# How far (radians for orbits / scaled for cut-ins) the composition search may swing
# a perspective shot to find a clear sightline to the mech (Slice B2).
@export var composition_search_arc: float = 0.6
```
In `director.gd`, change `func _silhouette_points(pos: Vector3, aim: Vector3) -> Array:` to `static func _silhouette_points(pos: Vector3, aim: Vector3) -> Array:` (its body uses only its params + engine constants, so it is already pure). `_resolve_occlusion` still calls `_silhouette_points(pos, aim)` unchanged (a static method is callable from an instance method).

- [ ] **Step 4: Run — expect PASS**

`godot --headless --path godot_director_spike -s res://tests/shot_grammar_check.gd` → `---- ALL PASS`, exit 0.

- [ ] **Step 5: Confirm hash unchanged**

`godot --headless --path godot_director_spike -s res://tests/hybrid_check.gd` → `---- ALL PASS`, `got hash 2543717900`.

- [ ] **Step 6: Commit**

```bash
git add godot_director_spike/scripts/director/shot_grammar.gd godot_director_spike/scripts/director.gd godot_director_spike/tests/shot_grammar_check.gd
git commit -m "feat(grammar): composition_search_arc param; make _silhouette_points static (Slice B2)"
```

---

### Task 2: `_pick_clear_pose` (pure scorer + hysteresis)

**Files:**
- Modify: `godot_director_spike/scripts/director.gd` (add `_pick_clear_pose` + `_pick_idx` member)
- Test: `godot_director_spike/tests/sightline_check.gd` (append)

- [ ] **Step 1: Write the failing test** — append to `tests/sightline_check.gd`, before the final `print(...)`/`quit(...)`. (Reuse the `_bld` helper already in that file.)

```gdscript
	# --- _pick_clear_pose: choose the candidate with the most clear rays ---
	var Director := load("res://scripts/director.gd")
	var aim2 := Vector3(0, 10, 0)
	# Three candidate camera positions; a wall blocks the middle one's view of the subject.
	var cands := [Vector3(-40, 10, 20), Vector3(0, 10, 40), Vector3(40, 10, 20)]
	var wall2 := _bld(Vector3(-6, 0, 18), Vector3(12, 30, 4))   # sits between cand[1] and aim
	# prev_idx = 1 (the now-blocked middle); margin 1 -> should switch to a clear one.
	var pk: Dictionary = Director._pick_clear_pose(cands, aim2, [wall2], 1, 1)
	check(pk.idx != 1, "pick switches off the blocked candidate")
	check(pk.clear > Director._pick_clear_pose([cands[1]], aim2, [wall2], 0, 1).clear, "chosen candidate is clearer than the blocked one")
	# hysteresis: with no buildings all candidates tie -> keep prev_idx (no jitter).
	var pk2: Dictionary = Director._pick_clear_pose(cands, aim2, [], 2, 1)
	check(pk2.idx == 2, "on a tie, hysteresis keeps the previous pick")
	wall2.free()
```

- [ ] **Step 2: Run — expect FAIL**

`godot --headless --path godot_director_spike -s res://tests/sightline_check.gd` → FAIL `Invalid call ... '_pick_clear_pose'`, exit 1.

- [ ] **Step 3: Add `_pick_clear_pose` + `_pick_idx`**

In `director.gd`, add a member near the other camera state (e.g. by `_axis_keyed_side`):
```gdscript
var _pick_idx := -1   # composition-search hysteresis: the candidate index held across frames
```
Add the static scorer (near `_silhouette_points`):
```gdscript
## Pick the candidate camera position with the most clear silhouette rays toward
## `aim`. `candidates` is an ordered array of Vector3 whose index pattern is stable
## across frames (e.g. angle offsets [-arc..+arc]). Keeps `prev_idx` unless another
## candidate beats its clear ray count by `margin` (hysteresis — damps jitter).
## Returns { "idx": int, "pos": Vector3, "clear": int }. Pure.
static func _pick_clear_pose(candidates: Array, aim: Vector3, buildings: Array, prev_idx: int, margin: int) -> Dictionary:
	if candidates.is_empty():
		return {"idx": -1, "pos": aim, "clear": 0}
	var cur := prev_idx if (prev_idx >= 0 and prev_idx < candidates.size()) else int(candidates.size() / 2)
	var scores: Array = []
	for c in candidates:
		scores.append(Sightline.evaluate(c, _silhouette_points(c, aim), buildings).clear_count)
	var top := 0
	for i in candidates.size():
		if scores[i] > scores[top]:
			top = i
	var chosen := cur
	if scores[top] >= scores[cur] + margin:
		chosen = top
	return {"idx": chosen, "pos": candidates[chosen], "clear": scores[chosen]}
```

- [ ] **Step 4: Run — expect PASS**

`godot --headless --path godot_director_spike -s res://tests/sightline_check.gd` → `---- ALL PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot_director_spike/scripts/director.gd godot_director_spike/tests/sightline_check.gd
git commit -m "feat(director): _pick_clear_pose composition scorer with hysteresis (Slice B2)"
```

---

### Task 3: melee_cut orbit-angle search (the frame-07 fix)

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` (`melee_cut` case + reset `_pick_idx` on shot change)

- [ ] **Step 1: Reset the hysteresis index when the shot changes**

In `hybrid.gd`, the base `director.gd`'s `_update_shot()` advances `_shot_idx` (it sets `Engine.time_scale` there). Add a `_pick_idx` reset so each new shot starts its search fresh. In `director.gd _update_shot()`, where `_shot_idx` is incremented (the `while ... _shot_idx += 1` loop), add after the increment:
```gdscript
		_pick_idx = -1   # reset the composition-search hysteresis for the new shot
```

- [ ] **Step 2: Search the melee orbit angle**

In `hybrid.gd`, replace the `melee_cut` case body's pose computation. Current:
```gdscript
		"melee_cut":
			# Tight, slightly slow close-up orbiting the blade clash point.
			var fr: Dictionary = _grammar.framing[s.mode]
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var contact := f.position.lerp(o.position, 0.5) + Vector3(0, 11, 0)
			var ang := PI * 0.25 + _wall * 0.6
			pos = contact + Vector3(cos(ang) * fr.radius, fr.height, sin(ang) * fr.radius)
			aim = contact
			fov = fr.fov
```
Replace the `pos = ...` line with an angle search (generate 5 candidate angles around the authored one, pick the clearest):
```gdscript
			var arc: float = _grammar.composition_search_arc
			var cands: Array = []
			for off in [-arc, -arc * 0.5, 0.0, arc * 0.5, arc]:
				var aa := ang + off
				cands.append(contact + Vector3(cos(aa) * fr.radius, fr.height, sin(aa) * fr.radius))
			var pick := _pick_clear_pose(cands, contact, get_tree().get_nodes_in_group("kb_building"), _pick_idx, 2)
			_pick_idx = pick.idx
			pos = pick.pos
```
Leave `aim = contact` and `fov = fr.fov` as they are. (The authored angle is candidate index 2, the middle — so when all are blocked equally or clear, the search keeps the authored orbit; it only swings when a clearer angle exists.)

- [ ] **Step 3: Boot smoke + hash unchanged**

`godot --headless --path godot_director_spike --quit-after 400 -- --director=hybrid --log=fight_log_melee` → `KM-DIRECTOR-SPIKE boot ok`, no errors, exit 0.
`godot --headless --path godot_director_spike -s res://tests/hybrid_check.gd` → `---- ALL PASS`, `got hash 2543717900`. (Camera pose is presentation; the shot list is unchanged.)

- [ ] **Step 4: Commit**

```bash
git add godot_director_spike/scripts/director.gd godot_director_spike/scripts/directors/hybrid.gd
git commit -m "feat(director): melee_cut searches its orbit angle for a clear view (Slice B2)"
```

---

### Task 4: hero_os / hero_cut keyed-side lateral search

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` (`hero_os`, `hero_cut`)

- [ ] **Step 1: Search the keyed-side lateral magnitude for `hero_os`**

In `hybrid.gd`, the `hero_os` case currently computes (after Slice A):
```gdscript
			var lat_os := _keyed_lateral(f.position, o.position, fr.pullback, fr.height, fr.lateral, a.position, b.position, _axis_keyed_side)
			pos = f.position - d * fr.pullback + d.cross(Vector3.UP) * lat_os + Vector3(0, fr.height, 0)
```
Replace the `pos = ...` line with a candidate search over lateral magnitudes (all on the keyed side, since `lat_os` already carries the keyed sign):
```gdscript
			var cands_os: Array = []
			for scale in [0.6, 0.85, 1.0, 1.3, 1.7]:
				cands_os.append(f.position - d * fr.pullback + d.cross(Vector3.UP) * (lat_os * scale) + Vector3(0, fr.height, 0))
			var pick_os := _pick_clear_pose(cands_os, aim, get_tree().get_nodes_in_group("kb_building"), _pick_idx, 2)
			_pick_idx = pick_os.idx
			pos = pick_os.pos
```
IMPORTANT: this must come AFTER `aim` is set for `hero_os` (the search scores against `aim`). Read the case — `aim = o.position + Vector3(0, 10, 0)` is set after the `pos` line currently. Reorder so `aim` is computed BEFORE the candidate search (move the `aim = ...` line above the search, or compute the search after it). The search needs the final `aim`.

- [ ] **Step 2: Same for `hero_cut`**

The `hero_cut` case (after Slice A) computes `lat_cut` then `pos = ...`, with `aim = mid + Vector3(0, 9, 0)` and `_roll = fr.roll`. Ensure `aim` is set first, then replace its `pos = ...` line with the same pattern using `lat_cut` and `cands_cut`/`pick_cut` local names:
```gdscript
			var cands_cut: Array = []
			for scale in [0.6, 0.85, 1.0, 1.3, 1.7]:
				cands_cut.append(f.position - d * fr.pullback + d.cross(Vector3.UP) * (lat_cut * scale) + Vector3(0, fr.height, 0))
			var pick_cut := _pick_clear_pose(cands_cut, aim, get_tree().get_nodes_in_group("kb_building"), _pick_idx, 2)
			_pick_idx = pick_cut.idx
			pos = pick_cut.pos
```
Leave `aim`, `fov`, `_roll` otherwise unchanged.

- [ ] **Step 3: Boot smoke + hash unchanged**

`godot --headless --path godot_director_spike --quit-after 400 -- --director=hybrid --log=fight_log_everything` → `boot ok`, no errors, exit 0.
`godot --headless --path godot_director_spike -s res://tests/hybrid_check.gd` → `---- ALL PASS`, `got hash 2543717900`. If the hash changed, STOP and report BLOCKED.

- [ ] **Step 4: Commit**

```bash
git add godot_director_spike/scripts/directors/hybrid.gd
git commit -m "feat(director): hero cut-ins search keyed-side lateral for a clear view (Slice B2)"
```

---

### Task 5: Regression + visual confirmation

**Files:** none (verification only).

- [ ] **Step 1: Full headless suite — all green, hash unchanged**

```bash
for t in shot_grammar_check grade_check time_emphasis_check continuity_check sightline_check hybrid_check director_check; do
  echo "=== $t ==="; godot --headless --path godot_director_spike -s res://tests/$t.gd 2>/dev/null | grep -E "ALL PASS|FAIL|got hash"
done
```
Expected: every suite `---- ALL PASS`; `hybrid_check` `got hash 2543717900`.

- [ ] **Step 2: Visual (windowed) — the melee close-up finds a clear angle**

```bash
godot --path godot_director_spike --quit-after 1800 -- --director=hybrid --log=fight_log_melee --armor --frames
godot --path godot_director_spike --quit-after 2500 -- --director=hybrid --log=fight_log_everything --armor --frames
```
Open the `tmp/frame_hybrid_*.png` melee close-up frames (the frame-07 burial case). Confirm: the melee orbit now favors angles where the clash reads (the camera swings to a clearer view rather than orbiting blindly into a wall), and the hero cuts hold a clear-ish view on their keyed side. The orbits still orbit (continuous motion), `bullet_time` kill cam and `iso` are unchanged. Tuning dials: `composition_search_arc` (swing range), the hysteresis margin (`2`), the candidate scales/offsets.

- [ ] **Step 3: Done**

Slice B2 complete — the combined continuity + sightline camera now keys screen sides (A), clears true occluders (B1), and aims for a clear sightline (B2). Deferred follow-up (B2b, optional): the iso fallback when a cut-in has no clear same-side pose.

---

## Self-review notes
- Spec coverage: B2 implements the composition search (clear-pose pick + hysteresis) for `melee_cut` (orbit angle) and `hero_os`/`hero_cut` (keyed-side lateral). bullet_time/iso out of scope (kill-cam constraint). iso fallback deferred to B2b. Determinism gate asserted in Tasks 1/3/4.
- Type consistency: `_pick_clear_pose(candidates, aim, buildings, prev_idx, margin) -> {idx, pos, clear}` is identical in the test (Task 2) and all three call sites (Tasks 3, 4). `_silhouette_points` made static (Task 1) before `_pick_clear_pose` (static) calls it (Task 2). `_pick_idx` defined (Task 2), reset (Task 3 Step 1), used (Tasks 3, 4).
