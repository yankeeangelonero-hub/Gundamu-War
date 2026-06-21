extends SceneTree
## Throwaway visualization harness (not a gate): stage a fixture and print the movement trace
## as CSV so the staged motion can be plotted. Rows: tick,actor,x,z,dist_to_enemy,speed.

func profiles() -> Dictionary:
	return {
		"A": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
	}

func truth_log() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 30, "hp_after": 70}},
		{"tick": 20, "seq": 3, "actor": "B", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 30, "hp_after": 70}},
		{"tick": 30, "seq": 4, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 35, "hp_after": 35}},
		{"tick": 38, "seq": 5, "actor": "B", "kind": "shot",      "payload": {"motif": "burst", "tier": 2, "travel": 4, "outcome": "miss"}},
		{"tick": 44, "seq": 6, "actor": "A", "kind": "shot",      "payload": {"motif": "buster", "tier": 3, "travel": 6, "outcome": "hit", "damage": 40, "lethal": true, "hp_after": 0}},
		{"tick": 44, "seq": 7, "actor": "B", "kind": "destroyed", "payload": {}},
	]

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	var staged: Array = C.stage(truth_log(), 7, profiles())
	print("CSV_BEGIN")
	for row in C.movement_trace(staged):
		print("%d,%s,%f,%f,%f,%f" % [int(row.tick), row.actor, float(row.x), float(row.z), float(row.dist_to_enemy), float(row.speed)])
	print("CSV_END")
	quit()
