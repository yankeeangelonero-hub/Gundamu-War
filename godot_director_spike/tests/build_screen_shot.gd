extends SceneTree
## Windowed screenshot runner: builds a representative loadout and saves a PNG of
## the rendered build screen for visual review. Run WITHOUT --headless.
##   godot --path godot_director_spike -s res://tests/build_screen_shot.gd

func _initialize() -> void:
	var scr: Control = load("res://scenes/build_screen.tscn").instantiate()
	get_root().add_child(scr)
	await process_frame
	await process_frame

	# a representative build: reactor + rifle buffed by two supports + a cannon.
	scr._arm("reactor_core"); scr._on_cell_clicked(Vector2i(0, 0))
	scr._arm("beam_rifle"); scr._on_cell_clicked(Vector2i(0, 3))
	scr._arm("power_cell"); scr._on_cell_clicked(Vector2i(0, 4))
	scr._arm("targeting_scope"); scr._on_cell_clicked(Vector2i(1, 4))
	scr._arm("beam_cannon"); scr._on_cell_clicked(Vector2i(0, 2))
	scr._arm("amplifier"); scr._on_cell_clicked(Vector2i(2, 0))
	# select a support so its buff-slot overlay draws
	for entry in scr.grid.placed:
		if entry.def_id == "power_cell":
			scr._select(entry.iid)

	for _i in 8:
		await process_frame
	await create_timer(0.4).timeout

	var img := get_root().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://tmp")
	img.save_png("res://tmp/build_screen.png")
	print("saved tmp/build_screen.png  (%dx%d)" % [img.get_width(), img.get_height()])
	quit(0)
