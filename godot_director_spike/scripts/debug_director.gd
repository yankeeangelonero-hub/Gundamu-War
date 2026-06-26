extends CanvasLayer
## Debug Director - live feel/balance tuning bench (behind main.gd --debug).
## Spec: docs/superpowers/specs/2026-06-22-debug-director-tuning-ui-design.md
## Slices 1-4: side panel, Replay, live ShotGrammar sliders, shot-type toggles,
## per-mech FeelProfile/preset controls, and a scaffold spectacle metrics readout.

signal replay_requested
signal live_changed(enabled)
signal grammar_number_changed(property_name, value)
signal framing_number_changed(mode, property_name, value)
signal feel_number_changed(actor, property_name, value)
signal preset_changed(actor, preset_name)
signal shot_mode_changed(mode, enabled)

const GrammarParams := preload("res://scripts/sim/grammar_params.gd")

class SliderRelay:
	extends RefCounted
	var panel: CanvasLayer
	var key: String
	func _init(p_panel: CanvasLayer, p_key: String) -> void:
		panel = p_panel
		key = p_key
	func on_value_changed(value: float) -> void:
		panel._on_slider_value_changed_key(key, value)

class ShotRelay:
	extends RefCounted
	var panel: CanvasLayer
	var mode: String
	func _init(p_panel: CanvasLayer, p_mode: String) -> void:
		panel = p_panel
		mode = p_mode
	func on_toggled(enabled: bool) -> void:
		panel._on_shot_toggled_key(mode, enabled)

class PresetRelay:
	extends RefCounted
	var panel: CanvasLayer
	var picker: OptionButton
	var actor: String
	func _init(p_panel: CanvasLayer, p_picker: OptionButton, p_actor: String) -> void:
		panel = p_panel
		picker = p_picker
		actor = p_actor
	func on_item_selected(index: int) -> void:
		panel._on_preset_selected_key(picker, actor, index)

var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _shot_checks: Dictionary = {}
var _preset_buttons: Dictionary = {}
var _relays: Array = []
var _root_col: VBoxContainer = null
var _metrics_label: Label = null
var _live := true
var _suppress := false
var _pending_config: Dictionary = {}
var _pending_metrics: Dictionary = {}

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	root.position = Vector2(-328, 12)
	root.custom_minimum_size = Vector2(316, 0)
	add_child(root)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(316, 650)
	root.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)
	_root_col = col
	var title := Label.new()
	title.text = "DEBUG DIRECTOR"
	title.add_theme_font_size_override("font_size", 16)
	col.add_child(title)
	var hint := Label.new()
	hint.text = "live cinematic tuning bench"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.6)
	col.add_child(hint)
	col.add_child(HSeparator.new())
	var live := CheckBox.new()
	live.text = "Live re-film"
	live.button_pressed = _live
	live.toggled.connect(func(enabled: bool) -> void:
		_live = enabled
		live_changed.emit(enabled)
	)
	col.add_child(live)
	var replay := Button.new()
	replay.text = "Replay / re-film"
	replay.pressed.connect(func(): replay_requested.emit())
	col.add_child(replay)

	_add_metrics_section(col)
	_add_shot_toggles(col)
	_add_camera_controls(col)
	_add_actor_controls(col, "A")
	_add_actor_controls(col, "B")

	if not _pending_config.is_empty():
		var p := _pending_config
		_pending_config = {}
		configure(p.grammar, p.feel_profiles, p.enabled_modes)
	if not _pending_metrics.is_empty():
		var metrics := _pending_metrics
		_pending_metrics = {}
		set_metrics_summary(metrics)


func configure(grammar: ShotGrammar, feel_profiles: Dictionary, enabled_modes: Dictionary) -> void:
	if _root_col == null:
		_pending_config = {
			"grammar": grammar,
			"feel_profiles": feel_profiles,
			"enabled_modes": enabled_modes,
		}
		return
	_suppress = true
	_set_slider("grammar:os_len", grammar.os_len)
	_set_slider("grammar:cut_len", grammar.cut_len)
	_set_slider("grammar:min_iso", grammar.min_iso)
	_set_slider("grammar:camera_min_duration", grammar.camera_min_duration)
	_set_slider("grammar:camera_max_duration", grammar.camera_max_duration)
	_set_slider("grammar:camera_speed_scale", grammar.camera_speed_scale)
	_set_slider("grammar:dolly_cap", grammar.dolly_cap)
	_set_slider("grammar:iso_dolly_cap", grammar.iso_dolly_cap)
	_set_slider("grammar:melee_radius_factor", grammar.melee_radius_factor)
	_set_slider("grammar:bt_pre", grammar.bt_pre)
	_set_slider("grammar:bt_post", grammar.bt_post)
	_set_slider("grammar:bt_scale", grammar.bt_scale)
	_set_slider("framing:hero_os:fov", float(grammar.framing.get("hero_os", {}).get("fov", 40.0)))
	_set_slider("framing:hero_cut:fov", float(grammar.framing.get("hero_cut", {}).get("fov", 46.0)))
	_set_slider("framing:hero_cut:lateral", float(grammar.framing.get("hero_cut", {}).get("lateral", 9.0)))
	_set_slider("framing:melee_cut:radius", float(grammar.framing.get("melee_cut", {}).get("radius", 26.0)))
	_set_slider("framing:bullet_time:radius", float(grammar.framing.get("bullet_time", {}).get("radius", 32.0)))
	for actor in ["A", "B"]:
		var fp: Dictionary = feel_profiles.get(actor, {}) if feel_profiles.get(actor, {}) is Dictionary else {}
		_set_slider("feel:%s:heft" % actor, float(fp.get("heft", 0.5)))
		_set_slider("feel:%s:tempo" % actor, float(fp.get("tempo", 0.5)))
		if _preset_buttons.has(actor):
			var picker: OptionButton = _preset_buttons[actor]
			var preset := str(fp.get("preset", "custom"))
			var idx := _option_index(picker, preset)
			picker.select(idx if idx >= 0 else 0)
	for mode in _shot_checks.keys():
		var cb: CheckBox = _shot_checks[mode]
		cb.button_pressed = bool(enabled_modes.get(mode, true))
	_suppress = false


func set_metrics_summary(profile: Dictionary) -> void:
	if _metrics_label == null:
		_pending_metrics = profile.duplicate(true)
		return
	var mix: Dictionary = profile.get("weapon_mix", {}) if profile.get("weapon_mix", {}) is Dictionary else {}
	var weapons := mix.keys()
	weapons.sort()
	var finisher: Dictionary = profile.get("finisher", {}) if profile.get("finisher", {}) is Dictionary else {}
	var movement: Dictionary = profile.get("movement_profile", {}) if profile.get("movement_profile", {}) is Dictionary else {}
	_metrics_label.text = "%.1fs | %d atk | %.2f/s | dead %.1fs\nboost %d | heavy %d | def %d\n%s | finish %s%s" % [
		float(profile.get("duration_sec", 0.0)),
		int(profile.get("attack_count", 0)),
		float(profile.get("attack_density_per_sec", 0.0)),
		float(profile.get("longest_dead_air_sec", 0.0)),
		int(movement.get("boost_count", 0)),
		int(profile.get("heavy_beat_count", 0)),
		int(profile.get("defensive_reversal_count", 0)),
		", ".join(weapons),
		str(finisher.get("kind", "none")),
		(" heavy" if bool(finisher.get("heavy", false)) else ""),
	]


func _add_metrics_section(col: VBoxContainer) -> void:
	_add_section_label(col, "Spectacle")
	_metrics_label = Label.new()
	_metrics_label.text = "profile pending"
	_metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_metrics_label.add_theme_font_size_override("font_size", 10)
	_metrics_label.modulate = Color(1, 1, 1, 0.72)
	col.add_child(_metrics_label)


func _add_shot_toggles(col: VBoxContainer) -> void:
	_add_section_label(col, "Shot types")
	var note := Label.new()
	note.text = "iso backbone always fills gaps"
	note.add_theme_font_size_override("font_size", 10)
	note.modulate = Color(1, 1, 1, 0.55)
	col.add_child(note)
	for mode in ["hero_os", "hero_cut", "melee_cut", "bullet_time"]:
		var shot_mode: String = mode
		var cb := CheckBox.new()
		cb.text = shot_mode
		cb.button_pressed = true
		var relay := ShotRelay.new(self, shot_mode)
		_relays.append(relay)
		cb.toggled.connect(Callable(relay, "on_toggled"))
		_shot_checks[shot_mode] = cb
		col.add_child(cb)


func _add_camera_controls(col: VBoxContainer) -> void:
	_add_section_label(col, "Camera")
	_add_slider(col, "OS length", "grammar:os_len", 4.0, 0.4, 4.0, 0.05)
	_add_slider(col, "Cut length", "grammar:cut_len", 4.0, 0.4, 4.0, 0.05)
	_add_slider(col, "Min iso", "grammar:min_iso", 1.0, 0.0, 3.0, 0.05)
	_add_slider(col, "Cam min dur", "grammar:camera_min_duration", 1.5, 0.1, 1.5, 0.05)
	_add_slider(col, "Cam max dur", "grammar:camera_max_duration", 5.0, 0.6, 5.0, 0.05)
	_add_slider(col, "Cam speed", "grammar:camera_speed_scale", 0.25, 0.25, 2.0, 0.05)
	_add_slider(col, "Close cap", "grammar:dolly_cap", 42.0, 10.0, 140.0, 1.0)
	_add_slider(col, "Iso cap", "grammar:iso_dolly_cap", 42.0, 10.0, 140.0, 1.0)
	_add_slider(col, "Melee radius", "grammar:melee_radius_factor", 1.4, 0.7, 3.0, 0.05)
	_add_slider(col, "BT lead", "grammar:bt_pre", 0.2, 0.0, 1.0, 0.025)
	_add_slider(col, "BT hold", "grammar:bt_post", 0.55, 0.05, 2.0, 0.025)
	_add_slider(col, "BT scale", "grammar:bt_scale", 0.07, 0.03, 0.4, 0.005)
	_add_slider(col, "OS FOV", "framing:hero_os:fov", 40.0, 24.0, 75.0, 1.0)
	_add_slider(col, "Cut FOV", "framing:hero_cut:fov", 46.0, 24.0, 75.0, 1.0)
	_add_slider(col, "Cut lateral", "framing:hero_cut:lateral", 9.0, 0.0, 22.0, 0.5)
	_add_slider(col, "Melee orbit", "framing:melee_cut:radius", 26.0, 12.0, 60.0, 1.0)
	_add_slider(col, "Kill orbit", "framing:bullet_time:radius", 32.0, 12.0, 70.0, 1.0)


func _add_actor_controls(col: VBoxContainer, actor: String) -> void:
	_add_section_label(col, "Archetype %s" % actor)
	var note := Label.new()
	note.text = "regenerates weapons + restages motion"
	note.add_theme_font_size_override("font_size", 10)
	note.modulate = Color(1, 1, 1, 0.55)
	col.add_child(note)
	var picker := OptionButton.new()
	picker.add_item("custom")
	var names: Array = GrammarParams.load_presets().keys()
	names.sort()
	for n in names:
		picker.add_item(str(n))
	var relay := PresetRelay.new(self, picker, actor)
	_relays.append(relay)
	picker.item_selected.connect(Callable(relay, "on_item_selected"))
	_preset_buttons[actor] = picker
	col.add_child(picker)
	_add_slider(col, "Heft", "feel:%s:heft" % actor, 0.5, 0.0, 1.0, 0.01)
	_add_slider(col, "Tempo", "feel:%s:tempo" % actor, 0.5, 0.0, 1.0, 0.01)


func _add_section_label(col: VBoxContainer, text: String) -> void:
	col.add_child(HSeparator.new())
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	col.add_child(label)


func _add_slider(col: VBoxContainer, label_text: String, key: String, value: float,
		min_value: float, max_value: float, step: float) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(86, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = _fmt(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(42, 0)
	row.add_child(value_label)
	var relay := SliderRelay.new(self, key)
	_relays.append(relay)
	slider.value_changed.connect(Callable(relay, "on_value_changed"))
	_sliders[key] = slider
	_value_labels[key] = value_label
	col.add_child(row)


func _on_slider_value_changed_key(key: String, value: float) -> void:
	if _value_labels.has(key):
		var value_label: Label = _value_labels[key]
		value_label.text = _fmt(value)
	if _suppress:
		return
	var parts := key.split(":")
	if parts.size() < 2:
		return
	match String(parts[0]):
		"grammar":
			grammar_number_changed.emit(String(parts[1]), value)
		"framing":
			if parts.size() >= 3:
				framing_number_changed.emit(String(parts[1]), String(parts[2]), value)
		"feel":
			if parts.size() >= 3:
				feel_number_changed.emit(String(parts[1]), String(parts[2]), value)


func _on_shot_toggled_key(mode: String, enabled: bool) -> void:
	if _suppress:
		return
	shot_mode_changed.emit(mode, enabled)


func _on_preset_selected_key(picker: OptionButton, actor: String, index: int) -> void:
	if _suppress:
		return
	var preset := picker.get_item_text(index)
	if preset != "custom":
		preset_changed.emit(actor, preset)


func _set_slider(key: String, value: float) -> void:
	if not _sliders.has(key):
		return
	var slider: HSlider = _sliders[key]
	var label: Label = _value_labels[key]
	slider.value = value
	label.text = _fmt(value)


func _option_index(picker: OptionButton, label: String) -> int:
	for i in picker.item_count:
		if picker.get_item_text(i) == label:
			return i
	return -1


func _fmt(value: float) -> String:
	if absf(value) < 10.0:
		return "%.2f" % value
	return "%.1f" % value
