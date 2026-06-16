extends "res://scripts/director.gd"
## Variant 6 — Iso Hybrid: the production direction. An isometric tactical view
## over a destructible city is the BASE the eye lives in (legible, strategy-game
## readable), and the camera CUTS to cinematic perspective shots on the big
## beats — the opening exchange, a mid-fight building-wrecking beam, and the
## kill — then cuts back to iso. Orthographic backbone, perspective punctuation.

const VOCAB := ["iso", "iso_aftermath", "hero_os", "hero_cut", "melee_cut", "bullet_time"]


static func build_shot_list(events: Array, dur: float, grammar: ShotGrammar = null) -> Array:
	if grammar == null:
		grammar = ShotGrammar.default()
	var first_t := -1.0
	var first_actor := "A"
	var lethal_t := dur
	var lethal_actor := "A"
	var mids: Array = []      # non-first, non-lethal beams: candidates to intercut
	# The kill can be any event kind (beam OR melee cleave) — find it generically.
	for e in events:
		if e.payload.get("lethal", false):
			lethal_t = float(e.tick) * TICK
			lethal_actor = str(e.actor)
	for e in events:
		if e.kind != "fire_beam" or e.payload.get("lethal", false):
			continue
		var t := float(e.tick) * TICK
		if first_t < 0.0:
			first_t = t
			first_actor = str(e.actor)
		else:
			mids.append({"t": t, "actor": str(e.actor)})
	# Intercut the beam nearest mid-fight (most likely diagonal across a tower).
	var target := (first_t + lethal_t) * 0.5
	var mid: Dictionary = {}
	for m in mids:
		if mid.is_empty() or absf(float(m.t) - target) < absf(float(mid.t) - target):
			mid = m

	var fixed: Array = [{"t0": first_t - 0.3, "t1": first_t + grammar.os_len, "mode": "hero_os",
		"focus": first_actor, "time_scale": 1.0}]
	if not mid.is_empty() and float(mid.t) - 0.3 > first_t + grammar.os_len:
		fixed.append({"t0": float(mid.t) - 0.3, "t1": float(mid.t) + grammar.cut_len, "mode": "hero_cut",
			"focus": str(mid.actor), "time_scale": 1.0})
	# Every non-lethal melee clash gets a tight close-up so the blade reads.
	for e in events:
		if e.kind == "melee" and not e.payload.get("lethal", false):
			var mt := float(e.tick) * TICK
			fixed.append({"t0": mt - 0.5, "t1": mt + 1.7, "mode": "melee_cut",
				"focus": str(e.actor), "time_scale": 0.5})
	fixed.append({"t0": lethal_t - grammar.bt_pre, "t1": lethal_t + grammar.bt_post, "mode": "bullet_time",
		"focus": lethal_actor, "time_scale": grammar.bt_scale})
	fixed.sort_custom(func(x, y): return float(x.t0) < float(y.t0))

	# Iso fills every gap; the tail after the kill is the iso aftermath read.
	var shots: Array = []
	var cursor := 0.0
	for f in fixed:
		var t0 := maxf(float(f.t0), cursor)
		if t0 - cursor > 0.001:
			shots.append({"t0": cursor, "t1": t0, "mode": "iso", "focus": "", "time_scale": 1.0})
		shots.append({"t0": t0, "t1": float(f.t1), "mode": f.mode, "focus": f.focus, "time_scale": f.time_scale})
		cursor = float(f.t1)
	if dur - cursor > 0.001:
		shots.append({"t0": cursor, "t1": dur, "mode": "iso_aftermath", "focus": "", "time_scale": 1.0})
	return shots

# ---- runtime camera ----

var _zoom := 90.0
var _cam_shot := -1
var _wall := 0.0
# Runtime framing/timing source. At defaults this matches the grammar build_shot_list()
# self-defaults to, so the two paths agree. When custom-grammar wiring lands (Phase 3),
# keep this in sync with the grammar passed to build_shot_list() — give the director one source.
var _grammar: ShotGrammar = ShotGrammar.default()

func _update_camera(delta: float) -> void:
	if _shot_idx < 0:
		return
	if _shot_idx != _cam_shot:
		_cam_shot = _shot_idx
		_wall = 0.0
		_aim_init = false
	_wall += delta / maxf(Engine.time_scale, 0.01)
	var s: Dictionary = shots[_shot_idx]
	var a: Node3D = actors["A"]
	var b: Node3D = actors["B"]
	var mid := (a.position + b.position) * 0.5
	_roll = 0.0

	# --- isometric backbone (orthographic) ---
	if s.mode == "iso" or s.mode == "iso_aftermath":
		var focus_pt := mid
		var want := clampf(a.position.distance_to(b.position) * _grammar.iso_zoom_factor + _grammar.iso_zoom_base, _grammar.iso_zoom_min, _grammar.iso_zoom_max)
		if s.mode == "iso_aftermath":
			focus_pt = (b.position if b.dead else a.position)
			want = _grammar.aftermath_zoom
		var k := 1.0 - exp(-3.0 * delta / maxf(Engine.time_scale, 0.05))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_zoom = lerpf(_zoom, want, k)
		camera.size = _zoom
		camera.position = camera.position.lerp(focus_pt + _grammar.iso_offset, k)
		_set_focus(-1.0)
		_fade_for_iso(camera.position, a.position + Vector3(0, 10, 0), b.position + Vector3(0, 10, 0))
		_cull_near(camera.position, 0.0)   # tactical view sees the whole city
		_apply_aim(focus_pt, delta, 5.0)
		return

	# --- cinematic punctuation (perspective) ---
	var pos: Vector3
	var aim: Vector3
	var fov := 45.0
	# Framing-table guard (Phase-1 deferred seam): a perspective mode with no
	# framing entry would null-crash on fr.* below. Skip the shot, don't crash.
	if not _grammar.framing.has(s.mode):
		return
	match s.mode:
		"hero_os":
			# Pulled back/up/wide so a bulky (full-armour) shoulder frames the
			# corner instead of blocking the subject.
			var fr: Dictionary = _grammar.framing[s.mode]
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var d := (o.position - f.position).normalized()
			pos = f.position - d * fr.pullback + d.cross(Vector3.UP) * fr.lateral + Vector3(0, fr.height, 0)
			aim = o.position + Vector3(0, 10, 0)
			fov = fr.fov
		"hero_cut":
			# Low angle beside the shooter, looking down the firing line into the
			# city — the beam lances past camera and wrecks whatever it crosses.
			var fr: Dictionary = _grammar.framing[s.mode]
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var d := (o.position - f.position).normalized()
			pos = f.position - d * fr.pullback + d.cross(Vector3.UP) * fr.lateral + Vector3(0, fr.height, 0)
			aim = mid + Vector3(0, 9, 0)
			fov = fr.fov
			_roll = fr.roll
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
		"bullet_time":
			var fr: Dictionary = _grammar.framing[s.mode]
			var shooter: Node3D = actors[s.focus]
			var victim: Node3D = actors[_other(str(s.focus))]
			var center := victim.position.lerp(shooter.position, 0.2) + Vector3(0, 10, 0)
			var wall_len := (float(s.t1) - float(s.t0)) / _grammar.bt_scale
			var p := clampf(_wall / wall_len, 0.0, 1.0)
			var ang := PI + p * TAU * 0.75
			pos = center + Vector3(cos(ang) * fr.radius, fr.height_base + p * fr.height_rise, sin(ang) * fr.depth)
			aim = center
			fov = fr.fov
			_roll = lerpf(-0.05, 0.03, p)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov
	pos = _resolve_occlusion(pos, aim)
	# Footfall/landing rumble — only on these close perspective shots, so the
	# low hero angles feel the giant's weight while the iso view stays steady.
	if shake_strength > 0.001:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_strength * 0.3
	camera.position = pos
	# Clear everything between the lens and just shy of the subject — no rubble,
	# debris, or towers occluding the close shot (the blade was getting buried).
	_cull_near(pos, maxf(pos.distance_to(aim) - 6.0, 0.0))
	_set_focus(pos.distance_to(aim), 0.07)
	_apply_aim(aim, delta, 9.0)

func _fade_for_iso(eye: Vector3, a_pos: Vector3, b_pos: Vector3) -> void:
	for bld in get_tree().get_nodes_in_group("kb_building"):
		var aabb: AABB = bld.get_meta("aabb")
		var occ := aabb.intersects_segment(eye, a_pos) != null \
			or aabb.intersects_segment(eye, b_pos) != null
		_fade_building(bld, FADE_MIN if occ else 1.0)
