extends Node3D

const CityBuilder := preload("res://scripts/city_builder.gd")
const MechActor := preload("res://scripts/mech_actor.gd")
const FightLog := preload("res://scripts/fight_log.gd")
const Garnish := preload("res://scripts/garnish.gd")
const SpikeAudio := preload("res://scripts/spike_audio.gd")
const Art := preload("res://scripts/art_config.gd")
const PauseController := preload("res://scripts/pause_controller.gd")

var camera: Camera3D
var mech_a: Node3D
var mech_b: Node3D
var director: Node3D
var _fps_samples: Array[float] = []
var _fade: ColorRect
var _cel_shader: Shader
var _cel_ramp: GradientTexture1D
var _outline_mat: ShaderMaterial
var _cel_materials: Array[ShaderMaterial] = []
var _pbr_materials: Array[StandardMaterial3D] = []   # gundam surface overrides, for the PBR tune panel
var _crane_a := Vector3.ZERO        # --hero crane: start camera pose
var _crane_b := Vector3.ZERO        # --hero crane: end camera pose
var _crane_look := Vector3(0, 10, 0)   # --hero crane: aim point (mech mid-height) — keeps full body framed
var _cel_post_mat: ShaderMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _tune := false
var _tune_layer: CanvasLayer
var _paused_layer: CanvasLayer

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if Engine.get_process_frames() % 30 == 0:
		_fps_samples.append(Performance.get_monitor(Performance.TIME_FPS))

## --frames: dump a PNG every 1.5 game-seconds for offline shot review.
func _capture_frames(director_name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var idx := 0
	while director != null and director.playing:
		await get_tree().create_timer(1.5).timeout
		var img := get_viewport().get_texture().get_image()
		img.resize(640, 360)
		img.save_png("res://tmp/frame_%s_%02d.png" % [director_name, idx])
		idx += 1

## Per-material cel pass (eldskald-style): swap every static mesh's material for
## the cel shader (copying albedo/emission) with an inverted-hull outline next_pass.
func _apply_cel(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			_celify(child)
		_apply_cel(child)

func _celify(mi: MeshInstance3D) -> void:
	var col := Color(0.6, 0.6, 0.66)
	var emis := Color(0, 0, 0)
	var ee := 0.0
	var albedo_tex: Texture2D = null
	var src := mi.get_active_material(0)
	if src is StandardMaterial3D:
		var sm := src as StandardMaterial3D
		col = sm.albedo_color
		albedo_tex = sm.albedo_texture   # textured meshes (Gundam) — sampled by the cel shader
		if sm.emission_enabled:
			emis = sm.emission
			ee = sm.emission_energy_multiplier
	var spec := Art.SPECULAR_COLOR
	spec.a = Art.SPECULAR_STRENGTH
	var fres := Art.FRESNEL_COLOR
	fres.a = Art.FRESNEL_STRENGTH
	if mi.is_in_group("kb_matte"):
		spec.a = 0.0   # concrete/ground is matte — no glossy highlight blob
		fres.a = 0.0
	var m := ShaderMaterial.new()
	m.shader = _cel_shader
	m.set_shader_parameter("color", col)
	if albedo_tex != null:
		m.set_shader_parameter("albedo_tex", albedo_tex)
		m.set_shader_parameter("use_albedo_tex", true)
		m.set_shader_parameter("albedo_tex_strength", Art.ALBEDO_TEX_STRENGTH)
	m.set_shader_parameter("diffuse_curve", _cel_ramp)
	m.set_shader_parameter("emission", Vector3(emis.r, emis.g, emis.b))
	m.set_shader_parameter("emission_energy", ee)
	m.set_shader_parameter("specular", spec)
	m.set_shader_parameter("specular_smoothness", Art.SPECULAR_SMOOTHNESS)
	m.set_shader_parameter("fresnel", fres)
	m.set_shader_parameter("fresnel_smoothness", Art.FRESNEL_SMOOTHNESS)
	m.next_pass = _outline_mat
	mi.material_override = m
	_cel_materials.append(m)   # tracked so the live tune panel can update them all

## Hard-banded grayscale ramp for the cel diffuse (sampled by N·L). Constant
## interpolation = crisp 3-tone bands (shadow / mid / lit).
func _make_cel_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, Art.BAND_SHADOW_THRESHOLD, Art.BAND_MID_THRESHOLD])
	g.colors = PackedColorArray([Art.BAND_SHADOW, Art.BAND_MID, Art.BAND_LIT])
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t

## --tune: an in-game panel of live sliders for the cel/lighting knobs. Drag while
## the fight plays; F1 toggles the panel. (Defaults come from art_config.gd.)
func _build_tune_panel() -> void:
	_tune_layer = CanvasLayer.new()
	_tune_layer.layer = 5
	# ALWAYS so the sliders stay draggable while the fight is paused (tune on a
	# frozen frame). Leaf UI subtree, so this does not unpause the gameplay nodes.
	_tune_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tune_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	_tune_layer.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "ART TUNE — F1 hide · R restart"
	vbox.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "⟳ Restart fight"
	restart_btn.pressed.connect(_restart)
	vbox.add_child(restart_btn)
	_slider(vbox, "Ambient energy", 0.0, 3.0, _env.ambient_light_energy, 0.01,
		func(v): _env.ambient_light_energy = v)
	_slider(vbox, "Sun energy", 0.0, 4.0, _sun.light_energy, 0.01,
		func(v): _sun.light_energy = v)
	_slider(vbox, "Skylight (sky fill)", 0.0, 1.0, _env.ambient_light_sky_contribution, 0.01,
		func(v): _env.ambient_light_sky_contribution = v)
	_slider(vbox, "Band shadow level", 0.0, 1.5, 1.0, 0.01,
		func(v): _cel_ramp.gradient.set_color(0, Art.BAND_SHADOW * v))   # scales the tinted shadow
	_slider(vbox, "Band mid level", 0.0, 1.5, 1.0, 0.01,
		func(v): _cel_ramp.gradient.set_color(1, Art.BAND_MID * v))
	_slider(vbox, "Shadow threshold", 0.05, 0.95, Art.BAND_SHADOW_THRESHOLD, 0.01,
		func(v): _cel_ramp.gradient.set_offset(1, v))
	_slider(vbox, "Mid threshold", 0.05, 0.99, Art.BAND_MID_THRESHOLD, 0.01,
		func(v): _cel_ramp.gradient.set_offset(2, v))
	_slider(vbox, "Albedo tex strength", 0.0, 1.0, Art.ALBEDO_TEX_STRENGTH, 0.01,
		func(v): _set_cel_param("albedo_tex_strength", v))   # fade baked wear/grime toward clean
	_slider(vbox, "Specular strength", 0.0, 1.0, Art.SPECULAR_STRENGTH, 0.01, _set_spec_strength)
	_slider(vbox, "Specular smooth", 0.0, 0.5, Art.SPECULAR_SMOOTHNESS, 0.005,
		func(v): _set_cel_param("specular_smoothness", v))
	_slider(vbox, "Fresnel strength", 0.0, 1.0, Art.FRESNEL_STRENGTH, 0.01, _set_fresnel_strength)
	_slider(vbox, "Fresnel smooth", 0.0, 0.5, Art.FRESNEL_SMOOTHNESS, 0.005,
		func(v): _set_cel_param("fresnel_smoothness", v))
	_slider(vbox, "Outline width", 0.0, 10.0, Art.OUTLINE_WIDTH, 0.1,
		func(v): _outline_mat.set_shader_parameter("outline_width", v))
	_slider(vbox, "Line thickness", 0.3, 3.0, Art.LINE_THICKNESS, 0.05,
		func(v): _cel_post_mat.set_shader_parameter("thickness", v))
	_slider(vbox, "Interior lines (lo=more)", 0.15, 1.5, Art.INTERIOR_EDGE, 0.01,
		func(v): _cel_post_mat.set_shader_parameter("interior_edge", v))
	_slider(vbox, "Occlusion lines (lo=more)", 0.005, 0.15, Art.OCCLUSION_EDGE, 0.002,
		func(v): _cel_post_mat.set_shader_parameter("occlusion_edge", v))

func _slider(vbox: VBoxContainer, text: String, lo: float, hi: float, val: float,
		step: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(140, 0)
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(180, 0)
	row.add_child(s)
	var vlbl := Label.new()
	vlbl.text = "%.2f" % val
	vlbl.custom_minimum_size = Vector2(48, 0)
	row.add_child(vlbl)
	s.value_changed.connect(func(v):
		vlbl.text = "%.2f" % v
		cb.call(v))
	vbox.add_child(row)

func _set_cel_param(param: String, value: Variant) -> void:
	for mat in _cel_materials:
		mat.set_shader_parameter(param, value)

func _set_spec_strength(v: float) -> void:
	var c := Art.SPECULAR_COLOR
	c.a = v
	_set_cel_param("specular", c)

func _set_fresnel_strength(v: float) -> void:
	var c := Art.FRESNEL_COLOR
	c.a = v
	_set_cel_param("fresnel", c)

## Restart the fight from the top (same flags) — reloads the scene fresh.
## Note: resets the look to art_config.gd defaults (slider tweaks are not kept).
func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if _tune_layer and event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			_tune_layer.visible = not _tune_layer.visible
		elif event.keycode == KEY_R:
			_restart()

## Screen-space ink pass for cel mode (interior creases + occlusion edges).
## Complements the per-material inverted-hull silhouette outline.
func _add_cel_outline_post() -> void:
	_cel_post_mat = ShaderMaterial.new()
	_cel_post_mat.shader = load("res://shaders/cel_post_outline.gdshader")
	_cel_post_mat.render_priority = 2   # draw the ink overlay last, over the FX
	_cel_post_mat.set_shader_parameter("thickness", Art.LINE_THICKNESS)
	_cel_post_mat.set_shader_parameter("interior_edge", Art.INTERIOR_EDGE)
	_cel_post_mat.set_shader_parameter("occlusion_edge", Art.OCCLUSION_EDGE)
	_cel_post_mat.set_shader_parameter("ink", Art.OUTLINE_COLOR)
	_cel_post_mat.set_shader_parameter("ink_strength", Art.LINE_STRENGTH)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	qm.flip_faces = true
	quad.mesh = qm
	quad.material_override = _cel_post_mat
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(quad)

## Fullscreen cel/ink post pass on a camera-child quad (Godot post-process pattern).
func _add_anime_post() -> void:
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	qm.flip_faces = true
	quad.mesh = qm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/anime_post.gdshader")
	quad.material_override = mat
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(quad)

## Build the cel pipeline and apply it to every static mesh in the scene.
func _init_cel() -> void:
	_cel_shader = load("res://shaders/cel.gdshader")
	_cel_ramp = _make_cel_ramp()
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = load("res://shaders/cel_outline.gdshader")
	_outline_mat.set_shader_parameter("outline_color", Art.OUTLINE_COLOR)
	_outline_mat.set_shader_parameter("outline_width", Art.OUTLINE_WIDTH)
	_apply_cel(self)
	_add_cel_outline_post()   # interior + occlusion ink lines (screen-space)
	if _tune:
		_build_tune_panel()

## --hero crane callback: interpolate the camera pose and re-aim at mid-height so
## the full body stays framed throughout (called by a looping tween_method).
func _crane(t: float) -> void:
	camera.position = _crane_a.lerp(_crane_b, t)
	camera.look_at(_crane_look, Vector3.UP)

## --hero dressing: human-scale reference figures at the feet, a low golden sun
## that throws a long shadow toward camera, and depth haze. Together these read the
## mech as a towering, imposing giant rather than a model on a turntable.
func _setup_hero_scene() -> void:
	_add_scale_figure(Vector3(4.5, 0.0, 11.0))    # foreground figures give the eye a
	_add_scale_figure(Vector3(-3.5, 0.0, 8.0))    # known ~1.8 m yardstick for scale
	_add_scale_figure(Vector3(1.5, 0.0, 14.0))
	if _sun:
		_sun.rotation_degrees = Vector3(-12, 200, 0)   # low sun → long raking shadow
		_sun.light_color = Color(1.0, 0.86, 0.66)      # warm golden hour
		_sun.light_energy = 1.7
		_sun.shadow_enabled = true
		_sun.directional_shadow_max_distance = 240.0   # reach far enough for the long shadow
	if _env:
		_env.fog_enabled = true
		_env.fog_light_color = Color(0.80, 0.85, 0.95)
		_env.fog_density = 0.0035        # subtle aerial haze (depth without washing the mech)
		_env.fog_aerial_perspective = 0.5
		_env.fog_sky_affect = 0.6

## A placeholder 1.8 m human figure (capsule) standing on the ground for scale.
func _add_scale_figure(pos: Vector3) -> void:
	var fig := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.8   # total height incl. caps — a person-sized yardstick
	fig.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.18, 0.22)   # dark so it reads against the bright ground
	mat.roughness = 0.9
	fig.material_override = mat
	fig.position = pos + Vector3(0, 0.9, 0)   # capsule centre at half-height → feet on ground
	add_child(fig)

## PBR tune panel (realistic lighting): sun/ambient + the surface roughness/metallic
## that drive the matte-vs-plastic read. Shown for --gundam --tune without --cel.
func _build_pbr_tune_panel() -> void:
	_tune_layer = CanvasLayer.new()
	_tune_layer.layer = 5
	_tune_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tune_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	_tune_layer.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "PBR TUNE (realistic) — F1 hide"
	vbox.add_child(title)
	_slider(vbox, "Ambient energy", 0.0, 3.0, _env.ambient_light_energy, 0.01,
		func(v): _env.ambient_light_energy = v)
	_slider(vbox, "Sun energy", 0.0, 4.0, _sun.light_energy, 0.01,
		func(v): _sun.light_energy = v)
	_slider(vbox, "Skylight (sky fill)", 0.0, 1.0, _env.ambient_light_sky_contribution, 0.01,
		func(v): _env.ambient_light_sky_contribution = v)
	var rough0 := _pbr_materials[0].roughness if not _pbr_materials.is_empty() else 0.8
	var metal0 := _pbr_materials[0].metallic if not _pbr_materials.is_empty() else 0.0
	_slider(vbox, "Roughness (all)", 0.0, 1.0, rough0, 0.01, _set_pbr_roughness)
	_slider(vbox, "Metallic (all)", 0.0, 1.0, metal0, 0.01, _set_pbr_metallic)

func _set_pbr_roughness(v: float) -> void:
	for m in _pbr_materials:
		m.roughness = v

func _set_pbr_metallic(v: float) -> void:
	for m in _pbr_materials:
		m.metallic = v

## --gundam: drop the real textured Gundam mesh in (static, bind pose) on a slow
## turntable under the daytime lighting, so cel vs PBR can be judged on a textured
## model instead of grey block-out. Skips the mechs/director/garnish entirely.
func _show_gundam(cel: bool, anime: bool) -> void:
	var packed := load("res://models/gundam_mk2.glb") as PackedScene
	if packed == null:
		push_error("--gundam: res://models/gundam_mk2.glb not found (run --import first)")
		get_tree().quit(1); return
	var pivot := Node3D.new()
	add_child(pivot)
	var inst := packed.instantiate()
	pivot.add_child(inst)
	# Auto-fit: scale to ~20u (the Gundam Mk-II is ~18–20 m) so 1u ≈ 1 m for the
	# pedestrian scale shot; sit feet on the ground, centred over the pivot.
	var box := _world_aabb(inst)
	var s := 20.0 / maxf(box.size.y, 0.001)
	inst.scale = Vector3(s, s, s)
	var mn := box.position * s
	var sz := box.size * s
	inst.position = Vector3(-(mn.x + sz.x * 0.5), -mn.y, -(mn.z + sz.z * 0.5))
	_set_roughness(inst, 0.8)   # glb ships glossy (~0.1) — knock back the plastic sheen (PBR only)
	var ped := "--ped" in OS.get_cmdline_user_args()
	var hero := "--hero" in OS.get_cmdline_user_args()
	if hero:
		_setup_hero_scene()   # scale-reference figures + low golden sun + depth haze
	camera = Camera3D.new()
	camera.attributes = CameraAttributesPractical.new()
	add_child(camera)
	if hero:
		# Slow crane: low-and-far → craned-up, kept far enough that the whole 20 m
		# body stays in frame the entire move (no crop). Aim held at mid-height.
		camera.fov = 50
		_crane_a = Vector3(7.0, 2.0, 50.0)
		_crane_b = Vector3(2.0, 15.0, 44.0)
		_crane(0.0)
	elif ped:
		# Pedestrian worm's-eye: human eye-height (1.7 m) close to the feet, wide
		# lens, tilted up — near legs loom, head recedes, selling ~20 m of scale.
		camera.fov = 70
		camera.position = Vector3(6.0, 1.7, 16.0)
		camera.look_at(Vector3(0, 12.0, 0), Vector3.UP)
	else:
		camera.fov = 45
		camera.position = Vector3(0, 12, 44)
		camera.look_at(Vector3(0, 10, 0), Vector3.UP)
	if anime:
		_add_anime_post()
	if cel:
		_init_cel()
	elif _tune:
		_build_pbr_tune_panel()   # realistic-lighting knobs (no cel)
	if hero:
		# Ease up, ease back down, forever — a slow, heavy cinematic drift.
		var crane := create_tween().set_loops()
		crane.tween_method(_crane, 0.0, 1.0, 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		crane.tween_method(_crane, 1.0, 0.0, 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif not ped:
		# Slow turntable so every side is visible for the look review.
		var spin := create_tween().set_loops()
		spin.tween_property(pivot, "rotation:y", TAU, 16.0).from_current()
	var mode := " — hero" if hero else (" — pedestrian" if ped else "")
	print("KM-DIRECTOR-SPIKE boot ok (gundam viewer%s)" % mode)

## Override every surface material under a node to a fixed roughness (per-surface
## override, so the cached imported material resource is left untouched).
func _set_roughness(root: Node, r: float) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var count := mi.mesh.get_surface_count() if mi.mesh else 0
			for i in count:
				var src := mi.get_active_material(i)
				if src is StandardMaterial3D:
					var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
					m.roughness = r
					mi.set_surface_override_material(i, m)
					_pbr_materials.append(m)   # tracked so the PBR tune panel can update them all
		for c in n.get_children():
			stack.append(c)

## Merged world-space AABB of every VisualInstance3D under (and including) a node.
func _world_aabb(root: Node) -> AABB:
	var acc := AABB()
	var started := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VisualInstance3D:
			var vi := n as VisualInstance3D
			var b: AABB = vi.global_transform * vi.get_aabb()
			if started:
				acc = acc.merge(b)
			else:
				acc = b; started = true
		for c in n.get_children():
			stack.append(c)
	return acc

func _ready() -> void:
	var director_name := "cinematic"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--director="):
			director_name = arg.trim_prefix("--director=")
	var director_path := "res://scripts/directors/%s.gd" % director_name
	if not ResourceLoader.exists(director_path):
		push_error("Unknown director variant '%s': %s does not exist" % [director_name, director_path])
		get_tree().quit(1)
		return
	var DirectorScript: GDScript = load(director_path)
	var anime := "--anime" in OS.get_cmdline_user_args()
	var cel := "--cel" in OS.get_cmdline_user_args()
	_tune = "--tune" in OS.get_cmdline_user_args()
	var env_refs := CityBuilder.build_environment(self, anime, cel)
	_env = env_refs[0]
	_sun = env_refs[1]
	CityBuilder.build(self, cel)
	if "--gundam" in OS.get_cmdline_user_args():
		_show_gundam(cel, anime)   # static textured-mesh look test; skips the fight sim
		return
	var full_armor := "--armor" in OS.get_cmdline_user_args()
	var rig := "--mesh" in OS.get_cmdline_user_args()
	mech_a = MechActor.new()
	mech_a.setup("A", Color(0.30, 0.45, 0.75), -40.0, full_armor, rig)
	add_child(mech_a)
	mech_b = MechActor.new()
	mech_b.setup("B", Color(0.70, 0.30, 0.25), 40.0, full_armor, rig)
	add_child(mech_b)
	camera = Camera3D.new()
	camera.position = Vector3(0, 45, 90)
	camera.fov = 55
	camera.attributes = CameraAttributesPractical.new()
	add_child(camera)
	camera.look_at(Vector3(0, 10, 0), Vector3.UP)
	if anime:
		_add_anime_post()
	if cel:
		_init_cel()   # scene meshes are built by now; runtime FX stay emissive
	print("KM-DIRECTOR-SPIKE boot ok")
	if "--still" in OS.get_cmdline_user_args():
		# Behind mech A (x=-55), looking toward B (x=+40) — sees both mechs + city flanks
		camera.position = Vector3(-55, 22, 8)
		camera.fov = 72
		camera.look_at(Vector3(20, 8, 0), Vector3.UP)
		await get_tree().create_timer(2.0).timeout
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("res://tmp")
		img.save_png("res://tmp/still_%s.png" % director_name)
		print("still saved: tmp/still_%s.png" % director_name)
		get_tree().quit()
		return
	# Cinema letterbox: black bars squeeze the 16:9 viewport toward 2.39:1.
	var bars := CanvasLayer.new()
	bars.layer = 2
	add_child(bars)
	var top_bar := ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.105
	bars.add_child(top_bar)
	var bot_bar := ColorRect.new()
	bot_bar.color = Color.BLACK
	bot_bar.anchor_top = 0.895
	bot_bar.anchor_right = 1.0
	bot_bar.anchor_bottom = 1.0
	bars.add_child(bot_bar)
	# Pause overlay (Space / P). Process-always so it can toggle while paused.
	_paused_layer = CanvasLayer.new()
	_paused_layer.layer = 6
	_paused_layer.visible = false
	_paused_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_paused_layer)
	var paused_label := Label.new()
	paused_label.text = "❚❚ PAUSED"
	paused_label.add_theme_font_size_override("font_size", 28)
	paused_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	paused_label.position = Vector2(-70, 64)
	_paused_layer.add_child(paused_label)
	# Dedicated ALWAYS-process input node so Space/P can toggle (and un-toggle)
	# the tree pause. It has no children, so its ALWAYS mode does not leak into
	# the gameplay nodes the way setting the scene root to ALWAYS would.
	var pause_ctl := PauseController.new()
	pause_ctl.overlay = _paused_layer
	add_child(pause_ctl)
	var layer := CanvasLayer.new()
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	var log_path := "res://data/fight_log.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--log="):
			log_path = "res://data/%s.json" % arg.trim_prefix("--log=")
	var events := FightLog.load_events(log_path)
	var dur := FightLog.duration_sec(events)
	var shots: Array = DirectorScript.build_shot_list(events, dur)
	director = DirectorScript.new()
	add_child(director)
	director.start(events, shots, camera, {"A": mech_a, "B": mech_b}, dur)
	var garnish := Garnish.new()
	add_child(garnish)
	garnish.setup({"A": mech_a, "B": mech_b}, director, cel)
	var audio := SpikeAudio.new()
	add_child(audio)
	audio.wire(director)
	if "--frames" in OS.get_cmdline_user_args():
		_capture_frames(director_name)
	director.fight_over.connect(func():
		if _tune:
			return   # stay up on the final frame so the look can keep being tuned
		create_tween().tween_property(_fade, "color:a", 1.0, 2.0)
		await get_tree().create_timer(2.2).timeout
		_fps_samples.sort()
		if _fps_samples.size() > 2:
			print("FPS min=%d  p5=%d  avg=%d" % [int(_fps_samples[0]),
				int(_fps_samples[_fps_samples.size() / 20]),
				int(_fps_samples.reduce(func(a, b): return a + b) / _fps_samples.size())])
		get_tree().quit())
