extends RefCounted
## Combat Choreographer — stages the positionless combat-truth log for the camera.
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   (supersedes the ambient-only 2026-06-17-combat-choreographer-design.md).
##
## A PURE function: stage(truth_events, seed, feel_profiles) -> the same truth events with the
## presentation layer merged in (spawn {x,z} + `advance` movement beats). It is the stage
## manager in `build -> sim -> log -> CHOREOGRAPHER -> director`: it decides where the two
## mechs ARE and how they MOVE so the director has a 3D scene to film. It never edits
## combat-truth — it only adds. Deterministic and reproducible, but NOT verified (the
## presentation layer the contract's INV-VERIFY excludes).
##
## Pipeline (four layers, outer-to-inner; pass 1 implements the beam-trade path only):
##   Layer 3 — schedule() groups shots into beats (mode per shot, coalesce, rank by tier,
##     commit screen-time with preemption), then the beam-trade exchange places both mechs in
##     a range band and structures each beat as Cue·Reaction·Action, emitting `advance` beats.
##   Layer 1 prosody and Layer 4 dramaturgy land in later increments.
##
## CG-BLIND: pre-impact staging (cue→fire→track) reads only fire-knowable attributes; the
## victim's sell/near-miss is staged AT impact, where the truth itself reveals the resolution.
## So a hit and a miss are staged identically until the impact tick.
##
## Public `position_at` and `movement_trace` delegate to movement_trace.gd (the single source
## of truth for the position model). Internal staging helpers (_pos, _eval_layered) operate on
## the partial `built` array during generation.

# --- staging parameters (world staging, separate from camera-craft ShotGrammar) ----------
const SPAWN_X := 40.0   # mirrored spawn: A at -SPAWN_X, B at +SPAWN_X, on the z=0 line
const KNOCK := 14.0     # how far an at-impact sell shoves the struck mech away from the shooter
const WEAVE := 16.0     # lateral offset of a near-miss dodge (a miss reaction, not a sell)
const ORBIT_AMP := 0.5  # radians the engage strafes off the shooter's home bearing (~28°: circles its own side, never crosses center)
const ORBIT_RATE := 1.1 # how fast the strafe oscillates across successive beats (zig-zag, not a slow drift)
const HOP_Y := 9.0      # apex height of a boosted (airborne) heavy-beat close
const BOOST_TIER := 3   # tier at/above which the shooter's close reads as a boosted airborne dash


# =========================================================================================
# Public API
# =========================================================================================

## Stage the combat-truth log: returns the input truth events (unchanged, in canonical
## (tick, seq) order) with presentation events merged in — `advance` beats slotted after the
## truth of their tick (actor A before B), and {x,z} added onto each `spawn`. `feel_profiles`
## is required (one {heft, tempo, mode_mix} per actor); seed pins any presentation RNG (the
## beam-trade exchange is deterministic geometry, so seed is currently inert but pinned).
static func stage(truth: Array, _seed: int, feel_profiles: Dictionary) -> Array:
	var spawn_pos := {"A": Vector2(-SPAWN_X, 0.0), "B": Vector2(SPAWN_X, 0.0)}
	var beats := schedule(truth, feel_profiles, load_mode_map())
	var built := _beam_trade(beats, truth, spawn_pos)
	return _merge(truth, spawn_pos, built)


## Position of a mech at `tick`, reconstructed from the staged log (spawn {x,z} + that actor's
## `advance` beats). Vector2 is the ground plane (x, z). Delegates to movement_trace.gd.
static func position_at(events: Array, actor: String, tick: int) -> Vector2:
	return _MT.position_at(events, actor, tick)


## Per-tick, per-mech movement log resampled from the model. Delegates to movement_trace.gd.
static func movement_trace(events: Array) -> Array:
	return _MT.movement_trace(events)


## Cached references (loaded once, reused across static calls).
static var _MT := load("res://scripts/sim/movement_trace.gd")
static var _P := load("res://scripts/sim/grammar_params.gd")


# =========================================================================================
# Layer 3 — exchange-mode composition (beat scheduler, Step 0)
# =========================================================================================

## The closed four-mode grammar vocabulary, in the fixed tie-break order
## (beam-trade < swarm < dodge-pursuit < melee).
const GRAMMAR_MODES := ["beam-trade", "swarm", "dodge-pursuit", "melee"]

## Select a shot's grammar mode from the SHOOTER's FeelProfile mode_mix and the firing
## weapon's mode_weights, mapping feel-modes to grammar-modes via mode_map. Pure argmax:
##   feel_g[g] = Σ_{f → g in mode_map} mode_mix[f];  score[g] = mode_weights[g] · feel_g[g].
## Ties resolve to the earliest mode in GRAMMAR_MODES order. This is the real selection seam;
## pass-1 beam-trade gating is applied separately by the caller (gate_mode), so selection is
## exercised even while only beam-trade is staged.
static func select_mode(mode_mix: Dictionary, mode_weights: Dictionary, mode_map: Dictionary) -> String:
	var feel_g := {}
	for g in GRAMMAR_MODES:
		feel_g[g] = 0.0
	for f in mode_map:
		var g: String = mode_map[f]
		feel_g[g] = float(feel_g.get(g, 0.0)) + float(mode_mix.get(f, 0.0))

	var best := GRAMMAR_MODES[0]
	var best_score := 0.0
	for g in GRAMMAR_MODES:
		var score := float(mode_weights.get(g, 0.0)) * float(feel_g[g])
		if score > best_score:
			best_score = score
			best = g
	if best_score > 0.0:
		return best

	# Degenerate (no feel-mode and weapon weight coincide on any mode): fall back to the
	# weapon's own argmax; if that is also all-zero, the final fallback is beam-trade.
	var w_best := GRAMMAR_MODES[0]
	var w_best_score := 0.0
	for g in GRAMMAR_MODES:
		var w := float(mode_weights.get(g, 0.0))
		if w > w_best_score:
			w_best_score = w
			w_best = g
	return w_best


## Path to the feel-mode → grammar-mode data table (a versioned data resource, not code).
const MODE_MAP_PATH := "res://data/grammar_mode_map.json"

## Load the feel-mode → grammar-mode table from MODE_MAP_PATH.
static func load_mode_map() -> Dictionary:
	var text := FileAccess.get_file_as_string(MODE_MAP_PATH)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## Load-time validation: the map must cover EVERY FeelProfile feel-mode (missing key = invalid),
## and every value must be one of the four grammar modes.
static func validate_mode_map(mode_map: Dictionary, feel_modes: Array) -> bool:
	for f in feel_modes:
		if not mode_map.has(f):
			return false
	for f in mode_map:
		if not GRAMMAR_MODES.has(mode_map[f]):
			return false
	return true


## Pass-1 gating: only the beam-trade exchange is implemented this pass, so any selected mode
## is staged as beam-trade. The selection seam (select_mode) is real and exercised; only the
## staging is gated. Later passes drop this gate as each mode's exchange lands.
static func gate_mode(_mode: String) -> String:
	return "beam-trade"


# =========================================================================================
# Layer 3 — beat scheduler (total & deterministic)
# =========================================================================================

## Neutral weapon weights used for mode selection: the truth log carries `motif`/`tier`/
## `travel` but not per-weapon `mode_weights` (those are pre-sim build data aggregated into the
## actor's mode_mix), so in this pass the shooter's mode_mix decides the selected mode. A real
## per-weapon mode_weights data row is the deferred extension when a second mode is staged.
const NEUTRAL_MODE_WEIGHTS := {"beam-trade": 1.0, "swarm": 1.0, "dodge-pursuit": 1.0, "melee": 1.0}

## Group the truth shots into beats. Total & deterministic, ordered by (tick, seq).
##   Step 0 — mode per shot (select_mode on the shooter's mode_mix; gated to beam-trade).
##   Step 1 — coalesce: same shooter + same selected mode within COALESCE_WINDOW ticks → one
##     beat. Representative = (tick,seq)-earliest; impact_tick = latest impact; fire_tick =
##     impact_tick − representative.travel; cue_tick = max(fire_tick − TELEGRAPH, spawn tick).
##   Step 2 — rank (fire-knowable): heavy (tier ≥ HEAVY_TIER) > normal; tier only, never
##     lethal/damage (CG-BLIND part 2). The lethal resolution is an at-impact treatment.
## Step 3 (commit/preemption: is_background/reaction_background) is applied by commit_beats().
## `connects`/`lethal` record the at-impact resolution for the sell/hero treatment — read only
## at impact_tick, never by the fire-knowable rank.
static func schedule(truth: Array, feel_profiles: Dictionary, mode_map: Dictionary) -> Array:
	var spawn := _spawn_ticks(truth)

	# Step 0 — collect shots in (tick, seq) order, each tagged with its selected mode.
	var shots := []
	for e in truth:
		if e.kind != "shot":
			continue
		var mix: Dictionary = feel_profiles.get(e.actor, {}).get("mode_mix", {})
		shots.append({"e": e, "mode": select_mode(mix, NEUTRAL_MODE_WEIGHTS, mode_map)})
	shots.sort_custom(func(p, q):
		var et: Dictionary = p.e
		var qt: Dictionary = q.e
		if int(et.tick) != int(qt.tick):
			return int(et.tick) < int(qt.tick)
		return int(et.seq) < int(qt.seq))

	# Step 1 — coalesce per (shooter, mode) stream; a shot joins the open group while its tick
	# is within COALESCE_WINDOW of the group's representative (earliest) tick.
	var groups := []  # each: {shooter, mode, shots:[...]}
	var open := {}    # key "shooter|mode" -> index into groups of the currently-open group
	for s in shots:
		var shooter: String = s.e.actor
		var key := "%s|%s" % [shooter, s.mode]
		var g_idx: int = open.get(key, -1)
		if g_idx >= 0 and int(s.e.tick) - int(groups[g_idx].shots[0].tick) <= _P.COALESCE_WINDOW:
			groups[g_idx].shots.append(s.e)
		else:
			groups.append({"shooter": shooter, "mode": s.mode, "shots": [s.e]})
			open[key] = groups.size() - 1

	# Steps 1 (fields) + 2 (rank) — realise each group as a beat.
	var beats := []
	for g in groups:
		var rep: Dictionary = g.shots[0]  # (tick,seq)-earliest (shots arrive in order)
		var impact := 0
		var tier := 0
		var lethal := false
		var connects := false
		for sh in g.shots:
			impact = maxi(impact, int(sh.tick))
			tier = maxi(tier, int(sh.payload.get("tier", 0)))
			lethal = lethal or bool(sh.payload.get("lethal", false))
			connects = connects or sh.payload.get("outcome", "") == "hit"
		var fire := impact - int(rep.payload.get("travel", 0))
		var cue: int = maxi(fire - _P.TELEGRAPH, int(spawn.get(g.shooter, 0)))
		beats.append({
			"truth_ref": {"tick": int(rep.tick), "seq": int(rep.seq)},
			"shooter": g.shooter,
			"selected_mode": g.mode,
			"exchange_mode": gate_mode(g.mode),
			"cue_tick": cue,
			"fire_tick": fire,
			"impact_tick": impact,
			"tier": tier,
			"priority": "heavy" if tier >= _P.HEAVY_TIER else "normal",
			"connects": connects,
			"lethal": lethal,
			"is_background": false,
			"reaction_background": false,
		})
	return commit_beats(beats)


## Step 3 — commit actor screen-time with preemption. Walk beats in (priority desc, tick asc,
## seq asc) order; each full-CRA beat claims TWO half-open spans: the shooter's
## [cue_tick, impact_tick) (cue→fire→track) and the target's [impact_tick, impact_tick+REACT)
## (the victim's sell). The two claims are demoted INDEPENDENTLY: a span overlapping an
## already-committed (≥-priority) claim on that actor's timeline goes background and yields no
## claim of its own. Because heavies are processed first, a high-tier beat is never demoted by
## an earlier normal commit. Annotates and returns the SAME beat dicts.
static func commit_beats(beats: Array) -> Array:
	var order := beats.duplicate()
	order.sort_custom(func(p, q):
		var pp := 0 if p.priority == "heavy" else 1  # heavy first
		var qp := 0 if q.priority == "heavy" else 1
		if pp != qp:
			return pp < qp
		if int(p.truth_ref.tick) != int(q.truth_ref.tick):
			return int(p.truth_ref.tick) < int(q.truth_ref.tick)
		return int(p.truth_ref.seq) < int(q.truth_ref.seq))

	var claims := {"A": [], "B": []}  # actor -> committed foreground [start, end) intervals
	for b in order:
		var shooter: String = b.shooter
		var target := "B" if shooter == "A" else "A"
		var s_span := [int(b.cue_tick), int(b.impact_tick)]
		var r_span := [int(b.impact_tick), int(b.impact_tick) + int(_P.REACT)]

		if _overlaps_any(claims[shooter], s_span):
			b.is_background = true
		else:
			b.is_background = false
			claims[shooter].append(s_span)

		if _overlaps_any(claims[target], r_span):
			b.reaction_background = true
		else:
			b.reaction_background = false
			claims[target].append(r_span)
	return beats


## True if [s, e) overlaps any committed half-open interval. A zero-length span overlaps nothing.
static func _overlaps_any(intervals: Array, span: Array) -> bool:
	var s := int(span[0])
	var e := int(span[1])
	for iv in intervals:
		if int(iv[0]) < e and s < int(iv[1]):
			return true
	return false


static func _spawn_ticks(events: Array) -> Dictionary:
	var out := {}
	for e in events:
		if e.kind == "spawn":
			out[e.actor] = int(e.tick)
	return out


# =========================================================================================
# Layer 3 — beam-trade exchange (places mechs in a range band; Cue·Reaction·Action)
# =========================================================================================

## Realise the scheduled beats as `advance` beats. Each beat contributes two movement spans,
## built in start-tick order so each is placed against the model already built:
##   engage   [cue_tick, impact_tick) — the shooter closes onto the BAND (range_mid) distance
##            from the target along the current axis (cue→fire→track). Fire-knowable only.
##   reaction [impact_tick, impact_tick+REACT) — the target sells: shoved away from the shooter
##            on a connecting hit (drives the staged_dom sell channel), or weaves laterally on a
##            miss (a real near-miss, no sell). Read AT impact, where the truth reveals it.
static func _beam_trade(beats: Array, _truth: Array, spawn_pos: Dictionary) -> Array:
	var band: float = _P.RANGE_MID
	var react: int = int(_P.REACT)
	# Stable home bearing per shooter (target-centric), so the strafe oscillates around a fixed
	# side instead of compounding: A sits on B's −x arc, B on A's +x arc.
	var home := {
		"A": (spawn_pos["A"] - spawn_pos["B"]).angle(),
		"B": (spawn_pos["B"] - spawn_pos["A"]).angle(),
	}

	# Collect both spans of every beat as intents, then realise in (start, actor) order. Each
	# shooter's engages carry a running orbit index so successive closes strafe around the ring.
	var orbit := {"A": 0, "B": 0}
	var intents := []
	for b in beats:
		var shooter: String = b.shooter
		var target := "B" if shooter == "A" else "A"
		var heavy := int(b.tier) >= BOOST_TIER
		# Plant-then-fire: arrive by fire_tick, then HOLD through the shot (no advance past
		# fire), so the mech sets its feet and fires planted instead of sliding through the beam.
		intents.append({
			"start": int(b.cue_tick), "end": maxi(int(b.fire_tick), int(b.cue_tick) + 1),
			"actor": shooter, "kind": "engage", "shooter": shooter, "target": target,
			"orbit": orbit[shooter], "heavy": heavy,
		})
		orbit[shooter] += 1
		intents.append({
			"start": int(b.impact_tick), "end": int(b.impact_tick) + react,
			"actor": target, "kind": "reaction", "shooter": shooter, "target": target,
			"connects": bool(b.get("connects", false)),
		})
	intents.sort_custom(func(p, q):
		if int(p.start) != int(q.start):
			return int(p.start) < int(q.start)
		return _actor_id(p.actor) < _actor_id(q.actor))

	var built := []
	for it in intents:
		var actor: String = it.actor
		var shooter: String = it.shooter
		var target: String = it.target
		var start: int = it.start
		var shooter_pos := _pos(built, spawn_pos, shooter, start)
		var target_pos := _pos(built, spawn_pos, target, start)
		var to: Vector2
		var to_y := 0.0
		var boost := false
		match it.kind:
			"engage":
				# Strafe to BAND distance on an oscillating bearing around the shooter's home
				# side, so the duel circles instead of sliding head-on. Heavy beats boost in
				# (airborne dash); the bearing/boost are fire-knowable (no outcome read).
				var bearing: float = float(home[shooter]) + ORBIT_AMP * sin(float(it.orbit) * ORBIT_RATE)
				to = target_pos + Vector2(cos(bearing), sin(bearing)) * band
				if bool(it.heavy):
					boost = true
					to_y = HOP_Y
			"reaction":
				var away := target_pos - shooter_pos
				away = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
				if bool(it.connects):
					to = target_pos + away * KNOCK       # sell: a grounded stagger-step back, feet planted
				else:
					to = target_pos + away.orthogonal() * WEAVE  # near-miss: lateral weave
		built.append({
			"tick": start, "actor": actor, "kind": "advance",
			"payload": {"to_x": to.x, "to_z": to.y, "to_y": to_y, "boost": boost, "end_tick": it.end},
		})
	return built


# =========================================================================================
# Position model (during generation, against the partial `built` array)
# =========================================================================================

## Self position from the model so far, during generation (spawn + already-built beats).
static func _pos(built: Array, spawn_pos: Dictionary, actor: String, tick: int) -> Vector2:
	var beats := []
	for b in built:
		if b.actor == actor:
			beats.append(b)
	return _eval_layered(spawn_pos[actor], beats, tick)


## Evaluate a position from spawn + advance beats, honouring overlap by latest-started-wins.
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
# Internals — merge
# =========================================================================================

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
