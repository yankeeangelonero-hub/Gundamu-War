extends SceneTree
## Faithful reproduction of the REAL build_screen._on_deploy path, for honest
## observation of the live deployed fight. Mirrors _on_deploy exactly, then loads
## main.tscn so FightHandoff.active drives the deploy fight. Run windowed with
## --write-movie to capture what the player actually sees.

const Sim := preload("res://scripts/build/build_fight_sim.gd")
const Opp := preload("res://scripts/build/opponent_source.gd")
const FightHandoff := preload("res://scripts/build/fight_handoff.gd")

func _init() -> void:
	var placement := [
		{"def_id": "reactor_core", "rot": 0, "anchor": [0, 0]},
		{"def_id": "beam_rifle", "rot": 0, "anchor": [0, 2]},
	]
	var pick := 12345
	var player := Sim.build_from_placement(placement)
	var ghost: Dictionary = Opp.get_ghost(pick)
	var ghost_build := Sim.build_from_placement(ghost.placement)
	var events := Sim.simulate(player, ghost_build, pick)
	FightHandoff.saved_placement = placement
	FightHandoff.player_placement = placement
	FightHandoff.ghost_placement = ghost.placement
	FightHandoff.set_fight(events, "VESPER-7", str(ghost.get("callsign", "GHOST")))
	FightHandoff.return_scene = "res://scenes/gauntlet_screen.tscn"
	call_deferred("change_scene_to_file", "res://scenes/main.tscn")
