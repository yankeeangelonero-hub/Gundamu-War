extends SceneTree
## Unit test — CG-BLIND (outcome-blind structural staging), the two hard tests.
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "Outcome-blind structural staging" + Testing "CG-BLIND (two tests)".
##
## Mirror test: applying (swap actor labels A<->B + mirror positions about x) to the truth
## yields structural staging identical up to that relabeling (only the suspense plan differs).
## Prefix-blindness test: a fixture and a variant differing ONLY in a shot's post-impact
## resolution stage byte-identically on [0, impact_tick) for the whole staged trace + causal
## presentation fields — the resolution cannot leak before its own impact.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func profiles() -> Dictionary:
	# Identical profiles so the label swap is a pure mirror (no profile asymmetry to track).
	return {
		"A": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
	}

# A duel with hits, a MISS (weave reaction), and a heavy beat — exercises every reaction path.
func truth_log() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 25, "hp_after": 75}},
		{"tick": 20, "seq": 3, "actor": "B", "kind": "shot",      "payload": {"motif": "burst", "tier": 1, "travel": 4, "outcome": "miss"}},
		{"tick": 30, "seq": 4, "actor": "A", "kind": "shot",      "payload": {"motif": "buster", "tier": 3, "travel": 6, "outcome": "hit", "damage": 30, "hp_after": 45}},
		{"tick": 40, "seq": 5, "actor": "B", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 80}},
		{"tick": 50, "seq": 6, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 25, "hp_after": 20}},
	]

# Relabel every event A<->B (the truth carries no positions, so this is the whole transform).
func swap_actors(truth: Array) -> Array:
	var out := []
	for e in truth:
		var c: Dictionary = e.duplicate(true)
		c.actor = "B" if e.actor == "A" else "A"
		out.append(c)
	return out

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	if C == null:
		print("---- 1 FAIL"); quit(1); return

	var truth := truth_log()
	var staged: Array = C.stage(truth, 7, profiles())
	var end_tick := 50

	# =====================================================================================
	# Mirror test — stage(swap(truth)) mirrors stage(truth): A's path == B's path with x
	# negated (and vice versa), within float tolerance (cos/sin reflection is not bit-exact).
	# =====================================================================================
	var mirrored: Array = C.stage(swap_actors(truth), 7, profiles())
	var EPS := 1e-3
	var mirror_ok := true
	for t in range(end_tick + 1):
		var a: Vector2 = C.position_at(staged, "A", t)
		var b_m: Vector2 = C.position_at(mirrored, "B", t)   # swapped: original A -> mirrored B
		var b: Vector2 = C.position_at(staged, "B", t)
		var a_m: Vector2 = C.position_at(mirrored, "A", t)
		if absf(a.x + b_m.x) > EPS or absf(a.y - b_m.y) > EPS:   # A.x == -mirrorB.x ; A.z == mirrorB.z
			mirror_ok = false
		if absf(b.x + a_m.x) > EPS or absf(b.y - a_m.y) > EPS:
			mirror_ok = false
	check(mirror_ok, "mirror test: stage(swap(truth)) is the x-mirror of stage(truth)")

	# =====================================================================================
	# Prefix-blindness test — flip shot @ tick 30 (seq 4) from hit -> miss (a post-impact
	# resolution change). The staged trace on [0, 30) must be byte-identical for both actors;
	# the causal presentation fields (apparent_initiative) likewise; and it must DIFFER at or
	# after 30 (non-vacuous).
	# =====================================================================================
	var variant := truth_log()
	variant[4].payload = {"motif": "buster", "tier": 3, "travel": 6, "outcome": "miss"}  # was a hit
	var staged_v: Array = C.stage(variant, 7, profiles())
	var impact_k := 30

	var prefix_exact := true
	for t in range(impact_k):
		for actor in ["A", "B"]:
			if C.position_at(staged, actor, t) != C.position_at(staged_v, actor, t):
				prefix_exact = false
	check(prefix_exact, "prefix-blindness: staged trace on [0, impact) is byte-identical (hit vs miss)")

	# causal presentation fields (apparent_initiative) byte-identical on [0, impact).
	var ai: Array = C.presentation(truth, 7, profiles()).fight.apparent_initiative
	var ai_v: Array = C.presentation(variant, 7, profiles()).fight.apparent_initiative
	var ai_prefix_exact := true
	for s in ai:
		if int(s.tick) >= impact_k:
			continue
		var match_v := {}
		for sv in ai_v:
			if int(sv.tick) == int(s.tick):
				match_v = sv
				break
		if match_v.is_empty() or float(match_v.lead) != float(s.lead):
			ai_prefix_exact = false
	check(ai_prefix_exact, "prefix-blindness: apparent_initiative on [0, impact) is byte-identical")

	# non-vacuous: the resolution DOES change staging at/after its own impact.
	var diverges := false
	for t in range(impact_k, end_tick + 1):
		if C.position_at(staged, "B", t) != C.position_at(staged_v, "B", t):
			diverges = true
	check(diverges, "prefix-blindness is non-vacuous: staging differs at/after the impact tick")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
