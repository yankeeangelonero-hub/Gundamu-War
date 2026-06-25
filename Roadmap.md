---
project: kitbash-mecha
repo: gundamu-war
doc_type: roadmap
status: active
updated: 2026-06-20
---

# Roadmap — Kitbash Mecha

**Fireworks first. Balance later.**

The v0.1 immediate goal is a **First Cinematic Combat Sandbox / Fireworks Build**: the player
assembles or chooses weapon combinations for two mechs, presses Fight, and watches a
deterministic anime / UC-legible duel resolve through the locked hybrid director. The balanced
gauntlet — shop economy, hearts, run structure, long-run progression — is explicitly deferred
until the sandbox proves the fights slap. The version line was rebooted on 2026-06-14 for the
Godot build; the earlier v0.4 pilot-fit plan is deferred to v0.2+. The browser prototypes
(0.1–0.3) are superseded pre-history whose deterministic-sim foundation carries forward.

The roadmap runs two parallel tracks. **Combat-feel / cinematic direction** is now the lead
track: it carries the immediate sandbox route (choreographer → fireworks profiler → minimal sim
→ build picker → first playable). **v0.1 — Backpack engineering** is the richer build path
(the full grid editor) that the *later* gauntlet needs; it can proceed in parallel but is no
longer the gate on the first playable. The two meet at the build → fight seam: a resolved
loadout drives the deterministic sim, whose event-log the cinematic pipeline films.

## Doctrine — Gundam fight readability

> Target: Gundam fight readability. Different archetypes and match shapes must render
> differently: stomp, pitched duel, ranged pressure, melee chase, artillery finish, shield
> attrition.

This is the bar, not "a generic effects reel." Rifle/missile pressure, buster artillery,
saber/booster aggression, shield/tank attrition, and mixed-arsenal duels must each produce
distinct logs and distinct camera/staging reads. One-sided stomps and difficult pitched
battles are both valid outcomes — but they must look different on screen.

## Canonical pipeline + ownership

```text
build / weapon combination
→ deterministic build-vs-build sim
→ combat-truth event log
→ choreographer
→ staged fight log
→ hybrid director grammar
→ Godot rendering/frontend
```

```text
Truth decides what happened.
Choreographer decides where it happened.
Director decides how to see it.
Renderer makes it visible.
```

---

## Track: Combat-feel / cinematic direction (lead — the sandbox route)

Goal: make combat *read* Gundam UC — the camera work and direction are what make the game feel,
per the combat-feel research north star
(`Research/Research Documents/research-synthesis-2026-06-13-gundam-uc-combat-feel.md`). Much of
this track is already built and locked (CF-VIEWER); the frontier is the deterministic data-spine
that wires a *build* into the fight and the spectacle tooling that proves each generated fight
is worth filming. Authoritative slice spec for the sandbox route:
`docs/slices/CF-FIREWORKS-cinematic-combat-sandbox.md`.

### CF-VIEWER — Cinematic director + viewer grammar

**Status:** Built and locked. The hybrid director (isometric tactical backbone + cinematic
intercuts), the shot grammar (framing / timing / mood), the grade layer (lighting + colour mood),
sightline + X-ray occlusion handling, the time-emphasis arbiter, and the garnish VFX / hero-kill
spectacle are all implemented in `godot_director_spike/` and verified by the `tests/` check suite
(golden-hash regression on the hybrid shot list). Guide: `fight_log_everything --director=hybrid`.

**Done when:** (met) a hand-authored fight log renders as a directed, UC-legible cinematic fight
through the locked hybrid director.

### CF-CHOREOGRAPHER — Stage the truth log (FIRST on the route)

**Status:** Ready — implementation exists uncommitted; must be fixed before it is treated as
landed. Stages the positionless truth log into spawn positions + advance beats so the director
has a 3D scene to film, replacing hand-authored positions. Spec:
`docs/superpowers/specs/2026-06-17-combat-choreographer-design.md`.

**Known blocker (Ada) — fix before landing:** a same-tick precedence bug. When a reactive
evade/stagger starts on the same tick as an ambient stride, both `advance` events are emitted,
and `_eval_layered()` / `_active_advance()` (and director event order) can pick ambient instead
of the higher-priority reactive beat. The current 39 PASS misses it because the tests avoid
stride-boundary reactive windows.

**Done when:** a contract-valid log is staged into deterministic positions the director films,
**and** the same-tick precedence bug is fixed (reactive wins over ambient on a stride boundary in
both emission and active-beat lookup) with a regression test that exercises a stride-boundary
reactive window.

### CF-FIREWORKS — Spectacle profiler + parity report (SECOND on the route)

**Status:** Ready — slice spec drafted (`docs/slices/CF-FIREWORKS-cinematic-combat-sandbox.md`).
Spectacle-profile tooling: read any fight log (authored or generated) and emit its spectacle
profile, then compare a candidate against the fireworks baseline.

`godot_director_spike/data/fight_log_everything.json` is the authored fireworks baseline:
23.1s, 101 events, 50 attacks, 48 advances, 10 boosts, full arsenal, lethal buster finish. It
proves spectacle density and director usability. It is **not** the taste target — too metronomic,
too symmetric, light on defensive/reversal beats, no melee. Generated fights use it as a minimum
fireworks floor, not as a mold to mimic.

The profile records the **intended archetype / matchup shape and spectacle profile**, not only
raw event counts — see the slice spec's *Fight Log Tracking / Spectacle Profile* section
(matchup shape, dead-air gaps, weapon mix, heavy-beat count, defensive/reversal beats, movement
profile, director-beat availability, finisher quality, human taste verdict).

**Done when:** a profiler produces a spectacle profile for `fight_log_everything.json` and a
comparison report runs candidate-vs-baseline with a dead-air / spectacle-floor check.

### M0-SANDBOX-SIM — Minimal weapon-combination sim (THIRD on the route)

**Status:** Blocked on CF-CHOREOGRAPHER + CF-FIREWORKS. The smallest deterministic build-vs-build
sim: two weapon combinations + a seed → a contract-valid combat-truth event-log, then wired
`sim → choreographer → hybrid director`. A temporary v2→v1 adapter is allowed if it is the
shortest path. No grid economy required yet — it consumes a raw loadout so the sandbox can run
before the full M1 editor; later extended to consume the M1 grid build.

**Done when:** two weapon loadouts + seed resolve to a contract-valid log that the choreographer
stages and the hybrid director films; the same loadouts + seed reproduce the identical normalized
log byte-for-byte (BEH-D01); no dead-air failure vs the fireworks floor.

### BUILD-PICKER — Crude build picker + fight launcher (FOURTH on the route)

**Status:** Blocked on M0-SANDBOX-SIM. A crude UI to choose/assemble two weapon loadouts and
press Fight, launching the deterministic pipeline. Minimal — not the full M1 grid editor; just
enough to drive the sandbox and pick distinct archetypes.

**Done when:** a player can pick two loadouts, press Fight, and watch the generated cinematic
fight; re-running the same picks + seed replays the identical fight.

### CF-SANDBOX — First Cinematic Combat Sandbox (first playable)

**Status:** Blocked on the route above. The v0.1 first-playable finish line.

**Acceptance criteria:**

- Same builds + seed reproduce the identical event log (deterministic, re-simulable).
- A generated fireworks fight has no dead-air failure compared to the baseline.
- A generated fight offers director-usable beats: opening hero beat, mid escalation,
  heavy/finisher, aftermath.
- At least three build archetypes produce visibly different spectacle profiles **and** rendered
  reads — e.g. rifle+missiles (ranged pressure), buster+shield (artillery + defensive), saber+
  booster (melee chase).
- A comparison report exists for each generated fight against `fight_log_everything.json`.
- At least one generated fight includes a defensive/reversal beat; at least one a melee /
  close-range chase beat; at least one ends in a heavy/finisher beat with aftermath space.

**Done when:** the three archetypes above render as deterministic, visibly different,
UC-legible fights, each with a baseline comparison report. Gauntlet/shop/hearts start only after
this ships.

### CF-FEEL — FeelProfile per-build presentation lean (parallel polish)

**Status:** Designed; pure leaf built, consumers pending. A per-build cosmetic bias
`{heft, tempo, mode_mix}` — derived purely from a build's resolved stats — that makes a heavy
bruiser read heavy and a nimble gunner read nimble by modulating the director grammar and
choreographer, without touching combat truth. The pure function (`scripts/sim/feel_profile.gd`)
and its tests are built and committed; nothing consumes it yet. Spec:
`docs/superpowers/specs/2026-06-18-feel-profile-design.md`. Sharpens the sandbox's archetype
reads but is **not** a hard gate on the first playable.

**Done when:** the director grammar and choreographer read the per-mech FeelProfile and a build
visibly looks like itself on screen (the bias is no longer a dead leaf).

---

## Track: v0.1 — Backpack engineering (richer build path, parallel)

Goal: prove the backpack *engineering* is fun by building the proven Backpack-Battles loop — a
unified spatial grid, a power battery economy, adjacency-transforming supports, recipes, bag
expansions, three scaling vectors. This is the deeper build surface the *later* gauntlet needs.
It is standalone-testable and can proceed in parallel with the sandbox route, but it is no
longer the gate on the first playable. Authoritative design:
`docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md`.

### M1 — Grid + power build editor

**Status:** Ready — spec committed 2026-06-14
(`docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md`). Next: the
build-screen UI design (in Claude design), then an implementation plan, then build.

**Goal:** the richer build editor. A 5×4 grid; place shaped builder/spender/support items; a
single power battery economy (pool + regen); supports apply value modifiers (added/increased/more)
by adjacency to the weapons in their slots, and author adjacency transforms (fork/chain/multishot);
slotted weapons mount on the shared 3D mech. No live fight in this slice.

**Done when:** a player can place builders, weapons, and supports; see each weapon's effective
damage, power-per-shot, and authored transforms change as supports cover it; read the build's
total pool and regen; and see the weapons mount on the 3D mech. Resolver and grid are pure and
unit-tested.

### M3 — The gauntlet run (deferred behind the sandbox)

**Status:** Blocked — starts only after CF-SANDBOX ships. The balanced run: a shop phase
(buy, sell, reroll, combine, buy expansions) then a deterministic cinematic auto-battle against a
ghost opponent through the injected opponent source; a few hearts, a loss costs one, the run ends
at zero or at a win threshold; no persistence. The pilot is the Backpack-Battles hero — a starting
signature item and a small unique-item pool the shop can offer.

**Done when:** a tester can play a full escalating gauntlet — shop, build, fight, win or lose a
heart — and the engineering decisions feel like the fun, with the pilot-as-item-source toehold in
place for v0.2.

---

## Future (v0.2+ — not planned in detail)

The depth that follows the gauntlet: M2 — distinct tall/wide/tank scaling vectors and archetype
viability, bag-expansion container items, recipe/merge fusion at the round transition.

The pilot layer returns on top of the v0.1 engineering core: the in-fight sync / breakthrough
meter (re-entering as item behaviour), a persistent bonded pilot with no fresh-run reset, salvage
acquisition (strip items off mechs you beat), and grid expansion through pilot milestones rather
than purchase. This is where the deferred v0.4 pilot-fit direction lands.

Further out, no dates: the networked backend for real-player ghosts and async-PvP; the
two-faction GM-steered live war; a stable of multiple pilots; the opt-in pilot-behaviour rule
layer; grunts in the field; research as a second use for salvage.

---

## Changelog

- 2026-06-20 — Reframed the v0.1 immediate goal to **First Cinematic Combat Sandbox / Fireworks
  Build** (fireworks first, balance later). Promoted the Combat-feel track to lead and added the
  sandbox route: CF-CHOREOGRAPHER (fix same-tick precedence bug first) → CF-FIREWORKS (spectacle
  profiler + baseline parity) → M0-SANDBOX-SIM (minimal weapon-combination build-vs-build sim,
  v2→v1 adapter allowed) → BUILD-PICKER (crude launcher) → CF-SANDBOX (first playable, 3 distinct
  archetypes). Added the Gundam-fight-readability doctrine and the spectacle-profile tracking
  pointer. Demoted the backpack-engineering track to the richer build path feeding the later
  gauntlet; M3 gauntlet/shop/hearts now deferred behind the sandbox proof. New slice spec:
  `docs/slices/CF-FIREWORKS-cinematic-combat-sandbox.md`.
- 2026-06-18 — vouse-managing-versions — Added the **Combat-feel / cinematic direction** track
  (CF-VIEWER built/locked, CF-SPINE designed, CF-FEEL designed + leaf built) to track the
  previously-untracked combat presentation data-spine; reframed the intro as two parallel tracks
  meeting at the build → fight seam. (Formal version bump + `check_roadmap.py` validation not run:
  this repo has the Vouse doc artefacts but not the helper scripts / version-frontmatter contract.)
