extends SceneTree
## Headless checks for BuildGrid (placement validity, overlap) and the rotation
## invariant in BuildData (shape AND buff-slots rotate together).

const BuildGrid := preload("res://scripts/build/build_grid.gd")
const BuildData := preload("res://scripts/build/build_data.gd")

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _set_of(cells: Array) -> Dictionary:
	var d := {}
	for c in cells:
		d[c] = true
	return d

func _same_cells(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var sa := _set_of(a)
	for c in b:
		if not sa.has(c):
			return false
	return true

func _initialize() -> void:
	_in_grid_validity()
	_no_overlap()
	_rotation_transforms_shape_and_buff()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

func _in_grid_validity() -> void:
	var g := BuildGrid.new()
	var rifle := BuildData.get_def("beam_rifle")   # 1x3v, 3 tall
	# rows are 0..3 (ROWS=4). anchor (2,0) → rows 2,3,4 → 4 is out → invalid.
	check(not g.can_place(rifle, 0, Vector2i(2, 0)), "1x3v at row 2 spills off the 4-row grid → invalid")
	# anchor (1,0) → rows 1,2,3 → all in grid.
	check(g.can_place(rifle, 0, Vector2i(1, 0)), "1x3v at row 1 fits → valid")
	# negative anchor → invalid.
	check(not g.can_place(rifle, 0, Vector2i(-1, 0)), "negative anchor → invalid")

func _no_overlap() -> void:
	var g := BuildGrid.new()
	var rifle := BuildData.get_def("beam_rifle")
	var placed := g.place("a", "beam_rifle", 0, Vector2i(0, 0))
	check(not placed.is_empty(), "first rifle places at (0,0)")
	check(not g.can_place(rifle, 0, Vector2i(0, 0), "b"), "second rifle on the same column overlaps → invalid")
	check(g.can_place(rifle, 0, Vector2i(0, 1)), "second rifle one column over → valid")
	check(g.item_at(Vector2i(1, 0)) == "a", "occupancy map points the middle cell at item a")
	g.remove("a")
	check(g.item_at(Vector2i(1, 0)) == "", "after remove, the cell is free again")

# The amplifier (1x2v, buff-slots to its right) must keep its buff-slots glued to
# its body when rotated 90° clockwise.
func _rotation_transforms_shape_and_buff() -> void:
	var amp := BuildData.get_def("amplifier")
	var anc := Vector2i(0, 0)

	# rot 0: vertical body at col 0, buff-slots in col 1.
	var shape0 := BuildData.placed_cells(amp, 0, anc)
	var buff0 := BuildData.buff_cells(amp, 0, anc)
	check(_same_cells(shape0, [Vector2i(0, 0), Vector2i(1, 0)]), "rot0 shape = vertical (0,0)(1,0)")
	check(_same_cells(buff0, [Vector2i(0, 1), Vector2i(1, 1)]), "rot0 buff = right column (0,1)(1,1)")

	# rot 1 (90° CW): body becomes horizontal across row 0; buff-slots swing to row 1.
	var shape1 := BuildData.placed_cells(amp, 1, anc)
	var buff1 := BuildData.buff_cells(amp, 1, anc)
	check(_same_cells(shape1, [Vector2i(0, 0), Vector2i(0, 1)]), "rot1 shape = horizontal (0,0)(0,1)")
	check(_same_cells(buff1, [Vector2i(1, 0), Vector2i(1, 1)]),
		"rot1 buff rotated WITH shape → row below (1,0)(1,1)")
