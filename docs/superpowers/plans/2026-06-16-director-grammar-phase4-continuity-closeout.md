# Director Grammar Phase 4 — Continuity Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lock the screen-direction (180°) invariant with an automated guard and formalize the establishing layout, closing the Continuity dimension (F32–F36) of the Director Grammar — with zero visible change.

**Architecture:** Extract the duplicated hero cut-in candidate-pose generation from `hybrid.gd` into one pure static helper on `director.gd` (`_hero_candidates`), so a new headless test (`coherence_check.gd`) can verify the *real* pose path never crosses the A↔B axis. Add an F34 comment naming the iso backbone as the establishing layout. F36 split-screen is deferred.

**Tech Stack:** Godot 4.6.3, GDScript. Headless test scripts (`extends SceneTree`, run via `godot --headless --path godot_director_spike -s res://tests/<name>.gd`).

**Spec:** `docs/superpowers/specs/2026-06-16-director-grammar-phase4-continuity-closeout-design.md`

**The gate:** every change here is presentation-side. `tests/hybrid_check.gd` MUST keep printing `got hash 2543717900`. If it moves, stop — something leaked into the deterministic path.

**Gotcha (from the handoff):** a brand-new script or `class_name` may need one `godot --headless --path godot_director_spike --import` pass before the engine sees it ("Could not resolve class" / "script not found" = stale cache, not a missing file). The steps below include the import where a new file is introduced.

`godot` is on PATH (also `~/.local/bin/godot.cmd`). Run all commands from the repo root `D:\claude\Gundamu-War`.

---

### Task 1: F35 — `_hero_candidates` helper + `coherence_check.gd` guard

**Files:**
- Create: `godot_director_spike/tests/coherence_check.gd`
- Modify: `godot_director_spike/scripts/director.gd` (add static helper after `_keyed_lateral`, ~line 335)

- [ ] **Step 1: Write the failing test**

Create `godot_director_spike/tests/coherence_check.gd` with exactly this content:

```gdscript
extends SceneTree
## Headless guard for F35 (coherence_over_polish): the hero cut-in pose search can
## never cross the A<->B action axis (the 180deg / screen-direction rule). Exercises
## the REAL candidate path (_hero_candidates) plus the occlusion pick
## (_pick_clear_pose) across many duel geometries, both keyed sides, and several
## building layouts. melee_cut is intentionally NOT covered (it orbits the clash and
## may sit on either side). Pure + headless; mirrors continuity_check / sightline_check.

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
	var Director := load("res://scripts/director.gd")
	check(Director != null, "director.gd loads")

	# Representative hero framing magnitudes; the SIGN is chosen by _keyed_lateral.
	var pullback := 18.0
	var height := 12.0
	var lateral := 9.0

	# Duel geometries: axis-aligned, rotated 90deg, diagonal, and off-origin.
	var geometries := [
		[Vector3(-40, 0, 0), Vector3(40, 0, 0)],
		[Vector3(0, 0, -40), Vector3(0, 0, 40)],
		[Vector3(-30, 0, -30), Vector3(35, 0, 25)],
		[Vector3(120, 0, -10), Vector3(60, 0, 50)],
	]
	# Building layouts the occlusion search must dodge (incl. one straddling the line).
	var layouts := [
		[],
		[_bld(Vector3(-10, 0, -8), Vector3(20, 30, 16))],
		[_bld(Vector3(-30, 0, -30), Vector3(60, 40, 60))],
	]

	for gi in geometries.size():
		var a: Vector3 = geometries[gi][0]
		var b: Vector3 = geometries[gi][1]
		# Each mech takes a turn as the cut-in focus (f); the other is o.
		for pair in [[a, b], [b, a]]:
			var f: Vector3 = pair[0]
			var o: Vector3 = pair[1]
			for keyed in [1, -1]:
				var lat: float = Director._keyed_lateral(f, o, pullback, height, lateral, a, b, keyed)
				var cands: Array = Director._hero_candidates(f, o, pullback, height, lat)
				check(cands.size() == 5, "geo %d keyed %d: 5 hero candidates" % [gi, keyed])
				# (a) every candidate lands on the keyed side of the axis
				var all_keyed := true
				for c in cands:
					if Director._axis_side(c, a, b) != keyed:
						all_keyed = false
				check(all_keyed, "geo %d keyed %d: all hero candidates on keyed side" % [gi, keyed])
				# (b) the occlusion pick stays keyed-side for EVERY building layout
				var aim: Vector3 = o + Vector3(0, 10, 0)
				var pick_keyed := true
				for layout in layouts:
					var pk: Dictionary = Director._pick_clear_pose(cands, aim, layout, -1, 2)
					if Director._axis_side(pk.pos, a, b) != keyed:
						pick_keyed = false
				check(pick_keyed, "geo %d keyed %d: picked pose keyed-side across all layouts" % [gi, keyed])

	for layout in layouts:
		for n in layout:
			n.free()

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
```

- [ ] **Step 2: Import (new file) and run to verify it FAILS**

Run:
```
godot --headless --path godot_director_spike --import
godot --headless --path godot_director_spike -s res://tests/coherence_check.gd
```
Expected: a `SCRIPT ERROR: Invalid call. Nonexistent function '_hero_candidates' in base 'GDScript'` (the helper doesn't exist yet), and the run does NOT print `---- ALL PASS`.

- [ ] **Step 3: Add the `_hero_candidates` static helper to `director.gd`**

Insert this immediately AFTER the `_keyed_lateral` function (which ends at the line `return lateral if _axis_side(p, a_pos, b_pos) == keyed_side else -lateral`, ~line 335) and BEFORE the `_silhouette_points` doc comment:

```gdscript
## The keyed-side candidate camera poses for a hero cut-in: the focus mech pulled
## back along the firing line, raised, and offset laterally by scaled multiples of
## the (already keyed-signed) lateral. Pullback is along the A<->B axis and height is
## vertical -- neither changes which side of the axis a pose sits on -- so every
## candidate shares the keyed lateral's sign and lands on the same (keyed) side.
## `lateral_signed` is the output of _keyed_lateral. Pure.
static func _hero_candidates(f_pos: Vector3, o_pos: Vector3, pullback: float, height: float, lateral_signed: float) -> Array:
	var d := (o_pos - f_pos).normalized()
	var out: Array = []
	for scale in [0.6, 0.85, 1.0, 1.3, 1.7]:
		out.append(f_pos - d * pullback + d.cross(Vector3.UP) * (lateral_signed * float(scale)) + Vector3(0, height, 0))
	return out
```

- [ ] **Step 4: Run the test to verify it PASSES**

Run:
```
godot --headless --path godot_director_spike -s res://tests/coherence_check.gd
```
Expected: a column of `PASS` lines and a final `---- ALL PASS`. (No `--import` needed — a new static method on an existing script is picked up on reload. If you see "Could not resolve class", run `--import` once and re-run.)

- [ ] **Step 5: Commit**

```
git add godot_director_spike/tests/coherence_check.gd godot_director_spike/scripts/director.gd
git commit -m "test(render): F35 coherence guard + _hero_candidates helper

New headless coherence_check.gd asserts every hero cut-in candidate AND the
occlusion-picked pose stay on the keyed side of the A<->B axis across many
geometries, both keyed sides, and several building layouts -- locking the
180deg/screen-direction rule. Adds the pure _hero_candidates helper it tests.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Wire `hero_os` + `hero_cut` to the helper (behavior-preserving dedup)

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` (the `hero_os` and `hero_cut` branches of `match s.mode`)

- [ ] **Step 1: Replace the `hero_os` candidate loop**

In the `"hero_os":` branch, replace these four lines:

```gdscript
			var cands_os: Array = []
			for scale in [0.6, 0.85, 1.0, 1.3, 1.7]:
				cands_os.append(f.position - d * fr.pullback + d.cross(Vector3.UP) * (lat_os * float(scale)) + Vector3(0, fr.height, 0))
			var pick_os := _pick_clear_pose(cands_os, aim, get_tree().get_nodes_in_group("kb_building"), _pick_idx, 2)
```

with:

```gdscript
			var cands_os := _hero_candidates(f.position, o.position, fr.pullback, fr.height, lat_os)
			var pick_os := _pick_clear_pose(cands_os, aim, get_tree().get_nodes_in_group("kb_building"), _pick_idx, 2)
```

- [ ] **Step 2: Replace the `hero_cut` candidate loop**

In the `"hero_cut":` branch, replace these four lines:

```gdscript
			var cands_cut: Array = []
			for scale in [0.6, 0.85, 1.0, 1.3, 1.7]:
				cands_cut.append(f.position - d * fr.pullback + d.cross(Vector3.UP) * (lat_cut * float(scale)) + Vector3(0, fr.height, 0))
			var pick_cut := _pick_clear_pose(cands_cut, aim, get_tree().get_nodes_in_group("kb_building"), _pick_idx, 2)
```

with:

```gdscript
			var cands_cut := _hero_candidates(f.position, o.position, fr.pullback, fr.height, lat_cut)
			var pick_cut := _pick_clear_pose(cands_cut, aim, get_tree().get_nodes_in_group("kb_building"), _pick_idx, 2)
```

- [ ] **Step 3: Verify the golden hash is unchanged**

Run:
```
godot --headless --path godot_director_spike -s res://tests/hybrid_check.gd
```
Expected: `PASS  hybrid shot list matches golden snapshot (got hash 2543717900)` and `---- ALL PASS`. If the hash differs, the refactor changed behavior — revert and compare the candidate math character-by-character.

- [ ] **Step 4: Run the full suite**

Run each and confirm `---- ALL PASS`:
```
for t in shot_grammar_check grade_check time_emphasis_check continuity_check coherence_check sightline_check hybrid_check director_check; do godot --headless --path godot_director_spike -s res://tests/$t.gd; done
```
(PowerShell: `foreach ($t in 'shot_grammar_check','grade_check','time_emphasis_check','continuity_check','coherence_check','sightline_check','hybrid_check','director_check') { & "$env:USERPROFILE\.local\bin\godot.cmd" --headless --path godot_director_spike -s "res://tests/$t.gd" }`)
Expected: every script ends in `---- ALL PASS`.

- [ ] **Step 5: Commit**

```
git add godot_director_spike/scripts/directors/hybrid.gd
git commit -m "refactor(render): hero_os/hero_cut share _hero_candidates (no behavior change)

Both hero cut-in branches generated identical candidate poses inline; route
both through the pure _hero_candidates helper extracted in the prior commit.
Golden hash 2543717900 held; full suite green.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: F34 — formalize the establishing layout (comment only)

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` (the runtime iso branch, the `if s.mode == "iso" or s.mode == "iso_aftermath":` line, ~line 93)

- [ ] **Step 1: Add the establishing-layout comment**

Directly ABOVE the line `if s.mode == "iso" or s.mode == "iso_aftermath":`, insert:

```gdscript
	# F34 establishing_layout: the orthographic iso backbone IS the establishing
	# layout -- it opens the fight (establish), returns between perspective
	# intercuts (re-establish), and holds the aftermath (final establish), fixing
	# the geography so the cut-ins never disorient. Coverage: hybrid_check asserts
	# "opens on the isometric base view", "iso base returns between the intercuts",
	# and "closes on the iso aftermath read".
```

- [ ] **Step 2: Verify nothing broke**

Run:
```
godot --headless --path godot_director_spike -s res://tests/hybrid_check.gd
```
Expected: `---- ALL PASS`, hash still `2543717900` (a comment cannot change behavior, but confirm).

- [ ] **Step 3: Commit**

```
git add godot_director_spike/scripts/directors/hybrid.gd
git commit -m "docs(render): F34 name the iso backbone as the establishing layout

Comment-only formalization closing the Continuity dimension: records that the
iso/ortho backbone is the F34 establishing/re-establishing layout already
covered by hybrid_check's three iso assertions. No behavior change.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Visual parity verification (no code)

**Files:** none.

- [ ] **Step 1: Launch the live viewer**

Run:
```
godot --path godot_director_spike -- --director=hybrid --log=fight_log_everything --armor
```
(PowerShell: `Start-Process -FilePath "$env:USERPROFILE\.local\bin\godot.cmd" -ArgumentList '--path','godot_director_spike','--','--director=hybrid','--log=fight_log_everything','--armor' -WorkingDirectory 'D:\claude\Gundamu-War'`)

- [ ] **Step 2: Confirm identical look**

Expected: the fight looks identical to before this plan — same iso backbone, same hero/melee/bullet-time cut-ins, same x-ray behavior. The intended outcome of this whole plan is NO visible change; if anything looks different, the Task 2 refactor was not behavior-preserving — investigate before considering the plan done.

- [ ] **Step 3: Final full-suite confirmation**

Re-run the Task 2 Step 4 suite loop one more time; expected every script ends `---- ALL PASS`, hash `2543717900`. No commit.

---

## Self-review notes

- **Spec coverage:** F35 coherence guard → Task 1 (test) + Task 2 (real-path wiring). F34 establishing-layout formalization → Task 3. F36 split-screen → deferred per spec, no task. Determinism gate (hash held) → asserted in Tasks 2, 3, 4. Visual parity → Task 4.
- **Types/signatures:** `_hero_candidates(f_pos, o_pos, pullback, height, lateral_signed) -> Array` defined in Task 1 Step 3 and called identically in Task 2 (positional args; `lat_os`/`lat_cut` are the `_keyed_lateral` outputs already in scope). `_keyed_lateral(...)` / `_axis_side(...)` / `_pick_clear_pose(...) -> {idx,pos,clear}` used per their existing signatures in `director.gd`.
- **No placeholders:** all test and helper code is complete; no TODO/TBD.
