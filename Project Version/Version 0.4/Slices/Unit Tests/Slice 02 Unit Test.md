---
name: slice-02-unit-test
description: Unit test record for Slice 02 -- Backpack System Comparator
metadata:
  type: unit-test
  slice: Slice-02
  version: v0.4
  status: review
---

# Slice 02 Unit Tests -- Backpack System Comparator

## Check script

`experiments/backpack-comparator/backpack-check.cjs`

Run: `node experiments/backpack-comparator/backpack-check.cjs`

## Evidence files

| File | Covers |
|---|---|
| `evidence/backpack-comparator/placement.json` | AC-1 |
| `evidence/backpack-comparator/adjacency-preview.md` | AC-2 |
| `evidence/backpack-comparator/determinism-log.md` + `diff-note.md` | AC-3 |
| `evidence/backpack-comparator/debrief-comparison.md` + `comparison.md` | AC-4 |

AC-5 asserted inline; failures appear in check output.
