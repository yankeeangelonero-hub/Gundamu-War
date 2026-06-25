# Hybrid Director — UC Camera Grammar Gap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Broaden `hybrid.gd`'s mid-fight intercut candidates from beam-only to all fire events, add movement punctuation (pop-up burst, dodge-pursuit chase), escalate the `hero_kill` camera arc, and apply UC F4–F6 authored cut rhythm throughout — while keeping all six director variants and all headless tests green.

**Architecture:** `hybrid.gd` is the only file edited. Its `build_shot_list` (pure, headless-testable) gains new fixed-shot candidates for `fire_burst`/`fire_swarm`/`fire_buster`, pop-up `advance` events, dodge-pursuit `advance` runs, and overload build-up. Its `_update_camera` gains two new VOCAB modes (`popup_burst` and `chase_pursuit`) and extended `bullet_time` logic for `hero_kill`. All new modes are added to `VOCAB`. The five sibling director variants and `director.gd` are not touched. `hybrid_check.gd` gets new assertions. `enriched_render_shot.gd` gets new frame captures for the three required proof points.

**Tech Stack:** GDScript, Godot 4.6, headless `--script` runner for checks, windowed runner for render proofs.

---

## File Structure

| File | Change |
|---|---|
| `godot_director_spike/scripts/directors/hybrid.gd` | Edit: broaden intercut logic, add 2 VOCAB modes, add 3 new fixed-shot types, extend `_update_camera` |
| `godot_director_spike/tests/hybrid_check.gd` | Edit: extend with 3 new assertions (swarm intercut, movement beats, hero_kill escalation) |
| `godot_director_spike/tests/enriched_render_shot.gd` | Edit: add 3 frame captures for swarm hero cut, dodge-pursuit chase shot, escalated hero_kill |

`director.gd`, `build_fight_sim.gd`, all sibling variant scripts, and all other test files are read-only for this plan.

---

## Context you must understand before touching code

### What hybrid.gd currently does

`build_shot_list` scans events to find:
1. The first `fire_beam` (not lethal) → `hero_os` opening over-shoulder shot
2. All subsequent non-lethal `fire_beam` events → candidates for a single mid-fight `hero_cut`
3. Every non-lethal `melee` → `melee_cut` close-up
4. The lethal event (any kind) → `bullet_time` kill

Between those fixed shots, `iso` fills gaps. The fight ends on `iso_aftermath`.

The **gap**: only `fire_beam` events produce `hero_os`/`hero_cut` candidates. A swarm-only or burst-only fight produces zero hero intercepts and falls back to a static iso stretch for the entire mid-fight. Also: pop-up and dodge-pursuit movement beats get no punctuation.

### VOCAB constraint

`hybrid_check.gd` line 54 asserts that every shot mode appears in `Hybrid.VOCAB`. You must add new mode strings to the `VOCAB` constant or the vocab check fails.

### The existing VOCAB

```gdscript
const VOCAB := ["iso", "iso_aftermath", "hero_os", "hero_cut", "melee_cut", "bullet_time"]
```

### New modes to add

- `"popup_burst"` — low/heroic angle at a pop-up advance onset (`to_y > 0`)
- `"chase_pursuit"` — wide tracking shot framing the dodge-pursuit weave

### hero_kill escalation: what already exists

`director.gd`'s `_hero_kill_escalate` (lines 201-208) already sets `shake_strength = 3.5` and holds `Engine.time_scale` dilated. The renderer (garnish) does whiteout/screen-fill. Your job is the **camera arc**: when the lethal event carries `hero_kill: true`, make the `bullet_time` shot arc wider, rise higher, and orbit more (capital-grade camera move). The `bullet_time` shot in `build_shot_list` only needs to mark that this is a hero_kill by passing `hero_kill: true` into the shot dict; `_update_camera` reads it and adjusts the arc radius/height/sweep.

### Overload build-up: what currently happens

An overload lethal event is caught by the generic `lethal` scan in `build_shot_list` — it finds `lethal_t` via `e.payload.get("lethal", false)` on any event. So overload fights do get a `bullet_time` window. The gap is there is no build-up beat before the overload — the lethal event arrives with no escalating approach shot. Add a short `hero_cut` (tightening/rising) 0.8s before the lethal overload tick on any overload event with `lethal: true`.

### Choreography timing (from build_fight_sim.gd)

- Phase 1 pop-up: tick 20 (`to_y = 6`), lands tick 31 → t ≈ 2.0s..3.1s
- Phase 2 pop-up: tick 80 (`to_y = 6`), lands tick 91 → t ≈ 8.0s..9.1s
- Dodge-pursuit run: ticks 100-133 → t ≈ 10.0s..13.3s
- Phase 3 pop-up: tick 182 (`to_y = 6`), lands tick 193 → t ≈ 18.2s..19.3s

### Shot duration budget (UC F5 authored rhythm)

| Shot mode | Duration | Rationale |
|---|---|---|
| `hero_os` | 1.8s (unchanged) | Opening exchange; wide-to-medium; establish |
| `hero_cut` | 1.8s (unchanged) | Mid-fight fire; medium-to-close; impact |
| `melee_cut` | 2.2s @ 0.5× | Close blade clash; densest cut |
| `popup_burst` | 1.2s | Short punch — low heroic angle, thrust flare |
| `chase_pursuit` | 2.5s | Wider tracking; the weave needs time to read |
| `bullet_time` (standard) | 0.55s realtime (existing BT_PRE 0.2 + BT_POST 0.35 @ 0.07×) | Lethal standard |
| `bullet_time` (hero_kill) | BT_PRE 0.2 + BT_POST 0.6 @ 0.05× | Bigger arc, longer freeze |

### Conflict avoidance

`build_shot_list` appends fixed shots then sorts by `t0`. If two fixed shots overlap (e.g. a `popup_burst` at t=2.0 overlapping with `hero_os` at t=1.7), the gap-fill loop's `cursor` advance means the later shot is clipped at `cursor`. This is correct existing behaviour — clips are fine; the iso backbone recovers. No special de-overlap logic needed.

---

## Task 1: Extend VOCAB and broaden fire-event intercut candidates

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` lines 1-70

This task handles requirement 1 (all fire events produce hero-cut candidates) and adds the two new VOCAB entries needed by later tasks.

- [ ] **Step 1: Read hybrid.gd lines 1-70 in full**

You already have it above; confirm line 8 is the `VOCAB` constant and line 17 is `build_shot_list`.

- [ ] **Step 2: Replace VOCAB constant to add two new modes**

In `hybrid.gd`, change line 8 from:
```gdscript
const VOCAB := ["iso", "iso_aftermath", "hero_os", "hero_cut", "melee_cut", "bullet_time"]
```
to:
```gdscript
const VOCAB := ["iso", "iso_aftermath", "hero_os", "hero_cut", "melee_cut", "bullet_time",
	"popup_burst", "chase_pursuit"]
```

- [ ] **Step 3: Broaden the fire-event scan in build_shot_list**

The current scan at lines 28-36 is:
```gdscript
	for e in events:
		if e.kind != "fire_beam" or e.payload.get("lethal", false):
			continue
		var t := float(e.tick) * TICK
		if first_t < 0.0:
			first_t = t
			first_actor = str(e.actor)
		else:
			mids.append({"t": t, "actor": str(e.actor)})
```

Replace it with:
```gdscript
	const FIRE_KINDS := ["fire_beam", "fire_burst", "fire_swarm", "fire_buster"]
	for e in events:
		if not (e.kind in FIRE_KINDS) or e.payload.get("lethal", false):
			continue
		var t := float(e.tick) * TICK
		if first_t < 0.0:
			first_t = t
			first_actor = str(e.actor)
		else:
			mids.append({"t": t, "actor": str(e.actor)})
```

- [ ] **Step 4: Run hybrid_check headless to confirm it still passes**

```
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/hybrid_check.gd
```

Expected: `---- ALL PASS` and exit 0. The existing `hero_cut >= 1` check at line 59 of `hybrid_check.gd` passes because the fight log contains `fire_beam` events too; broadening the scan does not break any existing assertion.

---

## Task 2: Add hero_kill flag to bullet_time shot and escalate its camera arc

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` — `build_shot_list` (bullet_time append) and `_update_camera` (bullet_time branch)

This task handles requirement 4 (hero_kill escalation) and requirement 2's bullet-time extension for overload.

- [ ] **Step 1: Find the lethal event and extract hero_kill flag in build_shot_list**

The existing lethal scan at lines 24-27 finds `lethal_t` and `lethal_actor`. Extend it to also capture `lethal_kind` and `hero_kill_flag`:

Replace:
```gdscript
	for e in events:
		if e.payload.get("lethal", false):
			lethal_t = float(e.tick) * TICK
			lethal_actor = str(e.actor)
```
with:
```gdscript
	var lethal_kind := ""
	var hero_kill_flag := false
	for e in events:
		if e.payload.get("lethal", false):
			lethal_t = float(e.tick) * TICK
			lethal_actor = str(e.actor)
			lethal_kind = str(e.kind)
			hero_kill_flag = bool(e.payload.get("hero_kill", false))
```

- [ ] **Step 2: Pass hero_kill into the bullet_time shot dict**

The existing `fixed.append` for `bullet_time` at line 55 is:
```gdscript
	fixed.append({"t0": lethal_t - BT_PRE, "t1": lethal_t + BT_POST, "mode": "bullet_time",
		"focus": lethal_actor, "time_scale": BT_SCALE})
```

Replace with (hero_kill gets longer post-window and slower scale; plain lethal keeps existing constants):
```gdscript
	var bt_post := 0.6 if hero_kill_flag else BT_POST
	var bt_scale := 0.05 if hero_kill_flag else BT_SCALE
	fixed.append({"t0": lethal_t - BT_PRE, "t1": lethal_t + bt_post, "mode": "bullet_time",
		"focus": lethal_actor, "time_scale": bt_scale, "hero_kill": hero_kill_flag})
```

- [ ] **Step 3: Extend _update_camera bullet_time branch for hero_kill**

The existing `"bullet_time":` branch in `_update_camera` (lines 143-153) computes an arcing orbit. For `hero_kill`, widen the orbit radius and increase the Y rise so the shot reads capital-grade:

Replace the `"bullet_time":` match arm:
```gdscript
		"bullet_time":
			var shooter: Node3D = actors[s.focus]
			var victim: Node3D = actors[_other(str(s.focus))]
			var center := victim.position.lerp(shooter.position, 0.2) + Vector3(0, 10, 0)
			var wall_len := (float(s.t1) - float(s.t0)) / BT_SCALE
			var p := clampf(_wall / wall_len, 0.0, 1.0)
			var ang := PI + p * TAU * 0.75
			pos = center + Vector3(cos(ang) * 32.0, 8.0 + p * 9.0, sin(ang) * 14.0)
			aim = center
			fov = 48
			_roll = lerpf(-0.05, 0.03, p)
```
with:
```gdscript
		"bullet_time":
			var shooter: Node3D = actors[s.focus]
			var victim: Node3D = actors[_other(str(s.focus))]
			var center := victim.position.lerp(shooter.position, 0.2) + Vector3(0, 10, 0)
			var bt_ts := float(s.time_scale)
			var wall_len := (float(s.t1) - float(s.t0)) / maxf(bt_ts, 0.001)
			var p := clampf(_wall / wall_len, 0.0, 1.0)
			# hero_kill: wider radius, greater height rise, longer arc sweep (capital-grade)
			var is_hk: bool = bool(s.get("hero_kill", false))
			var radius_h := 42.0 if is_hk else 32.0
			var radius_v := 18.0 if is_hk else 14.0
			var height_rise := 16.0 if is_hk else 9.0
			var sweep := TAU * 1.0 if is_hk else TAU * 0.75
			var ang := PI + p * sweep
			pos = center + Vector3(cos(ang) * radius_h, 8.0 + p * height_rise, sin(ang) * radius_v)
			aim = center
			fov = 44.0 if is_hk else 48.0
			_roll = lerpf(-0.07, 0.05, p) if is_hk else lerpf(-0.05, 0.03, p)
```

- [ ] **Step 4: Run hybrid_check headless**

```
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/hybrid_check.gd
```

Expected: `---- ALL PASS`. The existing `dilated.size() == 1` check still passes because only one `bullet_time` shot exists; its `time_scale` is still `< 1.0`.

---

## Task 3: Add overload build-up beat and pop-up punctuation shots

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` — `build_shot_list` only

This task handles requirement 2 (overload build-up) and requirement 3 (pop-up movement punctuation).

- [ ] **Step 1: Add overload build-up fixed shot**

After the bullet_time append and before `fixed.sort_custom`, add:

```gdscript
	# Overload build-up: a tightening "reactor cooking off" shot just before the
	# lethal overload. Only fires when the killing blow is an overload (not a weapon fire).
	if lethal_kind == "overload":
		var buildup_t := lethal_t - 0.8
		if buildup_t > first_t + OS_LEN + 0.1:
			fixed.append({"t0": buildup_t, "t1": lethal_t, "mode": "hero_cut",
				"focus": lethal_actor, "time_scale": 1.0})
```

The build-up reuses `hero_cut` mode (a tight low-angle perspective shot) — appropriate as a rising/tightening tension beat. No new mode needed.

- [ ] **Step 2: Add pop-up punctuation shots**

Pop-up bursts are `advance` events where `payload.to_y > 0`. Add a `popup_burst` intercut at each pop-up onset — but only if it doesn't collide with `hero_os` (skip if within the `hero_os` window).

After the overload build-up block (still before `fixed.sort_custom`), add:

```gdscript
	# Pop-up punctuation: a low/heroic angle shot at the onset of each pop-up burst.
	# Duration: 1.2s. Skip if it would fully overlap with the hero_os window.
	const POPUP_LEN := 1.2
	for e in events:
		if e.kind != "advance" or not (float(e.payload.get("to_y", 0.0)) > 0.0):
			continue
		var pt := float(e.tick) * TICK
		# Skip if this pop-up fires inside or immediately after the hero_os window.
		if pt < first_t + OS_LEN + 0.2:
			continue
		fixed.append({"t0": pt - 0.1, "t1": pt + POPUP_LEN, "mode": "popup_burst",
			"focus": str(e.actor), "time_scale": 1.0})
```

- [ ] **Step 3: Add dodge-pursuit chase shot**

The dodge-pursuit run spans ticks 100-133 (t 10.0-13.3s). Detect it by finding a run of consecutive `evade`/`pursue` advance events and adding one `chase_pursuit` shot spanning the run's midpoint.

After the pop-up block, add:

```gdscript
	# Chase-pursuit punctuation: one wide tracking shot spanning the dodge-pursuit weave.
	# Detect the run by finding the first evade and last pursue in the log; add a shot
	# that covers the middle ~2.5s of that window.
	const CHASE_LEN := 2.5
	var chase_start := -1.0
	var chase_end := -1.0
	var chase_actor := "A"
	for e in events:
		if e.kind != "advance":
			continue
		if bool(e.payload.get("evade", false)) or bool(e.payload.get("pursue", false)):
			var ct := float(e.tick) * TICK
			if chase_start < 0.0:
				chase_start = ct
				chase_actor = str(e.actor)
			chase_end = ct + float(e.payload.end_tick - e.tick) * TICK
	if chase_start >= 0.0:
		var chase_mid := (chase_start + chase_end) * 0.5
		var cs0 := chase_mid - CHASE_LEN * 0.5
		var cs1 := chase_mid + CHASE_LEN * 0.5
		# Only add if it doesn't fully overlap with bullet_time (kill near the chase run).
		if cs1 < lethal_t - BT_PRE - 0.1:
			fixed.append({"t0": cs0, "t1": cs1, "mode": "chase_pursuit",
				"focus": chase_actor, "time_scale": 1.0})
```

- [ ] **Step 4: Run hybrid_check headless**

```
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/hybrid_check.gd
```

Expected: `---- ALL PASS`. The vocab check now covers `popup_burst` and `chase_pursuit` because they are in `VOCAB`. The `iso >= 2` check still passes because iso fills gaps between all the new shots. The `hero_cut >= 1` check still passes (overload build-up reuses `hero_cut`; non-overload fights have the beam/fire intercut).

---

## Task 4: Add camera poses for popup_burst and chase_pursuit modes

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` — `_update_camera` only

This task handles requirement 3's camera poses for the two new movement beats (F6 framing-for-scale: low/heroic = giant scale; wide tracking = the weave reads).

- [ ] **Step 1: Add popup_burst match arm to _update_camera**

In the `match s.mode:` block of `_update_camera` (after `"hero_cut":` and before `"melee_cut":`), add:

```gdscript
		"popup_burst":
			# Low/heroic angle: camera planted low and wide, looking UP at the boosting mech.
			# The pop-up burst should read as a giant leaving the ground — F6 framing-for-scale.
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var d := (o.position - f.position).normalized()
			# Place camera low, behind and below the boosting mech — looking up into the thrust.
			pos = f.position - d * 12.0 + Vector3(0, 2.0, 0)
			aim = f.position + Vector3(0, 18.0, 0)   # aim high: the mech is rising
			fov = 52   # wider field — sell the vertical scale
			_roll = 0.02
```

- [ ] **Step 2: Add chase_pursuit match arm to _update_camera**

After `"popup_burst":` and before `"melee_cut":`, add:

```gdscript
		"chase_pursuit":
			# Wide tracking shot: planted at mid-height between the two mechs, panning with the
			# evader's movement across the depth plane. The weave must read — keep it wide.
			# F4: constant reframing (aim tracks evader); F5: shot held long enough to see the arc.
			var evader: Node3D = actors[s.focus]
			var pursuer: Node3D = actors[_other(str(s.focus))]
			var lateral := evader.position - pursuer.position
			# Offset the camera perpendicular to the chase axis, at a middling height.
			var perp := Vector3(-lateral.z, 0.0, lateral.x).normalized()
			pos = evader.position.lerp(pursuer.position, 0.5) + perp * 28.0 + Vector3(0, 14.0, 0)
			aim = evader.position + Vector3(0, 10.0, 0)  # track the evader
			fov = 58   # wide — full weave visible
```

- [ ] **Step 3: Run hybrid_check headless**

```
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/hybrid_check.gd
```

Expected: `---- ALL PASS`. The new arms are purely runtime code and do not affect the pure `build_shot_list` function that the headless tests exercise. Confirm no syntax errors prevent the script from loading (the `vocab_ok` check exercises `Hybrid.VOCAB` via `load`).

---

## Task 5: Extend hybrid_check.gd with three new assertions

**Files:**
- Modify: `godot_director_spike/tests/hybrid_check.gd`

This task adds the three required assertions: (a) swarm/gatling-only log yields hero intercut; (b) pop-up + dodge-pursuit log yields the new movement beats; (c) hero_kill log yields escalated bullet-time.

- [ ] **Step 1: Read the full current hybrid_check.gd**

You already have it above (lines 1-60). The `_check_hybrid_shot_list` function is the only function beyond `check` and `_initialize`. You will add a second function `_check_enriched_shots` and call it from `_initialize`.

- [ ] **Step 2: Add _check_enriched_shots function to hybrid_check.gd**

Add the following new function AFTER the closing `}` of `_check_hybrid_shot_list` (i.e. after line 60) and call it from `_initialize` (between `_check_hybrid_shot_list()` and `print`):

```gdscript
func _check_enriched_shots() -> void:
	var Sim := load("res://scripts/build/build_fight_sim.gd")
	var Hybrid := load("res://scripts/directors/hybrid.gd")
	var FightLog := load("res://scripts/fight_log.gd")
	if Sim == null or Hybrid == null:
		check(false, "enriched: Sim/Hybrid scripts load")
		return

	# --- (a) Swarm/gatling-only log yields >= 1 hero intercut ---
	# Build: only missile (fire_swarm) weapon — NO beam weapon at all.
	var w_swarm := {"id": "s1", "damage": 18.0, "cost": 3.0, "cadence": 1.8,
		"mount": "shoulder_r", "fx": "missiles"}
	var w_burst := {"id": "b1", "damage": 10.0, "cost": 2.0, "cadence": 1.2,
		"mount": "hand_r", "fx": "burst"}
	var build_swarm := {"hp": 100.0, "pool": 80.0, "regen": 14.0, "weapons": [w_swarm, w_burst]}
	var foe_weak := {"hp": 100.0, "pool": 30.0, "regen": 5.0,
		"weapons": [{"id": "f1", "damage": 3.0, "cost": 1.0, "cadence": 2.0,
			"mount": "hand_r", "fx": "beam"}]}
	var swarm_events := Sim.simulate(build_swarm, foe_weak, 5)
	# Verify there are no fire_beam events from actor A (the swarm/burst build).
	var a_has_beam := false
	for e in swarm_events:
		if e.actor == "A" and e.kind == "fire_beam":
			a_has_beam = true
	check(not a_has_beam, "enriched (a): swarm+burst build emits no fire_beam from A")
	var swarm_dur := FightLog.duration_sec(swarm_events)
	var swarm_shots := Hybrid.build_shot_list(swarm_events, swarm_dur)
	var hero_intercepts: Array = swarm_shots.filter(
		func(s): return s.mode == "hero_os" or s.mode == "hero_cut")
	check(hero_intercepts.size() >= 1,
		"enriched (a): swarm/burst-only fight yields >= 1 hero intercut (got %d)" % hero_intercepts.size())

	# --- (b) Pop-up + dodge-pursuit log yields movement beats ---
	# Any BuildFightSim log contains choreography including pop-up and dodge-pursuit.
	var a_std := {"hp": 100.0, "pool": 60.0, "regen": 10.0,
		"weapons": [{"id": "a1", "damage": 12.0, "cost": 2.0, "cadence": 1.0,
			"mount": "hand_r", "fx": "beam"}]}
	var b_std := {"hp": 100.0, "pool": 40.0, "regen": 6.0,
		"weapons": [{"id": "b2", "damage": 8.0, "cost": 3.0, "cadence": 1.5,
			"mount": "hand_r", "fx": "beam"}]}
	var std_events := Sim.simulate(a_std, b_std, 7)
	var std_dur := FightLog.duration_sec(std_events)
	var std_shots := Hybrid.build_shot_list(std_events, std_dur)
	var has_popup_shot := false
	var has_chase_shot := false
	for s in std_shots:
		if s.mode == "popup_burst":
			has_popup_shot = true
		if s.mode == "chase_pursuit":
			has_chase_shot = true
	check(has_popup_shot, "enriched (b): log with pop-up advances yields >= 1 popup_burst shot")
	check(has_chase_shot, "enriched (b): log with dodge-pursuit run yields >= 1 chase_pursuit shot")

	# --- (c) hero_kill log yields escalated bullet-time ---
	# Build where A has high DPS swarm weapon → fast lethal → hero_kill:true on fire_swarm.
	var w_hk := {"id": "hk1", "damage": 40.0, "cost": 3.0, "cadence": 1.0,
		"mount": "shoulder_r", "fx": "missiles"}
	var build_hk := {"hp": 100.0, "pool": 999.0, "regen": 999.0, "weapons": [w_hk]}
	var foe_hk := {"hp": 100.0, "pool": 0.0, "regen": 0.0, "weapons": []}
	var hk_events := Sim.simulate(build_hk, foe_hk, 0)
	# Confirm hero_kill:true in this log.
	var hk_present := false
	for e in hk_events:
		if e.payload.get("hero_kill", false):
			hk_present = true
	check(hk_present, "enriched (c): high-DPS swarm build produces hero_kill:true event")
	var hk_dur := FightLog.duration_sec(hk_events)
	var hk_shots := Hybrid.build_shot_list(hk_events, hk_dur)
	var bt_shots: Array = hk_shots.filter(func(s): return s.mode == "bullet_time")
	check(bt_shots.size() == 1, "enriched (c): hero_kill log has exactly one bullet_time shot")
	if bt_shots.size() == 1:
		var bt: Dictionary = bt_shots[0]
		# Escalated: hero_kill bullet-time is longer than plain bullet-time (BT_POST=0.35; hero_kill=0.6)
		var bt_window := float(bt.t1) - float(bt.t0)
		check(bt_window > 0.55, "enriched (c): hero_kill bullet-time window > 0.55s realtime (got %.3f)" % bt_window)
		check(bool(bt.get("hero_kill", false)), "enriched (c): bullet_time shot dict carries hero_kill:true flag")
		# Slower time_scale than standard (standard BT_SCALE=0.07; hero_kill=0.05)
		check(float(bt.time_scale) < 0.06, "enriched (c): hero_kill time_scale < 0.06 (got %.3f)" % float(bt.time_scale))
```

- [ ] **Step 3: Call _check_enriched_shots from _initialize**

Change `_initialize` in hybrid_check.gd from:
```gdscript
func _initialize() -> void:
	_check_hybrid_shot_list()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
```
to:
```gdscript
func _initialize() -> void:
	_check_hybrid_shot_list()
	_check_enriched_shots()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
```

- [ ] **Step 4: Run hybrid_check headless to confirm all new assertions pass**

```
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/hybrid_check.gd
```

Expected: all existing checks pass AND the three new enriched checks pass. Output will include lines like:
```
PASS  enriched (a): swarm/burst-only fight yields >= 1 hero intercut (got 2)
PASS  enriched (b): log with pop-up advances yields >= 1 popup_burst shot
PASS  enriched (b): log with dodge-pursuit run yields >= 1 chase_pursuit shot
PASS  enriched (c): hero_kill bullet-time window > 0.55s realtime (got 0.800)
PASS  enriched (c): bullet_time shot dict carries hero_kill:true flag
PASS  enriched (c): hero_kill time_scale < 0.06 (got 0.050)
---- ALL PASS
```

If any check fails, diagnose whether it's a build_shot_list logic error (wrong t0/t1 arithmetic, wrong chase detection) or a test build issue (build with no fire_beam from A, hero_kill triggering). Fix in hybrid.gd first, not in the test.

---

## Task 6: Run all six director variant checks and build_fight_sim_check

**Files:** read-only (test execution only)

This task proves the sibling variants are unaffected and the sim check is still green.

- [ ] **Step 1: Run all headless checks**

Run each command and capture its exit line:

```
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/director_check.gd
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/iso_check.gd
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/blend_check.gd
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/witness_check.gd
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/broadcast_check.gd
godot --path "D:/Claude/Mech Bags/godot_director_spike" --headless -s res://tests/build_fight_sim_check.gd
```

Expected: every run exits `---- ALL PASS` and exit code 0.

- [ ] **Step 2: If any variant fails**

The sibling variants (`iso.gd`, `blend.gd`, `witness.gd`, `broadcast.gd`, `cinematic.gd`) and `director.gd` are NOT edited by this plan. A failure here means `hybrid.gd` changed something shared — which it cannot because `hybrid.gd` only `extends "res://scripts/director.gd"` and only overrides `build_shot_list` and `_update_camera`. If a failure occurs, check for a GDScript parse error in `hybrid.gd` (a bad `const FIRE_KINDS` placement — GDScript does not allow `const` inside a function body; move it outside or inline the array literal). Fix before proceeding.

---

## Task 7: Extend enriched_render_shot.gd with three proof frames

**Files:**
- Modify: `godot_director_spike/tests/enriched_render_shot.gd`

The existing script captures four frames. Add three more for: (a) hero cut on NON-beam fire event, (b) dodge-pursuit chase shot, (c) escalated hero_kill. The existing build already has a swarm weapon (missiles fx) so `fire_swarm` events are present.

- [ ] **Step 1: Read the current enriched_render_shot.gd in full**

You already have it above (lines 1-109). The four existing captures are at lines 80-99.

- [ ] **Step 2: Add three more frame captures**

The timing for new frames:

- **(a) hero cut on non-beam fire**: The swarm/burst build fires `fire_swarm` and `fire_burst` events. The first swarm event fires within the first few seconds (high regen build). The `hero_os` shot triggers on the first fire event at t≈0-2s. A `hero_cut` on a swarm event appears in the mid-fight. Capture at t≈5s wall-clock (after the existing `enriched_swarm_volley` frame at t=4s). This frame should show the perspective `hero_cut` camera angle coinciding with a non-beam fire event.

- **(b) chase shot**: The dodge-pursuit run is at t≈10-13s game time. We're already ~4s in after frame 2. The existing `enriched_dodge_pursuit` frame captures at t≈11s wall-clock total. Capture the CHASE shot at t≈12s wall-clock total (1s after the existing dodge-pursuit frame, so we're well inside the chase_pursuit window).

- **(c) escalated hero_kill**: The existing `enriched_hero_kill` capture fires at t≈23.5s wall-clock total. Capture a second frame 0.5s earlier (at t≈23s) to get the mid-arc of the wider hero_kill bullet-time orbit before it completes.

Replace the capture block (lines 80-99) with:

```gdscript
	# Frame 1 — Phase 1 pop-up burst: hop emitted at tick 20 (~t=2.0s).
	await create_timer(2.5).timeout
	_capture("enriched_popup_burst")

	# Frame 2 — swarm volley in flight (~t=4s).
	await create_timer(1.5).timeout
	_capture("enriched_swarm_volley")

	# Frame 2b — hero cut on NON-beam fire event: the hybrid director fires a hero_cut
	# on the mid-fight swarm/burst volley. By ~5s wall-clock we are past the hero_os
	# window and into the first mid-fight hero_cut triggered by a fire_swarm or fire_burst.
	await create_timer(1.0).timeout
	_capture("enriched_hero_cut_nonbeam")

	# Frame 3 — dodge-pursuit weave (~t=11s wall-clock total).
	await create_timer(6.0).timeout
	_capture("enriched_dodge_pursuit")

	# Frame 3b — chase_pursuit tracking shot: 1s into the weave window, the hybrid
	# director is in chase_pursuit mode. Capture the wide tracking angle.
	await create_timer(1.0).timeout
	_capture("enriched_chase_pursuit")

	# Frame 4 — hero_kill escalated bullet-time orbit: capture mid-arc before it exits.
	await create_timer(11.0).timeout
	_capture("enriched_hero_kill")

	# Frame 4b — hero_kill orbit completion: 0.5s later, the wider arc is still live
	# (hero_kill window is 0.6s realtime vs 0.35s standard).
	await create_timer(0.5).timeout
	_capture("enriched_hero_kill_arc")
```

Also update the print line at line 101:
```gdscript
	print("enriched_render_shot: all frames captured — see res://tmp/")
```
(unchanged; it already prints this).

- [ ] **Step 3: Run enriched_render_shot.gd windowed and capture all frames**

```
godot --path "D:/Claude/Mech Bags/godot_director_spike" -s res://tests/enriched_render_shot.gd
```

Expected:
- No `push_warning` or "unknown" mode in output
- Seven `saved res://tmp/enriched_*.png` lines printed
- Exit 0

Actual frame files (GDScript `res://` maps to the project directory):
```
D:\Claude\Mech Bags\godot_director_spike\tmp\enriched_popup_burst.png
D:\Claude\Mech Bags\godot_director_spike\tmp\enriched_swarm_volley.png
D:\Claude\Mech Bags\godot_director_spike\tmp\enriched_hero_cut_nonbeam.png
D:\Claude\Mech Bags\godot_director_spike\tmp\enriched_dodge_pursuit.png
D:\Claude\Mech Bags\godot_director_spike\tmp\enriched_chase_pursuit.png
D:\Claude\Mech Bags\godot_director_spike\tmp\enriched_hero_kill.png
D:\Claude\Mech Bags\godot_director_spike\tmp\enriched_hero_kill_arc.png
```

Inspect `enriched_hero_cut_nonbeam.png` visually: the camera should be in a low, close, side-on perspective angle (the `hero_cut` pose) — not the isometric top-down. If you still see iso, the `hero_cut` window for the first swarm volley may be occurring slightly later; try increasing the wait before `enriched_hero_cut_nonbeam` to 1.5s.

Inspect `enriched_chase_pursuit.png`: camera should be wide and lateral (above and to the side), framing both mechs, distinctly different from the tight `hero_cut` pose. The evader should be visible mid-weave.

Inspect `enriched_hero_kill.png` and `enriched_hero_kill_arc.png`: camera should be at a noticeably wider arc than a standard kill (radius 42 vs 32), higher off the ground, and still orbiting (the longer BT_POST gives it more time to sweep).

---

## Self-Review

### Spec coverage check

| Requirement | Task covering it |
|---|---|
| 1. Broaden intercut to all fire events | Task 1 Step 3 |
| 2. Overload build-up beat | Task 3 Step 1 |
| 3. Pop-up burst punctuation (`popup_burst`) | Task 3 Step 2 |
| 3. Dodge-pursuit chase shot (`chase_pursuit`) | Task 3 Step 3 |
| 4. hero_kill escalated camera arc (bigger/longer bullet-time) | Task 2 Steps 2-3 |
| 5. UC F4 camera as active second actor | Covered by existing iso backbone + all new intercepts keep reframing between planes |
| 5. UC F5 authored cut rhythm (establish→mid→close→reaction, varied durations) | Shot durations: hero_os 1.8s, hero_cut 1.8s, popup_burst 1.2s, chase_pursuit 2.5s, melee_cut 2.2s |
| 5. UC F6 framing-for-scale (low/wide = awe; tight OTS = impact) | popup_burst: low angle looking up; chase_pursuit: wide lateral; hero_cut: tight side-on |
| Keep all six variants working | Task 6 |
| Extend hybrid_check.gd | Task 5 |
| Render proof frames | Task 7 |
| No sim/log/dispatch changes | Only hybrid.gd and test files edited |
| Determinism | build_shot_list is a pure function with no RNG; same log → same shots |

### Placeholder scan

No TBDs. All code blocks are complete. All commands have expected output.

### Type consistency check

- `FIRE_KINDS` is used only in Task 1 Step 3 as an inline constant inside `build_shot_list`. GDScript does NOT allow `const` declarations inside function bodies. Use `var FIRE_KINDS := [...]` instead, or define it at class level. **Fix:** define `FIRE_KINDS` as a class-level constant alongside the other `const` declarations at the top of `hybrid.gd` (after `const ISO_OFFSET`).

**Corrected Step 3 of Task 1:** do NOT write `const FIRE_KINDS :=` inside `build_shot_list`. Instead, add to the class-level constants block (after `const ISO_OFFSET := ...`):
```gdscript
const FIRE_KINDS := ["fire_beam", "fire_burst", "fire_swarm", "fire_buster"]
```
Then in `build_shot_list`, simply reference `FIRE_KINDS`:
```gdscript
	for e in events:
		if not (e.kind in FIRE_KINDS) or e.payload.get("lethal", false):
			continue
```

- `lethal_kind` and `hero_kill_flag` are declared at the top of `build_shot_list` in Task 2 Step 1, then consumed later in the same function. Consistent.

- `bt_post` and `bt_scale` are local vars in `build_shot_list`, consumed immediately in the `fixed.append` in Task 2 Step 2. Consistent.

- `chase_actor` is set but only used as the `focus` field of the `chase_pursuit` shot in Task 3 Step 3. In `_update_camera`, `s.focus` maps to `actors[s.focus]` which expects `"A"` or `"B"`. `chase_actor` is set to `str(e.actor)` where `e.actor` is always `"A"` or `"B"` from the sim. Consistent.

- `wall_len` in the revised `bullet_time` branch in Task 2 Step 3 divides by `bt_ts` not `BT_SCALE` — this is correct because `s.time_scale` is the actual value stored in the shot (either `BT_SCALE=0.07` or `0.05` for hero_kill). Consistent.

- `is_hk` reads `bool(s.get("hero_kill", false))` — the shot dict always has this key from Task 2 Step 2. Consistent.
