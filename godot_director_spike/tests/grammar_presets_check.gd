extends SceneTree
## Unit test — archetype presets (data-driven FeelProfiles + const overrides).
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "Extensibility": a new archetype is a FeelProfile bias / authored preset in the DATA
##   resource grammar_presets.json (heft/tempo/mode_mix + overrides:{<const>:value}).

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func truth() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 25, "hp_after": 75}},
	]

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	var P := load("res://scripts/sim/grammar_params.gd")

	# --- presets load from the data resource.
	var presets: Dictionary = P.load_presets()
	check(presets.has("bruiser") and presets.has("skirmisher") and presets.has("gunner"),
		"grammar_presets.json loads the archetype table")

	# --- apply_preset builds a FeelProfile from an archetype row.
	var bruiser: Dictionary = C.apply_preset("bruiser")
	check(bruiser.heft == 0.9 and bruiser.mode_mix.has("melee") and bruiser.overrides.has("KNOCK"),
		"apply_preset('bruiser') -> heavy, melee-leaning, with a KNOCK override")
	var skirm: Dictionary = C.apply_preset("skirmisher")
	check(skirm.heft == 0.1, "apply_preset('skirmisher') -> light")

	# --- two archetypes stage the same truth differently.
	var as_bruiser := {"A": bruiser, "B": C.apply_preset("gunner")}
	var as_skirm := {"A": skirm, "B": C.apply_preset("gunner")}
	check(C.stage(truth(), 7, as_bruiser) != C.stage(truth(), 7, as_skirm),
		"a bruiser and a skirmisher stage distinct fights")

	# --- a const override reaches the exchange: B with overrides{KNOCK:30} is sold further than
	#     the same-heft B without the override.
	var base_b := {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}}
	var over_b := {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}, "overrides": {"KNOCK": 30.0}}
	var a := {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}}
	var s_base: Array = C.stage(truth(), 7, {"A": a, "B": base_b})
	var s_over: Array = C.stage(truth(), 7, {"A": a, "B": over_b})
	var b0: Vector2 = C.position_at(s_base, "B", 12)
	var b1: Vector2 = C.position_at(s_base, "B", 17)
	var o0: Vector2 = C.position_at(s_over, "B", 12)
	var o1: Vector2 = C.position_at(s_over, "B", 17)
	check(o0.distance_to(o1) > b0.distance_to(b1), "a KNOCK override sells the struck mech further")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
