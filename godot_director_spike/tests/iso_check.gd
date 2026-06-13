extends SceneTree
## Headless checks for the "iso" (fixed isometric) variant. Exit 0 = pass.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	_check_iso_shot_list()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

func _check_iso_shot_list() -> void:
	var FightLog := load("res://scripts/fight_log.gd")
	var Iso := load("res://scripts/directors/iso.gd")
	check(Iso != null, "iso variant script loads")
	if Iso == null:
		return
	var events: Array = FightLog.load_events("res://data/fight_log.json")
	var dur: float = FightLog.duration_sec(events)
	var shots: Array = Iso.build_shot_list(events, dur)
	check(shots.size() == 3, "shot list is exactly 3 shots (got %d)" % shots.size())
	check(absf(float(shots[0].t0)) < 0.001, "first shot starts at t=0")
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
	check(absf(float(shots[-1].t1) - dur) < 0.001, "last shot ends at fight duration")
	var lethal_t := -1.0
	for e in events:
		if e.kind == "fire_beam" and e.payload.get("lethal", false):
			lethal_t = float(e.tick) * 0.1
	var dilated: Array = shots.filter(func(s): return float(s.time_scale) < 1.0)
	check(dilated.size() == 1, "exactly one shot dilates time (got %d)" % dilated.size())
	if dilated.size() == 1:
		var k: Dictionary = dilated[0]
		check(k.mode == "iso_kill", "the dilated shot is the iso_kill zoom")
		check(float(k.t0) <= lethal_t and lethal_t <= float(k.t1), "iso_kill spans the lethal beam tick")
	var vocab_ok := true
	for s in shots:
		if not (s.mode in Iso.VOCAB):
			vocab_ok = false
	check(vocab_ok, "every mode belongs to the iso vocabulary %s" % str(Iso.VOCAB))
