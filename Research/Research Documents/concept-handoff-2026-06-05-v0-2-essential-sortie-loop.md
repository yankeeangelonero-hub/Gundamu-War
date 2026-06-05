---
project: mech-bags
artefact: research-document
kind: concept-handoff
status: frozen
created: 2026-06-05
source: xuanyue
supersedes: Research/Research Documents/concept-handoff-2026-06-05-theatre-meta-feed-essential-loop.md
supersedes_section: "Version 0.2 essential loop shape"
---

# Version 0.2 Essential Sortie Loop — Customize, Deploy, Retreat, Improve

**Status:** Owner correction and scope lock candidate for Version 0.2. This document narrows the theatre-meta direction into the exact loop Xuanyue wants to test first.

---

## Intended Version 0.2 loop

The intended Version 0.2 test is:

```text
Customize mech
→ deploy to war
→ mech fights in a pool of 10 other mechs
→ fights resolve quickly and deterministically in the background
→ user can spectate or leave at any time
→ user retreats mech
→ loot drop and pilot XP go up
→ pilot learns skills and user modifies mech
→ fight again
```

This is the essential loop. The version should prove this before adding warfront maps, rich NPC towns, full theatre simulation, seasonal rewards, multiple pilots, or gear-vs-grid comparisons.

## Product feel

The player is not primarily choosing authored missions or optimizing a visible risk meter. They are building what they think is the best mech they can, sending it into a war theatre, watching or leaving while deterministic fights resolve, then pulling the mech back to inspect gains and improve.

The loop should feel like maintaining a persistent combat machine and pilot in a hostile live theatre:

- build quality matters;
- matchups against the theatre pool matter;
- the pilot grows from sorties;
- loot gives a reason to change the build;
- the player chooses when to retreat and reconfigure;
- spectating is optional, not required.

## Required Version 0.2 objects

Minimum objects:

- one player mech using the existing five-bag grid;
- one pilot with Level, XP, condition, and a small skill track;
- a fixed pool of 10 enemy mechs;
- deterministic battle resolution against the pool;
- an optional spectator view using the existing battle viewer where possible;
- a retreat/return action;
- loot drop results;
- pilot XP and skill progress results;
- post-sortie summary that explains what happened and what changed.

## Determinism and background resolution

The fights should resolve quickly and deterministically. The player should be able to:

1. deploy and watch the fight if they want;
2. deploy and leave the spectator view while the sortie still resolves;
3. return to a resolved or progress summary;
4. retreat the mech and claim sortie outcomes.

The deterministic contract matters because the game should be trustworthy. Given the same player build, enemy pool, sortie seed, and retreat timing rule, the sortie result should be repeatable.

## Retreat as the loop boundary

Retreat is the important player boundary for Version 0.2.

It marks the end of a sortie and transitions the player from combat theatre back to workshop:

```text
deployed / fighting / resolved
→ retreat mech
→ receive loot + XP + condition/skill changes
→ modify mech
→ redeploy
```

Version 0.2 does not need a full risk-management UI. Pilot consequence can be simple and tied to sortie performance.

## Pilot growth

The pilot layer should be visible but small:

- Level;
- XP;
- condition such as Ready / Fatigued / Wounded / Out of Service;
- one or two early skills or skill tracks;
- XP from sortie participation, survival, and performance;
- skill progress from repeated exposure or relevant performance patterns.

Pilot skills should not overpower mech buildcraft. They should make the pilot feel persistent and learned through the war.

## Loot and build modification

Loot should be simple in Version 0.2. It can be parts, salvage currency, or a small reward table, but it must create a reason to modify the mech before the next deployment.

The important test is not economy depth. The important test is whether the player wants to adjust the build after seeing sortie results, loot, and pilot growth.

## Deferred from Version 0.2

Defer:

- full warfront map and territory control;
- authored mission board as the main adaptation driver;
- gear/mech customisation surface implementation;
- multiple pilots;
- full NPC town capture/death simulation;
- LLM-generated live narration;
- seasonal titles/skins;
- real backend or live multiplayer;
- deep loot economy;
- common pilot permadeath.

## Version 0.2 success question

Version 0.2 succeeds if this loop feels worth repeating:

> I changed my mech, deployed it into a pool, saw or received deterministic battle outcomes, retreated, earned loot and pilot XP, learned something, modified the mech, and wanted to fight again.
