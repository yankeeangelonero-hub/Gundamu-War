extends Node3D
## VFX garnish. Reads outcomes from event payloads; never decides anything.

var actors: Dictionary = {}
var director: Node3D
var rng := RandomNumberGenerator.new()
var grammar: ShotGrammar = ShotGrammar.default()
var _last_kill_class := ""
const MELEE_FX_HIT_RANGE := 17.0
const MELEE_FX_CONTACT_WAIT := 1.5

func setup(p_actors: Dictionary, p_director: Node3D, p_grammar: ShotGrammar = null) -> void:
	actors = p_actors
	director = p_director
	if p_grammar != null:
		grammar = p_grammar
	rng.seed = 7
	_last_kill_class = ""
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
	if e.payload.get("lethal", false):
		_last_kill_class = str(e.kind)
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
		"fire_plasma":
			_plasma(shooter, target, e.payload)
		"fire_railgun":
			_railgun(shooter, target, e.payload)
		"fire_full_burst":
			_full_burst(shooter, target, e.payload)
		"melee":
			_melee_clash(shooter, target, e.payload)
		"destroyed":
			_staggered_blast(shooter.position + Vector3(0, 9, 0), grammar.yield_tier(_last_kill_class))
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

## A beam segment from-to: a single HDR-emissive bar that self-fades.
func _draw_beam(from: Vector3, to: Vector3, color: Color, core_w: float) -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = (from + to) * 0.5
	if not holder.global_position.is_equal_approx(to):
		holder.look_at(to, Vector3.UP)
	var length := from.distance_to(to)
	# Bright inner core...
	var em := _energy_mat(color, 17.0)
	_beam_box(holder, Vector3(core_w, core_w, length), em)
	# ...wrapped in a wider, softer glow sheath so the lance reads heavy and powerful.
	var halo := _energy_mat(color, 5.0)
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.albedo_color = Color(1, 1, 1, 0.32)
	_beam_box(holder, Vector3(core_w * 2.8, core_w * 2.8, length), halo)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(em, "emission_energy_multiplier", 0.0, 0.38)
	tw.tween_property(halo, "emission_energy_multiplier", 0.0, 0.38)
	tw.chain().tween_callback(holder.queue_free)

## Re-aim a shot so it leaves straight down the barrel (following the rifle's
## animated rotation) while keeping the original muzzle-aim distance - so a hit
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
	var mat: ShaderMaterial = (b as MeshInstance3D).mesh.material
	var tw := create_tween().set_parallel(true)
	# Topple over in the dash direction, slide, sink, and char.
	tw.tween_property(b, "position", b.position + dir * 14.0 - Vector3(0, b.position.y * 0.7, 0), 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "rotation", Vector3(dir.z * 1.4, 0, -dir.x * 1.4), 0.8)
	tw.tween_property(b, "scale:y", 0.25, 0.9)
	tw.tween_property(mat, "shader_parameter/albedo", Color(0.04, 0.035, 0.03), 0.7)
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
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = 20.0
	mech.muzzle.add_child(light)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(orb, "scale", Vector3.ONE * 1.5, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(light, "light_energy", 9.0 * grammar.fx_light_energy, 0.42)
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
	_draw_beam(from, to, color, 1.15)   # fat endgame energy lance (core + halo)
	_impact_flash(to, color, 1.8)
	_ring(to, color, 18.0)              # a shock ring sells the punch
	_beam_light(from, color, 11.0)  # muzzle flash lights the firing mech
	_beam_light(to, color, 14.0)    # impact flash lights the target / struck city
	# Beams punch through architecture: any building crossing the line dies.
	for bld in get_tree().get_nodes_in_group("kb_building"):
		var aabb: AABB = bld.get_meta("aabb")
		var hit_pt: Variant = aabb.intersects_segment(from, to)
		if hit_pt != null:
			bld.remove_from_group("kb_building")
			_detonate_building(bld, hit_pt, from)
	if payload.get("hit", false):
		_emphasize(float(payload.get("damage", 0)), grammar.hitstop_dur)
	director.shake_strength = maxf(director.shake_strength, 1.1 if payload.get("hit", false) else 0.4)

## A beam tore through this building: blast at the entry point, then the
## whole block collapses straight down into a charred slab. Visual-only -
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
	var mat: ShaderMaterial = b.mesh.material
	tw.tween_property(mat, "shader_parameter/albedo", Color(0.03, 0.025, 0.02), 0.7)

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
	ol.light_color = color
	ol.omni_range = 32.0
	shooter.muzzle.add_child(ol)
	var ctw := create_tween().set_parallel(true)
	ctw.tween_property(orb, "scale", Vector3.ONE * 3.2, 0.35)
	ctw.tween_property(ol, "light_energy", 11.0 * grammar.fx_light_energy, 0.35)
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
## a hot flash + hitstop. Placed at the rendered midpoint - the outcome is the log.
func _melee_clash(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var connected: bool = await _wait_for_melee_fx_contact(shooter, target)
	if not is_instance_valid(shooter) or not is_instance_valid(target):
		return
	if not connected:
		return
	var contact := shooter.position.lerp(target.position, 0.5) + Vector3(0, 11, 0)
	var blocked: bool = payload.get("blocked", false)
	var col := Color(0.7, 0.9, 1.0) if blocked else Color(1.0, 0.85, 0.6)
	_impact_flash(contact, col, 1.8)
	if not blocked and payload.get("hit", false):
		_melee_collision_explosion(contact)
	var flash := OmniLight3D.new()
	flash.light_color = col
	flash.light_energy = 28.0 * grammar.fx_light_energy
	flash.omni_range = 30.0
	add_child(flash)
	flash.global_position = contact
	create_tween().tween_property(flash, "light_energy", 0.0, 0.5)
	get_tree().create_timer(1.0).timeout.connect(func(): flash.queue_free())
	director.shake_strength = maxf(director.shake_strength, 1.4 if not blocked else 1.0)
	# A lethal blow may carry 0 damage in the payload; force it over the threshold so
	# the arbiter picks hitstop (the kill still reads as a heavy clash, not a flash).
	var melee_dmg := grammar.hitstop_threshold + 1.0 if payload.get("lethal", false) \
		else float(payload.get("damage", 0))
	_emphasize(melee_dmg, grammar.melee_hitstop_dur)

func _wait_for_melee_fx_contact(shooter: Node3D, target: Node3D) -> bool:
	var waited := 0.0
	while waited < MELEE_FX_CONTACT_WAIT:
		if not is_instance_valid(shooter) or not is_instance_valid(target):
			return false
		var dist := Vector2(shooter.position.x - target.position.x, shooter.position.z - target.position.z).length()
		if dist <= MELEE_FX_HIT_RANGE:
			return true
		await get_tree().create_timer(0.03).timeout
		waited += 0.03
	return is_instance_valid(shooter) and is_instance_valid(target) \
		and Vector2(shooter.position.x - target.position.x, shooter.position.z - target.position.z).length() <= MELEE_FX_HIT_RANGE

func _melee_collision_explosion(contact: Vector3) -> void:
	_fireball(contact)
	_smoke(contact)
	_ring(contact, Color(1.0, 0.72, 0.28), 30.0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.62, 0.25)
	flash.light_energy = 42.0 * grammar.fx_light_energy
	flash.omni_range = 52.0
	add_child(flash)
	flash.global_position = contact
	create_tween().tween_property(flash, "light_energy", 0.0, 0.75)
	get_tree().create_timer(1.5).timeout.connect(func(): flash.queue_free())
	director.shake_strength = maxf(director.shake_strength, 1.8)

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

## A short-lived OmniLight that flashes then fades and frees - gives an ordinary
## beam its dynamic cast on mechs and city (F24), scaled by the grammar dial.
func _beam_light(pos: Vector3, color: Color, peak: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = peak * grammar.fx_light_energy
	l.omni_range = 26.0
	add_child(l)
	l.global_position = pos
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35)
	tw.chain().tween_callback(l.queue_free)

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

## The kill blast as a SERIES scaled by the killing weapon's yield tier (F16/F17):
## tier 1 = one modest blast (today); tier 3 = a spreading 3-blast chain whose
## repeated detonations sustain the shake (the capital-tier "fear beat"). Offsets
## use the seeded rng, so the spectacle stays deterministic per seed.
func _staggered_blast(pos: Vector3, tier: int) -> void:
	for i in maxi(tier, 1):
		if i == 0:
			_explosion(pos)
		else:
			var off := Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 6.0), rng.randf_range(-8.0, 8.0)) * float(i)
			get_tree().create_timer(0.18 * float(i)).timeout.connect(func(): _explosion(pos + off))

func _explosion(pos: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.35)
	flash.light_energy = 60.0 * grammar.fx_light_energy
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
		return   # already slow (bullet-time or another hitstop) - don't stack/corrupt
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	# Restore to what the current shot wants, never to a captured (possibly stale) value.
	Engine.time_scale = director.current_time_scale()

## Route a contact beat through the time-emphasis arbiter (Phase 3 Slice 1):
## exactly one of hitstop / impact-frame fires; both are suppressed during a
## bullet-time (kill-cam) shot, so they never stack.
func _emphasize(damage: float, hitstop_dur: float) -> void:
	var in_bullet_time: bool = director.current_time_scale() < 0.2
	match TimeEmphasis.decide(in_bullet_time, damage, grammar.hitstop_threshold):
		"hitstop":
			_hitstop(hitstop_dur)
		"impact":
			_impact_frame()
		# "bullet" / "none": no transient emphasis

## Plasma cannon: a short muzzle gather, then a fat slow glowing bolt that lobs straight
## to the target and bursts in a heavy plasma splash. Reads distinct from the instant beam
## (a TRAVELLING orb, not a line) and from missiles (one heavy bolt, not a swarm). Green for
## A / magenta for B keeps it off the beam's cyan/orange palette.
func _plasma(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var color: Color = Color(0.4, 1.0, 0.45) if shooter.actor_id == "A" else Color(0.95, 0.4, 1.0)
	# Short gather at the muzzle (shorter than a buster charge).
	var orb := MeshInstance3D.new()
	var omesh := SphereMesh.new()
	omesh.radius = 0.8
	omesh.height = 1.6
	omesh.material = _energy_mat(color, 12.0)
	orb.mesh = omesh
	orb.scale = Vector3.ONE * 0.2
	shooter.muzzle.add_child(orb)
	var gl := OmniLight3D.new()
	gl.light_color = color
	gl.omni_range = 24.0
	shooter.muzzle.add_child(gl)
	var ctw := create_tween().set_parallel(true)
	ctw.tween_property(orb, "scale", Vector3.ONE * 1.6, 0.25)
	ctw.tween_property(gl, "light_energy", 8.0 * grammar.fx_light_energy, 0.25)
	await get_tree().create_timer(0.25).timeout
	orb.queue_free()
	gl.queue_free()
	if not is_instance_valid(shooter) or not is_instance_valid(target):
		return
	var from: Vector3 = shooter.muzzle_pos()
	var to: Vector3 = target.position + Vector3(0, 11, 0)
	if payload.get("blocked", false):
		to = to - (target.position - shooter.position).normalized() * 4.0
	elif not payload.get("hit", false):
		to = to + Vector3(0, 6, 20) + (to - from).normalized() * 26.0
	# The travelling bolt: a fat glowing orb, slow (the beam is instant), trailing plasma.
	var bolt := MeshInstance3D.new()
	var bmesh := SphereMesh.new()
	bmesh.radius = 1.8
	bmesh.height = 3.6
	bmesh.material = _energy_mat(color, 13.0)
	bolt.mesh = bmesh
	add_child(bolt)
	bolt.global_position = from
	var blight := OmniLight3D.new()
	blight.light_color = color
	blight.light_energy = 6.0 * grammar.fx_light_energy
	blight.omni_range = 22.0
	bolt.add_child(blight)
	var hit: bool = payload.get("hit", false)
	var dmg := float(payload.get("damage", 0))
	var seg := [-1]
	var tw := create_tween()
	tw.tween_method(_plasma_step.bind(bolt, from, to, color, seg), 0.0, 1.0, maxf(from.distance_to(to) / 95.0, 0.25))
	tw.tween_callback(func():
		_plasma_splash(to, color, hit)
		if hit:
			_emphasize(dmg, grammar.hitstop_dur)
		bolt.queue_free())

func _plasma_step(p: float, bolt: Node3D, from: Vector3, to: Vector3, color: Color, seg: Array) -> void:
	if not is_instance_valid(bolt):
		return
	bolt.global_position = from.lerp(to, p)
	var s := int(p * 16)
	if s != seg[0]:
		seg[0] = s
		_plasma_trail(bolt.global_position, color)

func _plasma_trail(pos: Vector3, color: Color) -> void:
	var s := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.7
	mesh.height = 1.4
	var mat := _energy_mat(color, 7.0)
	mesh.material = mat
	s.mesh = mesh
	add_child(s)
	s.global_position = pos
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 0.1, 0.45)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.45)
	tw.chain().tween_callback(s.queue_free)

func _plasma_splash(pos: Vector3, color: Color, hit: bool) -> void:
	_impact_flash(pos, color, 2.6)
	_ring(pos, color, 34.0)
	var fl := OmniLight3D.new()
	fl.light_color = color
	fl.light_energy = 40.0 * grammar.fx_light_energy
	fl.omni_range = 54.0
	add_child(fl)
	fl.global_position = pos
	create_tween().tween_property(fl, "light_energy", 0.0, 0.6)
	get_tree().create_timer(1.2).timeout.connect(func(): fl.queue_free())
	director.shake_strength = maxf(director.shake_strength, 1.2 if hit else 0.6)

## Railgun: an INSTANT ultra-thin white-hot kinetic line with a long lingering rail trace,
## a hard recoil kick, and a sharp piercing crack. Reads distinct from the beam (far thinner,
## kinetic white-blue, a slower-fading trace + real recoil). Punches through architecture.
func _railgun(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var color: Color = Color(0.75, 0.88, 1.0) if shooter.actor_id == "A" else Color(1.0, 0.86, 0.7)
	var from: Vector3 = shooter.muzzle_pos()
	var to: Vector3 = target.position + Vector3(0, 11, 0)
	if payload.get("blocked", false):
		to = to - (target.position - shooter.position).normalized() * 4.0
	elif not payload.get("hit", false):
		to = to + Vector3(0, 5, 18) + (to - from).normalized() * 34.0
	to = _barrel_aim(shooter, from, to)
	# Thin lingering rail trace + a brighter white-hot inner core.
	_draw_rail(from, to, color, 0.28, 0.6)
	_draw_rail(from, to, Color(1, 1, 1), 0.1, 0.36)
	_beam_light(from, color, 13.0)
	_impact_flash(to, color, 1.2)
	_impact_flash(to, Color(1, 1, 1), 0.7)
	_ring(to, color, 22.0)
	# Kinetic penetrator: any building on the line dies (deterministic, like a beam).
	for bld in get_tree().get_nodes_in_group("kb_building"):
		var aabb: AABB = bld.get_meta("aabb")
		var hp: Variant = aabb.intersects_segment(from, to)
		if hp != null:
			bld.remove_from_group("kb_building")
			_detonate_building(bld, hp, from)
	# Hard recoil kick (kinetic, snappier than a buster's capital shove).
	if shooter.has_method("knockback"):
		shooter.knockback(shooter.position - target.position, 16.0)
	shooter.recoil()
	if payload.get("hit", false):
		_emphasize(float(payload.get("damage", 0)), grammar.hitstop_dur)
	director.shake_strength = maxf(director.shake_strength, 1.6 if payload.get("hit", false) else 0.9)

## FULL BURST: the gunner plants and unleashes everything at once — railgun lines from the
## four shoulder mounts + plasma bolts from the four waist mounts + the main rifle beam, all
## converging on the target in one wall of fire. The signature alpha-strike spectacle.
func _full_burst(shooter: Node3D, target: Node3D, payload: Dictionary) -> void:
	var hit: bool = payload.get("hit", false)
	var lethal: bool = payload.get("lethal", false)
	var to_base: Vector3 = target.position + Vector3(0, 11, 0)
	shooter.recoil()
	# A bloom of light over the firer as the whole rack lights up.
	var rail_color: Color = Color(0.75, 0.88, 1.0) if shooter.actor_id == "A" else Color(1.0, 0.86, 0.7)
	var pl_color: Color = Color(0.4, 1.0, 0.45) if shooter.actor_id == "A" else Color(0.95, 0.4, 1.0)
	_beam_light(shooter.position + Vector3(0, 10, 0), rail_color, 13.0)
	# Railgun fan from the shoulders — instant kinetic lines, slight spread.
	if shooter.has_method("railgun_mounts"):
		for mp in shooter.railgun_mounts():
			var to: Vector3 = to_base + Vector3(rng.randf_range(-5, 5), rng.randf_range(-4, 6), rng.randf_range(-3, 3))
			_draw_rail(mp, to, rail_color, 0.14, 0.5)
			_draw_rail(mp, to, Color(1, 1, 1), 0.05, 0.3)
			_impact_flash(to, rail_color, 0.5)
	# Plasma bolts from the waist — slow heavy orbs, staggered a hair so they read as a salvo.
	if shooter.has_method("plasma_mounts"):
		var i := 0
		for mp in shooter.plasma_mounts():
			_full_burst_bolt(mp, to_base + Vector3(rng.randf_range(-6, 6), rng.randf_range(-3, 7), rng.randf_range(-3, 3)), pl_color, float(i) * 0.04)
			i += 1
	# The main rifle beam straight down the centre of the fan.
	var beam_col: Color = Color(0.3, 0.9, 1.0) if shooter.actor_id == "A" else Color(1.0, 0.4, 0.2)
	_draw_beam(shooter.muzzle_pos(), to_base, beam_col, 1.4)
	_impact_flash(to_base, beam_col, 1.9)
	_ring(to_base, pl_color, 34.0)
	if lethal or hit:
		_explosion(to_base)
	director.shake_strength = 2.5
	if hit:
		_emphasize(grammar.hitstop_threshold + 1.0, grammar.hitstop_dur)

## One plasma bolt of a full-burst salvo: travels from a body mount to the aim point, bursts.
func _full_burst_bolt(from: Vector3, to: Vector3, color: Color, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var bolt := MeshInstance3D.new()
	var bmesh := SphereMesh.new()
	bmesh.radius = 1.0
	bmesh.height = 2.0
	bmesh.material = _energy_mat(color, 11.0)
	bolt.mesh = bmesh
	add_child(bolt)
	bolt.global_position = from
	var seg := [-1]
	var tw := create_tween()
	tw.tween_method(_plasma_step.bind(bolt, from, to, color, seg), 0.0, 1.0, maxf(from.distance_to(to) / 120.0, 0.2))
	tw.tween_callback(func():
		_plasma_splash(to, color, true)
		bolt.queue_free())

func _draw_rail(from: Vector3, to: Vector3, color: Color, core_w: float, fade: float) -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = (from + to) * 0.5
	if not holder.global_position.is_equal_approx(to):
		holder.look_at(to, Vector3.UP)
	var em := _energy_mat(color, 22.0)
	_beam_box(holder, Vector3(core_w, core_w, from.distance_to(to)), em)
	var tw := create_tween()
	tw.tween_property(em, "emission_energy_multiplier", 0.0, fade)
	tw.chain().tween_callback(holder.queue_free)

## A sub-perceptual screen flash on a minor contact (F37, impact-frame). Subtle by
## default (grammar.impact_frame_strength ~0.15), lasting impact_frame_len frames.
## The arbiter guarantees this never fires during a hitstop or bullet-time, so it
## never stacks on a freeze/slow-mo.
func _impact_frame() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(1.0, 1.0, 1.0, grammar.impact_frame_strength)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, float(grammar.impact_frame_len) / 60.0)
	tw.chain().tween_callback(layer.queue_free)
