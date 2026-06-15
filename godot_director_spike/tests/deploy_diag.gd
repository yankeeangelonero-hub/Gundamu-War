extends SceneTree
## Diagnostic (not a *_check). Replicates a realistic STARTER deploy build headlessly and
## dumps fire density + every movement waypoint, to ground-truth the live symptoms
## (no particles / barely-moves) without rendering.

const Sim := preload("res://scripts/build/build_fight_sim.gd")
const Opp := preload("res://scripts/build/opponent_source.gd")
const Hybrid := preload("res://scripts/directors/hybrid.gd")
const FightLog := preload("res://scripts/fight_log.gd")

func _dump(label: String, placement: Array) -> void:
	var player := Sim.build_from_placement(placement)
	var ghost: Dictionary = Opp.get_ghost(12345)
	var ghost_build := Sim.build_from_placement(ghost.placement)
	var events := Sim.simulate(player, ghost_build, 12345)
	var dur := FightLog.duration_sec(events)
	var fire := {}
	var spawns := {}
	var advances := []
	for e in events:
		if str(e.kind).begins_with("fire"):
			fire[e.kind] = int(fire.get(e.kind, 0)) + 1
		elif e.kind == "spawn":
			spawns[str(e.actor)] = float(e.payload.get("x", 0.0))
		elif e.kind == "advance":
			advances.append("%s->x%.0f,y%.0f@t%d" % [str(e.actor), float(e.payload.get("to_x",0)), float(e.payload.get("to_y",0)), int(e.payload.get("end_tick", e.tick))])
	print("--- %s ---" % label)
	print("  player: weapons=%d pool=%.0f regen=%.0f | ghost: weapons=%d pool=%.0f regen=%.0f" % [player.weapons.size(), player.pool, player.regen, ghost_build.weapons.size(), ghost_build.pool, ghost_build.regen])
	print("  dur=%.1fs events=%d fire=%s spawns=%s" % [dur, events.size(), str(fire), str(spawns)])
	print("  advances(%d): %s" % [advances.size(), ", ".join(advances)])

func _init() -> void:
	_dump("STARTER reactor+rifle", [
		{"def_id": "reactor_core", "rot": 0, "anchor": [0, 0]},
		{"def_id": "beam_rifle", "rot": 0, "anchor": [0, 2]}])
	_dump("STARVED rifle-only (no reactor)", [
		{"def_id": "beam_rifle", "rot": 0, "anchor": [0, 0]}])
	quit()
