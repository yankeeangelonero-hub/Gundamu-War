extends SceneTree
## TDD tests for grammar_metrics.gd
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##
## Tests cover:
##   truth_dom()        — correct sign, monotonic-ish, fixture-verified
##   reveal()           — hysteresis entry/exit, sentinel on draw
##   no_prespoil_ok()   — gate cases: pre-reveal FAILS, lag PASSES, draw case
##   classify_shape()   — all six branches incl. stalemate before photofinish
##   beam_trade_contrast_ok() — pragmatic bimodal check
##   integration check  — real fight_log_everything.json parses and classifies

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func approx(a: float, b: float, tol: float = 1e-5) -> bool:
	return abs(a - b) < tol

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

## Minimal staged events for position_at(): two spawns + advance beats.
## Actor A stays at x=-40, B at x=40 (no advance beats, so they never move).
func two_spawn_events() -> Array:
	return [
		{"tick": 0, "actor": "A", "kind": "spawn", "payload": {"x": -40.0, "z": 0.0, "hp": 100}},
		{"tick": 0, "actor": "B", "kind": "spawn", "payload": {"x":  40.0, "z": 0.0, "hp": 100}},
	]

## Build a minimal truth fixture for truth_dom():
##   A hits B twice (damage 30, then 20), B hits A once (damage 10).
##   No post_decision, no lethal. Spawn HP both 100.
## Expected truth_dom at end: frac_lost_B - frac_lost_A = 0.50 - 0.10 = 0.40 (positive = A ahead).
func small_truth_events() -> Array:
	return [
		{"tick": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		# A hits B, damage 30 -> frac_lost_B at tick 5 = 0.30
		{"tick": 5, "actor": "A", "kind": "shot",
			"payload": {"outcome": "hit", "damage": 30.0, "hp_after": 70.0}},
		# B hits A, damage 10 -> frac_lost_A at tick 8 = 0.10
		{"tick": 8, "actor": "B", "kind": "shot",
			"payload": {"outcome": "hit", "damage": 10.0, "hp_after": 90.0}},
		# A hits B again, damage 20 -> frac_lost_B at tick 12 = 0.50
		{"tick": 12, "actor": "A", "kind": "shot",
			"payload": {"outcome": "hit", "damage": 20.0, "hp_after": 50.0}},
	]

## Build a minimal staged-events fixture for staged_dom():
## Two mechs, A at x=-40 z=0, B at x=40 z=0 (static — no advance beats).
## We just need something position_at() can read.
func small_staged_events() -> Array:
	return two_spawn_events()

## Construct a constant-sign series (all positive, above CONF) for reveal() tests.
func all_positive_series(length: int, val: float) -> Array:
	var out := []
	for i in range(length):
		out.append(val)
	return out

## A draw series (all zero).
func zero_series(length: int) -> Array:
	var out := []
	for i in range(length):
		out.append(0.0)
	return out

## A series that starts positive, then flips negative (reversal shape):
## first `pos_count` values = +0.6, remaining = -0.6.
func reversal_series(pos_count: int, total: int, pos_val: float, neg_val: float) -> Array:
	var out := []
	for i in range(total):
		out.append(pos_val if i < pos_count else neg_val)
	return out

## Series that reveals late (last quarter only positive above CONF).
func late_reveal_series(length: int) -> Array:
	var out := []
	for i in range(length):
		out.append(0.1 if i < length * 3 / 4 else 0.7)
	return out

## Series that reveals early (first half positive above CONF, then stays).
func early_reveal_series(length: int) -> Array:
	var out := []
	for i in range(length):
		out.append(0.7)
	return out

## Load the real fight log JSON. Returns parsed Dictionary, or {} on failure.
func load_fight_log() -> Dictionary:
	var f := FileAccess.open("res://data/fight_log_everything.json", FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var result: Variant = JSON.parse_string(text)
	if result == null:
		return {}
	return result

# ---------------------------------------------------------------------------
# _init: run all checks
# ---------------------------------------------------------------------------
func _init() -> void:
	var P := load("res://scripts/sim/grammar_params.gd")
	check(P != null, "grammar_params.gd loads")

	var M := load("res://scripts/sim/movement_trace.gd")
	check(M != null, "movement_trace.gd loads")

	var G := load("res://scripts/sim/grammar_metrics.gd")
	check(G != null, "grammar_metrics.gd loads")

	if G == null or P == null or M == null:
		print("---- %d FAIL (modules missing)" % maxi(fails, 1))
		quit(1)
		return

	# -----------------------------------------------------------------------
	# truth_dom() — basic contract
	# -----------------------------------------------------------------------

	# On a zero-event fixture (no shots), both fracs stay 0 -> dom stays 0.
	var zero_truth := [
		{"tick": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
	]
	var zero_dom: Array = G.truth_dom(zero_truth, {"A": 100.0, "B": 100.0})
	check(not zero_dom.is_empty(), "truth_dom: returns non-empty array even with no shots")
	var all_zero := true
	for v in zero_dom:
		if not approx(float(v), 0.0):
			all_zero = false
	check(all_zero, "truth_dom: zero-damage fight produces all-zero series")

	# Small fixture: verify end-of-series value is correct (A 50% lost B, B 10% lost A).
	var small_truth := small_truth_events()
	var spawn_hp_small := {"A": 100.0, "B": 100.0}
	var dom_small: Array = G.truth_dom(small_truth, spawn_hp_small)
	check(not dom_small.is_empty(), "truth_dom: returns array for small fixture")

	# At tick 5 A has damaged B 30/100 = 0.30; A undamaged -> dom = 0.30 - 0.0 = 0.30 (positive).
	# Series index = tick (0-indexed from 0 to end_tick inclusive).
	var end_tick_small := 12
	check(dom_small.size() == end_tick_small + 1,
		"truth_dom: series length = end_tick + 1 (one entry per tick)")
	# At tick 4 (before any shot lands): dom should be 0.
	check(approx(float(dom_small[4]), 0.0, 1e-4), "truth_dom: tick 4, no damage yet -> dom 0.0")
	# At tick 5: frac_lost_B = 0.30, frac_lost_A = 0.0 -> dom = 0.30
	check(approx(float(dom_small[5]), 0.30, 1e-4),
		"truth_dom: tick 5, A hit B 30->frac_lost_B=0.30, dom=+0.30")
	# At tick 8: frac_lost_B = 0.30, frac_lost_A = 0.10 -> dom = 0.20
	check(approx(float(dom_small[8]), 0.20, 1e-4),
		"truth_dom: tick 8, B hit A 10->frac_lost_A=0.10, dom=+0.20")
	# At tick 12: frac_lost_B = 0.50, frac_lost_A = 0.10 -> dom = 0.40
	check(approx(float(dom_small[12]), 0.40, 1e-4),
		"truth_dom: tick 12, A hit B again->frac_lost_B=0.50, dom=+0.40")

	# dom is always >= prior value for frac_lost_B side only (not globally monotone since
	# B can also land shots). But the endpoint sign is positive (A ahead).
	check(float(dom_small[-1]) > 0.0,
		"truth_dom: final value positive (A ahead in small fixture)")

	# Values clamped to [-1, 1].
	var in_range := true
	for v in dom_small:
		if float(v) < -1.0 - 1e-6 or float(v) > 1.0 + 1e-6:
			in_range = false
	check(in_range, "truth_dom: all values clamped to [-1, 1]")

	# Determinism: same inputs -> same output.
	check(G.truth_dom(small_truth, spawn_hp_small) == G.truth_dom(small_truth, spawn_hp_small),
		"truth_dom: deterministic (same inputs -> identical output)")

	# post_decision shots contribute 0 damage.
	var post_dec_truth := [
		{"tick": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 5, "actor": "A", "kind": "shot",
			"payload": {"outcome": "hit", "damage": 30.0, "hp_after": 70.0, "post_decision": true}},
	]
	var dom_pd: Array = G.truth_dom(post_dec_truth, {"A": 100.0, "B": 100.0})
	check(approx(float(dom_pd[5]), 0.0, 1e-4),
		"truth_dom: post_decision shot contributes 0 damage to dom series")

	# miss shots contribute 0 damage.
	var miss_truth := [
		{"tick": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 5, "actor": "A", "kind": "shot",
			"payload": {"outcome": "miss"}},
	]
	var dom_miss: Array = G.truth_dom(miss_truth, {"A": 100.0, "B": 100.0})
	check(approx(float(dom_miss[5]), 0.0, 1e-4),
		"truth_dom: miss shot contributes 0 damage to dom series")

	# -----------------------------------------------------------------------
	# reveal() — hysteresis enter/exit, sentinel
	# -----------------------------------------------------------------------

	# A clear positive stomp: full series above CONF. Reveal should be tick 0.
	var stomp_series := all_positive_series(50, 0.7)
	var rev_stomp: int = G.reveal(stomp_series)
	check(rev_stomp == 0, "reveal: clear stomp (all >CONF) reveals at tick 0")

	# True draw (all zero): reveal returns sentinel (no stable run reaches end).
	var rev_draw: int = G.reveal(zero_series(50))
	check(rev_draw >= (1 << 20), "reveal: zero-damage series returns sentinel (>= large value)")

	# A series that reveals in the final quarter: last 25 ticks at +0.7, before 0.
	var quarter_reveal := []
	for i in range(100):
		quarter_reveal.append(0.7 if i >= 75 else 0.0)
	var rev_quarter: int = G.reveal(quarter_reveal)
	check(rev_quarter == 75, "reveal: series positive only in final quarter reveals at tick 75")

	# Reversal: first half positive, second half negative. reveal() = entry of LAST stable run.
	# Last stable run is the negative one, so should reveal at the start of the negative run.
	var rev_series := reversal_series(50, 100, 0.7, -0.7)
	var rev_reversal: int = G.reveal(rev_series)
	check(rev_reversal == 50, "reveal: reversal series - last stable run starts at tick 50")

	# Hysteresis: a run that briefly dips below CONF*(1-HYST) should exit and re-enter.
	# The last run is what matters. With CONF=0.5, HYST=0.2, exit threshold = 0.5*0.8 = 0.40.
	# Build: ticks 0..29 at 0.7, ticks 30..34 at 0.35 (below exit), ticks 35..99 at 0.7.
	# The run restarted at tick 35 is the final one -> reveal = 35.
	var hyst_series := []
	for i in range(100):
		if i >= 30 and i <= 34:
			hyst_series.append(0.35)
		else:
			hyst_series.append(0.7)
	var rev_hyst: int = G.reveal(hyst_series)
	check(rev_hyst == 35,
		"reveal: hysteresis - brief dip below exit threshold restarts run at tick 35")

	# -----------------------------------------------------------------------
	# no_prespoil_ok() — gate cases
	# -----------------------------------------------------------------------
	# Spec: reveal(staged) >= min(reveal(truth), int(LATE_FRAC*duration)) - SLACK
	# Using default params: LATE_FRAC=0.7, SLACK=5 (from grammar_params.gd).
	# duration=100: late_gate = 70. min(truth_reveal, 70) - 5.

	# Case 1: truth reveals at tick 40, staged reveals at tick 35.
	# threshold = min(40, 70) - 5 = 35. staged(35) >= 35 -> PASS.
	var truth_40 := []
	var staged_35 := []
	for i in range(100):
		truth_40.append(0.7 if i >= 40 else 0.0)
		staged_35.append(0.7 if i >= 35 else 0.0)
	check(G.no_prespoil_ok(truth_40, staged_35, 100),
		"no_prespoil_ok: staged reveals at truth-SLACK boundary -> PASS")

	# Case 2: truth reveals at tick 40, staged reveals at tick 30 (5 ticks before threshold).
	# threshold = min(40, 70) - 5 = 35. staged(30) < 35 -> FAIL.
	var staged_30 := []
	for i in range(100):
		staged_30.append(0.7 if i >= 30 else 0.0)
	check(not G.no_prespoil_ok(truth_40, staged_30, 100),
		"no_prespoil_ok: staged pre-reveals 5 ticks before threshold -> FAIL")

	# Case 3: draw fight (truth_reveal = sentinel). late_gate = 70.
	# threshold = min(sentinel, 70) - 5 = 65.
	# staged reveals at tick 70 -> 70 >= 65 -> PASS.
	var staged_70 := []
	for i in range(100):
		staged_70.append(0.7 if i >= 70 else 0.0)
	check(G.no_prespoil_ok(zero_series(100), staged_70, 100),
		"no_prespoil_ok: draw fight, staged reveals after late_gate-SLACK -> PASS")

	# Case 4: draw fight, staged reveals at tick 60 (< 65) -> FAIL.
	var staged_60 := []
	for i in range(100):
		staged_60.append(0.7 if i >= 60 else 0.0)
	check(not G.no_prespoil_ok(zero_series(100), staged_60, 100),
		"no_prespoil_ok: draw fight, staged reveals before late_gate-SLACK -> FAIL")

	# -----------------------------------------------------------------------
	# classify_shape() — all six branches
	# -----------------------------------------------------------------------
	# Shape decision tree (ordered):
	#   1. has_kill & decided_frac <= INSTANT_FRAC -> instant
	#   2. lead_flips >= 1 -> reversal
	#   3. !has_kill & margin < CONF -> stalemate
	#   4. margin >= STOMP_MARGIN & decided_frac <= STOMP_FRAC -> stomp
	#   5. has_kill & decided_frac >= LATE_FRAC & margin <= CLOSE_MARGIN -> photofinish
	#   6. else -> grind
	# Using params: INSTANT_FRAC=0.2, STOMP_MARGIN=0.6, STOMP_FRAC=0.5,
	#               LATE_FRAC=0.7, CLOSE_MARGIN=0.2, CONF=0.5.

	# Branch 1 - instant: kill + decided very early (tick 10/100, frac=0.10 <= 0.20).
	var instant_dom := []
	for i in range(100):
		instant_dom.append(0.7)  # decided at tick 0 (whole series above CONF)
	var shape_instant: String = G.classify_shape(instant_dom, true, 100)
	check(shape_instant == "instant", "classify_shape: instant kill decided early -> 'instant'")

	# Branch 2 - reversal: lead_flips >= 1 (positive then negative).
	var reversal_dom := reversal_series(40, 100, 0.7, -0.7)
	var shape_reversal: String = G.classify_shape(reversal_dom, true, 100)
	check(shape_reversal == "reversal", "classify_shape: stable sign flip -> 'reversal'")

	# Branch 3 - stalemate: no kill, margin < CONF at end.
	# Use all-zero series (margin=0 < CONF=0.5, no kill).
	var stalemate_dom := zero_series(100)
	var shape_stalemate: String = G.classify_shape(stalemate_dom, false, 100)
	check(shape_stalemate == "stalemate",
		"classify_shape: no kill + margin < CONF -> 'stalemate' (not photofinish)")

	# Stalemate takes priority over photofinish: same series with has_kill=false must NOT
	# fall into photofinish (the zero-damage draw case the spec guards).
	check(shape_stalemate != "photofinish",
		"classify_shape: stalemate before photofinish in decision tree (zero-damage draw guard)")

	# Branch 4 - stomp: large margin at tick 30 (frac=0.30 <= STOMP_FRAC=0.50),
	# decided at tick 30, no reversals.
	var stomp_dom := []
	for i in range(100):
		stomp_dom.append(0.7)  # decided early (tick 0), margin = 0.7 >= STOMP_MARGIN=0.6
	# But instant takes priority if decided_frac<=0.2. Need decided_frac in (0.2, 0.5].
	# Make series 0.0 until tick 25, then 0.7 -> decided at tick 25 (frac 0.25, in (0.2, 0.5]).
	stomp_dom = []
	for i in range(100):
		stomp_dom.append(0.7 if i >= 25 else 0.0)
	var shape_stomp: String = G.classify_shape(stomp_dom, true, 100)
	check(shape_stomp == "stomp", "classify_shape: large margin decided at frac 0.25 -> 'stomp'")

	# Branch 5 - photofinish: kill + decided late (>= LATE_FRAC=0.7) + small margin (<= CLOSE_MARGIN=0.2).
	var pf_dom := []
	for i in range(100):
		pf_dom.append(0.15 if i >= 75 else 0.0)
	# reveal at tick 75 (below CONF=0.5... need margin >= CONF to have a stable run).
	# Actually photofinish requires has_kill, decided_frac >= LATE_FRAC, margin <= CLOSE_MARGIN.
	# margin = |dom[-1]| <= CLOSE_MARGIN(0.2). decided_tick = reveal or last tick.
	# With small values (<CONF), reveal returns sentinel so decided_tick = last tick = 99, frac=0.99.
	# margin = 0.15 <= 0.20 -> photofinish.
	var shape_pf: String = G.classify_shape(pf_dom, true, 100)
	check(shape_pf == "photofinish",
		"classify_shape: kill + decided late (sentinel->last tick) + small margin -> 'photofinish'")

	# Branch 6 - grind: doesn't match any above.
	# Kill, no reversal, medium margin (not stomp-margin), not late enough for photofinish.
	# Decided at tick 60 (frac=0.60 > STOMP_FRAC=0.50, so not stomp), margin=0.40 > CLOSE_MARGIN.
	var grind_dom := []
	for i in range(100):
		grind_dom.append(0.6 if i >= 60 else 0.0)
	var shape_grind: String = G.classify_shape(grind_dom, true, 100)
	check(shape_grind == "grind",
		"classify_shape: kill + medium margin + mid-decided -> 'grind'")

	# Determinism.
	check(G.classify_shape(stomp_dom, true, 100) == G.classify_shape(stomp_dom, true, 100),
		"classify_shape: deterministic")

	# -----------------------------------------------------------------------
	# beam_trade_contrast_ok() — pragmatic bimodal check on staged events
	# -----------------------------------------------------------------------
	# Pass a minimal staged log with just spawns. Static mechs have near-zero speed -> all pauses.
	# That passes the PAUSE_MIN count check (lots of pauses). Check it at least runs without error.
	var staged_static := two_spawn_events()
	# beam_trade_contrast_ok should return bool without crashing.
	var bt_result = G.beam_trade_contrast_ok(staged_static, "A")
	check(bt_result is bool, "beam_trade_contrast_ok: returns a bool on static staged events")

	# -----------------------------------------------------------------------
	# Integration: real fight_log_everything.json
	# -----------------------------------------------------------------------
	var log_data := load_fight_log()
	check(not log_data.is_empty(), "integration: fight_log_everything.json loads and parses")

	if not log_data.is_empty():
		var events: Array = log_data.get("events", [])
		check(not events.is_empty(), "integration: events array is non-empty")

		# Extract spawn HP from the log (both actors = 100).
		var spawn_hp := {}
		for e in events:
			if e.get("kind", "") == "spawn":
				spawn_hp[e.actor] = float(e.payload.get("hp", 0.0))

		# Compute truth_dom on the real log.
		var real_dom: Array = G.truth_dom(events, spawn_hp)
		check(not real_dom.is_empty(), "integration: truth_dom runs on real log without error")
		check(real_dom.size() >= 231, "integration: dom series covers at least 231 ticks")

		# Determine end_tick: max tick of any event.
		var end_tick := 0
		for e in events:
			end_tick = maxi(end_tick, int(e.get("tick", 0)))
		var duration := end_tick + 1

		# Classify shape.
		# Check whether there is a lethal shot in the log.
		var has_kill := false
		for e in events:
			var p: Dictionary = e.get("payload", {})
			if p.get("lethal", false):
				has_kill = true
		var shape: String = G.classify_shape(real_dom, has_kill, duration)
		check(shape != "", "integration: classify_shape returns non-empty string on real log")
		var valid_shapes := ["instant", "reversal", "stalemate", "stomp", "photofinish", "grind"]
		check(shape in valid_shapes, "integration: classified shape is a valid shape name")

		# Print for human inspection.
		var rev_tick: int = G.reveal(real_dom)
		print("  [integration] real fight shape='%s' decided_tick=%d duration=%d" % [shape, rev_tick if rev_tick < (1<<20) else end_tick, end_tick])

		# Determinism: run twice, get identical results.
		check(G.truth_dom(events, spawn_hp) == G.truth_dom(events, spawn_hp),
			"integration: truth_dom is deterministic on real log")
		check(G.classify_shape(real_dom, has_kill, duration) == G.classify_shape(real_dom, has_kill, duration),
			"integration: classify_shape is deterministic on real log")

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
