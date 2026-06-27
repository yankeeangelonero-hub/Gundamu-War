extends SceneTree
## TDD: showcase resolver + fully-expressed showcase kits.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func _initialize() -> void:
	var Gen := load("res://scripts/sim/loadout_fight_generator.gd")
	check(Gen != null, "loadout_fight_generator.gd loads")
	if Gen == null:
		_finish()
		return
	var catalog: Dictionary = Gen.load_catalog()

	var rifle: Dictionary = Gen.resolve_showcase(catalog, "rifle")
	check(str(rifle.get("kit", "")) == "rifle_missile_showcase", "rifle showcase resolves to its kit")
	check(str(rifle.get("opponent", "")) == "artillery_ghost", "rifle showcase foil is artillery_ghost")
	check(int(rifle.get("seed", -1)) == 77, "rifle showcase seed is 77")
	check(absf(float(rifle.get("chaos", -1.0)) - 0.5) < 0.001, "rifle showcase chaos is 0.5")

	var buster: Dictionary = Gen.resolve_showcase(catalog, "buster")
	check(str(buster.get("kit", "")) == "buster_artillery_showcase", "buster showcase resolves to its kit")
	check(str(buster.get("opponent", "")) == "pressure_ghost", "buster showcase foil is pressure_ghost")

	var saber: Dictionary = Gen.resolve_showcase(catalog, "saber")
	check(str(saber.get("kit", "")) == "saber_booster_showcase", "saber showcase resolves to its kit")
	check(str(saber.get("opponent", "")) == "pressure_ghost", "saber showcase foil is pressure_ghost")

	var loadout: Dictionary = Gen.resolve_player_loadout(catalog, str(rifle.get("kit", "")), "pilot_aya")
	check((loadout.get("weapons", []) as Array).size() >= 3, "rifle showcase kit is fully expressed (>=3 weapons)")

	check(str(Gen.resolve_showcase(catalog, "nope").get("kit", "")) == "", "unknown showcase resolves empty")

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
