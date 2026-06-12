extends Node3D
## VFX garnish. Reads outcomes from event payloads; never decides anything.

var actors: Dictionary = {}
var director: Node3D
var rng := RandomNumberGenerator.new()

func setup(p_actors: Dictionary, p_director: Node3D) -> void:
	actors = p_actors
	director = p_director
	rng.seed = 7
	director.fight_event.connect(_on_event)

func _on_event(e: Dictionary) -> void:
	var shooter: Node3D = actors[e.actor]
	var target: Node3D = actors[_other(str(e.actor))]
	match e.kind:
		"fire_beam":
			_beam(shooter, target, e.payload)
		"fire_burst":
			_burst(shooter, target, e.payload)
		"destroyed":
			_explosion(target.position + Vector3(0, 9, 0))

func _other(a: String) -> String:
	return "B" if a == "A" else "A"

func _beam(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var from: Vector3 = shooter.muzzle_pos()
	var to: Vector3 = target.position + Vector3(0, 11, 0)
	if payload.get("blocked", false):
		to = target.position + Vector3(0, 11, 0) - (target.position - shooter.position).normalized() * 4.0
	elif not payload.get("hit", false):
		to = to + Vector3(0, 6, 14) + (to - from).normalized() * 30.0  # overshoot into a building
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, from.distance_to(to))
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 1.0) if shooter.actor_id == "A" else Color(1.0, 0.4, 0.2)
	mat.emission_energy_multiplier = 14.0
	mat.albedo_color = Color(1, 1, 1)
	mesh.material = mat
	beam.mesh = mesh
	add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)
	var light := OmniLight3D.new()
	light.light_color = mat.emission
	light.light_energy = 18.0
	light.omni_range = 35.0
	add_child(light)
	light.global_position = (from + to) * 0.5
	_impact_flash(to, mat.emission)
	if payload.get("hit", false) and float(payload.get("damage", 0)) > 25.0:
		_hitstop()
	director.shake_strength = maxf(director.shake_strength, 0.8 if payload.get("hit", false) else 0.3)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.35)
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.chain().tween_callback(func():
		beam.queue_free()
		light.queue_free())

func _burst(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var rounds := int(payload.rounds)
	var hits := int(payload.hits)
	for i in rounds:
		var is_hit := i < hits
		_tracer(shooter.muzzle_pos(), target, is_hit, float(i) * 0.09)

func _tracer(from: Vector3, target: Node3D, is_hit: bool, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var to: Vector3 = target.position + Vector3(0, rng.randf_range(6, 13), rng.randf_range(-2, 2))
	if not is_hit:
		to += Vector3(rng.randf_range(-4, 4), rng.randf_range(2, 8), rng.randf_range(10, 20))
		to += (to - from).normalized() * rng.randf_range(15.0, 35.0)  # sail past, hit cityscape
	var b := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.18
	mesh.height = 2.6
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.4)
	mat.emission_energy_multiplier = 8.0
	mesh.material = mat
	b.mesh = mesh
	add_child(b)
	b.global_position = from
	b.look_at(to, Vector3.UP)
	b.rotate_object_local(Vector3.RIGHT, PI / 2)
	var tw := create_tween()
	tw.tween_property(b, "global_position", to, from.distance_to(to) / 220.0)
	tw.tween_callback(func():
		_impact_flash(to, Color(1.0, 0.7, 0.3), 0.5 if is_hit else 0.9)
		b.queue_free())

func _impact_flash(pos: Vector3, color: Color, scale := 1.0) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.4
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 6.0 * scale
	pm.initial_velocity_max = 16.0 * scale
	pm.gravity = Vector3(0, -20, 0)
	pm.scale_min = 0.1
	pm.scale_max = 0.35 * scale
	pm.color = color
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.3
	dm.height = 0.6
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 6.0
	dm.material = mat
	p.draw_pass_1 = dm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func(): p.queue_free())

func _explosion(pos: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.35)
	flash.light_energy = 60.0
	flash.omni_range = 90.0
	add_child(flash)
	flash.global_position = pos
	create_tween().tween_property(flash, "light_energy", 0.0, 1.4)
	_fireball(pos)
	_smoke(pos)
	_ring(pos)
	_hitstop(0.12)
	director.shake_strength = 2.0
	get_tree().create_timer(3.0).timeout.connect(func(): flash.queue_free())

func _fireball(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 80
	p.lifetime = 1.1
	var pm := ParticleProcessMaterial.new()
	pm.spread = 180.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, 6, 0)
	pm.scale_min = 1.2
	pm.scale_max = 3.5
	pm.color = Color(1.0, 0.55, 0.15)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 1.0
	dm.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 5.0
	dm.material = mat
	p.draw_pass_1 = dm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(func(): p.queue_free())

func _smoke(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 40
	p.lifetime = 4.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, 2, 0)
	pm.scale_min = 2.0
	pm.scale_max = 6.0
	pm.color = Color(0.12, 0.11, 0.1, 0.7)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 1.0
	dm.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.14, 0.13, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = mat
	p.draw_pass_1 = dm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(6.0).timeout.connect(func(): p.queue_free())

func _ring(pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.5)
	mat.emission_energy_multiplier = 8.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.8)
	mesh.material = mat
	ring.mesh = mesh
	add_child(ring)
	ring.global_position = pos
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(40, 4, 40), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tw.chain().tween_callback(func(): ring.queue_free())

func _hitstop(dur := 0.07) -> void:
	var prev := Engine.time_scale
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = prev
