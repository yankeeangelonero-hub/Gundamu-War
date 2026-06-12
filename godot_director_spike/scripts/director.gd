extends Node3D
## Director: pre-reads the fight log and turns it into staging + camera.
## This file: static shot-list builder (pure, headless-testable).
## Runtime playback is added in Task 6 below the marker comment.

const TICK := 0.1
const WIDE_LEN := 3.0
const KILLCAM_PRE := 0.5
const KILLCAM_POST := 2.5
const PUNCH_PRE := 0.3
const PUNCH_POST := 0.9
const FILLER_MAX := 4.0

static func build_shot_list(events: Array, dur: float) -> Array:
	var fixed: Array = [{"t0": 0.0, "t1": WIDE_LEN, "mode": "wide", "focus": "", "time_scale": 1.0}]
	var killcam_end := dur
	var first_beam_done := false
	for e in events:
		var t := float(e.tick) * TICK
		if e.kind == "fire_beam" and not first_beam_done:
			# the first exchange gets an over-shoulder regardless of outcome
			first_beam_done = true
			fixed.append({"t0": t - 0.3, "t1": t + 1.5, "mode": "over_shoulder",
				"focus": str(e.actor), "time_scale": 1.0})
		if e.kind == "fire_beam" and e.payload.get("lethal", false):
			fixed.append({"t0": t - KILLCAM_PRE, "t1": t + KILLCAM_POST, "mode": "killcam",
				"focus": str(e.actor), "time_scale": 0.25})
			killcam_end = t + KILLCAM_POST
		elif e.kind == "fire_beam" and e.payload.get("blocked", false):
			fixed.append({"t0": t - PUNCH_PRE, "t1": t + PUNCH_POST, "mode": "punch_in",
				"focus": _other(str(e.actor)), "time_scale": 1.0})
	fixed.append({"t0": killcam_end, "t1": dur, "mode": "orbit", "focus": "", "time_scale": 1.0})
	fixed.sort_custom(func(a, b): return float(a.t0) < float(b.t0))

	# Fill gaps between fixed shots with dollies (advance active) or two-shots.
	var shots: Array = []
	var cursor := 0.0
	var side := "A"
	for s in fixed:
		var t0 := maxf(float(s.t0), cursor)
		while t0 - cursor > 0.001:
			var seg_end := minf(cursor + FILLER_MAX, t0)
			var adv := _advance_active_at(events, cursor)
			if adv != "":
				shots.append({"t0": cursor, "t1": seg_end, "mode": "dolly", "focus": adv, "time_scale": 1.0})
			else:
				shots.append({"t0": cursor, "t1": seg_end, "mode": "two_shot", "focus": side, "time_scale": 1.0})
				side = _other(side)
			cursor = seg_end
		if float(s.t1) > cursor:
			var clipped: Dictionary = s.duplicate()
			clipped.t0 = cursor
			shots.append(clipped)
			cursor = float(s.t1)
	return shots

static func _advance_active_at(events: Array, t: float) -> String:
	for e in events:
		if e.kind == "advance":
			var t0 := float(e.tick) * TICK
			var t1 := float(e.payload.end_tick) * TICK
			if t >= t0 and t < t1:
				return str(e.actor)
	return ""

static func _other(actor: String) -> String:
	return "B" if actor == "A" else "A"

# ---- runtime playback added in Task 6 ----
