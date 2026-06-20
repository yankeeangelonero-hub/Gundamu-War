extends SceneTree
## Unit test for the Combat Choreographer
## (spec: docs/superpowers/specs/2026-06-17-combat-choreographer-design.md).
##
## The choreographer is a PURE function (combat-truth log, presentation seed) ->
## presentation events merged into the log. It stages the positionless truth log into
## spawn positions + advance beats so the director has a 3D scene to film. It never edits
## combat-truth; it only adds. Reproducible, not verified.
##
## Cycle 1 (this section): the structural spine — spawn placement, truth pass-through,
## canonical merge order, ambient ring cadence, the in-ring invariant (in the
## choreographer's OWN position model), periodic boost, and determinism.
## Cycle 2 (added below once Cycle 1 is green): reactive triggers + guards.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

# --- fixture: a v2 combat-truth layer (no positions) -----------------------------
# A duel where A and B trade shots; B is destroyed at the end. Shapes match the
# fight event-log contract (km-fight-log-v2): spawn{hp}, shot{motif,tier,travel,
# outcome,damage?,lethal?,hp_after?}, destroyed{}. `actor` on a shot is the SHOOTER;
# damage/hp_after describe the struck (other) mech.
func truth_log() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 30, "hp_after": 70}},
		{"tick": 18, "seq": 3, "actor": "B", "kind": "shot",      "payload": {"motif": "burst", "tier": 1, "travel": 3, "outcome": "miss"}},
		{"tick": 26, "seq": 4, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 35, "hp_after": 35}},
		# travel 2 is below EVADE_MIN_TRAVEL, so this lethal blow stages NO reactive beat —
		# keeping the Cycle-1 fixture a clean ambient-only case (reactive triggers: Cycle 2).
		{"tick": 40, "seq": 5, "actor": "A", "kind": "shot",      "payload": {"motif": "buster", "tier": 3, "travel": 2, "outcome": "hit", "damage": 40, "lethal": true, "hp_after": 0}},
		{"tick": 40, "seq": 6, "actor": "B", "kind": "destroyed", "payload": {}},
	]

func dist(a: Vector2, b: Vector2) -> float:
	return (a - b).length()

# --- Cycle 2 fixture: B is the perpetual target; each shot exercises one trigger, and the
# reactive windows are kept on distinct ticks (none on a stride boundary) so each behaviour
# reads in isolation. A never gets hit, so A stays pure-ambient (the miss-guard control).
func truth_log2() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		# heavy hit: evade [18,24] over the flight, then stagger [24,28]; drops B to low HP.
		{"tick": 24, "seq": 2, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 3, "travel": 6, "outcome": "hit", "damage": 70, "hp_after": 30}},
		# B fires and MISSES A — must stage no reaction for A (miss guard).
		{"tick": 28, "seq": 3, "actor": "B", "kind": "shot",      "payload": {"motif": "burst", "tier": 3, "travel": 4, "outcome": "miss"}},
		# heavy hit but travel 2 < EVADE_MIN_TRAVEL: evade SKIPPED, stagger [34,38] still fires.
		{"tick": 34, "seq": 4, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 3, "travel": 2, "outcome": "hit", "damage": 10, "hp_after": 20}},
		# lethal blow: evade [42,50] fires, stagger SUPPRESSED (the destroyed beat owns tick 50).
		{"tick": 50, "seq": 5, "actor": "A", "kind": "shot",      "payload": {"motif": "buster", "tier": 3, "travel": 8, "outcome": "hit", "damage": 40, "lethal": true, "hp_after": 0}},
		{"tick": 50, "seq": 6, "actor": "B", "kind": "destroyed", "payload": {}},
		# post-decision shot after B is dead — must stage no reaction (post_decision + destroyed guards).
		{"tick": 56, "seq": 7, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 3, "travel": 5, "outcome": "hit", "post_decision": true}},
	]

# Find an advance beat for `actor` that starts at `tick`, else {}.
func adv_at(staged: Array, actor: String, tick: int) -> Dictionary:
	for e in staged:
		if e.kind == "advance" and e.actor == actor and int(e.tick) == tick:
			return e
	return {}

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	check(C != null, "choreographer.gd loads")
	if C == null:
		print("---- %d FAIL" % maxi(fails, 1))
		quit(1)
		return

	var truth := truth_log()
	var staged: Array = C.stage(truth, 7)
	check(staged is Array, "stage() returns an Array")

	# --- truth pass-through: the choreographer ADDS, never edits. Every truth field of every
	#     input event survives unchanged (spawn legitimately GAINS {x,z}; nothing is altered).
	var pass_through := true
	for src in truth:
		var match_ev := {}
		for out in staged:
			if int(out.tick) == int(src.tick) and out.get("seq", -999) == src.get("seq", -998) \
					and out.actor == src.actor and out.kind == src.kind:
				match_ev = out
				break
		if match_ev.is_empty():
			pass_through = false
			continue
		for key in src.payload:  # every truth field present and equal (additions allowed)
			if not match_ev.payload.has(key) or match_ev.payload[key] != src.payload[key]:
				pass_through = false
	check(pass_through, "all combat-truth events pass through unchanged (added, never edited)")

	# --- spawn placement: fixed mirrored spawn, A at -X, B at +X, on the z=0 line --------
	var spawn_a := {}
	var spawn_b := {}
	for e in staged:
		if e.kind == "spawn" and e.actor == "A":
			spawn_a = e
		elif e.kind == "spawn" and e.actor == "B":
			spawn_b = e
	check(spawn_a.has("payload") and spawn_a.payload.has("x") and spawn_a.payload.has("z"),
		"spawn A carries {x,z} placement")
	check(spawn_a.payload.has("hp"), "spawn A keeps its truth field hp")
	check(float(spawn_a.payload.x) < 0.0 and float(spawn_b.payload.x) > 0.0,
		"spawn mirrored: A at -X, B at +X")
	check(is_equal_approx(float(spawn_a.payload.x), -float(spawn_b.payload.x)),
		"spawn symmetric about origin")
	check(is_zero_approx(float(spawn_a.payload.z)) and is_zero_approx(float(spawn_b.payload.z)),
		"spawns on the z=0 line")

	# --- canonical merge order: truth in (tick,seq); advance slotted AFTER truth of its --
	#     tick; advance A before advance B at equal tick; truth (tick,seq) non-decreasing.
	var order_ok := true
	var last_tick := -1
	var last_seq := -1
	for e in staged:
		if e.has("seq"):  # a combat-truth event
			var t := int(e.tick)
			var s := int(e.seq)
			if t < last_tick or (t == last_tick and s < last_seq):
				order_ok = false
			last_tick = t
			last_seq = s
	check(order_ok, "combat-truth events stay in canonical (tick, seq) order")

	# advance never carries seq (outside the verified projection)
	var advance_seqless := true
	for e in staged:
		if e.kind == "advance" and e.has("seq"):
			advance_seqless = false
	check(advance_seqless, "advance events carry no seq (presentation layer)")

	# at any tick, every advance appears after every truth event of that same tick
	var slot_ok := true
	for i in staged.size():
		if staged[i].kind == "advance":
			var at := int(staged[i].tick)
			for j in range(i + 1, staged.size()):
				if int(staged[j].tick) == at and staged[j].has("seq"):
					slot_ok = false  # a truth event of this tick after an advance of this tick
	check(slot_ok, "advance slotted after all truth events of its tick")

	# --- ambient cadence: advances exist, land on STRIDE boundaries, for both actors -----
	var adv_a := 0
	var adv_b := 0
	var on_stride := true
	for e in staged:
		if e.kind == "advance":
			# ambient beats fall on stride boundaries; reactive beats (Cycle 2) may not —
			# but the Cycle-1 fixture triggers none, so every advance here is ambient.
			if int(e.tick) % C.STRIDE != 0:
				on_stride = false
			if e.actor == "A":
				adv_a += 1
			else:
				adv_b += 1
	check(adv_a > 0 and adv_b > 0, "ambient advances generated for both actors")
	check(on_stride, "ambient advances land on STRIDE boundaries")

	# --- in-ring invariant: every advance target lies within [ENGAGE_MIN, ENGAGE_MAX] of --
	#     the ENEMY's position in the choreographer's own model at that beat's start tick.
	var in_ring := true
	for e in staged:
		if e.kind == "advance":
			var enemy := "B" if e.actor == "A" else "A"
			var enemy_pos: Vector2 = C.position_at(staged, enemy, int(e.tick))
			var target := Vector2(float(e.payload.to_x), float(e.payload.to_z))
			var d := dist(target, enemy_pos)
			if d < C.ENGAGE_MIN - 0.5 or d > C.ENGAGE_MAX + 0.5:
				in_ring = false
	check(in_ring, "every advance target is within the duel ring of the enemy's modeled position")

	# --- periodic boost: at least one boosted beat, and boosts carry a to_y hop ----------
	var boost_count := 0
	var hop_ok := true
	for e in staged:
		if e.kind == "advance" and bool(e.payload.get("boost", false)):
			boost_count += 1
			if float(e.payload.get("to_y", 0.0)) <= 0.0:
				hop_ok = false
	check(boost_count > 0, "periodic boost beats are generated")
	check(hop_ok, "boost beats carry an upward to_y hop")

	# --- determinism: same (log, seed) -> identical staged output ------------------------
	check(C.stage(truth, 7) == C.stage(truth, 7), "stage is pure/deterministic for a fixed seed")
	# and a different seed restages the ambient bearings differently (seeded variety)
	check(C.stage(truth, 7) != C.stage(truth, 99), "a different seed restages differently")

	# --- movement trace: a per-tick, per-mech position log for cinematography analysis ---
	# Pure resample of the choreographer's own model: one row per (tick, actor) while the
	# mech is alive, so two builds/seeds can be diffed for movement/technical-cinema quality.
	var trace: Array = C.movement_trace(staged)
	check(trace is Array and not trace.is_empty(), "movement_trace returns a non-empty Array")

	# rows sorted by (tick, actor); A before B at equal tick
	var trace_sorted := true
	var prev_t := -1
	var prev_actor := ""
	for r in trace:
		var t := int(r.tick)
		if t < prev_t or (t == prev_t and r.actor < prev_actor):
			trace_sorted = false
		prev_t = t
		prev_actor = r.actor
	check(trace_sorted, "movement_trace rows are in (tick, actor) order")

	# every row carries the cinematography fields
	var fields_ok := true
	for r in trace:
		for key in ["tick", "actor", "x", "y", "z", "dist_to_enemy", "speed", "bearing_deg", "boost"]:
			if not r.has(key):
				fields_ok = false
	check(fields_ok, "each trace row has tick/actor/x/y/z/dist_to_enemy/speed/bearing_deg/boost")

	# position in the trace matches the choreographer's model exactly (no drift)
	var pos_matches := true
	var speed_nonneg := true
	for r in trace:
		var model_pos: Vector2 = C.position_at(staged, r.actor, int(r.tick))
		if not (is_equal_approx(float(r.x), model_pos.x) and is_equal_approx(float(r.z), model_pos.y)):
			pos_matches = false
		if float(r.speed) < 0.0:
			speed_nonneg = false
	check(pos_matches, "trace x/z agrees with position_at (the model is the single source of truth)")
	check(speed_nonneg, "trace speed is never negative")

	# a destroyed mech stops being traced after its death tick; the survivor keeps going
	var max_b := -1
	var max_a := -1
	for r in trace:
		if r.actor == "B":
			max_b = maxi(max_b, int(r.tick))
		else:
			max_a = maxi(max_a, int(r.tick))
	check(max_b <= 40, "destroyed mech B is not traced past its death tick (40)")
	check(max_a >= max_b, "the survivor A is traced at least as long as B")

	# boost airtime shows up as a positive y somewhere
	var any_air := false
	for r in trace:
		if float(r.y) > 0.0:
			any_air = true
	check(any_air, "boost beats register as airborne (y > 0) in the trace")

	# the trace is pure too
	check(C.movement_trace(staged) == trace, "movement_trace is pure/deterministic")

	# =====================================================================================
	# Cycle 2 — reactive triggers + guards
	# =====================================================================================
	var truth2 := truth_log2()
	var s2: Array = C.stage(truth2, 7)

	# --- boost-evade on an incoming heavy hit: off-cadence boost beat over the flight ----
	var evade := adv_at(s2, "B", 18)  # fire = impact(24) - travel(6)
	check(not evade.is_empty() and int(evade.payload.end_tick) == 24 and bool(evade.payload.get("boost", false)),
		"heavy inbound stages a boost-evade for the target over [impact-travel, impact]")

	# --- step-back stagger on the heavy hit landing: grounded beat at the impact tick -----
	var stagger := adv_at(s2, "B", 24)
	check(not stagger.is_empty() and int(stagger.payload.end_tick) == 24 + C.STAGGER_DUR \
			and not bool(stagger.payload.get("boost", false)),
		"a heavy non-lethal hit stages a grounded step-back stagger at the impact tick")

	# --- evade skipped when travel < EVADE_MIN_TRAVEL (no room to read a dodge) -----------
	check(adv_at(s2, "B", 32).is_empty(),  # fire would be 34-2 = 32
		"a heavy hit with travel < EVADE_MIN_TRAVEL stages no evade")
	# ...but the stagger for that same hit still lands.
	check(not adv_at(s2, "B", 34).is_empty(),
		"the short-travel heavy hit still stages its stagger at the impact tick")

	# --- lethal blow: evade fires, stagger is suppressed (destroyed owns the tick) --------
	check(not adv_at(s2, "B", 42).is_empty(),  # evade for the lethal shot: fire = 50-8
		"a lethal inbound still stages its boost-evade over the flight")
	check(adv_at(s2, "B", 50).is_empty(),
		"a lethal hit stages no stagger (the destroyed beat owns its tick)")

	# --- range tightens after a low-HP hit: B's ambient strides after tick 24 use a -------
	#     reduced outer ring; strides before it are unconstrained.
	var tighten_ok := true
	for e in s2:
		if e.kind == "advance" and e.actor == "B" and int(e.tick) % C.STRIDE == 0 and int(e.tick) > 24:
			var enemy_pos: Vector2 = C.position_at(s2, "A", int(e.tick))
			var target := Vector2(float(e.payload.to_x), float(e.payload.to_z))
			if dist(target, enemy_pos) > C.LOW_HP_MAX_RADIUS + 0.5:
				tighten_ok = false
	check(tighten_ok, "a low-HP mech's subsequent ambient ring tightens to LOW_HP_MAX_RADIUS")

	# --- guards: a MISS stages no reaction for the target; the un-hit mech stays ambient --
	var a_all_ambient := true
	for e in s2:
		if e.kind == "advance" and e.actor == "A" and int(e.tick) % C.STRIDE != 0:
			a_all_ambient = false  # A is never hit, so it must have only on-cadence ambient beats
	check(a_all_ambient, "a missed shot stages no evade/stagger (A stays pure-ambient)")

	# --- guards: a destroyed mech and a post_decision shot stage nothing past death -------
	var b_dead_quiet := true
	for e in s2:
		if e.kind == "advance" and e.actor == "B" and int(e.tick) >= 50:
			b_dead_quiet = false
	check(b_dead_quiet, "no beats for B at/after its destroyed tick (post_decision + destroyed guards)")

	# --- the in-ring invariant still holds for EVERY beat, reactive ones included ---------
	var in_ring2 := true
	for e in s2:
		if e.kind == "advance":
			var enemy := "B" if e.actor == "A" else "A"
			var enemy_pos: Vector2 = C.position_at(s2, enemy, int(e.tick))
			var target := Vector2(float(e.payload.to_x), float(e.payload.to_z))
			var d := dist(target, enemy_pos)
			if d < C.ENGAGE_MIN - 0.5 or d > C.ENGAGE_MAX + 0.5:
				in_ring2 = false
	check(in_ring2, "every beat (ambient + evade + stagger) lands within the duel ring")

	# --- still pure, and truth still passes through unchanged in the reactive fixture -----
	check(C.stage(truth2, 7) == s2, "reactive staging is pure/deterministic")
	var pass2 := true
	for src in truth2:
		var m := {}
		for out in s2:
			if int(out.tick) == int(src.tick) and out.get("seq", -999) == src.get("seq", -998) \
					and out.actor == src.actor and out.kind == src.kind:
				m = out
				break
		if m.is_empty():
			pass2 = false
			continue
		for key in src.payload:
			if not m.payload.has(key) or m.payload[key] != src.payload[key]:
				pass2 = false
	check(pass2, "combat-truth passes through unchanged with reactive staging")

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
