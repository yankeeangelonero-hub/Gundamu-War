# Claude Code Handoff — Vouse Scaffold for Mech Bags

Date: 2026-06-04
Owner: Xuanyue
Target root: `D:/Claude/Mech Bags`

## Task

Use the Vouse project-start workflow to scaffold a new Vouse project for the game concept below. This is a project/spec scaffolding task, not implementation. Do not create application source code yet.

If Claude Code has Vouse skills installed, invoke/use the relevant Vouse skills naturally: `vouse-start-project`, `vouse-project-docs`, `vouse-research`, `vouse-slice-lifecycle`, and roadmap/Kanban rendering conventions. If those skills are not installed in your environment, reproduce the Vouse artifact structure faithfully from the requirements below and state in your completion report that you used the written handoff instead of an installed skill.

## Required output tree

Create/fill these project documents under `D:/Claude/Mech Bags`:

- `CLAUDE.md`
- `Readme.md`
- `High Level Project Specifications.md`
- `Roadmap.md`
- `Version Log.md`
- `Kanban.md`
- `Current Architecture/Current Architecture.md`
- `Current Architecture/Actor Flows.md`
- `Research/Research Catalogue.md`
- `Research/wishlist.md`
- `Research/flows/` with at least one Mermaid flow document for the core run loop and one for ATB battle playback
- `Project Version/Version 0.1/Version 0_1 Project Specifications.md`
- `Project Version/Version 0.1/Slices/` with draft slice specifications for Version 0.1
- `agent-handoffs/claude-design-ui-requirements.md` must be preserved; do not overwrite it if it exists.

Use Vouse-style frontmatter on docs where appropriate. Keep prose concrete and checkable. Avoid speculative lore beyond what is needed for the prototype.

## Project identity

Display name: `Mech Bags`
Slug: `mech-bags`
One-sentence statement: `Mech Bags is a browser-based HTML prototype for a Backpack Battles-style async autobattler where players arrange shaped mech parts across five body-part bags, upgrade individual bag sizes, then watch 2D sprite battles resolve through a paused ATB animation queue.`

## Product brief from owner conversation

Xuanyue wants a simple Version 0.1, explicitly not a complex mech simulator.

Core concept:

- Shamelessly faithful to Backpack Battles, but with five separate bags instead of one backpack.
- The five bags are mech body parts: `Head`, `Torso`, `Back`, `Left Arm`, `Right Arm`.
- Items are shaped pieces placed into these bags.
- Bag expansions force the player to upgrade different parts of the mech, e.g. add space to Head instead of Right Arm.
- Do not restrict items by body part. If a player wants a beam rifle on the head, allow it.
- Adjacency bonuses should be Backpack Battles-like and should apply within the same bag.
- The prototype should be an HTML/browser prototype with 2D sprites.
- Battle animation should test an ATB-like event system: time advances until an attack is ready; time pauses; the weapon animation plays; the effect resolves; time resumes; the next ready animation plays.
- Async opponent behavior can be faked initially with saved/prebuilt enemy builds; no backend/accounts needed in Version 0.1.

## Primary actors

1. `Player` — enters the browser prototype, buys/places parts, expands bags, launches battles, and reads results.
2. `Opponent Build Pool` — supplies deterministic saved/prebuilt builds for async battles in Version 0.1.
3. `Battle Simulator` — resolves builds into an ATB event sequence and battle result.
4. `Design Reviewer` — uses the prototype and UI handoff to judge whether the bag layout, shop flow, and animation readability support the concept.

## Major components

1. `Build Board` — five independent body-part bag grids, item placement, rotation, adjacency preview.
2. `Shop and Run Loop` — item offers, reroll/lock if included, gold, wins/losses, bag expansion cards.
3. `Item Definition System` — shaped parts, stats, tags, adjacency rules, costs.
4. `ATB Battle Simulator` — deterministic event queue, hit/damage resolution, pause-for-animation sequence.
5. `2D Battle Viewer` — sprites, HP bars, attack animations, event log, speed/skip controls if scoped.
6. `Enemy Build Pool` — static/prebuilt opponent builds matched by round.
7. `Run State Persistence` — local browser state only if included; no backend.

## Named capabilities / features

Write these as project-level `FEAT-NNN` entries and decompose Version 0.1 slices from them:

- `FEAT-001 — Five-bag mech builder`: Player can place shaped parts into Head, Torso, Back, Left Arm, and Right Arm bags with no body-part item restrictions.
- `FEAT-002 — Body-part bag expansion`: Player can buy upgrades that add space to a specific body-part bag, making upgrade choice part of build strategy.
- `FEAT-003 — Backpack-style item synergies`: Items provide readable adjacency/tag effects within a bag.
- `FEAT-004 — Shop-based run progression`: Player advances through a short run by buying/rerolling/selling parts and fighting round opponents.
- `FEAT-005 — ATB battle playback`: Battles resolve as a deterministic queue where time pauses for one weapon animation at a time.
- `FEAT-006 — 2D sprite readability`: The battle viewer makes attacks, hits/misses, blocks, HP changes, and key triggers understandable without 3D.
- `FEAT-007 — Prototype enemy pool`: Version 0.1 can fight prebuilt/saved opponent builds without networking.

## Technical anchors

- Version 0.1 is a browser/HTML prototype.
- Prefer a single-page prototype, likely plain HTML/CSS/JavaScript unless the project later chooses a framework.
- Use 2D sprites/placeholders; no 3D.
- No backend, accounts, real matchmaking, or persistent ladder in Version 0.1.
- Battle simulation should be deterministic from build data and a seed, even if the visual playback is animated.
- Keep the simulation and animation layers conceptually separate.

## Explicitly not in scope for Version 0.1

- Real Gundam IP, names, factions, lore, or licensed assets.
- Complex mech simulation: no limb HP, heat, weight, ammo explosions, targeting body parts, pilots, campaign, or realistic hardpoints.
- Item placement restrictions by body part.
- Networking/accounts/real async matchmaking.
- 3D combat.
- Production-grade art pipeline.
- Mobile polish beyond reasonable responsive layout if easy.

## Candidate BEH invariants

Use/check/refine these into numbered `BEH-NNN` entries:

- `BEH-001`: Any item that fits geometrically can be placed in any of the five bags; the system must not reject a beam rifle on Head or a reactor on Right Arm because of anatomy.
- `BEH-002`: Bag expansion must target a named body-part bag and visibly increase only that bag's available space.
- `BEH-003`: Adjacency bonuses must be explainable from visible item placement inside a single bag.
- `BEH-004`: Battle playback must show one primary ready attack animation at a time; simulation time does not advance during that animation.
- `BEH-005`: After a battle, the player must be able to understand the main reason for win/loss from HP bars, event log, and/or report.

## Candidate ARC constraints

Use/check/refine these into numbered `ARC-NNN` entries:

- `ARC-001`: Simulation state and animation playback should be separable so battles can be skipped or replayed from the same build/seed.
- `ARC-002`: Version 0.1 stores opponent builds locally/static; it must not depend on backend matchmaking.
- `ARC-003`: The build board treats each body-part bag as an independent grid; cross-bag adjacency is out of scope for Version 0.1.
- `ARC-004`: Item definitions should be data-driven enough to add shapes/stats/synergies without rewriting battle logic.
- `ARC-005`: UI copy and reports should use prototype/game terms, not realistic engineering claims.

## Roadmap guidance

Create a short roadmap with one main track through Version 0.1. Use plausible dates starting from 2026-06-04; do not over-plan beyond the prototype.

Suggested milestone shape:

- `M1 — V0.1 playable loop`, target around 2026-06-21, goal: one complete 5-win/3-loss-style prototype run with five bags, shop, expansion, prebuilt enemies, and ATB playback.
- `M2 — Prototype tuning and readability`, target around 2026-07-07, goal: tune item synergies, battle reports, and UI clarity based on playtest feedback.

## Version 0.1 scope

Version 0.1 goal: `A player can complete a short browser prototype run: buy shaped items and body-part expansions, arrange them across five unrestricted bags, launch battles against prebuilt enemy builds, and watch deterministic ATB sprite playback until a win/loss result.`

Suggested slice list. Adjust if Vouse slicing rules require changes, but keep each slice one work-session sized and demoable:

1. `Slice 01 — Static five-bag board shell`: displays the five named bag grids and placeholder item shapes; no battle needed.
2. `Slice 02 — Item placement and rotation`: drag/place/rotate shaped items across any bag with no body restrictions; validates geometry/overlap only.
3. `Slice 03 — Shop and body expansion cards`: offers items and specific bag expansion upgrades; applying an expansion visibly changes only that bag.
4. `Slice 04 — Data-driven item stats and adjacency preview`: defines first item set and shows active same-bag adjacency bonuses.
5. `Slice 05 — Deterministic ATB simulator`: computes ordered attack events and battle outcome from two builds without full animation polish.
6. `Slice 06 — 2D battle viewer and paused animation playback`: plays one attack animation at a time, pauses time during animation, updates HP/log.
7. `Slice 07 — Short run loop with enemy pool`: ties shop/build/battle rounds together against static enemies with win/loss progression.

For each slice spec, include five-field acceptance checks in Vouse style. Do not invent tests that require a backend.

## Design handoff dependency

A separate Claude Design handoff should live at:

`D:/Claude/Mech Bags/agent-handoffs/claude-design-ui-requirements.md`

The Vouse scaffold should cite/point to it as the source for visual/UI design requirements, but should not require design output before the project specs are complete.

## Verification / closeout requirements

Before finishing:

1. Confirm the expected files exist.
2. Confirm the High Level Spec contains the named FEAT, BEH, ARC entries.
3. Confirm Version 0.1 has slice specs under `Project Version/Version 0.1/Slices/`.
4. Confirm `Kanban.md` has visible cards for the Version 0.1 slices.
5. Write a short completion report to `D:/Claude/Mech Bags/agent-handoffs/claude-code-vouse-scaffold-report.md` listing files created, unresolved assumptions, and any unavailable Vouse tooling/validators.

Do not commit, push, install dependencies, or create production app code.
