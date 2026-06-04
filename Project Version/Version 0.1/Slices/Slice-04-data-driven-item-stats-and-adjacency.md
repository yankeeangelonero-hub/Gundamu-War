---
project: mech-bags
doc_type: slice-spec
version: "0.1"
slice: "04"
title: Data-driven item stats and adjacency preview
status: not-started
updated: 2026-06-04
depends_on: ["02"]
---

# Slice 04 — Data-driven item stats and adjacency preview

## Goal

Define the first real item set as data objects (not hardcoded game logic). Each item carries stats (damage, speed, tags). When two qualifying items are adjacent within the same bag, the adjacency bonus activates and is visible on the build board. Moving an item out of adjacency removes the bonus indicator.

## Deliverable

8–12 item definitions as plain data (JSON or JS object literals). At least 3 items have meaningful adjacency rules. The build board reads these definitions and shows active bonus indicators when qualifying placements are made. A tooltip or side panel shows item stats and active bonuses on hover/select.

## Acceptance checks

1. **Each item has readable stat values (at minimum: damage or speed) shown in a card or tooltip.** Values come from the item data definition, not hardcoded UI strings.
2. **When two qualifying items are adjacent within the same bag, the adjacency bonus activates and is shown visually.** The indicator names the items and the effect (BEH-003).
3. **Moving an item out of adjacency removes the bonus indicator immediately.** No stale bonus indicators remain after the trigger condition is broken.
4. **Adding a new item to the data definition without changing battle-logic code causes the item to appear in the shop and behave correctly.** One new data entry must be sufficient (ARC-004).
5. **Adjacency bonuses are bag-scoped only.** Two items in different bags that would qualify do not show a bonus (ARC-003).

## Notes

- Suggested starter items (shapes, stats, tags): see `agent-handoffs/claude-design-ui-requirements.md` for item examples (Beam Rifle 1×3, Machine Gun 1×2, Missile Pod L-shape, Battery 1×2, Sensor 1×1, Armor Plate 2×2, Shield 1×2, Booster 1×2).
- Adjacency rules can start simple: "Sensor adjacent to any Weapon item: +10% hit chance."
- Tag examples: `weapon`, `armor`, `sensor`, `power`, `explosive`.
- No battle simulation is needed in this slice; adjacency preview is a build-board UI feature only.
