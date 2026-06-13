extends Node3D

const CityBuilder := preload("res://scripts/city_builder.gd")
const MechActor := preload("res://scripts/mech_actor.gd")
const FightLog := preload("res://scripts/fight_log.gd")
const Garnish := preload("res://scripts/garnish.gd")
const SpikeAudio := preload("res://scripts/spike_audio.gd")

var camera: Camera3D
var mech_a: Node3D
var mech_b: Node3D
var director: Node3D
var _fps_samples: Array[float] = []
var _fade: ColorRect

func _process(_delta: float) -> void:
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
	CityBuilder.build_environment(self, "--anime" in OS.get_cmdline_user_args())
	CityBuilder.build(self)
	var full_armor := "--armor" in OS.get_cmdline_user_args()
	mech_a = MechActor.new()
	mech_a.setup("A", Color(0.30, 0.45, 0.75), -40.0, full_armor)
	add_child(mech_a)
	mech_b = MechActor.new()
	mech_b.setup("B", Color(0.70, 0.30, 0.25), 40.0, full_armor)
	add_child(mech_b)
	camera = Camera3D.new()
	camera.position = Vector3(0, 45, 90)
	camera.fov = 55
	camera.attributes = CameraAttributesPractical.new()
	add_child(camera)
	camera.look_at(Vector3(0, 10, 0), Vector3.UP)
	if "--anime" in OS.get_cmdline_user_args():
		_add_anime_post()
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
	garnish.setup({"A": mech_a, "B": mech_b}, director)
	var audio := SpikeAudio.new()
	add_child(audio)
	audio.wire(director)
	if "--frames" in OS.get_cmdline_user_args():
		_capture_frames(director_name)
	director.fight_over.connect(func():
		create_tween().tween_property(_fade, "color:a", 1.0, 2.0)
		await get_tree().create_timer(2.2).timeout
		_fps_samples.sort()
		if _fps_samples.size() > 2:
			print("FPS min=%d  p5=%d  avg=%d" % [int(_fps_samples[0]),
				int(_fps_samples[_fps_samples.size() / 20]),
				int(_fps_samples.reduce(func(a, b): return a + b) / _fps_samples.size())])
		get_tree().quit())
