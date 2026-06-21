extends RefCounted
## Combat Choreography Grammar — pure measurement functions.
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "Testing — defined metrics" and "Shape classification" sections.
##
## All functions are PURE and STATIC. Same input -> same output. No rng. No state.
## Positions are read via movement_trace.gd (position_at). Constants from grammar_params.gd.
##
## v1 fight log compatibility note:
##   The reference log uses kinds fire_beam/fire_burst/fire_missiles/fire_buster with
##   payload fields {hit:bool}/{hits:int}. The truth-log contract for NEW logs uses kind=shot
##   with outcome:"hit"/"miss". truth_dom() handles BOTH shapes.

const _P := preload("res://scripts/sim/grammar_params.gd")
const _MT := preload("res://scripts/sim/movement_trace.gd")

# ---------------------------------------------------------------------------
# truth_dom(truth_events, spawn_hp) -> Array[float]
# Spec: "truth_dom(t) ∈ [-1,1] = frac_lost_B(t) − frac_lost_A(t)"
#       frac_lost_X(t) = clamp(Σ damage to X through tick t / spawn_hp_X, 0, 1)
#       Damage = connecting shots only; post_decision -> 0.
# ---------------------------------------------------------------------------

## Returns per-tick dominance series, one entry per tick from 0 to end_tick inclusive.
## Positive = A ahead (B is losing more HP fraction); negative = B ahead.
## For v1 log events (fire_beam etc.) and v2 log events (shot) both handled.
static func truth_dom(events: Array, spawn_hp: Dictionary) -> Array:
	return _truth_dom_impl(events, spawn_hp)

static func _truth_dom_impl(events: Array, spawn_hp: Dictionary) -> Array:
	var end_tick := 0
	for e in events:
		end_tick = maxi(end_tick, int(e.get("tick", 0)))

	var hp_a := float(spawn_hp.get("A", 0.0))
	var hp_b := float(spawn_hp.get("B", 0.0))

	# Accumulate damage delivered TO each actor, per tick.
	# Key: tick (int) -> {"A": float, "B": float}
	var dmg_to: Dictionary = {}
	for e in events:
		if not _is_connecting_shot(e):
			continue
		var shooter: String = e.get("actor", "")
		if shooter == "":
			continue
		var struck := "B" if shooter == "A" else "A"
		var tick := int(e.get("tick", 0))
		var dmg := _shot_damage(e)
		if not dmg_to.has(tick):
			dmg_to[tick] = {"A": 0.0, "B": 0.0}
		dmg_to[tick][struck] += dmg

	# Build cumulative damage series -> frac_lost -> dom.
	var cum_a := 0.0
	var cum_b := 0.0
	var series := []
	series.resize(end_tick + 1)
	for tick in range(end_tick + 1):
		if dmg_to.has(tick):
			cum_a += float(dmg_to[tick].get("A", 0.0))
			cum_b += float(dmg_to[tick].get("B", 0.0))
		var frac_lost_a := clampf(cum_a / hp_a, 0.0, 1.0) if hp_a > 0.0 else 0.0
		var frac_lost_b := clampf(cum_b / hp_b, 0.0, 1.0) if hp_b > 0.0 else 0.0
		series[tick] = frac_lost_b - frac_lost_a  # positive = A ahead
	return series


## Returns true when event `e` is a connecting shot (contributes damage to truth_dom).
## Handles both v2 contract (kind=shot, outcome=hit) and v1 log (fire_beam/burst/missiles/buster).
static func _is_connecting_shot(e: Dictionary) -> bool:
	var kind: String = e.get("kind", "")
	var p: Dictionary = e.get("payload", {})

	# v2 truth-log contract: kind="shot"
	if kind == "shot":
		if bool(p.get("post_decision", false)):
			return false
		return p.get("outcome", "") == "hit"

	# v1 reference log: fire_beam, fire_buster (hit:bool), fire_burst, fire_missiles (hits:int)
	if kind in ["fire_beam", "fire_buster"]:
		return bool(p.get("hit", false)) and float(p.get("damage", 0.0)) > 0.0
	if kind in ["fire_burst", "fire_missiles"]:
		return int(p.get("hits", 0)) > 0 and float(p.get("damage", 0.0)) > 0.0

	return false


## Extract damage amount from a connecting shot event.
static func _shot_damage(e: Dictionary) -> float:
	return float(e.get("payload", {}).get("damage", 0.0))


# ---------------------------------------------------------------------------
# staged_dom(staged_events) -> Array[float]
# Spec: "staged_dom(t) = clamp(pressure_A - pressure_B + KAPPA*(sells_B - sells_A))"
#   pressure_X(t) = EMA_alpha(clamp(closing_rate_X(t)/REF_SPEED, -1, 1))
#   closing_rate_X(t) = dot(X_pos(t-1)-X_pos(t), unit(enemy_pos(t-1)-X_pos(t-1)))
#   sells_X(t) = EMA_alpha(detector): 1 if in impact window and X displaces away from shooter
#   alpha = 2/(W+1); seeds = 0 at spawn.
# Reads positions from staged trace ONLY (via position_at).
# ---------------------------------------------------------------------------

static func staged_dom(staged_events: Array) -> Array:
	return _staged_dom_impl(staged_events)

static func _staged_dom_impl(staged_events: Array) -> Array:
	var alpha := 2.0 / (float(_P.W) + 1.0)
	var end_tick := 0
	for e in staged_events:
		end_tick = maxi(end_tick, int(e.get("tick", 0)))

	# Build impact windows: for each connecting shot, window = [impact_tick, impact_tick + REACT)
	# and record shooter position at impact.
	# sell detector for actor X: 1 on tick t if X is in a window as the struck actor AND
	# X displaces away from shooter_pos at impact_tick.
	# struct: {struck: "A"|"B", impact_tick: int, shooter_impact_pos: Vector2, end_tick: int}
	var windows := []
	for e in staged_events:
		if not _is_connecting_shot(e):
			continue
		var shooter: String = e.get("actor", "")
		if shooter == "":
			continue
		var struck := "B" if shooter == "A" else "A"
		var impact := int(e.get("tick", 0))
		var shooter_pos := _MT.position_at(staged_events, shooter, impact)
		windows.append({
			"struck": struck,
			"impact_tick": impact,
			"shooter_pos": shooter_pos,
			"end_tick": impact + _P.REACT,
		})

	# EMA state
	var pressure := {"A": 0.0, "B": 0.0}
	var sells := {"A": 0.0, "B": 0.0}

	var series := []
	series.resize(end_tick + 1)

	for tick in range(end_tick + 1):
		# closing_rate_X(t) = dot(X_pos(t-1)-X_pos(t), unit(enemy_pos(t-1)-X_pos(t-1)))
		for actor in ["A", "B"]:
			var enemy := "B" if actor == "A" else "A"
			var pos_now := _MT.position_at(staged_events, actor, tick)
			var pos_prev := _MT.position_at(staged_events, actor, tick - 1) if tick > 0 else pos_now
			var enemy_prev := _MT.position_at(staged_events, enemy, tick - 1) if tick > 0 else _MT.position_at(staged_events, enemy, 0)

			var displacement := pos_prev - pos_now  # X moved from prev to now; delta = prev-now if moving toward enemy
			var to_enemy := enemy_prev - pos_prev
			var to_enemy_len := to_enemy.length()
			var unit_to_enemy := to_enemy / to_enemy_len if to_enemy_len > 1e-6 else Vector2.ZERO

			var closing_rate := displacement.dot(unit_to_enemy)
			var clamped_cr := clampf(closing_rate / _P.REF_SPEED, -1.0, 1.0)

			# EMA update for pressure
			pressure[actor] = pressure[actor] + alpha * (clamped_cr - pressure[actor])

			# sell detector for this actor (is it being sold = knocked away from shooter?)
			var sell_val := 0.0
			for w in windows:
				if w.struck != actor:
					continue
				# Half-open window [impact_tick, end_tick)
				if tick < w.impact_tick or tick >= w.end_tick:
					continue
				# Check: actor displaces away from shooter.
				# dot(X_pos(t)-X_pos(t-1), unit(X_pos(t-1) - shooter_pos)) >= SELL_MIN
				var actor_delta := pos_now - pos_prev  # movement this tick
				var away_dir := pos_prev - (w.shooter_pos as Vector2)
				var away_len := away_dir.length()
				var unit_away := away_dir / away_len if away_len > 1e-6 else Vector2.ZERO
				if actor_delta.dot(unit_away) >= _P.SELL_MIN:
					sell_val = 1.0
					break  # one window is enough

			sells[actor] = sells[actor] + alpha * (sell_val - sells[actor])

		var dom := clampf(pressure["A"] - pressure["B"] + _P.KAPPA * (sells["B"] - sells["A"]), -1.0, 1.0)
		series[tick] = dom

	return series


# ---------------------------------------------------------------------------
# reveal(series) -> int
# Spec: entry tick of the final contiguous constant-sign run reaching the last tick.
# Hysteresis: enter at |v| >= CONF; exit at |v| < CONF*(1-HYST).
# Returns large sentinel (1<<30) if no stable run reaches end.
# ---------------------------------------------------------------------------

static func reveal(series: Array) -> int:
	if series.is_empty():
		return 1 << 30

	var conf: float = _P.CONF
	var exit_thresh: float = conf * (1.0 - _P.HYST)
	var sentinel := 1 << 30

	# Walk forward tracking hysteresis state.
	# We want the START tick of the LAST run that reaches series[-1].
	# Strategy: scan forward, record every run entry; the last one that reaches the end is our answer.

	var in_run := false
	var run_sign := 0  # +1 or -1
	var run_start := -1
	var last_valid_start := sentinel  # entry of last run reaching end_tick

	var last_idx := series.size() - 1

	for i in range(series.size()):
		var v: float = float(series[i])
		var abs_v := absf(v)
		var sign_v := 1 if v >= 0.0 else -1

		if not in_run:
			# Try to enter a run.
			if abs_v >= conf:
				in_run = true
				run_sign = sign_v
				run_start = i
		else:
			# Check exit condition.
			if abs_v < exit_thresh:
				# Exited the run — but only if sign hasn't changed while staying above conf.
				in_run = false
				run_sign = 0
				run_start = -1
			elif sign_v != run_sign and abs_v >= conf:
				# Sign flipped while still above conf — this starts a new run immediately.
				run_sign = sign_v
				run_start = i

	# After walking: if we're still in a run at the end, record it.
	if in_run and run_start >= 0:
		last_valid_start = run_start

	return last_valid_start


# ---------------------------------------------------------------------------
# no_prespoil_ok(truth_dom_series, staged_dom_series, duration) -> bool
# Spec: reveal(staged) >= min(reveal(truth), int(LATE_FRAC*duration)) - SLACK
# ---------------------------------------------------------------------------

static func no_prespoil_ok(truth_dom_series: Array, staged_dom_series: Array, duration: int) -> bool:
	var rev_truth := reveal(truth_dom_series)
	var rev_staged := reveal(staged_dom_series)
	var late_gate := int(_P.LATE_FRAC * float(duration))
	var threshold := mini(rev_truth, late_gate) - _P.SLACK
	return rev_staged >= threshold


# ---------------------------------------------------------------------------
# classify_shape(truth_dom_series, has_kill, duration) -> String
# Spec: ordered decision tree (spec section "Shape classification").
# decided_tick = reveal(truth_dom) if finite, else last tick (duration-1).
# ---------------------------------------------------------------------------

static func classify_shape(truth_dom_series: Array, has_kill: bool, duration: int) -> String:
	if truth_dom_series.is_empty():
		return "stalemate"

	var sentinel := 1 << 20  # anything >= this is "infinite" / no stable reveal
	var rev := reveal(truth_dom_series)
	var decided_tick := rev if rev < sentinel else (duration - 1)
	var decided_frac := float(decided_tick) / float(maxi(duration - 1, 1))
	var margin := absf(float(truth_dom_series[-1]))
	var lead_flips := _count_lead_flips(truth_dom_series)

	# Decision tree — order is fixed per spec.
	if has_kill and decided_frac <= _P.INSTANT_FRAC:
		return "instant"
	if lead_flips >= 1:
		return "reversal"
	if not has_kill and margin < _P.CONF:
		return "stalemate"
	if margin >= _P.STOMP_MARGIN and decided_frac <= _P.STOMP_FRAC:
		return "stomp"
	if has_kill and decided_frac >= _P.LATE_FRAC and margin <= _P.CLOSE_MARGIN:
		return "photofinish"
	return "grind"


## Count hysteresis-stable sign flips in a dominance series.
## A flip is: exiting one stable run and entering a stable run of the opposite sign.
## Uses the same hysteresis constants as reveal().
static func _count_lead_flips(series: Array) -> int:
	if series.is_empty():
		return 0

	var conf: float = _P.CONF
	var exit_thresh: float = conf * (1.0 - _P.HYST)
	var flips := 0
	var in_run := false
	var run_sign := 0

	for i in range(series.size()):
		var v: float = float(series[i])
		var abs_v := absf(v)
		var sign_v := 1 if v >= 0.0 else -1

		if not in_run:
			if abs_v >= conf:
				if run_sign != 0 and sign_v != run_sign:
					flips += 1
				in_run = true
				run_sign = sign_v
		else:
			if abs_v < exit_thresh:
				in_run = false
			elif sign_v != run_sign and abs_v >= conf:
				# Flip while still in a run — counts as a flip, new run starts.
				flips += 1
				run_sign = sign_v

	return flips


# ---------------------------------------------------------------------------
# beam_trade_contrast_ok(staged_events, actor) -> bool
# Spec (CG-CONTRAST, beam-trade instance):
#   Passes if EITHER:
#   (a) speed histogram is bimodal: fraction of ticks with speed < REF_SPEED*0.3 >= PAUSE_MIN
#       (simple pause-fraction proxy for bimodality — TUNING: document method)
#   OR
#   (b) aim/recoil alternation present (bearing snaps toward enemy + away, alternating per shot)
# Method for (a): "bimodal" = pause_fraction >= BIMODAL_MIN where pause = speed < pause_threshold.
#   pause_threshold = REF_SPEED * 0.3  (tunable via grammar_params; this is the "still" bin).
#   This is a pragmatic first version — histogram-peak separation would be more rigorous
#   but requires more data. Documented here as a TUNING note.
# Method for (b): count bearing direction alternations (toward/away from enemy per step);
#   >=2 alternations in actor's trace = aim/recoil present.
# ---------------------------------------------------------------------------

static func beam_trade_contrast_ok(staged_events: Array, actor: String) -> bool:
	var trace := _MT.movement_trace(staged_events)
	var actor_rows := []
	for r in trace:
		if r.actor == actor:
			actor_rows.append(r)

	if actor_rows.is_empty():
		return true  # no data, vacuously ok

	# (a) Pause fraction check.
	var pause_thresh := _P.REF_SPEED * 0.3
	var pause_count := 0
	for r in actor_rows:
		if float(r.speed) < pause_thresh:
			pause_count += 1
	var pause_frac := float(pause_count) / float(actor_rows.size())
	if pause_frac >= _P.BIMODAL_MIN:
		return true

	# (b) Aim/recoil alternation: consecutive bearing reversals >= 2.
	# A reversal = actor changes direction relative to enemy across consecutive ticks.
	if actor_rows.size() < 3:
		return false
	var enemy := "B" if actor == "A" else "A"
	var alternations := 0
	var last_dir := 0  # +1 = closing, -1 = opening
	for i in range(1, actor_rows.size()):
		var prev_r: Dictionary = actor_rows[i - 1]
		var curr_r: Dictionary = actor_rows[i]
		# Use dist_to_enemy change as closing/opening indicator.
		var d_prev := float(prev_r.dist_to_enemy)
		var d_curr := float(curr_r.dist_to_enemy)
		var dir := 1 if d_curr < d_prev else (-1 if d_curr > d_prev else 0)
		if dir != 0 and last_dir != 0 and dir != last_dir:
			alternations += 1
		if dir != 0:
			last_dir = dir
	return alternations >= 2


# ---------------------------------------------------------------------------
# Per-mode CG-CONTRAST registry (the other three modes). The closed set is:
# beam-trade (above), swarm, dodge-pursuit, melee.
# ---------------------------------------------------------------------------

## Count velocity-direction reversals (>90° between consecutive moving steps) for an actor —
## the signature of a zig-zag weave.
static func _velocity_reversals(staged_events: Array, actor: String) -> int:
	var trace := _MT.movement_trace(staged_events)
	var prev := Vector2.ZERO
	var reversals := 0
	for r in trace:
		if r.actor != actor:
			continue
		var spd := float(r.speed)
		if spd < 1e-3:
			continue
		var ang := deg_to_rad(float(r.bearing_deg))
		var v := Vector2(cos(ang), sin(ang)) * spd
		if prev != Vector2.ZERO and prev.dot(v) < 0.0:
			reversals += 1
		prev = v
	return reversals


## swarm: salvo present + target weave — the struck actor's path reverses laterally (>= 2).
static func swarm_contrast_ok(staged_events: Array, actor: String) -> bool:
	return _velocity_reversals(staged_events, actor) >= 2


## dodge-pursuit: a sustained weave over the pursuit window — the dodging actor reverses (>= 2).
static func dodge_pursuit_contrast_ok(staged_events: Array, actor: String) -> bool:
	return _velocity_reversals(staged_events, actor) >= 2


## melee: clash contrast — a close-range speed spike then a near-still contact dwell at range.
static func melee_contrast_ok(staged_events: Array, actor: String) -> bool:
	var trace := _MT.movement_trace(staged_events)
	var spike := false
	var contact_dwell := false
	for r in trace:
		if r.actor != actor:
			continue
		if float(r.speed) >= _P.REF_SPEED * 1.2:
			spike = true
		if float(r.speed) < _P.REF_SPEED * 0.3 and float(r.dist_to_enemy) < _P.RANGE_NEAR:
			contact_dwell = true
	return spike and contact_dwell
