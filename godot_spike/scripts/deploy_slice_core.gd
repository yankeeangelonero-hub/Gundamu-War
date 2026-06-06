extends RefCounted

const MODE_SAFE := "safe"
const MODE_PUSH := "push"

const FIT_SAFE := "safe"
const FIT_STRETCHED := "stretched"
const FIT_OVER := "over_demanding"

const STAT_KEYS := ["damage", "defense", "initiative", "dodge", "sync_gain"]

func load_catalog(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open deploy catalog: " + path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	push_error("Deploy catalog is not a JSON object: " + path)
	return {}

func get_default_selection(catalog: Dictionary) -> Dictionary:
	var selection := {}
	for slot in catalog.get("slots", []):
		selection[str(slot.get("id", ""))] = str(slot.get("default", ""))
	return selection

func get_part(catalog: Dictionary, part_id: String) -> Dictionary:
	for part in catalog.get("parts", []):
		if str(part.get("id", "")) == part_id:
			return part
	return {}

func get_weapon_visual(catalog: Dictionary, selection: Dictionary) -> String:
	var weapon_id := str(selection.get("weapon", ""))
	var part := get_part(catalog, weapon_id)
	return str(part.get("visual", "rifle"))

func compile_build(catalog: Dictionary, selection: Dictionary) -> Dictionary:
	var base: Dictionary = catalog.get("base_mech", {})
	var stats := {}
	for key in STAT_KEYS:
		stats[key] = int(base.get(key, 0))

	var total_demand := int(base.get("demand", 0))
	var selected_parts := []
	var normalized_selection := {}

	for slot in catalog.get("slots", []):
		var slot_id := str(slot.get("id", ""))
		var part_id := str(selection.get(slot_id, slot.get("default", "")))
		var part := get_part(catalog, part_id)
		if part.is_empty():
			continue

		normalized_selection[slot_id] = part_id
		total_demand += int(part.get("demand", 0))
		var combat: Dictionary = part.get("combat", {})
		for key in STAT_KEYS:
			stats[key] = int(stats[key]) + int(combat.get(key, 0))

		selected_parts.append({
			"slot": slot_id,
			"id": part_id,
			"label": str(part.get("label", part_id)),
			"demand": int(part.get("demand", 0)),
			"combat": _copy_stat_block(combat),
			"visual": str(part.get("visual", "stat")),
		})

	for key in STAT_KEYS:
		stats[key] = max(int(stats[key]), 0)

	return {
		"id": str(base.get("id", "base_mech")),
		"name": str(base.get("name", "Base Mech")),
		"selection": normalized_selection,
		"parts": selected_parts,
		"demand": total_demand,
		"damage": int(stats["damage"]),
		"defense": int(stats["defense"]),
		"initiative": int(stats["initiative"]),
		"dodge": int(stats["dodge"]),
		"sync_gain": int(stats["sync_gain"]),
	}

func forecast_fit(catalog: Dictionary, selection: Dictionary) -> Dictionary:
	var pilot: Dictionary = catalog.get("pilot", {})
	var build := compile_build(catalog, selection)
	var capacity := int(pilot.get("capacity", 0))
	var demand := int(build.get("demand", 0))
	var margin := capacity - demand
	var state := FIT_SAFE
	var label := "Safe"
	var explanation := "Safe fit: pilot can handle this cleanly."

	if demand > capacity + 15:
		state = FIT_OVER
		label = "Over-demanding"
		explanation = "Over-demanding fit: sync starts rough; pilot returns safely, but output can lag."
	elif demand > capacity:
		state = FIT_STRETCHED
		label = "Stretched"
		explanation = "Push fit: breakthrough possible, fight gets harder."

	return {
		"state": state,
		"label": label,
		"demand": demand,
		"capacity": capacity,
		"margin": margin,
		"explanation": explanation,
		"build": build,
	}

func preview_deploy(catalog: Dictionary, selection: Dictionary, mode: String) -> Dictionary:
	var forecast := forecast_fit(catalog, selection)
	var build: Dictionary = forecast.get("build", {})
	var capacity := int(forecast.get("capacity", 0))
	var demand := int(forecast.get("demand", 0))
	var effective_demand: int = _effective_demand(catalog, demand, mode)
	var pressure: int = maxi(effective_demand - capacity, 0)
	var sync_hint := 5
	var xp_hint := 8
	var breakthrough_hint := 2
	var text := ""

	if mode == MODE_SAFE:
		sync_hint = 5 + _i_div(max(capacity - effective_demand, 0), 10)
		xp_hint = 8 + _i_div(sync_hint, 3)
		breakthrough_hint = 1 + _i_div(sync_hint, 6)
		text = "Steady sortie: lower output, easier sync, modest growth."
	else:
		sync_hint = max(3, 8 - _i_div(pressure, 8) + _i_div(int(build.get("sync_gain", 0)), 4))
		xp_hint = max(6, 11 + _i_div(sync_hint, 2) - _i_div(pressure, 10))
		breakthrough_hint = max(4, 12 + sync_hint - _i_div(pressure, 5))
		text = "Breakthrough push: harder duel, larger sync and breakthrough upside."

	return {
		"mode": mode,
		"effective_demand": effective_demand,
		"fit_pressure": pressure,
		"sync_hint": sync_hint,
		"xp_hint": xp_hint,
		"breakthrough_hint": breakthrough_hint,
		"text": text,
	}

func run_deploy(catalog: Dictionary, selection: Dictionary, mode: String, seed_override: int = -1) -> Dictionary:
	var seed_value := int(catalog.get("seed", 0))
	if int(seed_override) >= 0:
		seed_value = int(seed_override)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var pilot: Dictionary = catalog.get("pilot", {})
	var ghost: Dictionary = catalog.get("ghost_opponent", {})
	var forecast := forecast_fit(catalog, selection)
	var build: Dictionary = forecast.get("build", {})
	var preview := preview_deploy(catalog, selection, mode)

	var capacity := int(forecast.get("capacity", 0))
	var demand := int(forecast.get("demand", 0))
	var effective_demand := int(preview.get("effective_demand", demand))
	var fit_pressure: int = maxi(effective_demand - capacity, 0)
	var stability: int = maxi(capacity - effective_demand, 0)

	var player_hp := 175 + int(build.get("defense", 0)) * 4
	if mode == MODE_SAFE:
		player_hp += 18
	player_hp -= fit_pressure * 2
	player_hp = max(player_hp, 80)

	var ghost_hp := int(ghost.get("hp", 150))
	if mode == MODE_PUSH:
		ghost_hp += 20 + fit_pressure

	var ghost_pressure := int(ghost.get("sync_pressure", 0))
	if mode == MODE_PUSH:
		ghost_pressure += 8
	ghost_pressure += _i_div(fit_pressure, 3)

	var sync: int = maxi(4, 10 + mini(_i_div(stability, 3), 8) - mini(_i_div(fit_pressure, 5), 5))
	var start_sync: int = sync
	var max_sync := int(pilot.get("sync_ceiling", 100))
	var events := []

	events.append({
		"type": "deploy",
		"mode": mode,
		"forecast_state": str(forecast.get("state", "")),
		"demand": demand,
		"effective_demand": effective_demand,
		"fit_pressure": fit_pressure,
		"player_hp": player_hp,
		"ghost_hp": ghost_hp,
		"text": _deploy_text(forecast, mode, fit_pressure),
	})

	var clip := "rifle_burst"
	if get_weapon_visual(catalog, selection) == "saber":
		clip = "melee_saber"

	var rounds := 0
	while player_hp > 0 and ghost_hp > 0 and rounds < 8:
		rounds += 1

		var sync_gain := _round_sync_gain(build, forecast, mode, stability, fit_pressure)
		sync = min(sync + sync_gain, max_sync)
		events.append({
			"type": "sync",
			"round": rounds,
			"sync": sync,
			"sync_gain": sync_gain,
			"fit_pressure": fit_pressure,
			"text": "Round %d sync +%d (sync %d)." % [rounds, sync_gain, sync],
		})

		var roll := rng.randi_range(-3, 4)
		var player_damage := _player_damage(build, ghost, mode, sync, fit_pressure, roll)
		ghost_hp = max(ghost_hp - player_damage, 0)
		events.append({
			"type": "attack",
			"round": rounds,
			"source": "player",
			"target": "ghost",
			"clip": clip,
			"roll": roll,
			"damage": player_damage,
			"target_hp": ghost_hp,
			"fit_pressure": fit_pressure,
			"text": "Ari attacks for %d. Ghost HP %d." % [player_damage, ghost_hp],
		})

		if ghost_hp <= 0:
			break

		var ghost_roll := rng.randi_range(-2, 5)
		var incoming := _ghost_damage(build, ghost, mode, ghost_pressure, fit_pressure, ghost_roll)
		player_hp = max(player_hp - incoming, 0)
		events.append({
			"type": "attack",
			"round": rounds,
			"source": "ghost",
			"target": "player",
			"clip": "hit_spark",
			"roll": ghost_roll,
			"damage": incoming,
			"target_hp": player_hp,
			"fit_pressure": fit_pressure,
			"text": "Ghost counters for %d. Ari HP %d." % [incoming, player_hp],
		})

	var won := ghost_hp <= 0 and player_hp > 0
	var result := _result(catalog, forecast, mode, won, player_hp, ghost_hp, start_sync, sync, fit_pressure, rounds)
	events.append({
		"type": "result",
		"won": won,
		"sync_gained": int(result.get("sync_gained", 0)),
		"xp_gained": int(result.get("xp_gained", 0)),
		"breakthrough_progress_gained": int(result.get("breakthrough_progress_gained", 0)),
		"no_permanent_pilot_harm": true,
		"text": str(result.get("explanation", "")),
	})

	return {
		"input": {
			"seed": seed_value,
			"mode": mode,
			"selection": build.get("selection", {}),
			"pilot_id": str(pilot.get("id", "")),
			"opponent_id": str(ghost.get("id", "")),
		},
		"forecast": _public_forecast(forecast),
		"preview": preview,
		"build": build,
		"events": events,
		"result": result,
	}

func _copy_stat_block(combat: Dictionary) -> Dictionary:
	var out := {}
	for key in STAT_KEYS:
		out[key] = int(combat.get(key, 0))
	return out

func _public_forecast(forecast: Dictionary) -> Dictionary:
	return {
		"state": str(forecast.get("state", "")),
		"label": str(forecast.get("label", "")),
		"demand": int(forecast.get("demand", 0)),
		"capacity": int(forecast.get("capacity", 0)),
		"margin": int(forecast.get("margin", 0)),
		"explanation": str(forecast.get("explanation", "")),
	}

func _effective_demand(catalog: Dictionary, demand: int, mode: String) -> int:
	var base: Dictionary = catalog.get("base_mech", {})
	if mode == MODE_SAFE:
		return max(int(base.get("demand", 0)), demand - 8)
	return demand + 6

func _round_sync_gain(build: Dictionary, forecast: Dictionary, mode: String, stability: int, fit_pressure: int) -> int:
	var gain := 4 + _i_div(int(build.get("sync_gain", 0)), 2)
	if mode == MODE_SAFE:
		gain += min(_i_div(stability, 8), 3)
		gain -= _i_div(fit_pressure, 8)
	else:
		gain += 3
		gain -= _i_div(fit_pressure, 7)
		if str(forecast.get("state", "")) == FIT_STRETCHED:
			gain += 2
	return max(gain, 2)

func _player_damage(build: Dictionary, ghost: Dictionary, mode: String, sync: int, fit_pressure: int, roll: int) -> int:
	var mode_bonus := 6
	if mode == MODE_SAFE:
		mode_bonus = -4
	var damage := int(build.get("damage", 0)) + mode_bonus + _i_div(sync, 12)
	damage -= _i_div(int(ghost.get("defense", 0)), 2)
	damage -= _i_div(fit_pressure, 2)
	damage += roll
	if mode == MODE_SAFE:
		damage -= 2
	return max(damage, 5)

func _ghost_damage(build: Dictionary, ghost: Dictionary, mode: String, ghost_pressure: int, fit_pressure: int, roll: int) -> int:
	var incoming := int(ghost.get("damage", 0)) + ghost_pressure
	incoming -= _i_div(int(build.get("defense", 0)), 2)
	incoming -= _i_div(int(build.get("dodge", 0)), 5)
	incoming += _i_div(fit_pressure, 6)
	incoming += roll
	if mode == MODE_SAFE:
		incoming -= 5
	return max(incoming, 4)

func _result(catalog: Dictionary, forecast: Dictionary, mode: String, won: bool, player_hp: int, ghost_hp: int, start_sync: int, sync: int, fit_pressure: int, rounds: int) -> Dictionary:
	var pilot: Dictionary = catalog.get("pilot", {})
	var sync_gained: int = maxi(sync - start_sync, 0)
	var xp_gained := 0
	var breakthrough_gain := 0

	if mode == MODE_SAFE:
		xp_gained = (10 if won else 6) + _i_div(sync_gained, 6)
		breakthrough_gain = 1 + _i_div(sync_gained, 10)
	else:
		xp_gained = (14 if won else 7) + _i_div(sync_gained, 4) - _i_div(fit_pressure, 8)
		breakthrough_gain = 10 + _i_div(sync_gained, 2) - _i_div(fit_pressure, 4)
		if str(forecast.get("state", "")) == FIT_STRETCHED:
			breakthrough_gain += 8
		if not won:
			breakthrough_gain -= 5

	xp_gained = max(xp_gained, 3)
	breakthrough_gain = max(breakthrough_gain, 1 if mode == MODE_SAFE else 4)

	var current_progress := int(pilot.get("breakthrough_progress", 0))
	var total_progress: int = mini(current_progress + breakthrough_gain, 100)
	var breakthrough_earned := current_progress + breakthrough_gain >= 100

	return {
		"outcome": "WIN" if won else "LOSS",
		"won": won,
		"rounds": rounds,
		"final_player_hp": player_hp,
		"final_ghost_hp": ghost_hp,
		"sync_gained": sync_gained,
		"final_sync": sync,
		"xp_gained": xp_gained,
		"breakthrough_progress_before": current_progress,
		"breakthrough_progress_gained": breakthrough_gain,
		"breakthrough_progress_after": total_progress,
		"breakthrough_earned": breakthrough_earned,
		"no_permanent_pilot_harm": true,
		"pilot_harm": "none",
		"explanation": _result_explanation(forecast, mode, won, fit_pressure),
	}

func _deploy_text(forecast: Dictionary, mode: String, fit_pressure: int) -> String:
	if mode == MODE_SAFE:
		return "Deploy Safe lowers effective demand and keeps growth modest."
	if fit_pressure > 0:
		return "Push adds pressure: demand exceeds capacity by %d." % fit_pressure
	return "Push keeps demand inside capacity and chases a larger breakthrough."

func _i_div(value: int, divisor: int) -> int:
	if divisor == 0:
		return 0
	return int(value / divisor)

func _result_explanation(forecast: Dictionary, mode: String, won: bool, fit_pressure: int) -> String:
	var state := str(forecast.get("state", ""))
	if mode == MODE_SAFE:
		return "Safe deployment kept fit manageable; Ari returns with steady growth and no permanent harm."
	if state == FIT_OVER:
		return "Demand exceeded capacity by %d, so sync climbed unevenly and output lagged. Ari returns safely; the cost is slower growth, not harm." % fit_pressure
	if state == FIT_STRETCHED:
		if won:
			return "The stretched fit was hard, but Ari converted the pressure into sync and breakthrough progress."
		return "The stretched fit outpaced current sync. Ari returns safely with partial progress and no permanent harm."
	return "The push created extra pressure for a larger reward while staying readable through fit and sync."
