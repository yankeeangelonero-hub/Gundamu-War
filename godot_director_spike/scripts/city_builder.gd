## Builds the grey-box night city procedurally. Deterministic via fixed seed.

static func build(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260612

	var ground := MeshInstance3D.new()
	var gmesh := PlaneMesh.new()
	gmesh.size = Vector2(400, 400)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1, 1, 1)
	gmat.roughness = 0.25
	gmat.metallic = 0.1
	gmesh.material = gmat
	ground.mesh = gmesh
	parent.add_child(ground)
	ground.add_to_group("kb_matte")

	# Two-street grid: main street |z| < 15 along X, cross street |x| < 20
	# along Z. Mechs and cameras own both corridors; buildings fill the four
	# corner quadrants. Every building registers in "kb_building" with its
	# AABB so beams can detonate it and cameras can resolve occlusion.
	for i in range(60):
		var h := rng.randf_range(18.0, 70.0)
		var size := Vector3(rng.randf_range(10.0, 22.0), h, rng.randf_range(10.0, 22.0))
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var x := rng.randf_range(-90.0, 90.0)
		var min_x := 20.0 + size.x * 0.5
		if absf(x) < min_x:
			x = (signf(x) if x != 0.0 else 1.0) * min_x
		var z := side * (15.0 + size.z * 0.5 + rng.randf_range(0.0, 40.0))
		# Plaza setback: keep a clear apron around the intersection (the staging
		# area) so the fight has open negative space to be framed against.
		if Vector2(x, z).length() < 42.0:
			x += signf(x) * 24.0
			z += signf(z) * 24.0
		var b := _building(parent, Vector3(x, h * 0.5, z), size, Color(1, 1, 1))
		if rng.randf() < 0.4:
			var win := MeshInstance3D.new()
			var wmesh := BoxMesh.new()
			wmesh.size = Vector3(size.x * 0.9, rng.randf_range(1.0, 2.5), 0.3)
			var wmat := StandardMaterial3D.new()
			wmat.emission_enabled = true
			wmat.emission = Color(0.9, 0.6, 0.25) if rng.randf() < 0.5 else Color(0.4, 0.7, 0.9)
			wmat.emission_energy_multiplier = 5.0
			wmesh.material = wmat
			win.mesh = wmesh
			# child of the building: collapses (scales) with it when destroyed
			win.position = Vector3(0, rng.randf_range(-h * 0.3, h * 0.3),
				-signf(z) * (size.z * 0.5 + 0.2))
			win.add_to_group("kb_matte")
			b.add_child(win)

	# Gate towers on the cross-street corners — the choreographed hero
	# diagonals (tick 100/120 and the lethal 230) fire straight through these.
	_building(parent, Vector3(26, 23.0, 20.0), Vector3(12, 46, 10), Color(1, 1, 1))
	_building(parent, Vector3(-26, 29.0, 21.0), Vector3(12, 58, 12), Color(1, 1, 1))

static func _building(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var b := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.7
	box.material = mat
	b.mesh = box
	b.position = pos
	parent.add_child(b)
	b.add_to_group("kb_building")
	b.add_to_group("kb_near_cull")   # hidden when it sits between a close-up lens and the action
	b.add_to_group("kb_matte")
	b.set_meta("aabb", AABB(pos - size * 0.5, size))
	return b

static func build_environment(parent: Node3D) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.02)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 0.9
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.6, 0.65, 0.8)
	env.sdfgi_enabled = true
	we.environment = env
	parent.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 2.2
	moon.rotation_degrees = Vector3(-35, 140, 0)
	moon.shadow_enabled = true
	parent.add_child(moon)
	return we
