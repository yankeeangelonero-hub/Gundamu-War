extends SceneTree
## Regression for the debug tuning bench: existing v1 viewer logs can be converted
## to v2 truth, restaged by FeelProfile presets, then rendered back as v1 viewer events.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func _initialize() -> void:
	var Main := load("res://scripts/main.gd")
	var FightLog := load("res://scripts/fight_log.gd")
	var C := load("res://scripts/sim/choreographer.gd")
	check(Main != null, "main.gd loads")
	if Main == null:
		_finish()
		return
	var m = Main.new()
	var source: Array = FightLog.load_events("res://data/fight_log_everything.json")
	var truth: Array = m._viewer_events_to_debug_truth(source)
	check(truth.filter(func(e): return e.kind == "advance").is_empty(),
		"debug truth strips authored advances")
	check(truth.filter(func(e): return e.kind == "shot").size() > 0,
		"debug truth converts v1 attacks to v2 shots")

	m.set("_debug_truth", truth)
	m.set("_feel", {"A": C.apply_preset("bruiser"), "B": C.apply_preset("gunner")})
	m._restage_debug_truth()
	var bruiser_events: Array = m.get("_events").duplicate(true)
	m.set("_feel", {"A": C.apply_preset("skirmisher"), "B": C.apply_preset("gunner")})
	m._restage_debug_truth()
	var skirm_events: Array = m.get("_events").duplicate(true)

	check(bruiser_events.filter(func(e): return e.kind == "advance").size() > 0,
		"restaged viewer events include generated advances")
	check(bruiser_events.filter(func(e): return e.kind == "shot").is_empty(),
		"restaged viewer events convert shots back to v1 kinds")
	check(bruiser_events.filter(func(e): return e.kind == "fire_beam").size() > 0,
		"restaged viewer events preserve v1 fire kinds")
	check(bruiser_events != skirm_events,
		"changing a Feel preset changes the restaged movement")

	m.set("_debug_live", false)
	m._on_debug_preset_changed("A", "bruiser")
	var bruiser_loadout_events: Array = m.get("_events").duplicate(true)
	m._on_debug_preset_changed("A", "skirmisher")
	var skirmisher_loadout_events: Array = m.get("_events").duplicate(true)
	var bruiser_kinds := _attack_kinds_for(bruiser_loadout_events, "A")
	var skirmisher_kinds := _attack_kinds_for(skirmisher_loadout_events, "A")
	check("melee" in bruiser_kinds and "fire_buster" in bruiser_kinds,
		"bruiser archetype generates saber + buster attacks")
	check("fire_burst" in skirmisher_kinds and "fire_missiles" in skirmisher_kinds,
		"skirmisher archetype generates burst + missile attacks")
	check(bruiser_kinds != skirmisher_kinds,
		"changing archetype changes weapon loadout kinds")
	m.free()
	_finish()


func _attack_kinds_for(events: Array, actor: String) -> Array:
	var kinds := []
	for e in events:
		if e.actor != actor:
			continue
		if e.kind in ["fire_beam", "fire_burst", "fire_missiles", "fire_buster", "melee"]:
			if not (e.kind in kinds):
				kinds.append(e.kind)
	kinds.sort()
	return kinds

func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
