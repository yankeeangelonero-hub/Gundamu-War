---
project: mech-bags
doc_type: slice-spec
version: "0.1"
slice: "02"
title: Item placement and rotation
status: not-started
updated: 2026-06-04
depends_on: ["01"]
---

# Slice 02 — Item placement and rotation

## Goal

Allow the player to drag, place, and rotate shaped items across any of the five bags. Placement is validated for geometry (overlap, out-of-bounds) only. No item is restricted from any bag based on anatomy. Rotation must be possible before or during placement.

## Deliverable

The build board accepts a set of hardcoded test items in a staging area. The player can drag an item to any bag, rotate it (e.g. 90° increments), and place it if it fits geometrically. Invalid placements (overlap, out-of-bounds) are rejected with a visual indicator. No shop, no stats, no adjacency bonuses needed in this slice.

## Acceptance checks

1. **Player can drag an item from the staging area and drop it into any bag.** The item snaps to the grid cell at the drop target.
2. **Geometric placement validation rejects overlapping or out-of-bounds drops.** A visual indicator (e.g. red highlight) shows the placement is invalid. No placement is rejected for anatomical reasons — placing a beam rifle in the Head bag must succeed if it fits geometrically (BEH-001).
3. **Player can rotate an item before or during placement.** Each rotation step changes the item's grid footprint by 90°. All four rotations must be reachable.
4. **Placed items remain in their cell positions until the player moves or removes them.** Refreshing the page may reset state; persistence is not required in this slice.
5. **No anatomical error message or restriction appears when placing any item in any bag.** The only rejection messages relate to geometry (overlap, out of bounds).

## Notes

- Item shapes are defined as `[row, col]` offset arrays from an anchor cell. See `Research/Research Catalogue.md` for shape representation notes.
- 90° CW rotation: `[r, c] → [c, maxRow - r]` (normalise after).
- A minimum of 3–4 distinct hardcoded test shapes is sufficient to demonstrate placement and rotation.
- Adjacency bonus display is not required in this slice (deferred to Slice 04).
