# Assumed sim event contract (km-director-spike-fight-log-v1)

What the director spike assumes a future deterministic spatial sim will emit.
A design input for the spatial-sim slice, extracted per the 2026-06-12 design spec.

## Envelope

Ordered array of `{tick, actor, kind, payload}`. Ticks are integers at a declared
`tick_seconds` (0.1 here). Multiple events may share a tick; array order breaks ties.
`actor` is the acting side. The log is complete before playback begins — the
presentation layer may read ahead (the director's whole premise).

## Kinds

| kind | payload | notes |
|---|---|---|
| `spawn` | `x`, `hp` | stage is 1-D for the spike; a real sim emits 2-D coarse positions |
| `advance` | `to_x`, `end_tick` | movement as start/end so playback can interpolate; sim owns the path |
| `fire_beam` | `hit`, `damage`, `hp_after`, opt `blocked`, `lethal`, `overkill`, `mount` | `hp_after` is the TARGET's hp; miss ⇒ `hit:false, damage:0`. `mount` (M0) is the firing weapon's hardpoint, so the beam leaves that weapon. |
| `fire_burst` | `rounds`, `hits`, `damage`, `hp_after`, opt `lethal`, `mount` | rapid-fire tracers (gatling); per-round hit distribution is presentation's choice; totals are sim truth |
| `fire_missiles` | `count`, `hits`, `damage`, `hp_after`, opt `lethal`, `mount` | a guided salvo (missile rack); flight is cosmetic, totals are sim truth |
| `fire_buster` | `hit`, `damage`, `hp_after`, opt `lethal`, `mount` | a charged heavy capital-beam (beam cannon): charge-up then a thick beam |
| `overload` | `damage`, `hp_after`, `lethal` | M0 sudden-death reactor overload: escalating self-damage on `actor`'s own mech once the duel passes the sudden-death tick. Added by KM-M0-SIM; renderer shows it as the mech cooking off, and the kill-cam fires on any `lethal` event (beam or overload). |
| `destroyed` | — | terminal for that actor |

## Invariants the spike relied on

- Outcomes are entirely in the log; the renderer never rolls dice that matter.
- Coarse positions are enough: garnish (tracer paths, ricochet points) may embellish
  freely as long as hit/miss/damage/death match the log.
- Exactly one terminal event; everything after it is epilogue staging.
- Tick→seconds scaling is presentation-owned (the director may dilate time).
