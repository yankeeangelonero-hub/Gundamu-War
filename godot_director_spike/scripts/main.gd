extends Node3D

const CityBuilder := preload("res://scripts/city_builder.gd")
const MechActor := preload("res://scripts/mech_actor.gd")
const FightLog := preload("res://scripts/fight_log.gd")
const Garnish := preload("res://scripts/garnish.gd")
const SpikeAudio := preload("res://scripts/spike_audio.gd")
const PauseController := preload("res://scripts/pause_controller.gd")
const DebugDirector := preload("res://scripts/debug_director.gd")

var camera: Camera3D
var mech_a: Node3D
var mech_b: Node3D
var director: Node3D
var _fps_samples: Array[float] = []
var _fade: ColorRect
var _paused_layer: CanvasLayer

# --debug: live feel/balance tuning bench. The fight is rebuildable so the panel can re-film.
var _debug_on := false
var _panel: CanvasLayer
var _DirectorScript: GDScript
var _world_env
var _full_armor := false
var _rig := false
var _grade
var _garnish
var _audio
# Current fight inputs, held so a replay/tune can re-stage and re-film the same (or edited) fight.
var _events: Array = []
var _grammar: ShotGrammar
var _feel: Dictionary = {}

# --camlog: per-frame trace of the ACTUAL runtime camera, for diagnosing transitions /
# sharp cuts / jerk independent of what the shot list intends. Written to tmp/camlog.json.
var _camlog_on := false
var _camlog: Array = []
var _wall_t := 0.0
var _cam_prev_pos := Vector3.ZERO
var _cam_prev_fwd := Vector3.ZERO
var _cam_prev_valid := false

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if Engine.get_process_frames() % 30 == 0:
		_fps_samples.append(Performance.get_monitor(Performance.TIME_FPS))
	if _camlog_on and director != null and camera != null:
		_capture_camlog(delta)

## Append one row of the real camera state. dpos/dang are per-frame deltas; a clean shot
## moves on a smooth curve, an unintended jerk shows a spike WITHIN a shot (shot index
## unchanged), an intentional cut shows a spike AT a shot-index change.
func _capture_camlog(delta: float) -> void:
	_wall_t += delta / maxf(Engine.time_scale, 0.01)
	var idx := int(director.get("_shot_idx"))
	var dshots: Array = director.get("shots")
	var mode := "?"
	if idx >= 0 and idx < dshots.size():
		mode = String(dshots[idx].mode)
	var p := camera.global_position
	var fwd := -camera.global_transform.basis.z
	var dpos := 0.0
	var dang := 0.0
	if _cam_prev_valid:
		dpos = p.distance_to(_cam_prev_pos)
		if fwd.length() > 0.001 and _cam_prev_fwd.length() > 0.001:
			dang = _cam_prev_fwd.angle_to(fwd)
	var ha: Vector3 = mech_a.global_position + Vector3(0, 10, 0)
	var hb: Vector3 = mech_b.global_position + Vector3(0, 10, 0)
	_camlog.append({
		"wall": snappedf(_wall_t, 0.001), "shot": idx, "mode": mode,
		"px": snappedf(p.x, 0.1), "py": snappedf(p.y, 0.1), "pz": snappedf(p.z, 0.1),
		"fov": snappedf(camera.fov, 0.1), "ortho": camera.projection == Camera3D.PROJECTION_ORTHOGONAL,
		"dpos": snappedf(dpos, 0.01), "dang": snappedf(dang, 0.001),
		"a_in": camera.is_position_in_frustum(ha), "b_in": camera.is_position_in_frustum(hb),
		"a_spd": snappedf(mech_a.velocity.length(), 0.1), "b_spd": snappedf(mech_b.velocity.length(), 0.1),
		"a_y": snappedf(mech_a.position.y, 0.01), "b_y": snappedf(mech_b.position.y, 0.01),
	})
	_cam_prev_pos = p
	_cam_prev_fwd = fwd
	_cam_prev_valid = true

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
	_DirectorScript = load(director_path)
	_world_env = CityBuilder.build_environment(self)
	CityBuilder.build(self)
	_full_armor = "--armor" in OS.get_cmdline_user_args()
	_rig = "--mesh" in OS.get_cmdline_user_args()
	camera = Camera3D.new()
	camera.position = Vector3(0, 45, 90)
	camera.fov = 55
	camera.attributes = CameraAttributesPractical.new()
	add_child(camera)
	camera.look_at(Vector3(0, 10, 0), Vector3.UP)
	print("KM-DIRECTOR-SPIKE boot ok")
	_camlog_on = "--camlog" in OS.get_cmdline_user_args()
	_debug_on = "--debug" in OS.get_cmdline_user_args()
	if "--still" in OS.get_cmdline_user_args():
		_spawn_mechs()
		# Behind mech A (x=-55), looking toward B (x=+40) - sees both mechs + city flanks
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
	paused_label.text = "|| PAUSED"
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
	# Load the fight inputs (truth + side-channel presentation hooks), held for replay/tuning.
	var log_path := "res://data/fight_log.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--log="):
			log_path = "res://data/%s.json" % arg.trim_prefix("--log=")
	_events = FightLog.load_events(log_path)
	_grammar = ShotGrammar.default()
	# Director seam: if the log carries the choreographer's side-channel presentation hooks,
	# surface them (the camera can read shape/climax_window/range_band for framing). Printed
	# only here - driving the runtime camera from these is the separately-gated v2 cutover.
	var presentation := FightLog.load_presentation(log_path)
	if not presentation.is_empty():
		var fight: Dictionary = presentation.get("fight", {})
		print("KM-PRESENTATION shape=%s template=%s climax=%s beats=%d" % [
			fight.get("shape", "?"), fight.get("template_id", "?"),
			str(fight.get("climax_window", [])), (presentation.get("beats", []) as Array).size()])
		_feel = presentation.get("actors", {})
	_build_fight()
	if "--frames" in OS.get_cmdline_user_args():
		_capture_frames(director_name)
	if _debug_on:
		_panel = DebugDirector.new()
		_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_panel)
		_panel.replay_requested.connect(_replay)

## (Re)create the two mech bodies, freeing any prior pair first. Used by the initial build,
## by --still, and by every debug re-film.
func _spawn_mechs() -> void:
	if mech_a != null and is_instance_valid(mech_a):
		mech_a.queue_free()
	if mech_b != null and is_instance_valid(mech_b):
		mech_b.queue_free()
	mech_a = MechActor.new()
	mech_a.setup("A", Color(0.30, 0.45, 0.75), -40.0, _full_armor, _rig)
	add_child(mech_a)
	mech_b = MechActor.new()
	mech_b.setup("B", Color(0.70, 0.30, 0.25), 40.0, _full_armor, _rig)
	add_child(mech_b)

## Build (or rebuild) the filmed fight from the held inputs (_events, _grammar, _feel): fresh
## mechs + director + grade + garnish + audio, all bound to the persistent camera. The single
## re-film seam the debug panel drives; the shipped one-shot path calls it once.
func _build_fight() -> void:
	for n in [director, _grade, _garnish, _audio]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	Engine.time_scale = 1.0
	_spawn_mechs()
	if _feel.has("A"):
		mech_a.apply_feel(float(_feel["A"].get("heft", 0.5)), float(_feel["A"].get("tempo", 0.5)), _grammar)
	if _feel.has("B"):
		mech_b.apply_feel(float(_feel["B"].get("heft", 0.5)), float(_feel["B"].get("tempo", 0.5)), _grammar)
	var dur := FightLog.duration_sec(_events)
	# Single source of truth: ONE grammar instance flows to shot-gen, the director's runtime
	# camera (_grammar), the Grade node, and garnish.
	var shots: Array = _DirectorScript.build_shot_list(_events, dur, _grammar)
	director = _DirectorScript.new()
	add_child(director)
	director.set("_grammar", _grammar)
	director.start(_events, shots, camera, {"A": mech_a, "B": mech_b}, dur)
	var GradeScript: GDScript = load("res://scripts/director/grade.gd")
	_grade = GradeScript.new()
	add_child(_grade)
	_grade.bind(_world_env.environment, _grammar, director)
	_grade.apply_base()
	_garnish = Garnish.new()
	add_child(_garnish)
	_garnish.setup({"A": mech_a, "B": mech_b}, director, _grammar)
	_audio = SpikeAudio.new()
	add_child(_audio)
	_audio.wire(director)
	director.fight_over.connect(_on_fight_over)

## End-of-fight: flush the camlog. In --debug, stay open for replay/tuning; otherwise fade + quit.
func _on_fight_over() -> void:
	if _camlog_on:
		DirAccess.make_dir_recursive_absolute("res://tmp")
		var fa := FileAccess.open("res://tmp/camlog.json", FileAccess.WRITE)
		fa.store_string(JSON.stringify(_camlog))
		fa.close()
		print("camlog: wrote %d rows to tmp/camlog.json" % _camlog.size())
	if _debug_on:
		return
	create_tween().tween_property(_fade, "color:a", 1.0, 2.0)
	await get_tree().create_timer(2.2).timeout
	_fps_samples.sort()
	if _fps_samples.size() > 2:
		print("FPS min=%d  p5=%d  avg=%d" % [int(_fps_samples[0]),
			int(_fps_samples[_fps_samples.size() / 20]),
			int(_fps_samples.reduce(func(a, b): return a + b) / _fps_samples.size())])
	get_tree().quit()

## Debug panel hook: re-film the current fight from the (possibly tuned) held inputs.
func _replay() -> void:
	_fade.color = Color(0, 0, 0, 0)
	_camlog.clear()
	_cam_prev_valid = false
	_wall_t = 0.0
	_build_fight()
