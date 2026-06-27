extends SceneTree
## TDD checks for the CF-FIREWORKS candidate-vs-baseline matrix report.
##
## SpectacleReport is a pure aggregation layer: given a baseline profile and a list of
## labelled candidate profiles, it runs the spectacle-floor comparison for each cell and
## emits one report artifact (matrix dict + text table + JSON) with pass/fail per cell.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func _passing_profile(log_id: String, shape: String) -> Dictionary:
	return {
		"schema": "km-spectacle-profile-v0",
		"log_id": log_id,
		"matchup_shape": shape,
		"duration_sec": 22.0,
		"attack_count": 48,
		"attack_density_per_sec": 2.0,
		"longest_dead_air_sec": 1.0,
		"weapon_mix": {"fire_beam": 20, "fire_missiles": 12, "fire_buster": 8, "melee": 8},
		"weapon_kind_count": 4,
		"heavy_beat_count": 8,
		"defensive_reversal_count": 4,
		"finisher": {"kind": "fire_buster", "heavy": true, "lethal": true},
	}


func _failing_profile(log_id: String, shape: String) -> Dictionary:
	return {
		"schema": "km-spectacle-profile-v0",
		"log_id": log_id,
		"matchup_shape": shape,
		"duration_sec": 30.0,
		"attack_count": 3,
		"attack_density_per_sec": 0.1,
		"longest_dead_air_sec": 9.0,
		"weapon_mix": {"fire_beam": 3},
		"weapon_kind_count": 1,
		"heavy_beat_count": 0,
		"defensive_reversal_count": 0,
		"finisher": {"kind": "none", "heavy": false, "lethal": false},
	}


func _initialize() -> void:
	var Report := load("res://scripts/sim/spectacle_report.gd")
	check(Report != null, "spectacle_report.gd loads")
	if Report == null:
		_finish()
		return

	var baseline := _passing_profile("fight_log_everything", "authored")
	var candidates := [
		{"label": "rifle_missile_pressure vs pressure_ghost", "profile": _passing_profile("good_cell", "ranged pressure")},
		{"label": "buster_artillery vs duelist_ghost", "profile": _failing_profile("bad_cell", "artillery execution")},
	]

	var report: Dictionary = Report.build(baseline, candidates)
	check(str(report.get("schema", "")) == "km-spectacle-report-v0", "report carries report schema")
	check(str(report.get("baseline_id", "")) == "fight_log_everything", "report names the baseline")
	check(int(report.get("cell_count", 0)) == 2, "report counts both matrix cells")
	check(int(report.get("pass_count", 0)) == 1, "report counts one passing cell")
	check(int(report.get("fail_count", 0)) == 1, "report counts one failing cell")
	check(bool(report.get("all_pass", true)) == false, "report all_pass is false when any cell fails")

	var cells: Array = report.get("cells", [])
	check(cells.size() == 2, "report exposes one entry per cell")
	var good: Dictionary = cells[0]
	var bad: Dictionary = cells[1]
	check(str(good.get("label", "")) == "rifle_missile_pressure vs pressure_ghost", "cell keeps its label")
	check(str(good.get("candidate_id", "")) == "good_cell", "cell keeps the candidate log id")
	check(bool(good.get("passes", false)) == true, "passing cell passes")
	check(bool(bad.get("passes", true)) == false, "failing cell fails")
	check((good.get("checks", {}) as Dictionary).has("dead_air"), "cell carries the floor checks")
	check((bad.get("notes", []) as Array).size() > 0, "failing cell carries notes")
	var bad_metrics: Dictionary = bad.get("metrics", {})
	check(str(bad_metrics.get("finisher_kind", "")) == "none", "cell metrics expose finisher kind")
	check(float(bad_metrics.get("longest_dead_air_sec", 0.0)) == 9.0, "cell metrics expose dead-air")

	var text: String = Report.format_report(report)
	check(text.contains("fight_log_everything"), "text report names the baseline")
	check(text.contains("PASS") and text.contains("FAIL"), "text report shows pass and fail rows")
	check(text.contains("buster_artillery vs duelist_ghost"), "text report lists candidate labels")

	var json_text: String = Report.to_json(report)
	var parsed = JSON.parse_string(json_text)
	check(parsed is Dictionary, "to_json emits parseable JSON")
	check(parsed != null and str(parsed.get("schema", "")) == "km-spectacle-report-v0", "json round-trips the schema")

	# An all-passing matrix reports all_pass true.
	var all_good: Dictionary = Report.build(baseline, [
		{"label": "a", "profile": _passing_profile("a", "duel")},
		{"label": "b", "profile": _passing_profile("b", "duel")},
	])
	check(bool(all_good.get("all_pass", false)) == true, "all-passing matrix reports all_pass true")

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
