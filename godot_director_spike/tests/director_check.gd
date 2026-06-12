extends SceneTree
## Headless checks for the spike's pure logic. Exit 0 = pass.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	_check_fight_log()
	_check_shot_list()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

func _check_fight_log() -> void:
	var FightLog := load("res://scripts/fight_log.gd")
	var events: Array = FightLog.load_events("res://data/fight_log.json")
	check(events.size() >= 15, "log has >= 15 events (got %d)" % events.size())
	var sorted := true
	var prev := -1
	for e in events:
		if int(e.tick) < prev:
			sorted = false
		prev = int(e.tick)
		check(e.has("tick") and e.has("actor") and e.has("kind") and e.has("payload"),
			"event T%s has all required fields" % str(e.get("tick")))
	check(sorted, "events sorted by tick")
	var kinds := {}
	for e in events:
		kinds[e.kind] = true
	for k in ["spawn", "advance", "fire_beam", "fire_burst", "destroyed"]:
		check(kinds.has(k), "log contains kind '%s'" % k)
	var lethal := events.filter(func(e): return e.kind == "fire_beam" and e.payload.get("lethal", false))
	check(lethal.size() == 1, "exactly one lethal beam")
	var blocked := events.filter(func(e): return e.kind == "fire_beam" and e.payload.get("blocked", false))
	check(blocked.size() == 1, "exactly one blocked beam")
	check(FightLog.duration_sec(events) > 20.0, "fight duration > 20s")

func _check_shot_list() -> void:
	var FightLog := load("res://scripts/fight_log.gd")
	var Director := load("res://scripts/director.gd")
	var events: Array = FightLog.load_events("res://data/fight_log.json")
	var dur: float = FightLog.duration_sec(events)
	var shots: Array = Director.build_shot_list(events, dur)
	check(shots.size() >= 5, "shot list has >= 5 shots (got %d)" % shots.size())
	check(absf(float(shots[0].t0)) < 0.001 and shots[0].mode == "wide", "first shot is establishing wide at t=0")
	var covered := true
	var monotonic := true
	for i in shots.size():
		var s: Dictionary = shots[i]
		if float(s.t1) <= float(s.t0):
			monotonic = false
		if i > 0 and absf(float(s.t0) - float(shots[i - 1].t1)) > 0.001:
			covered = false
	check(monotonic, "every shot has t1 > t0")
	check(covered, "shots are contiguous (no gaps/overlaps)")
	check(absf(float(shots[-1].t1) - dur) < 0.001, "last shot ends at fight duration")
	var lethal_t := 0.0
	for e in events:
		if e.kind == "fire_beam" and e.payload.get("lethal", false):
			lethal_t = float(e.tick) * 0.1
	var first_beam_t := -1.0
	for e in events:
		if e.kind == "fire_beam":
			first_beam_t = float(e.tick) * 0.1
			break
	var overshoulder := shots.filter(func(s): return s.mode == "over_shoulder")
	check(overshoulder.size() == 1, "exactly one over-shoulder shot")
	if overshoulder.size() == 1:
		check(float(overshoulder[0].t0) <= first_beam_t and first_beam_t <= float(overshoulder[0].t1),
			"over-shoulder spans the first beam tick")
	var killcam := shots.filter(func(s): return s.mode == "killcam")
	check(killcam.size() == 1, "exactly one killcam shot")
	if killcam.size() == 1:
		var k: Dictionary = killcam[0]
		check(float(k.t0) <= lethal_t and lethal_t <= float(k.t1), "killcam spans the lethal beam tick")
		check(float(k.time_scale) < 1.0, "killcam dilates time")
	check(shots[-1].mode == "orbit", "final shot is the wreck orbit")
	var normal := shots.filter(func(s): return s.mode != "killcam")
	check(normal.all(func(s): return absf(float(s.time_scale) - 1.0) < 0.001), "only killcam changes time_scale")
