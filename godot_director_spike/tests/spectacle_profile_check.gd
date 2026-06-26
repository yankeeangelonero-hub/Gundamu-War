extends SceneTree
## Characterization scaffold for CF-FIREWORKS fight-log spectacle profiles.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func approx(a: float, b: float, tol := 0.01) -> bool:
	return absf(a - b) <= tol


func _initialize() -> void:
	var FightLog := load("res://scripts/fight_log.gd")
	var Profile := load("res://scripts/sim/spectacle_profile.gd")
	var Main := load("res://scripts/main.gd")
	check(Profile != null, "spectacle_profile.gd loads")
	if Profile == null or FightLog == null:
		_finish()
		return

	var events: Array = FightLog.load_events("res://data/fight_log_everything.json")
	var baseline: Dictionary = Profile.profile(events, "fight_log_everything", {"source": "authored"})
	check(approx(float(baseline.duration_sec), FightLog.duration_sec(events)),
		"baseline duration matches FightLog.duration_sec")
	check(int(baseline.event_count) == 101, "baseline event count is 101")
	check(int(baseline.attack_count) == 50, "baseline attack count is 50")
	check(int(baseline.movement_profile.advance_count) == 48, "baseline advance count is 48")
	check(int(baseline.movement_profile.boost_count) == 10, "baseline boost count is 10")
	for kind in ["fire_beam", "fire_burst", "fire_missiles", "fire_buster"]:
		check(int(baseline.weapon_mix.get(kind, 0)) > 0, "baseline weapon mix includes %s" % kind)
	check(str(baseline.finisher.kind) == "fire_buster", "baseline finisher is buster")
	check(bool(baseline.finisher.heavy), "baseline finisher is heavy")
	check(int(baseline.heavy_beat_count) > 0, "baseline counts heavy beats")
	check(float(baseline.longest_dead_air_sec) >= 0.0, "baseline dead-air metric is non-negative")
	check(baseline.director_beats.bullet_time_finisher, "baseline exposes finisher beat")
	check(baseline.director_beats.aftermath_hold, "baseline exposes aftermath beat")

	var compare_self: Dictionary = Profile.compare(baseline, baseline)
	check(bool(compare_self.passes), "baseline passes comparison against itself")
	check(Profile.format_summary(baseline).contains("50 atk"), "summary includes attack count")

	if Main != null:
		var m = Main.new()
		m.set("_debug_live", false)
		m._on_debug_preset_changed("A", "bruiser")
		var bruiser_profile: Dictionary = Profile.profile(m.get("_events"), "bruiser")
		m._on_debug_preset_changed("A", "skirmisher")
		var skirmisher_profile: Dictionary = Profile.profile(m.get("_events"), "skirmisher")
		check(bruiser_profile.weapon_mix != skirmisher_profile.weapon_mix,
			"archetype loadouts produce different spectacle weapon mixes")
		check(int(bruiser_profile.weapon_mix.get("melee", 0)) > 0,
			"bruiser profile includes melee")
		check(int(skirmisher_profile.weapon_mix.get("fire_missiles", 0)) > 0,
			"skirmisher profile includes missiles")
		m.free()

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
