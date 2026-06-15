extends SceneTree
## Headless checks for the "hybrid" (iso base + cinematic intercut) variant.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	_check_hybrid_shot_list()
	_check_enriched_shots()
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

func _check_enriched_shots() -> void:
	var Sim := load("res://scripts/build/build_fight_sim.gd")
	var Hybrid := load("res://scripts/directors/hybrid.gd")
	var FightLog := load("res://scripts/fight_log.gd")
	if Sim == null or Hybrid == null:
		check(false, "enriched: Sim/Hybrid scripts load")
		return

	# --- (a) Swarm/gatling-only log yields >= 1 hero intercut ---
	# Build: only missile (fire_swarm) weapon — NO beam weapon at all.
	var w_swarm := {"id": "s1", "damage": 18.0, "cost": 3.0, "cadence": 1.8,
		"mount": "shoulder_r", "fx": "missiles"}
	var w_burst := {"id": "b1", "damage": 10.0, "cost": 2.0, "cadence": 1.2,
		"mount": "hand_r", "fx": "burst"}
	var build_swarm := {"hp": 100.0, "pool": 80.0, "regen": 14.0, "weapons": [w_swarm, w_burst]}
	var foe_weak := {"hp": 100.0, "pool": 30.0, "regen": 5.0,
		"weapons": [{"id": "f1", "damage": 3.0, "cost": 1.0, "cadence": 2.0,
			"mount": "hand_r", "fx": "beam"}]}
	var swarm_events: Array = Sim.simulate(build_swarm, foe_weak, 5)
	# Verify there are no fire_beam events from actor A (the swarm/burst build).
	var a_has_beam := false
	for e in swarm_events:
		if e.actor == "A" and e.kind == "fire_beam":
			a_has_beam = true
	check(not a_has_beam, "enriched (a): swarm+burst build emits no fire_beam from A")
	var swarm_dur: float = FightLog.duration_sec(swarm_events)
	var swarm_shots: Array = Hybrid.build_shot_list(swarm_events, swarm_dur)
	var hero_intercepts: Array = swarm_shots.filter(
		func(s): return s.mode == "hero_os" or s.mode == "hero_cut")
	check(hero_intercepts.size() >= 1,
		"enriched (a): swarm/burst-only fight yields >= 1 hero intercut (got %d)" % hero_intercepts.size())

	# --- (b) Pop-up + dodge-pursuit log yields movement beats ---
	# Any BuildFightSim log contains choreography including pop-up and dodge-pursuit.
	var a_std := {"hp": 100.0, "pool": 60.0, "regen": 10.0,
		"weapons": [{"id": "a1", "damage": 12.0, "cost": 2.0, "cadence": 1.0,
			"mount": "hand_r", "fx": "beam"}]}
	var b_std := {"hp": 100.0, "pool": 40.0, "regen": 6.0,
		"weapons": [{"id": "b2", "damage": 8.0, "cost": 3.0, "cadence": 1.5,
			"mount": "hand_r", "fx": "beam"}]}
	var std_events: Array = Sim.simulate(a_std, b_std, 7)
	var std_dur: float = FightLog.duration_sec(std_events)
	var std_shots: Array = Hybrid.build_shot_list(std_events, std_dur)
	var has_popup_shot := false
	var has_chase_shot := false
	for s in std_shots:
		if s.mode == "popup_burst":
			has_popup_shot = true
		if s.mode == "chase_pursuit":
			has_chase_shot = true
	check(has_popup_shot, "enriched (b): log with pop-up advances yields >= 1 popup_burst shot")
	check(has_chase_shot, "enriched (b): log with dodge-pursuit run yields >= 1 chase_pursuit shot")
	var popup_count := 0
	for s in std_shots:
		if s.mode == "popup_burst":
			popup_count += 1
	check(popup_count <= 1, "enriched (b): popup_burst capped at <= 1 shot (got %d)" % popup_count)

	# --- (c) hero_kill log yields escalated bullet-time ---
	# Build where A has high DPS swarm weapon → fast lethal → hero_kill:true on fire_swarm.
	var w_hk := {"id": "hk1", "damage": 40.0, "cost": 3.0, "cadence": 1.0,
		"mount": "shoulder_r", "fx": "missiles"}
	var build_hk := {"hp": 100.0, "pool": 999.0, "regen": 999.0, "weapons": [w_hk]}
	var foe_hk := {"hp": 100.0, "pool": 0.0, "regen": 0.0, "weapons": []}
	var hk_events: Array = Sim.simulate(build_hk, foe_hk, 0)
	# Confirm hero_kill:true in this log.
	var hk_present := false
	for e in hk_events:
		if e.payload.get("hero_kill", false):
			hk_present = true
	check(hk_present, "enriched (c): high-DPS swarm build produces hero_kill:true event")
	var hk_dur: float = FightLog.duration_sec(hk_events)
	var hk_shots: Array = Hybrid.build_shot_list(hk_events, hk_dur)
	var bt_shots: Array = hk_shots.filter(func(s): return s.mode == "bullet_time")
	check(bt_shots.size() == 1, "enriched (c): hero_kill log has exactly one bullet_time shot")
	if bt_shots.size() == 1:
		var bt: Dictionary = bt_shots[0]
		# Escalated: hero_kill bullet-time is longer than plain bullet-time (BT_POST=0.35; hero_kill=0.6)
		var bt_window := float(bt.t1) - float(bt.t0)
		check(bt_window > 0.55, "enriched (c): hero_kill bullet-time window > 0.55s realtime (got %.3f)" % bt_window)
		check(bool(bt.get("hero_kill", false)), "enriched (c): bullet_time shot dict carries hero_kill:true flag")
		# Slower time_scale than standard (standard BT_SCALE=0.07; hero_kill=0.05)
		check(float(bt.time_scale) < 0.06, "enriched (c): hero_kill time_scale < 0.06 (got %.3f)" % float(bt.time_scale))
