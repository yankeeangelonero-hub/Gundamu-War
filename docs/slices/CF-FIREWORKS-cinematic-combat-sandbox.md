---
project: kitbash-mecha
repo: gundamu-war
spec_id: CF-FIREWORKS
version: "0.1"
doc_type: slice-spec
status: draft
created: 2026-06-20
updated: 2026-06-20
---

# CF-FIREWORKS — First Cinematic Combat Sandbox

## 1. Decision

The first playable target is **not** the balanced gauntlet. It is the fireworks build:

```text
choose / assemble two mech weapon combinations
→ press Fight
→ deterministic fight log is generated
→ choreographer stages it
→ hybrid director films it
→ the result reads as a Gundam fight
```

Balance, shop economy, hearts, progression, recipes, and long-run tuning come after this proves the core promise: different mech archetypes produce different anime combat.

Fireworks first. Balance later.

## 2. North Star

Target: **Gundam fight readability**, not a generic effects reel.

A generated fight should make the matchup readable:

- a rifle/missile pressure build should feel oppressive and spatial;
- a buster artillery build should feel slower, heavier, and dangerous when it commits;
- a saber/booster build should feel predatory, close-range, and evasive;
- a shield/tank build should feel attritional, defensive, and hard to finish;
- a mixed arsenal duel should feel like a pitched battle with escalation and reversals.

The structure can be tuned later. The tracking must support the target now: one-sided stomps and difficult pitched battles are both valid, but they must render differently.

## 3. Baseline

`godot_director_spike/data/fight_log_everything.json` is the authored fireworks baseline.

It proves spectacle density and director usability:

- 23.1s duration;
- 101 total events;
- 50 attack events;
- 48 advance events;
- 10 boost advances;
- full arsenal coverage: beam, burst, missiles, buster;
- lethal buster finisher.

It is not the final taste target. It is too metronomic, too symmetric, light on defensive/reversal beats, and lacks melee. Generated fights should use it as a minimum fireworks benchmark, not as a mold.

## 4. Pipeline

```text
build / weapon combination
→ deterministic build-vs-build sim
→ combat-truth event log
→ choreographer
→ staged fight log
→ hybrid director grammar
→ Godot rendering/frontend
```

Ownership rule:

```text
Truth decides what happened.
Choreographer decides where it happened.
Director decides how to see it.
Renderer makes it visible.
```

## 5. Fight Log Tracking / Spectacle Profile

Every authored or generated candidate fight should have a spectacle profile, not just raw JSON.

Track:

- log id;
- authored/generated;
- seed;
- build archetype A;
- build archetype B;
- matchup shape: stomp, pitched battle, comeback, attrition, artillery execution, melee chase, ranged pressure, mixed arsenal duel;
- fight duration;
- event count and attack density;
- longest dead-air gap;
- weapon mix;
- heavy-beat count;
- defensive/reversal beats: block, evade, miss, stagger recovery, shield catch, interrupted charge;
- movement profile: advance count, boost count, stagger count, range-state changes;
- director beat availability: opening hero beat, mid escalation, melee cut, bullet-time/finisher, aftermath hold;
- finisher quality;
- human taste verdict.

Minimum report output:

```text
baseline: fight_log_everything.json
candidate: <generated-log-id>
result: passes/fails fireworks floor
notes: what reads differently and whether that difference matches the archetypes
```

## 6. Required Archetype Set

The sandbox must prove at least three distinct generated matchup reads:

1. **Rifle + Missiles vs Mixed Arsenal** — ranged pressure, spatial saturation, frequent hero-cut candidates.
2. **Buster + Shield vs Rifle Pressure** — slower tempo, defensive beats, heavy artillery punctuation, decisive finisher.
3. **Saber + Booster vs Artillery** — close-range chase, evasive movement, melee-cut candidate, danger of a stomp if the saber closes cleanly.

Additional useful shapes:

- one-sided stomp;
- difficult pitched battle;
- comeback win;
- shield attrition;
- artillery execution.

## 7. Acceptance Criteria

The slice is done when:

1. A profiler can produce a spectacle profile for `fight_log_everything.json`.
2. A minimal deterministic build-vs-build simulator can generate a candidate fight log from two weapon combinations and a seed.
3. Same builds + seed reproduce the same normalized event log byte-for-byte.
4. The generated log can be staged by the choreographer and consumed by the hybrid director, either directly through the v2 cutover or through a temporary v2-to-v1 adapter.
5. A comparison report exists for each generated fight against `fight_log_everything.json`.
6. No candidate intended as a fireworks fight has an unintentional dead-air failure.
7. Each required archetype produces a visibly different spectacle profile and a different rendered read.
8. At least one generated fight includes a defensive/reversal beat.
9. At least one generated fight includes a melee or close-range chase beat.
10. At least one generated fight ends in a heavy/finisher beat with aftermath space.

## 8. Immediate Implementation Order

1. Fix the choreographer same-tick precedence bug before landing it.
2. Build the fight-log spectacle profiler.
3. Add a temporary generated-log comparison report against `fight_log_everything.json`.
4. Build the minimal weapon-combination sim.
5. Wire sim → choreographer → hybrid director, using an adapter if faster than full director migration.
6. Add a crude build picker / fight launcher.
7. Generate and judge the three required archetype fights.

## 9. Explicitly Deferred

- balanced shop economy;
- hearts / run loss structure;
- long-term gauntlet progression;
- recipe/merge depth;
- tuned PvP fairness;
- pilot-fit / sync layer;
- full content balance.

Those systems are allowed to wait until the fight generator proves it can make the anime combat worth building around.

## 10. Known Blocker

The current uncommitted choreographer implementation has a same-tick precedence bug:

- if reactive evade/stagger starts on the same tick as ambient stride, both `advance` events are emitted;
- current active-beat lookup can pick ambient instead of higher-priority reactive;
- current tests avoid stride-boundary reactive windows, so the green test suite misses it.

This must be fixed before `cf-choreographer` is treated as landed.
