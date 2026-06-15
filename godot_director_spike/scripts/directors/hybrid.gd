extends "res://scripts/director.gd"
## Variant 6 — Iso Hybrid: the production direction. An isometric tactical view
## over a destructible city is the BASE the eye lives in (legible, strategy-game
## readable), and the camera CUTS to cinematic perspective shots on the big
## beats — the opening exchange, a mid-fight building-wrecking beam, and the
## kill — then cuts back to iso. Orthographic backbone, perspective punctuation.

const VOCAB := ["iso", "iso_aftermath", "hero_os", "hero_cut", "melee_cut", "bullet_time",
	"popup_burst", "chase_pursuit"]

const OS_LEN := 1.8
const CUT_LEN := 1.8
const BT_PRE := 0.2
const BT_POST := 0.35
const BT_SCALE := 0.07
const ISO_OFFSET := Vector3(-45, 90, 18)
const FIRE_KINDS := ["fire_beam", "fire_burst", "fire_swarm", "fire_buster"]

static func build_shot_list(events: Array, dur: float) -> Array:
	var first_t := -1.0
	var first_actor := "A"
	var lethal_t := dur
	var lethal_actor := "A"
	var lethal_kind := ""
	var hero_kill_flag := false
	var mids: Array = []      # non-first, non-lethal fire events: candidates to intercut
	# The kill can be any event kind (beam OR melee cleave) — find it generically.
	for e in events:
		if e.payload.get("lethal", false):
			lethal_t = float(e.tick) * TICK
			lethal_actor = str(e.actor)
			lethal_kind = str(e.kind)
			hero_kill_flag = bool(e.payload.get("hero_kill", false))
	for e in events:
		if not (e.kind in FIRE_KINDS) or e.payload.get("lethal", false):
			continue
		var t := float(e.tick) * TICK
		if first_t < 0.0:
			first_t = t
			first_actor = str(e.actor)
		else:
			mids.append({"t": t, "actor": str(e.actor)})
	# Intercut the fire event nearest mid-fight (most likely diagonal across a tower).
	var target := (first_t + lethal_t) * 0.5
	var mid: Dictionary = {}
	for m in mids:
		if mid.is_empty() or absf(float(m.t) - target) < absf(float(mid.t) - target):
			mid = m

	var fixed: Array = [{"t0": first_t - 0.3, "t1": first_t + OS_LEN, "mode": "hero_os",
		"focus": first_actor, "time_scale": 1.0}]
	if not mid.is_empty() and float(mid.t) - 0.3 > first_t + OS_LEN:
		fixed.append({"t0": float(mid.t) - 0.3, "t1": float(mid.t) + CUT_LEN, "mode": "hero_cut",
			"focus": str(mid.actor), "time_scale": 1.0})
	# Every non-lethal melee clash gets a tight close-up so the blade reads.
	for e in events:
		if e.kind == "melee" and not e.payload.get("lethal", false):
			var mt := float(e.tick) * TICK
			fixed.append({"t0": mt - 0.5, "t1": mt + 1.7, "mode": "melee_cut",
				"focus": str(e.actor), "time_scale": 0.5})
	# hero_kill gets longer post-window and slower scale (capital-grade arc).
	var bt_post := 0.6 if hero_kill_flag else BT_POST
	var bt_scale := 0.05 if hero_kill_flag else BT_SCALE
	fixed.append({"t0": lethal_t - BT_PRE, "t1": lethal_t + bt_post, "mode": "bullet_time",
		"focus": lethal_actor, "time_scale": bt_scale, "hero_kill": hero_kill_flag})

	# Overload build-up: a tightening "reactor cooking off" shot just before the
	# lethal overload. Only fires when the killing blow is an overload (not a weapon fire).
	if lethal_kind == "overload":
		var buildup_t := lethal_t - 0.8
		if buildup_t > first_t + OS_LEN + 0.1:
			fixed.append({"t0": buildup_t, "t1": lethal_t, "mode": "hero_cut",
				"focus": lethal_actor, "time_scale": 1.0})

	# Pop-up punctuation: a low/heroic angle shot at the single most dramatic pop-up
	# burst (highest to_y — sells the biggest vertical leap). Capped at one shot to
	# preserve the iso backbone rhythm; more than one floods the cut rate.
	# Duration: 1.2s. Skip if it would fully overlap with the hero_os window.
	const POPUP_LEN := 1.2
	var best_popup_e: Dictionary = {}
	for e in events:
		if e.kind != "advance" or not (float(e.payload.get("to_y", 0.0)) > 0.0):
			continue
		var pt := float(e.tick) * TICK
		# Skip if this pop-up fires inside or immediately after the hero_os window.
		if pt < first_t + OS_LEN + 0.2:
			continue
		if best_popup_e.is_empty() or float(e.payload.get("to_y", 0.0)) > float(best_popup_e.payload.get("to_y", 0.0)):
			best_popup_e = e
	if not best_popup_e.is_empty():
		var pt := float(best_popup_e.tick) * TICK
		fixed.append({"t0": pt - 0.1, "t1": pt + POPUP_LEN, "mode": "popup_burst",
			"focus": str(best_popup_e.actor), "time_scale": 1.0})

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
			chase_end = ct + float(e.payload.get("end_tick", e.tick) - e.tick) * TICK
	if chase_start >= 0.0:
		var chase_mid := (chase_start + chase_end) * 0.5
		var cs0 := chase_mid - CHASE_LEN * 0.5
		var cs1 := chase_mid + CHASE_LEN * 0.5
		# Always add — iso backbone clips it naturally if it overlaps bullet_time.
		fixed.append({"t0": cs0, "t1": cs1, "mode": "chase_pursuit",
			"focus": chase_actor, "time_scale": 1.0})

	fixed.sort_custom(func(x, y): return float(x.t0) < float(y.t0))

	# Iso fills every gap; the tail after the kill is the iso aftermath read.
	var shots: Array = []
	var cursor := 0.0
	for f in fixed:
		var t0 := maxf(float(f.t0), cursor)
		if float(f.t1) <= t0:
			continue  # fully clipped by a prior overlapping shot
		if t0 - cursor > 0.001:
			shots.append({"t0": cursor, "t1": t0, "mode": "iso", "focus": "", "time_scale": 1.0})
		var shot: Dictionary = f.duplicate()
		shot["t0"] = t0
		shots.append(shot)
		cursor = float(f.t1)
	if dur - cursor > 0.001:
		shots.append({"t0": cursor, "t1": dur, "mode": "iso_aftermath", "focus": "", "time_scale": 1.0})
	return shots

# ---- runtime camera ----

var _zoom := 90.0
var _cam_shot := -1
var _wall := 0.0

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
		var want := clampf(a.position.distance_to(b.position) * 0.7 + 30.0, 50.0, 118.0)
		if s.mode == "iso_aftermath":
			focus_pt = (b.position if b.dead else a.position)
			want = 58.0
		var k := 1.0 - exp(-3.0 * delta / maxf(Engine.time_scale, 0.05))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_zoom = lerpf(_zoom, want, k)
		camera.size = _zoom
		camera.position = camera.position.lerp(focus_pt + ISO_OFFSET, k)
		_set_focus(-1.0)
		_fade_for_iso(camera.position, a.position + Vector3(0, 10, 0), b.position + Vector3(0, 10, 0))
		_cull_near(camera.position, 0.0)   # tactical view sees the whole city
		_apply_aim(focus_pt, delta, 5.0)
		return

	# --- cinematic punctuation (perspective) ---
	var pos: Vector3
	var aim: Vector3
	var fov := 45.0
	match s.mode:
		"hero_os":
			# Pulled back/up/wide so a bulky (full-armour) shoulder frames the
			# corner instead of blocking the subject.
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var d := (o.position - f.position).normalized()
			pos = f.position - d * 18.0 + d.cross(Vector3.UP) * 8.0 + Vector3(0, 16, 0)
			aim = o.position + Vector3(0, 10, 0)
			fov = 40
		"hero_cut":
			# Low angle beside the shooter, looking down the firing line into the
			# city — the beam lances past camera and wrecks whatever it crosses.
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var d := (o.position - f.position).normalized()
			pos = f.position - d * 2.0 + d.cross(Vector3.UP) * 9.0 + Vector3(0, 5, 0)
			aim = mid + Vector3(0, 9, 0)
			fov = 46
			_roll = -0.05
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
		"melee_cut":
			# Tight, slightly slow close-up orbiting the blade clash point.
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var contact := f.position.lerp(o.position, 0.5) + Vector3(0, 11, 0)
			var ang := PI * 0.25 + _wall * 0.6
			pos = contact + Vector3(cos(ang) * 15.0, 4.0, sin(ang) * 15.0)
			aim = contact
			fov = 36
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
