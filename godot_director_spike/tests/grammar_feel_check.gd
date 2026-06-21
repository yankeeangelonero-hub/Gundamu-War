extends SceneTree
## Unit test — FeelProfile as a LIVE handle: heft + tempo visibly change the staging.
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "Extensibility": heft -> intensity + range-band preference; tempo -> cadence;
##   mode_mix -> exchange proportion.
##
## heft: heavier -> closer engage band, smaller strafe, bigger boost hop, and (as a target) it
##   resists the sell knockback. tempo: faster -> quicker strafe oscillation. So a heavy slow
##   bruiser and a light fast skirmisher stage differently from the SAME truth.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func prof(heft_a: float, tempo_a: float, heft_b := 0.5, tempo_b := 0.5) -> Dictionary:
	return {
		"A": {"heft": heft_a, "tempo": tempo_a, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": heft_b, "tempo": tempo_b, "mode_mix": {"ranged": 1.0}},
	}

func truth_log() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 25, "hp_after": 75}},
		{"tick": 22, "seq": 3, "actor": "B", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 25, "hp_after": 75}},
		{"tick": 32, "seq": 4, "actor": "A", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 25, "hp_after": 50}},
	]

func dist_at(C, staged: Array, t: int) -> float:
	var a: Vector2 = C.position_at(staged, "A", t)
	var b: Vector2 = C.position_at(staged, "B", t)
	return a.distance_to(b)

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	if C == null:
		print("---- 1 FAIL"); quit(1); return

	var truth := truth_log()

	# --- heft -> engage band: a heavy A closes; a light A keeps its distance. Measured at A's
	#     first shot impact (tick 12), when A is planted at its engage band and B is still at spawn.
	var heavy: Array = C.stage(truth, 7, prof(0.9, 0.5))
	var light: Array = C.stage(truth, 7, prof(0.1, 0.5))
	var d_heavy := dist_at(C, heavy, 12)
	var d_light := dist_at(C, light, 12)
	check(d_heavy < d_light - 10.0, "heft: a heavy A engages CLOSER than a light A (%.1f vs %.1f)" % [d_heavy, d_light])

	# --- tempo -> strafe cadence: a fast A and a slow A trace different paths.
	var fast: Array = C.stage(truth, 7, prof(0.5, 0.95))
	var slow: Array = C.stage(truth, 7, prof(0.5, 0.05))
	check(fast != slow, "tempo: a fast A and a slow A stage differently")

	# --- heft (as target) -> sell resistance: a HEAVY B is thrown LESS by the same hit than a
	#     light B. Measured as B's displacement across the sell window after A's hit at tick 12.
	var b_heavy: Array = C.stage(truth, 7, prof(0.5, 0.5, 0.9, 0.5))
	var b_light: Array = C.stage(truth, 7, prof(0.5, 0.5, 0.1, 0.5))
	var hb0: Vector2 = C.position_at(b_heavy, "B", 12)
	var hb1: Vector2 = C.position_at(b_heavy, "B", 16)
	var lb0: Vector2 = C.position_at(b_light, "B", 12)
	var lb1: Vector2 = C.position_at(b_light, "B", 16)
	var heavy_throw := hb0.distance_to(hb1)
	var light_throw := lb0.distance_to(lb1)
	check(heavy_throw < light_throw, "heft: a heavy B resists the sell (thrown %.1f vs light %.1f)" % [heavy_throw, light_throw])

	# --- determinism with profiles.
	check(C.stage(truth, 7, prof(0.9, 0.5)) == heavy, "stage is deterministic per profile")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
