extends SceneTree
## Throwaway: stage the SAME demo truth twice — A as a heavy slow bruiser vs a light fast
## skirmisher — and write two renderable logs, to show the FeelProfile handle is live.
## Outputs res://data/grammar_demo_heavy.json and res://data/grammar_demo_light.json.

const MOTIF_KIND := {"beam": "fire_beam", "buster": "fire_buster", "burst": "fire_burst", "missiles": "fire_missiles"}

const DEMO := preload("res://tests/_render_demo.gd")

func write_log(path: String, profiles: Dictionary) -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	var t: Array = DEMO.new().truth()
	var staged: Array = C.stage(t, 7, profiles)
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
				var kind: String = MOTIF_KIND.get(sp.get("motif", "beam"), "fire_beam")
				var connects: bool = sp.get("outcome", "") == "hit"
				var fp := {"hit": connects}
				if kind == "fire_burst":
					fp["hits"] = 3 if connects else 0
				elif kind == "fire_missiles":
					fp["hits"] = 4 if connects else 0
				if sp.has("damage"):
					fp["damage"] = sp.damage
				if sp.has("hp_after"):
					fp["hp_after"] = sp.hp_after
				if sp.get("lethal", false):
					fp["lethal"] = true
				events.append({"tick": int(e.tick), "actor": e.actor, "kind": kind, "payload": fp})
			_:
				events.append(e)
	var doc := {"schema": "km-director-spike-fight-log-v1", "tick_seconds": 0.1, "events": events,
		"presentation": C.presentation(t, 7, profiles)}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	print("wrote %s" % path)

func _init() -> void:
	# A heavy, slow bruiser: closes to brawl, plants, throws hard.
	write_log("res://data/grammar_demo_heavy.json", {
		"A": {"heft": 0.92, "tempo": 0.2, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
	})
	# A light, fast skirmisher: keeps range, strafes quick and wide.
	write_log("res://data/grammar_demo_light.json", {
		"A": {"heft": 0.08, "tempo": 0.92, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
	})
	quit()
