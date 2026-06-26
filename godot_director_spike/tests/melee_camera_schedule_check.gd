extends SceneTree
## Dense two-saber fights should not become a machine-gun sequence of tiny close-ups.

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
	var Main := load("res://scripts/main.gd")
	var Hybrid := load("res://scripts/directors/hybrid.gd")
	var FightLog := load("res://scripts/fight_log.gd")
	var ShotGrammar := load("res://scripts/director/shot_grammar.gd")
	check(Gen != null and Choreo != null and Main != null and Hybrid != null and FightLog != null and ShotGrammar != null,
		"camera schedule dependencies load")
	if Gen == null or Choreo == null or Main == null or Hybrid == null or FightLog == null or ShotGrammar == null:
		_finish()
		return

	var catalog: Dictionary = Gen.load_catalog()
	var player: Dictionary = Gen.resolve_player_loadout(catalog, "saber_booster_chase")
	var opponent: Dictionary = Gen.resolve_opponent_loadout(catalog, "duelist_ghost")
	var truth: Array = Gen.generate(player, opponent, 77, 0.5).events
	var profiles := {
		"A": Choreo.apply_preset(str(player.get("grammar_preset", "lancer"))),
		"B": Choreo.apply_preset(str(opponent.get("grammar_preset", "lancer"))),
	}
	var staged: Array = Choreo.stage(truth, 77, profiles)
	var main = Main.new()
	var viewer: Array = main._debug_staged_truth_to_viewer_events(staged)
	main.free()

	var grammar = ShotGrammar.default()
	var shots: Array = Hybrid.build_shot_list(viewer, FightLog.duration_sec(viewer), grammar)
	var melee_events: Array = viewer.filter(func(e): return e.kind == "melee" and not e.payload.get("lethal", false))
	var melee_modes: Array = Hybrid.MELEE_COVERAGE
	var melee_cuts: Array = shots.filter(func(s): return str(s.mode) in melee_modes)
	var used_melee_modes := {}
	for s in melee_cuts:
		used_melee_modes[str(s.mode)] = true
	check(melee_events.size() > 6, "fixture has dense melee events")
	check(melee_cuts.size() < melee_events.size(), "dense melee events are coalesced into fewer cut-ins")
	check(used_melee_modes.size() >= 3, "dense melee cut-ins rotate through at least three camera modes")
	check(_no_tiny_perspective(shots, float(grammar.camera_min_duration)), "no clipped ordinary perspective shots below minimum length")
	check(_no_long_perspective(shots, float(grammar.camera_max_duration)), "ordinary perspective shots respect maximum length")
	check(_perspective_reestablishes(shots), "non-bullet perspective shots are separated by iso re-establishes")
	_finish()

func _no_tiny_perspective(shots: Array, min_len: float) -> bool:
	for s in shots:
		if _is_iso_mode(str(s.mode)) or str(s.mode) == "bullet_time":
			continue
		if float(s.t1) - float(s.t0) + 0.001 < min_len:
			return false
	return true

func _no_long_perspective(shots: Array, max_len: float) -> bool:
	for s in shots:
		if _is_iso_mode(str(s.mode)) or str(s.mode) == "bullet_time":
			continue
		if float(s.t1) - float(s.t0) > max_len + 0.001:
			return false
	return true

func _perspective_reestablishes(shots: Array) -> bool:
	var prev_perspective := false
	for s in shots:
		var mode := str(s.mode)
		if _is_iso_mode(mode):
			prev_perspective = false
			continue
		if prev_perspective and mode != "bullet_time":
			return false
		prev_perspective = mode != "bullet_time"
	return true

func _is_iso_mode(mode: String) -> bool:
	return mode == "iso" or mode == "iso_aftermath"

func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
