---
project: mech-bags
artefact: research-document
kind: concept-handoff
status: frozen
created: 2026-06-05
source: xuanyue
supersedes: Research/Research Documents/concept-handoff-2026-06-05-v0-2-essential-sortie-loop.md
supersedes_section: "instant 10-fight batch resolution"
---

# Real-Time Theatre Loop, Downtime, Loot, and Pilot Growth — Concept Handoff

**Status:** Owner correction for the Version 0.2 essential sortie loop. This supersedes the earlier instant-batch assumption while preserving the core customize → deploy → retreat → improve → redeploy shape.

---

## Owner correction

The war theatre should not resolve instantly.

The player should customize the best mech they can, deploy it to the war theatre, and then the suit keeps fighting within the battlefront until the player retreats. Fights occur one at a time over real elapsed time. The player may spectate, leave the spectate view, or let the suit continue in the theatre.

Each fight should take roughly **15–30 seconds** for the first implementation. Between fights, the suit has downtime:

- **Victory resupply:** faster downtime, initially **5 seconds** before the next fight.
- **Loss penalty / repair delay:** the suit cannot fight until the penalty elapses, initially **15 seconds** before the next fight.

Retreat returns the suit to the workshop and claims accumulated sortie results.

## Revised loop

The intended Version 0.2 loop is:

1. Customize mech in the workshop.
2. Deploy to war theatre.
3. Suit fights an enemy from the theatre pool.
4. Fight takes 15–30 seconds.
5. Outcome is recorded.
6. If victory, suit resupplies for 5 seconds.
7. If loss, suit is delayed/repair-locked for 15 seconds.
8. Next fight begins automatically after downtime.
9. Player may spectate or leave while the loop continues.
10. Player retreats when ready.
11. Retreat summary grants loot drops, pilot XP, pilot skill progress/acquisition, and condition consequences.
12. Player modifies mech and redeploys.

## Why this matters

Instant batch resolution made the war theatre feel like a report generator. Real-time looping makes the mech feel deployed in an ongoing front. Victory and loss downtime make performance matter without requiring a full backend or global war simulation.

This also creates a clearer reason to spectate: the player can watch a live fight or check the current state of the deployed suit, but watching is not mandatory.

## Required missing pieces

The current implementation is missing three essential feedback layers:

1. **Loot drops** — the player needs concrete rewards from retreat that can help modify the mech.
2. **Pilot level up** — pilot XP must accumulate visibly and level changes should be called out.
3. **Skill acquisition/progress** — pilots should gain or advance small skills based on sortie events or performance patterns.

For Version 0.2 these should remain small and deterministic. One pilot, one or two starter skills, simple loot items/currency, and readable report copy are enough.

## Scope guardrails

This correction does not add full backend async PVP, global map simulation, multiple pilots, deep skill trees, or live LLM narration. The goal remains a local browser prototype that tests whether repeated real-time sorties create the desire to retreat, improve, and redeploy.
