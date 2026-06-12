extends "res://scripts/director.gd"
## Variant 2 — Combat Broadcast: televised multi-camera coverage of the duel.
## Long-lens telephoto down the street corridor, motorized drone arcs, hard
## snap cut-ins on every beam exchange, a bullet-time sweep around the kill,
## and a rising aerial pullback over the wreck.
##
## Every camera pose is computed parametrically from shot-local time and set
## directly — no easing across shot boundaries, so every cut SNAPS like a
## broadcast vision mixer. Within a shot, motion is smooth by construction
## (parametric drift/orbit), never handheld.

const CUT_PRE := 0.6
const CUT_POST := 1.0
const BT_PRE := 0.4
const BT_POST := 0.7
const BT_SCALE := 0.07

var _cam_shot := -1
var _wall := 0.0   # shot-local wall-clock seconds (immune to time_scale)

static func build_shot_list(events: Array, dur: float) -> Array:
	var fixed: Array = []
	var bt_end := dur
	for e in events:
		if e.kind != "fire_beam":
			continue
		var t := float(e.tick) * TICK
		if e.payload.get("lethal", false):
			fixed.append({"t0": t - BT_PRE, "t1": t + BT_POST, "mode": "bullet_time",
				"focus": str(e.actor), "time_scale": BT_SCALE})
			bt_end = t + BT_POST
		else:
			# Cut in on the shooter; on a block, on the blocker holding the beam.
			var focus := _other(str(e.actor)) if e.payload.get("blocked", false) else str(e.actor)
			fixed.append({"t0": t - CUT_PRE, "t1": t + CUT_POST, "mode": "cut_in",
				"focus": focus, "time_scale": 1.0})
	fixed.append({"t0": bt_end, "t1": dur, "mode": "aerial_pullback", "focus": "", "time_scale": 1.0})
	fixed.sort_custom(func(a, b): return float(a.t0) < float(b.t0))

	# Fill gaps with alternating coverage cameras: telephoto, then drone.
	var shots: Array = []
	var cursor := 0.0
	var coverage := "long_lens"
	for s in fixed:
		var t0 := maxf(float(s.t0), cursor)
		if t0 - cursor > 0.001:
			var focus := _advance_active_at(events, cursor) if coverage == "long_lens" else ""
			shots.append({"t0": cursor, "t1": t0, "mode": coverage, "focus": focus, "time_scale": 1.0})
			coverage = "drone_orbit" if coverage == "long_lens" else "long_lens"
			cursor = t0
		if float(s.t1) > cursor:
			var clipped: Dictionary = s.duplicate()
			clipped.t0 = cursor
			shots.append(clipped)
			cursor = float(s.t1)
	return shots

func _update_camera(delta: float) -> void:
	if _shot_idx < 0:
		return
	if _shot_idx != _cam_shot:
		_cam_shot = _shot_idx
		_wall = 0.0
	_wall += delta / maxf(Engine.time_scale, 0.01)
	var s: Dictionary = shots[_shot_idx]
	var a: Node3D = actors["A"]
	var b: Node3D = actors["B"]
	var mid := (a.position + b.position) * 0.5
	var pos: Vector3
	var aim: Vector3
	var fov := 40.0
	match s.mode:
		"long_lens":
			# Telephoto tower far down the street corridor (west end), slow truck in z.
			var target: Vector3 = mid if s.focus == "" else (actors[s.focus] as Node3D).position
			pos = Vector3(target.x - 115.0, 20, -6.0 + _wall * 1.2)
			aim = target + Vector3(0, 10, 0)
			fov = 16
		"drone_orbit":
			# Street-hugging elliptical arc: wide in x, shallow in z to stay out of buildings.
			var ang := float(s.t0) * 0.7 + _wall * 0.45
			pos = mid + Vector3(cos(ang) * 50.0, 30.0 + sin(ang) * 6.0, sin(ang) * 16.0)
			aim = mid + Vector3(0, 9, 0)
			fov = 40
		"cut_in":
			# Hard cut to a tight 3/4 on the focused actor, slow push-in.
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var toward := signf(o.position.x - f.position.x)
			var zside := 1.0 if s.focus == "A" else -1.0
			pos = f.position + Vector3(toward * 7.0, 13.5, zside * (15.0 - _wall * 1.0))
			aim = f.position + Vector3(0, 12, 0)
			fov = 32
		"bullet_time":
			# Frozen-moment sweep: 270-degree street-hugging ellipse around the
			# kill tableau, progressed on wall-clock so it arcs through the slow-mo.
			var shooter: Node3D = actors[s.focus]
			var victim: Node3D = actors[_other(str(s.focus))]
			var center := shooter.position.lerp(victim.position, 0.55) + Vector3(0, 11, 0)
			var wall_len := (float(s.t1) - float(s.t0)) / BT_SCALE
			var p := clampf(_wall / wall_len, 0.0, 1.0)
			var ang := PI + p * TAU * 0.75
			pos = center + Vector3(cos(ang) * 24.0, 7.0 + p * 9.0, sin(ang) * 15.0)
			aim = center
			fov = 42
		"aerial_pullback":
			# Rising crane: straight up over the wreck, city revealed below.
			var wreck: Node3D = actors["B"] if actors["B"].dead else actors["A"]
			var p := clampf(_wall / (float(s.t1) - float(s.t0)), 0.0, 1.0)
			pos = wreck.position + Vector3(-12.0 - p * 30.0, 12.0 + p * 75.0, 6.0 + p * 10.0)
			aim = wreck.position + Vector3(0, 4, 0)
			fov = 42
	if shake_strength > 0.001:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_strength * 0.4
	camera.position = pos
	camera.fov = fov
	if not camera.position.is_equal_approx(aim):
		camera.look_at(aim, Vector3.UP)
