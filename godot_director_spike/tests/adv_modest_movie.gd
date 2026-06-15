extends SceneTree
## Adversarial review: MODEST loadout movie runner.
## Build A: reactor_core + beam_rifle (typical early-round player build).
## Build B: reactor_core + beam_rifle (mirror, so the fight is balanced).
## Simulates via BuildFightSim, saves log, loads main.tscn with hybrid director.
##
## Run:
##   godot --path godot_director_spike --write-movie tmp/adv/adv_modest.avi ^
##         -- --director=hybrid --log=fight_log_adv_modest ^
##         -s res://tests/adv_modest_movie.gd

const Sim := preload("res://scripts/build/build_fight_sim.gd")

func _initialize() -> void:
	# Modest loadout: single reactor + single beam rifle each side.
	# Stats derived from build_items.json:
	#   reactor_core: pool=120, regen=14
	#   beam_rifle:   damage=14, cost=8, cadence=4.0, fx=beam, mount=hand_r
	var build_a := {
		"hp": 100.0,
		"pool": 120.0,
		"regen": 14.0,
		"weapons": [
			{"id": "br_a", "damage": 14.0, "cost": 8.0, "cadence": 4.0,
			 "mount": "hand_r", "fx": "beam"}
		]
	}
	var build_b := {
		"hp": 100.0,
		"pool": 120.0,
		"regen": 14.0,
		"weapons": [
			{"id": "br_b", "damage": 14.0, "cost": 8.0, "cadence": 4.0,
			 "mount": "hand_r", "fx": "beam"}
		]
	}

	var events := Sim.simulate(build_a, build_b, 42)

	# Audit the log.
	var fire_count := 0
	var has_popup := false
	var has_hero_kill := false
	var has_chase := false
	var lethal_tick := -1
	for e in events:
		if str(e.kind).begins_with("fire"):
			fire_count += 1
		if e.kind == "advance" and float(e.payload.get("to_y", 0.0)) > 0.0:
			has_popup = true
		if bool(e.payload.get("evade", false)) or bool(e.payload.get("pursue", false)):
			has_chase = true
		if e.payload.get("hero_kill", false):
			has_hero_kill = true
			lethal_tick = int(e.tick)

	print("adv_modest_movie: fire=%d popup=%s hero_kill=%s chase=%s lethal_tick=%d events=%d" % [
		fire_count, has_popup, has_hero_kill, has_chase, lethal_tick, events.size()])

	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open("res://data/fight_log_adv_modest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(events))
	f.close()
	print("adv_modest_movie: log saved to data/fight_log_adv_modest.json")

	change_scene_to_file("res://scenes/main.tscn")
