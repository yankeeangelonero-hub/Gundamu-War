extends SceneTree
## Unit test — Layer 3 beam-trade exchange (the new stage() pipeline).
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "Architecture — four layers", "Exchanges (Layer 3)", Testing "Range/measure" + "CG-NO-PRESPOIL".
##
## stage(truth, seed, feel_profiles) runs schedule() -> beam-trade exchange -> merge. It
## replaces the ambient/reactive model: evade -> weave near-miss, stagger -> sell-at-impact,
## range-tighten -> range band. This file drives the exchange TDD; the surviving structural
## invariants (pass-through, spawn placement, determinism) are asserted here too.

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

# A beam-trade duel: A and B trade hits at range; B is destroyed at the end.
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

# A one-sided stomp: A lands four beam hits; B never connects; B is destroyed.
func stomp_log() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 10, "seq": 2, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 30, "hp_after": 70}},
		{"tick": 14, "seq": 3, "actor": "B", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "miss"}},
		{"tick": 20, "seq": 4, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 30, "hp_after": 40}},
		{"tick": 30, "seq": 5, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 25, "hp_after": 15}},
		{"tick": 40, "seq": 6, "actor": "A", "kind": "shot",      "payload": {"motif": "buster", "tier": 3, "travel": 6, "outcome": "hit", "damage": 40, "lethal": true, "hp_after": 0}},
		{"tick": 40, "seq": 7, "actor": "B", "kind": "destroyed", "payload": {}},
	]

func _duration(events: Array) -> int:
	var d := 0
	for e in events:
		d = maxi(d, int(e.tick))
	return d + 1

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	check(C != null, "choreographer.gd loads")
	if C == null:
		print("---- %d FAIL" % maxi(fails, 1))
		quit(1)
		return

	var truth := truth_log()
	var staged: Array = C.stage(truth, 7, profiles())
	check(staged is Array, "stage(truth, seed, feel_profiles) returns an Array")

	# --- truth pass-through: every truth field survives unchanged; spawns gain {x,z}.
	var pass_through := true
	for src in truth:
		var found := {}
		for out in staged:
			if int(out.tick) == int(src.tick) and out.get("seq", -999) == src.get("seq", -998) \
					and out.kind == src.kind and out.actor == src.actor:
				found = out
				break
		if found.is_empty():
			pass_through = false
			break
		for k in src:
			if k == "payload":
				continue
			if found.get(k) != src[k]:
				pass_through = false
		for k in src.payload:
			if found.payload.get(k) != src.payload[k]:
				pass_through = false
	check(pass_through, "every truth event passes through unedited (spawns only gain {x,z})")

	# --- mirrored spawn placement: A at (-SPAWN_X, 0), B at (+SPAWN_X, 0).
	var spawn_a := {}
	var spawn_b := {}
	for e in staged:
		if e.kind == "spawn" and e.actor == "A":
			spawn_a = e
		elif e.kind == "spawn" and e.actor == "B":
			spawn_b = e
	check(not spawn_a.is_empty() and float(spawn_a.payload.x) == -C.SPAWN_X and float(spawn_a.payload.z) == 0.0,
		"A spawns at (-SPAWN_X, 0)")
	check(not spawn_b.is_empty() and float(spawn_b.payload.x) == C.SPAWN_X and float(spawn_b.payload.z) == 0.0,
		"B spawns at (+SPAWN_X, 0)")

	# --- the exchange emits advance beats (the mechs are staged, not frozen at spawn).
	var advances := 0
	for e in staged:
		if e.kind == "advance":
			advances += 1
	check(advances > 0, "the exchange emits advance beats")

	# --- determinism: same (truth, seed, feel_profiles) -> identical staged log.
	check(C.stage(truth, 7, profiles()) == staged, "stage is pure/deterministic")

	# --- canonical merge order: at each tick, every truth event precedes that tick's advances,
	#     and advances are A-before-B.
	var order_ok := true
	for k in range(staged.size() - 1):
		var a: Dictionary = staged[k]
		var b: Dictionary = staged[k + 1]
		if int(a.tick) > int(b.tick):
			order_ok = false
		elif int(a.tick) == int(b.tick):
			if a.kind != "advance" and b.kind == "advance":
				pass  # truth before advance: fine
			elif a.kind == "advance" and b.kind != "advance":
				order_ok = false  # advance before truth at same tick: wrong
			elif a.kind == "advance" and b.kind == "advance":
				if C._actor_id(a.actor) > C._actor_id(b.actor):
					order_ok = false
	check(order_ok, "canonical merge order (truth before advances; advances A before B)")

	# --- position model: the movement trace's x/z agrees with position_at at every row.
	var trace_ok := true
	for row in C.movement_trace(staged):
		var p: Vector2 = C.position_at(staged, row.actor, int(row.tick))
		if absf(float(row.x) - p.x) > 1e-5 or absf(float(row.z) - p.y) > 1e-5:
			trace_ok = false
	check(trace_ok, "movement_trace x/z agrees with position_at (no drift)")

	# --- range/measure gate: every connecting shot is in-band at its impact tick (<= RANGE_FAR).
	var in_band := true
	for e in truth:
		if e.kind != "shot" or e.payload.get("outcome", "") != "hit":
			continue
		var shooter: String = e.actor
		var target := "B" if shooter == "A" else "A"
		var sp: Vector2 = C.position_at(staged, shooter, int(e.tick))
		var tp: Vector2 = C.position_at(staged, target, int(e.tick))
		if sp.distance_to(tp) > float(C._P.RANGE_FAR):
			in_band = false
	check(in_band, "every connecting shot is in range band (<= RANGE_FAR) at impact")

	# --- sell-at-impact: on a connecting hit, the struck mech is displaced AWAY from the
	#     shooter across the reaction window (drives the staged_dom sell channel; CG-BLIND-safe
	#     because it is read only at impact). Check the first connecting A->B hit (tick 12).
	var sh := "A"
	var tg := "B"
	var impact := 12
	var react: int = int(C._P.REACT)
	var sp0: Vector2 = C.position_at(staged, sh, impact)
	var tp0: Vector2 = C.position_at(staged, tg, impact)
	var sp1: Vector2 = C.position_at(staged, sh, impact + react - 1)
	var tp1: Vector2 = C.position_at(staged, tg, impact + react - 1)
	check(sp1.distance_to(tp1) > sp0.distance_to(tp0), "a connecting hit shoves the struck mech away from the shooter (a sell)")

	# --- CG-NO-PRESPOIL (the hard gate): the staged motion must not reveal the winner earlier
	#     than the truth does. Computed by the increment-1 validator straight off the raw staged
	#     trace (never a choreographer hook). Sells land only at impact ticks (= when truth
	#     reveals damage), so staging is no-pre-spoil by construction.
	var GM := load("res://scripts/sim/grammar_metrics.gd")
	var spawn_hp := {"A": 100.0, "B": 100.0}
	var dur := _duration(truth)
	var td: Array = GM.truth_dom(truth, spawn_hp)
	var sd: Array = GM.staged_dom(staged)
	check(GM.no_prespoil_ok(td, sd, dur), "CG-NO-PRESPOIL holds on the trade fight")

	# --- the harder case: a one-sided STOMP. A hits B repeatedly; B never connects; B dies.
	#     truth_dom climbs early for A — staging must not betray it any earlier.
	var stomp := stomp_log()
	var staged_s: Array = C.stage(stomp, 7, profiles())
	var td_s: Array = GM.truth_dom(stomp, spawn_hp)
	var sd_s: Array = GM.staged_dom(staged_s)
	check(GM.no_prespoil_ok(td_s, sd_s, _duration(stomp)), "CG-NO-PRESPOIL holds on the stomp fight")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
