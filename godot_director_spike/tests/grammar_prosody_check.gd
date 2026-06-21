extends SceneTree
## Unit test — Layer 1 prosody / CG-CONTRAST (beam-trade).
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   Two universal laws "CG-CONTRAST", Testing "CG-CONTRAST — closed per-mode registry".
##
## The beam-trade contrast gate passes if EITHER the speed histogram is bimodal (pause
## fraction >= BIMODAL_MIN) OR aim/recoil bearing alternation is present. Weight and snap come
## from the contrast between stillness and sudden displacement (C0), not from velocity.

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

func truth_log() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 30, "hp_after": 70}},
		{"tick": 20, "seq": 3, "actor": "B", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 30, "hp_after": 70}},
		{"tick": 30, "seq": 4, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 35, "hp_after": 35}},
		{"tick": 44, "seq": 5, "actor": "A", "kind": "shot",      "payload": {"motif": "buster", "tier": 3, "travel": 6, "outcome": "hit", "damage": 40, "lethal": true, "hp_after": 0}},
		{"tick": 44, "seq": 6, "actor": "B", "kind": "destroyed", "payload": {}},
	]

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	var GM := load("res://scripts/sim/grammar_metrics.gd")
	check(C != null and GM != null, "modules load")
	if C == null or GM == null:
		print("---- %d FAIL" % maxi(fails, 1))
		quit(1)
		return

	var staged: Array = C.stage(truth_log(), 7, profiles())

	# --- CG-CONTRAST (beam-trade) holds for both pilots.
	check(GM.beam_trade_contrast_ok(staged, "A"), "beam-trade CG-CONTRAST holds for A")
	check(GM.beam_trade_contrast_ok(staged, "B"), "beam-trade CG-CONTRAST holds for B")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
