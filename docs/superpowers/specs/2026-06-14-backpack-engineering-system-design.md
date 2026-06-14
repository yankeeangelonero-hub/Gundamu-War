# Backpack Engineering System — Design

Date: 2026-06-14
Status: Design approved in brainstorm, pending written review.
Owner: Xuanyue
Branch: backpack-system-test
Upstream intent: docs/wishlist/wishlist.md (r2), docs/pilot-and-war-front-high-level-spec-and-work-map.md

This is the design for the mech *engineering* layer of Kitbash Mecha — the backpack you
assemble before a fight. It came out of a brainstorm following the 3D combat test, which is
proven and stays as-is. This document defines what feeds that combat, not the combat itself.

It reshapes the original Layer-1 "machine engineering budget" (KM-ENG) and the kitbash
part-tree assumption: instead of a tree of body parts, the build is a single spatial grid.
The wishlist (r2) is not edited by this; this is the concrete engineering system that sits
under its three-layer model, with Layer 2 (pilot-fit / sync) deliberately reduced to "the
pilot supplies unique items" for this version and the in-fight sync meter deferred.

## v0.1 scope — the traditional gauntlet

v0.1 builds the proven Backpack-Battles loop first, to test whether the backpack
*engineering* is fun before any of the bespoke meta is grafted on. The persistent bonded
pilot, salvage acquisition, and pilot-milestone grid expansion are all deferred to 0.2+.

What v0.1 is:

- A run is a gauntlet of escalating fights. Start with a small bag and some gold. Each round
  is a shop phase (buy, sell, reroll, combine items into upgrades, buy bag expansions) then a
  deterministic auto-battle against a ghost opponent drawn through the existing injected
  opponent source (KM-OPP). No persistence between runs.
- A lives system: a few hearts, a loss costs one, the run ends at zero or at a win threshold.
- Acquisition is shop-only. The grid grows by buying expansions, not by pilot milestones.
- The pilot is the Backpack-Battles "hero": the player picks a pilot before the run; she
  gives a starting signature item and defines a small unique-item pool the shop can offer.
  No pilot *system* beyond that — it is the toehold the 0.2 persistent pilot grows from.

The engineering core under test is unchanged from the sections below: the unified grid, the
power battery economy, shaped adjacency-transforming supports, and the three scaling vectors.

## What this is

The build is one unified, expandable spatial grid — a backpack, in the Backpack-Battles
sense. Every build decision is placing a shaped item in that grid. There is no separate
part-tree; the grid *is* the mech's loadout, and it is the only build surface the player
learns. The engineering tension — power, heat, weight, the cost of firepower — lives
entirely in the grid. The body never refuses a build; the grid does.

The defining hook is that the grid is not abstract: whatever you slot also appears on the
3D mech you watch fight. The build screen and the battlefield show the same machine, so a
loaded-out backpack reads instantly as a mech bristling with guns.

## The 3D mech is a visualizer, not a second constraint

The grid drives gameplay; the 3D mech faithfully shows the result and imposes no rules of
its own. Each item type has a preferred mount and a fallback priority list — a beam rifle
goes to a hand by default, and if both hands are taken it cascades down the line (forearms,
shoulders, hips, back booms) to the next free hardpoint. We guarantee enough generic
hardpoints to display a maxed loadout, so a build of ten rifles really does mount a gun on
every limb. Item-to-hardpoint assignment is automatic, with an optional cosmetic override
for players who want to re-route for looks. Provenance and placement are presentation only;
they never feed back into the simulation.

## Power is the one resource — a battery economy

There is a single currency: power. The mech has a power pool that refills at a regen rate.
Every item is one of three kinds:

- Builders — reactors and generators. They give pool and/or regen, and they cost grid
  cells you could have filled with weapons.
- Spenders — weapons and active systems. They cost power to fire.
- Multipliers — passive armor and buffs. Defense is treated as an HP multiplier.

Builders feed the economy, spenders convert power into damage, multipliers amplify. A good
build is these three in balance, not three of the same corner.

The pool-plus-regen model creates a burst-versus-sustain axis. A big pool with slow regen
hits hard once and then recharges — the alpha strike. A small pool with fast regen chips
steadily and never goes quiet. This is also what keeps the "ten rifles" build honest: you
can mount ten, but your reactor only regens so fast, so most of them sit idle waiting for
charge. The cap on quantity is economic, not a rule.

This reads cleanly in a watched fight. A power-starved mech visibly goes quiet mid-battle —
guns hanging idle, the power bar flatlined — so the player can see *why* it underperformed
and what to change (more regen, or fewer guns). Underperformance is legible, never bad luck.

## Adjacency synergy with transforming supports

Synergy is spatial. Support items placed next to a weapon do not add a flat percentage;
they transform it, in the Path of Exile support-gem sense — fork, chain, multishot, charge —
and the transform is visible in the watched fight, so a forked beam actually looks forked on
the mech.

Supports are themselves shaped items of different sizes, like everything else in the grid.
A weapon benefits from each distinct support whose shape touches one of its edges. The
keystone rule: a weapon's open, support-touching edges are its links. A weapon with room to
breathe can be fed by several supports and becomes a hero weapon; a weapon jammed in a
corner stays nearly bare. Placement is the craft.

Because supports are shaped and sized, stacking them is a genuine packing fight: a small
support tucks into a corner and still touches the weapon, while a large, powerful support
eats real estate and crowds out the neighbours that would also have buffed the gun. The
shape is the cost. And a heavily-supported weapon costs far more power per shot, which ties
the synergy puzzle straight back into the battery economy.

Decision pinned in this design: supports and multipliers apply by adjacency, not globally.
A buff reaches what it touches.

## Bag expansions and recipes

Two grid mechanics carry over authentically from Backpack Battles.

Bag expansions are items, not an abstract cell purchase. The shop sells container items — a
hardpoint pylon, a weapon rack, an external bay — that the player places into the grid and
which grant their own cells. A container can carry flavour of its own, such as an ammo bay
that buffs the weapons racked in it or an energy bay sized for reactors. Growing the grid is
therefore a placement decision with trade-offs, and the mech visibly grows external racks.

Recipes fuse component items into stronger ones, and the system is authentic to Backpack
Battles:

- A recipe UI (a browsable book) shows what combines into what, so the player can plan
  toward a target item.
- Merging is adjacency-triggered but resolves at the next round transition, not immediately.
  Placing the ingredients next to each other queues the merge; it fires when the next round
  begins, giving the player a full shop phase to see it coming.
- Items can be locked to prevent merging. A lock is what lets an adjacent pair stay together
  as a synergy pairing without fusing.

Passive adjacency-synergy and opt-in merging coexist by this rule: adjacency buffs are live
every round, while a merge fires only when an adjacent pair is unlocked and a recipe matches.
Recipes are data — ingredient items to result item — per the data-driven contract.

## Three independent scaling vectors, no counters

There is no rock-paper-scissors matchup relationship between build types. Tall, wide, and
tank are three independent directions you can scale, and any of them, built well, can
overpower the others. Power comes from build quality, not from a matchup advantage.

- Go-tall — one or two monstrous, heavily-linked, power-hungry hero weapons. High ceiling,
  a single point of failure, dead recharge windows.
- Go-wide — many cheap, bare guns plus count-scaling multipliers (a fire-control array
  worth more the more weapons you have; volume of fire that overwhelms a regenerating
  shield a single big hit can't crack). Degrades gracefully.
- Tank — multiplier-heavy and defensive.

The support and multiplier pool must reward both tall and wide so neither is a trap.

The no-counters rule is a deliberate fit for the async-PvP endgame: you fight a stored ghost
you cannot counter-pick against, so a hard-counter triangle would land as matchup luck —
unfair and illegible. "Build it well and you win, regardless of what it meets" upholds the
positive-valence and legibility contracts.

## The pilot supplies unique items

For this version the pilot is not a separate subsystem. She is a source of unique items —
signature weapons, supports, and passives that only she brings — and her growth unlocks more
and better ones. Attachment lives in her kit: the forked twin-beam is *hers*. Everything is
still just an item in the grid, so there is one mental model to learn.

The wishlist's in-fight sync / breakthrough meter is deferred. It slots in later as item
behaviour (a signature item that powers up mid-fight) without disturbing anything here.

## Acquisition and expansion

In v0.1 acquisition is the traditional shop gauntlet: between rounds the player buys, sells,
rerolls, and combines items, and buys bag expansions, all with gold earned per round. The
grid grows by purchase. Runs do not persist.

The fuller, persistent model is the 0.2+ target and is recorded here so it is not lost.
There, the build grows over a persistent bonded pilot with no fresh-run reset, through three
sources:

- Salvage — strip items off mechs you beat. On-theme, persistent, and the tie into the
  existing homecoming loop.
- Shop — buy and reroll items with currency for variety the drops alone won't supply.
- Workshop — combine and upgrade items: fuse two bare rifles into a better one, level a
  support.

In that version the backpack expands — more cells — through pilot milestones rather than
purchase, so growing the grid is tied to growing the pilot you're attached to.

## How this honours the existing architecture

- Determinism (BEH-D01): the grid resolves to a deterministic build the sim consumes from
  {build, seed}; the same backpack and seed produce the identical fight.
- Data-driven (CON-D06): items, supports, mounts, hardpoint cascade lists, and
  combine-recipes are all data, not code.
- Legibility (CON-D05): a below-ceiling result traces on screen to power starvation or poor
  placement, never to luck.
- Positive valence (CON-D04): losing costs slower growth, never permanent harm; the
  no-counters rule keeps async losses fair.
- Opponent-source (CON-D03): salvage, shop, and later real-player provenance never leak into
  the sim or the renderer.

## Deferred and still open

- The in-fight sync / breakthrough meter (later, as item behaviour).
- Exact grid shape and the cell-expansion schedule per pilot milestone.
- Currency tuning, shop reroll rules, and salvage drop rates.
- The concrete support catalogue (which transforms exist) and combine-recipe set.
- Whether large supports that touch a weapon along multiple edges count once or scale with
  contact length.
