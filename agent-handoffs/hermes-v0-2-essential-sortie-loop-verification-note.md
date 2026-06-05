# Hermes Verification Note — V0.2 Essential Sortie Loop

**Date:** 2026-06-05

## What was verified

Hermes independently checked Sonnet's V0.2 essential sortie implementation after worker `proc_ff6edd9f084a` completed.

## Commands / checks run

```bash
node prototype/tests/core-tests.js
```

Result:

```text
Results: 125 passed, 0 failed
All tests passed.
```

Browser smoke target:

```text
http://127.0.0.1:8787/
```

Observed:

- page title is `Mech Bags 0.2`;
- workshop shows Deploy and preserved Battle controls;
- Deploy resolves all 10 fights and opens the sortie overlay;
- sortie overlay shows 10 fight chips, seed, win/loss count, Spectate Fight, and Retreat;
- Retreat opens sortie summary with wins/losses, loot, new gold balance, pilot XP, condition, skill progress, and learning signal;
- browser console reported 0 messages / 0 JS errors after the smoke check.

## Screenshot inspection

The screenshot folder currently contains 3 files, not 12:

- `02-sortie-screen-2nd-sortie.png`
- `11-second-retreat-summary.png`
- `12-workshop-after-second-sortie.png`

These three screenshots were visually inspected and are readable/coherent:

- sortie overlay clearly communicates all 10 fights, 3W/7L, Spectate, and Retreat;
- retreat summary clearly shows loot, pilot XP/condition, Saber Duel Sense progress, learning signal, and Back to Workshop;
- workshop after second sortie remains usable and shows pilot LVL/XP/condition/skill pips.

The Sonnet report claims 12 screenshots, but only 3 are present on disk at verification time. Treat the missing 9 screenshots as a report mismatch, not as a functional failure.

## Noted follow-ups

1. Spectate fight selection: report says Spectate currently always opens fight 0; fight chips do not individually launch spectate. This is the most natural follow-up.
2. Pilot condition recovery semantics need owner review: current behavior re-derives condition from latest sortie, so a good sortie can reset Wounded to Ready.
3. V0.1 Battle and V0.2 Deploy now coexist; keep this until owner decides whether V0.1 run-loop remains accessible.
4. Formal Vouse slice records were not written because V0.2 remains draft-proposed pending Version 0.1 close/open approval.
