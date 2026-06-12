extends SceneTree
## Headless checks for the broadcast director variant. Exit 0 = pass.

const MODES := ["long_lens", "drone_orbit", "cut_in", "bullet_time", "aerial_pullback"]

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	var Broadcast: Variant = load("res://scripts/directors/broadcast.gd")
	check(Broadcast != null, "broadcast variant script loads")
	if Broadcast == null:
		print("---- 1 FAILURES")
		quit(1)
		return
	var FightLog := load("res://scripts/fight_log.gd")
	var events: Array = FightLog.load_events("res://data/fight_log.json")
	var dur: float = FightLog.duration_sec(events)
	var shots: Array = Broadcast.build_shot_list(events, dur)

	check(shots.size() >= 7, "shot list has >= 7 shots (got %d)" % shots.size())
	check(absf(float(shots[0].t0)) < 0.001, "first shot starts at t=0")
	check(shots[0].mode == "long_lens", "opening shot is a long lens")
	check(shots[-1].mode == "aerial_pullback", "final shot is the aerial pullback")
	check(absf(float(shots[-1].t1) - dur) < 0.001, "last shot ends at fight duration")

	var monotonic := true
	var covered := true
	for i in shots.size():
		var s: Dictionary = shots[i]
		if float(s.t1) <= float(s.t0):
			monotonic = false
		if i > 0 and absf(float(s.t0) - float(shots[i - 1].t1)) > 0.001:
			covered = false
	check(monotonic, "every shot has t1 > t0")
	check(covered, "shots are contiguous (no gaps/overlaps)")

	for s in shots:
		check(str(s.mode) in MODES, "mode '%s' is in the broadcast vocabulary" % str(s.mode))

	var lethal_t := 0.0
	for e in events:
		if e.kind == "fire_beam" and e.payload.get("lethal", false):
			lethal_t = float(e.tick) * 0.1
	var slow: Array = shots.filter(func(s): return float(s.time_scale) < 1.0)
	check(slow.size() == 1, "exactly one slow-motion shot (got %d)" % slow.size())
	if slow.size() == 1:
		var bt: Dictionary = slow[0]
		check(bt.mode == "bullet_time", "the slow shot is bullet_time")
		check(float(bt.time_scale) <= 0.1, "bullet_time time_scale <= 0.1 (got %.3f)" % float(bt.time_scale))
		check(float(bt.t0) <= lethal_t and lethal_t <= float(bt.t1),
			"bullet_time spans the lethal beam at t=%.1f" % lethal_t)
		check(float(bt.t1) - float(bt.t0) <= 1.5, "bullet_time game-time span stays short (<= 1.5s)")
	var rest: Array = shots.filter(func(s): return s.mode != "bullet_time")
	check(rest.all(func(s): return absf(float(s.time_scale) - 1.0) < 0.001),
		"every non-bullet-time shot runs at exactly 1.0")

	for e in events:
		if e.kind != "fire_beam" or e.payload.get("lethal", false):
			continue
		var t := float(e.tick) * 0.1
		var has_cut := shots.any(func(s): return s.mode == "cut_in" and float(s.t0) <= t and t <= float(s.t1))
		check(has_cut, "a snap cut-in spans the beam exchange at t=%.1f" % t)

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
