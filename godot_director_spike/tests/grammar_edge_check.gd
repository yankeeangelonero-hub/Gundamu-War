extends SceneTree
## Edge-fight fixture suite (first-class, owner request).
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   Testing "Edge-fight fixture suite".
##
## A library of edge truths, one per classifier shape. Each asserts: (1) the shape classifies
## as expected, (2) the template_id maps via grammar_templates.json, (3) CG-NO-PRESPOIL holds on
## the staged output. Each also reports its balance diagnostic decided_tick / duration.
## (truth_dom uses each shot's `damage`; hp_after is illustrative only.)

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func profiles() -> Dictionary:
	return {
		"A": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
	}

func spawn() -> Array:
	return [
		{"tick": 0, "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0, "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
	]

func shot(tick: int, seq: int, actor: String, motif: String, tier: int, travel: int, outcome: String, damage := 0, lethal := false) -> Dictionary:
	var p := {"motif": motif, "tier": tier, "travel": travel, "outcome": outcome}
	if outcome == "hit":
		p["damage"] = damage
	if lethal:
		p["lethal"] = true
	return {"tick": tick, "seq": seq, "actor": actor, "kind": "shot", "payload": p}

func destroyed(tick: int, seq: int, actor: String) -> Dictionary:
	return {"tick": tick, "seq": seq, "actor": actor, "kind": "destroyed", "payload": {}}

# --- the six edge fixtures ---------------------------------------------------------------

func fx_instant() -> Array:  # lead established at tick 3, kill late -> decided_frac tiny
	return spawn() + [
		shot(3,  2, "A", "buster", 3, 3, "hit", 60),
		shot(30, 3, "A", "buster", 3, 6, "hit", 40, true),
		destroyed(30, 4, "B"),
	]

func fx_stomp() -> Array:  # A dominates by tick 16 and holds; long tail; margin high
	return spawn() + [
		shot(8,  2, "A", "beam", 2, 5, "hit", 40),
		shot(16, 3, "A", "beam", 2, 5, "hit", 30),
		shot(20, 4, "B", "burst", 1, 4, "miss"),
		shot(35, 5, "B", "burst", 1, 4, "miss"),
		shot(50, 6, "A", "buster", 3, 6, "hit", 30, true),
		destroyed(50, 7, "B"),
	]

func fx_photofinish() -> Array:  # even trade to ~85% both, A kills last, final margin small
	return spawn() + [
		shot(10, 2, "A", "beam", 2, 5, "hit", 20),
		shot(16, 3, "B", "beam", 2, 5, "hit", 20),
		shot(24, 4, "A", "beam", 2, 5, "hit", 20),
		shot(30, 5, "B", "beam", 2, 5, "hit", 20),
		shot(40, 6, "A", "beam", 2, 5, "hit", 20),
		shot(46, 7, "B", "beam", 2, 5, "hit", 20),
		shot(56, 8, "A", "beam", 2, 5, "hit", 15),
		shot(62, 9, "B", "beam", 2, 5, "hit", 25),
		shot(72, 10, "A", "buster", 3, 6, "hit", 25, true),
		destroyed(72, 11, "B"),
	]

func fx_reversal() -> Array:  # B leads (dom -0.5), A reverses and kills (dom +0.5) -> a flip
	return spawn() + [
		shot(8,  2, "B", "beam", 2, 5, "hit", 50),
		shot(30, 3, "A", "beam", 2, 5, "hit", 50),
		shot(45, 4, "A", "buster", 3, 6, "hit", 50, true),
		destroyed(45, 5, "B"),
	]

func fx_stalemate() -> Array:  # no kill, near-even tiny damage, runs to a cap
	return spawn() + [
		shot(10, 2, "A", "beam", 2, 5, "hit", 10),
		shot(20, 3, "B", "beam", 2, 5, "hit", 10),
		shot(30, 4, "A", "beam", 2, 5, "miss"),
		shot(40, 5, "B", "beam", 2, 5, "miss"),
		shot(60, 6, "A", "beam", 2, 5, "miss"),
	]

func fx_grind() -> Array:  # contested, A wins; lead only resolves at the kill, margin high
	return spawn() + [
		shot(12, 2, "A", "beam", 2, 5, "hit", 30),
		shot(20, 3, "B", "beam", 2, 5, "hit", 30),
		shot(30, 4, "A", "beam", 2, 5, "hit", 35),
		shot(44, 5, "A", "buster", 3, 6, "hit", 40, true),
		destroyed(44, 6, "B"),
	]

# -----------------------------------------------------------------------------------------

var _C
var _GM
var _templates: Dictionary

func _has_kill(truth: Array) -> bool:
	for e in truth:
		if e.kind == "shot" and bool(e.get("payload", {}).get("lethal", false)):
			return true
	return false

func _duration(truth: Array) -> int:
	var d := 0
	for e in truth:
		d = maxi(d, int(e.tick))
	return d + 1

func assert_fixture(name: String, truth: Array, expected_shape: String) -> void:
	var dur := _duration(truth)
	var td: Array = _GM.truth_dom(truth, {"A": 100.0, "B": 100.0})
	var shape: String = _GM.classify_shape(td, _has_kill(truth), dur)
	check(shape == expected_shape, "%s classifies as '%s' (got '%s')" % [name, expected_shape, shape])

	var pres: Dictionary = _C.presentation(truth, 7, profiles())
	check(pres.fight.template_id == _templates.get(expected_shape, ""),
		"%s template_id is '%s'" % [name, _templates.get(expected_shape, "")])

	var staged: Array = _C.stage(truth, 7, profiles())
	var sd: Array = _GM.staged_dom(staged)
	check(_GM.no_prespoil_ok(td, sd, dur), "%s holds CG-NO-PRESPOIL" % name)

	var rev: int = _GM.reveal(td)
	var decided: int = rev if rev < (1 << 20) else (dur - 1)
	print("    [balance] %s decided_tick=%d / duration=%d = %.2f" % [name, decided, dur, float(decided) / float(dur)])

func _init() -> void:
	_C = load("res://scripts/sim/choreographer.gd")
	_GM = load("res://scripts/sim/grammar_metrics.gd")
	_templates = JSON.parse_string(FileAccess.get_file_as_string("res://data/grammar_templates.json"))

	assert_fixture("instant", fx_instant(), "instant")
	assert_fixture("stomp", fx_stomp(), "stomp")
	assert_fixture("photofinish", fx_photofinish(), "photofinish")
	assert_fixture("reversal", fx_reversal(), "reversal")
	assert_fixture("stalemate", fx_stalemate(), "stalemate")
	assert_fixture("grind", fx_grind(), "grind")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
