---
project: mech-bags
doc_type: slice-spec
version: "0.1"
slice: "05"
title: Deterministic ATB simulator
status: not-started
updated: 2026-06-04
depends_on: ["04"]
---

# Slice 05 — Deterministic ATB simulator

## Goal

Implement the ATB battle simulator as a pure function: given two build states and a seed, return an ordered list of attack events and the battle result. No animation, no DOM, no rendering. The simulator must be deterministic — same inputs produce the same output every time.

## Deliverable

A JavaScript function (or module) `simulate(playerBuild, enemyBuild, seed)` that returns `{ events, winner, finalPlayerHP, finalEnemyHP }`. The event list matches the ATB logic described in `Research/flows/atb-battle-flow.md`. A simple test harness (console output or a small test HTML page) verifies the determinism requirement.

## Acceptance checks

1. **Given two builds and a seed, the simulator returns a non-empty events list, a winner ('player' or 'enemy'), and final HP values.** The return value is readable without opening the animation viewer.
2. **Running the same simulation twice with identical inputs (same builds, same seed) produces byte-equal event lists.** No `Date.now()`, `Math.random()`, or other non-deterministic sources are used inside the simulator (ARC-001).
3. **The event list is in ascending time order.** Each event's `time` value is greater than or equal to the previous event's `time`.
4. **The simulator does not depend on any backend endpoint.** It runs entirely in the browser tab with no network calls.
5. **Calling `simulate()` with a skip-to-result intention (no viewer) still produces the correct `winner` from the same logic.** The viewer is not needed to determine the outcome (ARC-001).

## Notes

- ATB timer logic: each attack item has a `speed` value (ticks/attack). `nextFire[item] = speed`. Each loop: find min `nextFire`, advance clock, fire event, reset that item's timer.
- Seed-based PRNG: use a simple seeded LCG or equivalent. No `Math.random()` inside the simulator.
- HP values: a starting HP per build (e.g. 100 base + item bonuses) is acceptable prototype design.
- The simulator does not need to handle every edge case in this slice; it needs to produce a valid, deterministic event list for a typical build.
- Event schema: `{ time: number, attackerSide: 'player'|'enemy', bag: string, itemId: string, damage: number, effects: string[] }`.
