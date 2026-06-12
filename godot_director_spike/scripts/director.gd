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
			var clipped: Dictionary = s.duplicate()
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
