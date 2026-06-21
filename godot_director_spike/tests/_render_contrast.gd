extends SceneTree
## Throwaway: the most-contrasting loadout pair, staged head-to-head so the two feels read
## back to back. A = ANVIL (heavy melee brawler: heft 0.9, saber + buster); B = HORNET (light
## swarm skirmisher: heft 0.1, missiles + burst). Pilots are mode-neutral so each WEAPON drives
## its own exchange mode via the motif table: saber->melee, buster->beam-trade, missiles/burst
## ->swarm. So A charges to clash and lobs heavy beams (planted, momentum-carrying, KNOCK 8 =
## barely flinches); B kites at range on a wide weave (ORBIT_AMP 0.85) and gets tossed when hit
## (KNOCK 22 + light heft). Writes data/contrast_anvil_hornet.json (block-out render).

const MOTIF_KIND := {"beam": "fire_beam", "buster": "fire_buster", "burst": "fire_burst", "missiles": "fire_missiles", "vulcan": "fire_burst"}

func profiles() -> Dictionary:
	return {
		"A": {"heft": 0.9, "tempo": 0.25, "mode_mix": {}, "overrides": {"KNOCK": 8.0}},
		"B": {"heft": 0.1, "tempo": 0.95, "mode_mix": {}, "overrides": {"ORBIT_AMP": 0.85, "KNOCK": 22.0}},
	}

func s(tick: int, seq: int, actor: String, motif: String, tier: int, travel: int, dmg: int, lethal := false) -> Dictionary:
	var p := {"motif": motif, "tier": tier, "travel": travel, "outcome": "hit" if dmg > 0 else "miss"}
	if dmg > 0:
		p["damage"] = dmg
	if lethal:
		p["lethal"] = true
	return {"tick": tick, "seq": seq, "actor": actor, "kind": "shot", "payload": p}

# ~128-tick contested duel A (Anvil) wins on a finishing saber clash. A alternates melee clashes
# (saber) with heavy mid-range beams (buster); B answers with stand-off salvos (missiles/burst).
func truth() -> Array:
	return [
		{"tick": 0, "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0, "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		s(12,  2, "B", "missiles", 3, 6, 8),
		s(22,  3, "A", "buster",   3, 6, 10),
		s(32,  4, "B", "burst",    1, 4, 5),
		s(42,  5, "A", "saber",    3, 2, 12),
		s(54,  6, "B", "missiles", 3, 6, 8),
		s(64,  7, "A", "buster",   3, 6, 0),
		s(74,  8, "B", "burst",    1, 4, 5),
		s(84,  9, "A", "saber",    3, 2, 14),
		s(96, 10, "B", "missiles", 3, 6, 6),
		s(106,11, "A", "buster",   3, 6, 10),
		s(118,12, "B", "burst",    1, 4, 0),
		s(128,13, "A", "saber",    3, 2, 30, true),
		{"tick": 128, "seq": 14, "actor": "B", "kind": "destroyed", "payload": {}},
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
						fp["rounds"] = 4
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
	var f := FileAccess.open("res://data/contrast_anvil_hornet.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	print("wrote contrast_anvil_hornet.json (%d events)" % events.size())
	quit()
