extends SceneTree
## Throwaway: a long (~200-tick) weapon-varied grind to judge the weight pass over time.
## A is a HEAVY build (heft 0.92); B a medium build. Weapons drive the exchange mode via the
## motif table (neutral pilots), so the fight cycles beam-trade / swarm / dodge-pursuit / melee.
## Writes data/longfight.json (block-out render). saber clashes only tight-cut on heavy beats.

const MOTIF_KIND := {"beam": "fire_beam", "buster": "fire_buster", "burst": "fire_burst", "missiles": "fire_missiles", "vulcan": "fire_burst"}

func profiles() -> Dictionary:
	return {
		"A": {"heft": 0.92, "tempo": 0.3, "mode_mix": {}},
		"B": {"heft": 0.5, "tempo": 0.55, "mode_mix": {}},
	}

func s(tick: int, seq: int, actor: String, motif: String, tier: int, travel: int, dmg: int, lethal := false) -> Dictionary:
	var p := {"motif": motif, "tier": tier, "travel": travel, "outcome": "hit" if dmg > 0 else "miss"}
	if dmg > 0:
		p["damage"] = dmg
	if lethal:
		p["lethal"] = true
	return {"tick": tick, "seq": seq, "actor": actor, "kind": "shot", "payload": p}

func truth() -> Array:
	return [
		{"tick": 0, "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0, "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		s(12,  2, "A", "beam",     2, 5, 6),
		s(20,  3, "B", "beam",     2, 5, 6),
		s(28,  4, "A", "burst",    1, 4, 5),
		s(36,  5, "B", "vulcan",   1, 4, 0),
		s(44,  6, "A", "missiles", 3, 6, 8),
		s(54,  7, "B", "beam",     2, 5, 6),
		s(62,  8, "A", "beam",     2, 5, 0),
		s(70,  9, "B", "missiles", 3, 6, 8),
		s(80, 10, "A", "buster",   3, 6, 10),
		s(90, 11, "B", "burst",    1, 4, 5),
		s(98, 12, "A", "vulcan",   1, 4, 6),
		s(108,13, "B", "beam",     2, 5, 6),
		s(116,14, "A", "saber",    3, 2, 12),
		s(126,15, "B", "vulcan",   1, 4, 0),
		s(134,16, "A", "beam",     2, 5, 7),
		s(144,17, "B", "buster",   3, 6, 10),
		s(152,18, "A", "burst",    1, 4, 5),
		s(160,19, "B", "beam",     2, 5, 6),
		s(168,20, "A", "missiles", 3, 6, 8),
		s(176,21, "B", "beam",     2, 5, 0),
		s(184,22, "A", "saber",    3, 2, 14),
		s(196,23, "A", "buster",   3, 6, 20, true),
		{"tick": 196, "seq": 24, "actor": "B", "kind": "destroyed", "payload": {}},
	]

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	var t := truth()
	var staged: Array = C.stage(t, 7, profiles())
	var events := []
	for e in staged:
		match e.kind:
			"advance":
				var p: Dictionary = e.payload.duplicate()
				p["to_y"] = float(p.get("to_y", 0.0))
				p["boost"] = bool(p.get("boost", false))
				events.append({"tick": int(e.tick), "actor": e.actor, "kind": "advance", "payload": p})
			"shot":
				var sp: Dictionary = e.payload
				var connects: bool = sp.get("outcome", "") == "hit"
				var motif: String = sp.get("motif", "beam")
				var kind: String
				if motif == "saber":
					kind = "melee" if int(sp.get("tier", 0)) >= 3 else "fire_beam"
				else:
					kind = MOTIF_KIND.get(motif, "fire_beam")
				var fp := {}
				if kind == "melee":
					fp = {"style": "cleave", "connected": connects}
				else:
					fp = {"hit": connects}
					if kind == "fire_burst":
						fp["hits"] = 3 if connects else 0
					elif kind == "fire_missiles":
						fp["hits"] = 4 if connects else 0
				if sp.has("damage"):
					fp["damage"] = sp.damage
				if sp.get("lethal", false):
					fp["lethal"] = true
				events.append({"tick": int(e.tick), "actor": e.actor, "kind": kind, "payload": fp})
			_:
				events.append(e)
	var doc := {"schema": "km-director-spike-fight-log-v1", "tick_seconds": 0.1, "events": events,
		"presentation": C.presentation(t, 7, profiles())}
	var f := FileAccess.open("res://data/longfight.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	print("wrote longfight.json (%d events, %d shots)" % [events.size(), 22])
	quit()
