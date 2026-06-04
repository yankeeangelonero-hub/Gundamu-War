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

## Open research questions

| Question | Priority | Owner |
|---|---|---|
| What is a good starting item set (8–12 items) for a fun first prototype run? | High | — |
| What adjacency bonus rules are most readable for 5–6 initial items? | High | — |
| What constitutes a good enemy pool (how many builds, how spread across rounds)? | Medium | — |
| Should `localStorage` persistence be in scope for V0.1 or deferred? | Low | Xuanyue |
| Speed controls (fast/skip battle) — in scope for Slice 06 or deferred? | Low | Xuanyue |

---

## Flows and diagrams

See `Research/flows/` for Mermaid flowcharts:
- `run-loop-flow.md` — Core run loop
- `atb-battle-flow.md` — ATB battle simulation and playback
