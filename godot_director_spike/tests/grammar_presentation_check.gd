extends SceneTree
## Unit test — Layer 4 dramaturgy: the suspense plan + the root `presentation` hook block.
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "The choreographer ↔ director seam — structural facts in a root `presentation` block".
##
## presentation(truth, seed, feel_profiles) returns the side-channel hook block (it rides as a
## side file, not in the event log, until the contract amendment ratifies it). Per-beat hooks
## bind by truth_ref; the fight block carries shape/template, phrase_bounds, apparent_initiative
## (quantized to Q), climax_window, and lethal_ref. The hard CG-NO-PRESPOIL gate never reads
## this block; the advisory check is climax_window.start >= reveal(truth_dom).

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

# A duel A wins with a lethal buster at tick 44 (seq 5); B lands one hit (a contest).
func truth_log() -> Array:
	return [
		{"tick": 0,  "seq": 0, "actor": "A", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 0,  "seq": 1, "actor": "B", "kind": "spawn",     "payload": {"hp": 100}},
		{"tick": 12, "seq": 2, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 30, "hp_after": 70}},
		{"tick": 20, "seq": 3, "actor": "B", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 30, "hp_after": 70}},
		{"tick": 30, "seq": 4, "actor": "A", "kind": "shot",      "payload": {"motif": "beam", "tier": 2, "travel": 5, "outcome": "hit", "damage": 35, "hp_after": 35}},
		{"tick": 44, "seq": 5, "actor": "A", "kind": "shot",      "payload": {"motif": "buster", "tier": 3, "travel": 6, "outcome": "hit", "damage": 40, "lethal": true, "hp_after": 0}},
		{"tick": 44, "seq": 6, "actor": "B", "kind": "destroyed", "payload": {}},
	]

func _init() -> void:
	var C := load("res://scripts/sim/choreographer.gd")
	var GM := load("res://scripts/sim/grammar_metrics.gd")
	check(C != null and GM != null, "modules load")
	if C == null:
		print("---- %d FAIL" % maxi(fails, 1))
		quit(1)
		return

	var truth := truth_log()
	var pres: Dictionary = C.presentation(truth, 7, profiles())
	check(pres.has("beats") and pres.has("fight"), "presentation() returns {beats, fight}")

	# --- per-beat hooks bind by truth_ref and carry the structural facts.
	var beats: Array = pres.beats
	check(beats.size() >= 1, "at least one beat hook")
	var b0: Dictionary = beats[0]
	check(b0.has("truth_ref") and b0.truth_ref.has("tick") and b0.truth_ref.has("seq"),
		"a beat hook binds by truth_ref {tick, seq}")
	check(b0.exchange_mode == "beam-trade", "beat hook exchange_mode is beam-trade")
	check(b0.range_band == "mid", "beam-trade beat hook range_band is mid")
	check(b0.has("is_background") and b0.has("reaction_background") and b0.has("is_impact"),
		"beat hook carries is_background / reaction_background / is_impact")

	# --- fight block: shape + template, phrase_bounds, climax_window, lethal_ref.
	var fight: Dictionary = pres.fight
	check(fight.shape in ["instant", "reversal", "stalemate", "stomp", "photofinish", "grind"],
		"fight.shape is a valid classifier shape (got '%s')" % fight.get("shape", ""))
	var templates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/grammar_templates.json"))
	check(fight.template_id == templates.get(fight.shape, ""),
		"fight.template_id maps the shape via grammar_templates.json")

	# lethal_ref binds to the kill's truth beat.
	check(fight.lethal_ref == {"tick": 44, "seq": 5}, "fight.lethal_ref is the lethal shot {44, 5}")

	# --- climax_window: a tick span; advisory invariant start >= reveal(truth_dom).
	var spawn_hp := {"A": 100.0, "B": 100.0}
	var td: Array = GM.truth_dom(truth, spawn_hp)
	var rev: int = GM.reveal(td)
	var cw: Array = fight.climax_window
	check(cw.size() == 2 and int(cw[0]) <= int(cw[1]), "climax_window is a [t0,t1] span")
	check(int(cw[0]) >= rev, "climax_window.start >= reveal(truth_dom) (advisory: no early climax claim)")

	# --- apparent_initiative: sorted unique ticks, lead quantized to Q and finite.
	var ai: Array = fight.apparent_initiative
	check(ai.size() >= 1, "apparent_initiative has samples")
	var ai_ok := true
	var prev_tick := -1
	var q: float = C._P.Q
	for s in ai:
		if int(s.tick) <= prev_tick:
			ai_ok = false
		prev_tick = int(s.tick)
		var lead := float(s.lead)
		if not is_finite(lead):
			ai_ok = false
		if absf(lead / q - round(lead / q)) > 1e-6:
			ai_ok = false
	check(ai_ok, "apparent_initiative: ticks sorted+unique, leads finite and quantized to Q")

	# --- phrase_bounds: non-empty list of [t0,t1] spans.
	var pb: Array = fight.phrase_bounds
	var pb_ok := pb.size() >= 1
	for span in pb:
		if span.size() != 2 or int(span[0]) > int(span[1]):
			pb_ok = false
	check(pb_ok, "phrase_bounds is a non-empty list of [t0,t1] spans")

	# --- determinism.
	check(C.presentation(truth, 7, profiles()) == pres, "presentation() is pure/deterministic")

	if fails == 0:
		print("---- ALL PASS")
	else:
		print("---- %d FAIL" % fails)
	quit(1 if fails > 0 else 0)
