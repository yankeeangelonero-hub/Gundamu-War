---
project: kitbash-mecha
doc_type: actor-flows
version: "0.1"
status: as-built
updated: 2026-06-18
---

# Actor Flows — Kitbash Mecha (Godot build)

How actors interact with the as-built Godot build under `godot_director_spike/`. See
`Current Architecture.md` for component detail. What is built today is the **combat viewer**: there
is no interactive build/shop/battle gameplay loop yet — that is designed (v0.1 backpack) but
`[not built yet]`. Status markers: `[built]`, `[not built yet]`, `[deprecated]`.

---

## Actor: Operator (developer / showcase) — `[built]`

The only human actor in the current build. Drives the viewer from the command line; there is no
in-app interactivity beyond pause.

### Flow — Run a directed fight

```
Operator launches main.gd with CLI flags
    → --director=<hybrid|broadcast|witness|blend|iso|cinematic>   (default cinematic; hybrid is locked)
    → --log=<name>                                                (default fight_log.json)
    → optional: --armor (full-armor loadout), --mesh (rigged model),
                --still (one frame then exit), --frames (periodic PNG capture)

main.gd boots the scene
    → CityBuilder builds the seeded night-city + WorldEnvironment
    → Two MechActors (A/B) and the camera are spawned
    → FightLog.load_events() loads + validates the chosen log
    → One ShotGrammar is constructed (single source of truth)
    → The director variant's build_shot_list() pre-computes the shot sequence
    → Director.start() binds the mechs as an aimed combat pair and begins playback

Playback runs
    → Director walks the event list, calls MechActor methods per event kind,
      drives the camera per the active shot mode, owns the time scale (bullet-time / hitstop)
    → Garnish dramatizes each event (beams, blasts, hero-kill); Grade eases lighting/colour mood
    → On the lethal blow → killcam / hero-kill spectacle, then an orbit tail over the wreck

Fight ends
    → Director emits fight_over → main.gd fades and quits
    → (--still / --frames capture stills for review instead of/along the way)
```

### Flow — Verify the viewer (headless checks)

```
Operator runs a check headless
    → ~/.local/bin/godot --headless --script res://tests/<name>_check.gd
    → Each check is an `extends SceneTree` script; prints PASS/FAIL per assertion; exit 0 = all pass
    → hybrid_check carries a golden-hash regression guard on the production shot list
```

---

## Actor: Fight log (data source / truth) — `[built]`

### Flow — Supply the fight truth

```
The viewer requests a fight log (the --log flag)
    → A hand-authored data/fight_log_*.json provides the ordered event truth
    → Each event: { tick, actor, kind, payload }; kinds = spawn / advance / fire_beam /
      fire_burst / fire_missiles / fire_buster / melee / destroyed
    → The log is the contract between simulation and presentation: the viewer never writes it back
    → Same log (+ seed for seeded VFX/city) → identical fight every run (ARC-001 determinism)
```

> The producer of this log is currently a human author. The build-driven sim that will emit it from
> `{build, seed}` is `[not built yet]` (M0, KM-CORE-PORT).

---

## Actor: Player (build / shop / battle gameplay) — `[not built yet]`

The interactive v0.1 gameplay loop — placing shaped items into the unified backpack grid against a
power economy, the shop/run gauntlet, and watching the resulting build fight a ghost opponent — is
designed but not implemented on this branch. Authoritative design:
`docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md` and the M1 grid editor
spec. When built, the player's build flows: backpack grid → resolved build → (FeelProfile bias +
build-driven sim) → fight log → the combat viewer above.

## Actor: Opponent build source — `[not built yet]`

The injected interface supplying the ghost opponent each round (seeded ghost builds now,
network-shaped later; provenance never leaks into sim or renderer) is designed, not built.

---

## Cross-actor interaction summary (as-built)

```
Operator  ──CLI flags (director + log)──►  main.gd
main.gd   ──builds──►  CityBuilder, MechActor A/B, Camera, ShotGrammar
main.gd   ──load──►  FightLog  ──events──►  Director.build_shot_list ──shots──►  Director (runtime)
Director  ──per event──►  MechActor A/B (locomotion/animation)
Director  ──fight_event (read-only)──►  Garnish (VFX), Grade (lighting/mood)
Director  ──fight_over──►  main.gd (fade + quit)
```

---

## Archived — superseded browser-prototype flows (Mech Bags v0.1, 2026-06-04) — `[deprecated]`

The original Actor Flows described the plain-web JavaScript prototype under `prototype/`: a Player
who opened a single HTML file, bought items, dragged them into five per-body-part bag grids, bought
bag expansions, and clicked Battle; a Battle Simulator that produced a deterministic ATB event list
from two builds + a seed; a **2D Battle Viewer** that animated that list; an Opponent Build Pool
returning static builds by round; and a Design Reviewer who played the running prototype. Those
flows are **superseded** by the Godot build above; the prototype is retained only as the
deterministic-core reference to port (see `Current Architecture.md` archived appendix and git
history prior to 2026-06-18).
