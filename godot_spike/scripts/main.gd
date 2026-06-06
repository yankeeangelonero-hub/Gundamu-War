extends Node2D

const DATA_PATH := "res://data/deploy_parts.json"
const RigSpikeScript = preload("res://scripts/rig_spike.gd")
const DeploySliceCore = preload("res://scripts/deploy_slice_core.gd")
const MODE_SAFE := "safe"
const MODE_PUSH := "push"

var _core
var _catalog := {}
var _selection := {}

var _rig: Node2D
var _part_buttons := {}
var _pilot_label: Label
var _stats_label: Label
var _forecast_label: Label
var _forecast_explanation_label: Label
var _safe_preview_label: Label
var _push_preview_label: Label
var _sync_label: Label
var _event_log_label: RichTextLabel
var _result_label: Label
var _playback_timer: Timer

var _current_run := {}
var _playback_events := []
var _playback_index := 0
var _event_lines := []

func _ready() -> void:
	_core = DeploySliceCore.new()
	_catalog = _core.load_catalog(DATA_PATH)
	_selection = _core.get_default_selection(_catalog)
	_build_rig()
	_build_ui()
	_build_playback_timer()
	_refresh_workshop()

func _build_rig() -> void:
	_rig = Node2D.new()
	_rig.set_script(RigSpikeScript)
	_rig.position = Vector2(250, 0)
	_rig.scale = Vector2(0.9, 0.9)
	add_child(_rig)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var root := HBoxContainer.new()
	root.position = Vector2(18, 16)
	root.custom_minimum_size = Vector2(1240, 688)
	root.add_theme_constant_override("separation", 24)
	canvas.add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 680)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	var title := Label.new()
	title.text = "KM-DEPLOY"
	title.add_theme_font_size_override("font_size", 28)
	left.add_child(title)

	_pilot_label = _make_label("", 18, Vector2(540, 46))
	left.add_child(_pilot_label)

	_stats_label = _make_label("", 16, Vector2(540, 76))
	left.add_child(_stats_label)

	_forecast_label = _make_label("", 22, Vector2(540, 34))
	left.add_child(_forecast_label)

	_forecast_explanation_label = _make_label("", 16, Vector2(540, 48))
	left.add_child(_forecast_explanation_label)

	left.add_child(HSeparator.new())
	_build_part_controls(left)
	left.add_child(HSeparator.new())
	_build_deploy_controls(left)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(390, 680)
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)

	var watch_title := Label.new()
	watch_title.text = "Watched Duel"
	watch_title.add_theme_font_size_override("font_size", 22)
	right.add_child(watch_title)

	_sync_label = _make_label("Sync log waits for deployment.", 17, Vector2(380, 34))
	right.add_child(_sync_label)

	_event_log_label = RichTextLabel.new()
	_event_log_label.custom_minimum_size = Vector2(380, 330)
	_event_log_label.fit_content = false
	_event_log_label.scroll_active = true
	_event_log_label.add_theme_font_size_override("normal_font_size", 15)
	right.add_child(_event_log_label)

	var result_title := Label.new()
	result_title.text = "Homecoming"
	result_title.add_theme_font_size_override("font_size", 22)
	right.add_child(result_title)

	_result_label = _make_label("Choose a deployment to send Ari out.", 16, Vector2(380, 205))
	right.add_child(_result_label)

func _make_label(text: String, font_size: int, min_size: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = min_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _build_part_controls(parent: VBoxContainer) -> void:
	for slot in _catalog.get("slots", []):
		var slot_id := str(slot.get("id", ""))
		var label := Label.new()
		label.text = str(slot.get("label", slot_id))
		label.add_theme_font_size_override("font_size", 17)
		parent.add_child(label)

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(540, 58)
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)

		for part_id_variant in slot.get("parts", []):
			var part_id := str(part_id_variant)
			var part: Dictionary = _core.get_part(_catalog, part_id)
			var button := Button.new()
			button.text = str(part.get("label", part_id))
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(260, 54)
			button.add_theme_font_size_override("font_size", 17)
			button.pressed.connect(_on_part_pressed.bind(slot_id, part_id))
			row.add_child(button)
			_part_buttons[_part_key(slot_id, part_id)] = button

func _build_deploy_controls(parent: VBoxContainer) -> void:
	var deploy_row := HBoxContainer.new()
	deploy_row.custom_minimum_size = Vector2(540, 78)
	deploy_row.add_theme_constant_override("separation", 10)
	parent.add_child(deploy_row)

	var safe_button := Button.new()
	safe_button.text = "Deploy Safe"
	safe_button.custom_minimum_size = Vector2(260, 74)
	safe_button.add_theme_font_size_override("font_size", 21)
	safe_button.pressed.connect(_on_deploy_pressed.bind(MODE_SAFE))
	deploy_row.add_child(safe_button)

	var push_button := Button.new()
	push_button.text = "Push for Breakthrough"
	push_button.custom_minimum_size = Vector2(270, 74)
	push_button.add_theme_font_size_override("font_size", 19)
	push_button.pressed.connect(_on_deploy_pressed.bind(MODE_PUSH))
	deploy_row.add_child(push_button)

	_safe_preview_label = _make_label("", 15, Vector2(540, 48))
	parent.add_child(_safe_preview_label)

	_push_preview_label = _make_label("", 15, Vector2(540, 54))
	parent.add_child(_push_preview_label)

func _build_playback_timer() -> void:
	_playback_timer = Timer.new()
	_playback_timer.wait_time = 0.65
	_playback_timer.one_shot = false
	_playback_timer.timeout.connect(_play_next_event)
	add_child(_playback_timer)

func _on_part_pressed(slot_id: String, part_id: String) -> void:
	_selection[slot_id] = part_id
	_refresh_workshop()

func _on_deploy_pressed(mode: String) -> void:
	_current_run = _core.run_deploy(_catalog, _selection, mode)
	_playback_events = _current_run.get("events", [])
	_playback_index = 0
	_event_lines.clear()
	_event_log_label.text = ""
	_result_label.text = "Sortie in progress. The duel is precomputed, then watched back."
	_sync_label.text = "Sync log active."
	_playback_timer.stop()
	_play_next_event()
	_playback_timer.start()

func _play_next_event() -> void:
	if _playback_index >= _playback_events.size():
		_playback_timer.stop()
		_show_result()
		return

	var event: Dictionary = _playback_events[_playback_index]
	_playback_index += 1
	_append_event(str(event.get("text", "")))

	var event_type := str(event.get("type", ""))
	if event_type == "sync":
		_sync_label.text = "Sync %d  |  gained +%d  |  fit pressure %d" % [
			int(event.get("sync", 0)),
			int(event.get("sync_gain", 0)),
			int(event.get("fit_pressure", 0)),
		]
	elif event_type == "attack" and str(event.get("source", "")) == "player":
		_rig.play_attack_event(event)
	elif event_type == "result":
		_playback_timer.stop()
		_show_result()

func _append_event(text: String) -> void:
	if text.is_empty():
		return
	_event_lines.append(text)
	while _event_lines.size() > 16:
		_event_lines.pop_front()
	var joined := ""
	for line in _event_lines:
		if not joined.is_empty():
			joined += "\n"
		joined += str(line)
	_event_log_label.text = joined

func _show_result() -> void:
	if _current_run.is_empty():
		return
	var result: Dictionary = _current_run.get("result", {})
	_result_label.text = "%s\nSync gained: +%d\nXP gained: +%d\nBreakthrough: %d -> %d%s\n%s\nPilot harm: none. No permanent pilot harm." % [
		str(result.get("outcome", "RESULT")),
		int(result.get("sync_gained", 0)),
		int(result.get("xp_gained", 0)),
		int(result.get("breakthrough_progress_before", 0)),
		int(result.get("breakthrough_progress_after", 0)),
		" (earned)" if bool(result.get("breakthrough_earned", false)) else "",
		str(result.get("explanation", "")),
	]

func _refresh_workshop() -> void:
	var forecast: Dictionary = _core.forecast_fit(_catalog, _selection)
	var build: Dictionary = forecast.get("build", {})
	var pilot: Dictionary = _catalog.get("pilot", {})

	_pilot_label.text = "%s  |  capacity %d  |  sync ceiling %d" % [
		str(pilot.get("name", "Pilot")),
		int(pilot.get("capacity", 0)),
		int(pilot.get("sync_ceiling", 0)),
	]

	_stats_label.text = "Build demand %d/%d  |  damage %d  defense %d  initiative %d  dodge %d  sync gain %d" % [
		int(forecast.get("demand", 0)),
		int(forecast.get("capacity", 0)),
		int(build.get("damage", 0)),
		int(build.get("defense", 0)),
		int(build.get("initiative", 0)),
		int(build.get("dodge", 0)),
		int(build.get("sync_gain", 0)),
	]

	_forecast_label.text = "Fit forecast: %s" % str(forecast.get("label", "Unknown"))
	_forecast_explanation_label.text = str(forecast.get("explanation", ""))

	for slot in _catalog.get("slots", []):
		var slot_id := str(slot.get("id", ""))
		for part_id_variant in slot.get("parts", []):
			var part_id := str(part_id_variant)
			var key := _part_key(slot_id, part_id)
			if _part_buttons.has(key):
				_part_buttons[key].button_pressed = str(_selection.get(slot_id, "")) == part_id

	var safe_preview: Dictionary = _core.preview_deploy(_catalog, _selection, MODE_SAFE)
	var push_preview: Dictionary = _core.preview_deploy(_catalog, _selection, MODE_PUSH)
	_safe_preview_label.text = "Safe: demand %d, XP about +%d, breakthrough +%d. %s" % [
		int(safe_preview.get("effective_demand", 0)),
		int(safe_preview.get("xp_hint", 0)),
		int(safe_preview.get("breakthrough_hint", 0)),
		str(safe_preview.get("text", "")),
	]
	_push_preview_label.text = "Push: demand %d, XP about +%d, breakthrough +%d. %s" % [
		int(push_preview.get("effective_demand", 0)),
		int(push_preview.get("xp_hint", 0)),
		int(push_preview.get("breakthrough_hint", 0)),
		str(push_preview.get("text", "")),
	]

	if _rig and _rig.has_method("set_weapon_visual"):
		_rig.set_weapon_visual(_core.get_weapon_visual(_catalog, _selection))

func _part_key(slot_id: String, part_id: String) -> String:
	return slot_id + "::" + part_id
