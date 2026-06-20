extends RefCounted
## Movement trace — extracted from choreographer.gd so both the choreographer and
## grammar_metrics.gd can call it without coupling.
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##
## All functions are PURE and STATIC: same inputs -> same output, no side effects.
## Position model: spawn {x,z} + actor's `advance` beats, latest-started-wins on overlap.

## Per-tick, per-mech movement log resampled from the model.
## One row per (tick, actor) while the mech is alive, in (tick, actor) order.
## Row shape: {tick, actor, x, y, z, dist_to_enemy, speed, bearing_deg, boost}.
## Pure resample — x/z always agree with `position_at`.
static func movement_trace(events: Array) -> Array:
	var destroyed := _destroyed_ticks(events)
	var end_tick := _end_tick(events)
	var rows := []
	for tick in range(0, end_tick + 1):
		for actor in ["A", "B"]:
			if tick > int(destroyed.get(actor, 1 << 30)):
				continue
			var enemy := "B" if actor == "A" else "A"
			var pos := position_at(events, actor, tick)
			var prev := position_at(events, actor, tick - 1) if tick > 0 else pos
			var vel := pos - prev
			var speed := vel.length()
			var bearing_deg := rad_to_deg(atan2(vel.y, vel.x)) if speed > 1e-4 else 0.0
			rows.append({
				"tick": tick,
				"actor": actor,
				"x": pos.x,
				"y": _hop_y(events, actor, tick),
				"z": pos.y,
				"dist_to_enemy": pos.distance_to(position_at(events, enemy, tick)),
				"speed": speed,
				"bearing_deg": bearing_deg,
				"boost": _active_advance(events, actor, tick).get("payload", {}).get("boost", false),
			})
	return rows


## Position of a mech at `tick`, reconstructed from spawn {x,z} + advance beats.
## Vector2 is the ground plane (x, z). Latest-started active beat wins on overlap.
static func position_at(events: Array, actor: String, tick: int) -> Vector2:
	return _eval_layered(_spawn_xz(events, actor), _advances_for(events, actor), tick)


# ---------------------------------------------------------------------------
# Internal helpers (all static, all pure)
# ---------------------------------------------------------------------------

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
	# Not covered: standing at the target of the latest-started finished beat.
	var prev := {}
	for b in beats:
		if int(b.payload.end_tick) <= tick and (prev.is_empty() or int(b.tick) > int(prev.tick)):
			prev = b
	if not prev.is_empty():
		return Vector2(float(prev.payload.to_x), float(prev.payload.to_z))
	return spawn


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
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.tick) < int(q.tick))
	return out


static func _active_advance(events: Array, actor: String, tick: int) -> Dictionary:
	var active := {}
	for e in events:
		if e.kind == "advance" and e.actor == actor \
				and int(e.tick) <= tick and tick < int(e.payload.end_tick) \
				and (active.is_empty() or int(e.tick) > int(active.tick)):
			active = e
	return active


## Boost hop height at `tick`: triangle peaking at HOP mid-beat, 0 at the ends; 0 on ground.
## Mirrors choreographer._hop_y exactly (same constant pulled from the advance payload to_y).
static func _hop_y(events: Array, actor: String, tick: int) -> float:
	var b := _active_advance(events, actor, tick)
	if b.is_empty() or not bool(b.payload.get("boost", false)):
		return 0.0
	var s := int(b.tick)
	var e := int(b.payload.end_tick)
	var half := float(e - s) * 0.5
	if half <= 0.0:
		return 0.0
	# Use to_y as the peak (the choreographer writes it there).
	var hop := float(b.payload.get("to_y", 0.0))
	return hop * maxf(0.0, 1.0 - absf(float(tick) - float(s + e) * 0.5) / half)


static func _destroyed_ticks(events: Array) -> Dictionary:
	var out := {}
	for e in events:
		if e.kind == "destroyed":
			out[e.actor] = int(e.tick)
	return out


static func _end_tick(events: Array) -> int:
	var last := 0
	for e in events:
		# In truth logs, events have seq; in the v1 reference log they don't.
		# Use any event to find the timeline extent.
		last = maxi(last, int(e.get("tick", 0)))
	return last
