extends SceneTree
## Headless checks for BuildFightSim (KM-M0-SIM §6): determinism, single terminal,
## overload termination, power-starvation, reactor gating, renderer-schema
## compatibility, and the opponent source.

const Sim := preload("res://scripts/build/build_fight_sim.gd")
const Opp := preload("res://scripts/build/opponent_source.gd")
const FightLog := preload("res://scripts/fight_log.gd")
const Hybrid := preload("res://scripts/directors/hybrid.gd")

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

# --- small build factories (hand-crafted resolved-build dicts) ---
func weapon(dmg: float, cost: float, cad: float) -> Dictionary:
	return {"id": "w", "damage": dmg, "cost": cost, "cadence": cad, "mount": "hand_r"}

func build(hp: float, pool: float, regen: float, weapons: Array) -> Dictionary:
	return {"hp": hp, "pool": pool, "regen": regen, "weapons": weapons}

func count_kind(log: Array, kind: String, actor := "") -> int:
	var n := 0
	for e in log:
		if e.kind == kind and (actor == "" or e.actor == actor):
			n += 1
	return n

func has_lethal(log: Array) -> bool:
	for e in log:
		if (e.kind == "fire_beam" or e.kind == "overload") and e.payload.get("lethal", false):
			return true
	return false

func _initialize() -> void:
	_determinism()
	_single_terminal()
	_overload_termination()
	_starvation_bites()
	_reactor_matters()
	_schema_compatible()
	_opponent_source()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

# 1. same inputs → identical log
func _determinism() -> void:
	var a := build(100, 60, 10, [weapon(12, 2, 1.0)])
	var b := build(100, 40, 6, [weapon(8, 3, 1.5)])
	var l1 := Sim.simulate(a, b, 7)
	var l2 := Sim.simulate(a, b, 7)
	check(JSON.stringify(l1) == JSON.stringify(l2), "determinism: identical {builds, seed} → identical log")
	# and via the placement path (ghost resolve)
	var g := Sim.build_from_placement(Opp.get_placement(0))
	var p1 := Sim.simulate(g, g, 1)
	var p2 := Sim.simulate(g, g, 1)
	check(JSON.stringify(p1) == JSON.stringify(p2), "determinism: placement-resolved build is reproducible")

# 2. exactly one destroyed, preceded by a lethal event, and it's terminal
func _single_terminal() -> void:
	var strong := build(100, 999, 999, [weapon(40, 1, 1.0)])
	var weak := build(100, 0, 0, [])
	var log := Sim.simulate(strong, weak, 0)
	check(count_kind(log, "destroyed") == 1, "single terminal: exactly one destroyed (got %d)" % count_kind(log, "destroyed"))
	check(log[-1].kind == "destroyed", "single terminal: destroyed is the last event")
	check(has_lethal(log), "single terminal: a lethal event precedes the destroyed")
	check(log[-1].actor == "B", "single terminal: the out-gunned side (B) is destroyed")

# 3. even durable builds end via the escalating overload past the sudden-death tick
func _overload_termination() -> void:
	var durable := build(100, 50, 5, [weapon(5, 1, 4.0)])   # ~55 dmg over 45s < 100 hp
	var log := Sim.simulate(durable, durable, 0)
	check(count_kind(log, "destroyed") == 1, "overload: exactly one destroyed")
	var killer: Dictionary = log[log.size() - 2]   # the lethal event just before destroyed
	check(killer.kind == "overload" and killer.payload.lethal, "overload: the killing blow is a lethal overload")
	check(int(killer.tick) >= Sim.SUDDEN_DEATH_TICK, "overload: kill happens at/after the sudden-death tick (got %d)" % int(killer.tick))
	check(log.size() < 100000, "overload: fight terminates within the tick budget")

# 4. a power-starved build fires fewer shots than the same build with unlimited power
func _starvation_bites() -> void:
	var guns := [weapon(20, 20, 1.0), weapon(20, 20, 1.0), weapon(20, 20, 1.0), weapon(20, 20, 1.0)]
	var bag := build(1000000, 0, 0, [])   # a punching bag that won't die in the window
	var starved := Sim.simulate(build(100, 20, 5, guns.duplicate(true)), bag, 0)
	var fed := Sim.simulate(build(100, 999999, 999999, guns.duplicate(true)), bag, 0)
	var starved_shots := count_kind(starved, "fire_beam", "A")
	var fed_shots := count_kind(fed, "fire_beam", "A")
	check(starved_shots < fed_shots, "starvation: starved build fires fewer shots (%d) than fed (%d)" % [starved_shots, fed_shots])
	check(starved_shots > 0, "starvation: a small reactor still fires some shots")

# 5. no reactor → no fire; a reactor → fire
func _reactor_matters() -> void:
	var bag := build(1000000, 0, 0, [])
	var dead := Sim.simulate(build(100, 0, 0, [weapon(10, 5, 1.0)]), bag, 0)
	var alive := Sim.simulate(build(100, 50, 10, [weapon(10, 5, 1.0)]), bag, 0)
	check(count_kind(dead, "fire_beam", "A") == 0, "reactor: zero pool/regen fires nothing")
	check(count_kind(alive, "fire_beam", "A") > 0, "reactor: a reactor lets weapons fire")

# 6. a sim log is consumable by the existing renderer contract
func _schema_compatible() -> void:
	var strong := build(100, 60, 10, [weapon(12, 2, 1.0)])
	var weak := build(100, 30, 3, [weapon(3, 1, 2.0)])
	var log := Sim.simulate(strong, weak, 0)
	check(not has_overload(log), "schema: decisive fight ends by weapon kill (no overload)")
	var dur: float = FightLog.duration_sec(log)
	check(dur > 0.0, "schema: FightLog.duration_sec returns a positive duration (%.1fs)" % dur)
	var shots: Array = Hybrid.build_shot_list(log, dur)
	check(shots.size() >= 1, "schema: Hybrid.build_shot_list accepts a sim log and returns shots (%d)" % shots.size())

func has_overload(log: Array) -> bool:
	for e in log:
		if e.kind == "overload":
			return true
	return false

# 7. opponent source serves distinct, sim-runnable ghost builds
func _opponent_source() -> void:
	check(Opp.count() >= 2, "opponent: pool has at least two ghosts (got %d)" % Opp.count())
	var g0 := Opp.get_ghost(0)
	var g1 := Opp.get_ghost(1)
	check(g0.has("placement") and g0.has("name"), "opponent: ghost carries a placement + name")
	check(JSON.stringify(g0.placement) != JSON.stringify(g1.placement), "opponent: different picks give different builds")
	var ba := Sim.build_from_placement(Opp.get_placement(0))
	var bb := Sim.build_from_placement(Opp.get_placement(1))
	var log := Sim.simulate(ba, bb, 3)
	check(count_kind(log, "destroyed") == 1, "opponent: ghost-vs-ghost runs to exactly one terminal")
