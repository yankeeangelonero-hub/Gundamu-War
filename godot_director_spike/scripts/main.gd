extends Node3D

const CityBuilder := preload("res://scripts/city_builder.gd")
const MechActor := preload("res://scripts/mech_actor.gd")
const FightLog := preload("res://scripts/fight_log.gd")
const Garnish := preload("res://scripts/garnish.gd")
const SpikeAudio := preload("res://scripts/spike_audio.gd")
const PauseController := preload("res://scripts/pause_controller.gd")
const FightHandoff := preload("res://scripts/build/fight_handoff.gd")
const LoadoutView := preload("res://scripts/build/loadout_view.gd")

var camera: Camera3D
var mech_a: Node3D
var mech_b: Node3D
var director: Node3D
var _fps_samples: Array[float] = []
var _fade: ColorRect
var _paused_layer: CanvasLayer
var _trace := false

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if Engine.get_process_frames() % 30 == 0:
		_fps_samples.append(Performance.get_monitor(Performance.TIME_FPS))
	if _trace and director != null and director.playing and Engine.get_process_frames() % 12 == 0:
		print("TRACE f=%d cam=(%.1f,%.1f,%.1f) A=(%.1f,%.1f,%.1f) B=(%.1f,%.1f,%.1f)" % [
			Engine.get_process_frames(),
			camera.global_position.x, camera.global_position.y, camera.global_position.z,
			mech_a.global_position.x, mech_a.global_position.y, mech_a.global_position.z,
			mech_b.global_position.x, mech_b.global_position.y, mech_b.global_position.z])

## --frames: dump a PNG every 1.5 game-seconds for offline shot review.
func _capture_frames(director_name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var idx := 0
	var interval := 0.1 if "--densecap" in OS.get_cmdline_user_args() else 1.5
	while director != null and director.playing:
		await get_tree().create_timer(interval).timeout
		var img := get_viewport().get_texture().get_image()
		img.resize(640, 360)
		img.save_png("res://tmp/frame_%s_%04d.png" % [director_name, idx])
		idx += 1

## Establishing intro for a deployed fight: hold on a far lens that slowly pushes
## toward the two squared-up mechs while a VS title fades up, then hand off to the
## director for the fight. Camera is ours here (the director isn't playing yet).
func _intro(a: Node3D, b: Node3D, dur := 3.2) -> void:
	# Human-scale establishing shot: a person standing on the deck at the foot of a
	# ~20m mech, craning up at it. The camera holds human eye height (~1.7m) and walks
	# in, so the mech towers and the up-angle steepens — selling the scale. Anchored
	# to the mech's position; `mid` is the high look-up point (the head).
	var ap := a.position
	var mid := ap + Vector3(0, 10.0, 0)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 50
	var from := ap + Vector3(40.0, 1.7, 21.0)   # eye height, well back so the whole mech reads
	var to := ap + Vector3(30.0, 1.7, 16.0)     # ease in a little, still human-height
	camera.position = from
	camera.look_at(mid, Vector3.UP)
	_intro_clear_occluders(a, b)

	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.modulate = Color(1, 1, 1, 0)
	layer.add_child(cc)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(box)
	var vs := Label.new()
	vs.text = "%s    VS    %s" % [FightHandoff.player_label, FightHandoff.ghost_label]
	vs.add_theme_font_size_override("font_size", 46)
	vs.add_theme_color_override("font_color", Color("9af1ff"))
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(vs)
	var sub := Label.new()
	sub.text = "出撃   SORTIE"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color("d9933a"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	create_tween().tween_property(cc, "modulate:a", 1.0, 0.6)

	var t := 0.0
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / dur, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)   # ease-out push-in
		camera.position = from.lerp(to, e)
		camera.look_at(mid, Vector3.UP)
		_intro_clear_occluders(a, b)

	var ft := create_tween()
	ft.tween_property(cc, "modulate:a", 0.0, 0.4)
	await ft.finished
	layer.queue_free()

## During the intro the director isn't playing, so reuse its see-through-occluder
## fade to dissolve any buildings standing between the far lens and the two mechs.
func _intro_clear_occluders(a: Node3D, b: Node3D) -> void:
	if director == null:
		return
	var ah := a.position + Vector3(0, 10, 0)
	var bh := b.position + Vector3(0, 10, 0)
	if director.has_method("_fade_for_iso"):
		director._fade_for_iso(camera.position, ah, bh)
	elif director.has_method("_resolve_occlusion"):
		director._resolve_occlusion(camera.position, (ah + bh) * 0.5)

func _ready() -> void:
	# Debug: self-inject a starter DEPLOY fight so the real FightHandoff path can be
	# traced by running main.tscn directly (no separate runner). Gated by --deploy-test.
	if "--deploy-test" in OS.get_cmdline_user_args() and not FightHandoff.active:
		var Sim := load("res://scripts/build/build_fight_sim.gd")
		var Opp := load("res://scripts/build/opponent_source.gd")
		var placement := [
			{"def_id": "reactor_core", "rot": 0, "anchor": [0, 0]},
			{"def_id": "beam_rifle", "rot": 0, "anchor": [0, 2]}]
		var gh: Dictionary = Opp.get_ghost(12345)
		var ev: Array = Sim.simulate(Sim.build_from_placement(placement), Sim.build_from_placement(gh.placement), 12345)
		FightHandoff.player_placement = placement
		FightHandoff.ghost_placement = gh.placement
		FightHandoff.return_scene = ""   # empty → quit after one fight (debug trace)
		FightHandoff.set_fight(ev, "VESPER-7", str(gh.get("callsign", "GHOST")))
	var director_name := "cinematic"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--director="):
			director_name = arg.trim_prefix("--director=")
	# Launched from the build screen → play the injected fight with the proven hybrid grammar.
	if FightHandoff.active:
		director_name = FightHandoff.director_name
	var director_path := "res://scripts/directors/%s.gd" % director_name
	if not ResourceLoader.exists(director_path):
		push_error("Unknown director variant '%s': %s does not exist" % [director_name, director_path])
		get_tree().quit(1)
		return
	var DirectorScript: GDScript = load(director_path)
	CityBuilder.build_environment(self)
	CityBuilder.build(self)
	var full_armor := "--armor" in OS.get_cmdline_user_args()
	var rig := "--mesh" in OS.get_cmdline_user_args()
	mech_a = MechActor.new()
	mech_a.setup("A", Color(0.30, 0.45, 0.75), -40.0, full_armor, rig)
	add_child(mech_a)
	mech_b = MechActor.new()
	mech_b.setup("B", Color(0.70, 0.30, 0.25), 40.0, full_armor, rig)
	add_child(mech_b)
	# Deployed fight: hang each side's actual loadout on the mech that fights, so the
	# mech you built is the mech on the field (presentation only — beams still fire
	# from the existing muzzle; the sim outcome is unchanged).
	if FightHandoff.active:
		mech_a.register_hardpoints()
		LoadoutView.mount_loadout(mech_a, FightHandoff.player_placement)
		mech_b.register_hardpoints()
		LoadoutView.mount_loadout(mech_b, FightHandoff.ghost_placement)
	camera = Camera3D.new()
	camera.position = Vector3(0, 45, 90)
	camera.fov = 55
	camera.attributes = CameraAttributesPractical.new()
	add_child(camera)
	camera.look_at(Vector3(0, 10, 0), Vector3.UP)
	_trace = "--trace" in OS.get_cmdline_user_args()
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
	var events: Array
	if FightHandoff.active:
		events = FightHandoff.events   # injected by the build screen's DEPLOY
	else:
		var log_path := "res://data/fight_log.json"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--log="):
				log_path = "res://data/%s.json" % arg.trim_prefix("--log=")
		events = FightLog.load_events(log_path)
	var dur := FightLog.duration_sec(events)
	var shots: Array = DirectorScript.build_shot_list(events, dur)
	director = DirectorScript.new()
	add_child(director)
	var garnish := Garnish.new()
	add_child(garnish)
	garnish.setup({"A": mech_a, "B": mech_b}, director)
	var audio := SpikeAudio.new()
	add_child(audio)
	audio.wire(director)
	# Deployed-fight only: a far, slow establishing push-in before the duel begins.
	# Standalone runs (cmdline) skip this so the proven combat feel is untouched.
	if FightHandoff.active:
		await _intro(mech_a, mech_b)
	director.start(events, shots, camera, {"A": mech_a, "B": mech_b}, dur)
	if "--frames" in OS.get_cmdline_user_args():
		_capture_frames(director_name)
	director.fight_over.connect(func():
		create_tween().tween_property(_fade, "color:a", 1.0, 2.0)
		await get_tree().create_timer(2.2).timeout
		# From a build-screen deploy: return to the bag instead of quitting.
		if FightHandoff.active:
			var rs := FightHandoff.return_scene
			FightHandoff.clear()
			if rs != "":
				get_tree().change_scene_to_file(rs)
				return
			get_tree().quit()
			return
		_fps_samples.sort()
		if _fps_samples.size() > 2:
			print("FPS min=%d  p5=%d  avg=%d" % [int(_fps_samples[0]),
				int(_fps_samples[_fps_samples.size() / 20]),
				int(_fps_samples.reduce(func(a, b): return a + b) / _fps_samples.size())])
		get_tree().quit())
