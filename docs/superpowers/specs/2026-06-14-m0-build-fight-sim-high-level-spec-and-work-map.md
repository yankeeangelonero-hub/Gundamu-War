# M0 — Build→Fight Sim — High-Level Specification and Spec Work Map

Date: 2026-06-14
Owner: Xuanyue
Branch: backpack-system-test
Status: COMPLETE 2026-06-14. KM-M0-SIM (+ KM-M0-OPP folded in) and KM-M0-VIEWER implemented and
tested; see 2026-06-14-km-m0-sim-feature-spec.md. DEPLOY SORTIE now runs the deterministic duel
against a seeded ghost, plays a human-scale establishing intro, then the fight in the proven
hybrid viewer, and returns to the (restored) bag. No director changes were needed — hybrid
already keys the kill-cam on any lethal event and ignores the `overload` kind in dispatch; the
intro + log injection live in main.gd gated by FightHandoff.active, so the standalone combat feel
is untouched (verified). Grilled via vouse-high-level-spec-decomposition on 2026-06-14.

OPEN (deferred, owner deferred during testing): mechs are the ~15m block-out; a literal 20m
resize would ripple into the locked combat framing and is not done — the intro conveys scale via
a human-eye-height (~1.7m) vantage instead. Also deferred: mounting the player's actual loadout
onto the FIGHTING mech (the fighter is still the standard block-out), and a bespoke overload
cook-off visual.
Upstream: docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md (v0.1 design);
docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md (M1, implemented);
docs/pilot-and-war-front-high-level-spec-and-work-map.md (root contract).

## Part I — High-Level Specification

## 1. Request

"Start the M0 fight." Build the deterministic build→fight simulation: turn two backpack
builds plus a seed into the event log the proven combat viewer already plays, run it from the
build screen's DEPLOY SORTIE, and watch the duel resolve. M1 builds and resolves a backpack;
M0 is the fight that backpack was for.

## 2. Request class

Mixed — **New system** (the deterministic sim core + opponent source) plus **Integration**
(wiring the build screen to the existing combat viewer through the event log).

## 3. Current pain

M1 lets the player assemble a backpack and reads out each weapon's effective damage and
power-per-shot, but there is no fight, so the player cannot tell whether a build is *good*.
This is by design: M1 deliberately deferred the sustain-versus-burst forecast to the fight,
on the principle that the economy is taught by watching a power-starved mech go quiet, not by
a forecast panel. Until M0 exists, that lesson can't land and the power economy is untested.

## 4. Desired outcome

- DEPLOY SORTIE on the build screen runs a deterministic duel between the player's build and a
  seeded ghost opponent, then plays the resulting fight in the proven combat viewer, then
  returns to the bag.
- The fight makes the **power economy legible**: a mech that mounted more guns than its reactor
  can feed visibly fires fewer shots — guns hang idle, the pool flatlines — so underperformance
  reads as an engineering choice, never as luck.
- A **sudden-death overload** guarantees a clean finish: after a time limit, an exponentially
  escalating damage-over-time burns both mechs until one dies, so no duel (even tank-vs-tank)
  stalls, and the mech that built better effective survivability outlasts the other.
- Determinism holds: the same two builds and the same seed always produce the identical event
  log, so a result can be re-simulated and verified (the async-PvP enabler).

## 5. Non-negotiable existing behaviors

- BEH-M0-N1 — The combat viewer's proven feel is locked. The director shot grammar, camera,
  movement, and garnish that make `fight_log_everything --director=hybrid` the north star must
  not regress. M0 may extend the renderer additively (handle a new event kind, treat any lethal
  event as the kill beat) but must not retune the existing combat feel.
- BEH-M0-N2 — `MechActor`'s combat path is untouched (its build_pose path is M1's; its fight
  path stays as the directors drive it).
- BEH-M0-N3 — The M1 resolver, grid, and mount cascade are consumed unchanged; M0 reads their
  output and adds nothing to the build-side math.
- BEH-M0-N4 — Determinism (BEH-D01 from root): same {buildA, buildB, seed} → identical event
  array, every run, headless or windowed.
- BEH-M0-N5 — Opponent provenance never leaks into the sim or renderer (CON-D03): the sim
  fights any build identically whether it came from a file, a designer, or a real player.
- BEH-M0-N6 — Positive valence (CON-D04): a loss is just a loss; no permanent harm modelled.

## 6. Allowed changes

- ALW-M0-1 — Extend the event contract with one new kind for the sudden-death overload tick
  (carrying damage, hp_after, and a lethal flag), additively. Existing kinds are unchanged.
- ALW-M0-2 — Add a build-fight controller/scene that injects an in-memory event log into the
  viewer instead of loading `res://data/fight_log.json`, and returns to the build screen when
  the fight ends.
- ALW-M0-3 — Teach a director to treat *any* lethal event (beam or overload) as the kill beat,
  so the kill-cam fires whether the killing blow is a shot or the overload.
- ALW-M0-4 — Introduce base HP and sudden-death parameters as data (tunable), since M1 has no
  HP and armor multipliers are M2.

## 7. Architecture constraints

- ARC-M0-1 — The sim is a pure, deterministic, renderer-agnostic core: a function of
  (resolved buildA, resolved buildB, seed) → event log. No node tree, no RNG outside a seeded
  generator, no wall-clock.
- ARC-M0-2 — Sim and presentation stay architecturally separate (the director's whole premise:
  the log is complete before playback).
- ARC-M0-3 — The opponent is one injected source behind the KM-OPP interface; the sim takes a
  resolved build and does not know its provenance.
- ARC-M0-4 — No backend, database, or network endpoint (root rule). Architect so the war-front
  backend is not precluded; build none now.
- ARC-M0-5 — Reuse the existing `MechActor` + a director for playback; do not build a second
  renderer.

## 8. Shared vocabulary

- tick / tick_seconds — integer ticks at 0.1s (matches the contract).
- resolved build — the M1 output a fight consumes: per-weapon {effective_damage, effective_cost,
  cadence, mount}, plus total_pool, total_regen, and base_hp.
- pool / regen — the battery economy: current power, refilled at regen per second, capped at pool.
- cadence — a weapon's seconds between shots (from its def).
- cooldown gate — a weapon fires when its cadence has elapsed AND pool ≥ effective_cost.
- overload / sudden-death — after sudden_death_tick, an escalating DoT on both mechs.
- ghost build — an opponent build served by KM-OPP.
- event log — the ordered `{tick, actor, kind, payload}` array (contract v1 + the overload kind).

## 9. Global invariants

- INV-M0-1 — Determinism: identical inputs → byte-identical event array (re-sim verifiable).
- INV-M0-2 — Outcomes live entirely in the log; the renderer never rolls dice that matter.
- INV-M0-3 — Exactly one terminal `destroyed`; the lethal event precedes it; everything after
  is epilogue staging.
- INV-M0-4 — The sim emits only data (no Godot nodes, no colors, no camera).
- INV-M0-5 — Legibility: when a build is power-starved, the log shows it (idle-gun gaps,
  flatlined pool) so the renderer can make it visible.
- INV-M0-6 — Sudden death always terminates the fight within a bounded number of ticks after
  sudden_death_tick (the DoT grows exponentially; HP is finite).

## 10. System surfaces

- BuildResolver / BuildMounts / BuildGrid (existing, M1) — produce the resolved build; consumed.
- BuildFightSim (new, pure) — the duel core; the heart of M0.
- OpponentSource / KM-OPP (new) — serves a resolved ghost build; small static pool for v0.1.
- Event log (existing schema + overload kind) — the sim's output, the viewer's input.
- Combat viewer scene + directors + MechActor + garnish (existing) — playback, reused.
- Build screen DEPLOY SORTIE (existing button) — the trigger.
- Build-fight controller/scene (new) — runs the sim, injects the log, plays it, returns.

## 11. Acceptance gates

- GATE-M0-1 — Headless determinism check: the same {buildA, buildB, seed} resolves to an
  identical event array across repeated runs.
- GATE-M0-2 — Termination check: from any starting HP, the sudden-death overload drives the
  fight to exactly one `destroyed` within a bounded tick budget.
- GATE-M0-3 — Power-starvation legibility check: a build whose weapons' summed cost-per-cadence
  exceeds regen fires demonstrably fewer shots over the fight than an idealised
  unlimited-power version of the same build (the economy actually bites).
- GATE-M0-4 — DEPLOY plays the fight in the combat viewer and returns to the build screen.
- GATE-M0-5 — Non-regression: the existing director/combat headless tests still pass, and a
  normal fight log renders with the proven feel unchanged.
- GATE-M0-6 — Opponent-source seam: swapping the ghost source for a different build (or a
  mirror) changes the fight but requires no change in the sim.

## 12. Open questions

- OQ-M0-1 (non-blocking) — Concrete numbers: base_hp, sudden_death_tick, overload base damage
  and growth factor. Proposed defaults to tune in play: base_hp 100; sudden_death at 45s (450
  ticks); overload starts at 1 dmg/tick and grows ×1.12 per tick on both mechs. Tunable data.
- OQ-M0-2 (non-blocking) — Does the hybrid director consume build-fights as-is, or does M0 add
  a small `buildfight` director variant? Recommendation: reuse hybrid; add only the lethal-any
  + overload handling (ALW-M0-3). Resolve during VIEWER work.
- OQ-M0-3 (non-blocking) — Log injection: in-memory hand-off via the controller (recommended)
  versus writing a temp `fight_log.json`. Recommendation: in-memory, since main.gd's file/cmdline
  path stays for standalone viewer use.
- OQ-M0-4 (non-blocking) — Minimal movement: the duel has no spatial gameplay, but the renderer
  expects some `advance` events to avoid frozen mechs. Recommendation: the sim emits a few
  deterministic, cosmetic approach/strafe advances (presentation scaffolding, not gameplay).

No blocking open questions.

## Part II — Spec Work Map

## 13. Candidate downstream artifacts

- KM-M0-SIM — **vertical feature spec.** The deterministic build-fight sim core: a pure
  function (resolved buildA, resolved buildB, seed) → event log. Owns the per-tick power
  economy (regen, cooldown+cost gating), damage application, the sudden-death overload, and
  emission of `spawn` / minimal `advance` / `fire_beam` (and `fire_burst` for fast cadence) /
  `overload` / `destroyed`. Includes the determinism, termination, and power-starvation
  headless checks (GATE-M0-1/2/3). Folds in the event-contract extension and the resolved-build
  input shape (small enough not to be its own spec).
- KM-M0-OPP — **foundation contract + data.** The KM-OPP opponent source: a one-method
  interface returning a resolved ghost build, plus a small static pool of hand-authored ghost
  builds as data. The sim consumes its output identically to the player's build.
- KM-M0-VIEWER — **integration contract.** The build↔viewer wiring: DEPLOY runs the sim, injects
  the in-memory log into a build-fight controller that drives the existing combat scene/director,
  plays the fight, and returns to the build screen. Owns ALW-M0-2/3 (injection + lethal-any /
  overload handling). Must not retune the proven combat feel.

## 14. Dependency graph

- KM-M0-SIM depends on: M1 resolver output shape (exists). Defines the event-contract extension.
- KM-M0-OPP depends on: the resolved-build input shape from KM-M0-SIM (so its ghosts match).
- KM-M0-VIEWER depends on: KM-M0-SIM (needs a real log to play) and the existing combat scene.

Drafting dependencies only: SIM first (it fixes the contract + input shape), then OPP and
VIEWER. OPP and VIEWER do not depend on each other.

## 15. Concurrency graph

- KM-M0-OPP and KM-M0-VIEWER can be built concurrently once KM-M0-SIM's event-contract extension
  and resolved-build input shape are fixed.
- They touch different surfaces (OPP = new data + interface; VIEWER = scene wiring + a director
  tweak), so concurrent work is safe. Both must avoid the must-not-touch surfaces in §18.

## 16. Shared contracts

- The **resolved-build input shape** (the dictionary the sim takes): owned by KM-M0-SIM,
  consumed by KM-M0-OPP and the build screen.
- The **event log schema** (contract v1 + `overload`): owned by KM-M0-SIM, consumed by
  KM-M0-VIEWER and the directors.
- The **KM-OPP interface**: owned by KM-M0-OPP, called by the build-fight controller.

## 17. Parent change proposal rules

A child artifact that discovers a needed change to this root (e.g. the sim needs a contract
kind not listed, or the viewer needs the combat feel changed) records a Parent Change Proposal
in its §0 and does not silently redefine M0. The orchestrator verifies against the repo, patches
this root + dependent siblings, and marks the PCP applied. Combat-feel changes are especially
gated (BEH-M0-N1).

## 18. Boundary escalation rules

Must-not-touch without escalation: the director shot grammar and tuned combat feel (additive
event handling only); `MechActor`'s combat path; the M1 resolver/grid/mount math; the M1 build
screen's existing behavior (DEPLOY may be wired to launch, but the bag UI must not regress). An
implementation unit that must cross one of these halts and writes a boundary escalation note.

## 19. Recommended downstream artifact order

1. KM-M0-SIM (vertical feature spec → vouse-writing-specs), including the contract extension,
   resolved-build input shape, and headless checks.
2. KM-M0-OPP (foundation contract + ghost data) — small; can run parallel to VIEWER after SIM.
3. KM-M0-VIEWER (integration contract) — after SIM produces a real log.

M0 is small. A defensible alternative is two vertical specs: SIM (with OPP folded in as a stub
source) then VIEWER. The orchestrator may collapse OPP into SIM at consolidation if it stays a
few lines of data.

## 20. Decomposition self-check

- [x] Original wording preserved (§1: "start the m0 fight").
- [x] Request class identified (§2: New system + Integration).
- [x] Current pain and desired outcome concrete (§3, §4) — grounded in the M1 deferral and the
  backpack design's legibility contract.
- [x] Non-regression behaviors have IDs (BEH-M0-N1..N6) — sourced from the combat-viewer north
  star memory and CLAUDE.md constraints.
- [x] Allowed changes have IDs (ALW-M0-1..4).
- [x] Architecture constraints have IDs (ARC-M0-1..5) — from CLAUDE.md sim/render split + root.
- [x] Global invariants have IDs (INV-M0-1..6).
- [x] System surfaces have IDs (§10) — existing M1/viewer surfaces verified in repo.
- [x] Candidate downstream artifacts typed honestly (§13: one feature spec, one foundation
  contract+data, one integration contract).
- [x] Decision spikes separated — none needed; no unresolved engine/library fork (the renderer
  and resolver exist). Open questions are tuning, not blockers.
- [x] Dependency graph is drafting-only (§14).
- [x] Concurrency graph present (§15).
- [x] Shared contracts named (§16).
- [x] PCP format present (§17).
- [x] Boundary escalation present (§18).
- [x] Downstream order present (§19).
- [x] Open questions marked blocking/non-blocking (§12: all non-blocking).
