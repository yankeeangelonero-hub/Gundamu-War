extends SceneTree
## Throwaway render bridge (NOT a gate): stage a v2 truth through the choreographer, translate
## the v2 `shot` events to the viewer's v1 `fire_*` kinds (keeping the computed `advance`
## motion + spawn {x,z}), and write a renderable log to res://data/grammar_demo.json.
## Run the viewer with:  --director=hybrid --log=grammar_demo
##
## This is the apples-to-apples way to watch the NEW exchange in the same proven viewer as the
## hand-authored reference. The v2 director cutover that would render `shot` natively is the
## deferred, separately-gated work this stands in for.

const MOTIF_KIND := {"beam": "fire_beam", "buster": "fire_buster", "burst": "fire_burst", "missiles": "fire_missiles"}

func profiles() -> Dictionary:
	return {
		"A": {"heft": 0.55, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": 0.5, "tempo": 0.55, "mode_mix": {"ranged": 1.0}},
	}

# A contested beam duel: both land hits (a near-symmetric trade, like the reference), with
# heavy buster/missile beats and a lethal buster finale. ~17 shots over 118 ticks.
func truth() -> Array:
	return [
		{"tick": 0,   "seq": 0,  "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,   "seq": 1,  "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 10,  "seq": 2,  "actor": "A", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "hit",  "damage": 10, "hp_after": 90}},
		{"tick": 16,  "seq": 3,  "actor": "B", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "hit",  "damage": 10, "hp_after": 90}},
		{"tick": 22,  "seq": 4,  "actor": "A", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "miss"}},
		{"tick": 28,  "seq": 5,  "actor": "B", "kind": "shot",      "payload": {"motif": "burst",    "tier": 1, "travel": 4, "outcome": "hit",  "damage": 8,  "hp_after": 82}},
		{"tick": 34,  "seq": 6,  "actor": "A", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "hit",  "damage": 12, "hp_after": 78}},
		{"tick": 44,  "seq": 7,  "actor": "A", "kind": "shot",      "payload": {"motif": "buster",   "tier": 3, "travel": 6, "outcome": "hit",  "damage": 18, "hp_after": 60}},
		{"tick": 50,  "seq": 8,  "actor": "B", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "hit",  "damage": 10, "hp_after": 72}},
		{"tick": 58,  "seq": 9,  "actor": "B", "kind": "shot",      "payload": {"motif": "missiles", "tier": 3, "travel": 6, "outcome": "hit",  "damage": 16, "hp_after": 56}},
		{"tick": 64,  "seq": 10, "actor": "A", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "miss"}},
		{"tick": 70,  "seq": 11, "actor": "A", "kind": "shot",      "payload": {"motif": "burst",    "tier": 1, "travel": 4, "outcome": "hit",  "damage": 10, "hp_after": 50}},
		{"tick": 76,  "seq": 12, "actor": "B", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "hit",  "damage": 12, "hp_after": 44}},
		{"tick": 82,  "seq": 13, "actor": "A", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "hit",  "damage": 14, "hp_after": 36}},
		{"tick": 88,  "seq": 14, "actor": "B", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "miss"}},
		{"tick": 96,  "seq": 15, "actor": "A", "kind": "shot",      "payload": {"motif": "buster",   "tier": 3, "travel": 6, "outcome": "hit",  "damage": 20, "hp_after": 16}},
		{"tick": 102, "seq": 16, "actor": "B", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "hit",  "damage": 10, "hp_after": 26}},
		{"tick": 108, "seq": 17, "actor": "A", "kind": "shot",      "payload": {"motif": "beam",     "tier": 2, "travel": 5, "outcome": "hit",  "damage": 8,  "hp_after": 8}},
		{"tick": 118, "seq": 18, "actor": "A", "kind": "shot",      "payload": {"motif": "buster",   "tier": 3, "travel": 6, "outcome": "hit",  "damage": 8,  "lethal": true, "hp_after": 0}},
		{"tick": 118, "seq": 19, "actor": "B", "kind": "destroyed", "payload": {}},
	]

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	var staged: Array = C.stage(truth(), 7, profiles())

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
				# Salvo kinds (burst/missiles) render N projectiles from payload.hits.
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

	var doc := {"schema": "km-director-spike-fight-log-v1", "tick_seconds": 0.1, "events": events}
	var f := FileAccess.open("res://data/grammar_demo.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	print("wrote res://data/grammar_demo.json  (%d events)" % events.size())
	quit()
