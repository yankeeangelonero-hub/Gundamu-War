# CLAUDE.md — Kitbash Mecha

Working title: Kitbash Mecha
Repo: Gundamu-War
Owner: Xuanyue
Started: 2026-06-04 (as "Mech Bags"); pivoted through recursive kitbash to the current
pilot-fit + war-front direction on 2026-06-06.

## What this project is

Kitbash Mecha is a mech build-fighter with a pilot bond. The player is the partner
engineer, not the pilot: you kitbash a humanoid mech by slotting shaped parts into a single
spatial grid (a backpack), fit it out for a single persistent pilot you grow attached to,
then deploy that pilot into a living war and watch the deterministic duel resolve. The fantasy is a positive power
loop — building a feared ace — and the defining endgame is async PvP where your ace fights
other real players' stored builds in a contested war.

The build is a negotiation across three constraint layers, all running through the pilot:
machine engineering (power/heat/armor/weight — kept lean), pilot-machine fit (the star: a
soft capacity-vs-demand relationship expressed in combat as sync climbing toward a
breakthrough), and pilot behavior (smart defaults near-term; an opt-in rule layer later,
gated hard). Power is never free, but it is potential the pilot grows into, not a tax she
suffers — there is no permanent harm to the pilot.

This file is a pointer to the live design record, not the record itself. Read the wishlist
for intent and the work map for the plan before doing design or build work.

## Current build (v0.1, rebooted 2026-06-14)

The version line was rebooted for the Godot build. v0.1 is the backpack engineering gauntlet
over the proven 3D combat: the build is one unified spatial grid (not a part-tree), driven by
a single power battery economy with adjacency-transforming supports, bag expansions, and
recipes — the proven Backpack-Battles loop. The pilot-fit / sync layer that the vision above
calls the star is deliberately deferred to v0.2+; for v0.1 the pilot only supplies unique
items. The 3D combat viewer is proven and locked (guide: `fight_log_everything` +
`--director=hybrid`). Authoritative v0.1 design:
`docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md`. The vision above is
unchanged — only the build order moved.

The active first slice is M1 — the grid build editor + power economy
(`docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md`, designed
2026-06-14). It is built before the M0 build→fight sim because the editor is standalone-testable.
Damage uses PoE increased/more algebra; supports buff weapons in their authored slots; the build
dresses the shared `MechActor`. Currently awaiting the build-screen UI design (in Claude design),
then an implementation plan — no code yet.

## Context for agents

- The product target is Steam PC first and mobile-app compatible second. The build target is
  Godot 4.6 using GDScript; web export is optional for demos/playtests, not the primary
  product platform. C++ via GDExtension is the only sanctioned performance escape hatch. The
  choice is recorded in the stack ADR and is confirmed in practice via the Godot director spike.
- The earlier prototype under `prototype/` is plain-web JavaScript (`game-core.js` is a
  pure deterministic core, `app.js` is a DOM renderer). It is a reference to port into the
  Godot build, not the shipping codebase.
- The simulation is a pure, deterministic, renderer-agnostic core. Same build(s) + seed
  must produce the identical event sequence. Determinism is also the PvP enabler: a result
  must be reproducible so a headless re-simulation can verify it.
- Simulation and animation are separate concerns; keep them architecturally distinct so a
  fight can be skipped, replayed, or re-simulated server-side.
- Debugging a visual / camera / feel issue: INSTRUMENT AND MEASURE THE ACTUAL SIGNAL — do not
  infer behaviour from reading code or from proxy data. For camera bugs, log the real runtime
  camera per frame (position, look-direction, fov, per-frame Δpos and Δaim, and whether each
  subject is inside the frustum) via `main.gd --camlog` → `tmp/camlog.json`, then separate
  intentional changes (a spike AT a shot-index boundary = a cut) from artifacts (a spike WITHIN
  a shot = jerk). For movement/feel, log each actor's real integrated `velocity`, not the
  choreographer's waypoint positions. This is how the 2026-06-21 melee-camera jerk was actually
  solved (the framing was fine; the camera *velocity* was the bug) after several inferred guesses
  missed. Measure, change, re-measure.
- Combat-feel TUNING lives in the grammar, not scattered magic numbers. Two homes: (1)
  `scripts/sim/grammar_params.gd` — sim/choreographer constants (range bands, KNOCK, WEAVE,
  ORBIT_AMP, MOBILE_HEFT, STRAFE_AMP, …), each per-archetype overridable through a preset's
  `overrides:{CONST: value}` → `_param()`; (2) `scripts/director/shot_grammar.gd` (`ShotGrammar`)
  — render/camera params (`min_iso`, `dolly_cap`, `melee_radius_factor`, and the `feel` body
  curves heft→speed/accel/pose + tempo→gait that `mech_actor.apply_feel` reads). A new suit
  archetype is a DATA ROW in `data/grammar_presets.json` (heft/tempo/mode_mix/weapons/overrides) —
  no code. The four exchange modes + plant/strafe behaviours stay in code on purpose (a closed
  grammar vocabulary, not config). So: add an archetype = data; tune the response = edit one
  grammar resource (or override per-build); add a behaviour = code.
- Opponent builds are an injected data source behind one interface. The game simulates any
  build identically whether it came from a static file, a designer, or a real player. Near
  term, opponents are local seeded ghost builds shaped like real-player builds; there is no
  backend yet, but the architecture must not preclude the one the war endgame needs.
- Part, skill, gate, fit, ghost-build, and war-front definitions are data, not code.

## Key documents

| Document | Purpose |
|---|---|
| `docs/wishlist/wishlist.md` | The experience wishlist (r2) — authoritative record of intent. Read first. |
| `docs/wishlist/flows/` | Core-loop and homecoming user-flow diagrams. |
| `Research/Research Documents/research-synthesis-2026-06-13-gundam-uc-combat-feel.md` | **Combat-feel north star — camera work makes or breaks the game feel.** What makes combat read Gundam UC vs MechWarrior: verified camera principles (F4–F6, keep), the movement-model gap (F1–F3, the real fix), exchange-variety and scale staging. Read before ANY combat, camera, or fight-choreography work. Companions: `Research/Research Documents/research-synthesis-2026-06-15-weighty-mecha-multi-title-and-cockpit.md` (F11–F21: cadence-as-weight, cockpit lens, yield-by-weapon-class, across UC/0083/08th/Evangelion); `Research/Research Documents/research-synthesis-2026-06-16-director-grammar-lighting-color-lens-continuity.md` (F22–F40: lighting, color/grade, lens, spatial-continuity — the first-class director-grammar dimensions); and `agent-handoffs/handoff-2026-06-13-km-director-iso-hybrid-direction-and-barrage.md`. |
| `docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md` | Authoritative v0.1 design: the backpack engineering system (unified grid, power economy, synergy, recipes). Read first for current build. |
| `docs/pilot-and-war-front-high-level-spec-and-work-map.md` | The high-level spec + decomposition (work map) — invariants + the v0.2+ pilot-fit plan; see its 2026-06-14 rescope note. |
| `docs/adrs/2026-06-06-build-stack-decision.md` | Stack decision (Godot 4.6 + GDScript), confirmed in practice via the director spike. |
| `docs/slices/KM-STACK-SPIKE-godot-platform-confirmation.md` | Ready slice spec for the first Godot confirmation spike. |
| `agent-handoffs/claude-godot-km-stack-spike-prompt.md` | Claude Code implementation prompt for the Godot confirmation spike. |
| `output/kitbash-approved-0e22-payload/kb-art-manifest.json` | Current part/anchor manifest and sprite payload for the spike. |
| `Version Log.md`, `Roadmap.md`, `Kanban.md` | Version history, milestones, slice status. |

## Agents should not

- Add a backend, database, or network endpoint in the near-term prototype. Architect so the
  later backend is not precluded, but do not build it now.
- Use C# in the near-term build. Current direction is GDScript; C# can only be re-opened by a
  later stack decision if optional web export is fully abandoned. (The earlier "no 3D"
  constraint is lifted: the proven combat viewer is 3D Godot. The 2D-cutout assumption from the
  pilot-era plan no longer holds.)
- Add real Gundam IP, licensed names, or lore. Specifically no V-fin antenna, no split
  twin-eye visor, no RX-78 silhouette or trim. Original identity uses a mono-eye, a single
  visor band, or a full-face sensor plate.
- Inflict permanent harm on the pilot, or use a stress-as-punishment loop; the valence is
  positive (sync toward a breakthrough; the downside of a loss is slower growth).
- Let opponent provenance (static / designer / real-player) leak into the sim or renderer.
- Commit, push, or install dependencies without explicit instruction.

## Naming conventions

- Slices: `Slice-NN-kebab-name`
- Features: `FEAT-NNN`
- Behaviour invariants: `BEH-NNN`
- Architecture constraints: `ARC-NNN`
- Work-map artifact IDs use the `KM-` prefix (e.g. `KM-DEPLOY`, `KM-PILOT-FIT`).

## Roadmap sync — read on every commit

The shippable roadmap lives in `roadmap.json` (rendered to `roadmap.html` by `python -m roadmap_tree .`).
Node states: shipped · in-progress · ready · blocked · decision · locked · pending.

- BEFORE starting work: open the tree, find the READY node, copy its handoff prompt.
- ON a commit that advances a node: edit that node's `state` in `roadmap.json` — set `shipped`
  when its done-when is met and tests pass, or `in-progress` while it is still partial. Then
  recompute downstream: flip any node whose deps are now all shipped from `blocked` to `ready`.
  Re-run `python -m roadmap_tree . --sync` to re-stamp canon to HEAD.
- WHEN a new requirement or decision arrives: add a `decision` or `pending` node and do NOT graft
  it until reviewed and approved (use "Branch here" to draft it).
- If commits land without a re-sync, the board shows "OUT OF SYNC — N commits ahead"; click
  "Session Diff" to copy a brief that reconciles the tree from the real git diff.

States are never derived — the board shows exactly what `roadmap.json` says. Keep it the source of
truth for what is left to ship, not just git history.
