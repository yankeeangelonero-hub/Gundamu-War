---
project: mech-bags
doc_type: version-spec
version: "0.2"
status: draft-proposed
created: 2026-06-05
updated: 2026-06-05
lifecycle_note: "Proposed pending owner-approved Version 0.1 close. Do not treat as formally open until Version 0.1 close protocol is complete."
slices:
  - SLICE-01
  - SLICE-02
  - SLICE-03
  - SLICE-04
  - SLICE-05
  - SLICE-06
---

# Version 0.2 Project Specifications — Single-Canvas Theatre Loop

## Version goal

Validate the smallest repeatable Mech Bags loop from a simpler Backpack Battles-like base: the player customizes one expandable canvas by placing items and buying small bag pieces, deploys the mech into a theatre where it repeatedly fights enemies over real elapsed time, optionally spectates or leaves while the suit continues cycling through fights and downtime, retreats, receives loot and pilot XP/skill progress/acquisition, modifies the canvas/build, and redeploys.

Version 0.2 answers two connected questions:

> Is one big canvas with buyable small bags a clearer base than five body-part bags?

> Is customize → deploy → repeated real-time theatre fights → retreat → loot + pilot growth → modify → redeploy compelling enough to become the next spine of Mech Bags?

## Scope boundary

Version 0.2 is still a local browser prototype. No backend, accounts, live multiplayer, persistent global war, or real LLM war director is required.

The previous five-body-part build surface is not the target for this version. Version 0.2 should replace the active build surface with a single main canvas and buyable bag pieces. The gear/mech-customisation fork remains open, but it is not implemented in this version.

## In scope

| Feature | Ref | Notes |
|---|---|---|
| Single expandable canvas build surface | FEAT-001R | Replaces five independent body-part bags for this version. |
| Buyable small bag pieces / canvas expansions | FEAT-008 | Shop can sell bag pieces that add owned cells/space to the canvas. |
| Spatial item placement on owned canvas cells | FEAT-009 | Placement fails only for overlap, out-of-bounds, or unowned cells. |
| Fixed theatre pool of 10 enemy builds | FEAT-010 | Enemy builds are deterministic and inspectable enough to support learning. |
| Deploy / active theatre sortie state | FEAT-011 | Player build enters the war theatre and keeps fighting until retreat. |
| Real-time repeated fight loop | FEAT-012 | Each fight takes 15–30 seconds in the first implementation. |
| Victory resupply / loss delay downtime | FEAT-013 | Victory downtime starts at 5 seconds; loss repair/delay starts at 15 seconds. |
| Optional spectate / leave-at-any-time flow | FEAT-014 | Player can watch a live fight or leave the spectator view without stopping the sortie. |
| Retreat / return to workshop | FEAT-015 | Retreat ends the active sortie and delivers accumulated results. |
| Loot drop, pilot XP, level, and skill acquisition/progress | FEAT-016 | Rewards and pilot growth motivate modifying the build and redeploying. |

## Explicitly out of scope

- Five simultaneous body-part grids as the active Version 0.2 build surface.
- Body-part anatomy as a placement rule.
- Gear/mech-customisation surface implementation.
- Full warfront map and territory control.
- Authored mission board as the main adaptation driver.
- Real async PVP, accounts, backend, matchmaking, or server persistence.
- Multiple pilots.
- Deep pilot skill tree or life-sim management.
- Common pilot permadeath.
- NPC towns, town capture/death simulation, seasonal skins, titles, or war-hero reward tracks.
- Live LLM-generated narration.
- Deep loot economy.
- Production art.

## Behaviour invariants proposed for Version 0.2

These are proposed for this version and should be ratified when Version 0.2 formally opens:

- **BEH-006 — Single canvas base:** The active build surface is one expandable canvas/workbench, not five independent body-part boards.
- **BEH-007 — Buyable bag space:** Bag pieces/canvas expansions are purchasable build resources that add owned cells or shapes to the canvas.
- **BEH-008 — Spatial placement only:** Items may be placed anywhere on owned canvas cells if geometry permits. Placement rejects overlap, out-of-bounds, or unowned cells only.
- **BEH-009 — Sortie loop boundary:** Retreat is the boundary that returns the player from deployed/fighting/downtime state to workshop state and awards accumulated sortie outcomes.
- **BEH-010 — Optional spectating:** Watching the fight is optional. Leaving the spectator view must not stop or lose deterministic sortie progress.
- **BEH-011 — Pilot growth is secondary to buildcraft:** Pilot XP and skills may influence the loop, but they must not replace buildcraft as the primary source of agency.
- **BEH-012 — Consequences come from sortie performance:** Pilot condition changes should derive from survival/performance in the sortie, not from arbitrary hidden drama.
- **BEH-013 — Theatre fights are paced, not instant:** The active theatre loop should not resolve the entire sortie instantly. Fights occur one at a time with visible timer/downtime pacing.
- **BEH-014 — Downtime reflects outcome:** Victory uses faster resupply downtime; loss uses longer delay/repair downtime during which the suit cannot fight.

## Architecture constraints proposed for Version 0.2

- **ARC-006 — Canvas ownership model:** Build legality is determined by owned canvas cells, item shape, rotation, and overlap. Body-part identity is not part of placement validation.
- **ARC-007 — Deterministic fight resolver:** Given the same player build, enemy build, seed, and fight index, individual fight results are repeatable.
- **ARC-008 — Theatre scheduler owns pacing:** The theatre loop schedules fight → outcome → downtime → next fight. Spectator animation displays this state but is not the authority that determines rewards or pilot XP.
- **ARC-009 — Local prototype only:** All Version 0.2 state can live in the browser/local prototype. No backend dependency is introduced.
- **ARC-010 — Accumulated sortie state:** Loot, XP, condition, skill progress, and fight history accumulate during the active sortie and are claimed on retreat.

## Slices

Version 0.2 is delivered through six slices. Each slice should produce demoable evidence on its own and fit roughly one work session.

| # | Title | Kind | Depends on | Evidence signal |
|---|---|---|---|---|
| 01 | Single canvas and buyable bag pieces | Feature | Version 0.1 placement logic | Player can place items on one owned canvas and buy bag pieces that expand usable space. |
| 02 | Theatre pool and single-fight resolver | Enabling | 01, Version 0.1 core sim | Deterministic results against 10 valid enemy builds are repeatable per fight/seed. |
| 03 | Real-time deploy loop and downtime scheduler | Feature | 02 | Player deploys; fights occur one at a time; victory creates 5s resupply; loss creates 15s delay. |
| 04 | Optional spectate and leave flow | Feature | 03 | Player can watch the current fight or leave spectate while the theatre loop continues. |
| 05 | Retreat, loot, pilot XP, and skills | Feature | 03, 04 | Retreat returns to workshop and awards visible loot, XP/level, condition, and skill acquisition/progress. |
| 06 | Modify-after-results playtest and evidence gate | Enabling | 01–05 | Testers complete at least two deploy→retreat→modify cycles and answer whether the loop is worth repeating. |

### Slice 01 — Single canvas and buyable bag pieces

Replace the five independent body-part boards with one expandable canvas/workbench. The player starts with a small owned area and can buy small bag pieces or expansion shapes that add owned cells to the canvas. Items are placed spatially into owned cells.

Acceptance shape:

- One main canvas is visible and usable.
- The player starts with owned cells on the canvas.
- Shop can offer at least one bag piece/canvas expansion.
- Buying a bag piece adds owned space to the canvas.
- Items can be placed anywhere on owned cells if geometry permits.
- Placement rejects overlap, out-of-bounds, or unowned cells only.
- Mobile tap-select, rotate, move, and invalid-feedback behavior remains usable.

### Slice 02 — Theatre pool and single-fight resolver

Create a fixed theatre pool of 10 enemy builds compatible with the single-canvas representation and ensure the resolver can run one deterministic fight at a time against a selected/scheduled enemy.

Acceptance shape:

- 10 enemy builds exist and are valid under the single-canvas placement/ownership rules.
- A single fight result is deterministic for the same player build, enemy build, seed, and fight index.
- Results expose enough facts for later report, loot, XP, condition, skill, and scheduling logic.

### Slice 03 — Real-time deploy loop and downtime scheduler

Add deployed theatre state. The player sends the current build into the theatre. The scheduler runs fight → outcome → downtime → next fight until the player retreats. For the first implementation, each fight should last between 15 and 30 seconds. A victory enters 5 seconds of resupply downtime. A loss enters 15 seconds of repair/delay downtime where the suit cannot fight.

Acceptance shape:

- Deploy action is visible from workshop/build state.
- Active theatre view shows current state: fighting, victory resupply, loss delay/repair, or readying next enemy.
- Fight duration is paced between 15 and 30 seconds rather than instant batch resolution.
- Victory downtime is 5 seconds.
- Loss downtime is 15 seconds.
- The loop continues until retreat.

### Slice 04 — Optional spectate and leave flow

Add or revise spectate as a view over the currently active fight/state. The player can watch the fight, leave the spectator view, and return later without stopping the theatre loop.

Acceptance shape:

- Spectate is optional and does not block sortie progression.
- Leaving spectate returns to the theatre/workshop-facing state while the sortie remains active.
- The existing battle viewer may be reused, but it is not the authority for results or timers.
- The player can tell whether the suit is currently fighting, resupplying, delayed after loss, or readying the next fight.

### Slice 05 — Retreat, loot, pilot XP, and skills

Add retreat as the sortie boundary. On retreat, the player receives accumulated results: fights completed, wins/losses, loot drops, pilot XP, level progress, condition change, and skill acquisition/progress.

Acceptance shape:

- Retreat returns the player to workshop state.
- Loot drops are visible and create at least one concrete reason to modify or improve the build.
- Pilot XP and level progress are visible.
- At least one pilot skill can progress or be acquired from sortie facts.
- Pilot condition can change in a small readable ladder such as Ready / Fatigued / Wounded / Out of Service.
- Rewards and pilot growth are deterministic from sortie facts.

### Slice 06 — Modify-after-results playtest and evidence gate

Run the loop as a product test, not just a feature check. The version needs evidence that testers want to repeat the loop from the simplified canvas base.

Acceptance shape:

- Tester completes canvas build → deploy → repeated timed fights/downtime → optional spectate/leave → retreat → loot+XP+skill → modify → redeploy.
- Tester can explain whether the single-canvas base is clearer than the old five-body-part boards.
- Tester can explain what happened during the sortie, what loot/skill/condition changed, and what they changed before redeploying.
- Decision recorded: proceed with this single-canvas theatre loop, revise it, or stop and rethink.

## Definition of done

Version 0.2 is complete when all of the following are true:

1. The player can customize the build using one expandable canvas.
2. The player can buy small bag pieces/canvas expansions that add usable space.
3. The player can place, rotate, move, and receive invalid-placement feedback for items on owned canvas cells.
4. The player can deploy into a fixed pool of 10 enemy builds.
5. Theatre fights are not instant batch resolution; they occur one at a time with a visible 15–30 second fight duration.
6. Victory creates 5 seconds of resupply downtime before the next fight.
7. Loss creates 15 seconds of delay/repair downtime before the suit can fight again.
8. The player can spectate or leave the spectator view without stopping or losing theatre progress.
9. The theatre loop keeps cycling fights/downtime until the player retreats.
10. The player can retreat and receive loot drops, pilot XP/level progress, condition, and skill acquisition/progress results.
11. The player can modify the canvas/build and redeploy for another sortie.
12. The version records playtest evidence about whether the single-canvas theatre loop is worth repeating.

## Decisions and open questions for this version

| Question | Owner / status |
|---|---|
| Should Version 0.2 keep five body-part bags? | **Decided:** no; use one big canvas plus buyable small bags/pieces. |
| Is the fixed pool exactly 10 enemy builds for the first implementation? | **Decided:** yes; use a fixed deterministic pool of 10 valid enemy builds. |
| Should the war theatre resolve instantly or over time? | **Decided:** over time. Do not instant-resolve the sortie. |
| How long should each fight take? | **Decided for V0.2:** 15–30 seconds. |
| What downtime follows victory? | **Decided for V0.2:** 5 seconds resupply. |
| What downtime follows loss? | **Decided for V0.2:** 15 seconds delay/repair lockout where the suit cannot fight. |
| When are rewards claimed? | **Decided for V0.2:** on retreat, using accumulated sortie facts. |
| What exact bag-piece shapes are sold first? | Open for implementation default; keep to a few small readable expansions. |
| Is loot a currency, actual item drop, or both? | Open for implementation default; must be visible and actionable enough to motivate modification. |
| What are the first pilot skills? | Open for implementation default; keep to one or two visible tracks/acquisitions. |
| Does pilot XP come from participation, survival, performance, or all three? | Open for implementation default; should be deterministic and readable. |
| Does spectate show the active live fight, a simplified animation, or a rolling summary? | Open for implementation default; it must represent current theatre state and remain optional. |

## Research and journey references

- `Research/Research Documents/concept-handoff-2026-06-05-single-canvas-buyable-bags.md`
- `Research/Research Documents/concept-handoff-2026-06-05-real-time-theatre-loop.md`
- `Research/Research Documents/concept-handoff-2026-06-05-pilot-skill-xp-layer.md`
- `Research/User Journeys.md` — Journey 12 and Journey 13
- `agent-handoffs/opus-essential-loop-distillation-report.md`

## Lifecycle note

This spec is draft-proposed because Version 0.1 is not formally closed. Version 0.2 implementation work may proceed only because Xuanyue explicitly authorized prototype iteration before the formal Vouse close/open ceremony. Do not treat this as a closed or formally shipped version until the lifecycle is reconciled.
