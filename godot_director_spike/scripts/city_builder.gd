## Builds the grey-box night city procedurally. Deterministic via fixed seed.

static func build(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260612

	var ground := MeshInstance3D.new()
	var gmesh := PlaneMesh.new()
	gmesh.size = Vector2(400, 400)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.05, 0.055, 0.07)
	gmat.roughness = 0.25
	gmat.metallic = 0.1
	gmesh.material = gmat
	ground.mesh = gmesh
	parent.add_child(ground)

	# Buildings flanking a street that runs along X. Street half-width 14.
	for i in range(60):
		var b := MeshInstance3D.new()
		var box := BoxMesh.new()
		var h := rng.randf_range(18.0, 70.0)
		box.size = Vector3(rng.randf_range(10.0, 22.0), h, rng.randf_range(10.0, 22.0))
		var mat := StandardMaterial3D.new()
		var shade := rng.randf_range(0.06, 0.12)
		mat.albedo_color = Color(shade, shade, shade * 1.15)
		mat.roughness = 0.7
		box.material = mat
		b.mesh = box
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		b.position = Vector3(rng.randf_range(-90.0, 90.0), h * 0.5,
			side * rng.randf_range(16.0, 60.0))
		parent.add_child(b)
		if rng.randf() < 0.4:
			var win := MeshInstance3D.new()
			var wmesh := BoxMesh.new()
			wmesh.size = Vector3(box.size.x * 0.9, rng.randf_range(1.0, 2.5), 0.3)
			var wmat := StandardMaterial3D.new()
			wmat.emission_enabled = true
			wmat.emission = Color(0.9, 0.6, 0.25) if rng.randf() < 0.5 else Color(0.4, 0.7, 0.9)
			wmat.emission_energy_multiplier = 5.0
			wmesh.material = wmat
			win.mesh = wmesh
			win.position = b.position + Vector3(0, rng.randf_range(-h * 0.3, h * 0.3),
				-signf(b.position.z) * (box.size.z * 0.5 + 0.2))
			parent.add_child(win)

	for x in range(-80, 81, 20):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.75, 0.45)
		lamp.light_energy = 15.0
		lamp.omni_range = 35.0
		lamp.position = Vector3(x, 9.0, 12.0 * (1 if (x / 20) % 2 == 0 else -1))
		parent.add_child(lamp)

static func build_environment(parent: Node3D) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.2)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 0.9
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = Color(0.6, 0.65, 0.8)
	env.sdfgi_enabled = true
	we.environment = env
	parent.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 1.5
	moon.rotation_degrees = Vector3(-35, 140, 0)
	moon.shadow_enabled = true
	parent.add_child(moon)
