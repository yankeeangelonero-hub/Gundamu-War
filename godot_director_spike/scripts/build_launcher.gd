extends CanvasLayer
## First playable M0 bridge UI: pick a player kit, opponent preset, chaos, then Fight.

signal fight_requested(player_kit_id, opponent_id, chaos, seed)

const LoadoutGenerator := preload("res://scripts/sim/loadout_fight_generator.gd")

var _catalog: Dictionary = {}
var _kit_picker: OptionButton
var _opponent_picker: OptionButton
var _chaos_slider: HSlider
var _chaos_label: Label
var _summary_label: Label
var _profile_label: Label
var _grid: GridContainer
var _kit_ids: Array = []
var _opponent_ids: Array = []
var _seed := 77

func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_catalog = LoadoutGenerator.load_catalog()
	_build_ui()
	_refresh_summary()


func set_profile(profile: Dictionary) -> void:
	if _profile_label == null:
		return
	_profile_label.text = "Last fight\n%s" % profile.get("summary", "")


func _build_ui() -> void:
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = Vector2(18, 18)
	root.custom_minimum_size = Vector2(380, 0)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	root.add_child(col)

	var title := Label.new()
	title.text = "KITBASH MECHA"
	title.add_theme_font_size_override("font_size", 20)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "choose a kit, pick a ghost, press Fight"
	sub.modulate = Color(1, 1, 1, 0.62)
	sub.add_theme_font_size_override("font_size", 11)
	col.add_child(sub)

	_add_picker_row(col)
	_add_chaos_row(col)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.custom_minimum_size = Vector2(250, 160)
	col.add_child(_grid)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 12)
	col.add_child(_summary_label)

	var fight := Button.new()
	fight.text = "Fight"
	fight.custom_minimum_size = Vector2(0, 36)
	fight.pressed.connect(_on_fight_pressed)
	col.add_child(fight)

	_profile_label = Label.new()
	_profile_label.text = "Last fight\nnone yet"
	_profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_label.modulate = Color(1, 1, 1, 0.72)
	_profile_label.add_theme_font_size_override("font_size", 11)
	col.add_child(_profile_label)


func _add_picker_row(col: VBoxContainer) -> void:
	var kit_label := Label.new()
	kit_label.text = "Player kit"
	col.add_child(kit_label)
	_kit_picker = OptionButton.new()
	var kits: Dictionary = _catalog.get("kits", {})
	_kit_ids = kits.keys()
	_kit_ids.sort()
	for id in _kit_ids:
		var kit: Dictionary = kits[id]
		_kit_picker.add_item(str(kit.get("name", id)))
	_kit_picker.item_selected.connect(func(_idx: int) -> void: _refresh_summary())
	col.add_child(_kit_picker)

	var opp_label := Label.new()
	opp_label.text = "Opponent ghost"
	col.add_child(opp_label)
	_opponent_picker = OptionButton.new()
	var opponents: Dictionary = _catalog.get("opponents", {})
	_opponent_ids = opponents.keys()
	_opponent_ids.sort()
	for id in _opponent_ids:
		var opp: Dictionary = opponents[id]
		_opponent_picker.add_item(str(opp.get("name", id)))
	_opponent_picker.select(_option_index_for_id(_opponent_ids, "artillery_ghost"))
	_opponent_picker.item_selected.connect(func(_idx: int) -> void: _refresh_summary())
	col.add_child(_opponent_picker)


func _add_chaos_row(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Chaos"
	label.custom_minimum_size = Vector2(58, 0)
	row.add_child(label)
	_chaos_slider = HSlider.new()
	_chaos_slider.min_value = 0.0
	_chaos_slider.max_value = 1.0
	_chaos_slider.step = 0.05
	_chaos_slider.value = 0.5
	_chaos_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chaos_slider.value_changed.connect(func(_v: float) -> void: _refresh_summary())
	row.add_child(_chaos_slider)
	_chaos_label = Label.new()
	_chaos_label.custom_minimum_size = Vector2(42, 0)
	_chaos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_chaos_label)
	col.add_child(row)


func _refresh_summary() -> void:
	if _kit_picker == null or _summary_label == null:
		return
	var kit := _selected_kit()
	var pilot: Dictionary = _catalog.get("pilots", {}).get("pilot_aya", {})
	_chaos_label.text = "%.2f" % float(_chaos_slider.value)
	_draw_grid(kit)
	var intent: Dictionary = kit.get("spectacle_intent", {}) if kit.get("spectacle_intent", {}) is Dictionary else {}
	_summary_label.text = "Pilot %s '%s'\n%s\n%s\nHP %d | weapons %d" % [
		str(pilot.get("name", "Pilot")),
		str(pilot.get("callsign", "")),
		str(kit.get("name", "")),
		str(intent.get("summary", "")),
		int(kit.get("hp", 0)),
		(kit.get("weapons", []) as Array).size(),
	]


func _draw_grid(kit: Dictionary) -> void:
	for child in _grid.get_children():
		child.queue_free()
	var cells := []
	for i in range(20):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(48, 30)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		panel.add_child(label)
		cells.append({"panel": panel, "label": label})
		_grid.add_child(panel)
	for item in (kit.get("grid", []) as Array):
		var rect: Dictionary = item
		for yy in range(int(rect.get("h", 1))):
			for xx in range(int(rect.get("w", 1))):
				var x := int(rect.get("x", 0)) + xx
				var y := int(rect.get("y", 0)) + yy
				var idx := y * 5 + x
				if idx < 0 or idx >= cells.size():
					continue
				var cell: Dictionary = cells[idx]
				var panel: PanelContainer = cell.panel
				var label: Label = cell.label
				var style := StyleBoxFlat.new()
				style.bg_color = _color_for_kind(str(rect.get("kind", "")))
				style.border_color = Color(0.08, 0.10, 0.12)
				style.set_border_width_all(1)
				panel.add_theme_stylebox_override("panel", style)
				if xx == 0 and yy == 0:
					label.text = str(rect.get("label", rect.get("kind", ""))).substr(0, 5)


func _color_for_kind(kind: String) -> Color:
	match kind:
		"reactor": return Color(0.25, 0.55, 0.95)
		"weapon": return Color(0.86, 0.28, 0.23)
		"support": return Color(0.35, 0.72, 0.42)
		"booster": return Color(0.92, 0.65, 0.20)
		_: return Color(0.18, 0.20, 0.24)


func _on_fight_pressed() -> void:
	fight_requested.emit(_selected_kit_id(), _selected_opponent_id(), float(_chaos_slider.value), _seed)
	_seed += 1


func _selected_kit_id() -> String:
	if _kit_ids.is_empty():
		return ""
	return str(_kit_ids[_kit_picker.selected])


func _selected_opponent_id() -> String:
	if _opponent_ids.is_empty():
		return ""
	return str(_opponent_ids[_opponent_picker.selected])


func _selected_kit() -> Dictionary:
	var kits: Dictionary = _catalog.get("kits", {})
	return kits.get(_selected_kit_id(), {})


func _option_index_for_id(ids: Array, id: String) -> int:
	for i in ids.size():
		if str(ids[i]) == id:
			return i
	return 0
