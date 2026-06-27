extends RefCounted
## M0 deterministic loadout-to-truth generator.
##
## This is the build-system bridge, not final balance: it consumes the same resolved-loadout
## shape the M1 grid resolver will later produce, and emits v2 truth events.

const DEFAULT_MAX_TICK := 450
const DEFAULT_MIN_DECISION_TICK := 320
const DEFAULT_MAX_EVENTS := 160
const DEBUG_MOTIF_TO_KIND := {
	"beam": "fire_beam",
	"burst": "fire_burst",
	"missiles": "fire_missiles",
	"buster": "fire_buster",
	"saber": "melee",
	"vulcan": "fire_burst",
}

static func generate(loadout_a: Dictionary, loadout_b: Dictionary, seed: int, chaos := 0.5) -> Dictionary:
	var c := clampf(chaos, 0.0, 1.0)
	var rng := _rng_new(seed)
	var hp := {
		"A": int(loadout_a.get("hp", 180)),
		"B": int(loadout_b.get("hp", 180)),
	}
	var truth: Array = [
		{"tick": 0, "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": hp.A}},
		{"tick": 0, "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": hp.B}},
	]
	var streams: Array = []
	_add_streams(streams, "A", loadout_a, seed)
	_add_streams(streams, "B", loadout_b, seed + 101)
	var impacts: Array = []
	var seq := 2
	var last_tick := 0
	var decided := false
	var winner := ""
	var max_tick := int(maxi(DEFAULT_MAX_TICK, int(loadout_a.get("target_duration_ticks", 0))))
	max_tick = int(maxi(max_tick, int(loadout_b.get("target_duration_ticks", 0))))
	while truth.size() + impacts.size() < DEFAULT_MAX_EVENTS and (not streams.is_empty() or not impacts.is_empty()):
		streams.sort_custom(_stream_sort)
		impacts.sort_custom(_impact_sort)
		var next_fire := int(streams[0].next_tick) if not streams.is_empty() else (1 << 28)
		var next_impact := int(impacts[0].tick) if not impacts.is_empty() else (1 << 28)
		var tick: int = mini(next_fire, next_impact)
		if tick > max_tick:
			break
		last_tick = tick

		while not impacts.is_empty() and int(impacts[0].tick) == tick:
			var impact: Dictionary = impacts.pop_front()
			var event := _resolve_impact(impact, hp, decided, c, DEFAULT_MIN_DECISION_TICK)
			event["seq"] = seq
			seq += 1
			truth.append(event)
			if not decided and bool(event.payload.get("lethal", false)):
				decided = true
				winner = str(event.actor)
				var loser := "B" if winner == "A" else "A"
				truth.append({"tick": tick, "seq": seq, "actor": loser, "kind": "destroyed", "payload": {}})
				seq += 1

		if decided:
			streams.clear()
			continue

		var due: Array = []
		while not streams.is_empty() and int(streams[0].next_tick) == tick:
			due.append(streams.pop_front())
		due.sort_custom(_fire_sort)
		for s in due:
			if decided:
				break
			var actor := str(s.actor)
			var target := "B" if actor == "A" else "A"
			if hp[actor] <= 0 or hp[target] <= 0:
				continue
			var weapon: Dictionary = s.weapon
			var hit := _roll_hit(rng, weapon, c)
			var dmg := _roll_damage(rng, weapon, c) if hit else 0
			impacts.append({
				"tick": tick + maxi(1, int(weapon.get("travel", 1))),
				"actor": actor,
				"target": target,
				"weapon": weapon,
				"hit": hit,
				"damage": dmg,
			})
			s.next_tick = tick + maxi(1, int(weapon.get("cooldown", 24)))
			streams.append(s)

	if not decided:
		var forced := _forced_finisher(loadout_a, loadout_b, hp)
		var forced_tick := maxi(last_tick + 12, DEFAULT_MIN_DECISION_TICK)
		forced_tick = mini(forced_tick, max_tick)
		var actor := str(forced.actor)
		var loser := "B" if actor == "A" else "A"
		var weapon: Dictionary = forced.weapon
		var payload := _payload_for_weapon(weapon, hp[loser], true, true)
		truth.append({"tick": forced_tick, "seq": seq, "actor": actor, "kind": "shot", "payload": payload})
		seq += 1
		truth.append({"tick": forced_tick, "seq": seq, "actor": loser, "kind": "destroyed", "payload": {}})
		winner = actor

	truth.sort_custom(func(a, b):
		if int(a.tick) != int(b.tick):
			return int(a.tick) < int(b.tick)
		return int(a.seq) < int(b.seq))
	return {
		"events": truth,
		"result": {"winner": winner, "cause": "kill"},
		"inputs": {
			"seed": seed,
			"chaos": c,
			"archetypes": {"A": loadout_a.get("archetype", ""), "B": loadout_b.get("archetype", "")},
		},
	}


static func apply_pilot_modifier(loadout: Dictionary, pilot: Dictionary) -> Dictionary:
	var out := loadout.duplicate(true)
	var modifier: Dictionary = pilot.get("kit_modifier", {}) if pilot.get("kit_modifier", {}) is Dictionary else {}
	if modifier.is_empty():
		return out
	var bonus := float(modifier.get("accuracy_bonus", 0.0))
	var weapons: Array = out.get("weapons", [])
	for i in weapons.size():
		var w: Dictionary = weapons[i]
		w["accuracy"] = clampf(float(w.get("accuracy", 0.8)) + bonus, 0.05, 0.98)
		weapons[i] = w
	out["weapons"] = weapons
	return out


static func load_catalog(path := "res://data/m0_loadout_kits.json") -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func resolve_player_loadout(catalog: Dictionary, kit_id: String, pilot_id := "pilot_aya") -> Dictionary:
	var kits: Dictionary = catalog.get("kits", {}) if catalog.get("kits", {}) is Dictionary else {}
	var pilots: Dictionary = catalog.get("pilots", {}) if catalog.get("pilots", {}) is Dictionary else {}
	var loadout: Dictionary = kits.get(kit_id, {}).duplicate(true)
	loadout["id"] = kit_id
	loadout["pilot_id"] = pilot_id
	return apply_pilot_modifier(loadout, pilots.get(pilot_id, {}))


static func resolve_opponent_loadout(catalog: Dictionary, opponent_id: String) -> Dictionary:
	var opponents: Dictionary = catalog.get("opponents", {}) if catalog.get("opponents", {}) is Dictionary else {}
	var kits: Dictionary = catalog.get("kits", {}) if catalog.get("kits", {}) is Dictionary else {}
	var opponent: Dictionary = opponents.get(opponent_id, {})
	var kit_id := str(opponent.get("kit", "rifle_missile_pressure"))
	var loadout: Dictionary = kits.get(kit_id, {}).duplicate(true)
	loadout["id"] = opponent_id
	loadout["pilot_id"] = "opponent"
	loadout["name"] = str(opponent.get("name", loadout.get("name", "Opponent")))
	loadout["hp"] = int(loadout.get("hp", 180)) + int(opponent.get("hp_bonus", 0))
	# An opponent may override the kit's stance (e.g. an artillery ghost should hold and
	# shell, not charge in like the melee-leaning anvil its kit defaults to).
	if opponent.has("grammar_preset"):
		loadout["grammar_preset"] = str(opponent.get("grammar_preset"))
	return loadout


static func resolve_showcase(catalog: Dictionary, name: String) -> Dictionary:
	var showcases: Dictionary = catalog.get("showcases", {}) if catalog.get("showcases", {}) is Dictionary else {}
	var entry: Dictionary = showcases.get(name, {}) if showcases.get(name, {}) is Dictionary else {}
	return {
		"kit": str(entry.get("kit", "")),
		"opponent": str(entry.get("opponent", "")),
		"seed": int(entry.get("seed", 77)),
		"chaos": float(entry.get("chaos", 0.5)),
	}


static func _add_streams(streams: Array, actor: String, loadout: Dictionary, seed: int) -> void:
	var weapons: Array = loadout.get("weapons", [])
	for i in weapons.size():
		var weapon: Dictionary = weapons[i]
		var jitter := int(abs(seed + i * 7 + (0 if actor == "A" else 11)) % 5)
		streams.append({
			"actor": actor,
			"weapon_idx": i,
			"weapon": weapon,
			"next_tick": int(weapon.get("start", 10 + i * 5)) + jitter,
		})


static func _stream_sort(a: Dictionary, b: Dictionary) -> bool:
	if int(a.next_tick) != int(b.next_tick):
		return int(a.next_tick) < int(b.next_tick)
	if str(a.actor) != str(b.actor):
		return str(a.actor) < str(b.actor)
	return int(a.weapon_idx) < int(b.weapon_idx)


static func _fire_sort(a: Dictionary, b: Dictionary) -> bool:
	var wa: Dictionary = a.weapon
	var wb: Dictionary = b.weapon
	if int(wa.get("initiative", 0)) != int(wb.get("initiative", 0)):
		return int(wa.get("initiative", 0)) > int(wb.get("initiative", 0))
	if str(a.actor) != str(b.actor):
		return str(a.actor) < str(b.actor)
	return str(wa.get("id", "")) < str(wb.get("id", ""))


static func _impact_sort(a: Dictionary, b: Dictionary) -> bool:
	if int(a.tick) != int(b.tick):
		return int(a.tick) < int(b.tick)
	if str(a.actor) != str(b.actor):
		return str(a.actor) < str(b.actor)
	return str(a.weapon.get("id", "")) < str(b.weapon.get("id", ""))


static func _resolve_impact(impact: Dictionary, hp: Dictionary, decided: bool, chaos: float, min_decision_tick: int) -> Dictionary:
	var weapon: Dictionary = impact.weapon
	if decided:
		return {
			"tick": int(impact.tick),
			"actor": str(impact.actor),
			"kind": "shot",
			"payload": _payload_for_weapon(weapon, 0, false, bool(impact.hit), true),
		}
	var target := str(impact.target)
	var hit := bool(impact.hit)
	var damage := int(impact.damage) if hit else 0
	if hit:
		hp[target] = maxi(0, int(hp[target]) - damage)
		if int(impact.tick) < min_decision_tick and int(hp[target]) <= 0:
			hp[target] = 1
	var lethal := hit and int(hp[target]) <= 0
	var payload := _payload_for_weapon(weapon, int(hp[target]), lethal, hit)
	if _defensive_beat(hit, chaos, weapon):
		payload["defensive_beat"] = "evade" if not hit else "guarded_hit"
	return {"tick": int(impact.tick), "actor": str(impact.actor), "kind": "shot", "payload": payload}


static func _roll_hit(rng: Dictionary, weapon: Dictionary, chaos: float) -> bool:
	var acc := float(weapon.get("accuracy", 0.8))
	var spread := lerpf(0.02, 0.12, chaos)
	acc = clampf(acc + (_next_float(rng) - 0.5) * spread, 0.05, 0.98)
	return _next_float(rng) <= acc


static func _roll_damage(rng: Dictionary, weapon: Dictionary, chaos: float) -> int:
	var base := float(weapon.get("damage", 1))
	var var_amount := float(weapon.get("variance", 0.0)) * lerpf(0.5, 1.5, chaos)
	var roll := 1.0 + ((_next_float(rng) * 2.0) - 1.0) * var_amount
	return maxi(1, int(floor(base * roll + 0.5)))


static func _defensive_beat(hit: bool, chaos: float, weapon: Dictionary) -> bool:
	if not hit:
		return true
	return chaos >= 0.55 and int(weapon.get("tier", 1)) >= 2


static func _payload_for_weapon(weapon: Dictionary, hp_after: int, lethal: bool, hit := true, post_decision := false) -> Dictionary:
	var motif := str(weapon.get("motif", "beam"))
	var source_kind := str(weapon.get("viewer_kind", DEBUG_MOTIF_TO_KIND.get(motif, "fire_beam")))
	var payload := {
		"motif": motif,
		"tier": int(weapon.get("tier", 1)),
		"travel": int(weapon.get("travel", 1)),
		"outcome": "hit" if hit else "miss",
		"source_kind": source_kind,
		"source_payload": _source_payload_for_weapon(source_kind, weapon, hp_after, lethal, hit),
	}
	if post_decision:
		payload["post_decision"] = true
		return payload
	if hit:
		payload["damage"] = int(weapon.get("damage", 0))
		payload["hp_after"] = hp_after
	if lethal:
		payload["lethal"] = true
	return payload


static func _source_payload_for_weapon(kind: String, weapon: Dictionary, hp_after: int, lethal: bool, hit: bool) -> Dictionary:
	var p: Dictionary = {"damage": int(weapon.get("damage", 0))}
	if hit:
		p["hp_after"] = hp_after
	match kind:
		"fire_burst":
			p["rounds"] = int(weapon.get("rounds", 8))
			p["hits"] = int(weapon.get("hits", 3)) if hit else 0
		"fire_missiles":
			p["count"] = int(weapon.get("count", 6))
			p["hits"] = int(weapon.get("hits", 4)) if hit else 0
		"melee":
			p["hit"] = hit
			p["style"] = str(weapon.get("style", "cleave"))
			p["result"] = "knockback"
		_:
			p["hit"] = hit
	if lethal:
		p["lethal"] = true
	return p


static func _forced_finisher(loadout_a: Dictionary, loadout_b: Dictionary, hp: Dictionary) -> Dictionary:
	var score_a := _remaining_score(loadout_a, int(hp.B))
	var score_b := _remaining_score(loadout_b, int(hp.A))
	var actor := "A" if score_a >= score_b else "B"
	var loadout := loadout_a if actor == "A" else loadout_b
	return {"actor": actor, "weapon": _strongest_weapon(loadout)}


static func _remaining_score(loadout: Dictionary, enemy_hp: int) -> float:
	return float(loadout.get("hp", 0)) - float(enemy_hp) + float(_strongest_weapon(loadout).get("damage", 0)) * 0.25


static func _strongest_weapon(loadout: Dictionary) -> Dictionary:
	var weapons: Array = loadout.get("weapons", [])
	var best: Dictionary = {}
	for w in weapons:
		if best.is_empty() or int(w.get("damage", 0)) > int(best.get("damage", 0)):
			best = w
	return best if not best.is_empty() else {"id": "fallback_beam", "motif": "beam", "viewer_kind": "fire_beam", "tier": 2, "damage": 10, "travel": 5}


static func _rng_new(seed: int) -> Dictionary:
	return {"state": int(seed) & 0xffffffff}


static func _next_u32(rng: Dictionary) -> int:
	rng.state = (int(rng.state) * 1664525 + 1013904223) & 0xffffffff
	return int(rng.state)


static func _next_float(rng: Dictionary) -> float:
	return float(_next_u32(rng)) / 4294967296.0
