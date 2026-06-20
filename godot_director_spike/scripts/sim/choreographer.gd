extends RefCounted
## Combat Choreographer — stages the positionless combat-truth log for the camera.
## Spec: docs/superpowers/specs/2026-06-17-combat-choreographer-design.md
##
## A PURE function: (combat-truth events, presentation seed) -> the same events with the
## presentation layer merged in (spawn {x,z} placement + `advance` movement beats). It is
## the stage manager in `build -> sim -> log -> CHOREOGRAPHER -> director`: it decides where
## the two mechs ARE and how they MOVE so the director has a 3D scene to film. It never edits
## combat-truth — it only adds. Deterministic and reproducible, but NOT verified (this is the
## presentation layer the contract's INV-VERIFY excludes).
##
## Movement model: an ambient base (fixed mirrored spawn, a STRIDE reposition cadence onto
## the duel ring around the enemy, a periodic boost hop) plus three reactive triggers read
## off the truth log — boost-evade on an incoming heavy/lethal hit, a step-back stagger on a
## heavy hit landing, and a tightening ring as HP drops. All beats are placed in
## nondecreasing start-tick order against the model built so far, so every target is in-ring
## by construction and a later beat never perturbs an earlier tick. Precedence at overlap is
## evade > stagger > ambient (latest-started covering beat wins).
##
## Public `position_at` and `movement_trace` delegate to movement_trace.gd (the single
## source of truth for the position model). Internal staging helpers (_pos, _eval_layered,
## etc.) remain here because they operate on the partial `built` array during generation.

# --- staging parameters (world staging, separate from camera-craft ShotGrammar) ----------
const SPAWN_X := 40.0          # mirrored spawn: A at -SPAWN_X, B at +SPAWN_X, on the z=0 line
const STRIDE := 10             # ticks between ambient reposition beats
const ENGAGE_MIN := 34.0       # inner duel-ring radius (reads as circling / strafing)
const ENGAGE_MAX := 80.0       # outer duel-ring radius
const BOOST_EVERY := 3         # every K-th stride is an airborne boost
const HOP := 14.0              # peak to_y of a boost hop

const HIGH_TIER := 3           # tier at/above which a shot reads as heavy (evade + stagger)
const EVADE_MIN_TRAVEL := 3    # min flight ticks to read a dodge; shorter shots can't be evaded
const EVADE_ARC := 0.6         # radians the dodge weaves off the enemy bearing
const STAGGER_DAMAGE := 60.0   # damage at/above which a hit knocks the struck mech back
const STAGGER_DUR := 4         # ticks of the step-back beat
const KNOCKBACK := 10.0        # how far the stagger pushes the struck mech outward (clamped in-ring)
const LOW_HP_FRAC := 0.35      # below this fraction of spawn HP, the mech's ring tightens
const LOW_HP_MAX_RADIUS := 50.0 # tightened outer radius once a mech is low on HP

## Pinned so the presentation stream is independent of (but derived from) the fight seed.
const PRESENTATION_SALT := 0x9E3779B9


# =========================================================================================
# Public API
# =========================================================================================

## Stage the combat-truth log: returns the input truth events (unchanged, in canonical
## (tick, seq) order) with presentation events merged in — `advance` beats slotted after the
## truth of their tick (actor A before B), and {x,z} added onto each `spawn`.
static func stage(truth: Array, seed: int) -> Array:
	var pres_seed := (seed ^ PRESENTATION_SALT) & 0xFFFFFFFF
	var spawn_pos := {"A": Vector2(-SPAWN_X, 0.0), "B": Vector2(SPAWN_X, 0.0)}
	var spawn_hp := _spawn_hp(truth)
	var destroyed := _destroyed_ticks(truth)
	var low_hp := _low_hp_ticks(truth, spawn_hp)
	var end_tick := _end_tick(truth)
	var boost_phase := int(_hash01(pres_seed, 0, 0, 0) * BOOST_EVERY)

	# Collect every beat intent with its START tick, then realise them in start order so each
	# target is placed against the model already built (in-ring holds by construction).
	var intents := _ambient_intents(destroyed, end_tick, boost_phase)
	intents += _reactive_intents(truth, destroyed)
	intents.sort_custom(_intent_order)

	var built := []  # advance beats, accumulated in start order
	for it in intents:
		var actor: String = it.actor
		var enemy := "B" if actor == "A" else "A"
		var start: int = it.start
		var enemy_pos := _pos(built, spawn_pos, enemy, start)
		var target: Vector2
		var payload := {"end_tick": it.end}
		match it.kind:
			"ambient":
				var max_r := LOW_HP_MAX_RADIUS if low_hp.has(actor) and start > int(low_hp[actor]) else ENGAGE_MAX
				var bearing := _hash01(pres_seed, _actor_id(actor), start, 1) * TAU
				var radius := ENGAGE_MIN + _hash01(pres_seed, _actor_id(actor), start, 2) * (max_r - ENGAGE_MIN)
				target = enemy_pos + Vector2(cos(bearing), sin(bearing)) * radius
				if it.boost:
					payload["to_y"] = HOP
					payload["boost"] = true
			"evade":
				# weave sideways to a fresh in-ring bearing, airborne, spanning the flight.
				var self_pos := _pos(built, spawn_pos, actor, start)
				var to_self := (self_pos - enemy_pos).angle()
				var sign := 1.0 if _hash01(pres_seed, _actor_id(actor), start, 3) < 0.5 else -1.0
				var bearing := to_self + sign * EVADE_ARC
				var radius := (ENGAGE_MIN + ENGAGE_MAX) * 0.5
				target = enemy_pos + Vector2(cos(bearing), sin(bearing)) * radius
				payload["to_y"] = HOP
				payload["boost"] = true
			"stagger":
				# shoved outward along the enemy->self line, grounded, clamped in-ring.
				var self_pos := _pos(built, spawn_pos, actor, start)
				var dir := (self_pos - enemy_pos)
				dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
				var radius := clampf(self_pos.distance_to(enemy_pos) + KNOCKBACK, ENGAGE_MIN, ENGAGE_MAX)
				target = enemy_pos + dir * radius
		payload["to_x"] = target.x
		payload["to_z"] = target.y
		built.append({"tick": start, "actor": actor, "kind": "advance", "payload": payload})

	return _merge(truth, spawn_pos, built)


## Position of a mech in the choreographer's OWN model at `tick`, reconstructed from the
## staged log (spawn {x,z} + that actor's `advance` beats). Vector2 is the ground plane
## (x, z). Single source of truth for the in-ring invariant and the movement trace; the
## runtime director need not match it exactly (it interpolates + `_engage`-clamps).
## Delegates to movement_trace.gd — the canonical position model lives there.
static func position_at(events: Array, actor: String, tick: int) -> Vector2:
	return _MT.position_at(events, actor, tick)


## Per-tick, per-mech movement log resampled from the model, for comparing the technical
## cinematography quality of different builds/seeds later. One row per (tick, actor) while
## the mech is alive, in (tick, actor) order: {tick, actor, x, y, z, dist_to_enemy, speed,
## bearing_deg, boost}. Pure resample — x/z always agree with `position_at`.
## Delegates to movement_trace.gd.
static func movement_trace(events: Array) -> Array:
	return _MT.movement_trace(events)


## Cached reference to movement_trace.gd (loaded once, reused across static calls).
static var _MT := load("res://scripts/sim/movement_trace.gd")


# =========================================================================================
# Beat intents
# =========================================================================================

## Ambient reposition beats: every STRIDE ticks each living mech strides to a new ring point.
static func _ambient_intents(destroyed: Dictionary, end_tick: int, boost_phase: int) -> Array:
	var out := []
	var t := STRIDE
	while t <= end_tick:
		var stride_index := t / STRIDE
		for actor in ["A", "B"]:
			if t >= int(destroyed.get(actor, 1 << 30)):
				continue  # a destroyed mech gets no further beats
			out.append({
				"kind": "ambient", "actor": actor, "start": t, "end": t + STRIDE,
				"boost": (stride_index + boost_phase) % BOOST_EVERY == 0,
			})
		t += STRIDE
	return out


## Reactive beats read off the truth log. A shared guard skips a struck mech that is already
## destroyed and reads damage only where the contract guarantees it (connecting hits).
static func _reactive_intents(truth: Array, destroyed: Dictionary) -> Array:
	var out := []
	for e in truth:
		if e.kind != "shot":
			continue
		var p: Dictionary = e.payload
		if bool(p.get("post_decision", false)) or p.get("outcome", "") != "hit":
			continue  # post-decision and miss shots stage no reaction
		var struck := "B" if e.actor == "A" else "A"
		var impact := int(e.tick)
		if impact > int(destroyed.get(struck, 1 << 30)):
			continue  # already destroyed before this shot lands
		var tier := int(p.get("tier", 0))
		var lethal := bool(p.get("lethal", false))
		var damage := float(p.get("damage", 0.0))
		var heavy := tier >= HIGH_TIER or damage >= STAGGER_DAMAGE

		# Boost-evade: incoming heavy/lethal hit, span the whole flight; needs room to read.
		var travel := int(p.get("travel", 0))
		var fire := impact - travel
		if (tier >= HIGH_TIER or lethal) and travel >= EVADE_MIN_TRAVEL and fire >= 0:
			out.append({"kind": "evade", "actor": struck, "start": fire, "end": impact})

		# Step-back stagger: a heavy NON-lethal landing. A lethal hit's `destroyed` owns the tick.
		if heavy and not lethal:
			out.append({"kind": "stagger", "actor": struck, "start": impact, "end": impact + STAGGER_DUR})
	return out


## Deterministic realisation order: by start tick, then actor (A before B), then priority
## (ambient < stagger < evade) so a higher-priority beat at the same start wins on overlap.
static func _intent_order(p: Dictionary, q: Dictionary) -> bool:
	if p.start != q.start:
		return int(p.start) < int(q.start)
	if p.actor != q.actor:
		return _actor_id(p.actor) < _actor_id(q.actor)
	return _kind_rank(p.kind) < _kind_rank(q.kind)


static func _kind_rank(kind: String) -> int:
	match kind:
		"evade": return 2
		"stagger": return 1
		_: return 0


# =========================================================================================
# Position model
# =========================================================================================

## Self position from the model so far, during generation (spawn + already-built beats).
static func _pos(built: Array, spawn_pos: Dictionary, actor: String, tick: int) -> Vector2:
	var beats := []
	for b in built:
		if b.actor == actor:
			beats.append(b)
	return _eval_layered(spawn_pos[actor], beats, tick)


## Evaluate a position from spawn + advance beats, honouring overlap by latest-started-wins
## (evade preempts stagger preempts ambient because higher-priority beats start later/over).
## A beat's `from` is the position at its own start considering only earlier-started beats.
static func _eval_layered(spawn: Vector2, beats: Array, tick: int) -> Vector2:
	var active := {}
	for b in beats:
		var s := int(b.tick)
		var e := int(b.payload.end_tick)
		if s <= tick and tick < e and (active.is_empty() or s > int(active.tick)):
			active = b
	if not active.is_empty():
		var s := int(active.tick)
		var e := int(active.payload.end_tick)
		var to := Vector2(float(active.payload.to_x), float(active.payload.to_z))
		var earlier := []
		for b in beats:
			if int(b.tick) < s:
				earlier.append(b)
		var from := _eval_layered(spawn, earlier, s)
		return from.lerp(to, float(tick - s) / float(e - s))
	# Not covered by any beat: standing at the target of the latest-started finished beat.
	var prev := {}
	for b in beats:
		if int(b.payload.end_tick) <= tick and (prev.is_empty() or int(b.tick) > int(prev.tick)):
			prev = b
	if not prev.is_empty():
		return Vector2(float(prev.payload.to_x), float(prev.payload.to_z))
	return spawn


# =========================================================================================
# Internals — RNG, merge, lookups
# =========================================================================================

## Pinned uint32-wrapping LCG (Numerical Recipes constants) — the same arithmetic family the
## sim will use, so presentation RNG is reproducible across implementations.
static func _lcg(s: int) -> int:
	return (s * 1664525 + 1013904223) & 0xFFFFFFFF


## Deterministic per-beat value in [0, 1) from a 4-part key. Order-independent (no threaded
## stream), so the position-model evaluation order can never perturb the RNG.
static func _hash01(seed: int, a: int, b: int, c: int) -> float:
	var s := _lcg(seed & 0xFFFFFFFF)
	s = _lcg(s + (a & 0xFFFFFFFF))
	s = _lcg(s + (b & 0xFFFFFFFF))
	s = _lcg(s + (c & 0xFFFFFFFF))
	return float(s) / 4294967296.0


static func _actor_id(actor: String) -> int:
	return 0 if actor == "A" else 1


## Merge truth + presentation into one canonically ordered log. Truth keeps its (tick, seq)
## order; at each tick all truth events precede the tick's advances; advances are A-before-B
## (then in build order). `spawn` events get {x,z} added. Two-pointer merge.
static func _merge(truth: Array, spawn_pos: Dictionary, advances: Array) -> Array:
	advances.sort_custom(func(p, q):
		if int(p.tick) != int(q.tick):
			return int(p.tick) < int(q.tick)
		return _actor_id(p.actor) < _actor_id(q.actor))

	var out := []
	var i := 0
	var j := 0
	while i < truth.size() or j < advances.size():
		var take_truth := i < truth.size()
		if i < truth.size() and j < advances.size():
			take_truth = int(truth[i].tick) <= int(advances[j].tick)  # truth before advance at equal tick
		if take_truth:
			var e: Dictionary = truth[i].duplicate(true)
			if e.kind == "spawn":
				e.payload["x"] = spawn_pos[e.actor].x
				e.payload["z"] = spawn_pos[e.actor].y
			out.append(e)
			i += 1
		else:
			out.append(advances[j])
			j += 1
	return out


static func _spawn_xz(events: Array, actor: String) -> Vector2:
	for e in events:
		if e.kind == "spawn" and e.actor == actor:
			return Vector2(float(e.payload.get("x", 0.0)), float(e.payload.get("z", 0.0)))
	return Vector2.ZERO


static func _advances_for(events: Array, actor: String) -> Array:
	var out := []
	for e in events:
		if e.kind == "advance" and e.actor == actor:
			out.append(e)
	out.sort_custom(func(p, q): return int(p.tick) < int(q.tick))
	return out


static func _active_advance(events: Array, actor: String, tick: int) -> Dictionary:
	var active := {}
	for e in events:
		if e.kind == "advance" and e.actor == actor \
				and int(e.tick) <= tick and tick < int(e.payload.end_tick) \
				and (active.is_empty() or int(e.tick) > int(active.tick)):
			active = e
	return active


## Boost hop height at `tick`: a triangle peaking at HOP mid-beat, 0 at the ends; 0 on the
## ground. A model proxy for airtime — enough to compare apex / airborne fraction.
static func _hop_y(events: Array, actor: String, tick: int) -> float:
	var b := _active_advance(events, actor, tick)
	if b.is_empty() or not bool(b.payload.get("boost", false)):
		return 0.0
	var s := int(b.tick)
	var e := int(b.payload.end_tick)
	var half := float(e - s) * 0.5
	if half <= 0.0:
		return 0.0
	return HOP * maxf(0.0, 1.0 - absf(float(tick) - float(s + e) * 0.5) / half)


static func _spawn_hp(events: Array) -> Dictionary:
	var out := {}
	for e in events:
		if e.kind == "spawn":
			out[e.actor] = float(e.payload.get("hp", 0.0))
	return out


## First tick at which each mech's HP dropped below LOW_HP_FRAC of its spawn HP (the struck
## mech is the OTHER actor; hp_after describes it).
static func _low_hp_ticks(events: Array, spawn_hp: Dictionary) -> Dictionary:
	var out := {}
	for e in events:
		if e.kind != "shot" or not e.payload.has("hp_after"):
			continue
		var struck := "B" if e.actor == "A" else "A"
		if out.has(struck):
			continue
		var hp0 := float(spawn_hp.get(struck, 0.0))
		if hp0 > 0.0 and float(e.payload.hp_after) < LOW_HP_FRAC * hp0:
			out[struck] = int(e.tick)
	return out


static func _destroyed_ticks(events: Array) -> Dictionary:
	var out := {}
	for e in events:
		if e.kind == "destroyed":
			out[e.actor] = int(e.tick)
	return out


static func _end_tick(events: Array) -> int:
	var last := 0
	for e in events:
		if e.has("seq"):  # a combat-truth event marks the structural timeline
			last = maxi(last, int(e.tick))
	return last
