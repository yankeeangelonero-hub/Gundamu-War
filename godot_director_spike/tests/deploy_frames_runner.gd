extends SceneTree
## THROWAWAY — deploy-path frame capture for post-fix verification.
## Replicates the exact build_screen DEPLOY path: build_from_placement + OpponentSource,
## then sets FightHandoff exactly as build_screen does, then changes to main.tscn.
## main.gd's --frames flag dumps a PNG every 1.5s to res://tmp/.
## Run WITHOUT --headless:
##   godot --path godot_director_spike -s res://tests/deploy_frames_runner.gd -- --frames

const Sim := preload("res://scripts/build/build_fight_sim.gd")
const Opp := preload("res://scripts/build/opponent_source.gd")
const Handoff := preload("res://scripts/build/fight_handoff.gd")

func _initialize() -> void:
	var placement := [
		{"def_id": "reactor_core", "rot": 0, "anchor": [0, 0]},
		{"def_id": "gatling",      "rot": 0, "anchor": [0, 2]},
		{"def_id": "beam_rifle",   "rot": 0, "anchor": [0, 3]},
		{"def_id": "missile_rack", "rot": 0, "anchor": [2, 2]},
	]
	var pick := 12345
	var player := Sim.build_from_placement(placement)
	var ghost: Dictionary = Opp.get_ghost(pick)
	var ghost_build := Sim.build_from_placement(ghost.placement)
	var events := Sim.simulate(player, ghost_build, pick)

	# Wire up exactly as build_screen does on DEPLOY.
	Handoff.saved_placement   = placement
	Handoff.player_placement  = placement
	Handoff.ghost_placement   = ghost.placement
	Handoff.director_name     = "hybrid"
	Handoff.return_scene      = "res://scenes/build_screen.tscn"
	Handoff.set_fight(events, "VESPER-7", str(ghost.get("name", "GHOST")))

	print("deploy_frames_runner: events=%d, changing to main.tscn" % events.size())
	change_scene_to_file("res://scenes/main.tscn")
