---
project: mech-bags
doc_type: slice-spec
version: "0.1"
slice: "01"
title: Static five-bag board shell
status: not-started
updated: 2026-06-04
depends_on: []
---

# Slice 01 — Static five-bag board shell

## Goal

Render the five named body-part bag grids in a browser. This is a display-only slice — no item placement, no battle, no shop logic. The purpose is to establish the build board layout and confirm the five-bag visual structure before any interactive logic is added.

## Deliverable

A single HTML file (or equivalent) that, when opened in a browser, shows five distinct named grid sections: **Head**, **Torso**, **Back**, **Left Arm**, **Right Arm**. Placeholder rectangles or colored cells can represent item shapes. No JavaScript errors on load.

## Acceptance checks

1. **Opening the file in a browser renders five visible bag grids.** Each grid is labelled with its body-part name: Head, Torso, Back, Left Arm, Right Arm.
2. **Each bag has a distinct visual boundary.** Grids are separated enough that a tester can tell which cells belong to which bag without hovering or tooltips.
3. **Placeholder item shapes are visible in at least one bag.** These can be static coloured rectangles or simple outlines — no placement interaction required.
4. **No JavaScript errors appear in the browser console on page load.** The browser DevTools console must be clean.
5. **No battle UI, shop UI, or battle logic is required to be present or functional.** This slice delivers only the static board display.

## Notes

- The bag grids do not need to be the final size; default cell counts can be revised in later slices.
- A loose mech silhouette framing (head at top, arms at sides) is preferred but not required for acceptance.
- See `agent-handoffs/claude-design-ui-requirements.md` for visual direction.
- Cross-bag adjacency is not displayed in this slice (ARC-003).
