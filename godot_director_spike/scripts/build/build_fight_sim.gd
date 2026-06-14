extends RefCounted
## BuildFightSim — the deterministic M0 build→fight core (KM-M0-SIM).
##
## Pure: a function of (resolved buildA, resolved buildB, seed) → event log, in the
## existing km-director-spike-fight-log-v1 schema plus the additive `overload` kind.
## No node tree, no RNG that matters, no wall-clock. Same inputs → identical log.
## See docs/.../2026-06-14-km-m0-sim-feature-spec.md.

const BuildResolver := preload("build_resolver.gd")
const BuildMounts := preload("build_mounts.gd")
const BuildData := preload("build_data.gd")

const TICK_SECONDS := 0.1
const BASE_HP := 100.0
const SUDDEN_DEATH_TICK := 450      # 45 s
const OVERLOAD_BASE := 1.0
const OVERLOAD_GROWTH := 1.12       # per tick after sudden death
const MAX_TICKS := 3000             # safety backstop; overload must end the fight first

const SPAWN_X := {"A": -40.0, "B": 40.0}
const ENEMY := {"A": "B", "B": "A"}

## Turn a placement (array of {def_id, rot, anchor}) into the resolved-build input
## shape the sim consumes. Used by the opponent source now and the build screen later.
## Accepts anchors as Vector2i or [row, col]; assigns iids if missing.
static func build_from_placement(raw_placed: Array, base_hp := BASE_HP) -> Dictionary:
	var placed: Array = []
	var i := 0
	for r in raw_placed:
		i += 1
		var anc: Variant = r.get("anchor", Vector2i.ZERO)
		if anc is Array:
			anc = Vector2i(int(anc[0]), int(anc[1]))
		placed.append({
			"iid": r.get("iid", "g%d" % i),
			"def_id": r.def_id,
			"rot": int(r.get("rot", 0)),
			"anchor": anc,
		})
	var res := BuildResolver.resolve(placed)
	var mounts := BuildMounts.assign(placed)
	var weapons: Array = []
	for p in placed:
		var def := BuildData.get_def(p.def_id)
		if def.get("kind", "") != "spender":
			continue
		var e: Dictionary = res.weapons.get(p.iid, {})
		weapons.append({
			"id": p.iid,
			"damage": float(e.get("damage", def.get("base_damage", 0))),
			"cost": float(e.get("cost", def.get("base_power_cost", 0))),
			"cadence": float(def.get("cadence", 1.0)),
			"mount": mounts.mounts.get(p.iid, ""),
			"fx": def.get("fx", "beam"),
		})
	return {
		"hp": base_hp,
		"pool": float(res.totals.pool),
		"regen": float(res.totals.regen),
		"weapons": weapons,
	}

static func simulate(build_a: Dictionary, build_b: Dictionary, _seed: int = 0) -> Array:
	var log: Array = []
	var sides := {"A": _init_side(build_a), "B": _init_side(build_b)}

	for s in ["A", "B"]:
		log.append({"tick": 0, "actor": s, "kind": "spawn",
			"payload": {"x": SPAWN_X[s], "hp": sides[s].hp}})
	# cosmetic approach so the mechs aren't frozen (presentation scaffolding, no combat meaning)
	log.append({"tick": 2, "actor": "A", "kind": "advance", "payload": {"to_x": -18.0, "end_tick": 15}})
	log.append({"tick": 2, "actor": "B", "kind": "advance", "payload": {"to_x": 18.0, "end_tick": 15}})

	var tick := 0
	while tick < MAX_TICKS:
		# regen first, for both sides
		for s in ["A", "B"]:
			var side: Dictionary = sides[s]
			side.power = minf(side.pool, side.power + side.regen * TICK_SECONDS)
		# weapon fire, in fixed actor order (A acts first → wins simultaneous exchanges)
		for s in ["A", "B"]:
			var side: Dictionary = sides[s]
			var foe: Dictionary = sides[ENEMY[s]]
			for w in side.weapons:
				if tick < w.next_fire_tick:
					continue
				if side.power < w.cost:
					continue   # power-starved: weapon stays due, idles, retries next tick
				side.power -= w.cost
				foe.hp -= w.damage
				var lethal: bool = foe.hp <= 0.0
				log.append(_fire_event(tick, s, w, foe.hp, lethal))
				w.next_fire_tick = tick + int(round(w.cadence / TICK_SECONDS))
				if lethal:
					log.append({"tick": tick, "actor": ENEMY[s], "kind": "destroyed", "payload": {}})
					return log
		# sudden death: escalating overload on both, after the time limit
		if tick >= SUDDEN_DEATH_TICK:
			var dot: float = OVERLOAD_BASE * pow(OVERLOAD_GROWTH, tick - SUDDEN_DEATH_TICK)
			sides["A"].hp -= dot
			sides["B"].hp -= dot
			var loser := _overload_loser(sides)
			for s in ["A", "B"]:
				log.append({"tick": tick, "actor": s, "kind": "overload", "payload": {
					"damage": dot, "hp_after": maxf(0.0, sides[s].hp), "lethal": s == loser}})
			if loser != "":
				log.append({"tick": tick, "actor": loser, "kind": "destroyed", "payload": {}})
				return log
		tick += 1

	push_warning("BuildFightSim hit MAX_TICKS without a terminal event")
	return log

## Build the right event for a weapon's FX kind. Damage is already applied; this is
## pure presentation routing (the sim outcome is identical regardless of fx). Every
## kind carries `mount` (so the beam/burst/salvo fires from that weapon) and `lethal`
## (so the kill-cam fires on whichever weapon lands the killing blow).
static func _fire_event(tick: int, actor: String, w: Dictionary, foe_hp: float, lethal: bool) -> Dictionary:
	var payload := {
		"damage": w.damage, "hp_after": maxf(0.0, foe_hp), "lethal": lethal, "mount": w.mount,
	}
	var kind := "fire_beam"
	match w.fx:
		"burst":
			kind = "fire_burst"
			payload["rounds"] = 6
			payload["hits"] = 6
		"missiles":
			kind = "fire_missiles"
			payload["count"] = 8
			payload["hits"] = 8
		"buster":
			kind = "fire_buster"
			payload["hit"] = true
		_:
			kind = "fire_beam"
			payload["hit"] = true
			payload["overkill"] = maxf(0.0, -foe_hp)
	return {"tick": tick, "actor": actor, "kind": kind, "payload": payload}

static func _init_side(b: Dictionary) -> Dictionary:
	var weapons: Array = []
	for w in b.get("weapons", []):
		weapons.append({
			"id": w.get("id", ""), "damage": float(w.damage), "cost": float(w.cost),
			"cadence": float(w.cadence), "mount": w.get("mount", ""),
			"fx": w.get("fx", "beam"), "next_fire_tick": 0})
	var pool := float(b.get("pool", 0.0))
	return {"hp": float(b.get("hp", BASE_HP)), "pool": pool, "regen": float(b.get("regen", 0.0)),
		"power": pool, "weapons": weapons}

## Who dies this overload tick. Both-dead ties go to the lower (more negative) hp;
## an exact tie favours A (the player) — B is the loser, mirroring the A-first
## weapon tie-break.
static func _overload_loser(sides: Dictionary) -> String:
	var a_dead: bool = sides["A"].hp <= 0.0
	var b_dead: bool = sides["B"].hp <= 0.0
	if a_dead and b_dead:
		return "A" if sides["A"].hp < sides["B"].hp else "B"
	if a_dead:
		return "A"
	if b_dead:
		return "B"
	return ""
