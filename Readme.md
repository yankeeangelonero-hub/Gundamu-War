---
project: kitbash-mecha
repo: gundamu-war
doc_type: readme
status: active
updated: 2026-06-14
---

# Kitbash Mecha

Kitbash Mecha is a mech build-fighter with a pilot bond. You play the partner engineer, not
the pilot. You kitbash a humanoid mech by slotting shaped parts into a single spatial grid (a
backpack), fit it out for a single persistent pilot you grow attached to, then deploy that
pilot into a living war and
watch the battle resolve on its own. You cannot touch the controls once she is out there;
the tension is whether the machine you built and the pilot you grew can win the fight you
sent them into.

The pull of the game is a positive power loop. You are building toward an unstoppable ace,
and the defining endgame is a war where your ace fights other real players' machines —
their builds, pilots, and tactics — in a persistent, contested front. Power is never free,
but it is potential the pilot grows into rather than a tax she suffers, and there is no
permanent harm to the pilot; the worst outcome of a hard fight is a slower road, not a
broken friend.

Under the surface, a build is a negotiation across three layers. Machine engineering is the
substrate — power, heat, armor versus firepower, weight — kept lean. Pilot-machine fit is
the star: can this pilot, at her current ability, control this machine? Build it too
demanding and she fights the mech instead of fighting with it, expressed in combat as a sync
that climbs toward a breakthrough when pilot and machine click. Pilot behavior is how she
decides to fight in an async, spectated battle; it ships as smart defaults now, with an
opt-in rule layer later. The whole thing rests on a deterministic simulation: the same build
and seed produce the same fight every time, which is also what makes a fair, verifiable war
against other players' stored builds possible.

## Where the project is

The version line was rebooted on 2026-06-14. v0.1 is the backpack engineering gauntlet over
the proven 3D combat: the build is one unified spatial grid (not a part-tree), with a power
battery economy, adjacency supports, expansions, and recipes — the proven Backpack-Battles
loop. The pilot-fit star described above is deliberately deferred to v0.2+; for v0.1 the pilot
only supplies unique items. The authoritative v0.1 design is
docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md; the long-term vision
still lives in docs/wishlist/wishlist.md and the work map (with its 2026-06-14 rescope note) at
docs/pilot-and-war-front-high-level-spec-and-work-map.md.

The active first slice is M1, the grid build editor plus power economy
(docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md). It is built
before the build→fight sim because the editor is standalone-testable. The 3D combat itself is
already proven and locked — the guide is the full-arsenal showcase run with
`--director=hybrid` — and the build screen dresses the same mech you watch fight, so it is one
integrated Godot prototype.

The product target is Steam PC first and mobile-app compatible second. The build target is
Godot 4.6 using GDScript, chosen after evaluating the engine against the rigged-2D kitbash,
the effects pipeline, deterministic simulation, native desktop/mobile release paths, and the
server-side re-simulation the war endgame needs; the reasoning is in
docs/adrs/2026-06-06-build-stack-decision.md and is confirmed in practice via the Godot
director spike. Web export is optional for demos/playtests, not the main product target. The
earlier plain-web prototype under prototype/ is kept as the deterministic-core reference to
port (for the M0 build→fight sim), not as the shipping code.

## Constraints that hold across the project

There is no licensed Gundam IP anywhere — no V-fin, no split twin-eye visor, no RX-78
silhouette or trim; original identity uses a mono-eye, a single visor band, or a full-face
sensor plate. (The earlier no-3D constraint is lifted: the proven combat viewer is 3D Godot.) The near-term prototype runs locally with no backend, and opponents
are local seeded ghost builds shaped like real-player builds; the backend the war endgame
needs is a later addition the architecture must not preclude. Web-first product constraints
are out of scope unless explicitly re-promoted. The simulation stays pure,
deterministic, and separate from the animation that plays it back.
