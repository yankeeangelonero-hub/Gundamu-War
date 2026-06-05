---
project: mech-bags
artefact: research-document
kind: concept-handoff
status: frozen
created: 2026-06-05
source: xuanyue
supersedes: Research/Research Documents/concept-handoff-2026-06-05-theatre-meta-feed-essential-loop.md
supersedes_section: "pilot layer reframing"
---

# Pilot Skill and XP Layer — Concept Handoff

**Status:** Owner addition. This document records Xuanyue's requirement that pilots should have skills, levels, and XP within the theatre-meta essential loop.

---

## Owner addition

Pilots should not only have condition and consequence states. They should also have skills, levels, and XP.

The pilot layer therefore has two linked responsibilities:

1. **Stakes:** a poor mech can fatigue, wound, or temporarily remove the pilot from service.
2. **Growth:** repeated deployment, survival, and strong performance should develop the pilot through XP, levels, and skill progression.

This makes the pilot a persistent career identity, not just a damage-risk token.

## Fit with the theatre-meta loop

The essential loop remains theatre-feed driven:

1. Player builds the strongest mech they can.
2. Player deploys into the theatre.
3. Theatre combat resolves against enemy build population.
4. Feed shows top enemy builds and patterns.
5. Player adapts the mech to counter the meta.

Pilot XP should sit inside this loop as the career feedback layer:

- sorties grant pilot XP;
- better performance grants more XP;
- surviving harsh matchups may grant specialty XP;
- repeated exposure to the same enemy archetype can develop relevant skills;
- injuries or out-of-service time interrupt progression without deleting it.

## Skill design principles

Pilot skills should change play rather than act as flat generic bonuses.

Good skills:

- improve readability or counterplay against specific theatre patterns;
- reward coherent build identity over universal power;
- create soft preferences without invalidating player creativity;
- make a pilot feel experienced in the theatre they survived.

Weak skills:

- generic `+10% damage` as the main progression;
- opaque hidden modifiers;
- skills that make one pilot/build combination obviously optimal forever;
- progression that makes new or injured pilots unusable.

## Candidate skill categories

### Combat familiarity skills

These grow from facing enemy archetypes and help the player adapt to the meta feed.

Examples:

- **Missile Pattern Reader** — after repeated missile-heavy encounters, the pilot slightly improves survival/reporting against missile burst patterns.
- **Shieldline Breaker** — grows after fighting Shield Turtle variants; improves identification or exploitation of shield-heavy enemies.
- **Saber Duel Sense** — grows from close-range rush encounters; improves performance or warning signals against melee burst.

### Mech-handling skills

These grow from using certain build styles.

Examples:

- **Heavy Frame Handling** — improves stability or recovery in armor-heavy builds.
- **Back-Mount Familiarity** — improves reliability of builds centered on Back modules.
- **Sensor Discipline** — improves the value/readability of sensor-heavy builds and reconnaissance reports.

### Survival and recovery skills

These reinforce the pilot as a person trying to survive the war.

Examples:

- **Emergency Egress** — reduces severity of catastrophic losses if safety systems are present.
- **Damage Control Routine** — reduces fatigue from losses where the mech survives.
- **Medbay Discipline** — improves recovery from wounded to ready states.

## XP and level expectations for the essential loop

For the smallest version, pilot progression should be visible but not deep.

Minimum viable version:

- one pilot;
- one visible pilot level;
- XP gained after each sortie;
- one or two skill tracks tied to encounter/build patterns;
- level-up or skill-progress message in the sortie report;
- no full pilot roster yet;
- no permanent death in the essential-loop prototype.

Example report lines:

```text
Pilot XP +42
Aki reached Level 2.
Skill progress: Missile Pattern Reader 2/5
Condition: Fatigued
```

The player should understand that the pilot is learning from the theatre, even when the mech loses.

## Consequence and growth should coexist

A bad sortie can still teach the pilot if they survive. The report should distinguish:

- **performance outcome** — win/loss, damage dealt, survivability;
- **pilot condition outcome** — ready, fatigued, wounded, out of service;
- **pilot growth outcome** — XP, level, skill-track progress.

This prevents injury from feeling like pure punishment and makes difficult deployments narratively useful.

## Implication for Version 0.2

The distilled Version 0.2 should include pilot XP/skill progression as a small essential-loop feature if pilot identity remains in scope.

Recommended V0.2 treatment:

- Keep one pilot.
- Add Level and XP bar/readout.
- Grant deterministic XP from sortie result and survival.
- Add one or two skill-progress tracks linked to enemy theatre archetypes or build usage.
- Show XP/skill progress in the post-sortie report.
- Keep injuries simple: Ready / Fatigued / Wounded / Out of Service.
- Do not add multiple pilots, deep skill trees, pilot permadeath, affinity systems, or life-sim meters yet.

## Open questions

1. Should pilot XP reward wins most, survival most, or learning from specific enemy archetypes most?
2. Should skill tracks be chosen by the player, unlocked by behavior, or both?
3. How much can pilot skills affect combat before they overpower mech buildcraft?
4. Should injured pilots continue earning reduced XP from after-action analysis, or should progression pause while out of service?
5. What is the smallest skill display that makes the pilot feel persistent without turning V0.2 into an RPG system?
