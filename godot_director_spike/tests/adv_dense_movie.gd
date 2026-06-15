extends SceneTree
## Adversarial review: DENSE loadout movie runner.
## Build A: reactor_core + aux_cell + beam_rifle + gatling + missile_rack + beam_cannon
##   — the maxed 6-weapon build a player would field late-game.
## Build B: reactor_core + aux_cell + beam_rifle + gatling (strong but not maxed,
##   so we get asymmetry rather than a pure mirror).
## Stats from build_items.json.
##
## Run:
##   godot --path godot_director_spike --write-movie tmp/adv/adv_dense.avi ^
##         -- --director=hybrid --log=fight_log_adv_dense ^
##         -s res://tests/adv_dense_movie.gd

const Sim := preload("res://scripts/build/build_fight_sim.gd")

func _initialize() -> void:
	# Dense build A: reactor_core(pool=120,regen=14) + aux_cell(pool=45,regen=5)
	# + beam_rifle + gatling + missile_rack + beam_cannon
	var build_a := {
		"hp": 100.0,
		"pool": 165.0,
		"regen": 19.0,
		"weapons": [
			{"id": "br_a",  "damage": 14.0, "cost": 8.0,  "cadence": 4.0,
			 "mount": "hand_r",    "fx": "beam"},
			{"id": "gt_a",  "damage": 9.0,  "cost": 4.0,  "cadence": 1.2,
			 "mount": "shoulder_r","fx": "burst"},
			{"id": "mr_a",  "damage": 18.0, "cost": 12.0, "cadence": 6.0,
			 "mount": "back",      "fx": "missiles"},
			{"id": "bc_a",  "damage": 26.0, "cost": 18.0, "cadence": 8.0,
			 "mount": "shoulder_l","fx": "buster"},
		]
	}
	# Dense build B: reactor_core + aux_cell + beam_rifle + gatling (less heavy)
	var build_b := {
		"hp": 100.0,
		"pool": 165.0,
		"regen": 19.0,
		"weapons": [
			{"id": "br_b",  "damage": 14.0, "cost": 8.0,  "cadence": 4.0,
			 "mount": "hand_r",    "fx": "beam"},
			{"id": "gt_b",  "damage": 9.0,  "cost": 4.0,  "cadence": 1.2,
			 "mount": "hand_l",    "fx": "burst"},
			{"id": "mr_b",  "damage": 18.0, "cost": 12.0, "cadence": 6.0,
			 "mount": "shoulder_l","fx": "missiles"},
		]
	}

	var events := Sim.simulate(build_a, build_b, 13)

	# Audit the log.
	var beam_count := 0
	var burst_count := 0
	var swarm_count := 0
	var buster_count := 0
	var has_popup := false
	var has_hero_kill := false
	var has_chase := false
	var lethal_tick := -1
	for e in events:
		match e.kind:
			"fire_beam":   beam_count += 1
			"fire_burst":  burst_count += 1
			"fire_swarm":  swarm_count += 1
			"fire_buster": buster_count += 1
		if e.kind == "advance" and float(e.payload.get("to_y", 0.0)) > 0.0:
			has_popup = true
		if bool(e.payload.get("evade", false)) or bool(e.payload.get("pursue", false)):
			has_chase = true
		if e.payload.get("hero_kill", false):
			has_hero_kill = true
			lethal_tick = int(e.tick)

	print("adv_dense_movie: beams=%d bursts=%d swarms=%d busters=%d popup=%s hero_kill=%s chase=%s lethal_tick=%d events=%d" % [
		beam_count, burst_count, swarm_count, buster_count,
		has_popup, has_hero_kill, has_chase, lethal_tick, events.size()])

	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open("res://data/fight_log_adv_dense.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(events))
	f.close()
	print("adv_dense_movie: log saved to data/fight_log_adv_dense.json")

	change_scene_to_file("res://scenes/main.tscn")
