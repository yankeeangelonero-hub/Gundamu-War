extends RefCounted
## Pure fight-log spectacle profiler for the CF-FIREWORKS slice.
##
## This is intentionally a measurement layer, not a tuning layer: same events + metadata
## produce the same profile, and thresholds live only in compare().

const DEFAULT_TICK_SECONDS := 0.1
const DEFAULT_TAIL_SECONDS := 5.0
const DEAD_AIR_LIMIT_SEC := 3.0
const MIN_ATTACK_DENSITY_FACTOR := 0.55
const MIN_WEAPON_KINDS := 2

const ATTACK_KINDS := ["fire_beam", "fire_burst", "fire_missiles", "fire_buster", "melee", "shot"]
const HEAVY_KINDS := ["fire_buster"]

static func profile(events: Array, log_id := "", meta := {}) -> Dictionary:
	var metadata: Dictionary = meta if meta is Dictionary else {}
	var tick_seconds := float(metadata.get("tick_seconds", DEFAULT_TICK_SECONDS))
	var tail_seconds := float(metadata.get("tail_seconds", DEFAULT_TAIL_SECONDS))
	var duration_sec := _duration_sec(events, tick_seconds, tail_seconds)
	var attack_count := 0
	var advance_count := 0
	var boost_count := 0
	var stagger_count := 0
	var heavy_beat_count := 0
	var defensive_reversal_count := 0
	var weapon_mix := {}
	var spectacle_ticks := []
	var finisher := _empty_finisher()

	for e in events:
		var event: Dictionary = e if e is Dictionary else {}
		var kind := str(event.get("kind", ""))
		var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
		var tick := int(event.get("tick", 0))

		if kind == "advance":
			advance_count += 1
			if bool(payload.get("boost", false)):
				boost_count += 1
			spectacle_ticks.append(tick)
		elif kind == "stagger":
			stagger_count += 1
			spectacle_ticks.append(tick)
		elif kind == "destroyed":
			spectacle_ticks.append(tick)

		if _is_attack(event):
			attack_count += 1
			spectacle_ticks.append(tick)
			var weapon_key := _weapon_key(event)
			weapon_mix[weapon_key] = int(weapon_mix.get(weapon_key, 0)) + 1
			if _is_heavy(event):
				heavy_beat_count += 1
			if _is_defensive_or_reversal(event):
				defensive_reversal_count += 1
			if _is_finisher(event):
				finisher = _finisher_for(event)

	var director_beats := _director_beats(events, finisher, duration_sec, tick_seconds)
	var longest_dead_air_sec := _longest_gap_sec(spectacle_ticks, tick_seconds)
	return {
		"schema": "km-spectacle-profile-v0",
		"log_id": log_id,
		"source": str(metadata.get("source", "unknown")),
		"seed": metadata.get("seed", null),
		"archetypes": metadata.get("archetypes", {}),
		"matchup_shape": str(metadata.get("matchup_shape", "unclassified")),
		"human_taste_verdict": str(metadata.get("human_taste_verdict", "")),
		"duration_sec": snappedf(duration_sec, 0.001),
		"event_count": events.size(),
		"attack_count": attack_count,
		"attack_density_per_sec": snappedf(float(attack_count) / maxf(duration_sec, 0.001), 0.001),
		"longest_dead_air_sec": snappedf(longest_dead_air_sec, 0.001),
		"weapon_mix": weapon_mix,
		"weapon_kind_count": weapon_mix.keys().size(),
		"heavy_beat_count": heavy_beat_count,
		"defensive_reversal_count": defensive_reversal_count,
		"movement_profile": {
			"advance_count": advance_count,
			"boost_count": boost_count,
			"stagger_count": stagger_count,
			"range_state_changes": _range_state_changes(events),
		},
		"director_beats": director_beats,
		"finisher": finisher,
	}


static func compare(candidate: Dictionary, baseline: Dictionary, options := {}) -> Dictionary:
	var opts: Dictionary = options if options is Dictionary else {}
	var density_floor := float(baseline.get("attack_density_per_sec", 0.0)) * float(opts.get("min_attack_density_factor", MIN_ATTACK_DENSITY_FACTOR))
	var dead_air_limit := maxf(float(opts.get("dead_air_limit_sec", DEAD_AIR_LIMIT_SEC)), float(baseline.get("longest_dead_air_sec", 0.0)) * 1.5)
	var min_weapon_kinds := int(opts.get("min_weapon_kinds", MIN_WEAPON_KINDS))
	var finisher: Dictionary = candidate.get("finisher", {}) if candidate.get("finisher", {}) is Dictionary else {}
	var checks := {
		"attack_density": float(candidate.get("attack_density_per_sec", 0.0)) >= density_floor,
		"dead_air": float(candidate.get("longest_dead_air_sec", 0.0)) <= dead_air_limit,
		"weapon_mix": int(candidate.get("weapon_kind_count", 0)) >= min_weapon_kinds,
		"finisher": bool(finisher.get("lethal", false)),
	}
	var passes := true
	for value in checks.values():
		if not bool(value):
			passes = false
	return {
		"schema": "km-spectacle-compare-v0",
		"baseline": baseline.get("log_id", ""),
		"candidate": candidate.get("log_id", ""),
		"passes": passes,
		"checks": checks,
		"floors": {
			"attack_density_per_sec": snappedf(density_floor, 0.001),
			"dead_air_limit_sec": snappedf(dead_air_limit, 0.001),
			"min_weapon_kinds": min_weapon_kinds,
		},
		"notes": _comparison_notes(candidate, checks),
	}


static func format_summary(p: Dictionary) -> String:
	var mix: Dictionary = p.get("weapon_mix", {}) if p.get("weapon_mix", {}) is Dictionary else {}
	var weapons := mix.keys()
	weapons.sort()
	var finisher: Dictionary = p.get("finisher", {}) if p.get("finisher", {}) is Dictionary else {}
	var movement: Dictionary = p.get("movement_profile", {}) if p.get("movement_profile", {}) is Dictionary else {}
	return "%.1fs | %d atk | %.2f/s | dead %.1fs\nboost %d | heavy %d | def %d | %s\nfinish %s%s" % [
		float(p.get("duration_sec", 0.0)),
		int(p.get("attack_count", 0)),
		float(p.get("attack_density_per_sec", 0.0)),
		float(p.get("longest_dead_air_sec", 0.0)),
		int(movement.get("boost_count", 0)),
		int(p.get("heavy_beat_count", 0)),
		int(p.get("defensive_reversal_count", 0)),
		", ".join(weapons),
		str(finisher.get("kind", "none")),
		(" heavy" if bool(finisher.get("heavy", false)) else ""),
	]


static func _duration_sec(events: Array, tick_seconds: float, tail_seconds: float) -> float:
	if events.is_empty():
		return 0.0
	var end_tick := 0
	for e in events:
		if e is Dictionary:
			end_tick = maxi(end_tick, int(e.get("tick", 0)))
	return float(end_tick) * tick_seconds + tail_seconds


static func _is_attack(event: Dictionary) -> bool:
	return str(event.get("kind", "")) in ATTACK_KINDS


static func _weapon_key(event: Dictionary) -> String:
	var kind := str(event.get("kind", ""))
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	if kind == "shot":
		return str(payload.get("source_kind", payload.get("motif", "shot")))
	return kind


static func _is_heavy(event: Dictionary) -> bool:
	var kind := str(event.get("kind", ""))
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	if kind in HEAVY_KINDS:
		return true
	if kind == "shot":
		return int(payload.get("tier", 1)) >= 3 or str(payload.get("motif", "")) == "buster" or str(payload.get("source_kind", "")) in HEAVY_KINDS
	return false


static func _is_finisher(event: Dictionary) -> bool:
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	if bool(payload.get("lethal", false)):
		return true
	var source_payload: Dictionary = payload.get("source_payload", {}) if payload.get("source_payload", {}) is Dictionary else {}
	return bool(source_payload.get("lethal", false))


static func _finisher_for(event: Dictionary) -> Dictionary:
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	var weapon_key := _weapon_key(event)
	var heavy := _is_heavy(event)
	return {
		"kind": weapon_key,
		"actor": str(event.get("actor", "")),
		"tick": int(event.get("tick", 0)),
		"heavy": heavy,
		"lethal": true,
		"quality": "heavy_finisher" if heavy else "clean_finisher",
	}


static func _empty_finisher() -> Dictionary:
	return {
		"kind": "none",
		"actor": "",
		"tick": -1,
		"heavy": false,
		"lethal": false,
		"quality": "missing",
	}


static func _is_defensive_or_reversal(event: Dictionary) -> bool:
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	if bool(payload.get("blocked", false)):
		return true
	if payload.has("hit") and not bool(payload.get("hit", true)):
		return true
	if payload.has("hits") and int(payload.get("hits", 0)) <= 0:
		return true
	var outcome := str(payload.get("outcome", ""))
	if outcome in ["miss", "blocked", "evade", "parry", "reversal"]:
		return true
	var source_payload: Dictionary = payload.get("source_payload", {}) if payload.get("source_payload", {}) is Dictionary else {}
	return bool(source_payload.get("blocked", false)) or (source_payload.has("hits") and int(source_payload.get("hits", 0)) <= 0)


static func _longest_gap_sec(ticks: Array, tick_seconds: float) -> float:
	if ticks.is_empty():
		return 0.0
	var unique := {}
	for t in ticks:
		unique[int(t)] = true
	var sorted_ticks := unique.keys()
	sorted_ticks.sort()
	var longest := 0
	var prev := int(sorted_ticks[0])
	for i in range(1, sorted_ticks.size()):
		var tick := int(sorted_ticks[i])
		longest = maxi(longest, tick - prev)
		prev = tick
	return float(longest) * tick_seconds


static func _director_beats(events: Array, finisher: Dictionary, duration_sec: float, tick_seconds: float) -> Dictionary:
	var has_opening_attack := false
	var has_mid_escalation := false
	var has_melee := false
	var has_destroyed := false
	var mid_start_tick := int((duration_sec / tick_seconds) * 0.30)
	var mid_end_tick := int((duration_sec / tick_seconds) * 0.85)
	for e in events:
		if not (e is Dictionary):
			continue
		var event: Dictionary = e
		var kind := str(event.get("kind", ""))
		var tick := int(event.get("tick", 0))
		if kind == "destroyed":
			has_destroyed = true
		if not _is_attack(event):
			continue
		if tick <= mid_start_tick:
			has_opening_attack = true
		if tick >= mid_start_tick and tick <= mid_end_tick and (_is_heavy(event) or _weapon_key(event) in ["fire_missiles", "missiles", "melee", "saber"]):
			has_mid_escalation = true
		if kind == "melee" or _weapon_key(event) in ["melee", "saber"]:
			has_melee = true
	return {
		"opening_hero": has_opening_attack,
		"mid_escalation": has_mid_escalation,
		"melee_cut": has_melee,
		"bullet_time_finisher": bool(finisher.get("lethal", false)),
		"aftermath_hold": has_destroyed,
	}


static func _range_state_changes(events: Array) -> int:
	var last_band := ""
	var changes := 0
	for e in events:
		if not (e is Dictionary):
			continue
		var event: Dictionary = e
		if str(event.get("kind", "")) != "advance":
			continue
		var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
		if not payload.has("to_x"):
			continue
		var band := _range_band(absf(float(payload.get("to_x", 0.0))))
		if last_band != "" and band != last_band:
			changes += 1
		last_band = band
	return changes


static func _range_band(abs_x: float) -> String:
	if abs_x < 18.0:
		return "near"
	if abs_x < 36.0:
		return "mid"
	return "far"


static func _comparison_notes(candidate: Dictionary, checks: Dictionary) -> Array:
	var notes := []
	if not bool(checks.get("attack_density", false)):
		notes.append("attack density below floor")
	if not bool(checks.get("dead_air", false)):
		notes.append("dead-air gap above floor")
	if not bool(checks.get("weapon_mix", false)):
		notes.append("weapon mix too narrow")
	if not bool(checks.get("finisher", false)):
		notes.append("missing lethal finisher")
	if notes.is_empty():
		notes.append("passes scaffold fireworks floor")
	return notes
