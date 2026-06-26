# M0/M1 Game-System Bridge - Loadout to Fight Design

Date: 2026-06-26
Status: Draft for owner review.
Owner decisions captured: 2026-06-26 design grilling in Codex.
Upstream:
- `docs/wishlist/wishlist.md`
- `docs/slices/CF-FIREWORKS-cinematic-combat-sandbox.md`
- `docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md`
- `docs/superpowers/specs/2026-06-17-combat-sim-internals-design.md`

## 1. Purpose

This document joins the immediate combat-sandbox route to the backpack-grid route.

The next system must prove, in this order:

1. Different loadouts create different cinematic fights.
2. The backpack grid is fun to manipulate.

The player-facing prototype should start from the build surface, not from a pure debug picker,
but the fight generator underneath should consume the same future-proof resolved-loadout shape
that the real grid resolver will eventually produce.

In short:

```text
simple backpack-facing build choice
-> resolved loadout contract
-> deterministic M0 fight sim
-> choreographer
-> hybrid director
-> spectacle profile
```

The design target is not balance yet. The target is the power fantasy: build a complex mech from
a simple system, press Fight, and see the machine become as powerful as the player imagined it
would be.

## 2. Locked Owner Decisions

- **Primary proof:** different loadouts produce different cinematic fights first; grid fun second.
- **Prototype surface:** start on the backpack/grid side, not a stats-only combat picker.
- **Sim input:** use a fake-but-future-proof M0 input shape: raw data for now, identical contract to
  the future M1 grid resolver output.
- **First archetypes:** rifle/missile pressure, buster artillery, saber/booster melee chase.
- **Shield/tank semantics:** visible defensive beats, mechanically simple HP underneath.
- **Fight length:** 35-50 seconds; more duel drama than the current short fireworks baseline.
- **Randomness:** medium, seeded hit/miss and damage variance, with an explicit chaos parameter so
  drama can be art-directed.
- **Outcome bias:** better builds should usually/near-always win. No hard counter triangle.
- **Archetype tendencies:** allowed for cinematic texture, but not as matchup-luck counters.
- **Player choices before full grid maturity:** archetype presets first.
- **Sides:** player builds the player mech; opponent is a preset.
- **Pilot presence:** pilot supplies a light wrapper/signature item/archetype identity; no sync or
  growth yet.
- **Explicitly out now:** pilot growth, network/PvP, war map.

Clarification baked into this draft: the owner response included both "no counters" and "light
tendencies"; this design treats that as **no hard counters, but readable archetype tendencies**.

## 3. Product Shape of the Next Prototype

The next playable surface should feel like the start of the real game, not a spreadsheet:

```text
choose pilot/signature wrapper
-> choose or load an archetype kit for player mech
-> see a simple backpack/grid-facing representation of that kit
-> choose an opponent preset
-> press Fight
-> watch a 35-50s deterministic cinematic duel
-> read spectacle profile / result
```

The build surface can begin with archetype kits rather than full free placement. The important
thing is that the player perceives "this is my mech I assembled" before the fight. Full grid
drag/drop can come in as the next layer once the loadout-to-fight seam is solid.

## 4. The Resolved Loadout Contract

M0 consumes resolved loadouts. M1 later produces them.

```text
ResolvedLoadout {
  id: String,
  archetype: String,
  pilot_id: String,
  hp: int,
  power_identity: String,
  weapons: Array[ResolvedWeapon],
  defense_beats: Array[String],
  feel_bias: Dictionary,
  spectacle_intent: Dictionary
}

ResolvedWeapon {
  id: String,
  motif: "beam" | "burst" | "missiles" | "buster" | "saber" | "booster" | "shield",
  tier: int,
  damage: int,
  cooldown: int,
  accuracy: float,
  initiative: int,
  travel: int,
  variance: float,
  tags: Array[String]
}
```

M0 data can be hand-authored archetype presets. M1 grid resolution later fills the same fields
from placed reactors, weapons, supports, and pilot signature items.

## 5. Chaos Parameter

Chaos is deterministic drama, not nondeterminism.

```text
chaos: 0.0 to 1.0
```

It scales presentation and seeded variance while preserving reproducibility:

- hit/miss spread;
- damage variance;
- frequency of miss/block/evade defensive beats;
- chance that a trailing volley lands after the lethal decision;
- choreographer willingness to create near-collisions, chase beats, or reversal-shaped staging.

Guardrail: chaos may create drama, but it should not routinely invalidate build quality. At
default chaos, a better-built mech should win clearly most of the time; high chaos is an
art-direction mode for more dangerous, volatile fights.

## 6. Archetype Contracts

### Rifle/Missile Pressure

Fantasy: spatial pressure and saturation.

Sim shape:
- multiple mid-cooldown weapons;
- medium accuracy;
- medium travel;
- frequent attack events;
- missile beats create visible dodge/near-miss opportunities.

Profile target:
- high attack density;
- beam + missile weapon mix;
- many director hero-cut candidates;
- no long dead-air gaps.

### Buster Artillery

Fantasy: slower, heavier, dangerous commitment.

Sim shape:
- one or two high-tier heavy weapons;
- long cooldown;
- high damage;
- longer travel;
- lower event density but strong punctuation.

Profile target:
- heavy-beat count matters;
- long setup is acceptable only if other lighter weapons or defensive beats prevent dead air;
- finisher should often be heavy.

### Saber/Booster Melee Chase

Fantasy: predatory close-range pursuit.

Sim shape:
- fast saber/contact weapon;
- booster-tagged movement intent;
- shorter travel;
- lower ranged density but strong melee-cut availability.

Profile target:
- melee cut available;
- boost count high after choreography;
- chase shape reads distinct from artillery and ranged pressure.

### Shield/Tank, Deferred as Primary Archetype

Fantasy: attritional, defensive, hard to finish.

For M0, shield/tank is mechanically simple:
- HP and maybe accuracy pressure do most of the real sim work;
- defensive beats are emitted or tagged for art direction;
- no deep armor/mitigation system yet.

This keeps shield/tank as a visible read without forcing a defensive combat economy before the
first three archetypes are proven.

## 7. Sim Responsibilities

The M0 sim decides:

- fire schedule by cooldown/initiative;
- seeded hit/miss;
- seeded damage variance;
- impact timing by travel;
- HP changes;
- lethal impact;
- post-decision trailing shots;
- final result.

The M0 sim does not decide:

- 3D position;
- camera;
- exact dodge animation;
- range band choreography;
- sync/growth;
- war state;
- PvP verification backend.

## 8. Presentation Responsibilities

The choreographer/director decide:

- spawn positions and advance beats;
- chase, pressure, and artillery staging;
- defensive beat visualization;
- camera grammar and cuts;
- aftermath space;
- spectacle readability.

The profiler measures whether the result delivered the intended read:

- duration;
- attack density;
- longest dead-air gap;
- weapon mix;
- heavy beats;
- defensive/reversal beats;
- movement/boost profile;
- director beat availability;
- finisher quality.

## 9. Build Surface Bridge

The first player-facing version should not expose raw HP/cooldown/damage sliders. That belongs in
debug tools.

Recommended first surface:

- one pilot/signature wrapper;
- three player archetype kits;
- one opponent preset selector;
- a simple backpack/grid preview that shows the kit as shaped items;
- Fight button.

The grid preview can be non-final at first. Its job is to teach that the player is building a
machine, not selecting a menu class. As M1 comes online, the same archetype kits become starter
placements that the player can edit.

## 10. Pilot Wrapper

Pilot is present but light:

- name/portrait/callsign optional;
- one signature item or signature kit modifier;
- shop/growth/sync absent;
- no permanent harm;
- no relationship loop yet.

The pilot should make the build feel authored by a person without pulling v0.2 pilot-fit work into
M0.

## 11. Out of Scope

Explicit owner-forbidden for this step:

- pilot growth;
- network/PvP;
- war map.

Also not required for this bridge, even if not permanently forbidden:

- shop economy;
- hearts/lives;
- salvage;
- recipes;
- full balance pass;
- full freeform grid editing;
- pilot sync/breakthrough.

## 12. Acceptance

The bridge is good enough to build on when:

1. A player chooses one of the three archetype kits for the player mech and an opponent preset.
2. The selected kit appears as a simple mech/backpack build, not only text stats.
3. Pressing Fight produces a 35-50s deterministic duel through the hybrid director.
4. Same player kit, opponent preset, seed, and chaos value reproduce the same normalized event log.
5. Rifle/missile, buster artillery, and saber/booster produce visibly different fights.
6. The profiler reports different spectacle profiles for those archetypes.
7. Medium chaos creates drama without making outcomes feel arbitrary.
8. Better builds win by build quality, not by hard-counter matchup luck.
9. The player can look at the fight and say: "yes, that machine did what I built it to do."

## 13. Remaining Owner Decisions

These can wait until implementation planning:

1. What is the pilot/callsign for the first signature wrapper?
2. What exact three opponent presets should ship with the first picker?
3. What default chaos value feels right: restrained `0.35`, cinematic `0.50`, or volatile `0.70`?
4. Should the first backpack preview be static archetype kits only, or allow one editable slot?
5. Should the 35-50s duration target be enforced by HP/damage tuning only, or should there be a
   soft minimum-duration guard in the generator?
