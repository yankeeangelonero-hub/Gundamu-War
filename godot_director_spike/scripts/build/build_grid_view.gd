extends Control
## BuildGridView — the EXOFRAME "bag viewscreen": pure presentation of the build
## grid. Draws owned cells, placed item plates with their effective numbers, the
## held-item ghost + buff-slot overlay, and a glow on supported weapons. All state
## is pushed in from BuildScreen via set_view(); this node owns no game logic.

const BuildData := preload("build_data.gd")

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)

const CELL := 64
const PAD := 6

# EXOFRAME signal palette.
const VOID := Color("0a0910")
const GRID_LINE := Color("17343d")
const CELL_OWNED := Color("0e151a")
const CYAN := Color("9af1ff")
const CYAN_DIM := Color("2a6f80")
const AMBER := Color("d9933a")
const RED := Color("ff5a4a")
const GREEN := Color("5aa66f")

var _grid: RefCounted          # BuildGrid
var _eff: Dictionary = {}      # iid -> effective {damage,cost,buffed,...}
var _held_def: Dictionary = {}
var _held_rot := 0
var _hover := Vector2i(-9, -9)
var _selected := ""
var _ring_t := -1.0            # snap-ring animation clock (<0 = idle)
var _ring_cell := Vector2i.ZERO

var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(_grid_cols() * CELL + PAD * 2, _grid_rows() * CELL + PAD * 2)

func _grid_cols() -> int:
	return _grid.COLS if _grid else 5

func _grid_rows() -> int:
	return _grid.ROWS if _grid else 4

func set_view(grid: RefCounted, eff: Dictionary, held_def: Dictionary, held_rot: int,
		hover: Vector2i, selected: String) -> void:
	_grid = grid
	_eff = eff
	_held_def = held_def
	_held_rot = held_rot
	_hover = hover
	_selected = selected
	queue_redraw()

func snap_at(cell: Vector2i) -> void:
	_ring_cell = cell
	_ring_t = 0.0
	set_process(true)

func _process(delta: float) -> void:
	if _ring_t < 0.0:
		set_process(false)
		return
	_ring_t += delta
	if _ring_t > 0.45:
		_ring_t = -1.0
	queue_redraw()

# ---- pixel <-> cell ----------------------------------------------------------

func _origin() -> Vector2:
	var gw := _grid_cols() * CELL
	var gh := _grid_rows() * CELL
	return Vector2((size.x - gw) * 0.5, (size.y - gh) * 0.5)

func _cell_rect(cell: Vector2i) -> Rect2:
	var o := _origin()
	return Rect2(o.x + cell.y * CELL, o.y + cell.x * CELL, CELL, CELL)

func _cell_at(pos: Vector2) -> Vector2i:
	var o := _origin()
	var c := int(floor((pos.x - o.x) / CELL))
	var r := int(floor((pos.y - o.y) / CELL))
	return Vector2i(r, c)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		if cell != _hover:
			cell_hovered.emit(cell)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cell_clicked.emit(_cell_at(event.position))

# ---- drawing -----------------------------------------------------------------

func _draw() -> void:
	if _grid == null:
		return
	var rows := _grid_rows()
	var cols := _grid_cols()

	# owned cells + grid lines
	for r in rows:
		for c in cols:
			var rect := _cell_rect(Vector2i(r, c))
			draw_rect(rect.grow(-1), CELL_OWNED, true)
			draw_rect(rect.grow(-1), GRID_LINE, false, 1.0)

	_draw_placeable_hint()
	_draw_buff_overlay()        # selected support's authored buff-slots
	_draw_placed()
	_draw_ghost()
	_draw_ring()

# cells where the held item could legally seat → faint pulse.
func _draw_placeable_hint() -> void:
	if _held_def.is_empty():
		return
	var pulse := 0.10 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.006)
	for r in _grid_rows():
		for c in _grid_cols():
			var anc := Vector2i(r, c)
			if _grid.can_place(_held_def, _held_rot, anc):
				for cell in BuildData.placed_cells(_held_def, _held_rot, anc):
					draw_rect(_cell_rect(cell).grow(-2), Color(CYAN, pulse), true)

func _draw_buff_overlay() -> void:
	if _selected == "":
		return
	var entry := _placed_by_iid(_selected)
	if entry.is_empty():
		return
	var def := BuildData.get_def(entry.def_id)
	if def.get("kind", "") != "support":
		return
	for cell in BuildData.buff_cells(def, entry.rot, entry.anchor):
		if _grid.in_grid(cell):
			var rect := _cell_rect(cell).grow(-3)
			draw_rect(rect, Color(AMBER, 0.10), true)
			draw_rect(rect, Color(AMBER, 0.7), false, 1.0)

func _draw_placed() -> void:
	for p in _grid.placed:
		var def := BuildData.get_def(p.def_id)
		var cat := BuildData.category(def.get("kind", ""))
		var col := Color(cat.color)
		var b := _bounds(p.cells)
		var rect := Rect2(_cell_rect(Vector2i(b.position.x, b.position.y)).position,
			Vector2(b.size.y * CELL, b.size.x * CELL)).grow(-3)
		var focused: bool = p.iid == _selected
		var buffed: bool = _eff.has(p.iid) and _eff[p.iid].get("buffed", false)

		draw_rect(rect, Color(col, 0.16), true)
		var border_col := CYAN if focused else (Color(GREEN) if buffed else col)
		draw_rect(rect, border_col, false, 2.0 if (focused or buffed) else 1.0)
		# corner accent bar
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), col, true)

		# name + code
		draw_string(_font, rect.position + Vector2(6, 18), str(def.name).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 12, Color(0.92, 0.96, 1.0))
		draw_string(_font, rect.position + Vector2(6, rect.size.y - 6), str(def.code),
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 9, Color(CYAN_DIM))

		# per-item numbers (spec §3: per-item readouts on the grid)
		if def.get("kind", "") == "spender" and _eff.has(p.iid):
			var e: Dictionary = _eff[p.iid]
			var dmg_col := Color(GREEN) if buffed else RED
			draw_string(_font, rect.position + Vector2(6, 34),
				"DMG %d" % roundi(e.damage), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 12, dmg_col)
			draw_string(_font, rect.position + Vector2(6, 49),
				"PWR %d" % roundi(e.cost), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 11, AMBER)
		elif def.get("kind", "") == "builder":
			draw_string(_font, rect.position + Vector2(6, 36),
				"+%d POOL" % int(def.get("pool", 0)), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 11, CYAN)
			draw_string(_font, rect.position + Vector2(6, 50),
				"+%d REGEN" % int(def.get("regen", 0)), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 10, Color(CYAN_DIM))

func _draw_ghost() -> void:
	if _held_def.is_empty() or not _grid.in_grid(_hover):
		return
	var ok: bool = _grid.can_place(_held_def, _held_rot, _hover)
	var col := CYAN if ok else RED
	for cell in BuildData.placed_cells(_held_def, _held_rot, _hover):
		if _grid.in_grid(cell):
			var rect := _cell_rect(cell).grow(-2)
			draw_rect(rect, Color(col, 0.22), true)
			draw_rect(rect, col, false, 2.0)
	# support: show where its buff-slots would land
	if _held_def.get("kind", "") == "support":
		for cell in BuildData.buff_cells(_held_def, _held_rot, _hover):
			if _grid.in_grid(cell):
				draw_rect(_cell_rect(cell).grow(-6), Color(AMBER, 0.6), false, 1.0)

func _draw_ring() -> void:
	if _ring_t < 0.0:
		return
	var center := _cell_rect(_ring_cell).get_center()
	var t := _ring_t / 0.45
	draw_arc(center, 8 + t * 42, 0, TAU, 32, Color(CYAN, 1.0 - t), 2.0)

# ---- helpers -----------------------------------------------------------------

func _placed_by_iid(iid: String) -> Dictionary:
	for p in _grid.placed:
		if p.iid == iid:
			return p
	return {}

## Bounding box of a cell list as a Rect2i (position = min row/col, size = span).
func _bounds(cells: Array) -> Rect2i:
	var min_r: int = cells[0].x
	var min_c: int = cells[0].y
	var max_r: int = cells[0].x
	var max_c: int = cells[0].y
	for cell in cells:
		min_r = mini(min_r, cell.x)
		min_c = mini(min_c, cell.y)
		max_r = maxi(max_r, cell.x)
		max_c = maxi(max_c, cell.y)
	return Rect2i(min_r, min_c, max_r - min_r + 1, max_c - min_c + 1)
