extends SceneTree
## Unit test — exchange-mode composition (Layer 3 scheduler, Step 0).
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "Exchange-mode composition (total)".
##
## select_mode(mode_mix, mode_weights, mode_map) is the REAL selection seam: it maps the
## shooter's FeelProfile feel-modes to grammar modes via mode_map, weights by the firing
## weapon's mode_weights, and picks the argmax (fixed tie order beam-trade<swarm<dodge-pursuit
## <melee). Pass-1 beam-trade gating is a SEPARATE thin layer (gate_mode), so the selection is
## exercised even while only beam-trade is staged.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

# Feel-mode -> grammar-mode map (the v1 data table content).
func mode_map() -> Dictionary:
	return {"ranged": "beam-trade", "barrage": "swarm", "melee": "melee"}

# A neutral weapon: equal weight on all four grammar modes, so the shooter's mode_mix decides.
func flat_weapon() -> Dictionary:
	return {"beam-trade": 0.25, "swarm": 0.25, "dodge-pursuit": 0.25, "melee": 0.25}

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	check(C != null, "choreographer.gd loads")
	if C == null:
		print("---- %d FAIL" % maxi(fails, 1))
		quit(1)
		return

	# --- argmax: with a flat weapon, the shooter's dominant feel-mode picks the grammar mode.
	check(C.select_mode({"melee": 1.0}, flat_weapon(), mode_map()) == "melee",
		"a melee-leaning shooter with a flat weapon selects melee")
	check(C.select_mode({"ranged": 1.0}, flat_weapon(), mode_map()) == "beam-trade",
		"a ranged-leaning shooter with a flat weapon selects beam-trade")
	check(C.select_mode({"barrage": 1.0}, flat_weapon(), mode_map()) == "swarm",
		"a barrage-leaning shooter with a flat weapon selects swarm")

	# --- the weapon's mode_weights interact: a weapon that strongly weights one grammar mode
	#     overrides a split feel-mix (score = weight × feel, not feel alone).
	var melee_weapon := {"beam-trade": 0.0, "swarm": 0.0, "dodge-pursuit": 0.0, "melee": 1.0}
	check(C.select_mode({"ranged": 0.5, "melee": 0.5}, melee_weapon, mode_map()) == "melee",
		"a melee-heavy weapon overrides a split ranged/melee shooter")

	# --- tie-break: equal scores resolve to the earliest mode in GRAMMAR_MODES order.
	#     {ranged:0.5, melee:0.5} with a flat weapon ties beam-trade and melee at 0.125 → beam-trade.
	check(C.select_mode({"ranged": 0.5, "melee": 0.5}, flat_weapon(), mode_map()) == "beam-trade",
		"a beam-trade/melee score tie resolves to beam-trade (earliest in fixed order)")

	# --- all-zero score: the feel-mode and the weapon weight never coincide on any grammar
	#     mode, so every score is 0 → fall back to argmax(mode_weights). Here dodge-pursuit.
	var dodge_weapon := {"beam-trade": 0.0, "swarm": 0.0, "dodge-pursuit": 1.0, "melee": 0.0}
	check(C.select_mode({"barrage": 1.0}, dodge_weapon, mode_map()) == "dodge-pursuit",
		"an all-zero score falls back to argmax(mode_weights)")

	# --- fully degenerate: no feel, no weapon weight → beam-trade (the final fallback).
	check(C.select_mode({}, {"beam-trade": 0.0, "swarm": 0.0, "dodge-pursuit": 0.0, "melee": 0.0}, mode_map()) == "beam-trade",
		"a fully degenerate input falls back to beam-trade")

	# --- the mode-map data resource loads to the v1 table.
	var loaded: Dictionary = C.load_mode_map()
	check(loaded == mode_map(), "load_mode_map() reads res://data/grammar_mode_map.json")

	# --- load-validation: the map must cover every FeelProfile feel-mode and every value must
	#     be one of the four grammar modes.
	var FP := load("res://scripts/sim/feel_profile.gd")
	check(C.validate_mode_map(loaded, FP.V1_MODES) == true,
		"the v1 mode-map covers every FeelProfile feel-mode")
	check(C.validate_mode_map({"ranged": "beam-trade", "barrage": "swarm"}, FP.V1_MODES) == false,
		"a mode-map missing a feel-mode key fails validation")
	check(C.validate_mode_map({"ranged": "beam-trade", "barrage": "swarm", "melee": "not-a-mode"}, FP.V1_MODES) == false,
		"a mode-map with a non-grammar-mode value fails validation")

	# --- pass-1 gating: only beam-trade is staged this pass, so every selection is gated to it.
	check(C.gate_mode("melee") == "beam-trade", "pass-1 gating maps melee selection to beam-trade")
	check(C.gate_mode("swarm") == "beam-trade", "pass-1 gating maps swarm selection to beam-trade")
	check(C.gate_mode("beam-trade") == "beam-trade", "pass-1 gating keeps beam-trade as beam-trade")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
