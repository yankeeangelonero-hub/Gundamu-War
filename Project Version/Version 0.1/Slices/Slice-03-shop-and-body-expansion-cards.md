---
project: mech-bags
doc_type: slice-spec
version: "0.1"
slice: "03"
title: Shop and body expansion cards
status: not-started
updated: 2026-06-04
depends_on: ["01"]
---

# Slice 03 — Shop and body expansion cards

## Goal

Add a shop row beneath (or beside) the build board. The shop offers a mix of item cards and body expansion upgrade cards. Buying an expansion card increases only the named bag's grid by the specified cell count. Gold is tracked and deducted on purchase.

## Deliverable

A shop UI section with a small set of hardcoded item cards and at least one body expansion card per distinct bag. Clicking a card with sufficient gold deducts the cost and (for expansion cards) visibly grows only the targeted bag. Gold display is updated in real time.

## Acceptance checks

1. **Shop displays at least one item card and at least one body expansion card.** Expansion cards name the target body part explicitly (e.g. "Head Expansion — +1 cell to Head", "Right Arm Extension — +1 cell to Right Arm").
2. **Buying a body expansion card with sufficient gold deducts the cost and visibly increases only the targeted bag's grid.** The other four bags are unchanged (BEH-002).
3. **Buying an item card with sufficient gold deducts the cost and makes the item available to place.** (Placement interaction from Slice 02 is reused; the new item appears in the staging area or hand.)
4. **Attempting to buy any card without sufficient gold is rejected with a visible indicator.** No gold is deducted on a failed purchase.
5. **Gold display updates immediately after any successful purchase.** Stale gold values must not be shown after a transaction.

## Notes

- Exact starting gold amount and per-round gold award are TBD. Use a reasonable prototype value (e.g. 10 gold start, item costs 2–4, expansion costs 3–5).
- Reroll action is optional in this slice; basic fixed-offer shop is sufficient for acceptance.
- Lock mechanic is out of scope for this slice.
- The shop does not need to regenerate between rounds in this slice; that is handled in Slice 07.
- See `agent-handoffs/claude-design-ui-requirements.md` for bag expansion card copy examples.
