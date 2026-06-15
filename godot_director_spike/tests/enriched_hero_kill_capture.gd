extends SceneTree
## Standalone hero-kill money-shot capture.
##
## Plays the enriched sim log through the hybrid director in a fresh fight scene,
## waits until just after the lethal hero_kill bullet-time peak, and captures the
## whiteout frame. Does NOT use the build_screen→deploy→return flow, so the
## fight_over handler simply quits instead of switching to the build screen.
##
## Run WITHOUT --headless (needs GPU rendering):
##   godot --path godot_director_spike -s res://tests/enriched_hero_kill_capture.gd
##
## Timing maths (seed 7, enriched builds):
##   Fight duration:   9.8s fight-time
##   Hero kill tick:   48 → 4.8s fight-time
##   Bullet_time t0:   4.6s fight-time (BT_PRE = 0.2s before kill)
##   BT time_scale:    0.05
##   Kill lands at:    0.2s into BT window → 0.2 / 0.05 = 4.0s wall-clock into BT
##   BT wall-clock start from fight start: 4.6s (normal speed)
##   Wall-clock to whiteout from fight start: 4.6 + 4.0 = 8.6s
##   Scene load estimate: ~1.5s
##   Total timer from change_scene: 10.5s  (8.6 + 1.5 + 0.4s safety margin)
##   Second capture (mid-orbit): 10.5 + 4.0 = 14.5s

const Sim    := preload("res://scripts/build/build_fight_sim.gd")
const Handoff := preload("res://scripts/build/fight_handoff.gd")

func _initialize() -> void:
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
	print("enriched_hero_kill_capture: events=%d" % events.size())

	# Use FightHandoff to pass events, but clear .active before fight_over fires
	# so main.gd takes the quit path (not the return-to-build-screen path).
	Handoff.player_placement = []
	Handoff.ghost_placement  = []
	Handoff.set_fight(events, "ALPHA", "BRAVO")
	Handoff.director_name = "hybrid"

	# Schedule Handoff.active = false just before the fight ends (fight is 9.8s fight-time;
	# at BT scale 0.05 the tail after kill lasts ~8s wall-clock; total fight wall-clock
	# from start is ~4.6 + (5.4-4.6)/0.05 = 4.6 + 16 = 20.6s from fight start.
	# We clear active at 18s so main.gd can quit normally after we've already captured.)
	DirAccess.make_dir_recursive_absolute("res://tmp")
	change_scene_to_file("res://scenes/main.tscn")

	# Wait for the hero_kill whiteout peak.
	# When FightHandoff.active=true, main.gd runs a 3.2s intro before fight starts.
	# Scene loads ~1.5s; intro 3.2s; then fight normal-speed to BT start at 4.6s fight-time;
	# the lethal beam fires 0.2s into BT (fight-time), which is 0.2/0.05 = 4.0s wall-clock into BT.
	# Total from change_scene: 1.5 + 3.2 + 4.6 + 4.0 = 13.3s. Use 13.5s to be safe.
	await create_timer(13.5).timeout
	_capture("enriched_hero_kill_money")

	# Clear FightHandoff.active now so fight_over → quit (not build screen return).
	# The fight at 0.05x scale still has ~(9.4-4.6)/0.05 + (9.8-5.4)/0.1 = more time left;
	# we just captured — now force an immediate quit.
	Handoff.active = false

	print("enriched_hero_kill_capture: done — see res://tmp/enriched_hero_kill_money.png")
	await create_timer(0.5).timeout
	quit(0)

func _capture(name: String) -> void:
	var img := get_root().get_texture().get_image()
	var path := "res://tmp/%s.png" % name
	img.save_png(path)
	print("saved %s" % path)
