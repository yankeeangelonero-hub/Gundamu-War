extends SceneTree
## M0 bridge checks: kit data -> deterministic generated truth -> staged/viewer profile.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func _initialize() -> void:
	var Gen := load("res://scripts/sim/loadout_fight_generator.gd")
	var Choreo := load("res://scripts/sim/choreographer.gd")
	var Profile := load("res://scripts/sim/spectacle_profile.gd")
	var Main := load("res://scripts/main.gd")
	check(Gen != null, "loadout_fight_generator.gd loads")
	if Gen == null:
		_finish()
		return
	var catalog: Dictionary = Gen.load_catalog()
	check(not catalog.is_empty(), "m0 loadout catalog loads")

	var player: Dictionary = Gen.resolve_player_loadout(catalog, "rifle_missile_pressure")
	var artillery: Dictionary = Gen.resolve_opponent_loadout(catalog, "artillery_ghost")
	var first: Dictionary = Gen.generate(player, artillery, 77, 0.5)
	var second: Dictionary = Gen.generate(player, artillery, 77, 0.5)
	check(first == second, "same loadouts + seed + chaos generate identical truth")
	check((first.events as Array).filter(func(e): return e.kind == "shot").size() > 0,
		"generated truth includes shot events")
	check((first.events as Array).filter(func(e): return e.kind == "destroyed").size() == 1,
		"generated truth includes one destroyed event")
	check(float((first.events as Array)[-1].tick) >= 320.0,
		"generated fight reaches the drama-duration floor")

	var profiles := {
		"A": Choreo.apply_preset(str(player.get("grammar_preset", "gunner"))),
		"B": Choreo.apply_preset(str(artillery.get("grammar_preset", "gunner"))),
	}
	var staged: Array = Choreo.stage(first.events, 77, profiles)
	check(staged.filter(func(e): return e.kind == "advance").size() > 0,
		"choreographer stages generated truth")

	if Main != null:
		var m = Main.new()
		var viewer: Array = m._debug_staged_truth_to_viewer_events(staged)
		var profile: Dictionary = Profile.profile(viewer, "generated")
		check(int(profile.attack_count) > 0, "generated viewer profile counts attacks")
		check(int(profile.weapon_kind_count) >= 2, "generated profile has mixed weapon kinds")
		m.free()

	var saber: Dictionary = Gen.resolve_player_loadout(catalog, "saber_booster_chase")
	var saber_fight: Dictionary = Gen.generate(saber, artillery, 77, 0.5)
	check((saber_fight.events as Array).filter(func(e): return e.payload.get("motif", "") == "saber").size() > 0,
		"saber kit generates saber truth events")

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
