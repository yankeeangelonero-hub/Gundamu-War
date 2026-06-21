extends RefCounted
## Advisory diagnostics — REPORTED, never gating (spec: "Advisory diagnostics").
## Craft measures on a staged trace for tuning, plus the reference-diff that compares a
## recreated fight's metrics to a reference fight (the test that originally exposed the rev-0
## "flat mid-speed churn" failure). Pure static functions; no state.

const _MT := preload("res://scripts/sim/movement_trace.gd")
const _P := preload("res://scripts/sim/grammar_params.gd")

## Per-actor craft stats over the staged trace: distance held, speed shape, and the
## pause / burst / coast prosody split (burst-and-coast reads as weight when coast_frac stays
## above COAST_MIN; a flat churn has near-zero pause and coast).
static func trace_stats(staged_events: Array, actor: String) -> Dictionary:
	var trace := _MT.movement_trace(staged_events)
	var dists := []
	var speeds := []
	for r in trace:
		if r.actor != actor:
			continue
		dists.append(float(r.dist_to_enemy))
		speeds.append(float(r.speed))
	if speeds.is_empty():
		return {"mean_dist": 0.0, "mean_speed": 0.0, "speed_var": 0.0,
			"pause_frac": 0.0, "burst_frac": 0.0, "coast_frac": 0.0, "weave_reversals": 0}

	var pause_thresh: float = _P.REF_SPEED * 0.3
	var burst_thresh: float = _P.REF_SPEED
	var pause := 0
	var burst := 0
	var coast := 0
	for s in speeds:
		if s < pause_thresh:
			pause += 1
		elif s > burst_thresh:
			burst += 1
		else:
			coast += 1
	var n := float(speeds.size())
	return {
		"mean_dist": _mean(dists),
		"mean_speed": _mean(speeds),
		"speed_var": _variance(speeds),
		"pause_frac": float(pause) / n,
		"burst_frac": float(burst) / n,
		"coast_frac": float(coast) / n,
		"weave_reversals": _reversals(trace, actor),
	}


## Reference-diff: the per-metric delta of a recreated fight vs a reference fight, for the same
## actor. Small deltas mean the recreation tracks the reference's feel (the advisory tolerance
## check); large deltas are the rev-0 churn signature.
static func reference_diff(staged_events: Array, reference_events: Array, actor: String) -> Dictionary:
	var a := trace_stats(staged_events, actor)
	var b := trace_stats(reference_events, actor)
	return {
		"mean_dist": float(a.mean_dist) - float(b.mean_dist),
		"mean_speed": float(a.mean_speed) - float(b.mean_speed),
		"pause_frac": float(a.pause_frac) - float(b.pause_frac),
		"coast_frac": float(a.coast_frac) - float(b.coast_frac),
	}


## Weave amplitude advisory: peak lateral excursion vs the WEAVE_MIN floor (radians of bearing
## swing approximated by the velocity-reversal count being non-trivial). Reported, not gating.
static func weave_signature(staged_events: Array, actor: String) -> Dictionary:
	var trace := _MT.movement_trace(staged_events)
	return {"reversals": _reversals(trace, actor), "min_floor": _P.WEAVE_MIN}


static func _reversals(trace: Array, actor: String) -> int:
	var prev := Vector2.ZERO
	var rev := 0
	for r in trace:
		if r.actor != actor:
			continue
		var spd := float(r.speed)
		if spd < 1e-3:
			continue
		var v := Vector2(cos(deg_to_rad(float(r.bearing_deg))), sin(deg_to_rad(float(r.bearing_deg)))) * spd
		if prev != Vector2.ZERO and prev.dot(v) < 0.0:
			rev += 1
		prev = v
	return rev


static func _mean(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := 0.0
	for v in arr:
		s += float(v)
	return s / float(arr.size())


static func _variance(arr: Array) -> float:
	if arr.size() < 2:
		return 0.0
	var m := _mean(arr)
	var s := 0.0
	for v in arr:
		s += (float(v) - m) * (float(v) - m)
	return s / float(arr.size())
