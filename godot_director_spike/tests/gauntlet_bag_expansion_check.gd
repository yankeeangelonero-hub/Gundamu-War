extends SceneTree
## Headless checks for P1 bag expansion: placing a container item grants extra
## cells; removing it revokes them; placement into granted cells works.

const BuildGrid := preload("res://scripts/build/build_grid.gd")
const BuildData := preload("res://scripts/build/build_data.gd")

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	_container_grants_cells()
	_remove_container_revokes_cells()
	_granted_cells_accept_items()
	_base_grid_unchanged_without_container()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

func _container_grants_cells() -> void:
	var grid := BuildGrid.new()
	var before := grid.owned_cell_count()
	# hardpoint_pylon: extra_rows=2, extra_cols=2
	var entry := grid.place("hp1", "hardpoint_pylon", 0, Vector2i(0, 0))
	check(not entry.is_empty(), "container: hardpoint_pylon placed successfully")
	var after := grid.owned_cell_count()
	var granted_def := BuildData.get_def("hardpoint_pylon")
	var expected_extra := int(granted_def.extra_rows) * int(granted_def.extra_cols)
	check(after == before + expected_extra,
		"container: owned_cell_count grew by extra_rows*extra_cols=%d (before=%d after=%d)" % [expected_extra, before, after])
	check(grid.extra_cells().size() == expected_extra,
		"container: extra_cells() returns %d cells (got %d)" % [expected_extra, grid.extra_cells().size()])

func _remove_container_revokes_cells() -> void:
	var grid := BuildGrid.new()
	var before := grid.owned_cell_count()
	grid.place("hp1", "hardpoint_pylon", 0, Vector2i(0, 0))
	grid.remove("hp1")
	var after := grid.owned_cell_count()
	check(after == before, "container revoke: owned_cell_count restored to base after remove (before=%d after=%d)" % [before, after])
	check(grid.extra_cells().is_empty(), "container revoke: extra_cells() empty after remove")

func _granted_cells_accept_items() -> void:
	var grid := BuildGrid.new()
	# Place a container at row 0, the extra cells start at col 5+ (past base COLS=5).
	grid.place("hp1", "hardpoint_pylon", 0, Vector2i(0, 0))
	var extras := grid.extra_cells()
	check(extras.size() > 0, "granted accept: have extra cells to place into")
	# Try to place a 1x1 item into the first granted extra cell.
	var extra_cell: Vector2i = extras[0]
	var entry := grid.place("ax1", "aux_cell", 1, extra_cell)  # rot=1 makes it 1×1? no — use 1x1 item
	# Actually aux_cell is 1x2v; use targeting_scope (1x1).
	grid.remove("ax1")
	entry = grid.place("ts1", "targeting_scope", 0, extra_cell)
	check(not entry.is_empty(),
		"granted accept: 1x1 item placed in extra cell %s" % str(extra_cell))

func _base_grid_unchanged_without_container() -> void:
	var grid := BuildGrid.new()
	# Without any container, placing beyond base bounds fails.
	var out_of_bounds := Vector2i(0, BuildGrid.COLS)   # col 5 — past the base grid
	var def := BuildData.get_def("targeting_scope")
	check(not grid.can_place(def, 0, out_of_bounds),
		"base unchanged: col %d is out of base grid without container" % BuildGrid.COLS)
