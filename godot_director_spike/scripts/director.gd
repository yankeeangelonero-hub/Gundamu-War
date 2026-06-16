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

static func build_shot_list(events: Array, dur: float, _grammar: ShotGrammar = null) -> Array:
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
var _smooth_aim := Vector3.ZERO
var _aim_init := false
# X-ray gate: per-mech enable, faded toward 1 only while that mech is actually
# occluded by a building (>= XRAY_OCCLUDED_RAYS of its silhouette rays blocked).
var _xray_enable := {"A": 0.0, "B": 0.0}
const XRAY_FADE := 6.0          # enable lerp speed (~0.17s full on/off)
const XRAY_OCCLUDED_RAYS := 3   # of 5 silhouette rays blocked to count as occluded

func start(p_events: Array, p_shots: Array, p_camera: Camera3D, p_actors: Dictionary, dur: float) -> void:
	events = p_events
	shots = p_shots
	camera = p_camera
	actors = p_actors
	_dur = dur
	# It's a duel: each mech keeps its aim on the other, so movement strafes.
	if actors.has("A") and actors.has("B"):
		actors["A"].combat_face = actors["B"]
		actors["B"].combat_face = actors["A"]
		actors["A"].director = self
		actors["B"].director = self
	# Key the camera's side of the action axis once, from the opening camera pose
	# (F32/F33): every cut-in is then held on this side so the two mechs never swap
	# screen sides on a cut.
	if actors.has("A") and actors.has("B") and camera != null:
		_axis_keyed_side = _axis_side(camera.position, actors["A"].position, actors["B"].position)
	playing = true

## A footfall/landing thud, felt as camera shake scaled by proximity — a
## pedestrian-level lens close to a stomping giant rumbles; the high iso eye
## barely feels it. Mechs call this; the camera reads shake_strength.
func ground_shake(world_pos: Vector3, base: float) -> void:
	if camera == null:
		return
	var d := camera.global_position.distance_to(world_pos)
	shake_strength = maxf(shake_strength, base * clampf(45.0 / maxf(d, 10.0), 0.0, 1.0))

## Hard-hide any cullable clutter (buildings, rubble, debris) within `radius` of
## the lens, restoring everything beyond it. Call with radius 0 to show all.
## Clears the foreground on close-ups so debris never blocks the subject.
func _cull_near(cam_pos: Vector3, radius: float) -> void:
	for n in get_tree().get_nodes_in_group("kb_near_cull"):
		var node := n as Node3D
		node.visible = cam_pos.distance_to(node.global_position) > radius

## Fade each mech's x-ray window on only while that mech is genuinely occluded:
## cast the camera->mech silhouette rays against the city AABBs and require
## XRAY_OCCLUDED_RAYS of 5 blocked. Render-only; never touches the sim.
func _feed_xray_gate(mech_a: Vector3, mech_b: Vector3, delta: float) -> void:
	if camera == null:
		return
	var buildings := get_tree().get_nodes_in_group("kb_building")
	var cam := camera.global_position
	for key in ["A", "B"]:
		var aim: Vector3 = mech_a if key == "A" else mech_b
		var clear: int = Sightline.evaluate(cam, _silhouette_points(cam, aim), buildings).clear_count
		var target := 1.0 if (5 - clear) >= XRAY_OCCLUDED_RAYS else 0.0
		_xray_enable[key] = move_toward(_xray_enable[key], target, delta * XRAY_FADE)
	RenderingServer.global_shader_parameter_set("xray_enable_a", _xray_enable["A"])
	RenderingServer.global_shader_parameter_set("xray_enable_b", _xray_enable["B"])

func _process(delta: float) -> void:
	if not playing:
		return
	t += delta
	if actors.has("A") and actors.has("B"):
		var mech_a: Vector3 = actors["A"].position + Vector3(0, 9, 0)
		var mech_b: Vector3 = actors["B"].position + Vector3(0, 9, 0)
		RenderingServer.global_shader_parameter_set("xray_mech_a", mech_a)
		RenderingServer.global_shader_parameter_set("xray_mech_b", mech_b)
		_feed_xray_gate(mech_a, mech_b, delta)
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
			var raw := Vector3(float(e.payload.to_x), float(e.payload.get("to_y", 0.0)),
				float(e.payload.get("to_z", actor.position.z)))
			var to := _engage(raw, target.position)   # keep the move at duel range, not away
			actor.walk_to(to.x, to.y, to.z, dur, bool(e.payload.get("boost", false)))
		"fire_beam":
			actor.face_toward(target.position)
			actor.recoil()
			if e.payload.get("blocked", false):
				target.block_pose()
			elif e.payload.get("hit", false):
				target.flinch(float(e.payload.damage) > 25.0)
		"fire_burst":
			actor.face_toward(target.position)
			actor.recoil()
			if int(e.payload.hits) > 0:
				target.flinch(false)
		"fire_missiles":
			actor.face_toward(target.position)
			actor.recoil()
			if int(e.payload.get("hits", 0)) > 0:
				target.flinch(true)
		"fire_buster":
			actor.face_toward(target.position)
			# the heavy recoil/knockback + impact fire after the charge, in garnish
		"melee":
			actor.face_toward(target.position)
			actor.melee_strike(target.position, str(e.payload.get("style", "cleave")))
			target.face_toward(actor.position)
			var away: Vector3 = target.position - actor.position
			if e.payload.get("blocked", false):
				target.parry()          # defender draws + catches
				if str(e.payload.get("result", "lock")) == "knockback":
					actor.clash_lock(0.6)               # attacker drives through
					target.knockback(away, 40.0)        # defender shoved back
				else:
					actor.clash_lock(0.8)               # blades lock — both planted, straining
					target.clash_lock(0.8)
			elif e.payload.get("hit", false):
				target.flinch(true)
				target.knockback(away, 34.0)            # a connecting blow drives them back
			shake_strength = maxf(shake_strength, 1.0)
		"destroyed":
			actor.die()
			shake_strength = 1.0
	fight_event.emit(e)

## Engagement ring: keep a mech's move target within duel range of its enemy, so a
## log position that would send it walking off into the distance instead lands on
## the ring at the same bearing — the move reads as strafing the enemy, not fleeing.
## Pure function of the log target + enemy position, so it stays deterministic.
const ENGAGE_MIN := 34.0
const ENGAGE_MAX := 80.0
func _engage(raw: Vector3, enemy: Vector3) -> Vector3:
	var off := Vector3(raw.x - enemy.x, 0.0, raw.z - enemy.z)
	var d := off.length()
	if d < 0.5:
		return raw   # degenerate (target ~on enemy) — leave it, sim meant point-blank
	var clamped := clampf(d, ENGAGE_MIN, ENGAGE_MAX)
	var p := enemy + off / d * clamped
	return Vector3(p.x, raw.y, p.z)

func _update_shot() -> void:
	while _shot_idx + 1 < shots.size() and float(shots[_shot_idx + 1].t0) <= t:
		_shot_idx += 1
		Engine.time_scale = float(shots[_shot_idx].time_scale)
		_pick_idx = -1   # reset the composition-search hysteresis for the new shot

## The time scale the current shot wants — what a hitstop restores to, so a
## transient freeze can never leave time stuck in slow-mo.
func current_time_scale() -> float:
	if _shot_idx >= 0 and _shot_idx < shots.size():
		return float(shots[_shot_idx].time_scale)
	return 1.0

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
	var dof := false   # shallow focus on close coverage, deep focus on plates
	_roll = 0.0
	match s.mode:
		"wide":
			pos = Vector3(0, 45, 90)
			aim = mid
			fov = 55
		"dolly":
			# Leading shot: planted up the street ahead of the advancing mech.
			var f: Node3D = actors[s.focus]
			var o: Node3D = actors[_other(str(s.focus))]
			var dirx := signf(o.position.x - f.position.x)
			pos = f.position + Vector3(dirx * 16.0, 8, 12)
			aim = f.position + Vector3(0, 11, 0)
			fov = 48
			dof = true
		"two_shot":
			# Raking shot down the duel axis: focus mech foreground, opponent centered.
			var f2: Node3D = actors[s.focus]
			var o2: Node3D = actors[_other(str(s.focus))]
			var d2 := (o2.position - f2.position).normalized()
			var zside := 1.0 if s.focus == "A" else -1.0
			pos = f2.position - d2 * 14.0 + Vector3(0, 12, 10 * zside)
			aim = o2.position + Vector3(0, 10, 0)
			fov = 50
			dof = true
		"over_shoulder":
			var os_shooter: Node3D = actors[s.focus]
			var os_victim: Node3D = actors[_other(str(s.focus))]
			var os_dir := (os_victim.position - os_shooter.position).normalized()
			pos = os_shooter.position - os_dir * 18.0 + os_dir.cross(Vector3.UP) * 8.0 + Vector3(0, 16, 0)
			aim = os_victim.position + Vector3(0, 10, 0)
			fov = 40
			dof = true
		"punch_in":
			var f: Node3D = actors[s.focus]
			pos = f.position + Vector3(0, 13, 12 * (1.0 if f.position.x < 0 else -1.0))
			aim = f.position + Vector3(0, 13, 0)
			fov = 32
			dof = true
			_roll = 0.03
		"killcam":
			var shooter: Node3D = actors[s.focus]
			var victim: Node3D = actors[_other(str(s.focus))]
			var dir := (victim.position - shooter.position).normalized()
			var perp := dir.cross(Vector3.UP)
			pos = shooter.position - dir * 10.0 + perp * 7.0 + Vector3(0, 15, 0)
			aim = victim.position + Vector3(0, 10, 0)
			fov = 38
			dof = true
			_roll = -0.04
		"orbit":
			var wreck: Node3D = actors["B"] if actors["B"].dead else actors["A"]
			var ang := (t - float(s.t0)) * 0.35
			pos = wreck.position + Vector3(cos(ang) * 30.0, 22, sin(ang) * 10.0)
			aim = wreck.position + Vector3(0, 6, 0)
			fov = 45
	_set_focus(pos.distance_to(aim) if dof else -1.0)
	var k := 1.0 - exp(-5.0 * delta / maxf(Engine.time_scale, 0.05))
	camera.position = camera.position.lerp(pos, k)
	camera.fov = lerpf(camera.fov, fov, k)
	if shake_strength > 0.001:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_strength * 0.2
	_apply_aim(aim, delta, 8.0)

## Which side of the A<->B action axis a point sits on, in the horizontal plane
## (+1 or -1). Pure — used to hold the cut-ins on one side of the 180° line (F32).
static func _axis_side(p: Vector3, a_pos: Vector3, b_pos: Vector3) -> int:
	var axis := b_pos - a_pos
	axis.y = 0.0
	var rel := p - a_pos
	rel.y = 0.0
	return 1 if axis.cross(Vector3.UP).dot(rel) >= 0.0 else -1

## The authored lateral offset, signed so a cut-in's camera lands on `keyed_side`
## of the A<->B axis (F32). Flipping the lateral mirrors the camera across the axis
## (the offset is perpendicular to it), so this guarantees the keyed side. Pure.
static func _keyed_lateral(f_pos: Vector3, o_pos: Vector3, pullback: float, height: float, lateral: float, a_pos: Vector3, b_pos: Vector3, keyed_side: int) -> float:
	var d := (o_pos - f_pos).normalized()
	var p := f_pos - d * pullback + d.cross(Vector3.UP) * lateral + Vector3(0, height, 0)
	return lateral if _axis_side(p, a_pos, b_pos) == keyed_side else -lateral

## Silhouette sample points around the look target for the multi-ray occlusion test
## — feet / upper-body / both shoulders — so an off-center building covering the mech
## is caught, not just one dead-center ray. `aim` is the look point.
static func _silhouette_points(pos: Vector3, aim: Vector3) -> Array:
	var fwd := aim - pos
	fwd.y = 0.0
	var right := (fwd.cross(Vector3.UP).normalized() if fwd.length() > 0.01 else Vector3.RIGHT)
	return [
		aim,
		aim + Vector3(0, 5.0, 0),    # upper body / head
		aim - Vector3(0, 9.0, 0),    # toward the feet
		aim + right * 5.0,           # one shoulder
		aim - right * 5.0,           # other shoulder
	]

## Pick the candidate camera position with the most clear silhouette rays toward
## `aim`. `candidates` is an ordered array of Vector3 whose index pattern is stable
## across frames (e.g. angle offsets [-arc..+arc]). Keeps `prev_idx` unless another
## candidate beats its clear ray count by `margin` (hysteresis — damps jitter).
## Returns { "idx": int, "pos": Vector3, "clear": int }. Pure.
static func _pick_clear_pose(candidates: Array, aim: Vector3, buildings: Array, prev_idx: int, margin: int) -> Dictionary:
	if candidates.is_empty():
		return {"idx": -1, "pos": aim, "clear": 0}
	var cur := prev_idx if (prev_idx >= 0 and prev_idx < candidates.size()) else int(candidates.size() / 2)
	var scores: Array = []
	for c in candidates:
		scores.append(Sightline.evaluate(c, _silhouette_points(c, aim), buildings).clear_count)
	var top := 0
	for i in candidates.size():
		if scores[i] > scores[top]:
			top = i
	var chosen := cur
	if scores[top] >= scores[cur] + margin:
		chosen = top
	return {"idx": chosen, "pos": candidates[chosen], "clear": scores[chosen]}

## Keep an orbiting camera from passing directly overhead: enforce a minimum
## horizontal distance from its center so the shot always reads as an angle.
func _keep_lateral(pos: Vector3, center: Vector3, min_d: float) -> Vector3:
	var off := Vector2(pos.x - center.x, pos.z - center.z)
	if off.length() < min_d:
		off = Vector2(min_d, 0) if off.length() < 0.01 else off.normalized() * min_d
	return Vector3(center.x + off.x, pos.y, center.z + off.y)

const SNAP_ANGLE := 0.5     # rad (~28 deg): a swing bigger than this becomes a snap cut
const AIM_RATE_CAP := 0.9   # rad/s of wall-clock aim rotation within a shot

var _roll := 0.0            # camera dutch/roll (rad), applied after look_at
var _axis_keyed_side := 1   # which side of the A<->B axis the cut-ins stay on (F32)
var _pick_idx := -1         # composition-search hysteresis: the candidate index held across frames

## Shallow-focus control. dist <= 0 disables DOF (deep-focus plates).
func _set_focus(dist: float, strength := 0.06) -> void:
	var attr: CameraAttributesPractical = camera.attributes
	if attr == null:
		return
	if dist <= 0.0:
		attr.dof_blur_far_enabled = false
		attr.dof_blur_near_enabled = false
		return
	attr.dof_blur_amount = strength
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = dist + 18.0
	attr.dof_blur_far_transition = 30.0
	attr.dof_blur_near_enabled = true
	attr.dof_blur_near_distance = maxf(dist - 14.0, 0.5)
	attr.dof_blur_near_transition = 8.0

## Eased aim with an angular guard: small drifts ease in at a capped angular
## rate; anything bigger than SNAP_ANGLE cuts instantly instead of swinging.
func _apply_aim(aim: Vector3, delta: float, rate := 8.0) -> void:
	var wall_delta := delta / maxf(Engine.time_scale, 0.01)
	if not _aim_init:
		_smooth_aim = aim
		_aim_init = true
	else:
		var to_cur := _smooth_aim - camera.position
		var to_new := aim - camera.position
		var ang := 0.0
		if to_cur.length() > 0.01 and to_new.length() > 0.01:
			ang = to_cur.normalized().angle_to(to_new.normalized())
		if ang > SNAP_ANGLE:
			_smooth_aim = aim
		else:
			var ak := 1.0 - exp(-rate * wall_delta)
			if ang > 0.0001:
				ak = minf(ak, AIM_RATE_CAP * wall_delta / ang)
			_smooth_aim = _smooth_aim.lerp(aim, ak)
	if not camera.position.is_equal_approx(_smooth_aim):
		camera.look_at(_smooth_aim, Vector3.UP)
		if absf(_roll) > 0.0005:
			camera.rotate_object_local(Vector3(0, 0, 1), _roll)
