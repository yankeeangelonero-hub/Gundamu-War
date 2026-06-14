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
