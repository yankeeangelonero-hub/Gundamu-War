extends SceneTree
## Movie runner for the enriched hybrid fight.
## Simulates a rich fight (swarm + beam, enough reactor to fire often) and saves the
## event log to data/fight_log_enriched_hybrid.json, then loads it via main.gd's
## --log= path (FightHandoff.active stays false so fight_over quits cleanly).
##
## Run WITH --write-movie to capture the AVI:
##   godot --path godot_director_spike --write-movie tmp/enriched_fight_hybrid.avi ^
##         -- --director=hybrid --log=fight_log_enriched_hybrid ^
##         -s res://tests/enriched_hybrid_movie.gd
##
## The fight uses the same builds as enriched_render_shot.gd: build A has a high-DPS
## swarm weapon + a beam, high regen, so it fires often and the log contains pop-up
## bursts, fire_swarm volleys, a dodge-pursuit run, and a hero_kill on the final blow.

const Sim    := preload("res://scripts/build/build_fight_sim.gd")

func _initialize() -> void:
	var w_swarm_a := {
		"id": "s1", "damage": 18.0, "cost": 3.0, "cadence": 1.8,
		"mount": "shoulder_r", "fx": "missiles"
	}
	var w_beam_a := {
		"id": "b1", "damage": 10.0, "cost": 2.0, "cadence": 1.2,
		"mount": "hand_r", "fx": "beam"
	}
	var build_a := {
		"hp": 100.0, "pool": 80.0, "regen": 14.0,
		"weapons": [w_swarm_a, w_beam_a]
	}
	var w_beam_b := {
		"id": "b2", "damage": 7.0, "cost": 2.0, "cadence": 1.5,
		"mount": "hand_r", "fx": "beam"
	}
	var build_b := {
		"hp": 100.0, "pool": 50.0, "regen": 8.0,
		"weapons": [w_beam_b]
	}

	var events := Sim.simulate(build_a, build_b, 7)

	# Log the key beats.
	var has_swarm := false
	var has_popup := false
	var has_hero_kill := false
	var lethal_tick := -1
	for e in events:
		if e.kind == "fire_swarm":
			has_swarm = true
		if e.kind == "advance" and e.payload.get("to_y", 0.0) > 0.0:
			has_popup = true
		if e.payload.get("hero_kill", false):
			has_hero_kill = true
			lethal_tick = int(e.tick)
	print("enriched_hybrid_movie: swarm=%s popup=%s hero_kill=%s lethal_tick=%d events=%d" % [
		has_swarm, has_popup, has_hero_kill, lethal_tick, events.size()])

	# Save log to data/ so main.gd can load it via --log=
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open("res://data/fight_log_enriched_hybrid.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(events))
	f.close()
	print("enriched_hybrid_movie: log saved to data/fight_log_enriched_hybrid.json")

	# Load main.tscn — it will pick up --director=hybrid and --log= from cmdline.
	# FightHandoff.active is false, so fight_over → quit (not return to build screen).
	change_scene_to_file("res://scenes/main.tscn")
