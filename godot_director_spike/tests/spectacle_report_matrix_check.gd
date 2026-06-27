extends SceneTree
## TDD checks for the real archetype/opponent spectacle-report matrix runner on Main.
##
## build_spectacle_report() drives the live loadout pipeline (generate -> stage -> viewer)
## for every kit x opponent pair, profiles each against the fight_log_everything baseline,
## and returns one SpectacleReport. Same seed + chaos must reproduce the identical report.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func _initialize() -> void:
	var Main := load("res://scripts/main.gd")
	check(Main != null, "main.gd loads")
	if Main == null:
		_finish()
		return

	var m = Main.new()
	var report: Dictionary = m.build_spectacle_report(77, 0.5)
	check(str(report.get("schema", "")) == "km-spectacle-report-v0", "matrix report carries report schema")
	check(str(report.get("baseline_id", "")) == "fight_log_everything", "matrix report uses the fireworks baseline")
	check(int(report.get("cell_count", 0)) == 9, "matrix report covers 3 kits x 3 opponents")

	var cells: Array = report.get("cells", [])
	check(cells.size() == 9, "matrix report exposes nine cells")
	var labelled := true
	var profiled := true
	for cell in cells:
		var c: Dictionary = cell
		if not str(c.get("label", "")).contains(" vs "):
			labelled = false
		if str(c.get("candidate_id", "")) == "":
			profiled = false
		var metrics: Dictionary = c.get("metrics", {})
		if int(metrics.get("attack_count", 0)) <= 0:
			profiled = false
	check(labelled, "every cell has a 'kit vs opponent' label")
	check(profiled, "every cell carries a profiled candidate with attacks")

	var report_again: Dictionary = m.build_spectacle_report(77, 0.5)
	check(report == report_again, "same seed + chaos reproduce the identical matrix report")
	m.free()

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
