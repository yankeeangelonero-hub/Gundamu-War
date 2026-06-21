extends SceneTree
## Unit test — advisory diagnostics (reported, never gating).
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md "Advisory diagnostics".
## These assert the measures RUN and are sane, and that the reference-diff distinguishes builds
## — not that any value passes a gate.

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
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 80}},
		{"tick": 22, "seq": 3, "actor": "B", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 80}},
		{"tick": 34, "seq": 4, "actor": "A", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 60}},
	]

func prof(heft: float) -> Dictionary:
	return {
		"A": {"heft": heft, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
	}

func swarm_truth() -> Array:
	var w := {"beam-trade": 0.0, "swarm": 1.0, "dodge-pursuit": 0.0, "melee": 0.0}
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 14, "seq": 2, "actor": "A", "kind": "shot",  "payload": {"motif": "x", "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 80, "mode_weights": w}},
		{"tick": 26, "seq": 3, "actor": "A", "kind": "shot",  "payload": {"motif": "x", "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 60, "mode_weights": w}},
	]

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	var D := load("res://scripts/sim/grammar_diagnostics.gd")

	var staged: Array = C.stage(truth(), 7, prof(0.5))
	var st: Dictionary = D.trace_stats(staged, "A")
	check(is_finite(st.mean_dist) and is_finite(st.mean_speed) and st.mean_speed >= 0.0,
		"trace_stats produces finite distance/speed")
	var frac_sum: float = float(st.pause_frac) + float(st.burst_frac) + float(st.coast_frac)
	check(absf(frac_sum - 1.0) < 1e-6, "pause + burst + coast fractions sum to 1")

	# --- reference-diff distinguishes a heavy (close) build from a light (far) one: the heavy
	#     holds a SMALLER mean distance, so the diff is meaningfully negative.
	var heavy: Array = C.stage(truth(), 7, prof(0.9))
	var light: Array = C.stage(truth(), 7, prof(0.1))
	var diff: Dictionary = D.reference_diff(heavy, light, "A")
	check(float(diff.mean_dist) < -5.0, "reference_diff: a heavy build holds a closer mean distance than a light one (%.1f)" % diff.mean_dist)

	# --- weave_signature catches the swarm dodge (reversals present).
	var sw: Array = C.stage(swarm_truth(), 7, prof(0.5))
	var wsig: Dictionary = D.weave_signature(sw, "B")
	check(int(wsig.reversals) >= 2, "weave_signature reports the swarm target's weave reversals")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
