extends SceneTree
## Windowed runner: drive a deployed fight and capture a frame mid-intro to review
## the establishing camera framing. Run WITHOUT --headless.
##   godot --path godot_director_spike -s res://tests/intro_shot.gd

const Sim := preload("res://scripts/build/build_fight_sim.gd")
const Opp := preload("res://scripts/build/opponent_source.gd")
const Handoff := preload("res://scripts/build/fight_handoff.gd")

func _initialize() -> void:
	var player := Sim.build_from_placement(Opp.get_placement(0))
	var ghost := Sim.build_from_placement(Opp.get_placement(1))
	var events := Sim.simulate(player, ghost, 1)
	Handoff.set_fight(events, "VESPER-7", "PIERCE-9")
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.7).timeout   # mid-intro (push-in ~halfway, title up)
	var img := get_root().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://tmp")
	img.save_png("res://tmp/intro_shot.png")
	print("saved tmp/intro_shot.png")
	quit(0)
