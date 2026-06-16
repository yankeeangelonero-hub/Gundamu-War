extends SceneTree
## Unit test for the time-emphasis precedence arbiter (Phase 3 Slice 1, spec Open Q#3):
## given overlapping conditions, exactly ONE tool owns the beat.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func _init() -> void:
	var T := load("res://scripts/director/time_emphasis.gd")
	check(T != null, "time_emphasis.gd loads")
	var thr := 25.0
	# bullet-time owns the beat regardless of damage (kill cam suppresses the rest)
	check(T.decide(true, 100.0, thr) == "bullet", "bullet-time + heavy -> bullet")
	check(T.decide(true, 5.0, thr) == "bullet", "bullet-time + minor -> bullet")
	check(T.decide(true, 0.0, thr) == "bullet", "bullet-time + no damage -> bullet")
	# not in bullet-time: heavy hit -> hitstop, minor -> impact, none -> none
	check(T.decide(false, 64.0, thr) == "hitstop", "heavy hit -> hitstop")
	check(T.decide(false, 26.0, thr) == "hitstop", "just-over-threshold -> hitstop")
	check(T.decide(false, 25.0, thr) == "impact", "at-threshold -> impact (boundary: at/below = minor)")
	check(T.decide(false, 10.0, thr) == "impact", "minor hit -> impact")
	check(T.decide(false, 0.0, thr) == "none", "no damage -> none")
	# determinism: same inputs, same output (pure)
	check(T.decide(false, 10.0, thr) == T.decide(false, 10.0, thr), "decide is pure/deterministic")

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
