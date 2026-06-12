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
