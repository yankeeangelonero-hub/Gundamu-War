# M1 — Build Grid + Power Economy — Design

Date: 2026-06-14
Status: Design approved in brainstorm. Pending: UI design (in Claude design) and an
implementation plan before any code.
Owner: Xuanyue
Branch: backpack-system-test
Upstream: docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md (the v0.1
backpack engineering design); root contract docs/pilot-and-war-front-high-level-spec-and-work-map.md.

M1 is the first slice of the v0.1 backpack engineering system: the build editor with the power
economy and a minimal adjacency, dressing the shared 3D mech. It is built in Godot inside the
existing director-spike project, so the build screen and the battlefield are one integrated
prototype sharing one mech. The live fight is the M0 follow-up; M1 stops at the build side.

## 1. Scope and success criteria

In scope: a 5×4 grid; placing shaped builder/spender/support items; the power economy totals;
adjacency where supports apply value modifiers (added/increased/more) to the weapons sitting in
their slots; per-item numbers on the grid; and the slotted weapons appearing on the shared 3D
mech via a mount cascade.

Out of scope (and why): the live fight (M0); behaviour transforms like fork/chain (M2 — M1
supports carry only value modifiers, not transforms, through the same slot model);
bag-expansion containers and recipes
(M2); armor/defense multipliers and the tank vector (M2); the shop, gauntlet, and lives (M3);
pilot unique items (M3); persistence and salvage (v0.2+).

Success: a player can place builders, weapons, and supports; watch each weapon's effective
damage and power-per-shot change as supports cover it; read the build's total pool and regen;
and see the slotted weapons mount on the 3D mech. Because there is no fight yet, M1's
standalone test is mechanical — placement, adjacency, the resolution math, and mounting all
correct. The judgement of whether a build is *good* genuinely arrives with the M0 fight, which
is by design: the spec teaches the economy by showing a power-starved mech go quiet, not by a
forecast panel.

## 2. Data model

Everything is data (the data-driven contract). A grid is a 5×4 cell array. An item occupies a
polyomino shape and can rotate; its shape and any buff-slots rotate together. There are three
item kinds in M1:

- Builder (reactor): shape, a `pool` contribution, and a `regen` contribution. Builders feed
  the whole build's economy; they are not adjacency-based.
- Spender (weapon): shape, `base_damage`, `base_power_cost`, `cadence`, a `preferred_mount`,
  and an ordered `fallback_mounts` list for the 3D cascade.
- Support: shape, an authored buff-slot layout (the cells, relative to the support, that it
  buffs), a `cost_multiplier` (may be below 1.0), and any of the damage modifiers
  `flat_added`, `increased`, `more`. A support buffs any weapon occupying one of its slots.

Defense/armor and other passive multipliers are deliberately absent from M1; they are the
tank vector and belong with M2's scaling work.

## 3. Resolution math

The resolver is a pure function of the placement — no rendering, no randomness — so M0's sim
can consume the identical output and reproduce it from {build, seed}. When anything moves, it
recomputes.

For each weapon, gather every support whose buff-slots cover any cell that weapon occupies,
then apply Path of Exile's increased-vs-more algebra:

```
effective_damage = (base_damage + Σ flat_added) × (1 + Σ increased) × Π (1 + more_k)
effective_cost   = base_power_cost × Π cost_multiplier
```

All `increased` from covering supports sum into one `(1 + Σ increased)` multiplier; each `more`
is its own multiplier and they all multiply together, which is where exponential scaling lives.
`flat_added` sums into the base. Cost multipliers multiply, so a tall stack of supports drives
per-shot cost up exponentially — the reactor's regen, not an artificial cap, is what keeps the
stack honest. Build totals are simply `total_pool = Σ builder pool` and
`total_regen = Σ builder regen`.

The screen shows per-item numbers only: each weapon's effective damage and power-per-shot, each
support's modifiers and multiplier, each reactor's pool/regen, plus the build's total pool and
regen. No sustain-versus-burst forecast — that legibility lands in the M0 fight.

## 4. Build-grid interaction

A 5×4 grid. Items come from a developer palette (there is no shop until M3). The player places
by drag or click, rotates with a key (shape and buff-slots rotate together), and removes an
item back to the palette. A placement is valid only when every cell is inside the grid and
empty — no overlaps. Any change re-runs the resolver and refreshes both the numbers and the 3D
mech.

## 5. 3D mech integration

M1 reuses the same `MechActor` the combat viewer drives — one mech node for the build screen
now and the fight later, which is the spec's defining hook made literal. The current fixed
attach code (the rifle and armor mounts) is generalised into a generic hardpoint registry:
named mounts (hands left/right, forearms, shoulders, hips, back booms) with enough generic
points to display a maxed loadout. Each placed weapon resolves to a mount by trying its
`preferred_mount` and, if that is taken, cascading down its `fallback_mounts` to the next free
hardpoint. M1 shows a static pose with placeholder block-out weapon meshes; because it is the
same mech node, M0 inherits these mounts for the fight.

## 6. Modules and how it sits in the integrated project

Everything lands in the existing Godot project alongside the combat viewer, preserving the
sim/render split:

- Item definitions as data (Godot Resource `.tres` or JSON under `data/`).
- BuildGrid — pure logic: grid state, placement validity, rotation. No rendering.
- BuildResolver — pure logic: placed items to per-weapon effective damage/cost and totals via
  the section-3 formula. A pure function, reused unchanged by the M0 sim.
- Build UI — a scene: the 5×4 grid, the dev palette, the per-item numbers.
- MechActor extension — the generic hardpoint registry and mount cascade, extending
  `mech_actor.gd`.
- Build screen scene — hosts the grid UI plus a 3D sub-viewport showing the shared `MechActor`.

BuildGrid and BuildResolver are renderer-agnostic, mirroring the existing core/render
discipline and setting up M0; the UI and the mech are presentation.

## 7. Testing

The project already runs headless check scripts under `tests/`. M1 adds: resolver unit tests
(a known placement resolves to the expected effective damage and cost under the increased/more/
flat formula, and the same placement always yields the same output); grid tests (in-grid and
no-overlap validity, and that rotation transforms both the shape and the buff-slots correctly);
and a mount-cascade test (N weapons resolve to the expected hardpoints, with fallback when a
preferred mount is taken).

## 8. Open and deferred

The 5×4 grid size is a working number and is meant to be retuned. The concrete support
catalogue — which supports exist and their flat/increased/more/cost-multiplier values — is M2
content and will be seeded from the owner's local PoE 2 support-gem reference
(G:\My Drive\Vault_2_0\Knowledge\Tech\PoE2), adapting mechanics and patterns, not names or lore.
The build screen's visual layout and interaction are being designed separately in Claude design
(see the M1 build-screen UI handoff); this document fixes the mechanics and data, not the look.
