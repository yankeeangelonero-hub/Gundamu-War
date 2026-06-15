extends SceneTree
## Windowed screenshot of the gauntlet shop UI.
## Run WITHOUT --headless:
##   godot --path godot_director_spike -s res://tests/gauntlet_shop_shot.gd
## Saves to tmp/shop_screen.png.

const RunState  := preload("res://scripts/gauntlet/run_state.gd")
const ShopState := preload("res://scripts/gauntlet/shop_state.gd")

func _initialize() -> void:
	# Seed a mid-run state so the shop screen has content.
	RunState.new_run("vesper", 12345)
	RunState.gold = 22
	RunState.hearts = 2
	RunState.round = 2
	ShopState.clear()
	ShopState.add_to_inventory("beam_rifle")
	ShopState.add_to_inventory("reactor_core")
	ShopState.begin_round(12345, 2)

	change_scene_to_file("res://scenes/gauntlet_screen.tscn")
	await create_timer(1.5).timeout
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var img := get_root().get_texture().get_image()
	img.save_png("res://tmp/shop_screen.png")
	print("shop screenshot saved: tmp/shop_screen.png")
	quit()
