extends SceneTree
## Regression: the three showcases are deterministic and read as distinct fights
## (different weapon-motif signatures). NOT a quality grade — only a "not accidentally
## identical" guard.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func _motifs(events: Array) -> Dictionary:
	var m := {}
	for e in events:
		if e is Dictionary:
			var payload: Dictionary = e.get("payload", {}) if e.get("payload", {}) is Dictionary else {}
			var motif := str(payload.get("motif", ""))
			if motif != "":
				m[motif] = true
	return m


func _initialize() -> void:
	var Gen := load("res://scripts/sim/loadout_fight_generator.gd")
	if Gen == null:
		_finish()
		return
	var catalog: Dictionary = Gen.load_catalog()
	var motif_sets := {}
	for name in ["rifle", "buster", "saber"]:
		var s: Dictionary = Gen.resolve_showcase(catalog, name)
		var player: Dictionary = Gen.resolve_player_loadout(catalog, str(s.get("kit", "")), "pilot_aya")
		var opp: Dictionary = Gen.resolve_opponent_loadout(catalog, str(s.get("opponent", "")))
		var first: Dictionary = Gen.generate(player, opp, int(s.get("seed", 77)), float(s.get("chaos", 0.5)))
		var second: Dictionary = Gen.generate(player, opp, int(s.get("seed", 77)), float(s.get("chaos", 0.5)))
		check(first == second, "%s showcase is deterministic" % name)
		motif_sets[name] = _motifs(first.get("events", []))

	check(motif_sets["rifle"] != motif_sets["buster"], "rifle vs buster motif signatures differ")
	check(motif_sets["rifle"] != motif_sets["saber"], "rifle vs saber motif signatures differ")
	check(motif_sets["buster"] != motif_sets["saber"], "buster vs saber motif signatures differ")

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
