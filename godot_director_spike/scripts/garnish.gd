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
	# Pre-read the log (the director advantage, applied to VFX): every beam
	# gets a muzzle charge-up glow starting 0.45s before it fires.
	for e in director.events:
		if e.kind == "fire_beam":
			var at := float(e.tick) * 0.1 - 0.45
			if at > 0.0:
				var who := str(e.actor)
				get_tree().create_timer(at).timeout.connect(func(): _charge(actors[who]))

func _on_event(e: Dictionary) -> void:
	var shooter: Node3D = actors[e.actor]
	var target: Node3D = actors[_other(str(e.actor))]
	# Any weapon discharge snaps the firer into its firing stance (rigged mechs).
	if str(e.kind).begins_with("fire") and shooter.has_method("fire_weapon"):
		shooter.fire_weapon()
	match e.kind:
		"fire_beam":
			_beam(shooter, target, e.payload)
		"fire_burst":
			_burst(shooter, target, e.payload)
		"fire_missiles":
			_missiles(shooter, target, e.payload)
		"fire_buster":
			_buster(shooter, target, e.payload)
		"melee":
			_melee_clash(shooter, target, e.payload)
		"destroyed":
			_explosion(shooter.position + Vector3(0, 9, 0))
			_wreck_smoke(shooter.position + Vector3(0, 5, 0))

func _other(a: String) -> String:
	return "B" if a == "A" else "A"

# ---- energy-FX materials: HDR emissive (bloom) ----

## One-mesh HDR-emissive energy material. Used by tracers, missiles, charge orbs,
## impact sparks, beams.
func _energy_mat(color: Color, mult := 8.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = mult
	m.albedo_color = Color(1, 1, 1)
	return m

## A beam segment from→to: a single HDR-emissive bar that self-fades.
func _draw_beam(from: Vector3, to: Vector3, color: Color, core_w: float) -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = (from + to) * 0.5
	if not holder.global_position.is_equal_approx(to):
		holder.look_at(to, Vector3.UP)
	var length := from.distance_to(to)
	var em := _energy_mat(color, 14.0)
	_beam_box(holder, Vector3(core_w, core_w, length), em)
	var tw := create_tween()
	tw.tween_property(em, "emission_energy_multiplier", 0.0, 0.35)
	tw.chain().tween_callback(holder.queue_free)

## Re-aim a shot so it leaves straight down the barrel (following the rifle's
## animated rotation) while keeping the original muzzle→aim distance — so a hit
## still reaches the enemy plane and a miss still overshoots by the same length.
func _barrel_aim(shooter: Node3D, from: Vector3, aim_point: Vector3) -> Vector3:
	if not shooter.has_method("muzzle_forward"):
		return aim_point
	return from + shooter.muzzle_forward() * from.distance_to(aim_point)

func _beam_box(holder: Node3D, size: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	holder.add_child(mi)

## Mechs body-check the city: any intact building a (living) mech's footprint
## overlaps gets smashed and toppled in the mech's travel direction. Driven by
## deterministic mech positions, so the same buildings fall on every run.
func _process(_delta: float) -> void:
	for id in actors:
		var m: Node3D = actors[id]
		if m.dead:
			continue
		var here := Vector3(m.position.x, m.position.y + 8.0, m.position.z)   # body centre, real altitude
		for bld in get_tree().get_nodes_in_group("kb_building"):
			var aabb: AABB = bld.get_meta("aabb")
			if aabb.grow(2.5).has_point(here):
				bld.remove_from_group("kb_building")
				_smash_building(bld, m)

func _smash_building(b: Node3D, mech: Node3D) -> void:
	var at := Vector3(b.position.x, 8.0, b.position.z)
	var dir := mech.global_transform.basis.z   # mech front (+Z)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3(1, 0, 0)
	_fireball(at)
	_smoke(at)
	_debris(at)
	_ring(Vector3(b.position.x, 1.0, b.position.z), Color(0.6, 0.55, 0.5), 70.0)
	director.shake_strength = maxf(director.shake_strength, 1.8)
	if mech.has_method("crash_jolt"):
		mech.crash_jolt()
	var mat: StandardMaterial3D = (b as MeshInstance3D).mesh.material
	var tw := create_tween().set_parallel(true)
	# Topple over in the dash direction, slide, sink, and char.
	tw.tween_property(b, "position", b.position + dir * 14.0 - Vector3(0, b.position.y * 0.7, 0), 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "rotation", Vector3(dir.z * 1.4, 0, -dir.x * 1.4), 0.8)
	tw.tween_property(b, "scale:y", 0.25, 0.9)
	tw.tween_property(mat, "albedo_color", Color(0.04, 0.035, 0.03), 0.7)
	for c in (b as MeshInstance3D).get_children():
		if c is MeshInstance3D:
			c.visible = false

## Anticipation: a growing emissive orb + light at the muzzle ahead of a beam.
func _charge(mech: Node3D) -> void:
	if mech.dead:
		return
	var color: Color = Color(0.3, 0.9, 1.0) if mech.actor_id == "A" else Color(1.0, 0.4, 0.2)
	var orb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.material = _energy_mat(color, 10.0)
	orb.mesh = mesh
	orb.scale = Vector3.ONE * 0.2
	mech.muzzle.add_child(orb)
	var light := OmniLight3D.new()
	light.visible = false   # omni removed: scene lit by directional + sky only
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = 20.0
	mech.muzzle.add_child(light)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(orb, "scale", Vector3.ONE * 1.5, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(light, "light_energy", 9.0, 0.42)
	tw.chain().tween_callback(func():
		orb.queue_free()
		light.queue_free())

## The wreck smolders through the aftermath coverage.
func _wreck_smoke(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 26
	p.lifetime = 3.5
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 18.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, 1.5, 0)
	pm.scale_min = 1.5
	pm.scale_max = 4.0
	pm.color = Color(0.1, 0.09, 0.085, 0.55)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 1.0
	dm.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.11, 0.1, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = mat
	p.draw_pass_1 = dm
	add_child(p)
	p.global_position = pos
	p.emitting = true

func _beam(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var from: Vector3 = shooter.muzzle_pos()
	var to: Vector3 = target.position + Vector3(0, 11, 0)
	if payload.get("blocked", false):
		to = target.position + Vector3(0, 11, 0) - (target.position - shooter.position).normalized() * 4.0
	elif not payload.get("hit", false):
		to = to + Vector3(0, 6, 22) + (to - from).normalized() * 30.0  # overshoot into a building
	to = _barrel_aim(shooter, from, to)   # leave the shot down the rifle barrel
	var color := Color(0.3, 0.9, 1.0) if shooter.actor_id == "A" else Color(1.0, 0.4, 0.2)
	_draw_beam(from, to, color, 0.6)
	_impact_flash(to, color)
	# Beams punch through architecture: any building crossing the line dies.
	for bld in get_tree().get_nodes_in_group("kb_building"):
		var aabb: AABB = bld.get_meta("aabb")
		var hit_pt: Variant = aabb.intersects_segment(from, to)
		if hit_pt != null:
			bld.remove_from_group("kb_building")
			_detonate_building(bld, hit_pt, from)
	if payload.get("hit", false) and float(payload.get("damage", 0)) > 25.0:
		_hitstop()
	director.shake_strength = maxf(director.shake_strength, 0.8 if payload.get("hit", false) else 0.3)

## A beam tore through this building: blast at the entry point, then the
## whole block collapses straight down into a charred slab. Visual-only —
## the city layout and beam line are both deterministic, so the same
## buildings die on every run of the same log.
func _detonate_building(b: Node3D, at: Vector3, from: Vector3) -> void:
	await get_tree().create_timer(from.distance_to(at) / 250.0).timeout
	_fireball(at)
	_smoke(at)
	_smoke(Vector3(b.position.x, 2.0, b.position.z))
	_impact_flash(at, Color(1.0, 0.6, 0.2), 1.6)
	director.shake_strength = maxf(director.shake_strength, 1.3)
	_debris(at)
	_ring(Vector3(b.position.x, 1.0, b.position.z), Color(0.55, 0.5, 0.45), 70.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(b, "scale:y", 0.06, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "position:y", b.position.y * 0.06, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "rotation:z", rng.randf_range(-0.06, 0.06), 0.9)
	var mat: StandardMaterial3D = b.mesh.material
	tw.tween_property(mat, "albedo_color", Color(0.03, 0.025, 0.02), 0.7)

## Tumbling concrete chunks thrown from a building hit.
func _debris(at: Vector3) -> void:
	for i in 9:
		var c := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * rng.randf_range(1.2, 3.5)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.075, 0.08)
		mat.roughness = 0.9
		mesh.material = mat
		c.mesh = mesh
		add_child(c)
		c.add_to_group("kb_near_cull")   # debris is culled when it blocks a close-up
		c.global_position = at + Vector3(rng.randf_range(-2, 2), rng.randf_range(-2, 2), rng.randf_range(-2, 2))
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.1, 0.8), rng.randf_range(-1, 1)).normalized()
		var land := at + dir * rng.randf_range(8.0, 26.0)
		land.y = rng.randf_range(0.5, 1.5)
		var dur := rng.randf_range(0.7, 1.3)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(c, "global_position", land, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "rotation", Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6)), dur)
		get_tree().create_timer(7.0).timeout.connect(func(): c.queue_free())

## A missile salvo: a stream of self-guided projectiles that arc out and converge
## on the target from spread directions (all-range), each trailing smoke, blooming
## on impact. Hits/misses come from the payload; the flight is cosmetic (seeded rng).
func _missiles(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var count := int(payload.get("count", 10))
	var hits := int(payload.get("hits", count))
	for i in count:
		_one_missile(shooter, target, i < hits, float(i) * 0.04 + rng.randf_range(0.0, 0.05))

func _one_missile(shooter: Node3D, target: Node3D, is_hit: bool, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(shooter) or not is_instance_valid(target):
		return
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = mesh.radius * 2.0
	mesh.material = _energy_mat(Color(1.0, 0.7, 0.3), 6.0)
	m.mesh = mesh
	add_child(m)
	var start: Vector3 = shooter.muzzle_pos() + Vector3(rng.randf_range(-3, 3), rng.randf_range(3, 7), rng.randf_range(-3, 3))
	m.global_position = start
	var to: Vector3 = target.position + Vector3(0, rng.randf_range(7, 13), 0)
	if not is_hit:
		to += Vector3(rng.randf_range(-10, 10), rng.randf_range(5, 14), rng.randf_range(-10, 10)) + (to - start).normalized() * 22.0
	var apex: Vector3 = start.lerp(to, 0.45) + Vector3(rng.randf_range(-12, 12), rng.randf_range(14, 26), rng.randf_range(-12, 12))
	var seg := [-1]
	var tw := create_tween()
	tw.tween_method(_missile_step.bind(m, start, apex, to, seg), 0.0, 1.0, rng.randf_range(0.7, 1.05)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_impact_flash(m.global_position, Color(1.0, 0.6, 0.3), 1.1)
		m.queue_free())

func _missile_step(p: float, m: Node3D, a: Vector3, b: Vector3, c: Vector3, seg: Array) -> void:
	if not is_instance_valid(m):
		return
	var ab := a.lerp(b, p)
	var bc := b.lerp(c, p)
	m.global_position = ab.lerp(bc, p)
	var s := int(p * 14)
	if s != seg[0]:
		seg[0] = s
		_smoke_puff(m.global_position)

func _smoke_puff(pos: Vector3) -> void:
	var s := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.6, 0.62, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	s.mesh = mesh
	add_child(s)
	s.global_position = pos
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 2.0, 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(s.queue_free)

## Giant buster rifle: a charge-up, then a thick capital-ship-grade beam that
## tears through everything it crosses, a screen-filling impact, and a heavy
## recoil that shoves the firer backward (yield = scale).
func _buster(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var color: Color = Color(0.4, 0.8, 1.0) if shooter.actor_id == "A" else Color(1.0, 0.5, 0.3)
	var orb := MeshInstance3D.new()
	var omesh := SphereMesh.new()
	omesh.radius = 1.0
	omesh.height = 2.0
	var omat := _energy_mat(color, 14.0)
	omesh.material = omat
	orb.mesh = omesh
	orb.scale = Vector3.ONE * 0.2
	shooter.muzzle.add_child(orb)
	var ol := OmniLight3D.new()
	ol.visible = false   # omni removed: scene lit by directional + sky only
	ol.light_color = color
	ol.omni_range = 32.0
	shooter.muzzle.add_child(ol)
	var ctw := create_tween().set_parallel(true)
	ctw.tween_property(orb, "scale", Vector3.ONE * 3.2, 0.35)
	ctw.tween_property(ol, "light_energy", 11.0, 0.35)
	await get_tree().create_timer(0.35).timeout
	orb.queue_free()
	ol.queue_free()
	if not is_instance_valid(shooter) or not is_instance_valid(target):
		return
	var from: Vector3 = shooter.muzzle_pos()
	var to: Vector3 = target.position + Vector3(0, 11, 0)
	if not payload.get("hit", false):
		to += (to - from).normalized() * 40.0 + Vector3(0, 8, 0)
	to = _barrel_aim(shooter, from, to)   # fire straight down the barrel
	_draw_beam(from, to, color, 2.5)   # thick capital-ship beam (core + halo in cel)
	for bld in get_tree().get_nodes_in_group("kb_building"):
		var aabb: AABB = bld.get_meta("aabb")
		var hp: Variant = aabb.intersects_segment(from, to)
		if hp != null:
			bld.remove_from_group("kb_building")
			_detonate_building(bld, hp, from)
	_explosion(to)
	director.shake_strength = 2.5
	if shooter.has_method("knockback"):
		shooter.knockback(shooter.position - target.position, 26.0)   # capital-ship recoil
	shooter.recoil()
	if payload.get("hit", false):
		target.flinch(true)

## Blade clash: a burst of sparks + light at the contact point between the two
## suits. A block locks blades (cool sparks, push apart); a connecting cleave is
## a hot flash + hitstop. Placed at the rendered midpoint — the outcome is the log.
func _melee_clash(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var contact := shooter.position.lerp(target.position, 0.5) + Vector3(0, 11, 0)
	var blocked: bool = payload.get("blocked", false)
	var col := Color(0.7, 0.9, 1.0) if blocked else Color(1.0, 0.85, 0.6)
	_impact_flash(contact, col, 1.8)
	var flash := OmniLight3D.new()
	flash.visible = false   # omni removed: scene lit by directional + sky only
	flash.light_color = col
	flash.light_energy = 28.0
	flash.omni_range = 30.0
	add_child(flash)
	flash.global_position = contact
	create_tween().tween_property(flash, "light_energy", 0.0, 0.5)
	get_tree().create_timer(1.0).timeout.connect(func(): flash.queue_free())
	director.shake_strength = maxf(director.shake_strength, 1.4 if not blocked else 1.0)
	if payload.get("lethal", false) or float(payload.get("damage", 0)) > 25.0:
		_hitstop(0.12)

func _burst(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var rounds := int(payload.rounds)
	var hits := int(payload.hits)
	for i in rounds:
		var is_hit := i < hits
		_tracer(shooter, target, is_hit, float(i) * 0.09)

func _tracer(shooter: Node3D, target: Node3D, is_hit: bool, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(shooter) or not is_instance_valid(target):
		return
	var from: Vector3 = shooter.muzzle_pos()
	var to: Vector3 = target.position + Vector3(0, rng.randf_range(6, 13), rng.randf_range(-2, 2))
	if not is_hit:
		to += Vector3(rng.randf_range(-4, 4), rng.randf_range(2, 8), rng.randf_range(10, 20))
		to += (to - from).normalized() * rng.randf_range(15.0, 35.0)  # sail past, hit cityscape
	to = _barrel_aim(shooter, from, to)   # tracers stream out the barrel too
	var b := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.18
	mesh.height = 2.8
	mesh.material = _energy_mat(Color(1.0, 0.85, 0.4), 8.0)
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
	dm.material = _energy_mat(color, 6.0)
	p.draw_pass_1 = dm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func(): p.queue_free())

func _explosion(pos: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.visible = false   # omni removed: scene lit by directional + sky only
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
	dm.material = _energy_mat(Color(1.0, 0.45, 0.1), 5.0)
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

func _ring(pos: Vector3, color := Color(1.0, 0.8, 0.5), size := 40.0) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 8.0
	mat.albedo_color = Color(1, 1, 1, 0.8)
	mesh.material = mat
	ring.mesh = mesh
	add_child(ring)
	ring.global_position = pos
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(size, size * 0.1, size), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tw.chain().tween_callback(func(): ring.queue_free())

func _hitstop(dur := 0.07) -> void:
	if Engine.time_scale < 0.2:
		return   # already slow (bullet-time or another hitstop) — don't stack/corrupt
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	# Restore to what the current shot wants, never to a captured (possibly stale) value.
	Engine.time_scale = director.current_time_scale()
