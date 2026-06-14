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
	var src := mi.get_active_material(0)
	if src is StandardMaterial3D:
		var sm := src as StandardMaterial3D
		col = sm.albedo_color
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
		_cel_shader = load("res://shaders/cel.gdshader")
		_cel_ramp = _make_cel_ramp()
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/cel_outline.gdshader")
		_outline_mat.set_shader_parameter("outline_color", Art.OUTLINE_COLOR)
		_outline_mat.set_shader_parameter("outline_width", Art.OUTLINE_WIDTH)
		_apply_cel(self)   # mechs + city are built by now; runtime FX stay emissive
		_add_cel_outline_post()   # interior + occlusion ink lines (screen-space)
		if _tune:
			_build_tune_panel()
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
