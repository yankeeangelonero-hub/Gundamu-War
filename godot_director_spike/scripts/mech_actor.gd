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
var _target_yaw := 0.0
var dashing := false
var _ghost_t := 0.0
var _trail: GPUParticles3D
var combat_face: Node3D = null   # when set, always aim at this enemy (strafe, don't turn away)
var _prev_yaw := 0.0
# Velocity integrator (real momentum): the mech steers toward _target with a
# capped acceleration and carries velocity across waypoints, so it banks through
# turns and can't stop on a dime. max_accel is the mass dial (lower = heavier).
var velocity := Vector3.ZERO
var _target := Vector3.ZERO
var max_speed := 48.0    # keep top speed up (slow mechs linger in the city and
var max_accel := 24.0    # tank perf); HEAVY comes from low accel — slow ramp, carried momentum
var _boost_t := 0.0
var _boost_cd := 0.0     # cooldown: must walk/strafe before boosting again
var _was_airborne := false
var _crouch := 0.0       # transient torso dip on a heavy landing
var _foot_phase := 0     # footfall counter (heavy steps shake the ground)
var _land_cd := 0.0      # debounce so a landing fires once, not per threshold-jitter frame
var director: Node = null   # set by the director; used to kick camera shake on footfalls
var full_armor := false      # heavy loadout: extra plating + shoulder missile pods
var saber: MeshInstance3D    # beam blade, retracted until a melee strike
var _saber_lit := false
var _blade_light: OmniLight3D
var _swinging := false        # while true, the blade lays down a swing trail
var _lock_t := 0.0            # while >0, planted in a blade lock (no movement)
var _blocking := false
# Rigged mode: drive a real Mixamo-rigged mesh (Y-bot stand-in + box armour)
# instead of building block-out boxes. The integrator + interface are unchanged.
var rigged := false
var _rig: Node3D
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _cur_clip := ""
var _fire_t := 0.0       # while >0 the rigged mech holds the firing-rifle stance
var _thruster: OmniLight3D
# Build-pose mode (M1): stand static and expose a named hardpoint registry so the
# build screen can mount a placed loadout onto the same mech the fight will drive.
var build_pose := false
var _hardpoints := {}    # name -> Node3D mount point
var _mounted := {}       # name -> mounted weapon Node3D

func setup(id: String, color: Color, x: float, p_full_armor := false, p_rigged := false, p_build_pose := false) -> void:
	actor_id = id
	tint = color
	full_armor = p_full_armor
	rigged = p_rigged
	build_pose = p_build_pose
	position = Vector3(x, 0, 0)

func _ready() -> void:
	if rigged:
		_build_rigged()
		_target = position
		look_at_enemy_side()
		_prev_yaw = rotation.y
		return
	var pelvis := _box(Vector3(4.5, 2.0, 3.0), Vector3(0, 7.5, 0))
	torso = _box(Vector3(5.5, 4.5, 3.5), Vector3(0, 11.0, 0))
	head = _box(Vector3(1.8, 1.6, 2.0), Vector3(0, 14.0, 0))
	# visor: single emissive band (original identity rule: no twin-eye)
	var visor := _box(Vector3(1.6, 0.35, 0.2), Vector3(0, 14.1, 1.1), true)
	arm_l = _box(Vector3(1.6, 5.0, 1.6), Vector3(-3.8, 11.0, 0))
	arm_r = _box(Vector3(1.6, 5.0, 1.6), Vector3(3.8, 11.0, 0))
	if not build_pose:
		var gun := _box(Vector3(0.9, 0.9, 6.0), Vector3(3.8, 9.0, 2.5))
		muzzle = Node3D.new()
		muzzle.position = Vector3(3.8, 9.0, 5.5)
		add_child(muzzle)
	for leg_x in [-1.6, 1.6]:
		_box(Vector3(2.0, 6.5, 2.4), Vector3(leg_x, 3.25, 0))
	# Build-pose mech: skip the combat FX (default gun, thruster, saber, trail), stand
	# square to the camera, and expose hardpoints for the placed loadout to mount on.
	if build_pose:
		register_hardpoints()
		rotation.y = 0.0
		_target_yaw = 0.0
		_target = position
		_prev_yaw = 0.0
		return
	_trail = GPUParticles3D.new()
	_trail.amount = 30
	_trail.lifetime = 0.5
	_trail.emitting = false
	var tpm := ParticleProcessMaterial.new()
	tpm.direction = Vector3(0, 1, 0)
	tpm.spread = 40.0
	tpm.initial_velocity_min = 2.0
	tpm.initial_velocity_max = 9.0
	tpm.gravity = Vector3(0, -2, 0)
	tpm.scale_min = 0.8
	tpm.scale_max = 2.4
	tpm.color = Color(0.55, 0.55, 0.6, 0.5)
	_trail.process_material = tpm
	var tdm := SphereMesh.new()
	tdm.radius = 0.6
	tdm.height = 1.2
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.45, 0.45, 0.5, 0.5)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tdm.material = tmat
	_trail.draw_pass_1 = tdm
	_trail.position = Vector3(0, 1.5, 0)
	add_child(_trail)
	_thruster = OmniLight3D.new()
	_thruster.light_color = Color(0.5, 0.75, 1.0) if actor_id == "A" else Color(1.0, 0.6, 0.35)
	_thruster.light_energy = 0.0
	_thruster.omni_range = 16.0
	_thruster.position = Vector3(0, 7.0, -2.5)   # backpack
	add_child(_thruster)
	saber = MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(1.1, 15.0, 1.1)          # big, reads at camera distance
	var bmat := StandardMaterial3D.new()
	bmat.emission_enabled = true
	var blade_col := Color(0.5, 0.85, 1.0) if actor_id == "A" else Color(1.0, 0.45, 0.25)
	bmat.emission = blade_col
	bmat.emission_energy_multiplier = 18.0
	bmat.albedo_color = Color(1, 1, 1)
	bmesh.material = bmat
	saber.mesh = bmesh
	saber.position = Vector3(0, -9.5, 0.8)         # extends well past the hand
	saber.scale = Vector3(1, 0.001, 1)             # retracted
	saber.visible = false
	arm_r.add_child(saber)
	_blade_light = OmniLight3D.new()
	_blade_light.light_color = blade_col
	_blade_light.light_energy = 0.0
	_blade_light.omni_range = 24.0
	saber.add_child(_blade_light)
	_target = position
	if full_armor:
		_add_armor()
		max_accel = 18.0   # all that plating + ordnance = heavier still
	look_at_enemy_side()
	_prev_yaw = rotation.y

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

## Full-armour loadout: bolt-on plating + shoulder missile pods (with glowing
## launch tubes), backpack, skirt and leg armour — a heavier, bristling silhouette.
func _add_armor() -> void:
	var ac := tint.darkened(0.15)
	_armor_box(Vector3(6.6, 5.2, 4.2), Vector3(0, 11.3, 0.4), ac)     # chest bulk
	_armor_box(Vector3(5.2, 2.2, 4.6), Vector3(0, 7.2, 0.2), ac)      # skirt
	_armor_box(Vector3(4.2, 4.5, 2.2), Vector3(0, 12.0, -2.9), ac)    # backpack
	for sx in [-1.0, 1.0]:
		_armor_box(Vector3(3.2, 2.8, 3.8), Vector3(sx * 5.2, 13.2, 0.0), ac)   # pauldron
		_armor_box(Vector3(2.8, 3.4, 2.8), Vector3(sx * 5.6, 15.2, -0.3), ac)  # missile pod
		for ty in [-0.7, 0.7]:                                                  # launch tubes
			_box(Vector3(0.55, 0.55, 0.4), Vector3(sx * 5.6, 15.2 + ty, 1.0), true)
		_armor_box(Vector3(2.9, 4.2, 3.2), Vector3(sx * 1.6, 4.0, 0.3), ac)    # leg armour

func _armor_box(size: Vector3, pos: Vector3, col: Color) -> Node3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.4
	mat.metallic = 0.55
	mesh.material = mat
	m.mesh = mesh
	m.position = pos
	add_child(m)
	return m

func look_at_enemy_side() -> void:
	# Model front (visor band, gun, muzzle) is local +Z. A spawns left (-x) and
	# faces the enemy on the right (+x) → +90°; B faces left → -90°.
	rotation.y = deg_to_rad(90) if actor_id == "A" else deg_to_rad(-90)
	_target_yaw = rotation.y

# ---- hardpoint registry (M1 build-pose mount cascade) ----
# Named mount points, generalised from the old fixed gun attach, so the build
# screen can hang a placed loadout on the same mech node the fight will drive.
# Offsets are mech-local (model front = +Z). Keys mirror BuildMounts.HARDPOINTS.
const HARDPOINT_OFFSETS := {
	"hand_r": Vector3(3.8, 8.4, 1.2),
	"hand_l": Vector3(-3.8, 8.4, 1.2),
	"forearm_r": Vector3(3.8, 10.2, 0.8),
	"forearm_l": Vector3(-3.8, 10.2, 0.8),
	"shoulder_r": Vector3(3.4, 13.4, -0.6),
	"shoulder_l": Vector3(-3.4, 13.4, -0.6),
	"hip_r": Vector3(2.2, 6.6, 0.6),
	"hip_l": Vector3(-2.2, 6.6, 0.6),
	"back": Vector3(0.0, 12.2, -2.8),
}

func register_hardpoints() -> void:
	if not _hardpoints.is_empty():
		return
	for hp_name in HARDPOINT_OFFSETS:
		var n := Node3D.new()
		n.name = "hp_" + hp_name
		n.position = HARDPOINT_OFFSETS[hp_name]
		add_child(n)
		_hardpoints[hp_name] = n

func has_hardpoint(hp_name: String) -> bool:
	return _hardpoints.has(hp_name)

## Hang a weapon mesh on a named hardpoint (it becomes a child, so it rides the mech).
func mount(hp_name: String, mesh: Node3D) -> void:
	if not _hardpoints.has(hp_name):
		return
	_hardpoints[hp_name].add_child(mesh)
	_mounted[hp_name] = mesh

func clear_mounts() -> void:
	for hp_name in _mounted:
		var m: Node3D = _mounted[hp_name]
		if is_instance_valid(m):
			m.queue_free()
	_mounted.clear()

## World-space muzzle of the weapon mounted at `mount` (its barrel tip), so beams
## fire from the actual weapon. Falls back to the mech's default muzzle when the
## mount is empty/unmounted (standalone logs carry no mount).
func weapon_muzzle_pos(mount := "") -> Vector3:
	if mount != "" and _mounted.has(mount):
		var w: Node3D = _mounted[mount]
		if is_instance_valid(w):
			var mz: Node3D = w.get_node_or_null("muzzle")
			return mz.global_position if mz else w.global_position
	return muzzle_pos()

## Forward (barrel) direction of the mounted weapon; falls back to the default.
func weapon_muzzle_forward(mount := "") -> Vector3:
	if mount != "" and _mounted.has(mount):
		var w: Node3D = _mounted[mount]
		if is_instance_valid(w):
			return w.global_transform.basis.z.normalized()
	return muzzle_forward()

## The muzzle Node3D to parent muzzle FX onto (so they ride the weapon); the
## mounted weapon's marker, else the default muzzle.
func weapon_muzzle_node(mount := "") -> Node3D:
	if mount != "" and _mounted.has(mount):
		var w: Node3D = _mounted[mount]
		if is_instance_valid(w):
			var mz: Node3D = w.get_node_or_null("muzzle")
			return mz if mz else w
	return muzzle

func _process(delta: float) -> void:
	if dead:
		return
	# --- velocity integrator: real momentum toward the current move target ---
	_boost_t = maxf(0.0, _boost_t - delta)
	_boost_cd = maxf(0.0, _boost_cd - delta)
	_land_cd = maxf(0.0, _land_cd - delta)
	_lock_t = maxf(0.0, _lock_t - delta)
	if _lock_t > 0.0:
		# Blades locked: planted, straining — no seeking, no sliding.
		velocity = velocity.lerp(Vector3.ZERO, 14.0 * delta)
	else:
		var cap := max_speed + (22.5 if _boost_t > 0.0 else 0.0)
		var to_t := _target - position
		var dist := to_t.length()
		var desired := Vector3.ZERO
		if dist > 0.4:
			var slow := 7.0   # arrive: ease the desired speed down inside this radius
			desired = to_t / dist * (cap if dist > slow else cap * dist / slow)
		var steer := desired - velocity
		var amax := (max_accel + (75.0 if _boost_t > 0.0 else 0.0)) * delta
		if steer.length() > amax:
			steer = steer.normalized() * amax
		velocity += steer
		if velocity.length() > cap:
			velocity = velocity.normalized() * cap
	position += velocity * delta
	if position.y < 0.0:
		position.y = 0.0
		if velocity.y < 0.0:
			velocity.y = 0.0
	var spd := velocity.length()
	moving = spd > 1.0
	dashing = spd > 28.0
	if _trail:
		_trail.emitting = dashing
	# In combat the mech keeps its front (gun + visor) on the enemy, so any move
	# reads as a strafe/dodge rather than turning tail. Track fast enough that a
	# quick orbit around the enemy never leaves a mech looking the wrong way.
	if combat_face != null and is_instance_valid(combat_face):
		var fd := combat_face.position - position
		if Vector2(fd.x, fd.z).length() > 0.5:
			_target_yaw = atan2(fd.x, fd.z)
	rotation.y = lerp_angle(rotation.y, _target_yaw, (16.0 if dashing else 11.0) * delta)
	if rigged:
		_drive_rig(delta)
		return   # skip the block-out box visuals; the rig + clips handle the body
	# AMBAC: the mech whips its facing by swinging its arms — the limbs counter-
	# rotate the torso (angular momentum), so a turn reads as limb-driven.
	var yaw_vel := angle_difference(_prev_yaw, rotation.y) / maxf(delta, 0.0001)
	_prev_yaw = rotation.y
	if not _blocking:
		var swing := clampf(yaw_vel * 0.04, -1.0, 1.0)
		arm_l.rotation.x = lerpf(arm_l.rotation.x, swing, 14.0 * delta)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, -swing, 14.0 * delta)
	# Bank/lean from the integrated velocity; while locked, strain forward into
	# the blade press instead.
	if _lock_t > 0.0:
		torso.rotation.z = lerpf(torso.rotation.z, 0.0, 9.0 * delta)
		torso.rotation.x = lerpf(torso.rotation.x, -0.24, 10.0 * delta)
	else:
		var lat := velocity.dot(transform.basis.x)
		var fwd_s := velocity.dot(transform.basis.z)
		torso.rotation.z = lerpf(torso.rotation.z, clampf(-lat * 0.012, -0.34, 0.34), 9.0 * delta)
		torso.rotation.x = lerpf(torso.rotation.x, clampf(-fwd_s * 0.007, -0.32, 0.06), 9.0 * delta)
	var airborne := position.y > 2.0
	_crouch = lerpf(_crouch, 0.0, 8.0 * delta)
	if moving and not airborne:
		# Heavy gait: slow, big bob with a pronounced weight-shift waddle. Each
		# footfall (every half-cycle) thuds — kicks the camera and dips the torso.
		_bob_t += delta * (16.0 if dashing else 6.0)
		torso.position.y = 11.0 + sin(_bob_t) * (0.5 if dashing else 0.55) - _crouch
		rotation.z = sin(_bob_t * 0.5) * 0.03
		if not dashing:
			var ph := int(_bob_t / PI)
			if ph != _foot_phase:
				_foot_phase = ph
				_footfall()
	elif airborne:
		_bob_t += delta * 2.5                       # slow hover float
		torso.position.y = 11.0 + sin(_bob_t) * 0.2 - _crouch
		rotation.z = lerpf(rotation.z, 0.0, 5.0 * delta)
	else:
		torso.position.y = lerpf(torso.position.y, 11.0 - _crouch, 8.0 * delta)
		rotation.z = lerpf(rotation.z, 0.0, 5.0 * delta)
	# Land only on a genuine downward touchdown (not threshold jitter), debounced.
	if _was_airborne and not airborne and velocity.y < -2.0 and _land_cd <= 0.0:
		_land()
		_land_cd = 0.5
	_was_airborne = airborne
	if dashing:
		_ghost_t += delta
		if _ghost_t > 0.05:
			_ghost_t = 0.0
			_spawn_ghost()
	if _swinging and _saber_lit:
		_spawn_blade_trail()

## Set the move target. The integrator in _process steers there with inertia —
## velocity carries across calls, so a new target mid-move curves the mech rather
## than restarting it. A boost adds a one-shot thruster impulse + flare and is the
## only thing that goes airborne; default movement is grounded and momentum-driven.
func walk_to(to_x: float, to_y: float, to_z: float, dur: float, boost := false) -> void:
	moving = true
	_target = Vector3(to_x, to_y, to_z)
	if combat_face == null:
		var d := _target - position
		if Vector2(d.x, d.z).length() > 0.5:
			_target_yaw = atan2(d.x, d.z)
	if boost and _boost_cd <= 0.0:
		# Ground-boost: a horizontal thruster kick (mostly flattened) sustained for
		# the move, so the mech skims low and fast across the deck "for a while".
		var dir := _target - position
		dir.y *= 0.2                                  # keep the kick horizontal
		if dir.length() > 0.1:
			velocity += dir.normalized() * 21.0
		_boost_t = clampf(dur, 0.45, 1.6)             # boost lasts the move, not an instant
		_boost_cd = 3.2                               # then must walk/strafe before boosting again
		_boost_flare(-(_target - position).normalized())
	elif boost:
		_target.y = 0.0                               # boost requested but on cooldown → stay grounded

## Thruster jet: a bright flare + light kick at the back of the mech, pointing
## opposite the boost vector, that flashes and fades on each dash onset.
func _boost_flare(back_dir: Vector3) -> void:
	if _thruster:
		_thruster.light_energy = 6.0
		create_tween().tween_property(_thruster, "light_energy", 0.0, 0.45)
	var jet := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 1.1
	mesh.height = 9.0
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = _thruster.light_color if _thruster else Color(0.6, 0.8, 1.0)
	mat.emission_energy_multiplier = 9.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.7)
	mesh.material = mat
	jet.mesh = mesh
	get_parent().add_child(jet)
	jet.global_position = global_position + Vector3(0, 8.0, 0) + back_dir * 4.0
	jet.look_at(jet.global_position + back_dir, Vector3.UP)
	jet.rotate_object_local(Vector3.RIGHT, PI / 2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(jet, "scale", Vector3(0.2, 1.4, 0.2), 0.3)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.3)
	tw.chain().tween_callback(jet.queue_free)

## Turn (eased in _process) to face a world point — used when firing mid-run.
func face_toward(p: Vector3) -> void:
	var d := p - position
	if Vector2(d.x, d.z).length() > 0.5:
		_target_yaw = atan2(d.x, d.z)

## Speed-smear afterimage: a translucent emissive copy of the torso, left behind
## and fading, spawned a few times a second while dashing.
func _spawn_ghost() -> void:
	var g := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(5.5, 9.0, 3.5)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.32)
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.4
	mesh.material = mat
	g.mesh = mesh
	get_parent().add_child(g)
	g.global_position = global_position + Vector3(0, 10.5, 0)
	g.rotation = global_rotation
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.28)
	tw.chain().tween_callback(g.queue_free)

## A footfall of a heavy walking mech: dips the torso and kicks the camera
## (scaled by proximity, so pedestrian-level shots rumble and the iso view doesn't).
func _footfall() -> void:
	_crouch = maxf(_crouch, 0.35)
	if director and director.has_method("ground_shake"):
		director.ground_shake(position, 0.55)

## Heavy touchdown off a boost skim: deep crouch, dust kick, bigger ground-shake.
func _land() -> void:
	_crouch = 1.7
	_landing_dust()
	if director and director.has_method("ground_shake"):
		director.ground_shake(position, 1.4)

func _landing_dust() -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.7
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 85.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 0.8
	pm.scale_max = 2.0
	pm.color = Color(0.5, 0.48, 0.45, 0.5)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.5
	dm.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.43, 0.4, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = mat
	p.draw_pass_1 = dm
	get_parent().add_child(p)
	p.global_position = Vector3(global_position.x, 1.0, global_position.z)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func(): p.queue_free())

## Ignite the beam blade (extends from the hand) and light it up.
func ignite_saber() -> void:
	if saber == null or _saber_lit:
		return
	_saber_lit = true
	saber.visible = true
	saber.scale = Vector3(1, 0.001, 1)
	create_tween().tween_property(saber, "scale:y", 1.0, 0.08)
	if _blade_light:
		_blade_light.light_energy = 5.0

func retract_saber() -> void:
	if saber == null or not _saber_lit:
		return
	_saber_lit = false
	if _blade_light:
		_blade_light.light_energy = 0.0
	var tw := create_tween()
	tw.tween_property(saber, "scale:y", 0.001, 0.16)
	tw.tween_callback(func(): saber.visible = false)

## Melee strike: ignite, lunge in, and swing the blade arm in a big cleave arc
## that lays down a glowing swing trail. Presentation only — whether it connects
## is the log event, not this animation.
func melee_strike(target_pos: Vector3, _style: String) -> void:
	ignite_saber()
	var dir := target_pos - position
	dir.y = 0.0
	if dir.length() > 0.1:
		_target_yaw = atan2(dir.x, dir.z)
		velocity += dir.normalized() * 30.0       # lunge onto the target
	if arm_r == null:
		return                                    # rigged: lunge done, clips/garnish do the rest
	_blocking = true                              # hold the arm from AMBAC during the swing
	var tw := create_tween()
	tw.tween_property(arm_r, "rotation:x", deg_to_rad(-140), 0.14)   # wind up overhead
	tw.tween_property(arm_r, "rotation:x", deg_to_rad(95), 0.10)     # cleave through
	tw.tween_property(arm_r, "rotation:x", 0.0, 0.32)               # recover
	tw.tween_callback(func(): _blocking = false)
	_swinging = true                              # lay down the trail through the cleave
	get_tree().create_timer(0.36).timeout.connect(func(): _swinging = false)
	get_tree().create_timer(1.3).timeout.connect(retract_saber)

## Blades lock: plant in place and strain (no sliding) for the given duration.
func clash_lock(dur: float) -> void:
	_lock_t = dur
	velocity = Vector3.ZERO

## Knocked back: shoved away from the source of the blow with real momentum.
func knockback(away_dir: Vector3, force: float) -> void:
	away_dir.y = 0.0
	if away_dir.length() > 0.1:
		velocity = away_dir.normalized() * force

## Parry: the defender ignites its own blade and raises it to catch the strike,
## so a blocked melee reads as two blades locking.
func parry() -> void:
	if rigged:
		return
	ignite_saber()
	_blocking = true
	var tw := create_tween()
	tw.tween_property(arm_r, "rotation:x", deg_to_rad(-45), 0.1)
	tw.tween_interval(0.45)
	tw.tween_property(arm_r, "rotation:x", 0.0, 0.3)
	tw.tween_callback(func(): _blocking = false)
	get_tree().create_timer(1.3).timeout.connect(retract_saber)

## A fading copy of the blade dropped at its current pose each frame of a swing —
## together they read as a glowing arc trailing the cleave.
func _spawn_blade_trail() -> void:
	var g := MeshInstance3D.new()
	g.mesh = saber.mesh
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = _blade_light.light_color
	mat.emission_energy_multiplier = 12.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.6)
	g.material_override = mat
	get_parent().add_child(g)
	g.global_transform = saber.global_transform
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.24)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.24)
	tw.chain().tween_callback(g.queue_free)

## An upward velocity bump when the mech body-checks through a building.
func crash_jolt() -> void:
	velocity.y += 6.0

func muzzle_pos() -> Vector3:
	return muzzle.global_position

## Direction the barrel actually points (rigged: the rifle's animated +Z out the
## muzzle; block-out: the mech front). Beams travel along this so the shot leaves
## the gun where the gun is aimed, instead of snapping straight at the enemy.
func muzzle_forward() -> Vector3:
	if muzzle == null:
		return transform.basis.z.normalized()
	return muzzle.global_transform.basis.z.normalized()

## A weapon just fired: in rigged mode, snap into the firing-rifle stance and hold
## it briefly (the body plants to shoot, Torrington-style). Block-out mode has its
## own recoil tween, so this is a no-op there.
func fire_weapon() -> void:
	if not rigged or _anim == null or not _anim.has_animation("fire"):
		return
	_anim.speed_scale = 1.0
	_anim.play("fire", 0.1)
	_cur_clip = "fire"
	_fire_t = minf(_anim.get_animation("fire").length, 0.8)

func recoil() -> void:
	if rigged:
		return
	var tw := create_tween()
	tw.tween_property(torso, "position:z", -0.6, 0.05)
	tw.tween_property(torso, "position:z", 0.0, 0.25)

func flinch(big: bool) -> void:
	if rigged:
		return
	var amt := 0.10 if big else 0.04
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", -amt, 0.06)
	tw.tween_property(self, "rotation:x", 0.0, 0.3)

func block_pose() -> void:
	if rigged:
		return
	_blocking = true
	var tw := create_tween()
	tw.tween_property(arm_l, "rotation:x", deg_to_rad(-70), 0.12)
	tw.tween_interval(0.5)
	tw.tween_property(arm_l, "rotation:x", 0.0, 0.4)
	tw.tween_callback(func(): _blocking = false)

func die() -> void:
	dead = true
	moving = false
	if rigged:
		if _anim and _anim.has_animation("walk"):
			_anim.speed_scale = 0.0   # freeze the pose; garnish explosion covers the kill
		var tw := create_tween()
		tw.tween_property(_rig, "rotation:z", deg_to_rad(80), 0.7).set_trans(Tween.TRANS_QUAD)  # topple
		return
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

# ---- rigged mode: Mixamo Y-bot + bolt-on box armour + box rifle ----

const RIG_SCALE := 11.0   # Mixamo ~1.7u tall → ~19u mech, matching the city scale

func _build_rigged() -> void:
	var packed := load("res://models/run_rifle.fbx") as PackedScene
	_rig = packed.instantiate()
	_rig.scale = Vector3.ONE * RIG_SCALE
	add_child(_rig)
	_skel = _find_type(_rig, "Skeleton3D")
	_anim = _find_type(_rig, "AnimationPlayer")
	if _anim == null or _skel == null:
		push_error("rigged mech: skeleton/anim not found"); return
	# Base clip (the run-rifle take) → "run"; pull the others in from their files.
	_install_anim("run", _anim.get_animation("mixamo_com"))
	_add_clip("walk", "res://models/walk.fbx")
	_add_clip("strafe_l", "res://models/strafe_left.fbx")
	_add_clip("strafe_r", "res://models/strafe_right.fbx")
	_add_clip("fire", "res://models/firing_rifle.fbx")
	_add_clip("stand", "res://models/rifle_aiming_idle.fbx")   # default idle: rifle aiming stance
	for c in ["run", "walk", "strafe_l", "strafe_r", "stand"]:
		_prep_loco(c)
	_prep_oneshot("fire")   # one-shot firing stance for the plant; "stand" is the relaxed idle
	_attach_rifle()   # weapons only — no bolt-on armour (the real mech brings its own)
	var start := "stand" if _anim.has_animation("stand") else "walk"
	_anim.play(start)
	_cur_clip = start

func _find_type(n: Node, klass: String) -> Node:
	if n.is_class(klass):
		return n
	for c in n.get_children():
		var r := _find_type(c, klass)
		if r:
			return r
	return null

func _add_clip(clip_name: String, file: String) -> void:
	if not ResourceLoader.exists(file):
		return
	var temp := (load(file) as PackedScene).instantiate()
	var ap := _find_type(temp, "AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation("mixamo_com"):
		_install_anim(clip_name, ap.get_animation("mixamo_com"))
	temp.queue_free()

func _install_anim(clip_name: String, src: Animation) -> void:
	if src == null:
		return
	var a := src.duplicate() as Animation
	var lib: AnimationLibrary
	if _anim.has_animation_library(""):
		lib = _anim.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		_anim.add_animation_library("", lib)
	if lib.has_animation(clip_name):
		lib.remove_animation(clip_name)
	lib.add_animation(clip_name, a)

## Loop + strip root translation so the clip cycles in place (the integrator owns position).
func _prep_loco(clip_name: String) -> void:
	var a := _anim.get_animation(clip_name)
	if a == null:
		return
	a.loop_mode = Animation.LOOP_LINEAR
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D and String(a.track_get_path(i)).ends_with("Hips"):
			a.remove_track(i)
			return

## Like _prep_loco but plays once (firing stance) — strip root drift, no loop.
func _prep_oneshot(clip_name: String) -> void:
	var a := _anim.get_animation(clip_name)
	if a == null:
		return
	a.loop_mode = Animation.LOOP_NONE
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D and String(a.track_get_path(i)).ends_with("Hips"):
			a.remove_track(i)
			return

func _drive_rig(delta: float) -> void:
	if _fire_t > 0.0:
		_fire_t -= delta   # firing stance owns the body; resume locomotion when it ends
		return
	var spd := velocity.length()
	var fwd := velocity.dot(transform.basis.z)
	var lat := velocity.dot(transform.basis.x)
	var clip := "stand"
	# Front (local +Z) tracks the enemy, so a sideways move is a strafe. local +X is
	# the mech's LEFT (front +Z, up +Y → +X faces left), so +lat = stepping left.
	if spd > 5.0 and absf(lat) > absf(fwd):
		clip = "strafe_l" if lat > 0.0 else "strafe_r"
	elif spd > 14.0:
		clip = "run"
	elif spd > 2.0:
		clip = "walk"
	if not _anim.has_animation(clip):
		clip = "walk"   # stand missing → fall back so a stopped mech still cycles
	if clip != _cur_clip and _anim.has_animation(clip):
		_cur_clip = clip
		_anim.play(clip, 0.25)
	# Locomotion clips scale with speed; the standing pose plays at a calm steady rate.
	# A mech facing the enemy but moving backward plays its walk/run REVERSED, so a
	# retreat reads as a backpedal instead of a moonwalk (legs forward, body sliding back).
	if clip == "stand":
		_anim.speed_scale = 1.0
	else:
		var s := clampf(spd / 16.0, 0.7, 1.6) if spd > 1.5 else 0.85
		if (clip == "walk" or clip == "run") and fwd < -1.0:
			s = -s
		_anim.speed_scale = s

## Bolt a box onto a bone (armour plate / weapon mount). Tinted = team colour.
func _bone_box(bone: String, offset: Vector3, size: Vector3, col: Color) -> Node3D:
	var idx := _skel.find_bone(bone)
	if idx < 0:
		return null
	var ba := BoneAttachment3D.new()
	_skel.add_child(ba)
	ba.bone_name = bone
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.5
	mesh.material = mat
	mi.mesh = mesh
	mi.position = offset
	ba.add_child(mi)
	return mi

## Strap blocky armour over the Y-bot so it reads as a mech, not a mannequin.
func _strap_armor() -> void:
	var dark := tint.darkened(0.2)
	_bone_box("mixamorig_Spine2", Vector3(0, 0.04, 0.02), Vector3(0.45, 0.42, 0.32), tint)   # chest
	_bone_box("mixamorig_Hips", Vector3(0, 0, 0), Vector3(0.4, 0.26, 0.32), dark)            # pelvis
	_bone_box("mixamorig_Head", Vector3(0, 0.06, 0.03), Vector3(0.26, 0.26, 0.3), tint)      # head
	for s in ["Left", "Right"]:
		_bone_box("mixamorig_%sArm" % s, Vector3(0, -0.06, 0), Vector3(0.22, 0.26, 0.24), tint)        # shoulder
		_bone_box("mixamorig_%sForeArm" % s, Vector3(0, -0.1, 0), Vector3(0.16, 0.32, 0.18), dark)     # forearm
		_bone_box("mixamorig_%sUpLeg" % s, Vector3(0, -0.12, 0), Vector3(0.2, 0.34, 0.22), tint)       # thigh
		_bone_box("mixamorig_%sLeg" % s, Vector3(0, -0.12, 0), Vector3(0.18, 0.34, 0.2), dark)         # shin
		_bone_box("mixamorig_%sFoot" % s, Vector3(0, -0.02, 0.05), Vector3(0.18, 0.12, 0.3), dark)     # foot

## A rectangle rifle in the right hand; its tip is the muzzle for beam FX.
func _attach_rifle() -> void:
	var idx := _skel.find_bone("mixamorig_RightHand")
	if idx < 0:
		return
	var ba := BoneAttachment3D.new()
	_skel.add_child(ba)
	ba.bone_name = "mixamorig_RightHand"
	# Holder carries the (correct) facing rotation; the rifle + muzzle are then
	# offset along the HOLDER's forward, so they sit in the hand and extend down
	# the barrel — not along the hand bone's Z (which pointed at the shoulder).
	var holder := Node3D.new()
	holder.rotation_degrees = Vector3(-90, 0, 0)
	ba.add_child(holder)
	var rifle := MeshInstance3D.new()
	var rmesh := BoxMesh.new()
	rmesh.size = Vector3(0.13, 0.17, 0.8)   # a clear box rifle
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.16, 0.16, 0.19)
	rmat.roughness = 0.5
	rmesh.material = rmat
	rifle.mesh = rmesh
	rifle.position = Vector3(0, 0, 0.34)    # grip at the hand, barrel extends forward
	holder.add_child(rifle)
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0, 0.78)   # barrel tip — projectiles originate + aim from here
	holder.add_child(muzzle)
