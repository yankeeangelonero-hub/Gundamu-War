extends RefCounted
## BuildFightSim — the deterministic M0 build→fight core (KM-M0-SIM).
##
## Pure: a function of (resolved buildA, resolved buildB, seed) → event log, in the
## existing km-director-spike-fight-log-v1 schema plus extensions documented in
## event-contract.md. No node tree, no wall-clock, no unseeded RNG.
## Same inputs → byte-identical log (BEH-D01).
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

# Choreography zone constants (X magnitude; sign applied per side).
# A spawns at -40 (negative X), B at +40 (positive X).
# CLOSE = toe-to-toe slug-fest; MID = stand-off exchange; BACK = retreat/evade
const _ZONE_CLOSE := 8.0
const _ZONE_MID   := 18.0
const _ZONE_BACK  := 30.0
const _POP_Y      := 6.0   # low hop height for grounded burst; returns to 0 after each hop

# Z-depth weave offsets (lateral/depth flanking). Arena safe range ≈ ±43.
# Using a fixed table keyed by a small index to keep the choreography deterministic
# without a seeded call per waypoint.
const _Z_OFFSETS := [7.0, -9.0, 17.0, -13.0, 23.0, -6.0, -21.0, 12.0,
					  -24.0, 10.0, -5.0, 19.0, -15.0, 3.0, -11.0, 25.0]

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

	# --- spawn ---
	for s in ["A", "B"]:
		log.append({"tick": 0, "actor": s, "kind": "spawn",
			"payload": {"x": SPAWN_X[s], "hp": sides[s].hp}})

	# --- repositioning choreography (pure waypoint data; does not affect combat) ---
	_emit_choreography(log, sides, _seed)

	# --- combat loop ---
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

# ---------------------------------------------------------------------------
# Choreography — deterministic waypoint sequence.
#
# Emits advance events (including evade/pursue variants) to tell the renderer
# where mechs are during each phase of the fight. Has zero effect on who wins
# or HP totals — the combat loop ignores these events entirely.
#
# Dramatic arc:
#   Phase 1 OPEN    (tick  2..59)  — presser rushes in; retreater holds then counters
#   Phase 2 REVERSAL (tick 60..144) — retreater becomes aggressor; dodge-pursuit run
#   Phase 3 CLIMAX  (tick 145+)   — both close in for slug-fest + optional pop-up
#
# "presser" = side with higher DPS (dominates opener).
# All variation keyed on _seed via _seeded_int(); no global RNG state touched.
# ---------------------------------------------------------------------------

static func _emit_choreography(log: Array, sides: Dictionary, seed_val: int) -> void:
	# Assign presser/retreater by DPS so the higher-damage side drives the narrative.
	var dmg_a := _total_dps(sides["A"])
	var dmg_b := _total_dps(sides["B"])
	var presser: String   = "A" if dmg_a >= dmg_b else "B"
	var retreater: String = ENEMY[presser]

	# _z picks a depth offset from the pre-baked table, mixed with seed and a waypoint
	# index so every waypoint gets a distinct, reproducible z.  Both actors use the same
	# table but with different index strides so their paths diverge (circle/flank).
	# The index wraps; values stay within ±43 (arena safe zone).
	var zi := _seeded_int(seed_val, 7, _Z_OFFSETS.size())   # starting position in table

	# Phase 1 — OPEN: presser rushes mid (flanking left/right), retreater holds deep.
	# Both actors get independent z paths from the start.
	var z0p: float = _Z_OFFSETS[zi % _Z_OFFSETS.size()]
	var z0r: float = _Z_OFFSETS[(zi + 5) % _Z_OFFSETS.size()]
	_adv(log, 2,  presser,   _sx(presser)   * _ZONE_MID,  0.0, 15, z0p)
	_adv(log, 2,  retreater, _sx(retreater) * _ZONE_BACK, 0.0, 20, z0r)

	# presser pops up (hop burst toward enemy) while orbiting to a new z angle
	var z1p: float = _Z_OFFSETS[(zi + 2) % _Z_OFFSETS.size()]
	_adv(log, 20, presser, _sx(presser) * _ZONE_CLOSE, _POP_Y, 30, z1p)
	# presser drops back to ground — still at the same close x, shifted z
	_adv(log, 31, presser, _sx(presser) * _ZONE_CLOSE, 0.0, 38, z1p)
	# retreater reads the hop and dashes to mid, flanking the other direction
	var z1r: float = _Z_OFFSETS[(zi + 8) % _Z_OFFSETS.size()]
	_adv(log, 35, retreater, _sx(retreater) * _ZONE_MID, 0.0, 50, z1r)

	# Phase 2 — REVERSAL: retreater pushes to close from its flank angle; presser falls back.
	var z2r: float = _Z_OFFSETS[(zi + 11) % _Z_OFFSETS.size()]
	var z2p: float = _Z_OFFSETS[(zi + 4) % _Z_OFFSETS.size()]
	_adv(log, 60, retreater, _sx(retreater) * _ZONE_CLOSE, 0.0, 75, z2r)
	_adv(log, 65, presser,   _sx(presser)   * _ZONE_MID,  0.0, 80, z2p)
	# retreater (now aggressor) pops up — dominance display, same flank angle
	_adv(log, 80, retreater, _sx(retreater) * _ZONE_CLOSE, _POP_Y, 90, z2r)
	_adv(log, 91, retreater, _sx(retreater) * _ZONE_CLOSE, 0.0, 97, z2r)

	# Dodge-pursuit run (tick 100..133):
	#   evader  = presser  (falling back, weaving through fire — big z swings)
	#   pursuer = retreater (the current aggressor, closing in — tracking the evader)
	# Evader micro-dashes carry evade:true; pursuer advances carry pursue:true.
	var ze0: float = _Z_OFFSETS[(zi + 6) % _Z_OFFSETS.size()]
	var ze1: float = _Z_OFFSETS[(zi + 13) % _Z_OFFSETS.size()]
	var ze2: float = _Z_OFFSETS[(zi + 1) % _Z_OFFSETS.size()]
	var zp0: float = _Z_OFFSETS[(zi + 9) % _Z_OFFSETS.size()]
	var zp1: float = _Z_OFFSETS[(zi + 3) % _Z_OFFSETS.size()]
	_evade(log, 100, presser, _sx(presser) * _ZONE_MID,          0.0,          108, ze0)
	_evade(log, 109, presser, _sx(presser) * _ZONE_BACK,         0.0,          117, ze1)
	_evade(log, 118, presser, _sx(presser) * _ZONE_MID,          _POP_Y * 0.5, 126, ze2)
	_evade(log, 127, presser, _sx(presser) * _ZONE_MID,          0.0,          133, ze0)
	_pursue(log, 102, retreater, _sx(retreater) * _ZONE_CLOSE,   0.0,          112, zp0)
	_pursue(log, 115, retreater, _sx(retreater) * _ZONE_MID,     0.0,          125, zp1)

	# Phase 3 — CLIMAX: both reset to mid with independent z angles, then converge to close.
	var z3a: float = _Z_OFFSETS[(zi + 7) % _Z_OFFSETS.size()]
	var z3b: float = _Z_OFFSETS[(zi + 12) % _Z_OFFSETS.size()]
	_adv(log, 145, "A", _sx("A") * _ZONE_MID,   0.0, 160, z3a)
	_adv(log, 145, "B", _sx("B") * _ZONE_MID,   0.0, 160, z3b)
	# Close in for the slug-fest, both pulling toward z=0 (face-to-face)
	var z4a: float = z3a * 0.4
	var z4b: float = z3b * 0.4
	_adv(log, 165, "A", _sx("A") * _ZONE_CLOSE, 0.0, 178, z4a)
	_adv(log, 165, "B", _sx("B") * _ZONE_CLOSE, 0.0, 178, z4b)

	# One side gets a final climax pop-up; which side is seeded.
	var pop_side := "A" if _seeded_int(seed_val, 99, 2) == 0 else "B"
	var zpop: float = _Z_OFFSETS[(zi + 10) % _Z_OFFSETS.size()] * 0.5
	_adv(log, 182, pop_side, _sx(pop_side) * _ZONE_CLOSE, _POP_Y, 192, zpop)
	_adv(log, 193, pop_side, _sx(pop_side) * _ZONE_CLOSE, 0.0,    200, zpop)

# ---------------------------------------------------------------------------
# Choreography helpers
# ---------------------------------------------------------------------------

# Sign giving the correct X direction for a side's home territory.
# A is negative-X (left), B is positive-X (right).
static func _sx(s: String) -> float:
	return -1.0 if s == "A" else 1.0

# Plain repositioning waypoint.
static func _adv(log: Array, tick: int, actor: String,
		to_x: float, to_y: float, end_tick: int, to_z := 0.0) -> void:
	log.append({"tick": tick, "actor": actor, "kind": "advance",
		"payload": {"to_x": to_x, "to_y": to_y, "to_z": to_z, "end_tick": end_tick}})

# Evasive dash — same envelope as advance but flags the renderer to use a
# fast directional burst visual rather than a walk.
static func _evade(log: Array, tick: int, actor: String,
		to_x: float, to_y: float, end_tick: int, to_z := 0.0) -> void:
	log.append({"tick": tick, "actor": actor, "kind": "advance",
		"payload": {"to_x": to_x, "to_y": to_y, "to_z": to_z, "end_tick": end_tick, "evade": true}})

# Pursuit dash — like evade but signals that this actor is closing on the enemy.
static func _pursue(log: Array, tick: int, actor: String,
		to_x: float, to_y: float, end_tick: int, to_z := 0.0) -> void:
	log.append({"tick": tick, "actor": actor, "kind": "advance",
		"payload": {"to_x": to_x, "to_y": to_y, "to_z": to_z, "end_tick": end_tick, "pursue": true}})

# Rough DPS for presser/retreater assignment only. Has no effect on combat.
static func _total_dps(side: Dictionary) -> float:
	var dps := 0.0
	for w in side.weapons:
		if float(w.cadence) > 0.0:
			dps += float(w.damage) / float(w.cadence)
	return dps

# Deterministic integer hash — returns a value in [0, modulus).
# Mixes seed_val with idx using a fixed multiplier; stays in signed 32-bit range.
static func _seeded_int(seed_val: int, idx: int, modulus: int) -> int:
	var h: int = (seed_val ^ (idx * 2654435761)) & 0x7FFFFFFF
	h = ((h >> 16) ^ h) & 0x7FFFFFFF
	return h % modulus

# ---------------------------------------------------------------------------
# Fire-event routing — damage is already applied before this is called.
# This is pure presentation routing: same damage, different visual schema.
# ---------------------------------------------------------------------------

## Build the right event for a weapon's FX kind. Damage is already applied; this is
## pure presentation routing (the sim outcome is identical regardless of fx). Every
## kind carries `mount` (so the beam/burst/salvo fires from that weapon) and `lethal`
## (so the kill-cam fires on whichever weapon lands the killing blow).
## Lethal events also carry `hero_kill: true` so the renderer/director can apply
## capital-ship-grade treatment (whiteout/screen-fill/collateral).
static func _fire_event(tick: int, actor: String, w: Dictionary, foe_hp: float, lethal: bool) -> Dictionary:
	var payload := {
		"damage": w.damage, "hp_after": maxf(0.0, foe_hp), "lethal": lethal, "mount": w.mount,
	}
	if lethal:
		payload["hero_kill"] = true
	var kind := "fire_beam"
	match w.fx:
		"burst":
			kind = "fire_burst"
			payload["rounds"] = 6
			payload["hits"] = 6
		"missiles":
			# Missiles route as a homing swarm (all-range convergence, Itano-circus style).
			# The renderer arcs each shot wide before they converge on the target.
			kind = "fire_swarm"
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
