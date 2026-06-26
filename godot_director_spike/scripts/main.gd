extends Node3D

const CityBuilder := preload("res://scripts/city_builder.gd")
const MechActor := preload("res://scripts/mech_actor.gd")
const FightLog := preload("res://scripts/fight_log.gd")
const Garnish := preload("res://scripts/garnish.gd")
const SpikeAudio := preload("res://scripts/spike_audio.gd")
const PauseController := preload("res://scripts/pause_controller.gd")
const DebugDirector := preload("res://scripts/debug_director.gd")
const Choreographer := preload("res://scripts/sim/choreographer.gd")
const DEBUG_LOADOUTS_PATH := "res://data/debug_archetype_loadouts.json"

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
var _source_events: Array = []
var _debug_truth: Array = []
var _grammar: ShotGrammar
var _feel: Dictionary = {}
var _enabled_modes: Dictionary = {}
var _debug_live := true
var _debug_seed := 7
var _debug_archetypes := {"A": "", "B": ""}
var _debug_loadout_truth_active := false

const DEBUG_KIND_TO_MOTIF := {
	"fire_beam": "beam",
	"fire_burst": "burst",
	"fire_missiles": "missiles",
	"fire_buster": "buster",
	"melee": "saber",
}
const DEBUG_MOTIF_TO_KIND := {
	"beam": "fire_beam",
	"burst": "fire_burst",
	"missiles": "fire_missiles",
	"buster": "fire_buster",
	"saber": "melee",
	"vulcan": "fire_burst",
}

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
	_load_debug_source_log(log_path)
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
		_panel.live_changed.connect(_on_debug_live_changed)
		_panel.grammar_number_changed.connect(_on_debug_grammar_number_changed)
		_panel.framing_number_changed.connect(_on_debug_framing_number_changed)
		_panel.feel_number_changed.connect(_on_debug_feel_number_changed)
		_panel.preset_changed.connect(_on_debug_preset_changed)
		_panel.shot_mode_changed.connect(_on_debug_shot_mode_changed)
		_panel.configure(_grammar, _feel, _enabled_modes)

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
	var shots: Array = _DirectorScript.build_shot_list(_events, dur, _grammar, _enabled_modes)
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


func _load_debug_source_log(log_path: String) -> void:
	_source_events = FightLog.load_events(log_path)
	_events = _source_events.duplicate(true)
	_debug_truth = _viewer_events_to_debug_truth(_source_events)


func _on_debug_live_changed(enabled: bool) -> void:
	_debug_live = enabled


func _debug_refilm_if_live() -> void:
	if _debug_live and _fade != null:
		_replay()


func _on_debug_grammar_number_changed(property_name: String, value: float) -> void:
	_grammar.set(property_name, value)
	_debug_refilm_if_live()


func _on_debug_framing_number_changed(mode: String, property_name: String, value: float) -> void:
	var framing: Dictionary = _grammar.framing.duplicate(true)
	var entry: Dictionary = framing.get(mode, {}).duplicate(true) if framing.get(mode, {}) is Dictionary else {}
	entry[property_name] = value
	framing[mode] = entry
	_grammar.framing = framing
	_debug_refilm_if_live()


func _on_debug_feel_number_changed(actor: String, property_name: String, value: float) -> void:
	var fp := _feel_profile_for(actor)
	fp[property_name] = value
	_feel[actor] = fp
	_restage_debug_truth()
	_debug_refilm_if_live()


func _on_debug_preset_changed(actor: String, preset_name: String) -> void:
	var fp: Dictionary = Choreographer.apply_preset(preset_name)
	fp["preset"] = preset_name
	_feel[actor] = fp
	_debug_archetypes[actor] = preset_name
	_regenerate_debug_truth_from_archetypes()
	if _panel != null and is_instance_valid(_panel):
		_panel.configure(_grammar, _feel, _enabled_modes)
	_restage_debug_truth()
	_debug_refilm_if_live()


func _on_debug_shot_mode_changed(mode: String, enabled: bool) -> void:
	_enabled_modes[mode] = enabled
	_debug_refilm_if_live()


func _feel_profile_for(actor: String) -> Dictionary:
	var fp: Dictionary = {}
	if _feel.has(actor) and _feel[actor] is Dictionary:
		fp = _feel[actor].duplicate(true)
	if not fp.has("heft"):
		fp["heft"] = 0.5
	if not fp.has("tempo"):
		fp["tempo"] = 0.5
	if not fp.has("mode_mix"):
		fp["mode_mix"] = {}
	if not fp.has("overrides"):
		fp["overrides"] = {}
	fp["preset"] = "custom"
	return fp


## Debug-only bridge: most existing viewer logs are v1 render logs (`fire_beam`,
## `advance`, etc.). The choreographer restages v2 truth (`shot`) logs. For live
## feel tuning, strip authored advances and convert attacks to v2 shots, preserving
## the original viewer kind/payload as metadata so we can render them back through
## the locked v1 director.
func _viewer_events_to_debug_truth(events: Array) -> Array:
	var truth: Array = []
	var seq := 0
	for e in events:
		var kind := str(e.get("kind", ""))
		if kind == "advance":
			continue
		var payload: Dictionary = e.get("payload", {}).duplicate(true)
		if kind == "spawn":
			payload.erase("x")
			payload.erase("z")
			truth.append({"tick": int(e.tick), "seq": seq, "actor": str(e.actor), "kind": "spawn", "payload": payload})
		elif kind in DEBUG_KIND_TO_MOTIF:
			var motif: String = DEBUG_KIND_TO_MOTIF[kind]
			var outcome := "hit" if _viewer_attack_connects(kind, payload) else "miss"
			var shot_payload := {
				"motif": motif,
				"tier": _debug_tier_for_kind(kind),
				"travel": _debug_travel_for_kind(kind),
				"outcome": outcome,
				"damage": float(payload.get("damage", 0.0)),
				"source_kind": kind,
				"source_payload": payload,
			}
			if payload.has("hp_after"):
				shot_payload["hp_after"] = payload.hp_after
			if payload.get("lethal", false):
				shot_payload["lethal"] = true
			truth.append({"tick": int(e.tick), "seq": seq, "actor": str(e.actor), "kind": "shot", "payload": shot_payload})
		else:
			truth.append({"tick": int(e.tick), "seq": seq, "actor": str(e.actor), "kind": kind, "payload": payload})
		seq += 1
	truth.sort_custom(func(a, b):
		if int(a.tick) != int(b.tick):
			return int(a.tick) < int(b.tick)
		return int(a.seq) < int(b.seq))
	return truth


func _restage_debug_truth() -> void:
	if _debug_truth.is_empty():
		return
	var profiles := _debug_profiles_for_stage()
	var staged: Array = Choreographer.stage(_debug_truth, _debug_seed, profiles)
	_events = _debug_staged_truth_to_viewer_events(staged)
	print("KM-DEBUG restaged %s A=%s(h=%.2f,t=%.2f) B=%s(h=%.2f,t=%.2f)" % [
		("loadouts" if _debug_loadout_truth_active else "source-log"),
		str(_debug_archetypes.get("A", "")),
		float(profiles.A.heft), float(profiles.A.tempo),
		str(_debug_archetypes.get("B", "")),
		float(profiles.B.heft), float(profiles.B.tempo)])


func _debug_profiles_for_stage() -> Dictionary:
	return {
		"A": _feel_profile_for_stage("A"),
		"B": _feel_profile_for_stage("B"),
	}


func _regenerate_debug_truth_from_archetypes() -> void:
	var loadouts := _load_debug_loadouts()
	if loadouts.is_empty():
		return
	for actor in ["A", "B"]:
		if str(_debug_archetypes.get(actor, "")) == "":
			_debug_archetypes[actor] = "gunner"
		if not _feel.has(actor):
			var fp: Dictionary = Choreographer.apply_preset(str(_debug_archetypes[actor]))
			fp["preset"] = str(_debug_archetypes[actor])
			_feel[actor] = fp
	var a_name := str(_debug_archetypes.A)
	var b_name := str(_debug_archetypes.B)
	var a_loadout: Dictionary = loadouts.get(a_name, loadouts.get("gunner", {}))
	var b_loadout: Dictionary = loadouts.get(b_name, loadouts.get("gunner", {}))
	_debug_truth = _generate_debug_truth_from_loadouts(a_loadout, b_loadout, _debug_seed)
	_debug_loadout_truth_active = true


func _load_debug_loadouts() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEBUG_LOADOUTS_PATH))
	return parsed if parsed is Dictionary else {}


func _generate_debug_truth_from_loadouts(loadout_a: Dictionary, loadout_b: Dictionary, seed: int) -> Array:
	var hp := {
		"A": int(loadout_a.get("hp", 100)),
		"B": int(loadout_b.get("hp", 100)),
	}
	var truth: Array = [
		{"tick": 0, "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": hp.A}},
		{"tick": 0, "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": hp.B}},
	]
	var streams: Array = []
	_add_debug_weapon_streams(streams, "A", loadout_a, seed)
	_add_debug_weapon_streams(streams, "B", loadout_b, seed + 17)
	var seq := 2
	var last_tick := 0
	var max_tick := 220
	while seq < 80 and not streams.is_empty():
		streams.sort_custom(func(a, b):
			if int(a.next_tick) != int(b.next_tick):
				return int(a.next_tick) < int(b.next_tick)
			if str(a.actor) != str(b.actor):
				return str(a.actor) < str(b.actor)
			return int(a.weapon_idx) < int(b.weapon_idx))
		var s: Dictionary = streams[0]
		var tick := int(s.next_tick)
		if tick > max_tick:
			break
		var actor := str(s.actor)
		var target := "B" if actor == "A" else "A"
		if hp[target] <= 0:
			break
		var weapon: Dictionary = s.weapon
		var damage := float(weapon.get("damage", 1.0))
		hp[target] = maxi(0, int(round(float(hp[target]) - damage)))
		var lethal: bool = hp[target] <= 0
		var payload: Dictionary = _debug_shot_payload_from_weapon(weapon, hp[target], lethal)
		truth.append({"tick": tick, "seq": seq, "actor": actor, "kind": "shot", "payload": payload})
		seq += 1
		last_tick = tick
		if lethal:
			truth.append({"tick": tick, "seq": seq, "actor": target, "kind": "destroyed", "payload": {}})
			break
		s.next_tick = tick + maxi(1, int(weapon.get("cooldown", 12)))
		streams[0] = s
	if truth[-1].kind != "destroyed":
		var winner := "A" if hp.A >= hp.B else "B"
		var loser := "B" if winner == "A" else "A"
		var finisher: Dictionary = _strongest_debug_weapon(loadout_a if winner == "A" else loadout_b)
		var tick := last_tick + maxi(8, int(int(finisher.get("cooldown", 16)) / 2))
		var payload: Dictionary = _debug_shot_payload_from_weapon(finisher, 0, true)
		truth.append({"tick": tick, "seq": seq, "actor": winner, "kind": "shot", "payload": payload})
		seq += 1
		truth.append({"tick": tick, "seq": seq, "actor": loser, "kind": "destroyed", "payload": {}})
	truth.sort_custom(func(a, b):
		if int(a.tick) != int(b.tick):
			return int(a.tick) < int(b.tick)
		return int(a.seq) < int(b.seq))
	return truth


func _add_debug_weapon_streams(streams: Array, actor: String, loadout: Dictionary, seed: int) -> void:
	var weapons: Array = loadout.get("weapons", [])
	for i in weapons.size():
		var weapon: Dictionary = weapons[i]
		var start := int(weapon.get("start", 8 + i * 4))
		var jitter := int(abs(seed + i * 3 + (0 if actor == "A" else 5)) % 3)
		streams.append({"actor": actor, "weapon_idx": i, "weapon": weapon, "next_tick": start + jitter})


func _debug_shot_payload_from_weapon(weapon: Dictionary, hp_after: int, lethal: bool) -> Dictionary:
	var source_kind := str(weapon.get("viewer_kind", DEBUG_MOTIF_TO_KIND.get(weapon.get("motif", "beam"), "fire_beam")))
	var p := {
		"motif": str(weapon.get("motif", "beam")),
		"tier": int(weapon.get("tier", _debug_tier_for_kind(source_kind))),
		"travel": int(weapon.get("travel", _debug_travel_for_kind(source_kind))),
		"outcome": "hit",
		"damage": float(weapon.get("damage", 0.0)),
		"hp_after": hp_after,
		"source_kind": source_kind,
		"source_payload": _debug_source_payload_for_weapon(source_kind, weapon, hp_after, lethal),
	}
	if weapon.has("mode_weights"):
		p["mode_weights"] = weapon.mode_weights
	if lethal:
		p["lethal"] = true
	return p


func _debug_source_payload_for_weapon(kind: String, weapon: Dictionary, hp_after: int, lethal: bool) -> Dictionary:
	var p: Dictionary = {"damage": float(weapon.get("damage", 0.0)), "hp_after": hp_after}
	match kind:
		"fire_burst":
			p["rounds"] = int(weapon.get("rounds", 8))
			p["hits"] = int(weapon.get("hits", 3))
		"fire_missiles":
			p["count"] = int(weapon.get("count", 6))
			p["hits"] = int(weapon.get("hits", 4))
		_:
			p["hit"] = true
	if lethal:
		p["lethal"] = true
	return p


func _strongest_debug_weapon(loadout: Dictionary) -> Dictionary:
	var weapons: Array = loadout.get("weapons", [])
	var best: Dictionary = {}
	for w in weapons:
		if best.is_empty() or float(w.get("damage", 0.0)) > float(best.get("damage", 0.0)):
			best = w
	return best if not best.is_empty() else {"motif": "beam", "viewer_kind": "fire_beam", "tier": 2, "damage": 10, "travel": 5}


func _feel_profile_for_stage(actor: String) -> Dictionary:
	var fp: Dictionary = _feel_profile_for(actor)
	fp.erase("preset")
	return fp


func _debug_staged_truth_to_viewer_events(staged: Array) -> Array:
	var out: Array = []
	for e in staged:
		var kind := str(e.get("kind", ""))
		var payload: Dictionary = e.get("payload", {})
		match kind:
			"advance":
				var p := payload.duplicate(true)
				p["to_y"] = float(p.get("to_y", 0.0))
				p["boost"] = bool(p.get("boost", false))
				out.append({"tick": int(e.tick), "actor": str(e.actor), "kind": "advance", "payload": p})
			"shot":
				var source_kind := str(payload.get("source_kind", DEBUG_MOTIF_TO_KIND.get(payload.get("motif", "beam"), "fire_beam")))
				var p: Dictionary = payload.get("source_payload", {}).duplicate(true)
				if p.is_empty():
					p = _fallback_viewer_attack_payload(source_kind, payload)
				out.append({"tick": int(e.tick), "actor": str(e.actor), "kind": source_kind, "payload": p})
			_:
				var p := payload.duplicate(true)
				out.append({"tick": int(e.tick), "actor": str(e.actor), "kind": kind, "payload": p})
	out.sort_custom(func(a, b):
		if int(a.tick) != int(b.tick):
			return int(a.tick) < int(b.tick)
		if str(a.kind) == "advance" and str(b.kind) != "advance":
			return false
		if str(a.kind) != "advance" and str(b.kind) == "advance":
			return true
		return str(a.actor) < str(b.actor))
	return out


func _viewer_attack_connects(kind: String, payload: Dictionary) -> bool:
	if kind in ["fire_beam", "fire_buster", "melee"]:
		return bool(payload.get("hit", true)) and not bool(payload.get("blocked", false))
	return int(payload.get("hits", 0)) > 0


func _debug_tier_for_kind(kind: String) -> int:
	return {"fire_buster": 3, "fire_missiles": 2, "fire_beam": 2, "melee": 2, "fire_burst": 1}.get(kind, 1)


func _debug_travel_for_kind(kind: String) -> int:
	return {"fire_buster": 6, "fire_missiles": 6, "fire_beam": 5, "melee": 1, "fire_burst": 4}.get(kind, 5)


func _fallback_viewer_attack_payload(kind: String, payload: Dictionary) -> Dictionary:
	var hit: bool = payload.get("outcome", "") == "hit"
	var p: Dictionary = {"damage": payload.get("damage", 0.0)}
	if kind in ["fire_burst", "fire_missiles"]:
		p["hits"] = 3 if hit else 0
		if kind == "fire_burst":
			p["rounds"] = 4
		else:
			p["count"] = 6
	else:
		p["hit"] = hit
	if payload.has("hp_after"):
		p["hp_after"] = payload.hp_after
	if payload.get("lethal", false):
		p["lethal"] = true
	return p
