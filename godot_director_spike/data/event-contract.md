# Sim event contract (km-director-spike-fight-log-v1 + enriched-choreography)

What the director spike assumes a deterministic spatial sim will emit.
Last updated: 2026-06-15 (enriched choreography pass — verticality, swarm, dodge-pursuit,
momentum arc, hero-kill flag).

## Envelope

Ordered array of `{tick, actor, kind, payload}`. Ticks are integers at a declared
`tick_seconds` (0.1 here). Multiple events may share a tick; array order breaks ties.
`actor` is the acting side. The log is complete before playback begins — the
presentation layer may read ahead (the director's whole premise).

## Kinds

### Lifecycle

| kind | payload | notes |
|---|---|---|
| `spawn` | `x`, `hp` | stage is 1-D for the spike; a real sim emits 2-D coarse positions |
| `destroyed` | — | terminal event for `actor`; exactly one per fight |

### Movement — `advance`

```
advance {
  to_x:     float      -- target X position (sim units)
  to_y:     float      -- target Y position; 0 = grounded, >0 = pop-up burst / hop
  to_z:     float      -- target Z position (depth/lateral); 0 = centreline, ±40-ish
                          = full arena flank. Both mechs traverse independently so
                          the fight fills the arena in 3-D rather than closing on a
                          1-D line. Safe range: ±43 (arena boundary).
  end_tick: int        -- tick at which the mech reaches (to_x, to_y, to_z)
  evade?:   bool       -- present and true when this is an evasive micro-dash (fast
                          directional burst; renderer plays a boost-flare opposite
                          the direction of travel)
  pursue?:  bool       -- present and true when this is a pursuit close (same visual
                          treatment as evade but chasing, not fleeing; renderer may
                          tilt the camera slightly forward)
}
```

**Movement arc:** the fight is divided into three dramatic phases emitted as a
sequence of `advance` waypoints:

- **Phase 1 OPEN** (tick 2–59): the dominant side (higher DPS) presses to close range
  with a pop-up burst (`to_y = 6`); the other holds back then contests mid.
- **Phase 2 REVERSAL** (tick 60–133): the retreating side becomes aggressor, pushes
  close with its own pop-up. A **dodge-pursuit run** (tick 100–133) follows: the
  evader weaves across back/mid with `evade:true` dashes while the pursuer closes
  in with `pursue:true` advances and fires through the run.
- **Phase 3 CLIMAX** (tick 145+): both converge to close range; one seed-chosen side
  executes a final pop-up (`to_y = 6`) before the slug-fest ends.

**Renderer contract for `to_y`:** interpolate Y smoothly between waypoints. When
`to_y > 0` on arrival and the *next* waypoint for the same actor has `to_y = 0`,
this is a hop; play a thrust-burst flare on launch and a landing-dust puff on return.
Mechs never leave the ground plane without an `advance` event with `to_y > 0`.

**Renderer contract for `evade`/`pursue`:** these are the only two optional flags on
`advance`. All other `advance` events are plain repositioning. The renderer must not
crash on an `advance` that has neither flag.

### Ranged fire

| kind | payload | notes |
|---|---|---|
| `fire_beam` | `hit`, `damage`, `hp_after`, `mount`, opt `blocked`, `lethal`, `overkill`, `hero_kill` | `hp_after` is the TARGET's hp after this shot. Miss ⇒ `hit:false, damage:0`. `mount` is the firing weapon's hardpoint. |
| `fire_burst` | `rounds`, `hits`, `damage`, `hp_after`, `mount`, opt `lethal`, `hero_kill` | Rapid-fire tracers (gatling). Per-round hit distribution is presentation choice; totals are sim truth. |
| `fire_buster` | `hit`, `damage`, `hp_after`, `mount`, opt `lethal`, `hero_kill` | Charged heavy beam cannon: charge-up then a thick beam. |
| `fire_swarm` | `count`, `hits`, `damage`, `hp_after`, `mount`, opt `lethal`, `hero_kill` | All-range homing swarm. See below. |

**`fire_swarm` — all-range homing swarm (Itano-circus style):**

```
fire_swarm {
  count:    int    -- number of projectiles launched
  hits:     int    -- number that connect (sim truth; <= count)
  damage:   float  -- total damage applied this volley (sim truth)
  hp_after: float  -- target HP after all hits land
  mount:    string -- weapon hardpoint the salvo launches from
  lethal?:  bool   -- true when this volley reduces target HP to <= 0
  hero_kill?: bool -- present and true when lethal (see hero-kill below)
}
```

**Routing:** the `missiles` fx value in the weapon definition routes to `fire_swarm`.
The `fire_missiles` kind is **retired** — all missile-rack weapons now emit `fire_swarm`.
Renderer/director code that matched `fire_missiles` should be updated to `fire_swarm`
(the payload schema is identical).

**Renderer contract for `fire_swarm`:** launch `count` projectiles from the `mount`
hardpoint; arc each one wide (fan-out angle ≥ 45° off bore) before curving back to
converge on the target. `hits` projectiles register impacts; the remainder miss or
are shrugged off. Timing of individual impacts is presentation's choice.

### Reactor

| kind | payload | notes |
|---|---|---|
| `overload` | `damage`, `hp_after`, `lethal` | Sudden-death reactor overload: escalating self-damage on `actor`'s own mech once the duel passes the sudden-death tick. Renderer shows the mech cooking off. Kill-cam fires on any `lethal` event. |

### Hero-kill flag

Any fire event (`fire_beam`, `fire_burst`, `fire_buster`, `fire_swarm`) or `overload`
that reduces a mech's HP to ≤ 0 carries `lethal: true`. When the killing blow is a
weapon fire event (not overload), it also carries `hero_kill: true`.

```
hero_kill: true  -- the renderer/director SHOULD apply capital-ship-grade treatment:
                    whiteout flash, screen-fill beam, extended slow-motion, structural
                    collateral on nearby buildings. Another agent implements the
                    specific VFX; this flag is the hook.
```

The `destroyed` event that follows is the canonical terminal marker; `hero_kill` on
the lethal fire event is the *presentation* hook for escalated treatment.

## Invariants

- Outcomes are entirely in the log; the renderer never rolls dice that matter.
- Coarse positions are enough: garnish (tracer paths, ricochet points, fan arcs) may
  embellish freely as long as hit/miss/damage/death match the log.
- Exactly one `destroyed` event; it is always the last event in the log.
- Tick→seconds scaling is presentation-owned (the director may dilate time).
- `to_y` on `advance` is always present (default 0.0 = grounded).
  Renderers that previously ignored Y position must read it to support pop-up bursts.
- `to_z` on `advance` is always present from the 3-D choreography pass onward (default
  0.0 = centreline). Renderers pass it straight through to `walk_to(to_x, to_y, to_z, …)`
  — the chain already handles it. Both mechs carry non-zero `to_z` on most waypoints,
  spanning the full arena depth (±43 safe zone).
- Same (buildA, buildB, seed) → byte-identical log (BEH-D01). The choreography
  sequence is fully deterministic; the only seed-driven branch is the climax pop-up
  side assignment and the starting z-offset index.
