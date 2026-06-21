extends SceneTree
## Throwaway: stage the SAME contested fight four ways — one per exchange mode — and write a
## renderable log for each, so the four modes can be shown side by side. A's shots are forced to
## the showcase mode and translated to that mode's weapon VFX; B fights beam-trade throughout.
## Outputs res://data/showcase_<mode>.json for <mode> in beam-trade/swarm/dodge-pursuit/melee.

const MODE_FIRE := {"beam-trade": "fire_beam", "swarm": "fire_missiles", "dodge-pursuit": "fire_burst", "melee": "melee"}

func profiles() -> Dictionary:
	return {
		"A": {"heft": 0.5, "tempo": 0.6, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
	}

# A ~105-tick contested duel A wins; every A shot carries `forced` (mode_weights for the mode).
func truth(forced: Dictionary) -> Array:
	return [
		{"tick": 0,   "seq": 0,  "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,   "seq": 1,  "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		a(10,  2, "beam", 2, 12, true, forced), b(16, 3, 12),
		a(24,  4, "beam", 2, 0, false, forced), b(30, 5, 10),
		a(38,  6, "beam", 2, 14, true, forced),
		a(50,  7, "buster", 3, 16, true, forced), b(58, 8, 12),
		a(66,  9, "beam", 2, 0, false, forced),
		a(76, 10, "beam", 2, 14, true, forced), b(82, 11, 10),
		a(92, 12, "beam", 2, 16, true, forced),
		a(104, 13, "buster", 3, 30, true, forced, true),
		{"tick": 104, "seq": 14, "actor": "B", "kind": "destroyed", "payload": {}},
	]

# A shot from A (forced to the showcase mode); hit when dmg>0.
func a(tick: int, seq: int, motif: String, tier: int, dmg: int, hit: bool, forced: Dictionary, lethal := false) -> Dictionary:
	var p := {"motif": motif, "tier": tier, "travel": 5, "outcome": "hit" if hit else "miss", "mode_weights": forced}
	if hit:
		p["damage"] = dmg
	if lethal:
		p["lethal"] = true
	return {"tick": tick, "seq": seq, "actor": "A", "kind": "shot", "payload": p}

# A beam shot from B (beam-trade), always a hit.
func b(tick: int, seq: int, dmg: int) -> Dictionary:
	return {"tick": tick, "seq": seq, "actor": "B", "kind": "shot",
		"payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": dmg}}

func write_mode(mode: String) -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	var w := {"beam-trade": 0.0, "swarm": 0.0, "dodge-pursuit": 0.0, "melee": 0.0}
	w[mode] = 1.0
	var t := truth(w)
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
				# B fires beams; A fires the showcase mode's weapon. In melee, only the committed
				# heavy clashes (tier>=3) are `melee` events — the director tight-cuts EVERY melee
				# clash so the blade reads, so light beats stay close-range fire and the wide iso
				# base view dominates (otherwise the whole fight is a zoomed-in blade close-up).
				var kind: String
				if e.actor == "B":
					kind = "fire_beam"
				elif mode == "melee":
					kind = "melee" if int(sp.get("tier", 0)) >= 3 else "fire_beam"
				else:
					kind = MODE_FIRE[mode]
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
	var f := FileAccess.open("res://data/showcase_%s.json" % mode, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	print("wrote showcase_%s.json (%d events)" % [mode, events.size()])

func _init() -> void:
	for mode in ["beam-trade", "swarm", "dodge-pursuit", "melee"]:
		write_mode(mode)
	quit()
