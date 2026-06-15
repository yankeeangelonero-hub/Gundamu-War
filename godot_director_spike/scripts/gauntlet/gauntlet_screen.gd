extends Control
## GauntletScreen — the v0.1 traditional gauntlet loop wrapper.
##
## State machine: PILOT_PICK → SHOP → BUILD (reuses build_screen) → FIGHT →
## RESULT → (back to SHOP for next round, or RUN_OVER).
##
## This node owns the run-level HUD (gold, hearts, round) and the shop rack.
## The existing build_screen is instanced as a child and shown/hidden per phase.
## Pilot pick and run-over screens are drawn inline via _rebuild_ui().

const RunState  := preload("res://scripts/gauntlet/run_state.gd")
const ShopState := preload("res://scripts/gauntlet/shop_state.gd")
const BuildData := preload("res://scripts/build/build_data.gd")
const FightHandoff := preload("res://scripts/build/fight_handoff.gd")

# EXOFRAME palette (matches build_screen).
const VOID     := Color("0a0910")
const PANEL_BG := Color("0d1015")
const LINE     := Color("1d4450")
const CYAN     := Color("9af1ff")
const CYAN5    := Color("28c8e6")
const AMBER    := Color("d9933a")
const RED      := Color("ff5a4a")
const GREEN    := Color("5aa66f")
const TEXT     := Color("c9d6dd")
const DIM      := Color("5d7782")

const PILOT_DATA_PATH := "res://data/pilot_defs.json"

enum Phase { PILOT_PICK, SHOP, RUN_OVER }

var _phase := Phase.PILOT_PICK
var _pilot_defs: Array = []

# UI roots rebuilt per phase.
var _ui_layer: Control
var _hud: Control  # always-visible run HUD (gold/hearts/round)
var _build_layer: CanvasLayer  # houses the build_screen scene when SHOP phase

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_pilot_defs()

	var bg := ColorRect.new()
	bg.color = VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_ui_layer = Control.new()
	_ui_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui_layer)

	# Check if returning from a fight.
	if FightHandoff.active:
		_on_fight_returned()
	elif RunState.active:
		_enter_shop()
	else:
		_enter_pilot_pick()

# ---- pilot defs --------------------------------------------------------------

func _load_pilot_defs() -> void:
	var f := FileAccess.open(PILOT_DATA_PATH, FileAccess.READ)
	if f == null:
		push_warning("pilot_defs.json not found — no pilots available")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and parsed.has("pilots"):
		_pilot_defs = parsed.pilots

# ---- phase transitions -------------------------------------------------------

func _enter_pilot_pick() -> void:
	_phase = Phase.PILOT_PICK
	_rebuild_ui()

func _start_run(pilot_id: String) -> void:
	# Seed from a counter so it's deterministic per-session, not wall-clock.
	var seed_in := (Engine.get_process_frames() * 1664525 + 1013904223) & 0x7FFFFFFF
	RunState.new_run(pilot_id, seed_in)
	ShopState.clear()
	# Grant the pilot's signature item.
	var pilot := _pilot_by_id(pilot_id)
	if not pilot.is_empty():
		ShopState.add_to_inventory(pilot.signature_item)
	_enter_shop()

func _enter_shop() -> void:
	ShopState.begin_round(RunState.seed, RunState.round)
	_phase = Phase.SHOP
	FightHandoff.return_scene = "res://scenes/gauntlet_screen.tscn"
	_rebuild_ui()

func _on_fight_returned() -> void:
	# Determine win or loss from the fight log.
	var events := FightHandoff.events
	var player_won := _player_won(events)
	FightHandoff.clear()
	if player_won:
		RunState.apply_win()
	else:
		RunState.apply_loss()
	RunState.advance_round()
	if RunState.run_over():
		_phase = Phase.RUN_OVER
		_rebuild_ui()
	else:
		_enter_shop()

func _player_won(events: Array) -> bool:
	# Player wins if the last destroyed event is actor "B".
	for i in range(events.size() - 1, -1, -1):
		var e: Dictionary = events[i]
		if e.get("kind", "") == "destroyed":
			return e.get("actor", "") == "B"
	return false  # no destroyed event = treat as loss (overload tie)

# ---- UI build ----------------------------------------------------------------

func _rebuild_ui() -> void:
	for c in _ui_layer.get_children():
		_ui_layer.remove_child(c)
		c.queue_free()

	match _phase:
		Phase.PILOT_PICK: _build_pilot_pick_ui()
		Phase.SHOP:       _build_shop_ui()
		Phase.RUN_OVER:   _build_run_over_ui()

func _build_pilot_pick_ui() -> void:
	var margin := _margin_wrap(_ui_layer, 40)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	v.set_anchors_preset(Control.PRESET_CENTER)
	margin.add_child(v)

	v.add_child(_label("PILOT SELECTION  パイロット選択", 22, CYAN, true))
	v.add_child(_label("Choose your pilot — she defines your starting gear and unique item pool.", 12, DIM, false, true))

	for pilot in _pilot_defs:
		var card := _pilot_card(pilot)
		v.add_child(card)

func _pilot_card(pilot: Dictionary) -> PanelContainer:
	var pc := _panel(LINE)
	var body: VBoxContainer = pc.get_node("body")
	body.add_child(_label(str(pilot.get("name", "?")) + "  ·  " + str(pilot.get("callsign", "")), 16, CYAN, true))
	body.add_child(_label(str(pilot.get("blurb", "")), 11, TEXT, false, true))
	var sig: String = pilot.get("signature_item", "")
	if sig != "":
		var def := BuildData.get_def(sig)
		body.add_child(_label("Signature: " + str(def.get("name", sig)), 11, AMBER))
	var btn := _button("SELECT " + str(pilot.get("name", "?")), GREEN)
	var pid: String = pilot.get("id", "")
	btn.pressed.connect(func(): _start_run(pid))
	body.add_child(btn)
	return pc

func _build_shop_ui() -> void:
	# Run HUD strip at top.
	_build_hud(_ui_layer)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % s, 14)
	# push below HUD
	margin.add_theme_constant_override("margin_top", 60)
	_ui_layer.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(_label("SHOP  商店  —  ROUND %d / %d" % [RunState.round, RunState.WIN_ROUND], 16, CYAN, true))

	# Shop rack.
	var rack_h := HBoxContainer.new()
	rack_h.add_theme_constant_override("separation", 10)
	root.add_child(rack_h)
	for i in ShopState.shop_offers.size():
		rack_h.add_child(_offer_card(i))

	# Reroll button.
	var reroll_btn := _button("⟳  REROLL  (%d⊙)" % ShopState.REROLL_COST, CYAN5)
	reroll_btn.pressed.connect(_on_reroll)
	root.add_child(reroll_btn)

	# Inventory.
	root.add_child(_label("INVENTORY  在庫  (%d items)" % ShopState.inventory.size(), 12, DIM))
	var inv_h := HBoxContainer.new()
	inv_h.add_theme_constant_override("separation", 8)
	root.add_child(inv_h)
	for iid in ShopState.inventory:
		inv_h.add_child(_inventory_card(iid))

	# Enter build / deploy.
	var build_btn := _button("出撃  ENTER BUILD & DEPLOY", RED)
	build_btn.pressed.connect(_on_enter_build)
	root.add_child(build_btn)

func _offer_card(idx: int) -> PanelContainer:
	var offer: Dictionary = ShopState.shop_offers[idx]
	var def := BuildData.get_def(offer.def_id)
	var pc := _panel(LINE)
	pc.custom_minimum_size = Vector2(160, 0)
	var body: VBoxContainer = pc.get_node("body")
	var cat := BuildData.category(def.get("kind", ""))
	body.add_child(_label(str(def.get("name", "?")), 13, Color(cat.color), true))
	body.add_child(_label(str(def.get("kind", "")).to_upper(), 9, DIM))
	body.add_child(_label("%d⊙" % offer.price, 16, AMBER, true))
	var afford: bool = RunState.gold >= offer.price
	var btn := _button("BUY", GREEN if afford else DIM)
	btn.disabled = not afford
	btn.pressed.connect(func(): _on_buy(idx))
	body.add_child(btn)
	return pc

func _inventory_card(iid: String) -> PanelContainer:
	var def_id: String = ShopState.item_def_id(iid)
	var def := BuildData.get_def(def_id)
	var pc := _panel(LINE)
	pc.custom_minimum_size = Vector2(130, 0)
	var body: VBoxContainer = pc.get_node("body")
	var cat := BuildData.category(def.get("kind", ""))
	body.add_child(_label(str(def.get("name", "?")), 11, Color(cat.color), true))
	var price: int = BuildData.get_def(def_id).get("price", 4)
	var refund := int(floor(price * ShopState.SELL_FRACTION))
	var sell_btn := _button("SELL (%d⊙)" % refund, AMBER)
	sell_btn.pressed.connect(func(): _on_sell(iid))
	body.add_child(sell_btn)
	return pc

func _build_run_over_ui() -> void:
	var margin := _margin_wrap(_ui_layer, 60)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	v.set_anchors_preset(Control.PRESET_CENTER)
	margin.add_child(v)

	if RunState.run_won():
		v.add_child(_label("VICTORY  勝利", 36, GREEN, true))
		v.add_child(_label("You survived %d rounds. The war goes on." % RunState.WIN_ROUND, 14, TEXT, false, true))
	else:
		v.add_child(_label("RUN OVER  敗北", 36, RED, true))
		v.add_child(_label("Lost all hearts on round %d." % RunState.round, 14, TEXT, false, true))

	var again := _button("NEW RUN  再出撃", CYAN)
	again.pressed.connect(_on_new_run)
	v.add_child(again)

func _build_hud(parent: Node) -> void:
	var hud := _panel(LINE)
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.custom_minimum_size = Vector2(0, 48)
	parent.add_child(hud)
	var body: VBoxContainer = hud.get_node("body")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	body.add_child(h)
	h.add_child(_label("ROUND  %d/%d" % [RunState.round, RunState.WIN_ROUND], 13, CYAN, true))
	h.add_child(_label("GOLD  %d⊙" % RunState.gold, 13, AMBER, true))
	var hearts_str := "♥".repeat(RunState.hearts) + "♡".repeat(maxi(0, RunState.STARTING_HEARTS - RunState.hearts))
	h.add_child(_label("HEARTS  " + hearts_str, 13, RED, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	var pilot := _pilot_by_id(RunState.pilot_id)
	if not pilot.is_empty():
		h.add_child(_label(str(pilot.get("name", "")) + "  ·  " + str(pilot.get("callsign", "")), 11, DIM))

# ---- interactions ------------------------------------------------------------

func _on_buy(offer_idx: int) -> void:
	var result := ShopState.buy(offer_idx, RunState.gold)
	if result.ok:
		RunState.gold -= result.gold_spent
		_rebuild_ui()

func _on_sell(iid: String) -> void:
	var result := ShopState.sell(iid)
	if result.ok:
		RunState.gold += result.gold_gained
		_rebuild_ui()

func _on_reroll() -> void:
	var cost := ShopState.reroll(RunState.gold)
	if cost >= 0:
		RunState.gold -= cost
		_rebuild_ui()

func _on_enter_build() -> void:
	# Persist inventory into FightHandoff so build_screen can restore items after fight.
	# The build_screen launches the fight; we come back via FightHandoff.return_scene.
	get_tree().change_scene_to_file("res://scenes/build_screen.tscn")

func _on_new_run() -> void:
	RunState.clear()
	ShopState.clear()
	_enter_pilot_pick()

# ---- helpers -----------------------------------------------------------------

func _pilot_by_id(pid: String) -> Dictionary:
	for p in _pilot_defs:
		if p.get("id", "") == pid:
			return p
	return {}

func _margin_wrap(parent: Node, margin: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_%s" % s, margin)
	parent.add_child(m)
	return m

# ---- styled-widget factory (matches build_screen palette) --------------------

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

func _label(text: String, fsize: int, col: Color, bold := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(400, 0)
	return l

func _button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", accent)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent, 0.10)
	normal.set_border_width_all(1)
	normal.border_color = Color(accent, 0.7)
	normal.set_content_margin_all(7)
	var hov := normal.duplicate()
	hov.bg_color = Color(accent, 0.22)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(accent, 0.32)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
	return b
