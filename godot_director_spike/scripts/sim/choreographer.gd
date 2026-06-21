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
	var built := _beam_trade(beats, feel_profiles, spawn_pos)
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
static var _GM := load("res://scripts/sim/grammar_metrics.gd")


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


## Path to the weapon-motif → grammar-mode-weights table (data, not code).
const MOTIF_WEIGHTS_PATH := "res://data/grammar_motif_weights.json"

## Per-weapon mode_weights for a motif, from MOTIF_WEIGHTS_PATH. A weapon weights several grammar
## modes (a hybrid leans across them); an unknown motif falls back to neutral (all-equal).
static func motif_weights(motif: String) -> Dictionary:
	var table: Variant = _motif_table()
	if table is Dictionary and table.has(motif):
		return table[motif]
	return NEUTRAL_MODE_WEIGHTS

static var _MOTIF_TABLE
static func _motif_table() -> Variant:
	if _MOTIF_TABLE == null:
		_MOTIF_TABLE = JSON.parse_string(FileAccess.get_file_as_string(MOTIF_WEIGHTS_PATH))
	return _MOTIF_TABLE


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
		var weights: Dictionary = e.payload.get("mode_weights", motif_weights(e.payload.get("motif", "")))
		shots.append({"e": e, "mode": select_mode(mix, weights, mode_map)})
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
			"exchange_mode": g.mode,
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
static func _beam_trade(beats: Array, feel_profiles: Dictionary, spawn_pos: Dictionary) -> Array:
	var react: int = int(_P.REACT)
	# Stable home bearing per shooter (target-centric), so the strafe oscillates around a fixed
	# side instead of compounding: A sits on B's −x arc, B on A's +x arc.
	var home := {
		"A": (spawn_pos["A"] - spawn_pos["B"]).angle(),
		"B": (spawn_pos["B"] - spawn_pos["A"]).angle(),
	}

	# Collect both spans of every beat as intents, then realise in (start, actor) order. Each
	# shooter's engages carry a running orbit index so successive closes strafe around the ring.
	# Plant-then-fire: the engage arrives by fire_tick, then HOLDS through the shot.
	var orbit := {"A": 0, "B": 0}
	var intents := []
	for b in beats:
		var shooter: String = b.shooter
		var target := "B" if shooter == "A" else "A"
		intents.append({
			"start": int(b.cue_tick), "end": maxi(int(b.fire_tick), int(b.cue_tick) + 1),
			"actor": shooter, "kind": "engage", "shooter": shooter, "target": target,
			"orbit": orbit[shooter], "mode": b.exchange_mode,
		})
		orbit[shooter] += 1
		intents.append({
			"start": int(b.impact_tick), "end": int(b.impact_tick) + react,
			"actor": target, "kind": "reaction", "shooter": shooter, "target": target,
			"connects": bool(b.get("connects", false)), "mode": b.exchange_mode,
		})
	intents.sort_custom(func(p, q):
		if int(p.start) != int(q.start):
			return int(p.start) < int(q.start)
		return _actor_id(p.actor) < _actor_id(q.actor))

	var built := []
	for it in intents:
		var advs: Array = _engage(it, built, spawn_pos, feel_profiles, home) if it.kind == "engage" \
			else _reaction(it, built, spawn_pos, feel_profiles)
		for a in advs:
			built.append(a)
	return built


## Read a FeelProfile bias for an actor (heft/tempo), defaulting to the neutral 0.5.
static func _feel(feel_profiles: Dictionary, actor: String, key: String) -> float:
	return float(feel_profiles.get(actor, {}).get(key, 0.5))


## A tunable constant, optionally overridden per-actor by its archetype preset's `overrides`.
static func _param(feel_profiles: Dictionary, actor: String, key: String, default: float) -> float:
	return float(feel_profiles.get(actor, {}).get("overrides", {}).get(key, default))


## Build a FeelProfile {heft, tempo, mode_mix, overrides} from a named archetype preset
## (data: grammar_presets.json). A new archetype is a data row, never code.
static func apply_preset(name: String) -> Dictionary:
	var p: Dictionary = _P.load_presets().get(name, {})
	return {
		"heft": float(p.get("heft_bias", 0.5)),
		"tempo": float(p.get("tempo_bias", 0.5)),
		"mode_mix": p.get("mode_mix", {}),
		"overrides": p.get("overrides", {}),
	}


## Build one `advance` beat dict (a movement span the position model lerps across).
static func _adv(actor: String, start: int, end: int, to: Vector2, to_y := 0.0, boost := false) -> Dictionary:
	return {"tick": start, "actor": actor, "kind": "advance",
		"payload": {"to_x": to.x, "to_z": to.y, "to_y": to_y, "boost": boost, "end_tick": maxi(end, start + 1)}}


## Engage geometry per exchange mode — the shooter's pre-impact movement (fire-knowable only,
## no outcome read). Each mode reads as a distinct silhouette: beam-trade strafes at mid range;
## swarm stands off and lobs; dodge-pursuit charges in; melee dashes to contact. The per-side
## sign keeps every mode equivariant under (swap A<->B, negate-x) for the CG-BLIND mirror.
static func _engage(it: Dictionary, built: Array, spawn_pos: Dictionary, feel: Dictionary, home: Dictionary) -> Array:
	var shooter: String = it.shooter
	var start: int = it.start
	var end: int = it.end
	var sp := _pos(built, spawn_pos, shooter, start)
	var tp := _pos(built, spawn_pos, it.target, start)
	var heft := _feel(feel, shooter, "heft")
	var tempo := _feel(feel, shooter, "tempo")
	var oamp := _param(feel, shooter, "ORBIT_AMP", ORBIT_AMP)  # archetype-overridable strafe width
	var sign := 1.0 if shooter == "A" else -1.0
	var base: float = float(home[shooter])
	match it.mode:
		"swarm":
			var band := lerpf(_P.RANGE_FAR - 5.0, _P.RANGE_MID, heft)  # stand off and lob
			var bearing := base + sign * (oamp * 0.4) * sin(float(it.orbit) * ORBIT_RATE)
			return [_adv(shooter, start, end, tp + Vector2(cos(bearing), sin(bearing)) * band)]
		"dodge-pursuit":
			var band := lerpf(_P.RANGE_NEAR, _P.RANGE_CLOSE, heft)  # charge in (grounded)
			var bearing := base + sign * (oamp * 0.8) * sin(float(it.orbit) * ORBIT_RATE)
			return [_adv(shooter, start, end, tp + Vector2(cos(bearing), sin(bearing)) * band)]
		"melee":
			var dir := (sp - tp)  # grounded lunge straight to contact (speed spike into the clash)
			dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
			return [_adv(shooter, start, end, tp + dir * (_P.RANGE_CLOSE * 0.7))]
		_:  # beam-trade
			var band := lerpf(_P.RANGE_MID, _P.RANGE_CLOSE, heft)
			var amp := oamp * (1.3 - heft)
			var rate := ORBIT_RATE * (0.5 + tempo)
			var bearing := base + sign * amp * sin(float(it.orbit) * rate)
			return [_adv(shooter, start, end, tp + Vector2(cos(bearing), sin(bearing)) * band)]


## Reaction geometry per exchange mode — the struck mech AT impact (may read the resolution).
## beam-trade sells/weaves once; swarm and dodge-pursuit weave (zig-zag dodging); melee dwells
## in a contact then separates. The per-side lateral sign keeps the weave mirror-equivariant.
static func _reaction(it: Dictionary, built: Array, spawn_pos: Dictionary, feel: Dictionary) -> Array:
	var actor: String = it.actor  # the struck mech
	var start: int = it.start
	var end: int = it.end
	var sp := _pos(built, spawn_pos, it.shooter, start)
	var tp := _pos(built, spawn_pos, actor, start)
	var heft := _feel(feel, actor, "heft")
	var knock := _param(feel, actor, "KNOCK", KNOCK)  # archetype-overridable sell force
	var weave := _param(feel, actor, "WEAVE", WEAVE)  # archetype-overridable dodge throw
	var away := tp - sp
	away = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
	var lat := away.orthogonal() * (1.0 if actor == "A" else -1.0)
	match it.mode:
		"swarm":
			return _weave_path(actor, start, end, tp, lat, weave, 3)
		"dodge-pursuit":
			return _weave_path(actor, start, end, tp + away * (knock * 0.5), lat, weave, 3)
		"melee":
			var mid := (start + end) / 2  # contact dwell, then break apart
			return [_adv(actor, start, mid, tp), _adv(actor, mid, end, tp + away * (knock * (1.6 - heft)))]
		_:  # beam-trade
			if bool(it.connects):
				return [_adv(actor, start, end, tp + away * (knock * (1.5 - heft)))]
			return [_adv(actor, start, end, tp + lat * weave)]


## A zig-zag weave: `segments` contiguous sub-advances alternating ±lateral around `base`, so the
## velocity reverses each segment — the per-mode CG-CONTRAST signature for salvo/pursuit dodging.
static func _weave_path(actor: String, start: int, end: int, base: Vector2, lat: Vector2, amp: float, segments: int) -> Array:
	var out := []
	var span := end - start
	for k in range(segments):
		var s := start + k * span / segments
		var e := start + (k + 1) * span / segments
		out.append(_adv(actor, s, e, base + lat * amp * (1.0 if k % 2 == 0 else -1.0)))
	return out


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


# =========================================================================================
# Layer 4 — dramaturgy: suspense plan + the root `presentation` hook block
# =========================================================================================

const TEMPLATES_PATH := "res://data/grammar_templates.json"

## Load the shape → template_id registry (data, not code).
static func load_templates() -> Dictionary:
	var text := FileAccess.get_file_as_string(TEMPLATES_PATH)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## The side-channel `presentation` hook block (per the spec it rides as a side file, not inside
## the frozen event log, until the contract amendment ratifies it). Pure structural facts:
## per-beat hooks bound by truth_ref, plus a fight block with the classified shape + template,
## phrase bounds, the staged apparent-initiative series (quantized to Q), the climax window, and
## the lethal reference. The hard CG-NO-PRESPOIL gate never reads this block; the advisory
## invariant is climax_window.start >= reveal(truth_dom).
static func presentation(truth: Array, seed: int, feel_profiles: Dictionary) -> Dictionary:
	var staged := stage(truth, seed, feel_profiles)
	var beats := schedule(truth, feel_profiles, load_mode_map())
	var duration := _end_tick(truth) + 1

	var td: Array = _GM.truth_dom(truth, _spawn_hp(truth))
	var sd: Array = _GM.staged_dom(staged)
	var shape: String = _GM.classify_shape(td, _has_kill(truth), duration)
	var rev: int = _GM.reveal(td)
	var late_gate := int(_P.LATE_FRAC * float(duration))
	var climax_start: int = rev if rev < (1 << 20) else late_gate

	var beat_hooks := []
	for b in beats:
		beat_hooks.append({
			"truth_ref": b.truth_ref,
			"exchange_mode": b.exchange_mode,
			"range_band": _mode_band(b.exchange_mode),  # the proxemic band the mode engages at
			"cue_tick": int(b.cue_tick), "fire_tick": int(b.fire_tick), "impact_tick": int(b.impact_tick),
			"is_background": bool(b.is_background),
			"reaction_background": bool(b.reaction_background),
			"is_impact": bool(b.connects),
			"heavy_impact": bool(b.connects) and float(_max_damage(truth, b.truth_ref)) >= float(_P.HEAVY_DMG),
		})

	var q := float(_P.Q)
	var ai := []
	for t in range(sd.size()):
		ai.append({"tick": t, "lead": round(float(sd[t]) / q) * q})

	var fight := {
		"shape": shape,
		"template_id": String(load_templates().get(shape, "")),
		"phrase_bounds": _phrase_bounds(beats, int(_P.REACT)),
		"apparent_initiative": ai,
		"climax_window": [climax_start, maxi(duration - 1, climax_start)],
		"lethal_ref": _lethal_ref(truth),
	}
	return {"beats": beat_hooks, "fight": fight}


## Bundle the staged events with the side-channel `presentation` hook block, the shape the log
## document carries once the contract amendment blesses the optional `presentation` root key:
##   { "events": [...], "presentation": {...} }.
## The truth-set keys (events/result/…) project exactly as before — `presentation` is additive
## and the loader ignores unknown root keys — so the truth hash and re-sim are unaffected.
static func stage_with_hooks(truth: Array, seed: int, feel_profiles: Dictionary) -> Dictionary:
	return {"events": stage(truth, seed, feel_profiles), "presentation": presentation(truth, seed, feel_profiles)}


## Merge each beat's [cue_tick, impact_tick + gap] span into contiguous phrase bounds.
static func _phrase_bounds(beats: Array, gap: int) -> Array:
	var spans := []
	for b in beats:
		spans.append([int(b.cue_tick), int(b.impact_tick) + gap])
	spans.sort_custom(func(p, q): return int(p[0]) < int(q[0]))
	var merged := []
	for s in spans:
		if merged.is_empty() or int(s[0]) > int(merged[-1][1]):
			merged.append([int(s[0]), int(s[1])])
		else:
			merged[-1][1] = maxi(int(merged[-1][1]), int(s[1]))
	return merged


## A kill exists if any shot resolves lethal (equivalently result.cause == "kill").
static func _has_kill(truth: Array) -> bool:
	for e in truth:
		if e.kind == "shot" and bool(e.get("payload", {}).get("lethal", false)):
			return true
	return false


## The lethal shot's truth ref {tick, seq}, or null if the fight has no kill.
static func _lethal_ref(truth: Array):
	for e in truth:
		if e.kind == "shot" and bool(e.get("payload", {}).get("lethal", false)):
			return {"tick": int(e.tick), "seq": int(e.seq)}
	return null


static func _spawn_hp(truth: Array) -> Dictionary:
	var out := {}
	for e in truth:
		if e.kind == "spawn":
			out[e.actor] = float(e.get("payload", {}).get("hp", 0.0))
	return out


static func _end_tick(truth: Array) -> int:
	var last := 0
	for e in truth:
		last = maxi(last, int(e.tick))
	return last


## The proxemic range band a mode engages at (a structural fact for the director's framing).
static func _mode_band(mode: String) -> String:
	match mode:
		"swarm": return "far"
		"dodge-pursuit": return "near"
		"melee": return "close"
		_: return "mid"


## Damage of a beat's representative shot (for the at-impact heavy-emphasis hook).
static func _max_damage(truth: Array, ref: Dictionary) -> float:
	for e in truth:
		if e.kind == "shot" and int(e.tick) == int(ref.tick) and int(e.seq) == int(ref.seq):
			return float(e.get("payload", {}).get("damage", 0.0))
	return 0.0
