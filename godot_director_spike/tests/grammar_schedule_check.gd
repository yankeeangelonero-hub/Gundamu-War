extends SceneTree
## Unit test — Layer 3 beat scheduler (total & deterministic).
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "The beat scheduler (total & deterministic)".
##
## schedule(truth, feel_profiles, mode_map) -> Array[beat]. A total function of the truth
## shots, ordered by (tick, seq). Each beat carries the fire-knowable timing/priority/mode
## structure; range_band + advance positions are added later by the exchange (2c).
## CG-BLIND part 2: ranking is by `tier` only (fire-knowable) — never lethal/damage.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func mode_map() -> Dictionary:
	return {"ranged": "beam-trade", "barrage": "swarm", "melee": "melee"}

# Two beam-trade-leaning pilots (so every selected mode is beam-trade; gated to beam-trade too).
func profiles() -> Dictionary:
	return {
		"A": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
	}

# A single normal-tier shot from A. spawn tick 0; impact 12; travel 5.
func one_shot() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 30, "hp_after": 70}},
	]

# A synthetic beat dict matching schedule()'s output shape, for testing commit_beats() in
# isolation. `t` is the truth_ref tick (used as the beat's identity in these tests).
func mk_beat(shooter: String, _target: String, t: int, cue: int, impact: int, priority: String) -> Dictionary:
	return {
		"truth_ref": {"tick": t, "seq": 0},
		"shooter": shooter,
		"selected_mode": "beam-trade",
		"exchange_mode": "beam-trade",
		"cue_tick": cue,
		"fire_tick": impact,
		"impact_tick": impact,
		"tier": 3 if priority == "heavy" else 2,
		"priority": priority,
		"lethal": false,
		"is_background": false,
		"reaction_background": false,
	}

# Find the committed beat whose truth_ref tick == t.
func _find(beats: Array, t: int) -> Dictionary:
	for b in beats:
		if int(b.truth_ref.tick) == t:
			return b
	return {}

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	check(C != null, "choreographer.gd loads")
	if C == null:
		print("---- %d FAIL" % maxi(fails, 1))
		quit(1)
		return

	# --- a single shot coalesces to exactly one beat with the right timing + priority.
	var beats: Array = C.schedule(one_shot(), profiles(), mode_map())
	check(beats.size() == 1, "one shot -> one beat")
	if beats.size() == 1:
		var b: Dictionary = beats[0]
		check(b.truth_ref == {"tick": 12, "seq": 2}, "beat binds to the shot's (tick, seq)")
		check(b.shooter == "A", "beat shooter is A")
		check(int(b.impact_tick) == 12, "impact_tick = shot tick (12)")
		check(int(b.fire_tick) == 7, "fire_tick = impact_tick - travel (12-5=7)")
		check(int(b.cue_tick) == 3, "cue_tick = max(fire_tick - TELEGRAPH, spawn) = max(7-4,0)=3")
		check(int(b.tier) == 2, "beat tier = 2")
		check(b.priority == "normal", "tier 2 < HEAVY_TIER -> normal priority")
		check(b.exchange_mode == "beam-trade", "exchange_mode gated to beam-trade")

	# --- coalesce: two A shots within COALESCE_WINDOW (6) ticks fuse into one beat.
	var near := [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 80}},
		{"tick": 16, "seq": 3, "actor": "A", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 60}},
	]
	var nb: Array = C.schedule(near, profiles(), mode_map())
	check(nb.size() == 1, "two A shots within COALESCE_WINDOW -> one beat")
	if nb.size() == 1:
		check(int(nb[0].impact_tick) == 16, "coalesced impact_tick = latest impact (16)")
		check(int(nb[0].fire_tick) == 11, "coalesced fire_tick = 16 - rep.travel(5) = 11")

	# --- coalesce boundary: a gap > COALESCE_WINDOW splits into two beats.
	var far := near.duplicate(true)
	far[3].tick = 20  # gap 20-12 = 8 > 6
	var fb: Array = C.schedule(far, profiles(), mode_map())
	check(fb.size() == 2, "two A shots > COALESCE_WINDOW apart -> two beats")

	# --- different shooters never coalesce.
	var two_actors := [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 80}},
		{"tick": 13, "seq": 3, "actor": "B", "kind": "shot",  "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 20, "hp_after": 80}},
	]
	check(C.schedule(two_actors, profiles(), mode_map()).size() == 2, "A and B shots are separate beats")

	# --- CG-BLIND ranking: a LOW-tier lethal shot stays `normal` (lethal must not elevate the
	#     cue; only `tier` is fire-knowable). A high-tier non-lethal shot is `heavy`.
	var blind := [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 20, "seq": 2, "actor": "A", "kind": "shot",  "payload": {"motif": "pistol", "tier": 1, "travel": 5, "outcome": "hit", "damage": 40, "lethal": true, "hp_after": 0}},
		{"tick": 30, "seq": 3, "actor": "B", "kind": "shot",  "payload": {"motif": "buster", "tier": 3, "travel": 5, "outcome": "hit", "damage": 50, "hp_after": 50}},
	]
	var blb: Array = C.schedule(blind, profiles(), mode_map())
	var by_shooter := {}
	for b2 in blb:
		by_shooter[b2.shooter] = b2
	check(by_shooter.has("A") and by_shooter["A"].priority == "normal",
		"a low-tier LETHAL shot ranks normal (lethal does not elevate the cue)")
	check(by_shooter.has("B") and by_shooter["B"].priority == "heavy",
		"a high-tier non-lethal shot ranks heavy (tier is fire-knowable)")

	# --- determinism.
	check(C.schedule(near, profiles(), mode_map()) == C.schedule(near, profiles(), mode_map()),
		"schedule is pure/deterministic")

	# =====================================================================================
	# Step 3 — commit with preemption (commit_beats). REACT = 6.
	# =====================================================================================

	# Scenario 1 — two same-shooter beats whose shooter spans overlap on A's timeline; the
	# earlier-tick beat holds foreground, the later goes background. Reactions are disjoint, so
	# the later beat's reaction stays foreground (the two demotions are independent).
	var s1 := [
		mk_beat("A", "B", 10, 5, 15, "normal"),   # shooter span A[5,15), react B[15,21)
		mk_beat("A", "B", 20, 11, 25, "normal"),  # shooter span A[11,25) overlaps; react B[25,31) disjoint
	]
	var c1: Array = C.commit_beats(s1)
	var x := _find(c1, 10)
	var y := _find(c1, 20)
	check(x.is_background == false, "earlier overlapping beat keeps foreground shooter span")
	check(y.is_background == true, "later overlapping beat is demoted to background shooter span")
	check(y.reaction_background == false, "the demoted beat's disjoint reaction stays foreground (independent)")

	# Scenario 2 — a HEAVY beat at a LATER tick still wins over an earlier overlapping NORMAL
	# beat on the same actor: heavies commit first (priority desc), so the normal is demoted.
	var s2 := [
		mk_beat("A", "B", 20, 18, 35, "normal"),  # earlier tick, A[18,35)
		mk_beat("A", "B", 30, 28, 40, "heavy"),   # later tick, A[28,40) overlaps
	]
	var c2: Array = C.commit_beats(s2)
	check(_find(c2, 30).is_background == false, "the heavy beat holds foreground (committed first)")
	check(_find(c2, 20).is_background == true, "the earlier normal is demoted by the later heavy (never the reverse)")

	# Scenario 3 — a reaction claim occupies the target's timeline, demoting another beat whose
	# shooter span overlaps it: P hits B (B sells [12,18)); Q (B firing) overlaps -> Q background.
	var s3 := [
		mk_beat("A", "B", 10, 8, 12, "normal"),   # P: shooter A[8,12), react B[12,18)
		mk_beat("B", "A", 14, 13, 25, "normal"),  # Q: shooter B[13,25) overlaps P's react on B
	]
	var c3: Array = C.commit_beats(s3)
	check(_find(c3, 10).is_background == false, "P (earlier) keeps foreground")
	check(_find(c3, 14).is_background == true, "Q's shooter span is demoted by P's reaction claim on B (target busy)")

	# --- schedule() applies commit (single beat -> foreground both spans).
	check(beats[0].is_background == false and beats[0].reaction_background == false,
		"a lone scheduled beat is foreground on both spans")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
