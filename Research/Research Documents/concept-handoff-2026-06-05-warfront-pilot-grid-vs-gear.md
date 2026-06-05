---
project: mech-bags
artefact: research-document
kind: concept-handoff
status: frozen
created: 2026-06-05
source: xuanyue
supersedes: Research/Research Documents/concept-handoff-2026-06-05-backpack-autobattler-meta.md
supersedes_section: "meta-layer direction and open structural question"
---

# Warfront, Pilot Stakes, and Grid-vs-Gear Fork — Concept Handoff

**Status:** Early concept exploration. This document records the next conceptual pivot after the initial backpack-autobattler meta-layer handoff. Nothing here is locked as a permanent invariant. The next version should test the uncertain parts before the project commits to a production direction.

---

## The expanded premise

The project may move beyond isolated mech-customisation PVP into a living asynchronous warfront.

In this direction, players are not only tuning a mech for detached arena matches. They are fielding a persistent machine and pilot into a simulated battlefield where many mechs fight in the background. The campaign front changes daily. Towns, areas, NPC squads, and pilots can gain status, be captured, be wounded, disappear, or die. Players return to battle reports, rewards, titles, and a changed mission board that pushes them to adapt builds.

The stronger pitch is:

> A persistent mech and pilot fight in an asynchronous warfront whose territories, missions, NPCs, rewards, and risks change over time.

## LLM war director, deterministic war truth

The LLM should not be the hidden arbitrary decider of rewards or losses. The trustable shape is a split system:

- The deterministic war simulator owns territory state, faction pressure, mission outcomes, pilot conditions, reward eligibility, and title eligibility.
- The LLM war director turns those facts into anime briefings, town reports, NPC lines, rival taunts, and after-action drama.
- A validation layer prevents impossible state transitions, unfair rewards, or lore changes unsupported by the simulator.

The LLM can make the war feel alive, but the game state should remain inspectable and rule-bound.

## Warfront loop to test

The candidate macro loop is:

1. Build or tune mech.
2. Assign pilot and deploy to mission/front.
3. Background battles resolve against simulated or saved builds.
4. Warfront state updates: pressure, captures, town status, NPC squad outcomes.
5. Player receives report, salvage, reputation, title progress, and pilot condition.
6. Mission board changes; player adapts the mech for the next front.

This preserves mech customisation as the player-facing action while adding a reason for builds to change over time.

## Pilot layer as the stakes layer

The pilot layer makes the warfront emotionally consequential.

A poor mech or risky mission should not only mean a match loss. It can mean the pilot is fatigued, wounded, out of service, missing, or in rare high-risk cases killed/retired. This creates a strategic and emotional tradeoff: the player is not just optimizing damage, but deciding how much risk to put a person inside the machine through.

The starting injury ladder should be readable and non-punitive:

1. Unharmed
2. Fatigued
3. Lightly wounded
4. Seriously wounded / out of service
5. Missing in action
6. Killed / retired — rare, high-drama, opt-in or severe-war event tier

Pilot risk must be visible before deployment. It should be affected by mission danger, mech protection, safety equipment, pilot experience, enemy archetype, and whether the player chooses a desperate/high-reward sortie.

## Pilot mechanics should change play, not act as flat stats

The pilot layer earns its place only if it shapes decisions.

Good pilot mechanics:

- mission preferences and specialties;
- risk tolerance and retreat behavior;
- injury/recovery constraints;
- pilot-specific titles and hometown/faction ties;
- build preferences that encourage different equipment choices;
- consequences for repeatedly deploying a wounded or mismatched pilot.

Weak pilot mechanics:

- generic affinity meters;
- flat +10% damage bonuses;
- decorative portraits with no deployment consequence;
- heavy life-sim meters that distract from mech building.

The pilot should make the player ask: “How do I build this mech for this pilot and this front?”

## The grid-vs-gear fork

The next major design uncertainty is whether the project should keep the Backpack-style grid system or shift toward a more conventional gear-and-mech-customisation system.

### Option A — Keep backpack/grid body-part bags

Strengths:

- The current prototype already proves this toy.
- Spatial placement gives the game a tactile identity.
- Shape, rotation, adjacency, and bag expansion create readable buildcraft.
- Unrestricted placement creates the memorable “Beam Rifle in Head is valid” identity.

Risks:

- It may feel like a Backpack Battles reskin if the warfront/pilot layer does not become strong enough.
- Mobile placement/editing friction must remain under control.
- The grid may fight the fantasy of high-fidelity mech customisation if players expect limbs, frames, joints, armor, and weapon hardpoints.

### Option B — Shift to gear and mech customisation

Strengths:

- More directly supports the mech fantasy.
- Easier to express armor, cockpit safety, limbs, frames, engines, sensors, and pilot survivability.
- May communicate war-readiness and mission suitability more naturally.
- Could make pilot injury risk easier to reason about through cockpit/armor/escape systems.

Risks:

- Loses the distinctive spatial toy that the prototype already made playable.
- Risks becoming a generic loadout screen.
- Harder to preserve Backpack Battles-style adjacency/synergy charm.
- May push the project toward more simulation complexity before the fun is proven.

## Required next-version test

The next version should explicitly test this fork rather than decide it in prose.

Minimum comparative test:

- Prototype or design two build surfaces for the same warfront/pilot mission loop:
  - Body-part backpack grid version.
  - Gear/mech customisation version.
- Run the same sample mission brief through both surfaces.
- Check which one better communicates:
  - “what the mech can do”; 
  - “why this build fits the mission”; 
  - “what risk the pilot is taking”; 
  - “why I should adjust after the warfront changes”; 
  - “why this is not just a normal PVP ladder.”

The version should not commit to either surface until this test produces evidence.

## Candidate next-version spine

The next version should probably be a concept-validation version, not production PVP.

Candidate goal:

> Validate whether Mech Bags should remain a body-part grid builder or pivot to gear/mech customisation by testing both surfaces inside a small persistent warfront + pilot-risk loop.

Candidate scope:

- one local warfront board;
- a small set of missions and territory/town state changes;
- one or two pilot profiles with visible condition/risk;
- battle reports that connect build performance to warfront state;
- comparative build-surface test: grid vs gear;
- no real networking, no accounts, no live global war backend.

## Open questions

1. Is the project’s core toy spatial grid placement, or mech loadout fantasy?
2. Does pilot risk make players more attached or make them afraid to experiment?
3. Can a deterministic local warfront feel alive enough with LLM-generated reports layered on top?
4. Which build surface better pushes daily adaptation when the mission board changes?
5. What is the smallest demo that proves the warfront/pilot direction without building a full strategy game?
