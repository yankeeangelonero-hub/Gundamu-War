extends SceneTree
## Regression for the opening-rush contact collapse + positional drift (2026-06-27).
##
## Two pure-ranged builds (beam-trade) must never be staged into contact range, and the
## engagement must stay bounded near the arena centre (no monotonic drift). Both were
## violated because beam-trade engages placed each mech relative to the ENEMY's transient
## mid-dash position; the fix anchors standoff placement to the fixed centre / own side.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func _initialize() -> void:
	var Gen := load("res://scripts/sim/loadout_fight_generator.gd")
	var Choreo := load("res://scripts/sim/choreographer.gd")
	var catalog: Dictionary = Gen.load_catalog()
	# rifle (gunner, ranged) vs the artillery ghost (anvil, also ranged weapons) — both beam-trade.
	var s: Dictionary = Gen.resolve_showcase(catalog, "rifle")
	var player: Dictionary = Gen.resolve_player_loadout(catalog, str(s.kit), "pilot_aya")
	var opp: Dictionary = Gen.resolve_opponent_loadout(catalog, str(s.opponent))
	var truth: Array = Gen.generate(player, opp, int(s.seed), float(s.chaos)).get("events", [])
	var feel := {
		"A": Choreo.apply_preset(str(player.get("grammar_preset", "gunner"))),
		"B": Choreo.apply_preset(str(opp.get("grammar_preset", "anvil"))),
	}
	var staged: Array = Choreo.stage(truth, int(s.seed), feel)
	var trace: Array = Choreo.movement_trace(staged)

	var min_dist := 1.0e9
	var max_abs_x := 0.0
	for r in trace:
		min_dist = minf(min_dist, float(r.dist_to_enemy))
		max_abs_x = maxf(max_abs_x, absf(float(r.x)))

	print("measured: min_dist=%.1f  max_abs_x=%.1f" % [min_dist, max_abs_x])
	# Two no-melee builds must never be staged closer than a sane ranged floor.
	check(min_dist >= 10.0, "ranged beam-trade fight never collapses to contact (min dist >= 10)")
	# The engagement must stay bounded near centre (spawn is +-40); no runaway drift.
	check(max_abs_x < 120.0, "engagement stays bounded near centre (no positional drift)")

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
