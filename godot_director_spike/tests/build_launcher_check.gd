extends SceneTree
## Headless check for the first playable launcher UI.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func _initialize() -> void:
	var Launcher := load("res://scripts/build_launcher.gd")
	check(Launcher != null, "build_launcher.gd loads")
	if Launcher == null:
		_finish()
		return
	var launcher = Launcher.new()
	root.add_child(launcher)
	await process_frame
	var kit_picker: OptionButton = launcher.get("_kit_picker")
	var opponent_picker: OptionButton = launcher.get("_opponent_picker")
	var grid: GridContainer = launcher.get("_grid")
	check(kit_picker != null and kit_picker.item_count >= 3,
		"launcher exposes three player archetype kits")
	check(opponent_picker != null and opponent_picker.item_count >= 3,
		"launcher exposes opponent presets")
	check(grid != null and grid.get_child_count() == 20,
		"launcher draws a 5x4 backpack preview")
	var hits := {"fight": 0}
	launcher.fight_requested.connect(func(player_kit_id: String, opponent_id: String, chaos: float, seed: int) -> void:
		if player_kit_id != "" and opponent_id != "" and chaos >= 0.0 and seed > 0:
			hits.fight += 1
	)
	launcher._on_fight_pressed()
	check(hits.fight == 1, "Fight button emits selected kit/opponent/chaos")
	launcher.set_profile({"summary": "42.0s | 30 atk"})
	var profile_label: Label = launcher.get("_profile_label")
	check(profile_label.text.contains("42.0s"), "launcher displays profile summary")
	launcher.queue_free()
	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
