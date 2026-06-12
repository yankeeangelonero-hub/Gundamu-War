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
