extends SceneTree
## Unit test — the four exchange modes (closed grammar vocabulary).
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "Exchanges (Layer 3)", Testing "CG-CONTRAST — closed per-mode registry (4)".
##
## Each mode stages a distinct silhouette and passes its own contrast metric: beam-trade
## (strafe at mid range), swarm (stand off + target weaves), dodge-pursuit (charge + sustained
## weave), melee (dash to a clash). The gate is dropped, so the SELECTED mode is staged. Every
## mode must still hold CG-NO-PRESPOIL and the range/measure gate.

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

# A short A-on-B fight where every A shot is forced to `mode` via its mode_weights.
func forced_truth(mode: String) -> Array:
	var w := {"beam-trade": 0.0, "swarm": 0.0, "dodge-pursuit": 0.0, "melee": 0.0}
	w[mode] = 1.0
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",      "payload": {"motif": "x", "tier": 2, "travel": 5, "outcome": "hit", "damage": 25, "hp_after": 75, "mode_weights": w}},
		{"tick": 24, "seq": 3, "actor": "A", "kind": "shot",      "payload": {"motif": "x", "tier": 2, "travel": 5, "outcome": "hit", "damage": 25, "hp_after": 50, "mode_weights": w}},
		{"tick": 38, "seq": 4, "actor": "A", "kind": "shot",      "payload": {"motif": "x", "tier": 2, "travel": 5, "outcome": "hit", "damage": 50, "hp_after": 0, "lethal": true, "mode_weights": w}},
		{"tick": 38, "seq": 5, "actor": "B", "kind": "destroyed", "payload": {}},
	]

var C
var GM

func gates_ok(truth: Array, staged: Array) -> bool:
	var dur := 39
	var td: Array = GM.truth_dom(truth, {"A": 100.0, "B": 100.0})
	var sd: Array = GM.staged_dom(staged)
	var np: bool = GM.no_prespoil_ok(td, sd, dur)
	var in_band := true
	for e in truth:
		if e.kind != "shot" or e.payload.get("outcome", "") != "hit":
			continue
		var tg := "B" if e.actor == "A" else "A"
		var ap: Vector2 = C.position_at(staged, e.actor, int(e.tick))
		var bp: Vector2 = C.position_at(staged, tg, int(e.tick))
		if ap.distance_to(bp) > float(C._P.RANGE_FAR):
			in_band = false
	return np and in_band

func _init() -> void:
	C = load("res://scripts/sim/choreographer.gd")
	GM = load("res://scripts/sim/grammar_metrics.gd")

	# Each mode is actually SELECTED (gate dropped) and staged.
	for mode in ["beam-trade", "swarm", "dodge-pursuit", "melee"]:
		var beats: Array = C.schedule(forced_truth(mode), profiles(), C.load_mode_map())
		check(beats.size() >= 1 and beats[0].exchange_mode == mode,
			"%s is selected and staged (gate dropped)" % mode)

	# beam-trade.
	var bt := forced_truth("beam-trade")
	var bt_s: Array = C.stage(bt, 7, profiles())
	check(GM.beam_trade_contrast_ok(bt_s, "A"), "beam-trade contrast holds")
	check(gates_ok(bt, bt_s), "beam-trade holds no-prespoil + range")

	# swarm: the struck B weaves under the salvo.
	var sw := forced_truth("swarm")
	var sw_s: Array = C.stage(sw, 7, profiles())
	check(GM.swarm_contrast_ok(sw_s, "B"), "swarm contrast holds (B weaves)")
	check(gates_ok(sw, sw_s), "swarm holds no-prespoil + range")

	# dodge-pursuit: B sustains a weave away from the charging A.
	var dp := forced_truth("dodge-pursuit")
	var dp_s: Array = C.stage(dp, 7, profiles())
	check(GM.dodge_pursuit_contrast_ok(dp_s, "B"), "dodge-pursuit contrast holds (B weaves away)")
	check(gates_ok(dp, dp_s), "dodge-pursuit holds no-prespoil + range")

	# melee: A dashes to a clash (speed spike -> contact dwell).
	var ml := forced_truth("melee")
	var ml_s: Array = C.stage(ml, 7, profiles())
	check(GM.melee_contrast_ok(ml_s, "A"), "melee contrast holds (A dashes to contact)")
	check(gates_ok(ml, ml_s), "melee holds no-prespoil + range")

	# the modes stage DIFFERENTLY (silhouettes differ).
	check(bt_s != sw_s and sw_s != dp_s and dp_s != ml_s, "the four modes stage distinct motion")

	# --- per-weapon mode_weights (S2): with a NEUTRAL pilot (no mode_mix lean), the WEAPON MOTIF
	#     drives the mode via the data table — score = weight x feel collapses to the weapon argmax.
	var neutral := {"A": {"heft": 0.5, "tempo": 0.5, "mode_mix": {}}, "B": {"heft": 0.5, "tempo": 0.5, "mode_mix": {}}}
	var motif_mode := {"beam": "beam-trade", "missiles": "swarm", "vulcan": "dodge-pursuit", "saber": "melee"}
	for motif in motif_mode:
		var t := [
			{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
			{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
			{"tick": 14, "seq": 2, "actor": "A", "kind": "shot",  "payload": {"motif": motif, "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 80}},
		]
		var bts: Array = C.schedule(t, neutral, C.load_mode_map())
		check(bts.size() >= 1 and bts[0].exchange_mode == motif_mode[motif],
			"motif '%s' selects %s via grammar_motif_weights.json" % [motif, motif_mode[motif]])

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
