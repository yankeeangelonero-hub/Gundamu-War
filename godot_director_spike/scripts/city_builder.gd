const Art := preload("res://scripts/art_config.gd")

## Builds the grey-box night city procedurally. Deterministic via fixed seed.

static func build(parent: Node3D, cel := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260612
	var bcol := Art.BUILDING_COLOR if cel else Color(1, 1, 1)

	var ground := MeshInstance3D.new()
	var gmesh := PlaneMesh.new()
	gmesh.size = Vector2(400, 400)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Art.GROUND_COLOR if cel else Color(1, 1, 1)
	gmat.roughness = 0.25
	gmat.metallic = 0.1
	gmesh.material = gmat
	ground.mesh = gmesh
	parent.add_child(ground)
	ground.add_to_group("kb_matte")   # no cel specular blob on the flat ground

	# Two-street grid: main street |z| < 15 along X, cross street |x| < 20
	# along Z. Mechs and cameras own both corridors; buildings fill the four
	# corner quadrants. Every building registers in "kb_building" with its
	# AABB so beams can detonate it and cameras can resolve occlusion.
	for i in range(60):
		var h := rng.randf_range(18.0, 70.0)
		var size := Vector3(rng.randf_range(10.0, 22.0), h, rng.randf_range(10.0, 22.0))
		var shade := rng.randf_range(0.06, 0.12)
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
		var b := _building(parent, Vector3(x, h * 0.5, z), size, bcol)
		if rng.randf() < 0.4:
			var win := MeshInstance3D.new()
			var wmesh := BoxMesh.new()
			wmesh.size = Vector3(size.x * 0.9, rng.randf_range(1.0, 2.5), 0.3)
			var wmat := StandardMaterial3D.new()
			if cel:
				wmat.albedo_color = Art.WINDOW_COLOR   # dark daytime glass (not glowing)
				var _consume := rng.randf()            # keep the rng sequence aligned with night
			else:
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
	_building(parent, Vector3(26, 23.0, 20.0), Vector3(12, 46, 10), bcol)
	_building(parent, Vector3(-26, 29.0, 21.0), Vector3(12, 58, 12), bcol)
	# Street-lamp omnis removed: scene is now lit by the single DirectionalLight3D
	# ("sun") + procedural-sky ambient only. Restore from git history for a night look.

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
	b.add_to_group("kb_matte")       # concrete: cel diffuse + outline, no specular sheen
	b.set_meta("aabb", AABB(pos - size * 0.5, size))
	return b

static func build_environment(parent: Node3D, anime := false, cel := false) -> Array:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if cel:
		# Daytime cel — all knobs live in art_config.gd for art direction.
		env.background_color = Art.SKY_COLOR
		env.ambient_light_color = Art.AMBIENT_COLOR
		env.ambient_light_energy = Art.AMBIENT_ENERGY
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.glow_enabled = true
		env.glow_bloom = 0.1
		env.glow_hdr_threshold = 1.1
		# Skylight: a procedural sky drives ambient fill. The visible background
		# stays the flat art-directed SKY_COLOR (BG_COLOR), but ambient is gathered
		# from this sky so the "Skylight" tune dial has something to blend toward.
		# ambient_light_sky_contribution 0 = flat AMBIENT_COLOR, 1 = full sky fill.
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Art.SKY_COLOR
		sky_mat.sky_horizon_color = Art.AMBIENT_COLOR
		sky_mat.ground_horizon_color = Art.AMBIENT_COLOR
		sky_mat.ground_bottom_color = Art.AMBIENT_COLOR
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.5
	elif anime:
		# Flat, high-key daytime so cel banding + ink outlines read clean (the
		# moody night scene posterises into mud). This is what sells the look.
		env.background_color = Color(0.55, 0.62, 0.78)   # bright sky
		env.ambient_light_color = Color(0.78, 0.8, 0.85)
		env.ambient_light_energy = 2.6
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.glow_enabled = true
		env.glow_bloom = 0.1
		env.glow_hdr_threshold = 1.2
	else:
		env.background_color = Color(0.008, 0.01, 0.02)
		env.ambient_light_color = Color(0.1, 0.12, 0.2)
		env.ambient_light_energy = 1.6
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
	if cel:
		moon.light_color = Art.SUN_COLOR
		moon.light_energy = Art.SUN_ENERGY
		moon.rotation_degrees = Art.SUN_ROTATION
	else:
		moon.light_color = Color(1.0, 0.96, 0.88) if anime else Color(0.55, 0.65, 0.9)
		moon.light_energy = 1.6 if anime else 2.2
		moon.rotation_degrees = Vector3(-50, 125, 0) if anime else Vector3(-35, 140, 0)
	moon.shadow_enabled = true
	parent.add_child(moon)
	return [env, moon]   # exposed for the live tune panel
