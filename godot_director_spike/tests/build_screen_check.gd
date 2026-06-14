extends SceneTree
## Smoke + wiring check for the BuildScreen UI: instantiates the whole screen,
## drives it through the same methods the buttons/grid call, and verifies the
## live readouts reflect the placement. (Headless: logic/wiring, not pixels.)

const BuildScreen := preload("res://scripts/build/build_screen.gd")

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.05

func _initialize() -> void:
	var scr := BuildScreen.new()
	get_root().add_child(scr)
	await process_frame
	check(scr._grid_view != null, "build screen instantiates without error")
	check(scr._mech_view != null and scr._mech_view._mech != null, "3D frame view + build-pose mech present")
	check(scr._mech_view._mech.has_hardpoint("hand_r"), "mech registered its hardpoints")

	# place a reactor, a rifle, and a power booster covering the rifle — via the
	# same arm() / cell-click path the UI uses.
	scr._arm("reactor_core"); scr._on_cell_clicked(Vector2i(0, 0))
	scr._arm("beam_rifle"); scr._on_cell_clicked(Vector2i(0, 3))
	scr._arm("power_cell"); scr._on_cell_clicked(Vector2i(0, 4))
	check(scr.grid.placed.size() == 3, "three items placed through the UI path (got %d)" % scr.grid.placed.size())
	check(near(scr._result.totals.pool, 120.0), "topbar power pool reads 120 (got %s)" % scr._result.totals.pool)

	var rifle_iid := ""
	for entry in scr.grid.placed:
		if entry.def_id == "beam_rifle":
			rifle_iid = entry.iid
	check(near(scr._result.weapons[rifle_iid].damage, 18.2), "rifle shows buffed damage 18.2 in the readouts")

	# rotation of a held item updates without error
	scr._arm("amplifier")
	scr.held_rot = 0
	scr._input(_key(KEY_R))
	check(scr.held_rot == 1, "R rotates the held item")
	scr._input(_key(KEY_ESCAPE))
	check(scr.held.is_empty(), "ESC cancels the held item")

	# detach path
	scr._select(rifle_iid)
	scr._on_detach()
	check(scr.grid.placed.size() == 2, "detach removes the selected item (got %d)" % scr.grid.placed.size())

	# reset path
	scr._on_reset()
	check(scr.grid.placed.is_empty(), "reset clears the bag")

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e
