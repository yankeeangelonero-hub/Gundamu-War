---
project: kitbash-mecha
repo: gundamu-war
doc_type: kanban
status: active
updated: 2026-06-20
---

# Kanban — Kitbash Mecha

Slice-level status. **Fireworks first. Balance later.** The active direction (reframed
2026-06-20) is the **First Cinematic Combat Sandbox** — assemble two weapon loadouts, press
Fight, watch deterministic anime combat through the hybrid director. The balanced backpack
gauntlet is the richer build path that comes *after* the sandbox proves the fights slap.
Authoritative sandbox spec: docs/slices/CF-FIREWORKS-cinematic-combat-sandbox.md; backpack
design: docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md; root contract:
docs/pilot-and-war-front-high-level-spec-and-work-map.md (rescoped header). Pilot-fit deferred to
v0.2+. Items use CF- (cinematic) and KM- (work-map) IDs.

## In Progress — the sandbox route (do in this order)

### 1. [CF-CHOREOGRAPHER] Fix + land the combat choreographer
Stages the positionless truth log into spawn positions + advance beats so the director has a 3D
scene to film. Implementation exists uncommitted. **Blocker before landing (Ada):** a same-tick
precedence bug — when a reactive evade/stagger starts on the same tick as an ambient stride, both
`advance` events are emitted and `_eval_layered()` / `_active_advance()` (and director event
order) can pick ambient instead of the higher-priority reactive beat. Current 39 PASS misses it
because the tests avoid stride-boundary reactive windows. Fix it and add a stride-boundary
regression test before landing. Spec: docs/superpowers/specs/2026-06-17-combat-choreographer-design.md.

### 2. [CF-FIREWORKS] Fireworks baseline profiler + parity report
A spectacle profiler over the fight_log schema: emit each log's spectacle profile (intended
archetype/matchup shape, duration, event/attack density, longest dead-air gap, weapon mix,
heavy-beat count, defensive/reversal beats, movement/boost/stagger profile, director-beat
availability, finisher quality, taste verdict) and a comparison report against the baseline
`godot_director_spike/data/fight_log_everything.json` (23.1s, 101 events, 50 attacks, 48 advances,
10 boosts, full arsenal, lethal buster finish). Baseline is the fireworks floor, not a metronomic
mold. Tracking records archetype + spectacle shape, not only raw counts.

---

## Backlog — sandbox route (blocked on the above)

### 3. [KM-SANDBOX-SIM] Minimal weapon-combination sim (M0)
The smallest deterministic build-vs-build sim: two weapon combinations + a seed → a contract-valid
combat-truth event-log. Same loadouts + seed → identical normalized log byte-for-byte (BEH-D01);
no dead-air vs the fireworks floor. No grid economy yet — consumes a raw loadout so the sandbox
runs before the full M1 editor. Different archetypes (rifle/missile pressure, buster artillery,
saber/booster, shield/tank, mixed) must produce distinct logs and distinct staging reads.

### 4. [CF-ADAPTER] Wire sim → choreographer → hybrid director (v2→v1 adapter)
Wire the generated log through the choreographer into the locked hybrid director. A temporary
v2→v1 adapter is allowed if it is the shortest path to a rendered fight; full director migration
can follow.

### 5. [BUILD-PICKER] Crude build picker + fight launcher
A crude UI to choose/assemble two weapon loadouts and press Fight, launching the pipeline.
Minimal — not the full M1 grid editor. Re-running the same picks + seed replays the identical
fight.

### 6. [CF-SANDBOX] First Cinematic Combat Sandbox (first playable)
Generate at least three build archetypes (rifle+missiles, buster+shield, saber+booster) that are
deterministic, visibly different, and each carry director-usable beats (opening hero beat, mid
escalation, heavy/finisher, aftermath) with no dead-air failure and a baseline comparison report.
The v0.1 first-playable finish line.

---

## Parallel / richer build path

### [KM-BACKPACK-GRID] Grid + power build editor (M1) — ready, design done
The richer build editor and central engineering system (reshapes the old KM-ENG "lean Layer-1
budget"): a 5×4 grid, shaped builder/spender/support placement, the power battery economy
(builders give pool/regen, spenders cost power), support value-modifier adjacency
(added/increased/more with multiplicative cost multipliers) + authored adjacency transforms
(fork/chain/multishot), and the preferred-mount + fallback cascade that puts each slotted weapon
on the shared 3D mech. Standalone-testable; can proceed in parallel with the sandbox route but is
no longer the gate on the first playable — it is the deeper build surface the *later* gauntlet
needs. Design committed
(docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md). Next: build-screen
UI design (owner, in Claude design) → implementation plan → build. No code until the plan is
approved.

### [CF-FEEL-CONSUMERS] FeelProfile consumers — parallel polish
The director grammar and choreographer read each build's FeelProfile and bias their own params so
a loadout looks like itself on screen. Sharpens the sandbox's archetype reads; not a hard gate on
the first playable. Pure leaf (scripts/sim/feel_profile.gd) already shipped.

---

## Done

### Combat viewer / director spike — proven and locked
The Godot 4.6 director spike confirmed the engine and produced the combat viewer: procedural
block-out mechs, the full weapon arsenal (beam/burst/missiles/buster/melee), destructible
city, and the director grammars (cinematic, witness, broadcast, blend, iso, hybrid). The
hybrid grammar (iso base + cinematic intercut) is the chosen production direction. The locked
v0.1 gameplay-battles guide is `fight_log_everything` + `--director=hybrid`, with tuned boost
and kill cam. This also stands in for what was KM-WATCH. Art exploration (cel shading,
textured Gundam viewer) lives on branch spike/art-experiments; the prototype branch is the
block-out build. Look direction: realistic PBR.

---

## Deferred (v0.2+) — the pilot layer

Carried from the superseded v0.4 plan, to return on top of the v0.1 engineering core:

- [KM-PILOT] Persistent bonded pilot record + growth (no fresh-run reset).
- [KM-PILOT-FIT] Pilot-machine fit + the in-fight sync / breakthrough meter (re-enters as
  item behaviour). The wishlist's star, deliberately deferred.
- [KM-SALVAGE] Salvage acquisition — strip items off mechs you beat; ties the homecoming loop.
- [KM-DEPLOY] The deploy gamble (push for a breakthrough vs a safe fit) — a pilot-fit feature,
  deferred with the sync meter.
- [KM-WORKSHOP] / [KM-HOME] / [KM-THEATRE] — the loop screens around the pilot layer.
- Pilot-milestone grid expansion (grow the grid by growing the pilot, replacing shop-bought
  expansions).

---

## Done (historical — superseded browser prototypes)

Prototype 0.1 (bag-packing browser autobattler, all 7 slices), 0.2 (single-canvas theatre),
and 0.3 (recursive kitbash socket tree). The deterministic simulator and the
sim-versus-animation separation carry forward; the spatial surfaces (five bags, then the part
tree) were dropped or reshaped into the v0.1 single grid.

---

## Blocked / On Hold

<!-- Nothing blocked -->
