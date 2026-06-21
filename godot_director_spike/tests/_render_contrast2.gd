extends SceneTree
## Throwaway: the fast-vs-slow pair where the EXCHANGE MODE carries the speed contrast (not just
## the body dials). A = LANCER (fast close-pressure duelist: heft 0.25, tempo 0.9, vulcan-led ->
## dodge-pursuit = charge in + sustained weave, plus saber clashes); B = BASTION (slow planted
## gunline: heft 0.9, tempo 0.2, buster/beam -> beam-trade = holds ground, minimal strafe). Pilots
## are mode-neutral so each WEAPON drives its mode: vulcan->dodge-pursuit, saber->melee,
## buster/beam->beam-trade. So Lancer is in constant motion (boost-charges + weaves) while Bastion
## plants and trades heavy fire. Writes data/contrast_lancer_bastion.json (block-out render).

const MOTIF_KIND := {"beam": "fire_beam", "buster": "fire_buster", "burst": "fire_burst", "missiles": "fire_missiles", "vulcan": "fire_burst"}

func profiles() -> Dictionary:
	return {
		"A": {"heft": 0.25, "tempo": 0.9, "mode_mix": {}, "overrides": {"WEAVE": 22.0}},
		"B": {"heft": 0.9, "tempo": 0.2, "mode_mix": {}, "overrides": {}},
	}

func s(tick: int, seq: int, actor: String, motif: String, tier: int, travel: int, dmg: int, lethal := false) -> Dictionary:
	var p := {"motif": motif, "tier": tier, "travel": travel, "outcome": "hit" if dmg > 0 else "miss"}
	if dmg > 0:
		p["damage"] = dmg
	if lethal:
		p["lethal"] = true
	return {"tick": tick, "seq": seq, "actor": actor, "kind": "shot", "payload": p}

# ~122-tick duel the fast duelist (A) wins by closing. A charges + weaves with vulcan (dodge-pursuit)
# and punctuates with saber clashes; B holds its mark and trades heavy buster/beam (beam-trade).
func truth() -> Array:
	return [
		{"tick": 0, "seq": 0, "actor": "A", "kind": "spawn", "payload": {"hp": 100}},
		{"tick": 0, "seq": 1, "actor": "B", "kind": "spawn", "payload": {"hp": 100}},
		s(12,  2, "A", "vulcan", 1, 4, 5),
		s(22,  3, "B", "buster", 3, 6, 10),
		s(32,  4, "A", "vulcan", 1, 4, 5),
		s(42,  5, "A", "saber",  3, 2, 10),
		s(52,  6, "B", "beam",   2, 5, 8),
		s(62,  7, "A", "vulcan", 1, 4, 5),
		s(72,  8, "B", "buster", 3, 6, 0),
		s(82,  9, "A", "vulcan", 1, 4, 6),
		s(92, 10, "A", "saber",  3, 2, 12),
		s(102,11, "B", "beam",   2, 5, 8),
		s(112,12, "A", "vulcan", 1, 4, 6),
		s(122,13, "A", "saber",  3, 2, 30, true),
		{"tick": 122, "seq": 14, "actor": "B", "kind": "destroyed", "payload": {}},
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
	var f := FileAccess.open("res://data/contrast_lancer_bastion.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	print("wrote contrast_lancer_bastion.json (%d events)" % events.size())
	quit()
