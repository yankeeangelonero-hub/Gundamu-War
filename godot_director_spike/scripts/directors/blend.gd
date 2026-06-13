extends "res://scripts/director.gd"
## Variant 4 — Blend: Pacific Rim / Hathaway coverage. The backbone is the
## pedestrian on the ground — low-angle human-height shots reacting to giants —
## cut against mid/long drone plates, brief cockpit inserts, the cinematic
## over-shoulder on the first exchange, the broadcast bullet-time kill, and a
## top-down drone establishing shot hovering over the street (perspective, not
## true iso — the standalone `iso` director keeps the orthographic view).

const VOCAB := ["drone_top", "over_shoulder", "ground_react", "cockpit",
	"drone_mid", "drone_long", "bullet_time", "ground_aftermath"]

const ISO_END := 3.0
const REACT_PRE := 0.5
const REACT_POST := 1.4
const BT_PRE := 0.4
const BT_POST := 0.7
const BT_SCALE := 0.07

static func build_shot_list(events: Array, dur: float) -> Array:
	var fixed: Array = []
	var bt_end := dur
	var first_beam_done := false
	for e in events:
		if e.kind != "fire_beam":
			continue
		var t := float(e.tick) * TICK
		if e.payload.get("lethal", false):
			fixed.append({"t0": t - BT_PRE, "t1": t + BT_POST, "mode": "bullet_time",
				"focus": str(e.actor), "time_scale": BT_SCALE})
			bt_end = t + BT_POST
		elif not first_beam_done:
			first_beam_done = true
			fixed.append({"t0": t - 0.3, "t1": t + 1.5, "mode": "over_shoulder",
				"focus": str(e.actor), "time_scale": 1.0})
		else:
			# Pedestrian reaction: low angle beside the mech under fire.
			fixed.append({"t0": t - REACT_PRE, "t1": t + REACT_POST, "mode": "ground_react",
				"focus": _other(str(e.actor)), "time_scale": 1.0})
	fixed.append({"t0": bt_end, "t1": dur, "mode": "ground_aftermath", "focus": "", "time_scale": 1.0})
	fixed.sort_custom(func(a, b): return float(a.t0) < float(b.t0))

	# Open on the overhead drone read, then fill gaps cycling drone/cockpit coverage.
	var iso_end := minf(ISO_END, maxf(float(fixed[0].t0), 0.5))
	var shots: Array = [{"t0": 0.0, "t1": iso_end, "mode": "drone_top", "focus": "", "time_scale": 1.0}]
	var cursor := iso_end
	var fill := ["drone_long", "cockpit", "drone_mid"]
	var fi := 0
	for s in fixed:
		var t0 := maxf(float(s.t0), cursor)
		if t0 - cursor > 0.001:
			var mode: String = fill[fi % fill.size()]
			var adv := _advance_active_at(events, cursor)
			var focus := ""
			if mode == "cockpit":
				focus = adv if adv != "" else "A"
			shots.append({"t0": cursor, "t1": t0, "mode": mode, "focus": focus, "time_scale": 1.0})
			fi += 1
			cursor = t0
		if float(s.t1) > cursor:
			var clipped: Dictionary = s.duplicate()
			clipped.t0 = cursor
			shots.append(clipped)
			cursor = float(s.t1)
	return shots

# ---- runtime camera: full override ----

var _cam_shot := -1
var _wall := 0.0          # shot-local wall-clock seconds
var _wt := 0.0            # handheld sway clock
var _anchor := Vector3.ZERO
var _push_to := Vector3.ZERO

func _update_camera(delta: float) -> void:
	if _shot_idx < 0:
		return
	_wt += delta
	if _shot_idx != _cam_shot:
		_cam_shot = _shot_idx
		_wall = 0.0
		_aim_init = false
		_take_position(shots[_shot_idx])
	_wall += delta / maxf(Engine.time_scale, 0.01)
	var s: Dictionary = shots[_shot_idx]
	var a: Node3D = actors["A"]
	var b: Node3D = actors["B"]
	var mid := (a.position + b.position) * 0.5
	var pos := _anchor
	var aim: Vector3
	var fov := 50.0
	var ground := false
	var dof := false
	_roll = 0.0
	match s.mode:
		"drone_top":
			# Descending hero crane: starts high/wide, sinks toward the near
			# giant so it looms into frame as the fight opens.
			var near: Node3D = actors["A"]
			var p0 := clampf(_wall / 3.0, 0.0, 1.0)
			pos = near.position + Vector3(-26.0 + _wall * 3.0, lerpf(34.0, 18.0, p0), 26.0)
			aim = near.position.lerp(mid, 0.35) + Vector3(0, lerpf(10.0, 13.0, p0), 0)
			fov = 40
		"over_shoulder":
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var d := (o.position - f.position).normalized()
			pos = f.position - d * 12.0 + d.cross(Vector3.UP) * 5.0 + Vector3(0, 13, 0)
			aim = o.position + Vector3(0, 11, 0)
			fov = 42
			dof = true
		"cockpit":
			# Head-cam pushed forward clear of the mech's own body, walking bob.
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var fwd := (o.position - f.position).normalized()
			pos = f.position + fwd * 5.0 + Vector3(0, 17.0 + sin(_wt * 7.0) * 0.12, 0)
			aim = o.position + Vector3(0, 11, 0)
			fov = 58
			_roll = sin(_wt * 3.5) * 0.012
		"drone_mid":
			var ang := float(s.t0) * 0.7 + _wall * 0.4
			pos = _keep_lateral(mid + Vector3(cos(ang) * 38.0, 24.0 + sin(ang) * 5.0, sin(ang) * 10.0), mid, 26.0)
			aim = mid + Vector3(0, 9, 0)
			fov = 38
		"drone_long":
			# Slow long-lens helicopter plate: compressed, weighty, Pacific Rim.
			var ang2 := float(s.t0) * 0.7 + _wall * 0.22
			pos = _keep_lateral(mid + Vector3(cos(ang2) * 62.0, 38.0 + sin(ang2) * 5.0, sin(ang2) * 10.0), mid, 30.0)
			aim = mid + Vector3(0, 9, 0)
			fov = 26
		"ground_react":
			# The pedestrian: planted at human height, staring up at the giant.
			ground = true
			dof = true
			var f: Node3D = actors[s.focus]
			aim = f.position + Vector3(0, 12, 0)
			fov = 64
			_roll = _sway(7.7) * 0.02 + shake_strength * 0.025
		"bullet_time":
			# Arc anchored on the victim so the frame holds the mech taking the
			# hit (beam + shooter enter frame edge), pulled back to fill it.
			var shooter: Node3D = actors[s.focus]
			var victim: Node3D = actors[_other(str(s.focus))]
			var center := victim.position.lerp(shooter.position, 0.2) + Vector3(0, 10, 0)
			var wall_len := (float(s.t1) - float(s.t0)) / BT_SCALE
			var p := clampf(_wall / wall_len, 0.0, 1.0)
			var ang3 := PI + p * TAU * 0.75
			pos = center + Vector3(cos(ang3) * 32.0, 8.0 + p * 9.0, sin(ang3) * 14.0)
			aim = center
			fov = 48
			dof = true
			_roll = lerpf(-0.05, 0.03, p)   # slow roll across the frozen moment
		"ground_aftermath":
			ground = true
			dof = true
			var wreck: Node3D = actors["B"] if actors["B"].dead else actors["A"]
			var p2 := clampf((t - float(s.t0)) / (float(s.t1) - float(s.t0)), 0.0, 1.0)
			pos = _anchor.lerp(_push_to, p2)
			aim = wreck.position + Vector3(0, lerpf(8.0, 14.0, p2), 0)
	camera.fov = fov
	pos = _resolve_occlusion(pos, aim)
	_set_focus(pos.distance_to(aim) if dof else -1.0, 0.07)
	if ground:
		var amp := 0.05 + shake_strength * 0.4
		pos += Vector3(_sway(0.0), _sway(1.3), _sway(2.7)) * amp * 0.4
		aim += Vector3(_sway(4.1), _sway(5.6), 0.0) * amp * 0.8
	camera.position = pos
	_apply_aim(aim, delta, 7.0)

func _take_position(s: Dictionary) -> void:
	match s.mode:
		"ground_react":
			# Plant the pedestrian between the mech and the open intersection
			# so the sightline never needs an occlusion rescue (which would
			# drag the camera up to torso height and kill the low angle).
			var f: Node3D = actors[s.focus]
			var toward_open := Vector3.ZERO - f.position
			toward_open.y = 0.0
			toward_open = toward_open.normalized() if toward_open.length() > 1.0 else Vector3(-1, 0, 0)
			var side := 1.0 if _cam_shot % 2 == 0 else -1.0
			_anchor = f.position + toward_open * 13.0 + toward_open.cross(Vector3.UP) * side * 5.0
			_anchor.y = 1.7
		"ground_aftermath":
			var wreck: Node3D = actors["B"] if actors["B"].dead else actors["A"]
			_anchor = Vector3(wreck.position.x - 24.0, 2.2, 10.0)
			_push_to = Vector3(wreck.position.x - 10.0, 1.8, 4.0)

## Layered incommensurate sines: smooth handheld sway, not per-frame noise.
func _sway(phase: float) -> float:
	return sin(_wt * 1.9 + phase) * 0.55 + sin(_wt * 5.1 + phase * 2.0) * 0.3 \
		+ sin(_wt * 11.7 + phase * 3.0) * 0.05
