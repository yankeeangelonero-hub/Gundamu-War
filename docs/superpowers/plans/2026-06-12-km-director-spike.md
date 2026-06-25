# KM-DIRECTOR-SPIKE Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A throwaway Godot 4.6 scene that plays a ~25s cinematic night-city mech duel from a hand-authored event log through a director camera with VFX/audio garnish — the engine exit-test and log→director→spectacle pipeline proof defined in `Research/Research Documents/design-spec-2026-06-12-cinematic-3d-combat-direction-and-director-spike.md`.

**Architecture:** New standalone Godot project `godot_director_spike/` (Forward+ renderer — the existing `godot_spike/` is GL Compatibility, which cannot do volumetric fog/SDFGI; do not touch it). Everything is text-authored: scenes are built procedurally in GDScript, no editor work. Data flows one way: `fight_log.json` → `director.gd` (pre-reads whole log, builds a shot list, plays it back) → actors/garnish/audio. Garnish never affects outcomes. Pure logic (log loading, shot-list building) is TDD'd via headless `SceneTree` scripts; visual layers are verified by observation checkpoints and a final movie capture.

**Tech Stack:** Godot 4.6.3 (`godot` on PATH), GDScript only, no addons, no downloaded assets (audio is synthesized in code).

**Conventions:** Run all commands from repo root `D:\Claude\Mech Bags`. Headless tests: `godot --headless --path godot_director_spike --script res://tests/director_check.gd` (exit 0 = pass). Commits are plain messages, no co-author trailers.

---

### Task 1: Project scaffold

**Files:**
- Create: `godot_director_spike/project.godot`
- Create: `godot_director_spike/.gitignore`
- Create: `godot_director_spike/scenes/main.tscn`
- Create: `godot_director_spike/scripts/main.gd`

- [ ] **Step 1: Write project config**

`godot_director_spike/project.godot`:

```ini
config_version=5

[application]

config/name="KM-DIRECTOR-SPIKE"
config/features=PackedStringArray("4.6", "Forward Plus")
run/main_scene="res://scenes/main.tscn"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080

[editor]

movie_writer/mjpeg_quality=0.9
movie_writer/movie_file="tmp/money-shot.avi"
movie_writer/fps=60

[rendering]

renderer/rendering_method="forward_plus"
```

`godot_director_spike/.gitignore`:

```
.godot/
tmp/
```

- [ ] **Step 2: Write minimal main scene + script**

`godot_director_spike/scripts/main.gd`:

```gdscript
extends Node3D

func _ready() -> void:
	print("KM-DIRECTOR-SPIKE boot ok")
```

`godot_director_spike/scenes/main.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]

[node name="Main" type="Node3D"]
script = ExtResource("1")
```

- [ ] **Step 3: Import and smoke-run headless**

Run: `godot --headless --path godot_director_spike --import`
Expected: exits cleanly, creates `godot_director_spike/.godot/`.

Run: `godot --headless --path godot_director_spike --quit-after 5`
Expected: output contains `KM-DIRECTOR-SPIKE boot ok`, exit code 0.

- [ ] **Step 4: Commit**

```bash
git add godot_director_spike
git commit -m "feat(spike): scaffold KM-DIRECTOR-SPIKE Godot project (Forward+)"
```

---

### Task 2: Fight log — data + validated loader (TDD)

**Files:**
- Create: `godot_director_spike/tests/director_check.gd`
- Create: `godot_director_spike/data/fight_log.json`
- Create: `godot_director_spike/scripts/fight_log.gd`

- [ ] **Step 1: Write the failing test**

`godot_director_spike/tests/director_check.gd`:

```gdscript
extends SceneTree
## Headless checks for the spike's pure logic. Exit 0 = pass.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	_check_fight_log()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

func _check_fight_log() -> void:
	var FightLog := load("res://scripts/fight_log.gd")
	var events: Array = FightLog.load_events("res://data/fight_log.json")
	check(events.size() >= 15, "log has >= 15 events (got %d)" % events.size())
	var sorted := true
	var prev := -1
	for e in events:
		if int(e.tick) < prev:
			sorted = false
		prev = int(e.tick)
		check(e.has("tick") and e.has("actor") and e.has("kind") and e.has("payload"),
			"event T%s has all required fields" % str(e.get("tick")))
	check(sorted, "events sorted by tick")
	var kinds := {}
	for e in events:
		kinds[e.kind] = true
	for k in ["spawn", "advance", "fire_beam", "fire_burst", "destroyed"]:
		check(kinds.has(k), "log contains kind '%s'" % k)
	var lethal := events.filter(func(e): return e.kind == "fire_beam" and e.payload.get("lethal", false))
	check(lethal.size() == 1, "exactly one lethal beam")
	var blocked := events.filter(func(e): return e.kind == "fire_beam" and e.payload.get("blocked", false))
	check(blocked.size() == 1, "exactly one blocked beam")
	check(FightLog.duration_sec(events) > 20.0, "fight duration > 20s")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot_director_spike --script res://tests/director_check.gd`
Expected: FAILS (script error: `res://scripts/fight_log.gd` does not exist). A hard parse/load error is the failing state here.

- [ ] **Step 3: Author the fight log**

`godot_director_spike/data/fight_log.json` — the 25s beat sheet (ticks at 10/s; stage is a street along X; A starts at −40, B at +40; A wins at 42 HP; one miss, one blocked shot, one overkill kill):

```json
{
  "schema": "km-director-spike-fight-log-v1",
  "tick_seconds": 0.1,
  "events": [
    {"tick": 0,   "actor": "A", "kind": "spawn",      "payload": {"x": -40.0, "hp": 100}},
    {"tick": 0,   "actor": "B", "kind": "spawn",      "payload": {"x": 40.0,  "hp": 100}},
    {"tick": 10,  "actor": "A", "kind": "advance",    "payload": {"to_x": -22.0, "end_tick": 60}},
    {"tick": 20,  "actor": "B", "kind": "fire_burst", "payload": {"rounds": 6, "hits": 2, "damage": 8,  "hp_after": 92}},
    {"tick": 45,  "actor": "A", "kind": "fire_beam",  "payload": {"hit": false, "damage": 0}},
    {"tick": 70,  "actor": "B", "kind": "advance",    "payload": {"to_x": 24.0, "end_tick": 100}},
    {"tick": 80,  "actor": "B", "kind": "fire_burst", "payload": {"rounds": 8, "hits": 3, "damage": 12, "hp_after": 80}},
    {"tick": 100, "actor": "A", "kind": "fire_beam",  "payload": {"hit": true, "damage": 30, "hp_after": 70}},
    {"tick": 120, "actor": "B", "kind": "fire_beam",  "payload": {"hit": true, "damage": 22, "hp_after": 58}},
    {"tick": 140, "actor": "A", "kind": "advance",    "payload": {"to_x": -8.0, "end_tick": 180}},
    {"tick": 150, "actor": "B", "kind": "fire_burst", "payload": {"rounds": 10, "hits": 4, "damage": 16, "hp_after": 42}},
    {"tick": 170, "actor": "B", "kind": "fire_beam",  "payload": {"hit": false, "blocked": true, "damage": 0}},
    {"tick": 190, "actor": "A", "kind": "fire_burst", "payload": {"rounds": 6, "hits": 5, "damage": 20, "hp_after": 50}},
    {"tick": 210, "actor": "B", "kind": "advance",    "payload": {"to_x": 32.0, "end_tick": 230}},
    {"tick": 230, "actor": "A", "kind": "fire_beam",  "payload": {"hit": true, "damage": 64, "hp_after": -14, "lethal": true, "overkill": true}},
    {"tick": 235, "actor": "B", "kind": "destroyed",  "payload": {}}
  ]
}
```

Conventions an executor must keep: `actor` is who acts; damage events carry the *target's* `hp_after`; `advance` is start-tick + `end_tick` so playback can tween; misses have `hit: false`; the block is a `fire_beam` with `blocked: true`.

- [ ] **Step 4: Write the loader**

`godot_director_spike/scripts/fight_log.gd`:

```gdscript
## Loads and validates the hand-authored fight log.
## This file's schema doubles as the assumed future sim event contract.

const REQUIRED := ["tick", "actor", "kind", "payload"]
const KINDS := ["spawn", "advance", "fire_beam", "fire_burst", "destroyed"]

static func load_events(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "fight log missing: " + path)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	assert(parsed is Dictionary and parsed.has("events"), "bad fight log root")
	var events: Array = parsed.events
	for e in events:
		for k in REQUIRED:
			assert(e.has(k), "event missing field '%s': %s" % [k, str(e)])
		assert(e.kind in KINDS, "unknown event kind: " + str(e.kind))
		assert(e.actor in ["A", "B"], "unknown actor: " + str(e.actor))
	events.sort_custom(func(a, b): return int(a.tick) < int(b.tick))
	return events

static func duration_sec(events: Array, tick_seconds := 0.1, tail := 5.0) -> float:
	return float(events[-1].tick) * tick_seconds + tail
```

- [ ] **Step 5: Run test to verify it passes**

Run: `godot --headless --path godot_director_spike --script res://tests/director_check.gd`
Expected: all `PASS` lines, `---- ALL PASS`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add godot_director_spike/tests godot_director_spike/data godot_director_spike/scripts/fight_log.gd
git commit -m "feat(spike): hand-authored fight log + validated loader (event contract v1)"
```

---

### Task 3: Shot-list builder (TDD)

The director's pure-logic half: read the whole log, emit a sorted, gap-free list of camera shots. Dramatic shots are placed first (killcam over the lethal beam, punch-in on the block, orbit after the killcam, establishing wide at 0); gaps are filled with dollies (when an advance is active) or two-shots.

**Files:**
- Create: `godot_director_spike/scripts/director.gd` (static half only; runtime half comes in Task 6)
- Modify: `godot_director_spike/tests/director_check.gd`

- [ ] **Step 1: Add failing tests**

Append to `godot_director_spike/tests/director_check.gd` — add the call in `_initialize()` after `_check_fight_log()`:

```gdscript
	_check_shot_list()
```

and the method:

```gdscript
func _check_shot_list() -> void:
	var FightLog := load("res://scripts/fight_log.gd")
	var Director := load("res://scripts/director.gd")
	var events: Array = FightLog.load_events("res://data/fight_log.json")
	var dur: float = FightLog.duration_sec(events)
	var shots: Array = Director.build_shot_list(events, dur)
	check(shots.size() >= 5, "shot list has >= 5 shots (got %d)" % shots.size())
	check(absf(float(shots[0].t0)) < 0.001 and shots[0].mode == "wide", "first shot is establishing wide at t=0")
	var covered := true
	var monotonic := true
	for i in shots.size():
		var s: Dictionary = shots[i]
		if float(s.t1) <= float(s.t0):
			monotonic = false
		if i > 0 and absf(float(s.t0) - float(shots[i - 1].t1)) > 0.001:
			covered = false
	check(monotonic, "every shot has t1 > t0")
	check(covered, "shots are contiguous (no gaps/overlaps)")
	check(absf(float(shots[-1].t1) - dur) < 0.001, "last shot ends at fight duration")
	var lethal_t := 0.0
	for e in events:
		if e.kind == "fire_beam" and e.payload.get("lethal", false):
			lethal_t = float(e.tick) * 0.1
	var first_beam_t := -1.0
	for e in events:
		if e.kind == "fire_beam":
			first_beam_t = float(e.tick) * 0.1
			break
	var overshoulder := shots.filter(func(s): return s.mode == "over_shoulder")
	check(overshoulder.size() == 1, "exactly one over-shoulder shot")
	if overshoulder.size() == 1:
		check(float(overshoulder[0].t0) <= first_beam_t and first_beam_t <= float(overshoulder[0].t1),
			"over-shoulder spans the first beam tick")
	var killcam := shots.filter(func(s): return s.mode == "killcam")
	check(killcam.size() == 1, "exactly one killcam shot")
	if killcam.size() == 1:
		var k: Dictionary = killcam[0]
		check(float(k.t0) <= lethal_t and lethal_t <= float(k.t1), "killcam spans the lethal beam tick")
		check(float(k.time_scale) < 1.0, "killcam dilates time")
	check(shots[-1].mode == "orbit", "final shot is the wreck orbit")
	var normal := shots.filter(func(s): return s.mode != "killcam")
	check(normal.all(func(s): return absf(float(s.time_scale) - 1.0) < 0.001), "only killcam changes time_scale")
```

- [ ] **Step 2: Run to verify failure**

Run: `godot --headless --path godot_director_spike --script res://tests/director_check.gd`
Expected: FAILS — `res://scripts/director.gd` does not exist.

- [ ] **Step 3: Implement the builder**

`godot_director_spike/scripts/director.gd`:

```gdscript
extends Node3D
## Director: pre-reads the fight log and turns it into staging + camera.
## This file: static shot-list builder (pure, headless-testable).
## Runtime playback is added in Task 6 below the marker comment.

const TICK := 0.1
const WIDE_LEN := 3.0
const KILLCAM_PRE := 0.5
const KILLCAM_POST := 2.5
const PUNCH_PRE := 0.3
const PUNCH_POST := 0.9
const FILLER_MAX := 4.0

static func build_shot_list(events: Array, dur: float) -> Array:
	var fixed: Array = [{"t0": 0.0, "t1": WIDE_LEN, "mode": "wide", "focus": "", "time_scale": 1.0}]
	var killcam_end := dur
	var first_beam_done := false
	for e in events:
		var t := float(e.tick) * TICK
		if e.kind == "fire_beam" and not first_beam_done:
			# the first exchange gets an over-shoulder regardless of outcome
			first_beam_done = true
			fixed.append({"t0": t - 0.3, "t1": t + 1.5, "mode": "over_shoulder",
				"focus": str(e.actor), "time_scale": 1.0})
		if e.kind == "fire_beam" and e.payload.get("lethal", false):
			fixed.append({"t0": t - KILLCAM_PRE, "t1": t + KILLCAM_POST, "mode": "killcam",
				"focus": str(e.actor), "time_scale": 0.25})
			killcam_end = t + KILLCAM_POST
		elif e.kind == "fire_beam" and e.payload.get("blocked", false):
			fixed.append({"t0": t - PUNCH_PRE, "t1": t + PUNCH_POST, "mode": "punch_in",
				"focus": _other(str(e.actor)), "time_scale": 1.0})
	fixed.append({"t0": killcam_end, "t1": dur, "mode": "orbit", "focus": "", "time_scale": 1.0})
	fixed.sort_custom(func(a, b): return float(a.t0) < float(b.t0))

	# Fill gaps between fixed shots with dollies (advance active) or two-shots.
	var shots: Array = []
	var cursor := 0.0
	var side := "A"
	for s in fixed:
		var t0 := maxf(float(s.t0), cursor)
		while t0 - cursor > 0.001:
			var seg_end := minf(cursor + FILLER_MAX, t0)
			var adv := _advance_active_at(events, cursor)
			if adv != "":
				shots.append({"t0": cursor, "t1": seg_end, "mode": "dolly", "focus": adv, "time_scale": 1.0})
			else:
				shots.append({"t0": cursor, "t1": seg_end, "mode": "two_shot", "focus": side, "time_scale": 1.0})
				side = _other(side)
			cursor = seg_end
		if float(s.t1) > cursor:
			var clipped := s.duplicate()
			clipped.t0 = cursor
			shots.append(clipped)
			cursor = float(s.t1)
	return shots

static func _advance_active_at(events: Array, t: float) -> String:
	for e in events:
		if e.kind == "advance":
			var t0 := float(e.tick) * TICK
			var t1 := float(e.payload.end_tick) * TICK
			if t >= t0 and t < t1:
				return str(e.actor)
	return ""

static func _other(actor: String) -> String:
	return "B" if actor == "A" else "A"

# ---- runtime playback added in Task 6 ----
```

- [ ] **Step 4: Run tests to verify pass**

Run: `godot --headless --path godot_director_spike --script res://tests/director_check.gd`
Expected: `---- ALL PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot_director_spike/scripts/director.gd godot_director_spike/tests/director_check.gd
git commit -m "feat(spike): director shot-list builder with killcam/punch-in/orbit grammar"
```

---

### Task 4: Night city stage + environment + camera mount

Grey-box city, volumetric fog, SDFGI, glow, moonlight + street practicals. After this task a windowed run shows a moody empty street.

**Files:**
- Create: `godot_director_spike/scripts/city_builder.gd`
- Modify: `godot_director_spike/scripts/main.gd`

- [ ] **Step 1: Write the city builder**

`godot_director_spike/scripts/city_builder.gd`:

```gdscript
## Builds the grey-box night city procedurally. Deterministic via fixed seed.

static func build(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260612

	var ground := MeshInstance3D.new()
	var gmesh := PlaneMesh.new()
	gmesh.size = Vector2(400, 400)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.05, 0.055, 0.07)
	gmat.roughness = 0.25
	gmat.metallic = 0.1
	gmesh.material = gmat
	ground.mesh = gmesh
	parent.add_child(ground)

	# Buildings flanking a street that runs along X. Street half-width 14.
	for i in range(60):
		var b := MeshInstance3D.new()
		var box := BoxMesh.new()
		var h := rng.randf_range(18.0, 70.0)
		box.size = Vector3(rng.randf_range(10.0, 22.0), h, rng.randf_range(10.0, 22.0))
		var mat := StandardMaterial3D.new()
		var shade := rng.randf_range(0.06, 0.12)
		mat.albedo_color = Color(shade, shade, shade * 1.15)
		mat.roughness = 0.7
		box.material = mat
		b.mesh = box
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		b.position = Vector3(rng.randf_range(-90.0, 90.0), h * 0.5,
			side * rng.randf_range(16.0, 60.0))
		parent.add_child(b)
		if rng.randf() < 0.4:
			var win := MeshInstance3D.new()
			var wmesh := BoxMesh.new()
			wmesh.size = Vector3(box.size.x * 0.9, rng.randf_range(1.0, 2.5), 0.3)
			var wmat := StandardMaterial3D.new()
			wmat.emission_enabled = true
			wmat.emission = Color(0.9, 0.6, 0.25) if rng.randf() < 0.5 else Color(0.4, 0.7, 0.9)
			wmat.emission_energy_multiplier = 2.0
			wmesh.material = wmat
			win.mesh = wmesh
			win.position = b.position + Vector3(0, rng.randf_range(-h * 0.3, h * 0.3),
				-signf(b.position.z) * (box.size.z * 0.5 + 0.2))
			parent.add_child(win)

	for x in range(-80, 81, 20):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.75, 0.45)
		lamp.light_energy = 3.0
		lamp.omni_range = 22.0
		lamp.position = Vector3(x, 9.0, 12.0 * (1 if (x / 20) % 2 == 0 else -1))
		parent.add_child(lamp)

static func build_environment(parent: Node3D) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.2)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 0.9
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.025
	env.volumetric_fog_albedo = Color(0.6, 0.65, 0.8)
	env.sdfgi_enabled = true
	we.environment = env
	parent.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.5
	moon.rotation_degrees = Vector3(-35, 140, 0)
	moon.shadow_enabled = true
	parent.add_child(moon)
```

- [ ] **Step 2: Wire into main + add still-capture flag**

Replace `godot_director_spike/scripts/main.gd`:

```gdscript
extends Node3D

const CityBuilder := preload("res://scripts/city_builder.gd")

var camera: Camera3D

func _ready() -> void:
	CityBuilder.build_environment(self)
	CityBuilder.build(self)
	camera = Camera3D.new()
	camera.position = Vector3(0, 45, 90)
	camera.fov = 55
	add_child(camera)
	camera.look_at(Vector3(0, 10, 0), Vector3.UP)
	print("KM-DIRECTOR-SPIKE boot ok")
	if "--still" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("res://tmp")
		img.save_png("res://tmp/still.png")
		print("still saved")
		get_tree().quit()
```

- [ ] **Step 3: Visual checkpoint**

Run: `godot --path godot_director_spike -- --still`
Expected: a window appears for ~1s; `godot_director_spike/tmp/still.png` is written. **Look at the image:** dark street receding along X, grey towers both sides, warm street lamps glowing through fog, a few lit window strips. A black frame is a failure.

- [ ] **Step 4: Regression check + commit**

Run: `godot --headless --path godot_director_spike --script res://tests/director_check.gd`
Expected: still `ALL PASS`.

```bash
git add godot_director_spike/scripts
git commit -m "feat(spike): procedural night-city stage with fog, SDFGI, glow"
```

---

### Task 5: Block-out mech actors

Articulated grey-box mechs (~16m tall): pelvis/torso/head/arms/legs as separate boxes so recoil, flinch, block, walk-bob, and death scatter read. Right arm carries the gun; its tip is the muzzle.

**Files:**
- Create: `godot_director_spike/scripts/mech_actor.gd`
- Modify: `godot_director_spike/scripts/main.gd`

- [ ] **Step 1: Write the actor**

`godot_director_spike/scripts/mech_actor.gd`:

```gdscript
extends Node3D
## Block-out mech. All motion is presentation: the log decides outcomes.

var actor_id := "A"
var tint := Color(0.3, 0.5, 0.8)
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var muzzle: Node3D
var moving := false
var dead := false
var _bob_t := 0.0

func setup(id: String, color: Color, x: float) -> void:
	actor_id = id
	tint = color
	position = Vector3(x, 0, 0)

func _ready() -> void:
	var pelvis := _box(Vector3(4.5, 2.0, 3.0), Vector3(0, 7.5, 0))
	torso = _box(Vector3(5.5, 4.5, 3.5), Vector3(0, 11.0, 0))
	head = _box(Vector3(1.8, 1.6, 2.0), Vector3(0, 14.0, 0))
	# visor: single emissive band (original identity rule: no twin-eye)
	var visor := _box(Vector3(1.6, 0.35, 0.2), Vector3(0, 14.1, 1.1), true)
	arm_l = _box(Vector3(1.6, 5.0, 1.6), Vector3(-3.8, 11.0, 0))
	arm_r = _box(Vector3(1.6, 5.0, 1.6), Vector3(3.8, 11.0, 0))
	var gun := _box(Vector3(0.9, 0.9, 6.0), Vector3(3.8, 9.0, 2.5))
	muzzle = Node3D.new()
	muzzle.position = Vector3(3.8, 9.0, 5.5)
	add_child(muzzle)
	for leg_x in [-1.6, 1.6]:
		_box(Vector3(2.0, 6.5, 2.4), Vector3(leg_x, 3.25, 0))
	look_at_enemy_side()

func _box(size: Vector3, pos: Vector3, emissive := false) -> Node3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	if emissive:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.2, 0.1) if actor_id == "B" else Color(0.2, 0.8, 1.0)
		mat.emission_energy_multiplier = 6.0
	else:
		mat.albedo_color = tint
		mat.roughness = 0.5
		mat.metallic = 0.4
	mesh.material = mat
	m.mesh = mesh
	m.position = pos
	add_child(m)
	return m

func look_at_enemy_side() -> void:
	rotation.y = deg_to_rad(-90) if actor_id == "A" else deg_to_rad(90)

func _process(delta: float) -> void:
	if dead:
		return
	if moving:
		_bob_t += delta * 7.0
		torso.position.y = 11.0 + sin(_bob_t) * 0.25
		rotation.z = sin(_bob_t * 0.5) * 0.015
	else:
		torso.position.y = lerpf(torso.position.y, 11.0, 5.0 * delta)
		rotation.z = lerpf(rotation.z, 0.0, 5.0 * delta)

func walk_to(to_x: float, dur: float) -> void:
	moving = true
	var tw := create_tween()
	tw.tween_property(self, "position:x", to_x, dur)
	tw.tween_callback(func(): moving = false)

func muzzle_pos() -> Vector3:
	return muzzle.global_position

func recoil() -> void:
	var tw := create_tween()
	tw.tween_property(torso, "position:z", -0.6, 0.05)
	tw.tween_property(torso, "position:z", 0.0, 0.25)

func flinch(big: bool) -> void:
	var amt := 0.10 if big else 0.04
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", -amt, 0.06)
	tw.tween_property(self, "rotation:x", 0.0, 0.3)

func block_pose() -> void:
	var tw := create_tween()
	tw.tween_property(arm_l, "rotation:x", deg_to_rad(-70), 0.12)
	tw.tween_interval(0.5)
	tw.tween_property(arm_l, "rotation:x", 0.0, 0.4)

func die() -> void:
	dead = true
	moving = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for c in get_children():
		if c is MeshInstance3D:
			var tw := create_tween().set_parallel(true)
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1), rng.randf_range(-1, 1)) * rng.randf_range(4.0, 12.0)
			tw.tween_property(c, "position", c.position + dir, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "rotation", Vector3(rng.randf_range(-2, 2), rng.randf_range(-2, 2), rng.randf_range(-2, 2)), 1.2)
			if c.mesh.material is StandardMaterial3D and not c.mesh.material.emission_enabled:
				tw.tween_property(c.mesh.material, "albedo_color", Color(0.05, 0.04, 0.04), 0.8)
```

- [ ] **Step 2: Place both mechs in main**

In `godot_director_spike/scripts/main.gd`, add the preload at the top with the others, and spawn in `_ready()` after `CityBuilder.build(self)`:

```gdscript
const MechActor := preload("res://scripts/mech_actor.gd")

var mech_a: Node3D
var mech_b: Node3D
```

```gdscript
	mech_a = MechActor.new()
	mech_a.setup("A", Color(0.30, 0.45, 0.75), -40.0)
	add_child(mech_a)
	mech_b = MechActor.new()
	mech_b.setup("B", Color(0.70, 0.30, 0.25), 40.0)
	add_child(mech_b)
```

- [ ] **Step 3: Visual checkpoint**

Run: `godot --path godot_director_spike -- --still`
Expected in `tmp/still.png`: two articulated block-out mechs facing each other down the street, blue-grey left, red-brown right, visor bands glowing, clearly dwarfed-but-giant against the buildings (mechs ~16m vs towers 18–70m). Verify scale reads.

- [ ] **Step 4: Commit**

```bash
git add godot_director_spike/scripts
git commit -m "feat(spike): articulated block-out mech actors with motion verbs"
```

---

### Task 6: Director runtime — playback clock, event dispatch, camera grammar

After this task the whole fight plays back with motion and camera direction (no VFX yet — Task 7 garnishes it).

**Files:**
- Modify: `godot_director_spike/scripts/director.gd` (runtime half, below the Task 3 marker)
- Modify: `godot_director_spike/scripts/main.gd`

- [ ] **Step 1: Add runtime playback to director.gd**

Append below `# ---- runtime playback added in Task 6 ----`:

```gdscript
signal fight_event(e: Dictionary)
signal fight_over

var events: Array = []
var shots: Array = []
var camera: Camera3D
var actors: Dictionary = {}   # "A"/"B" -> mech node
var playing := false
var t := 0.0
var _event_idx := 0
var _shot_idx := -1
var shake_strength := 0.0
var _dur := 0.0

func start(p_events: Array, p_shots: Array, p_camera: Camera3D, p_actors: Dictionary, dur: float) -> void:
	events = p_events
	shots = p_shots
	camera = p_camera
	actors = p_actors
	_dur = dur
	playing = true

func _process(delta: float) -> void:
	if not playing:
		return
	t += delta
	while _event_idx < events.size() and float(events[_event_idx].tick) * TICK <= t:
		_dispatch(events[_event_idx])
		_event_idx += 1
	_update_shot()
	_update_camera(delta)
	shake_strength = maxf(0.0, shake_strength - delta * 3.0)
	if t >= _dur:
		playing = false
		Engine.time_scale = 1.0
		fight_over.emit()

func _dispatch(e: Dictionary) -> void:
	var actor: Node3D = actors[e.actor]
	var target: Node3D = actors[_other(str(e.actor))]
	match e.kind:
		"advance":
			var dur := (float(e.payload.end_tick) - float(e.tick)) * TICK
			actor.walk_to(float(e.payload.to_x), dur)
		"fire_beam":
			actor.recoil()
			if e.payload.get("blocked", false):
				target.block_pose()
			elif e.payload.get("hit", false):
				target.flinch(float(e.payload.damage) > 25.0)
		"fire_burst":
			actor.recoil()
			if int(e.payload.hits) > 0:
				target.flinch(false)
		"destroyed":
			actor.die()
			shake_strength = 1.0
	fight_event.emit(e)

func _update_shot() -> void:
	while _shot_idx + 1 < shots.size() and float(shots[_shot_idx + 1].t0) <= t:
		_shot_idx += 1
		Engine.time_scale = float(shots[_shot_idx].time_scale)

func _update_camera(delta: float) -> void:
	if _shot_idx < 0:
		return
	var s: Dictionary = shots[_shot_idx]
	var a: Node3D = actors["A"]
	var b: Node3D = actors["B"]
	var mid := (a.position + b.position) * 0.5 + Vector3(0, 10, 0)
	var pos: Vector3
	var aim: Vector3
	var fov := 50.0
	match s.mode:
		"wide":
			pos = Vector3(0, 45, 90)
			aim = mid
			fov = 55
		"dolly":
			var f: Node3D = actors[s.focus]
			pos = f.position + Vector3(0, 6, 24)
			aim = f.position + Vector3(0, 12, 0)
			fov = 45
		"two_shot":
			var zside := 1.0 if s.focus == "A" else -1.0
			pos = mid + Vector3(0, 6, 34 * zside)
			aim = mid
			fov = 48
		"over_shoulder":
			var os_shooter: Node3D = actors[s.focus]
			var os_victim: Node3D = actors[_other(str(s.focus))]
			var os_dir := (os_victim.position - os_shooter.position).normalized()
			pos = os_shooter.position - os_dir * 12.0 + os_dir.cross(Vector3.UP) * 5.0 + Vector3(0, 13, 0)
			aim = os_victim.position + Vector3(0, 11, 0)
			fov = 42
		"punch_in":
			var f: Node3D = actors[s.focus]
			pos = f.position + Vector3(0, 13, 16 * (1.0 if f.position.x < 0 else -1.0))
			aim = f.position + Vector3(0, 13, 0)
			fov = 32
		"killcam":
			var shooter: Node3D = actors[s.focus]
			var victim: Node3D = actors[_other(str(s.focus))]
			var dir := (victim.position - shooter.position).normalized()
			var perp := dir.cross(Vector3.UP)
			pos = shooter.position - dir * 10.0 + perp * 7.0 + Vector3(0, 15, 0)
			aim = victim.position + Vector3(0, 10, 0)
			fov = 38
		"orbit":
			var wreck: Node3D = actors["B"] if actors["B"].dead else actors["A"]
			var ang := (t - float(s.t0)) * 0.35
			pos = wreck.position + Vector3(cos(ang) * 32.0, 16, sin(ang) * 32.0)
			aim = wreck.position + Vector3(0, 6, 0)
			fov = 45
	var k := 1.0 - exp(-5.0 * delta / maxf(Engine.time_scale, 0.05))
	camera.position = camera.position.lerp(pos, k)
	camera.fov = lerpf(camera.fov, fov, k)
	if shake_strength > 0.001:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_strength * 0.7
	if not camera.position.is_equal_approx(aim):
		camera.look_at(aim, Vector3.UP)
```

- [ ] **Step 2: Wire director in main.gd**

In `_ready()` (after the mechs are added), replace the static camera framing with director-driven playback:

```gdscript
const Director := preload("res://scripts/director.gd")
const FightLog := preload("res://scripts/fight_log.gd")

var director: Node3D
```

```gdscript
	var events := FightLog.load_events("res://data/fight_log.json")
	var dur := FightLog.duration_sec(events)
	var shots := Director.build_shot_list(events, dur)
	director = Director.new()
	add_child(director)
	director.start(events, shots, camera, {"A": mech_a, "B": mech_b}, dur)
	director.fight_over.connect(func():
		await get_tree().create_timer(1.0).timeout
		get_tree().quit())
```

Keep the `--still` block; it is unaffected (the still captures the opening wide).

- [ ] **Step 3: Playthrough checkpoint**

Run: `godot --path godot_director_spike`
Expected: ~30s runtime, then auto-quit. Watch it whole: opening wide holds 3s → camera follows A's advance low → cuts between sides on exchanges (mechs recoil/flinch) → quick punch-in when B's beam is blocked (A raises arm) → slow-motion killcam over A's final shot → B's parts scatter and blacken → slow orbit of the wreck → quit. No errors in console.

- [ ] **Step 4: Regression + commit**

Run: `godot --headless --path godot_director_spike --script res://tests/director_check.gd`
Expected: `ALL PASS` (builder unchanged; runtime additions don't affect statics).

```bash
git add godot_director_spike/scripts
git commit -m "feat(spike): director runtime playback, event dispatch, camera grammar"
```

---

### Task 7: Garnish layer — beams, tracers, ricochets, explosion, hitstop

Cosmetic only: every visual outcome (hit/miss/block/kill) is read from the event payload, never computed.

**Files:**
- Create: `godot_director_spike/scripts/garnish.gd`
- Modify: `godot_director_spike/scripts/main.gd`

- [ ] **Step 1: Write the garnish layer**

`godot_director_spike/scripts/garnish.gd`:

```gdscript
extends Node3D
## VFX garnish. Reads outcomes from event payloads; never decides anything.

var actors: Dictionary = {}
var director: Node3D
var rng := RandomNumberGenerator.new()

func setup(p_actors: Dictionary, p_director: Node3D) -> void:
	actors = p_actors
	director = p_director
	rng.seed = 7
	director.fight_event.connect(_on_event)

func _on_event(e: Dictionary) -> void:
	var shooter: Node3D = actors[e.actor]
	var target: Node3D = actors[_other(str(e.actor))]
	match e.kind:
		"fire_beam":
			_beam(shooter, target, e.payload)
		"fire_burst":
			_burst(shooter, target, e.payload)
		"destroyed":
			_explosion(target.position + Vector3(0, 9, 0))

func _other(a: String) -> String:
	return "B" if a == "A" else "A"

func _beam(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var from: Vector3 = shooter.muzzle_pos()
	var to: Vector3 = target.position + Vector3(0, 11, 0)
	if payload.get("blocked", false):
		to = target.position + Vector3(0, 11, 0) - (target.position - shooter.position).normalized() * 4.0
	elif not payload.get("hit", false):
		to = to + Vector3(0, 6, 14) + (to - from).normalized() * 30.0  # overshoot into a building
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, from.distance_to(to))
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 1.0) if shooter.actor_id == "A" else Color(1.0, 0.4, 0.2)
	mat.emission_energy_multiplier = 14.0
	mat.albedo_color = Color(1, 1, 1)
	mesh.material = mat
	beam.mesh = mesh
	add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)
	var light := OmniLight3D.new()
	light.light_color = mat.emission
	light.light_energy = 18.0
	light.omni_range = 35.0
	add_child(light)
	light.global_position = (from + to) * 0.5
	_impact_flash(to, mat.emission)
	if payload.get("hit", false) and float(payload.get("damage", 0)) > 25.0:
		_hitstop()
	director.shake_strength = maxf(director.shake_strength, 0.8 if payload.get("hit", false) else 0.3)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.35)
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.chain().tween_callback(func():
		beam.queue_free()
		light.queue_free())

func _burst(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var rounds := int(payload.rounds)
	var hits := int(payload.hits)
	for i in rounds:
		var is_hit := i < hits
		_tracer(shooter.muzzle_pos(), target, is_hit, float(i) * 0.09)

func _tracer(from: Vector3, target: Node3D, is_hit: bool, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var to: Vector3 = target.position + Vector3(0, rng.randf_range(6, 13), rng.randf_range(-2, 2))
	if not is_hit:
		to += Vector3(rng.randf_range(-4, 4), rng.randf_range(2, 8), rng.randf_range(10, 20))
		to += (to - from).normalized() * rng.randf_range(15.0, 35.0)  # sail past, hit cityscape
	var b := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.18
	mesh.height = 2.6
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.4)
	mat.emission_energy_multiplier = 8.0
	mesh.material = mat
	b.mesh = mesh
	add_child(b)
	b.global_position = from
	b.look_at(to, Vector3.UP)
	b.rotate_object_local(Vector3.RIGHT, PI / 2)
	var tw := create_tween()
	tw.tween_property(b, "global_position", to, from.distance_to(to) / 220.0)
	tw.tween_callback(func():
		_impact_flash(to, Color(1.0, 0.7, 0.3), 0.5 if is_hit else 0.9)
		b.queue_free())

func _impact_flash(pos: Vector3, color: Color, scale := 1.0) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.4
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 6.0 * scale
	pm.initial_velocity_max = 16.0 * scale
	pm.gravity = Vector3(0, -20, 0)
	pm.scale_min = 0.1
	pm.scale_max = 0.35 * scale
	pm.color = color
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.3
	dm.height = 0.6
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 6.0
	dm.material = mat
	p.draw_pass_1 = dm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func(): p.queue_free())

func _explosion(pos: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.35)
	flash.light_energy = 60.0
	flash.omni_range = 90.0
	add_child(flash)
	flash.global_position = pos
	create_tween().tween_property(flash, "light_energy", 0.0, 1.4)
	_fireball(pos)
	_smoke(pos)
	_ring(pos)
	_hitstop(0.12)
	director.shake_strength = 2.0
	get_tree().create_timer(3.0).timeout.connect(func(): flash.queue_free())

func _fireball(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 80
	p.lifetime = 1.1
	var pm := ParticleProcessMaterial.new()
	pm.spread = 180.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, 6, 0)
	pm.scale_min = 1.2
	pm.scale_max = 3.5
	pm.color = Color(1.0, 0.55, 0.15)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 1.0
	dm.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 5.0
	dm.material = mat
	p.draw_pass_1 = dm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(func(): p.queue_free())

func _smoke(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 40
	p.lifetime = 4.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, 2, 0)
	pm.scale_min = 2.0
	pm.scale_max = 6.0
	pm.color = Color(0.12, 0.11, 0.1, 0.7)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 1.0
	dm.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.14, 0.13, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = mat
	p.draw_pass_1 = dm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(6.0).timeout.connect(func(): p.queue_free())

func _ring(pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.5)
	mat.emission_energy_multiplier = 8.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.8)
	mesh.material = mat
	ring.mesh = mesh
	add_child(ring)
	ring.global_position = pos
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(40, 4, 40), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tw.chain().tween_callback(func(): ring.queue_free())

func _hitstop(dur := 0.07) -> void:
	var prev := Engine.time_scale
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = prev
```

- [ ] **Step 2: Wire into main.gd**

```gdscript
const Garnish := preload("res://scripts/garnish.gd")
```

In `_ready()`, after `director.start(...)`:

```gdscript
	var garnish := Garnish.new()
	add_child(garnish)
	garnish.setup({"A": mech_a, "B": mech_b}, director)
```

**Note on hitstop vs killcam:** `_hitstop()` restores `Engine.time_scale` to the value it captured, and the director re-asserts the active shot's time_scale on every shot *change* only. The lethal beam's hitstop fires while the killcam (0.25) is active and restores 0.25 — correct. If during the playthrough the slow-mo visibly "pops" after the lethal hitstop, change `_hitstop` to restore via the director: `Engine.time_scale = float(director.shots[director._shot_idx].time_scale)`.

- [ ] **Step 3: Playthrough checkpoint**

Run: `godot --path godot_director_spike`
Expected additions over Task 6: tracer streams with most rounds sailing past and sparking off buildings, beams as fat glowing lines lighting the fog with impact bursts, A's beam at ~4.5s visibly missing into the cityscape, the blocked beam sparking off A's raised arm, a big hitstop on the 30-damage beam, and the kill: slow-mo beam → flash → fireball → shockwave ring → smoke column → parts scattering → orbit through drifting smoke. No errors in console.

- [ ] **Step 4: Regression + commit**

Run: `godot --headless --path godot_director_spike --script res://tests/director_check.gd`
Expected: `ALL PASS`.

```bash
git add godot_director_spike/scripts
git commit -m "feat(spike): VFX garnish layer (beams, tracers, ricochets, explosion, hitstop)"
```

---

### Task 8: Synthesized audio

Intensity without sound is untestable. Four sounds synthesized in code (no files, no import pipeline): beam crack, ballistic burst thud, explosion boom, end sting.

**Files:**
- Create: `godot_director_spike/scripts/spike_audio.gd`
- Modify: `godot_director_spike/scripts/main.gd`

- [ ] **Step 1: Write the synth**

`godot_director_spike/scripts/spike_audio.gd`:

```gdscript
extends Node
## Synthesizes placeholder SFX as 16-bit PCM at runtime. Deterministic.

const RATE := 44100
var streams: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 4242
	streams["beam"] = _make(0.45, func(i: int, n: int) -> float:
		var t := float(i) / RATE
		var f := 1400.0 - 1100.0 * (float(i) / n)
		return (sin(TAU * f * t) * 0.6 + rng.randf_range(-0.4, 0.4)) * (1.0 - float(i) / n))
	streams["thud"] = _make(0.12, func(i: int, n: int) -> float:
		var t := float(i) / RATE
		return (sin(TAU * 90.0 * t) + rng.randf_range(-0.5, 0.5)) * pow(1.0 - float(i) / n, 2.0))
	streams["boom"] = _make(2.2, func(i: int, n: int) -> float:
		var t := float(i) / RATE
		var env := pow(1.0 - float(i) / n, 1.6)
		return (sin(TAU * 45.0 * t) * 0.7 + rng.randf_range(-1, 1) * 0.5 * env) * env)
	streams["sting"] = _make(2.5, func(i: int, n: int) -> float:
		var t := float(i) / RATE
		var env := minf(t * 8.0, 1.0) * (1.0 - float(i) / n)
		var v := 0.0
		for f in [220.0, 261.6, 329.6]:
			v += sin(TAU * f * t) / 3.0
		return v * env)

func _make(dur: float, gen: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := clampf(gen.call(i, n), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = bytes
	return s

func play(key: String, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = streams[key]
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func wire(director: Node3D) -> void:
	director.fight_event.connect(func(e: Dictionary):
		match e.kind:
			"fire_beam":
				play("beam", -4.0)
			"fire_burst":
				for i in int(e.payload.rounds):
					get_tree().create_timer(float(i) * 0.09).timeout.connect(
						func(): play("thud", -10.0))
			"destroyed":
				play("boom", 2.0)
				get_tree().create_timer(2.5).timeout.connect(func(): play("sting", -6.0)))
```

- [ ] **Step 2: Wire into main.gd**

```gdscript
const SpikeAudio := preload("res://scripts/spike_audio.gd")
```

In `_ready()`, after the garnish wiring:

```gdscript
	var audio := SpikeAudio.new()
	add_child(audio)
	audio.wire(director)
```

- [ ] **Step 3: Playthrough checkpoint**

Run: `godot --path godot_director_spike`
Expected: beam crack on every beam, thud chains under tracer bursts, a long boom on the kill, the minor-chord sting as the orbit settles. Sound makes the fight read meaner — if it doesn't, tune `volume_db` values, not the synths.

- [ ] **Step 4: Commit**

```bash
git add godot_director_spike/scripts
git commit -m "feat(spike): synthesized placeholder SFX wired to fight events"
```

---

### Task 9: Judging instrumentation + deliverables

FPS evidence for pass-criterion 4, end fade, the movie capture, the event-contract write-up, and the verdict-note template.

**Files:**
- Modify: `godot_director_spike/scripts/main.gd`
- Create: `godot_director_spike/data/event-contract.md`
- Create: `godot_director_spike/VERDICT.md`

- [ ] **Step 1: FPS tracking + end fade in main.gd**

Add fields and `_process` to `main.gd`:

```gdscript
var _fps_samples: Array[float] = []
var _fade: ColorRect

func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		_fps_samples.append(Performance.get_monitor(Performance.TIME_FPS))
```

In `_ready()`, build the fade overlay (before the director wiring):

```gdscript
	var layer := CanvasLayer.new()
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
```

Replace the existing `fight_over` connection with:

```gdscript
	director.fight_over.connect(func():
		create_tween().tween_property(_fade, "color:a", 1.0, 2.0)
		await get_tree().create_timer(2.2).timeout
		_fps_samples.sort()
		if _fps_samples.size() > 2:
			print("FPS min=%d  p5=%d  avg=%d" % [int(_fps_samples[0]),
				int(_fps_samples[_fps_samples.size() / 20]),
				int(_fps_samples.reduce(func(a, b): return a + b) / _fps_samples.size())])
		get_tree().quit())
```

- [ ] **Step 2: Verify FPS print**

Run: `godot --path godot_director_spike`
Expected: full playthrough ends with a 2s fade to black, console prints `FPS min=… p5=… avg=…`, then quits. Record the numbers — criterion 4 wants stable 60 on a mid PC (this dev machine's numbers are the first data point, not the verdict).

- [ ] **Step 3: Capture the movie deliverable**

Run: `godot --path godot_director_spike --write-movie tmp/money-shot.avi`
Expected: renders offline at a fixed 60fps (slower than realtime is fine), writes `godot_director_spike/tmp/money-shot.avi`. Play the file — this is the artifact judges watch. Note: `tmp/` is gitignored; copy the final cut somewhere shareable when distributing to judges.

- [ ] **Step 4: Write the event contract doc**

`godot_director_spike/data/event-contract.md`:

```markdown
# Assumed sim event contract (km-director-spike-fight-log-v1)

What the director spike assumes a future deterministic spatial sim will emit.
A design input for the spatial-sim slice, extracted per the 2026-06-12 design spec.

## Envelope

Ordered array of `{tick, actor, kind, payload}`. Ticks are integers at a declared
`tick_seconds` (0.1 here). Multiple events may share a tick; array order breaks ties.
`actor` is the acting side. The log is complete before playback begins — the
presentation layer may read ahead (the director's whole premise).

## Kinds

| kind | payload | notes |
|---|---|---|
| `spawn` | `x`, `hp` | stage is 1-D for the spike; a real sim emits 2-D coarse positions |
| `advance` | `to_x`, `end_tick` | movement as start/end so playback can interpolate; sim owns the path |
| `fire_beam` | `hit`, `damage`, `hp_after`, opt `blocked`, `lethal`, `overkill` | `hp_after` is the TARGET's hp; miss ⇒ `hit:false, damage:0` |
| `fire_burst` | `rounds`, `hits`, `damage`, `hp_after` | per-round hit distribution is presentation's choice; totals are sim truth |
| `destroyed` | — | terminal for that actor |

## Invariants the spike relied on

- Outcomes are entirely in the log; the renderer never rolls dice that matter.
- Coarse positions are enough: garnish (tracer paths, ricochet points) may embellish
  freely as long as hit/miss/damage/death match the log.
- Exactly one terminal event; everything after it is epilogue staging.
- Tick→seconds scaling is presentation-owned (the director may dilate time).
```

- [ ] **Step 5: Write the verdict template**

`godot_director_spike/VERDICT.md`:

```markdown
# KM-DIRECTOR-SPIKE verdict — engine exit-test

Judged per the pass criteria in
`Research/Research Documents/design-spec-2026-06-12-cinematic-3d-combat-direction-and-director-spike.md`.
Grade the shot AS-IS. No "imagine it with better assets."

Judges: owner ☐  art team ☐  cold viewer ☐
Artifact judged: `tmp/money-shot.avi` @ commit `____`

| # | Criterion | Verdict | Evidence/notes |
|---|---|---|---|
| 1 | Mechs read as giant against the city | ☐ pass ☐ fail | |
| 2 | Beam exchange got an involuntary reaction from a non-builder | ☐ pass ☐ fail | who/what reaction: |
| 3 | The kill moment lands with the camera treatment | ☐ pass ☐ fail | |
| 4 | Stable 60 fps on a mid PC | ☐ pass ☐ fail | FPS min/p5/avg: |
| 5 | Graded as-is | ☐ confirmed | |

**Outcome:** ☐ Godot confirmed (stack ADR closes its confirmation condition)
☐ Fail → Unreal re-opens, Niagara tech-artist seat costed in

**Director-pattern observations** (what the shot-list grammar got right/wrong — feeds the real director design):
```

- [ ] **Step 6: Final full run + commit**

Run: `godot --headless --path godot_director_spike --script res://tests/director_check.gd`
Expected: `ALL PASS`.

Run: `godot --path godot_director_spike`
Expected: clean full playthrough, fade, FPS line, quit.

```bash
git add godot_director_spike
git commit -m "feat(spike): judging instrumentation, movie capture, event contract, verdict template"
```

---

## After execution

1. Watch `tmp/money-shot.avi`; iterate on feel (camera timing constants in `director.gd`, VFX scale in `garnish.gd`) before convening judges — feel iteration is expected, criteria are not renegotiable.
2. Convene judges; fill `VERDICT.md`.
3. Route the outcome: update the stack ADR's confirmation status; reconcile/supersede `docs/slices/KM-STACK-SPIKE-godot-platform-confirmation.md`; run the canon changes (no-3D rule, mobile target) through `vouse-routing-changes` as flagged in the design spec.
