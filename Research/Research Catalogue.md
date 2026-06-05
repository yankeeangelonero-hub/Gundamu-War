---
project: mech-bags
doc_type: research-catalogue
status: active
updated: 2026-06-04
---

# Research Catalogue — Mech Bags

Tracks research questions, findings, and outstanding items relevant to the project. Add entries as questions arise or answers are found.

---

## Reference: Backpack Battles

**What it is:** The primary inspiration. A browser/PC autobattler where players fill one grid backpack with shaped items, which fight automatically. Items interact through adjacency and tag bonuses.

**Relevant mechanics for Mech Bags:**
- Shaped item placement (polyomino-style)
- Same-bag adjacency bonuses (adjacent items trigger each other)
- Item tags (e.g. Weapon, Armor, Poison) that determine synergy rules
- Shop phase between rounds with reroll and lock
- Prebuilt/async opponents

**Key divergence in Mech Bags:**
- Five independent bags instead of one
- Bag expansion targets a specific body part
- No item placement restrictions by body part
- ATB battle playback (not real-time passive)

---

## Research: ATB battle system design

**Question:** What is the simplest viable ATB implementation that satisfies BEH-004 (one animation at a time) while remaining deterministic?

**Working answer:**
- Each item with an attack has a `speed` value in arbitrary units (e.g. ATB ticks per attack).
- Simulation maintains a next-fire time for each attacking item: `nextFire[item] = currentTime + speed`.
- On each loop iteration: find `min(nextFire)`, advance clock to that time, fire that item, reset its timer.
- No randomness needed for basic timing; seed-based RNG used only for hit/miss or special effect rolls.
- This approach is fully deterministic and produces an ordered event list that the viewer can play back at any speed.

**Status:** Sufficient for slice design. Refine during Slice 05.

---

## Research: Grid/item shape representation

**Question:** How should item shapes be stored for the placement engine?

**Working answer:**
- Represent each item shape as an array of `[row, col]` offsets from an anchor cell.
- Rotation can be applied by transforming offsets: for 90° CW, `[r, c] → [c, -r]` (normalise to positive coordinates after).
- Placement validity check: translate all offsets to grid coordinates, check each is in bounds and unoccupied.
- This is simple, data-driven (ARC-004), and easy to author by hand for a small item set.

**Status:** Ready for Slice 02 and Slice 04.

---

## Research: Adjacency bonus readability

**Question:** How does Backpack Battles communicate adjacency bonuses clearly?

**Notes from observation:**
- Items visually highlight when adjacent to a qualifying item.
- Bonus tooltip names both items and the effect.
- Bonus activates in-bag only.

**Implication for Mech Bags:** Same approach applies. Adjacency preview should highlight active bonuses on the build board. Event log should name the source bag and items.

**Status:** Sufficient for Slice 04.

---

## Research: Placeholder sprite strategy

**Question:** What is the minimal viable art approach for a prototype that communicates five body parts and 2D attack animations?

**Working answer:**
- Each bag can be represented by a simple rectangular section of a stylised mech silhouette (no licensed art needed).
- Items can be coloured rectangles with text labels at prototype stage.
- Attack animations: a projectile dot or flash originating from the attacking bag's region, moving toward the enemy.
- HP bars: standard CSS progress bars above each mech.
- No production art pipeline required.

**Status:** Ready to hand off to Design agent for visual treatment. See `agent-handoffs/claude-design-ui-requirements.md`.

---

## Concept handoffs

### Concept Handoff: Backpack auto-battler meta layer — 2026-06-05

**Path:** `Research/Research Documents/concept-handoff-2026-06-05-backpack-autobattler-meta.md`

**Summary:** Captures the initial meta-layer direction: persistent backpack in an asynchronous offline PVP arena, harvest-style loot/progression, unresolved convergence tension, and the pilot relationship layer as the likely spine if it changes play rather than merely adding stats. Partially superseded by the warfront/pilot/grid-vs-gear handoff below.

### Concept Handoff: Warfront, pilot stakes, and grid-vs-gear fork — 2026-06-05

**Path:** `Research/Research Documents/concept-handoff-2026-06-05-warfront-pilot-grid-vs-gear.md`

**Summary:** Records the expanded direction: living asynchronous warfront, deterministic simulator plus LLM war director, pilot injury/out-of-service stakes, and the unresolved build-surface fork between Backpack-style body-part grids and direct gear/mech customisation. Flags this fork as a required next-version test.

**Carried into:** `Project Version/Version 0.2/Version 0_2 Project Specifications.md` (draft-proposed). The version makes the grid-vs-gear fork an evidence gate rather than a prose decision (Slice 08), keeps deterministic war state separate from narrative copy, and builds the pilot-risk stakes loop. The spec is proposed pending Version 0.1 close.

### Concept Handoff: Theatre meta feed essential loop — 2026-06-05

**Path:** `Research/Research Documents/concept-handoff-2026-06-05-theatre-meta-feed-essential-loop.md`

**Summary:** Owner correction replacing the mission-condition / pre-deploy-risk framing with a theatre-performance feed loop: players build the strongest mech they can, deploy into a theatre, read top-performing enemy builds and matchup reports, then counter-build against the visible enemy meta. Partially superseded by the essential sortie loop handoff below.

### Concept Handoff: Version 0.2 essential sortie loop — 2026-06-05

**Path:** `Research/Research Documents/concept-handoff-2026-06-05-v0-2-essential-sortie-loop.md`

**Summary:** Narrowed Version 0.2 to a customize → deploy → retreat → improve loop, but assumed instant 10-fight batch resolution. Superseded by the real-time theatre loop handoff below.

### Concept Handoff: Real-time theatre loop — 2026-06-05

**Path:** `Research/Research Documents/concept-handoff-2026-06-05-real-time-theatre-loop.md`

**Summary:** Owner correction that the theatre should not resolve instantly. The suit keeps fighting until retreat; each fight takes 15–30 seconds; wins create 5 seconds of resupply; losses create 15 seconds of repair/delay lockout; retreat claims accumulated loot, pilot XP/level progress, condition, and skill acquisition/progress. Partially superseded by the single-canvas handoff below for build-surface direction.

### Concept Handoff: Single canvas and buyable bags — 2026-06-05

**Path:** `Research/Research Documents/concept-handoff-2026-06-05-single-canvas-buyable-bags.md`

**Summary:** Owner correction replacing the five body-part bags with one big Backpack Battles-like canvas and small buyable bag pieces/canvas expansions. This is now the immediate V0.2 build-surface direction while retaining the real-time theatre, retreat, loot, and pilot-growth loop.

### Concept Handoff: Pilot skill and XP layer — 2026-06-05

**Path:** `Research/Research Documents/concept-handoff-2026-06-05-pilot-skill-xp-layer.md`

**Summary:** Owner addition that pilots should have Level, XP, and skill progression in addition to condition/injury consequences. For the essential loop, this should be small: one pilot, visible XP, one or two skill tracks, and report lines that separate battle outcome, pilot condition, and pilot growth.

---

## Living journey documents

### User Journeys — active

**Path:** `Research/User Journeys.md`

**Summary:** Tracks current prototype journeys and next-version candidate journeys for warfront adaptation, pilot care, war-hero rewards, and the grid-vs-gear build-surface comparison.

---

## Open research questions

| Question | Priority | Owner |
|---|---|---|
| Confirm persistent backpack as the project spine over fresh disposable runs. | High | Xuanyue |
| Define how asynchronous offline PVP results are matched, timed, reported, and harvested. | High | — |
| Decide whether the next product spine is pure mech-customisation PVP or a living asynchronous warfront with daily mission-board changes. | High | Xuanyue |
| Define deterministic warfront state rules versus LLM war-director narration boundaries. | High | — |
| Decide whether the build surface should remain Backpack-style body-part grids or shift toward gear/mech customisation; test both in the next version. | High | Xuanyue |
| Define pilot injury/out-of-service mechanics that make risk readable without punishing experimentation. | High | — |
| Decide whether anti-convergence is led by structural rock-paper-scissors cycling, injected randomness, warfront mission shifts, pilot constraints, or a bounded combination. | High | — |
| Define pilot mechanics, including Level/XP and skill tracks, that change how players build/play without acting as flat stat bonuses or overpowering mech buildcraft. | High | — |
| Decide which progression layer is the spine: build, warfront, loot farm, or pilot. | High | Xuanyue |
| What is a good starting item set (8–12 items) for a fun first prototype run? | High | — |
| What adjacency bonus rules are most readable for 5–6 initial items? | High | — |
| What constitutes a good enemy pool (how many builds, how spread across rounds)? | Medium | — |
| Should `localStorage` persistence be in scope for V0.1 or deferred? | Low | Xuanyue |
| Speed controls (fast/skip battle) — in scope for Slice 06 or deferred? | Low | Xuanyue |

The grid-vs-gear build-surface question, the deterministic-warfront-vs-LLM-narration boundary, and the readable-non-punitive pilot-injury question are routed into the draft-proposed `Project Version/Version 0.2/Version 0_2 Project Specifications.md` for testing. They remain open here until Slice 08 produces evidence and a recommendation. The broader spine question (build vs warfront vs loot farm vs pilot) is not resolved by Version 0.2 — that version validates the warfront + pilot + build-surface slice of it only.

**Distillation note (2026-06-05, `agent-handoffs/opus-essential-loop-distillation-report.md`):** a distillation pass recommended sequencing loop-validation first. Xuanyue then corrected the proposed loop in `Research/Research Documents/concept-handoff-2026-06-05-theatre-meta-feed-essential-loop.md`: the essential loop should center a **theatre-performance feed of top enemy builds**, not authored mission-condition tags or a pre-deploy risk meter. The player builds the strongest mech they can, deploys into the theatre, reads which enemy builds are dominating, then adapts the mech against that meta. Under this correction, the grid-vs-gear question remains deferred until the theatre-meta loop is validated; the immediate V0.2 rewrite should replace mission-fit/risk tuning with feed-driven counter-building.

---

## Flows and diagrams

See `Research/flows/` for Mermaid flowcharts:
- `run-loop-flow.md` — Core run loop
- `atb-battle-flow.md` — ATB battle simulation and playback
