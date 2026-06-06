---
project: kitbash-mecha
repo: gundamu-war
doc_type: high-level-spec
status: active
updated: 2026-06-06
---

# High Level Project Specifications — Kitbash Mecha

This is the enduring high-level frame for the project. The detailed, living requirements
live in two places that this document points to rather than duplicates: the experience
wishlist at docs/wishlist/wishlist.md is the source of truth for intent, and the work map at
docs/pilot-and-war-front-high-level-spec-and-work-map.md holds the detailed behaviour
invariants (BEH-D), architecture constraints (ARC-D), and global invariants (INV-D) for the
current direction. The features and constraints below are the stable ones meant to outlast
any single version.

## Project statement

Kitbash Mecha is a mech build-fighter with a pilot bond. The player is the partner engineer:
they kitbash a humanoid mech from a tree of snap-together parts, fit it out for a single
persistent pilot, deploy that pilot into a living war, and watch the deterministic duel
resolve without touching the controls. The loop is a positive power fantasy of building a
feared ace, and the defining endgame is async PvP in which the player's ace fights other real
players' stored builds in a contested war.

## Primary actors

| Actor | Role |
|---|---|
| `Engineer (Player)` | Kitbashes the mech, fits it to the pilot, weighs the deploy gamble, deploys, and reads outcomes. Never pilots in real time. |
| `Pilot` | A persistent character with a fit to the machine, sync in combat, skills, and growth. The thing the player is attached to. |
| `Opponent-build source` | Supplies an enemy build to simulate. Seeded ghost builds near-term; real players' stored builds in the war endgame. Provenance is invisible to the sim. |
| `Simulator` | Resolves builds (plus pilot fit and abilities) into a deterministic event sequence and result. |
| `War` | The macro state that battles feed and that biases deploy options; a local backdrop near-term, the PvP aggregate later. |

## Major components

| Component | Responsibility |
|---|---|
| `Kitbash build tree` | The recursive typed socket assembly the player edits; the build, the stat structure, and the rig in one tree. |
| `Pilot-fit + sync model` | Capacity-vs-demand fit, the pre-deploy readout, and in-combat sync climbing to a breakthrough. The differentiator. |
| `Machine engineering` | The lean substrate budget: power, heat, armor, weight. |
| `Deterministic simulator` | Pure, renderer-agnostic event resolution; reproducible from builds + seed; the PvP-verification enabler. |
| `Rig renderer` | Cutout 2D rig that mounts the built parts and plays one primary attack at a time. |
| `Run + growth state` | The persistent pilot, skills, sync ceiling, salvage, and growth across a run. |
| `Opponent-build source` | The injected interface supplying enemy builds. |

## Features (FEAT)

These are the enduring features; per-slice acceptance lives in the work map.

### FEAT-001 — Kitbash build tree
The player assembles a mech from a recursive tree of typed snap-together parts. The same tree
is the build, the stat structure the simulator reads, and the rig the renderer mounts.

### FEAT-002 — Pilot-machine fit and sync
A build is fit to a specific pilot. The pre-deploy readout shows how well she handles the
machine, and in combat a sync meter climbs toward a breakthrough when pilot and machine work
well together. Fit is a soft relationship, never a hard gate.

### FEAT-003 — Positive growth loop
Pilots grow from what the player does and from surviving stretch deployments. Growth rewards
reaching and novelty, never repetition, and never inflicts permanent harm; a hard fight's
downside is a slower road, not injury.

### FEAT-004 — Skill and part mutual gating
Pilot skills and installed parts gate each other: a skill may need a part, a part may need an
unlocked pilot ability, before either functions. Inert items are visibly marked inert.

### FEAT-005 — Deploy gamble
Before deploying, the player chooses between a safe fit for steady growth and pushing the fit
to chase a breakthrough at the cost of a harder fight.

### FEAT-006 — Watched deterministic duel
Battles resolve as a deterministic queue with one primary attack animation at a time. The
player watches; they do not drive.

### FEAT-007 — Living war and async PvP
Battles feed a war state. Near-term the war is local and opponents are seeded ghost builds;
the defining endgame is async PvP where the player's ace fights other real players' stored
builds, made fair by deterministic re-simulation.

## Behaviour invariants (BEH)

The enduring invariants; the current direction's detailed BEH-D set is in the work map.

### BEH-001 — Determinism
The same build(s) + seed produce the identical event sequence. This is both a fairness rule
and the enabler of verifiable async PvP.

### BEH-002 — One primary attack animation at a time
Playback shows one primary ready-attack animation at a time; simulation time does not advance
during it.

### BEH-003 — Positive valence
No game state inflicts permanent harm on the pilot. The in-combat meter is sync toward a
breakthrough, not stress toward a breakdown.

### BEH-004 — Legible outcomes
Any below-ceiling result is traceable on screen to fit and sync, never presented as
unexplained luck.

### BEH-005 — Inert, never half-functional
A skill whose required part is missing, or a part whose pilot ability is not unlocked, is
inert and visibly marked; it never half-functions.

## Architecture constraints (ARC)

The enduring constraints; the current direction's detailed ARC-D set is in the work map.

### ARC-001 — Simulation and animation are separable
Simulation is a pure, renderer-agnostic core, separable from animation, so a fight can be
skipped, replayed, or re-simulated server-side.

### ARC-002 — Opponent builds are an injected data source
The game simulates any build identically regardless of whether it came from a static file, a
designer, or a real player. Provenance never leaks into the sim or the renderer.

### ARC-003 — Data-driven definitions
Parts, skills, gates, fits, ghost builds, and war fronts are data, not code.

### ARC-004 — Stack and platform
The product target is Steam PC first and mobile-app compatible second. The build target is
Godot 4.6 with GDScript; web export is optional for demos/playtests, not the primary product
platform. No 3D. No backend in the near-term prototype, but the architecture must not
preclude the backend the war endgame needs.

### ARC-005 — No licensed IP
No Gundam names, factions, lore, or trademarked silhouettes — specifically no V-fin antenna,
no split twin-eye visor, no RX-78 silhouette or trim. Original identity uses a mono-eye, a
single visor band, or a full-face sensor plate.

## What is out of near-term scope

Recorded so it is not mistaken for the next build: web-first product support, the networked
backend and real-player opponents; the two-faction, game-master-steered live war with
developer events; a stable of
multiple pilots; slice-of-life relationship activities; the opt-in pilot-behaviour rule layer
and any visual AI beyond it; grunts in the field; and research as a second use for salvage.
These are wanted later; the wishlist holds them as deferred wishes.
