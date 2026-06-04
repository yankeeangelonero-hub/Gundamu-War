---
project: mech-bags
doc_type: slice-spec
version: "0.1"
slice: "07"
title: Short run loop with enemy pool
status: not-started
updated: 2026-06-04
depends_on: ["03", "06"]
---

# Slice 07 — Short run loop with enemy pool

## Goal

Wire the shop/build phase, battle phase, and result screen into a complete run loop. Add a static enemy build pool. The player advances through multiple rounds until reaching the win or loss threshold. No network calls at any point.

## Deliverable

A fully playable (though not polished) short run. Round number, win/loss counters, gold between rounds, and enemy pool are all functional. The run ends with a win or loss screen. The page can be reloaded to start a new run.

## Acceptance checks

1. **Starting a run presents round 1 shop and provides an enemy build matched to round 1 from the pool.** The enemy build is a static data object; no network call is made to retrieve it (FEAT-007, ARC-002).
2. **Winning a battle increments the wins counter, awards gold for the next round, advances the round number, and presents a fresh shop.** The player's placed items carry over between rounds.
3. **Reaching the loss threshold (e.g. 3 losses) ends the run with a loss screen.** The loss screen shows the final win/loss tally and offers a "Start new run" button that resets all run state.
4. **Reaching the win threshold (e.g. 5 wins) ends the run with a win screen.** The win screen shows the final tally and offers a "Start new run" button.
5. **No network calls are made at any point during a full run from start to end.** Opening browser DevTools Network tab must show zero external requests attributable to run logic.

## Notes

- Enemy pool size: at least 4–6 distinct prebuilt builds to cover a realistic prototype run length.
- Pool selection: `pool[roundIndex % pool.length]` is acceptable.
- Win/loss thresholds (e.g. 5 wins / 3 losses) should be confirmed with Xuanyue before finalising; prototype defaults can be used if not confirmed.
- Round gold award: a fixed value per round is sufficient (e.g. 5 gold per round, carried over).
- The shop in each round can offer a fresh random-ish selection drawn from the item data pool (seeded random is fine; pure Math.random() for shop offers is acceptable since it does not affect battle determinism).
- This slice marks the end of the Version 0.1 playable loop; all prior slices must be integrated and working together before this slice is considered complete.
