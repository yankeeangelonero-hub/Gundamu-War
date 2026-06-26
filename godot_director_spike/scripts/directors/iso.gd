extends "res://scripts/director.gd"
## Variant 5 — Isometric: one fixed tactical 3/4 view held for the whole fight,
## for the player who just wants to read the duel like a strategy game. The
## orthographic camera tracks the midpoint; the only event treatment is a
## slow-mo zoom-in spanning the lethal beam (the contract's one dilated shot).

const VOCAB := ["iso", "iso_kill"]

const KILL_PRE := 0.5
const KILL_POST := 1.8

static func build_shot_list(events: Array, dur: float, _grammar: ShotGrammar = null, _enabled_modes: Dictionary = {}) -> Array:
	var lethal_t := dur
	for e in events:
		if e.kind == "fire_beam" and e.payload.get("lethal", false):
			lethal_t = float(e.tick) * TICK
	var k0 := maxf(lethal_t - KILL_PRE, 0.0)
	var k1 := minf(lethal_t + KILL_POST, dur)
	return [
		{"t0": 0.0, "t1": k0, "mode": "iso", "focus": "", "time_scale": 1.0},
		{"t0": k0, "t1": k1, "mode": "iso_kill", "focus": "", "time_scale": 0.25},
		{"t0": k1, "t1": dur, "mode": "iso", "focus": "", "time_scale": 1.0},
	]

const ISO_OFFSET := Vector3(-45, 90, 18)   # fixed tactical 3/4 eye direction

var _zoom := 90.0

func _update_camera(delta: float) -> void:
	if _shot_idx < 0:
		return
	var s: Dictionary = shots[_shot_idx]
	var a: Node3D = actors["A"]
	var b: Node3D = actors["B"]
	var mid := (a.position + b.position) * 0.5
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Frame-to-fit: the ortho box grows with the gap so both giants always read,
	# and punches in for the kill. Mechs roam in 2D, so the fit is live.
	var sep := a.position.distance_to(b.position)
	var want := clampf(sep * 0.7 + 30.0, 50.0, 92.0)
	if s.mode == "iso_kill":
		want = minf(want, 52.0)
	var k := 1.0 - exp(-3.0 * delta / maxf(Engine.time_scale, 0.05))
	_zoom = lerpf(_zoom, want, k)
	camera.size = _zoom
	camera.position = camera.position.lerp(mid + ISO_OFFSET, k)
	_apply_aim(mid, delta, 5.0)

