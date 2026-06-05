---
project: mech-bags
artefact: research-document
kind: concept-handoff
status: frozen
created: 2026-06-05
source: xuanyue
supersedes: null
---

# Backpack Auto-Battler — Concept Handoff

**Status:** Early concept exploration. Core loop is borrowed from an established genre; the design work here is entirely in the meta layer. Nothing is locked.

-----

## The premise

A backpack auto-battler in the lineage of *Backpack Battles* and its imitators. The combat itself — load a grid with weapons and parts, battles resolve automatically, shop between rounds — is **solved territory and not the point**. The genre is well-trodden and we’re not trying to reinvent it.

The actual design question is everything that sits *above* the run: the meta progression.

## Market read

The genre’s meta layer is currently thin. What exists in the wild is mostly:

- **PVP ladder climbs** (the dominant form)
- **Roguelike survival climbs** (a minority)

Almost nobody is doing anything orthogonal to “climb a competitive ranking.” That gap is the opening.

## The pivotal fork

The whole design hinges on one question:

> **Do players build one backpack consistently over many hours, or is each backpack built fresh and disposable per run?**

- *Persistent build* → attachment, mastery curve, identity. But slow to pivot, so the meta calcifies.
- *Fresh run* → every session is novel, the meta stays volatile and resists convergence. But nothing to get attached to.

**Where we landed:** the initial instinct was fresh-run, but the central innovation (below) pulls hard toward persistence. By the end of the discussion the fresh-run structure was effectively abandoned in favour of a persistent backpack living in an arena.

## The central innovation: asynchronous offline PVP

Your backpack fights **while you’re away** — submitted into a wider community pool of other players’ backpacks, grinding through matches overnight. You check back in to harvest results.

This is the differentiator. It reframes the game from a roguelike into something closer to a **persistent roster-building idle game**:

- Craft and tune your backpack once; adjust between matches.
- It runs on your phone / in the background. Auto-battling is cheap to simulate, so this is feasible.
- **Tight feedback when active:** when you do submit, battle reports stream back within minutes — engagement isn’t gated on the overnight cycle alone.
- **The morning harvest:** check in, see how your backpack did overnight, collect the spoils. “Harvesting from the farm.”

### Loot & economy

Winning yields **currency + scavenged parts dropped from defeated backpacks**, which feed upgrades. This is doing double duty:

1. Tangible progression to chase on every check-in.
1. **Emergent diversity** — because you’re looting whatever the community is actually fielding, you’re forced to adapt to the live meta rather than optimizing in a vacuum.

## The unresolved tension: meta convergence

The known failure mode: everyone reverse-engineers one optimal build and the asynchronous pool flattens into mirror matches.

Two proposed levers to keep it alive, **not yet reconciled**:

1. **Natural rock-paper-scissors cycling** — meta build emerges → counter-build farms it → counter becomes the new meta. Healthy *only if* the balance window is tight enough that no apex build sits beyond counterplay. The risk is exactly that: a true apex with no hard counter.
1. **Injected randomness** — keep outcomes noisy enough to resist pure optimization.

Note these pull against each other philosophically, and both interact with the persistence/fresh fork. This is the biggest open design knot.

## The pilot layer (newest, riskiest, possibly the spine)

Idea: each backpack has a **pilot** you build a relationship with over time, who has their own goals/arc.

Why it might be the strongest piece: relationships are meta-progression that **can’t be solved and discarded** the way a build can. People don’t reroll a pilot they’re invested in. That’s genuine, durable stickiness — and it’s a natural answer to the convergence problem, since attachment fights the urge to mirror the optimal loadout.

**The trap to avoid:** if pilot affinity is just “+10% damage,” it’s a stat with a face painted on. Players min-max it and the relationship is decorative. To earn its place, the pilot must change **how you play, not how hard you hit** — e.g. temperament that shifts performance against certain enemy archetypes, or preferences that constrain the loadout, so building *around* a pilot becomes a real strategic identity.

## The open structural question for whoever picks this up

There are now **three progression layers competing for attention**: the build, the loot farm, and the pilot. The idle-loot-farm game (optimization, churn) and the pilot game (attachment, continuity) point in different directions. They can coexist, but —

> **Which layer is the spine, and which ones serve it?**

Resolving that is the next real decision. Current lean: the pilot is probably where the heart of the game wants to live, *if* it’s framed as the answer to meta-staleness rather than a fourth system bolted on.

## Open questions, condensed

1. Persistent backpack vs fresh run — looks settled toward persistent, confirm.
1. Balance-window tightness needed to keep the counter-meta cycle healthy (and how to prevent a no-counter apex build).
1. Randomness vs structural cycling — pick a primary, or define how they combine.
1. Pilot mechanics: how does the pilot alter *play* rather than stats?
1. Which of the three layers is the spine.
