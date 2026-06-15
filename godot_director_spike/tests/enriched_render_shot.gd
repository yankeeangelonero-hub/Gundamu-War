extends SceneTree
## Windowed render runner — exercises the enriched sim renderer.
##
## Simulates a fresh log from BuildFightSim using a hand-crafted build that includes
## a swarm (missiles fx) weapon alongside a beam, so every new code path is reached:
##   - to_y pop-up bursts (advance events with to_y > 0)
##   - fire_swarm Itano-circus arcs
##   - evade:true and pursue:true advances (dodge-pursuit run, ticks 100-133)
##   - hero_kill yield framing (whiteout + oversized beam + structural collateral)
##
## Captures PNGs to res://tmp/ at seven story moments. Run WITHOUT --headless.
##   godot --path godot_director_spike -s res://tests/enriched_render_shot.gd
##
## Captured frames:
##   tmp/enriched_popup_burst.png        — Phase 1 pop-up hop (t~2.5s)
##   tmp/enriched_swarm_volley.png       — fire_swarm volley in flight (t~4s)
##   tmp/enriched_hero_cut_nonbeam.png   — hero cut on non-beam fire event (t~5s)
##   tmp/enriched_dodge_pursuit.png      — dodge-pursuit weave (t~11s)
##   tmp/enriched_chase_pursuit.png      — chase_pursuit tracking shot (t~12s)
##   tmp/enriched_hero_kill.png          — hero_kill whiteout + yield framing (end)
##   tmp/enriched_hero_kill_arc.png      — hero_kill wider arc mid-orbit (t+0.5s)

const Sim := preload("res://scripts/build/build_fight_sim.gd")
const Handoff := preload("res://scripts/build/fight_handoff.gd")

func _initialize() -> void:
	# Hand-craft resolved builds: both have a swarm weapon so fire_swarm events appear
	# early and the lethal blow can be a swarm (giving us a hero_kill on fire_swarm).
	# Build A: high DPS swarm + beam — wins fast and is the presser (pop-up in Phase 1).
	# Build B: single beam — lower DPS, retreater in Phase 1, evades in Phase 2.
	var w_swarm_a := {
		"id": "s1", "damage": 18.0, "cost": 3.0, "cadence": 1.8,
		"mount": "shoulder_r", "fx": "missiles"
	}
	var w_beam_a := {
		"id": "b1", "damage": 10.0, "cost": 2.0, "cadence": 1.2,
		"mount": "hand_r", "fx": "beam"
	}
	var build_a := {
		"hp": 100.0, "pool": 80.0, "regen": 14.0,
		"weapons": [w_swarm_a, w_beam_a]
	}
	var w_beam_b := {
		"id": "b2", "damage": 7.0, "cost": 2.0, "cadence": 1.5,
		"mount": "hand_r", "fx": "beam"
	}
	var build_b := {
		"hp": 100.0, "pool": 50.0, "regen": 8.0,
		"weapons": [w_beam_b]
	}

	var events := Sim.simulate(build_a, build_b, 7)

	# Verify the log exercises the new events before rendering.
	var has_popup := false
	var has_swarm := false
	var has_evade := false
	var has_pursue := false
	var has_hero_kill := false
	for e in events:
		if e.kind == "advance" and e.payload.get("to_y", 0.0) > 0.0:
			has_popup = true
		if e.kind == "fire_swarm":
			has_swarm = true
		if e.kind == "advance" and e.payload.get("evade", false):
			has_evade = true
		if e.kind == "advance" and e.payload.get("pursue", false):
			has_pursue = true
		if e.payload.get("hero_kill", false):
			has_hero_kill = true
	print("enriched log check — popup:%s swarm:%s evade:%s pursue:%s hero_kill:%s events:%d" % [
		has_popup, has_swarm, has_evade, has_pursue, has_hero_kill, events.size()])

	# Wire up the fight through the standard handoff path.
	Handoff.player_placement = []    # no placement; we used a resolved build directly
	Handoff.ghost_placement  = []
	Handoff.set_fight(events, "ALPHA", "BRAVO")
	Handoff.director_name = "hybrid"

	change_scene_to_file("res://scenes/main.tscn")
	DirAccess.make_dir_recursive_absolute("res://tmp")

	# Frame 1 — Phase 1 pop-up burst: hop emitted at tick 20 (~t=2.0s).
	await create_timer(2.5).timeout
	_capture("enriched_popup_burst")

	# Frame 2 — swarm volley in flight (~t=4s).
	await create_timer(1.5).timeout
	_capture("enriched_swarm_volley")

	# Frame 2b — hero cut on NON-beam fire event: the hybrid director fires a hero_cut
	# on the mid-fight swarm/burst volley. By ~5s wall-clock we are past the hero_os
	# window and into the first mid-fight hero_cut triggered by a fire_swarm or fire_burst.
	await create_timer(1.0).timeout
	_capture("enriched_hero_cut_nonbeam")

	# Frame 3 — dodge-pursuit weave (~t=11s wall-clock total).
	await create_timer(6.0).timeout
	_capture("enriched_dodge_pursuit")

	# Frame 3b — chase_pursuit tracking shot: 1s into the weave window, the hybrid
	# director is in chase_pursuit mode. Capture the wide tracking angle.
	await create_timer(1.0).timeout
	_capture("enriched_chase_pursuit")

	# Frame 4 — hero_kill escalated bullet-time orbit: capture mid-arc before it exits.
	await create_timer(11.0).timeout
	_capture("enriched_hero_kill")

	# Frame 4b — hero_kill orbit completion: 0.5s later, the wider arc is still live
	# (hero_kill window is 0.6s realtime vs 0.35s standard).
	await create_timer(0.5).timeout
	_capture("enriched_hero_kill_arc")

	print("enriched_render_shot: all frames captured — see res://tmp/")
	quit(0)

func _capture(name: String) -> void:
	var img := get_root().get_texture().get_image()
	var path := "res://tmp/%s.png" % name
	img.save_png(path)
	print("saved %s" % path)
