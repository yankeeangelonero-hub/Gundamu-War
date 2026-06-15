extends SceneTree
## Headless probe: print fight timing so we can compute precise capture times.
## godot --headless --path godot_director_spike -s res://tests/enriched_timing_probe.gd

const Sim    := preload("res://scripts/build/build_fight_sim.gd")
const Hybrid := preload("res://scripts/directors/hybrid.gd")
const FightLog := preload("res://scripts/fight_log.gd")

const TICK := 0.1

func _initialize() -> void:
	var w_swarm_a := {"id": "s1", "damage": 18.0, "cost": 3.0, "cadence": 1.8,
		"mount": "shoulder_r", "fx": "missiles"}
	var w_beam_a := {"id": "b1", "damage": 10.0, "cost": 2.0, "cadence": 1.2,
		"mount": "hand_r", "fx": "beam"}
	var build_a := {"hp": 100.0, "pool": 80.0, "regen": 14.0, "weapons": [w_swarm_a, w_beam_a]}
	var w_beam_b := {"id": "b2", "damage": 7.0, "cost": 2.0, "cadence": 1.5,
		"mount": "hand_r", "fx": "beam"}
	var build_b := {"hp": 100.0, "pool": 50.0, "regen": 8.0, "weapons": [w_beam_b]}

	var events := Sim.simulate(build_a, build_b, 7)
	var dur := FightLog.duration_sec(events)
	var shots := Hybrid.build_shot_list(events, dur)

	print("FIGHT_DUR=%.3f" % dur)
	print("EVENT_COUNT=%d" % events.size())

	for e in events:
		var t := float(e.tick) * TICK
		if e.payload.get("hero_kill", false):
			print("HERO_KILL_TICK=%d HERO_KILL_T=%.3f KIND=%s" % [int(e.tick), t, e.kind])
		if e.payload.get("lethal", false):
			print("LETHAL_TICK=%d LETHAL_T=%.3f KIND=%s" % [int(e.tick), t, e.kind])

	for s in shots:
		if s.mode == "bullet_time":
			print("BT_T0=%.3f BT_T1=%.3f BT_SCALE=%.4f BT_HERO_KILL=%s" % [
				float(s.t0), float(s.t1), float(s.time_scale), str(s.get("hero_kill", false))])
			# Wall-clock duration of the bullet_time window (dilated):
			var wall_dur := (float(s.t1) - float(s.t0)) / float(s.time_scale)
			print("BT_WALL_DUR=%.3f" % wall_dur)

	# Print first few events for context
	for i in min(5, events.size()):
		print("EVENT[%d] tick=%d kind=%s" % [i, int(events[i].tick), events[i].kind])

	quit(0)
