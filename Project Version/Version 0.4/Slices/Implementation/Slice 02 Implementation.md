---
name: slice-02-implementation
description: Implementation record for Slice 02 -- Backpack System Comparator Demo
metadata:
  type: implementation
  slice: Slice-02
  version: v0.4
  status: review
---

# Slice 02 Implementation -- Backpack System Comparator

## Delivered

| File | Role |
|---|---|
| `experiments/backpack-comparator.html` | Browser demo: 6x5 grid, dual-build comparison, preset loader, seed/deploy, event log, debrief |
| `experiments/backpack-comparator/backpack-core.js` | Pure deterministic JS core (UMD) |
| `experiments/backpack-comparator/backpack-check.cjs` | Node check script; 5 AC suites, writes evidence |

## ACs met

- AC-1 Grid placement: 6x5, canPlace, placeItem, overlap/OOB rejection
- AC-2 Adjacency preview: active, inactive, missing-partner, hover preview
- AC-3 Determinism: same seed x build -> byte-equal event log
- AC-4 Debrief: all 6 matchup combos produce winner/ticks/HP/adjacency debrief
- AC-5 Preset coverage: all 4 presets place cleanly
