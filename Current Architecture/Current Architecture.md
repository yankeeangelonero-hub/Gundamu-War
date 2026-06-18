---
project: kitbash-mecha
doc_type: architecture
version: "0.1"
status: as-built
updated: 2026-06-18
---

# Current Architecture — Kitbash Mecha (Godot build)

> As-built state of the Godot 4.6 / GDScript build under `godot_director_spike/`, the canonical
> codebase. What is built today is the **3D combat viewer** — the proven, locked presentation
> pipeline that turns a fight event-log into a directed cinematic fight. The backpack engineering
> system (v0.1 gameplay, M1), the build-driven fight sim (M0), the combat choreographer, and the
> FeelProfile consumers are **designed but not built** — they appear below with a `[not built yet]`
> marker so readers can tell intent from reality. The superseded browser prototype (the original
> Mech Bags v0.1, 2026-06-04) is retained as an archived appendix and is the deterministic-core
> reference to port.
>
> Status markers per component: `[built]` (in code, committed, on `combat-feel-restart`),
> `[not built yet]` (designed, no implementation), `[deprecated]` (superseded). The sibling
> `Actor Flows.md` describes the same as-built state per actor.

## Overview

The combat viewer is a **log-driven cinematic pipeline**. A fight is a sequence of pre-decided
events; the viewer reads that log and stages, films, and dramatizes it. Simulation (what happens)
and presentation (how it looks) are kept architecturally separate (ARC-001): the log is the
contract between them, and nothing in the presentation layer writes back into it.

The data flow as built:

```
fight_log_*.json  (hand-authored event log — the truth)
      │
      ▼
Director.build_shot_list(events, dur, grammar)   ── pure: events → ordered shot list
      │
      ▼
Director (runtime)  ── dispatches each event, drives camera through the shot list, owns time scale
      │   │   │
      │   │   └─► MechActor A/B   ── locomotion + animation (walk, fire, melee, recoil, die)
      │   └─────► Garnish         ── VFX/spectacle (beams, blasts, hero-kill), reads events read-only
      └─────────► Grade           ── lighting + colour mood, reads events read-only
      │
      ▼
rendered frames (+ CityBuilder environment, ShotGrammar parameters)
```

`main.gd` wires it together and is the single point that constructs the one `ShotGrammar` instance
that flows to the shot generator, the runtime camera, Grade, and Garnish.

---

## Component map (as-built)

### Fight Log + event schema — `[built]`

`scripts/fight_log.gd`. Loads, sorts, and validates a fight-log JSON into an ordered event array,
and computes fight duration. It defines the event contract every other component reads:

- Required fields per event: `tick`, `actor`, `kind`, `payload`.
- Event kinds: `spawn`, `advance`, `fire_beam`, `fire_burst`, `fire_missiles`, `fire_buster`,
  `melee`, `destroyed`.

Fight logs are currently **hand-authored** data files under `data/` (`fight_log.json` plus themed
variants — `_everything`, `_barrage`, `_melee`, `_duel`, `_guns`, `_air`, etc.). The locked
showcase guide is `fight_log_everything` under `--director=hybrid`. Pure; no engine or render
dependencies.

### Director — `[built]`

`scripts/director.gd`. Two responsibilities in one file, kept separate:

- **Shot-list builder** (`build_shot_list`, pure/static): pre-reads the whole log and emits a
  time-contiguous list of shots covering `[0, dur]` — a fixed wide open, over-shoulder on the first
  beam, killcam (slow-mo) on the lethal beam, punch-in on a blocked beam, dolly/two-shot fills, and
  an orbit tail over the wreck. No nodes, no RNG, no engine deps.
- **Runtime playback** (`start`/`_process`/`_dispatch`/`_update_camera`): binds the two mechs as an
  aimed combat pair, walks the event list, calls the matching `MechActor` method per event kind,
  emits a `fight_event` signal (consumed by Garnish and Grade), drives the camera per the active
  shot's mode, and owns the time scale (bullet-time / hitstop). Includes an X-ray occlusion gate
  that fades building windows when silhouette rays from camera to mech are blocked.

### Shot Grammar — `[built]`

`scripts/director/shot_grammar.gd`. The single authored home for every camera/timing/mood
parameter: per-mode framing (pullback, lateral, height, fov, roll), bullet-time dilation, hitstop
and impact-frame timing, lighting fill, mood variants (base/hero/death), weapon-class → kill-tier
yield table, lens compression, composition-search arc, and X-ray radius. `yield_tier(kind)` is a
pure lookup. Constructed once in `main.gd` and passed to every consumer as the single source of
truth.

### Director grammar helpers — `[built]`

- `scripts/director/time_emphasis.gd` — pure arbiter: given (in-bullet-time, damage, threshold)
  exactly one of `bullet`/`hitstop`/`impact`/`none` owns a contact beat.
- `scripts/director/sightline.gd` — pure multi-ray occlusion test (camera → subject silhouette
  points vs building AABBs) returning a clear-ray count and the occluders; used for occlusion-free
  composition.
- `scripts/director/grade.gd` — the lighting + colour layer. Binds a `WorldEnvironment`, applies a
  base grade (a non-black shadow fill), and eases toward an event-driven mood (`fire_buster` → hero,
  lethal/`destroyed` → death). Reads `fight_event` read-only on wall-clock time (immune to
  hitstop/bullet-time); never writes back to the sim.

### Director variants — `[built]`

`scripts/directors/` — each extends the base director and overrides the shot list and camera modes
to express a distinct grammar: `hybrid` (**production** — isometric tactical backbone with
cinematic intercuts: over-shoulder opening, hero cut, melee close-ups, bullet-time kill,
composition search, mood grade), plus the experimental `broadcast`, `witness`, `blend`, `iso`, and
`cinematic` (a thin base passthrough). The locked viewer is `hybrid`.

### Garnish (VFX) — `[built]`

`scripts/garnish.gd`. The event-driven spectacle layer. Pre-reads the log to schedule charge-up
glows before each beam, then on each `fight_event` routes to the matching effect: beam tracers with
muzzle/impact flash and building detonation, burst/missile fans (seeded spread), melee clash
sparks, and the tier-scaled `hero_kill`/buster spectacle (a capital "fear beat" at the top tier).
It triggers hitstop via `Engine.time_scale` transients and feeds camera shake. Reads outcomes from
payloads and grammar; it decides nothing and never writes the sim. Seeded RNG keeps it
deterministic per seed.

### MechActor (locomotion + animation) — `[built]`

`scripts/mech_actor.gd`. The visual mech: either procedural block-out geometry or a rigged Mixamo
model. Owns a momentum-based velocity integrator (capped accel, boost impulse with cooldown,
combat facing that keeps the gun on the enemy while strafing, footfall cadence). The director
drives it through `walk_to`, `face_toward`, `recoil`, `flinch`, `block_pose`, `melee_strike`,
`clash_lock`, `knockback`, `parry`, and `die`. The integrator owns position (the rigged model's
root translation is stripped); animation playback is chosen from velocity. Deterministic — its only
external inputs are log-driven targets.

### CityBuilder (environment) — `[built]`

`scripts/city_builder.gd`. Procedurally generates the night-city grey-box (seeded: 60 buildings +
gate towers, ~40% with emissive X-ray windows, each registered with an AABB used for beam
detonation and the occlusion test) and the `WorldEnvironment` (filmic tonemap, bloom, volumetric
fog, SDFGI, moon light). Seeded and deterministic; built once at setup.

### Main (entry + wiring) — `[built]`

`scripts/main.gd`. The entry point. Parses CLI flags (`--director=`, `--log=`, `--armor`, `--mesh`,
`--still`, `--frames`), builds the city + environment, spawns the two mechs and the camera,
constructs the single `ShotGrammar`, calls the selected variant's `build_shot_list`, instantiates
and starts the director, then binds Grade, Garnish, and audio. Quits on the `fight_over` signal.

### FeelProfile — `[built]` (leaf, no consumers yet)

`scripts/sim/feel_profile.gd`. A pure, static per-build presentation-bias function:
`derive(build) → {heft, tempo, mode_mix}` from a build's resolved feel-stats (weight, armor, and
per-weapon cooldown / pre-sim damage / mode weights), with monotonic axes, `[0,1]` bounds, and a
uniform fallback for empty/zero-damage builds. It is cosmetic, deterministic, never combat truth,
and never read by the sim. **It has no consumers in code today** — nothing references it outside
its own test; the choreographer and grammar hooks that would apply its bias are not built (below).
Spec: `docs/superpowers/specs/2026-06-18-feel-profile-design.md`.

---

## Designed but not built — `[not built yet]`

These have authoritative design specs but no implementation on this branch. They are listed so the
as-built picture is not mistaken for the full plan:

- **Build-driven fight sim (M0)** — `{build, seed} → fight log`, replacing the hand-authored logs
  with the same event contract; pure, deterministic, headless re-simulable. Today the logs are
  authored by hand. (`KM-CORE-PORT`.)
- **Backpack grid + power economy (M1)** — the unified spatial grid build editor and power battery
  economy; the v0.1 gameplay layer that produces the build the sim consumes and the FeelProfile
  reads. (`docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md`.)
- **Combat choreographer** — `build/log → spawn positions + advance beats`, the staging layer that
  turns a positionless truth log into a 3D scene for the director to film. Today the director is
  wired straight to the mechs with no staging layer.
  (`docs/superpowers/specs/2026-06-17-combat-choreographer-design.md`.)
- **FeelProfile consumers** — the Director Grammar and Choreographer reading the per-mech
  `{heft, tempo, mode_mix}` and biasing their own params (framing/cadence, stride/boost/ring). The
  `ShotGrammar` is static authored constants today, with no bias hook.

---

## Determinism boundary

Simulation is separable from rendering (ARC-001), evidenced by the pure, render-free units: the
fight log loader (`fight_log.gd`), the shot-list builder (`director.gd` `build_shot_list`), the
occlusion test (`sightline.gd`), the time-emphasis arbiter (`time_emphasis.gd`), and the FeelProfile
(`sim/feel_profile.gd`) are all pure and have no scene/render dependencies. The presentation layer
only reads: Garnish and Grade subscribe to `fight_event` read-only, the `MechActor` integrator takes
only log-driven targets, and nothing writes back to the log. Same log (+ seed for seeded VFX/city)
produces the identical fight every run. This is the property the war-endgame PvP needs: a result
can be re-simulated headless to verify it.

The test suite under `tests/` evidences what is built (all are headless `extends SceneTree` checks,
exit 0 = pass): `director_check`, `hybrid_check` (golden-hash regression), `shot_grammar_check`,
`time_emphasis_check`, `sightline_check`, `grade_check`, `iso_check`, `witness_check`, `blend_check`,
`broadcast_check`, `coherence_check`, `continuity_check`, and `feel_profile_check`.

---

## Architecture constraints in force

See `High Level Project Specifications.md` for the full ARC list. ARC-001 (simulation and
presentation must be separable) holds in the Godot build via the fight-log contract. The earlier
prototype-era constraints framed in browser terms are reinterpreted for Godot in the High Level
Spec; this document does not redefine them.

---

## Archived — superseded browser prototype (Mech Bags v0.1, 2026-06-04) — `[deprecated]`

The original Current Architecture documented the plain-web JavaScript prototype under `prototype/`
(`game-core.js` = a pure UMD deterministic core with no DOM; `app.js` = a DOM controller;
`prototype/tests/core-tests.js` = 66 Node assertions). It was a single-page browser game: five
per-body-part bag grids, a shop/run loop, an ATB battle simulator producing a deterministic event
list, and a **2D Battle Viewer** animating that list with CSS/Web Animations. It established the
three-layer separation (data / simulation / presentation) and the determinism guarantee carried
forward here.

It is **superseded** by the Godot build above and is retained only as the deterministic-core
**reference to port** (per CLAUDE.md). The full as-built prototype component detail is preserved in
git history (this file prior to 2026-06-18) and in `prototype/`. No part of the prototype is the
shipping codebase.
