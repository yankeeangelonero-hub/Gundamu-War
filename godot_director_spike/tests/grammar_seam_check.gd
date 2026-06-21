extends SceneTree
## Unit test — the choreographer<->director seam (presentation hooks ride with the log).
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "The choreographer <-> director seam" + the contract amendment (four touchpoints).
##
## stage_with_hooks bundles {events, presentation}. The loader IGNORES the presentation root
## key for event/outcome purposes (forward-compatible), while load_presentation surfaces it for
## the director's framing. Driving the runtime camera from the hooks is the separately-gated v2
## cutover, not exercised here.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func profiles() -> Dictionary:
	return {
		"A": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
		"B": {"heft": 0.5, "tempo": 0.5, "mode_mix": {"ranged": 1.0}},
	}

func truth() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 40, "hp_after": 60}},
		{"tick": 30, "seq": 3, "actor": "A", "kind": "shot",      "payload": {"motif": "buster", "tier": 3, "travel": 6, "outcome": "hit", "damage": 60, "lethal": true, "hp_after": 0}},
		{"tick": 30, "seq": 4, "actor": "B", "kind": "destroyed", "payload": {}},
	]

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	var FightLog := load("res://scripts/fight_log.gd")

	# --- stage_with_hooks bundles events + the presentation block, each equal to the standalone
	#     computation (additive; the events are unchanged by bundling).
	var bundle: Dictionary = C.stage_with_hooks(truth(), 7, profiles())
	check(bundle.has("events") and bundle.has("presentation"), "stage_with_hooks returns {events, presentation}")
	check(bundle.events == C.stage(truth(), 7, profiles()), "bundled events == stage() (unchanged)")
	check(bundle.presentation == C.presentation(truth(), 7, profiles()), "bundled presentation == presentation()")

	# --- contract amendment: a doc carrying the presentation root key still loads its events
	#     (the loader ignores unknown roots), and load_presentation surfaces the hooks.
	var doc := {
		"schema": "km-director-spike-fight-log-v1",
		"tick_seconds": 0.1,
		"events": [
			{"tick": 0, "actor": "A", "kind": "spawn", "payload": {"x": -40.0, "z": 0.0, "hp": 100}},
			{"tick": 0, "actor": "B", "kind": "spawn", "payload": {"x": 40.0, "z": 0.0, "hp": 100}},
		],
		"presentation": bundle.presentation,
	}
	var path := "res://tmp/seam_test.json"
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc))
	f.close()

	var loaded: Array = FightLog.load_events(path)
	check(loaded.size() == 2, "loader ignores the presentation root key and loads events normally")
	var pres: Dictionary = FightLog.load_presentation(path)
	check(pres.has("fight") and pres.fight.shape == bundle.presentation.fight.shape,
		"load_presentation surfaces the hook block for the director")
	check(int(pres.fight.lethal_ref.tick) == 30 and int(pres.fight.lethal_ref.seq) == 3,
		"the surfaced hooks carry the lethal_ref")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
