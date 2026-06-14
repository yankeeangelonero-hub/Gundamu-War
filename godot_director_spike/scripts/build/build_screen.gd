extends Control
## BuildScreen — the M1 build editor, dressed in the EXOFRAME "Mech Bags Workshop"
## language (adapted from the approved Claude design). Three-column command bay:
## left readouts, centre bag viewscreen, right dev palette. All mechanics come from
## the pure BuildGrid / BuildResolver; this node is presentation + interaction only.

const BuildData := preload("build_data.gd")
const BuildGrid := preload("build_grid.gd")
const BuildResolver := preload("build_resolver.gd")
const GridView := preload("build_grid_view.gd")
const MechView := preload("build_mech_view.gd")
const BuildFightSim := preload("build_fight_sim.gd")
const OpponentSource := preload("opponent_source.gd")
const FightHandoff := preload("fight_handoff.gd")

# EXOFRAME signal palette.
const VOID := Color("0a0910")
const PANEL_BG := Color("0d1015")
const LINE := Color("1d4450")
const CYAN := Color("9af1ff")
const CYAN5 := Color("28c8e6")
const AMBER := Color("d9933a")
const RED := Color("ff5a4a")
const GREEN := Color("5aa66f")
const TEXT := Color("c9d6dd")
const DIM := Color("5d7782")

var grid := BuildGrid.new()
var held: Dictionary = {}        # { iid, def_id } currently in hand, or {}
var held_rot := 0
var hover := Vector2i(-9, -9)
var selected := ""               # placed iid, or ""
var _iid := 0
var _result: Dictionary = {}
var _voice := "Lay it out smart — adjacency is everything."
var _voice_warn := false

var _grid_view: Control
var _mech_view: Control
var _readouts: VBoxContainer
var _palette_box: VBoxContainer
var _log_label: Label
var _cells_label: Label
var _pool_label: Label
var _palette_rows: Array = []    # [{ def_id, button }]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % s, 14)
	add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	margin.add_child(root_v)

	_build_topbar(root_v)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(body)

	_build_left(body)
	_build_center(body)
	_build_right(body)

	_restore_saved_build()
	_refresh()

## Rebuild the bag the player deployed, so returning from a fight lands on the same build.
func _restore_saved_build() -> void:
	for e in FightHandoff.saved_placement:
		_iid += 1
		grid.place("i%d" % _iid, e.def_id, int(e.rot), e.anchor)
	if not FightHandoff.saved_placement.is_empty():
		_say("Back from the sortie. Refit and redeploy.", false)

# ---- top command bar ---------------------------------------------------------

func _build_topbar(parent: Node) -> void:
	var bar := _panel(LINE)
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	bar.get_node("body").add_child(h)

	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	h.add_child(brand)
	brand.add_child(_label("MECH BAGS // WORKSHOP", 18, CYAN, true))
	brand.add_child(_label("鞄装 · BACKPACK ENGINEERING BAY", 10, DIM))

	var logs := VBoxContainer.new()
	logs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logs.add_theme_constant_override("separation", 1)
	h.add_child(logs)
	logs.add_child(_label('MMI// link established · pilot "VESPER-7" · bag-build protocol', 10, DIM))
	_log_label = _label("MMI// " + _voice, 10, CYAN)
	logs.add_child(_log_label)

	var counters := HBoxContainer.new()
	counters.add_theme_constant_override("separation", 16)
	h.add_child(counters)
	_cells_label = _counter("CELLS", "0/20", CYAN)
	_pool_label = _counter("POWER", "0", AMBER)
	counters.add_child(_cells_label.get_parent())
	counters.add_child(_pool_label.get_parent())

func _counter(label: String, value: String, col: Color) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(_label(label, 8, DIM))
	var val := _label(value, 22, col, true)
	v.add_child(val)
	return val

# ---- left readout rail (rebuilt on every change) -----------------------------

func _build_left(parent: Node) -> void:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(296, 0)
	col.add_theme_constant_override("separation", 10)
	parent.add_child(col)
	_readouts = VBoxContainer.new()
	_readouts.add_theme_constant_override("separation", 10)
	_readouts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_readouts)

	var deploy := _button("出撃  DEPLOY SORTIE", RED)
	deploy.pressed.connect(_on_deploy)
	col.add_child(deploy)
	var reset := _button("RESET BAG", DIM)
	reset.pressed.connect(_on_reset)
	col.add_child(reset)

func _rebuild_readouts() -> void:
	for c in _readouts.get_children():
		_readouts.remove_child(c)
		c.queue_free()

	if not held.is_empty():
		_panel_holding()
	elif selected != "":
		_panel_selected()
	else:
		_panel_totals()

	_panel_synergies()
	_panel_in_bag()

func _panel_holding() -> void:
	var def := BuildData.get_def(held.def_id)
	var p := _titled("HOLDING", def.code, CYAN)
	var body: VBoxContainer = p.get_node("body")
	body.add_child(_label(str(def.name).to_upper(), 15, TEXT, true))
	var kind: String = def.get("kind", "")
	var hint := "click a cell to seat it" if kind != "support" else "click a cell — amber = its buff-slots"
	body.add_child(_label("▸ " + hint, 10, CYAN5, false, true))
	body.add_child(_label("R rotate · right-click or ESC to put back", 9, DIM, false, true))
	var putback := _button("✕ PUT BACK", AMBER)
	putback.pressed.connect(_cancel_held)
	body.add_child(putback)
	_readouts.add_child(p)

func _panel_selected() -> void:
	var entry := _placed(selected)
	var def := BuildData.get_def(entry.def_id)
	var p := _titled("SELECTED", def.code, AMBER)
	var body: VBoxContainer = p.get_node("body")
	body.add_child(_label(str(def.name).to_upper(), 15, TEXT, true))
	match def.get("kind", ""):
		"spender":
			var e: Dictionary = _result.weapons.get(selected, {})
			_kv(body, "Base damage", str(e.get("base_damage", 0)), DIM)
			_kv(body, "Effective DMG", str(e.get("damage", 0)), GREEN if e.get("buffed", false) else RED)
			_kv(body, "Power / shot", str(e.get("cost", 0)), AMBER)
			_kv(body, "Cadence", "%ss" % def.get("cadence", 0), CYAN)
		"builder":
			_kv(body, "Pool", "+%d" % int(def.get("pool", 0)), CYAN)
			_kv(body, "Regen", "+%d" % int(def.get("regen", 0)), CYAN)
		"support":
			if int(def.get("flat_added", 0)) != 0:
				_kv(body, "Flat added", "+%d" % int(def.flat_added), GREEN)
			if float(def.get("increased", 0)) != 0.0:
				_kv(body, "Increased", "+%d%%" % roundi(float(def.increased) * 100), GREEN)
			if float(def.get("more", 0)) != 0.0:
				_kv(body, "More", "%d%%" % roundi(float(def.more) * 100), AMBER)
			_kv(body, "Cost ×", "%.2f" % float(def.get("cost_multiplier", 1.0)), RED)
	var detach := _button("DETACH", RED)
	detach.pressed.connect(_on_detach)
	body.add_child(detach)
	_readouts.add_child(p)

func _panel_totals() -> void:
	var p := _titled("BUILD TOTALS", "機体諸元", CYAN)
	var body: VBoxContainer = p.get_node("body")
	var t: Dictionary = _result.totals
	_kv(body, "Power pool", str(t.pool), CYAN)
	_kv(body, "Power regen", "%s /s" % t.regen, CYAN)
	_kv(body, "Firepower", str(t.firepower), RED)
	_kv(body, "Burst draw", str(t.burst_cost), AMBER)
	_kv(body, "Weapons", str(t.weapon_count), TEXT)
	if t.weapon_count == 0:
		body.add_child(_label("警告 UNARMED — no weapons in the bag", 10, RED, false, true))
	_readouts.add_child(p)

func _panel_synergies() -> void:
	var syn: Array = _result.synergies
	var p := _titled("SYNERGIES", str(syn.size()), AMBER)
	var body: VBoxContainer = p.get_node("body")
	if syn.is_empty():
		body.add_child(_label("none — set supports beside weapons", 10, DIM, false, true))
	for s in syn:
		body.add_child(_label("▸ " + s.text, 10, TEXT, false, true))
	_readouts.add_child(p)

func _panel_in_bag() -> void:
	var p := _titled("IN THE BAG", str(grid.placed.size()), CYAN)
	var body: VBoxContainer = p.get_node("body")
	if grid.placed.is_empty():
		body.add_child(_label("empty bag — nothing placed", 10, DIM, false, true))
	for entry in grid.placed:
		var def := BuildData.get_def(entry.def_id)
		var cat := BuildData.category(def.get("kind", ""))
		var row := _button("  " + str(def.name), Color(cat.color))
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(func(): _select(entry.iid))
		body.add_child(row)
	_readouts.add_child(p)

# ---- centre viewscreen -------------------------------------------------------

func _build_center(parent: Node) -> void:
	var p := _panel(LINE)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var body: VBoxContainer = p.get_node("body")

	var head := HBoxContainer.new()
	head.add_child(_label("FRAME VIEW 機体  ·  BAG ASSEMBLY 鞄組立", 11, DIM))
	body.add_child(head)

	# stage: the 3D frame on the left, the bag grid on the right.
	var stage := HBoxContainer.new()
	stage.add_theme_constant_override("separation", 10)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(stage)

	_mech_view = MechView.new()
	_mech_view.custom_minimum_size = Vector2(360, 0)
	_mech_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mech_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(_mech_view)

	var gwrap := CenterContainer.new()
	gwrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(gwrap)
	_grid_view = GridView.new()
	_grid_view._grid = grid
	_grid_view.cell_clicked.connect(_on_cell_clicked)
	_grid_view.cell_hovered.connect(_on_cell_hovered)
	gwrap.add_child(_grid_view)

	body.add_child(_label("pick a part from the rack → click an owned cell · R rotates · weapons mount on the frame", 10, DIM, false, true))

# ---- right palette rail ------------------------------------------------------

func _build_right(parent: Node) -> void:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(300, 0)
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)
	col.add_child(_label("DEV PALETTE 商店", 11, DIM))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_palette_box = VBoxContainer.new()
	_palette_box.add_theme_constant_override("separation", 6)
	_palette_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_palette_box)

	var last_kind := ""
	for def_id in BuildData.dev_palette():
		var def := BuildData.get_def(def_id)
		var kind: String = def.get("kind", "")
		if kind != last_kind:
			last_kind = kind
			var cat := BuildData.category(kind)
			_palette_box.add_child(_label(str(cat.label).to_upper(), 10, Color(cat.color)))
		_palette_box.add_child(_palette_card(def_id, def))

func _palette_card(def_id: String, def: Dictionary) -> Button:
	var cat := BuildData.category(def.get("kind", ""))
	var sp := BuildData.span(def, 0)
	var line := ""
	match def.get("kind", ""):
		"spender": line = "DMG %s · PWR %s · %ss" % [def.base_damage, def.base_power_cost, def.cadence]
		"builder": line = "+%d POOL · +%d REGEN" % [int(def.pool), int(def.regen)]
		"support": line = BuildResolver._mod_text(def)
	var b := Button.new()
	b.text = "%s   %d×%d\n%s" % [str(def.name), sp.x, sp.y, line]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(cat.color))
	_style_button(b, Color(cat.color))
	b.pressed.connect(func(): _arm(def_id))
	_palette_rows.append({"def_id": def_id, "button": b})
	return b

# ---- interaction -------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and not held.is_empty():
			held_rot = (held_rot + 1) % 4
			_refresh()
		elif event.keycode == KEY_ESCAPE and not held.is_empty():
			_cancel_held()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT and not held.is_empty():
		_cancel_held()
		get_viewport().set_input_as_handled()

func _arm(def_id: String) -> void:
	# click the same rack card again to put the held part back down
	if not held.is_empty() and held.def_id == def_id:
		_cancel_held()
		return
	_iid += 1
	held = {"iid": "i%d" % _iid, "def_id": def_id}
	held_rot = 0
	selected = ""
	var def := BuildData.get_def(def_id)
	_say("Holding the %s. Drop it where it'll buddy up." % def.name, false)
	_refresh()

func _cancel_held() -> void:
	held = {}
	_say("Put it back. Pick another part from the rack.", false)
	_refresh()

func _on_cell_clicked(cell: Vector2i) -> void:
	if not held.is_empty():
		var entry := grid.place(held.iid, held.def_id, held_rot, cell)
		if entry.is_empty():
			_say("Won't fit there — needs empty cells inside the grid.", true)
			_refresh()
			return
		var def := BuildData.get_def(held.def_id)
		_grid_view.snap_at(cell)
		_say("%s seated." % def.name, false)
		selected = held.iid
		held = {}
		_refresh()
	else:
		var iid := grid.item_at(cell)
		_select(iid if iid != selected else "")

func _on_cell_hovered(cell: Vector2i) -> void:
	hover = cell
	_grid_view.set_view(grid, _result.get("weapons", {}), _held_def(), held_rot, hover, selected)

func _select(iid: String) -> void:
	selected = iid
	held = {}
	_refresh()

func _on_detach() -> void:
	if selected == "":
		return
	var def := BuildData.get_def(_placed(selected).def_id)
	grid.remove(selected)
	selected = ""
	_say("Pulled the %s — back in the bin." % def.name, false)
	_refresh()

func _on_reset() -> void:
	grid.clear()
	held = {}
	selected = ""
	_say("Cleared the bag. Fresh layout.", false)
	_refresh()

func _on_deploy() -> void:
	if _result.totals.weapon_count == 0:
		_say("Can't sortie unarmed — slot a weapon first.", true)
		_refresh()
		return
	# Resolve both builds, run the deterministic duel, and hand the log to the viewer.
	var player_build := BuildFightSim.build_from_placement(grid.placed)
	var pick := int(Time.get_ticks_msec())
	var ghost: Dictionary = OpponentSource.get_ghost(pick)
	var ghost_build := BuildFightSim.build_from_placement(ghost.placement)
	var events := BuildFightSim.simulate(player_build, ghost_build, pick)
	# persist the bag so we return to this exact build after the fight
	var snap: Array = []
	for p in grid.placed:
		snap.append({"def_id": p.def_id, "rot": p.rot, "anchor": p.anchor})
	FightHandoff.saved_placement = snap
	FightHandoff.player_placement = snap                 # mounted on the fighting mech
	FightHandoff.ghost_placement = ghost.placement       # mounted on the enemy mech
	FightHandoff.set_fight(events, "VESPER-7", str(ghost.get("callsign", "GHOST")))
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ---- refresh -----------------------------------------------------------------

func _refresh() -> void:
	_result = BuildResolver.resolve(grid.placed)
	_grid_view.set_view(grid, _result.weapons, _held_def(), held_rot, hover, selected)
	if _mech_view:
		_mech_view.set_loadout(grid.placed)
	_rebuild_readouts()

	var used := 0
	for entry in grid.placed:
		used += entry.cells.size()
	_cells_label.text = "%d/%d" % [used, BuildGrid.COLS * BuildGrid.ROWS]
	_pool_label.text = str(_result.totals.pool)
	_log_label.text = ("WARN// " if _voice_warn else "MMI// ") + _voice
	_log_label.add_theme_color_override("font_color", AMBER if _voice_warn else CYAN)

	for row in _palette_rows:
		var armed: bool = not held.is_empty() and held.def_id == row.def_id
		row.button.modulate = Color(1.3, 1.3, 1.3) if armed else Color.WHITE

func _held_def() -> Dictionary:
	return BuildData.get_def(held.def_id) if not held.is_empty() else {}

func _placed(iid: String) -> Dictionary:
	for entry in grid.placed:
		if entry.iid == iid:
			return entry
	return {}

func _say(line: String, warn: bool) -> void:
	_voice = line
	_voice_warn = warn

# ---- styled-widget factory ---------------------------------------------------

func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_border_width_all(1)
	sb.border_color = LINE
	sb.set_content_margin_all(10)
	return sb

func _panel(_accent: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style())
	var body := VBoxContainer.new()
	body.name = "body"
	body.add_theme_constant_override("separation", 6)
	pc.add_child(body)
	return pc

func _titled(title: String, meta: String, accent: Color) -> PanelContainer:
	var pc := _panel(accent)
	var body: VBoxContainer = pc.get_node("body")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var dot := ColorRect.new()
	dot.color = accent
	dot.custom_minimum_size = Vector2(4, 14)
	head.add_child(dot)
	head.add_child(_label(title, 11, accent, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_label(meta, 10, DIM))
	body.add_child(head)
	var rule := ColorRect.new()
	rule.color = LINE
	rule.custom_minimum_size = Vector2(0, 1)
	body.add_child(rule)
	return pc

func _label(text: String, fsize: int, col: Color, bold := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(260, 0)
	return l

func _kv(parent: Node, label: String, value: String, col: Color) -> void:
	var h := HBoxContainer.new()
	var l := _label(label, 11, DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(_label(value, 13, col, true))
	parent.add_child(h)

func _button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", accent)
	_style_button(b, accent)
	return b

func _style_button(b: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent, 0.10)
	normal.set_border_width_all(1)
	normal.border_color = Color(accent, 0.7)
	normal.set_content_margin_all(7)
	var hover := normal.duplicate()
	hover.bg_color = Color(accent, 0.22)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(accent, 0.32)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
