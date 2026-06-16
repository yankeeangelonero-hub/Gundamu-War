extends "res://scripts/director.gd"
## Variant 2 — Ground Witness: a documentary war correspondent embedded at street
## level. The camera is a human-scale witness inside the battle; every vantage is
## 1.7-2.5m off the ground looking up at torsos, sidewalk cover at z = +/-13..17,
## handheld sway from layered sines. One locked-off slow-mo stare for the kill,
## then a slow ground-level push toward the wreck.

const VOCAB := ["street_wide", "track", "cower", "duck", "kill_gaze", "aftermath"]

const WIDE_END := 3.5
const KILL_PRE := 0.6
const KILL_POST := 2.6
const BEAT_TAIL := 1.6     # a scramble beat runs until this long after its fire event
const BEAT_MIN_GAP := 0.8  # fire events closer than this to the cut stay in the current beat

static func build_shot_list(events: Array, dur: float, _grammar: ShotGrammar = null) -> Array:
	var lethal_t := dur
	var lethal_actor := "A"
	for e in events:
		if e.kind == "fire_beam" and e.payload.get("lethal", false):
			lethal_t = float(e.tick) * TICK
			lethal_actor = str(e.actor)
	var kill_t0 := lethal_t - KILL_PRE
	var kill_t1 := minf(lethal_t + KILL_POST, dur - 1.5)
	var shots: Array = [{"t0": 0.0, "t1": minf(WIDE_END, kill_t0), "mode": "street_wide",
		"focus": "", "time_scale": 1.0}]
	var cursor := minf(WIDE_END, kill_t0)
	# Scramble between street-level vantages on the fire beats before the kill.
	var cycle := ["track", "cower", "duck"]
	var ci := 0
	for e in events:
		if e.kind != "fire_beam" and e.kind != "fire_burst":
			continue
		var t := float(e.tick) * TICK
		if t <= cursor + BEAT_MIN_GAP or t >= kill_t0 - BEAT_TAIL:
			continue
		var mode: String = cycle[ci % cycle.size()]
		# track/duck stay with the shooter; cower presses in beside the mech under fire
		var focus := _other(str(e.actor)) if mode == "cower" else str(e.actor)
		shots.append({"t0": cursor, "t1": minf(t + BEAT_TAIL, kill_t0), "mode": mode,
			"focus": focus, "time_scale": 1.0})
		cursor = minf(t + BEAT_TAIL, kill_t0)
		ci += 1
	if kill_t0 - cursor > 0.001:
		var adv := _advance_active_at(events, cursor)
		shots.append({"t0": cursor, "t1": kill_t0, "mode": "track",
			"focus": adv if adv != "" else lethal_actor, "time_scale": 1.0})
	shots.append({"t0": kill_t0, "t1": kill_t1, "mode": "kill_gaze",
		"focus": lethal_actor, "time_scale": 0.25})
	shots.append({"t0": kill_t1, "t1": dur, "mode": "aftermath",
		"focus": _other(lethal_actor), "time_scale": 1.0})
	return shots

# ---- runtime camera: full override, base grammar is never consulted ----

var _w_idx := -1            # shot index the witness has taken position for
var _w_anchor := Vector3.ZERO
var _w_push_to := Vector3.ZERO   # aftermath dolly end point
var _w_aim_lock := Vector3.ZERO  # kill_gaze locked aim
var _wt := 0.0              # handheld sway clock

func _update_camera(_delta: float) -> void:
	if _shot_idx < 0:
		return
	_wt += _delta
	var s: Dictionary = shots[_shot_idx]
	if _shot_idx != _w_idx:
		_w_idx = _shot_idx
		_take_position(s)   # the cut: witness has scrambled to new cover between shots
	var f: Node3D = actors[s.focus] if s.focus != "" else actors["A"]
	var pos := _w_anchor
	var aim: Vector3
	match s.mode:
		"street_wide":
			aim = f.position + Vector3(6, 10.5, 0)
		"track":
			aim = f.position + Vector3(0, 11, 0)
		"cower":
			aim = f.position + Vector3(0, 12.5, 0)
		"duck":
			aim = f.position + Vector3(0, 9.5, 0)
		"kill_gaze":
			# tracking stare: the victim may be sprinting through the slow-mo
			aim = actors[_other(str(s.focus))].position + Vector3(0, 11, 0)
		"aftermath":
			var p := clampf((t - float(s.t0)) / (float(s.t1) - float(s.t0)), 0.0, 1.0)
			pos = _w_anchor.lerp(_w_push_to, p)
			aim = f.position + Vector3(0, lerpf(8.0, 14.0, p), 0)  # end tilted up
	_roll = 0.0
	if s.mode != "kill_gaze":  # the kill is a locked-off stare; everything else is handheld
		var amp := 0.06 + shake_strength * 0.5 + _fire_proximity() * 0.3
		pos += Vector3(_sway(0.0), _sway(1.3), _sway(2.7)) * amp * 0.4
		aim += Vector3(_sway(4.1), _sway(5.6), 0.0) * amp * 0.8
		_roll = _sway(7.7) * 0.018
	_set_focus(pos.distance_to(aim) if s.mode != "street_wide" else -1.0,
		0.1 if s.mode == "kill_gaze" else 0.06)
	camera.position = _resolve_occlusion(pos, aim)
	_apply_aim(aim, _delta, 6.0)

func _take_position(s: Dictionary) -> void:
	_aim_init = false
	var f: Node3D = actors[s.focus] if s.focus != "" else actors["A"]
	var side := 1.0 if _w_idx % 2 == 0 else -1.0  # alternate sidewalks between shots
	var fov := 60.0
	match s.mode:
		"street_wide":
			# planted past the near giant, looking up and down the street at it
			_w_anchor = Vector3(f.position.x - 12.0, 2.0, 12.0)
			fov = 66
		"track":
			_w_anchor = Vector3(f.position.x + 4.0, 2.2, side * 12.0)
			fov = 56
		"cower":
			_w_anchor = Vector3(f.position.x + 5.0, 1.7, side * 12.0)
			fov = 68
		"duck":
			_w_anchor = Vector3(f.position.x - 7.0, 1.7, side * 11.0)
			fov = 58
		"kill_gaze":
			var victim: Node3D = actors[_other(str(s.focus))]
			_w_anchor = Vector3(victim.position.x - 16.0, 1.9, 11.0)
			_w_aim_lock = victim.position + Vector3(0, 11, 0)
			fov = 52
		"aftermath":
			_w_anchor = Vector3(f.position.x - 26.0, 2.5, 10.0)
			_w_push_to = Vector3(f.position.x - 10.0, 2.0, 4.0)
			fov = 60
	camera.position = _w_anchor
	camera.fov = fov

## Layered incommensurate sines: smooth handheld sway, not per-frame noise.
func _sway(phase: float) -> float:
	return sin(_wt * 1.9 + phase) * 0.55 + sin(_wt * 5.1 + phase * 2.0) * 0.3 \
		+ sin(_wt * 11.7 + phase * 3.0) * 0.05

## 0..1, rising as the clock nears any fire event — the witness flinches.
func _fire_proximity() -> float:
	var prox := 0.0
	for e in events:
		if e.kind == "fire_beam" or e.kind == "fire_burst":
			var d := absf(t - float(e.tick) * TICK)
			if d < 0.6:
				prox = maxf(prox, (0.6 - d) / 0.6)
	return prox
