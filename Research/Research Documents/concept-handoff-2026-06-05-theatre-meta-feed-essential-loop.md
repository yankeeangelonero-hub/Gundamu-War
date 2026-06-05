---
project: mech-bags
artefact: research-document
kind: concept-handoff
status: frozen
created: 2026-06-05
source: xuanyue
supersedes: agent-handoffs/opus-essential-loop-distillation-report.md
supersedes_section: "mission-condition and pilot-risk framing for the essential loop"
---

# Essential Loop Revision — Theatre Meta Feed Instead of Mission Condition Risk

**Status:** Owner correction. This document records Xuanyue's disagreement with the prior essential-loop distillation and replaces the mission-condition / pre-deploy-risk framing with a theatre-performance feed framing.

---

## Owner correction

Xuanyue disagrees with making the essential loop about mission conditions and pilot-risk tuning.

The intended loop is not:

> The mission tells me what build is good, and I tune risk against the mission.

The intended loop is closer to:

> I build the strongest mech I can, send it into the theatre, then read the enemy-side top-performing build feed to understand what is dominating and what I should adapt against.

The game should make the player feel like they are entering a live war theatre with a changing meta, not optimizing against authored mission modifiers.

## New essential loop candidate

The corrected loop is:

1. Player builds what they believe is the strongest mech available.
2. Player deploys the mech into a theatre/front.
3. Background combat resolves against the theatre's current enemy build population.
4. A theatre feed shows the top-performing enemy mech builds and patterns.
5. The player's report shows how their mech performed against that meta.
6. The player adjusts their build to counter or exploit the visible theatre meta.
7. The next deployment tests that adaptation.

This is a meta-reading loop, not a mission-condition loop.

## What the feed should show

The feed should reveal enough about enemy success patterns to make adaptation feel strategic without becoming a solved spreadsheet.

Possible feed entries:

- top enemy chassis/archetypes in the theatre;
- most successful weapon families;
- common support modules;
- win-rate or threat bands rather than exact perfect statistics;
- notable ace / squad builds;
- “rising threat” and “declining threat” patterns;
- what killed or countered the player's last build.

Example feed:

```text
Northern Theatre Enemy Performance Feed

1. Shield Turtle variants are holding 62% of defense encounters.
   Common pattern: Torso shield core + Back armor + Head sensor.

2. Missile Backpack variants are rising after yesterday's artillery push.
   Common pattern: Back missile stack + Ammo Box adjacency.

3. Saber Rush variants are failing against armor-heavy patrols.
   Counter-signal: close-range burst drops sharply when Torso armor is high.
```

The feed should be diegetic: intelligence reports, scout logs, captured telemetry, ace sightings, and battle-analysis summaries.

## Pilot layer reframing

The pilot can still create stakes, but the first loop should not be primarily about explicit pre-deployment risk tuning.

Pilot consequences should emerge from performance and survivability in the theatre:

- a fragile build that gets repeatedly destroyed may fatigue or wound the pilot;
- a build that survives but loses may impose mild fatigue;
- a well-performing build preserves pilot condition and builds reputation;
- severe pilot outcomes should remain rare and readable through combat performance, not arbitrary mission danger labels.

The pilot layer should reinforce the cost of sending a bad build into the theatre, not turn every deployment into a risk-management form.

## Implication for Version 0.2

The next version should validate the smallest loop around theatre meta adaptation:

- existing build surface;
- one theatre/front;
- deterministic enemy build population;
- background/simulated combat batch or representative encounters;
- theatre feed showing top enemy patterns;
- player report showing matchup outcome and pilot consequence;
- one more build adjustment cycle.

Do not center Version 0.2 on authored mission condition tags or mission-fit readouts unless they are subordinate to the theatre meta feed.

## Grid-vs-gear implication

The grid-vs-gear question remains open, but the comparison criterion changes.

The question is no longer primarily:

> Which surface best communicates mission suitability and pilot risk?

It becomes:

> Which surface best helps the player read a changing theatre meta and build a counter-mech?

For now, the existing grid surface can remain the implementation surface while the meta loop is tested.

## Deferred or reduced

The following should be reduced for the essential loop:

- authored mission-condition modifiers;
- explicit risk meters as the main pre-deploy decision;
- full warfront map;
- titles/seasonal rewards;
- multiple pilots;
- real LLM narration;
- built gear-surface comparison.

## Open questions

1. What stats are shown in the theatre feed without making the optimal counter obvious?
2. How many enemy builds/archetypes are enough for the feed to feel alive?
3. Does the player fight one sampled enemy, a batch of encounters, or an abstracted theatre sortie?
4. How should pilot fatigue/wound chance derive from performance without punishing experimentation too harshly?
5. Does the grid surface make counter-building against a meta feed satisfying enough for Version 0.2?
