extends SceneTree
## Headless checks for the "hybrid" (iso base + cinematic intercut) variant.

var fails := 0
# Frozen characterization hash of the hybrid shot list for fight_log_everything.json
# (count + per-shot mode,t0,t1,time_scale, rounded to 1e-4). It guards against
# unintended drift when refactoring the director — NOT a cross-version invariant.
# String.hash() is not guaranteed stable across Godot releases, so a Godot upgrade
# may require re-baking: run this test, copy the printed "got hash N", and replace
# the value below.
const GOLDEN_SHOTLIST_HASH := 2543717900

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	_check_hybrid_shot_list()
	_check_hybrid_parity_snapshot()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

func _check_hybrid_shot_list() -> void:
	var FightLog := load("res://scripts/fight_log.gd")
	var Hybrid := load("res://scripts/directors/hybrid.gd")
	check(Hybrid != null, "hybrid variant script loads")
	if Hybrid == null:
		return
	var events: Array = FightLog.load_events("res://data/fight_log.json")
	var dur: float = FightLog.duration_sec(events)
	var shots: Array = Hybrid.build_shot_list(events, dur)
	check(shots.size() >= 5, "shot list has >= 5 shots (got %d)" % shots.size())
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
	check(shots[0].mode == "iso", "opens on the isometric base view")
	check(shots[-1].mode == "iso_aftermath", "closes on the iso aftermath read")
	var lethal_t := -1.0
	for e in events:
		if e.kind == "fire_beam" and e.payload.get("lethal", false):
			lethal_t = float(e.tick) * 0.1
	var dilated: Array = shots.filter(func(s): return float(s.time_scale) < 1.0)
	check(dilated.size() == 1, "exactly one shot dilates time (got %d)" % dilated.size())
	if dilated.size() == 1:
		var k: Dictionary = dilated[0]
		check(k.mode == "bullet_time", "the dilated shot is the bullet_time kill")
		check(float(k.t0) <= lethal_t and lethal_t <= float(k.t1), "bullet_time spans the lethal beam tick")
	var vocab_ok := true
	for s in shots:
		if not (s.mode in Hybrid.VOCAB):
			vocab_ok = false
	check(vocab_ok, "every mode belongs to the hybrid vocabulary %s" % str(Hybrid.VOCAB))
	var modes: Array = shots.map(func(s): return s.mode)
	check(modes.count("hero_os") == 1, "exactly one over-shoulder intercut (opening exchange)")
	check(modes.count("hero_cut") >= 1, "at least one cinematic mid-fight intercut")
	check(modes.count("iso") >= 2, "iso base returns between the intercuts")

func _check_hybrid_parity_snapshot() -> void:
	var FightLog := load("res://scripts/fight_log.gd")
	var Hybrid := load("res://scripts/directors/hybrid.gd")
	check(Hybrid != null, "hybrid variant script loads (parity)")
	if Hybrid == null:
		return
	var events: Array = FightLog.load_events("res://data/fight_log_everything.json")
	var dur: float = FightLog.duration_sec(events)
	var shots: Array = Hybrid.build_shot_list(events, dur)
	var sig := "%d|" % shots.size()
	for s in shots:
		sig += "%s,%.4f,%.4f,%.4f;" % [s.mode, float(s.t0), float(s.t1), float(s.time_scale)]
	var hash_now := sig.hash()
	check(hash_now == GOLDEN_SHOTLIST_HASH, "hybrid shot list matches golden snapshot (got hash %d)" % hash_now)