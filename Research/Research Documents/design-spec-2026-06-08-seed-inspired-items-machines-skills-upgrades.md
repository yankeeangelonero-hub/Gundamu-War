---
project: kitbash-mecha
repo: gundamu-war
artefact: research-document
doc_type: design-spec
kind: finding
status: draft
created: 2026-06-08
source_request: "Owner request in Discord: Build me a Gundam seed inspired spec on items machines, skills and upgrades"
branch: backpack-system-test
ip_guardrail: "Original faction, machine, item, and skill names only; no Gundam, SEED, ZAFT, GAT-X, Phase Shift, N-Jammer, V-fin, split twin-eye, RX-78, Strike, Freedom, Justice, or other licensed terms/silhouettes."
feeds:
  - Project Version/Version 0.4/Slices/Slice 02 Specification.md
  - Research/Research Documents/test-brief-2026-06-08-comparable-backpack-system.md
---

# Design Spec 2026-06-08 — Seed-Inspired Items, Machines, Skills, and Upgrades

This is a branch-local design spec for the backpack comparator. It borrows the *shape* of the war-fantasy from Gundam SEED-like mecha fiction — prototype theft, battery limits, modular packs, ace silhouettes, beam-vs-armor counters, and war-era escalation — but it must remain an original setting and mechanical vocabulary. The project-level no-licensed-IP rule still holds: no names, factions, lore, silhouettes, V-fins, split twin-eye visors, or recognisable suit profiles from licensed material.

The design goal is a testable item economy for a single-canvas backpack system. The player is still the engineer. The machine fights by what is installed, where it is installed, and which pilot/machine skill packages are equipped. Upgrades may create real power escalation like Backpack Battles does, but the escalation must be paid for in visible constraints: footprint, heat, cooldown, dependency, power draw, timing, or counter-matchup exposure.

## Design pillars

- **Prototype arms race.** Machines are experimental field frames with swappable loadouts. Every item should feel like a war lab module: risky, power-hungry, tuned for a doctrine.
- **Energy pressure is the drama.** Strong items are not rare-tier stronger; they are hungry, hot, bulky, slow, or dependent on support modules. A build loses because it cannot feed its weapons, not because it lacks a +5 sword.
- **Backpack placement is engineering.** Shape, adjacency, conduits, reactors, armor plates, and weapon hardpoints are the readable build language.
- **Machine identity comes from loadout silhouette.** A blade rush frame, artillery frame, interceptor frame, and fortress frame should look and fight differently even with the same base grid.
- **Skills are doctrine, not magic.** Skills modify how installed items behave under conditions. They should read like pilot habits, OS tuning, or machine-control routines.
- **Upgrades are constrained escalation.** Some later items and upgrades can be stronger. They must also become more conditional, bulkier, hotter, slower, more power-hungry, or more counterable so the player reads the arms race instead of a flat stat treadmill.

## Machine model

A machine is a named build assembled from four layers:

1. **Frame** — defines canvas shape, base HP, base power throughput, heat tolerance, and default tags.
2. **Core system** — the central energy/OS item that anchors the build and often sets a doctrine bonus.
3. **Installed items** — shaped weapons, armor, mobility, reactor, sensor, and support modules placed on the backpack canvas.
4. **Skill package** — one pilot doctrine and one machine tuning package that alter deterministic item rules.

The comparator can start with one default frame and three preset builds, but the full spec below gives enough vocabulary to expand without redesign.

## Frames

Frames are not a linear rarity ladder. They are chassis with different board shapes and tolerances; advanced frames may have stronger rules, but they must expose sharper weaknesses or harder placement/power constraints.

| Frame | Shape fantasy | Base stats | Built-in rule | Weakness |
|---|---|---|---|---|
| **Aster Frame** | balanced prototype | 100 HP, 10 power, 10 heat | first `Beam` item installed gets -1 cooldown if connected to a power conduit | no extreme specialty |
| **Bulwark Frame** | heavy line-holder | 130 HP, 8 power, 14 heat | `Armor` items give +1 extra block when adjacent to Core | slow; mobility items cost +1 power |
| **Needle Frame** | light interceptor | 80 HP, 12 power, 8 heat | first movement action each cycle happens before same-time attacks | fragile; armor footprints count as one extra cell for placement |
| **Siege Frame** | artillery platform | 110 HP, 9 power, 12 heat | `Artillery` weapons gain +10 range when adjacent to Sensor | melee weapons start with +1 cooldown |

Recommended comparator scope: implement only **Aster Frame** first. Use the other three as named future presets or test data if easy.

## Item tags

Tags are the main rules vocabulary. Every item has 1–3 tags.

| Tag | Meaning |
|---|---|
| `Core` | central OS/reactor anchor; only one per build |
| `Beam` | energy weapon; high damage, power/heat pressure |
| `Kinetic` | physical weapon; lower heat, can punish shields or armor |
| `Blade` | close-range weapon; needs mobility or range control |
| `Artillery` | slow long-range attack; strong if protected |
| `Armor` | block, mitigation, anti-burst |
| `Shield` | timed defense; counters beam volleys but can be overloaded |
| `Reactor` | adds power or reduces energy starvation |
| `Conduit` | placement connector; carries adjacency from Core/Reactor |
| `Mobility` | closes, retreats, or changes attack timing |
| `Sensor` | improves accuracy, priority, or artillery targeting |
| `Drone` | independent small item timer; fragile but efficient |
| `Overdrive` | risky burst; creates heat/debt after activation |

## Item data contract

Each item should be data, not code:

```json
{
  "id": "beam_lance_mk1",
  "name": "Beam Lance",
  "tags": ["Beam", "Blade"],
  "footprint": [[0,0],[1,0],[2,0]],
  "powerDraw": 3,
  "heat": 2,
  "cooldown": 5,
  "range": 18,
  "damage": 26,
  "rules": ["if_connected_to_core:cooldown-1", "if_adjacent:capacitor:damage+4"]
}
```

Simulation rules must compile these strings or declarative rule IDs into deterministic functions. No arbitrary scripting.

## Starter item library

The first comparator should use 12–14 items. These are tuned to create three readable builds: burst, sustain, and clutter/misbuild.

### Core and power

| Item | Tags | Shape | Rule | Purpose |
|---|---|---|---|---|
| **Pulse Core** | `Core` | 2×2 square | emits `connected_to_core` through adjacent Conduits; +10 HP | default anchor |
| **Capacitor Cell** | `Reactor` | 1×2 | adjacent `Beam` item gets +4 damage but +1 heat | burst support |
| **Thermal Sink** | `Reactor` | 1×3 | adjacent item reduces heat by 2 per cycle | sustain support |
| **Power Conduit** | `Conduit` | 1×1 | extends Core adjacency through orthogonal chains | spatial glue |

### Weapons

| Item | Tags | Shape | Rule | Counterplay |
|---|---|---|---|---|
| **Beam Lance** | `Beam`, `Blade` | 1×3 line | high melee damage; -1 cooldown if connected to Core | needs mobility / range control |
| **Razor Saber Pair** | `Blade`, `Kinetic` | L triomino | two small strikes; bonus vs unshielded target | weak into armor |
| **Arc Rifle** | `Beam` | 2×2 corner | midrange shot; adjacent Sensor gives +15 range | power hungry |
| **Rail Javelin** | `Kinetic`, `Artillery` | 1×4 line | slow armor-piercing shot; ignores 30% block | needs protection |
| **Missile Hive** | `Artillery` | 2×3 rectangle | fires 3 small hits; adjacent Sensor retargets lowest HP component/fighter | bulky, slow |
| **Knife Drone Bay** | `Drone`, `Blade` | 2×2 | launches low-damage drone timer; adjacent Mobility gives +1 drone speed | fragile pressure |

### Defense and control

| Item | Tags | Shape | Rule | Counterplay |
|---|---|---|---|---|
| **Reactive Plate** | `Armor` | 1×3 | grants block before first incoming hit each cycle | weak to many small hits |
| **Prism Shield** | `Shield` | 2×2 | reduces next Beam hit by 60%; overloads if hit twice in a cycle | weak to kinetic/multihit |
| **Vector Thruster** | `Mobility` | 1×2 | close or retreat before first weapon if adjacent to a Blade/Beam item | costs power; bad placement wastes it |
| **Targeting Fin** | `Sensor` | 1×2 | adjacent Artillery/Beam gets +range and wins same-time tie | fragile, low direct value |

## Machine archetypes

These are not classes. They are build patterns the item set should support.

### 1. Dawn Knife — close burst duelist

- Core: Pulse Core
- Weapons: Beam Lance, Razor Saber Pair
- Support: Vector Thruster, Capacitor Cell, Power Conduit
- Defense: minimal
- Reads as: gets in fast, kills before shields matter.
- Loses when: thruster is not connected to blade path, or shield/armor build survives first cycle.
- Debrief examples:
  - `Beam Lance fired 3 times with Core conduit cooldown bonus.`
  - `Vector Thruster closed range before the first lance strike.`
  - `No armor installed; incoming rifle hits landed at full value.`

### 2. Bastion Choir — shield sustain machine

- Core: Pulse Core
- Weapons: Arc Rifle or Knife Drone Bay
- Support: Thermal Sink, Power Conduit
- Defense: Reactive Plate, Prism Shield
- Reads as: absorbs beam burst, wins by repeated safe attacks.
- Loses when: kinetic artillery ignores too much block or drones bypass shield cadence.
- Debrief examples:
  - `Prism Shield reduced 4 Beam hits but overloaded on cycle 3.`
  - `Thermal Sink prevented Arc Rifle heat debt.`
  - `Damage output lagged because only one weapon was installed.`

### 3. Choir Breaker — artillery counter-build

- Core: Pulse Core
- Weapons: Rail Javelin, Missile Hive
- Support: Targeting Fin, Thermal Sink
- Defense: Reactive Plate
- Reads as: punishes slow armor/shield builds from range.
- Loses when: blade rush closes before artillery cycles.
- Debrief examples:
  - `Rail Javelin ignored 30% block from Reactive Plate.`
  - `Targeting Fin won two same-time ties.`
  - `No Mobility item installed; melee opponent reached minimum range on turn 2.`

### 4. Bad Test Build — cluttered prototype

- Core: Pulse Core
- Weapons: too many weapons
- Support: no conduits or reactors
- Defense: mismatched Prism Shield not protecting against kinetic rival
- Reads as: visually plausible but mechanically incoherent.
- Loses because: energy starvation, inactive adjacency, too many cooldowns fighting for power.
- Debrief examples:
  - `Arc Rifle starved for power 3 times.`
  - `Capacitor Cell had no adjacent Beam item; no bonus applied.`
  - `Prism Shield prevented no damage because rival used Kinetic attacks.`

## Skill packages

Skills are deterministic rule modifiers. They do not add random crits. A build equips one **Pilot Doctrine** and one **Machine Tuning**.

### Pilot doctrines

| Skill | Rule | Good with | Bad with |
|---|---|---|---|
| **Opening Gambit** | first weapon to fire in a duel gets -1 cooldown and +10% heat | burst blade/rifle | sustain builds that do not need burst |
| **Conserve Fire** | if power would starve, skip lowest-priority weapon and reduce heat by 1 | overstuffed builds | pure rush that needs all attacks |
| **Shield Reader** | first attack each cycle prefers non-shielded damage type if available | mixed beam/kinetic builds | single-damage-type builds |
| **Close Quarters Habit** | if any Blade is installed, first Mobility action each cycle closes instead of retreats | blade builds | artillery builds |
| **Standoff Habit** | if any Artillery/Beam range > 60 is installed, first Mobility action retreats | rifle/artillery | melee builds |
| **Target Discipline** | Sensor adjacency also grants same-time tie priority to one adjacent weapon | sensor weapon nests | clutter builds with no sensors |

### Machine tunings

| Upgrade | Rule | Tradeoff |
|---|---|---|
| **Redline Capacitors** | Beam items adjacent to Reactor gain +3 damage | +1 heat per boosted shot |
| **Ablative Plating** | first Armor item gives +8 starting block | Mobility cooldown +1 |
| **Smart Conduits** | Conduit chains may bend through one Armor item | Conduits cost +1 power total |
| **Split Bus** | two weapons may draw power on the same timestamp without starvation | Core takes +1 heat |
| **Heat Bloom Venting** | if heat exceeds tolerance, clear 3 heat instead of firing lowest-priority weapon | skipped attack is logged |
| **Drone Handshake** | Drone item adjacent to Sensor fires before normal weapons once per cycle | Drone damage -2 |

## Upgrade economy

Upgrades widen the library and may raise power ceiling through visible escalation. Each group should add a new build question or a stronger-but-costlier tool, not a silent stat replacement.

### Tier 0 — Comparator library

Unlocked from the start for testing: Pulse Core, Power Conduit, Capacitor Cell, Thermal Sink, Beam Lance, Arc Rifle, Rail Javelin, Razor Saber Pair, Reactive Plate, Prism Shield, Vector Thruster, Targeting Fin, Missile Hive, Knife Drone Bay.

### Tier 1 — Role wideners

Tier 1 mostly broadens options. These are close to sidegrades.

Adds one new item per tag family:

- **Scatter Beam Emitter** — Beam multihit; counters single big shield, weak to armor.
- **Anchor Clamp** — Mobility control; prevents enemy retreat once per cycle, no damage.
- **Composite Guard** — hybrid Armor/Shield; weaker than either specialist but compact.
- **Micro Reactor** — tiny 1×1 reactor; efficient but creates heat debt.

### Tier 2 — Conversion packages

Tier 2 may be stronger than Tier 0 when the build supports it, but it demands placement or tag setup.

Adds items that convert one axis into another:

- **Heat-to-Block Vanes** — excess heat becomes temporary block once per cycle.
- **Kinetic Charger** — Kinetic hits charge the next Beam shot.
- **Sensor Ghost Line** — Sensor adjacency can count diagonally, but only for one item.
- **Drone Relay** — Drones extend conduit adjacency, but are disabled by artillery splash.

### Tier 3 — Ace identity packages

Tier 3 is allowed to feel like an ace-era escalation. These packages raise the ceiling, but they are bulky, conditional, and counter-buildable.

Adds high-commitment packages that define a machine silhouette:

- **Comet Pack** — Mobility + Beam package; extreme opening burst, poor sustain.
- **Citadel Pack** — Armor + Shield package; survives burst, vulnerable to armor-pierce.
- **Choir Pack** — Sensor + Artillery package; long-range timing control, vulnerable to rush.
- **Swarm Pack** — Drone package; many small timers, vulnerable to area/multihit counters.

These can be stronger than Tier 0 in their intended lane. They must also become more opinionated and easier to counter outside that lane.

## Upgrade rewards

Post-fight rewards should avoid stat inflation. Reward types:

- **New item pattern:** unlocks a new item, which may be a sidegrade or a stronger conditional item.
- **Canvas patch:** adds or reshapes board space, but introduces awkward geometry rather than pure more-space.
- **Doctrine chip:** unlocks a pilot doctrine.
- **Tuning chip:** unlocks a machine tuning.
- **Variant blueprint:** same item role, different footprint and adjacency needs.
- **Rival intel:** reveals a common enemy archetype so the player can counter-build.

Avoid rewards like `Beam Lance II +20% damage` when the only change is hidden arithmetic. A stronger-looking item is allowed if the cost is visible: bigger footprint, more heat, longer cooldown, tag vulnerability, stricter adjacency, rare support dependency, or a matchup that hard-counters it.

## Deterministic combat rules

The comparator should use a strict event loop:

1. Build derived stats from board placement: active adjacencies, conduit connectivity, power budget, heat tolerance, skill modifiers.
2. Initialize each active item timer from its cooldown and modifiers.
3. Find the smallest next event timestamp.
4. Resolve same-time ties by deterministic priority: skill priority, sensor priority, item anchor row, item anchor column, item id.
5. Apply power/heat checks. If an item cannot fire, log starvation or heat skip and schedule its next timer.
6. Apply attack/defense events. Defensive items must also be timer- or trigger-driven and logged.
7. Stop on HP <= 0 or max timestamp/event count.
8. Emit normalized event log and debrief facts.

No renderer state, animation timing, wall-clock time, or `Math.random` may affect simulation.

## Debrief facts

The simulator should collect debrief facts as structured counters rather than infer prose from raw logs later.

Suggested fact keys:

- `activeAdjacencyBonuses`: list of item pair + effect + count used
- `inactiveAdjacencyRules`: item + missing neighbor/tag
- `powerStarvedEvents`: item + timestamp + needed/available power
- `heatSkippedEvents`: item + timestamp + heat/tolerance
- `shieldBlocks`: item + blocked damage + source tag
- `armorBlocks`: item + blocked damage + source tag
- `rangeFailures`: item + timestamp + range needed/current
- `tieBreakWins`: item + reason
- `overkillOrWaste`: item + wasted damage/block
- `topDamageSources`: item + damage total

The debrief should choose 2–4 high-signal facts. It should not narrate every event.

## Example item JSON seed

```json
{
  "items": [
    {
      "id": "pulse_core",
      "name": "Pulse Core",
      "tags": ["Core"],
      "footprint": [[0,0],[0,1],[1,0],[1,1]],
      "powerDraw": 0,
      "heat": 0,
      "cooldown": null,
      "effects": [{"type":"core_source"},{"type":"hp_bonus","value":10}]
    },
    {
      "id": "beam_lance",
      "name": "Beam Lance",
      "tags": ["Beam","Blade"],
      "footprint": [[0,0],[1,0],[2,0]],
      "powerDraw": 3,
      "heat": 2,
      "cooldown": 5,
      "range": 18,
      "damage": 26,
      "effects": [
        {"when":"connected_to_core","type":"cooldown_delta","value":-1},
        {"when":"adjacent_tag","tag":"Reactor","type":"damage_delta","value":4,"heat_delta":1}
      ]
    },
    {
      "id": "prism_shield",
      "name": "Prism Shield",
      "tags": ["Shield"],
      "footprint": [[0,0],[0,1],[1,0],[1,1]],
      "powerDraw": 1,
      "heat": 1,
      "cooldown": 4,
      "effects": [{"type":"reduce_next_tag_damage","tag":"Beam","percent":60,"overload_per_cycle":2}]
    }
  ]
}
```

## Comparator presets

Use these as first-pass fixed builds.

### Preset A — Dawn Knife

Tests whether close burst is readable. Uses Beam Lance, Razor Saber Pair, Vector Thruster, Capacitor Cell, and Power Conduit. Expected: beats slow artillery if it closes, loses if shield sustain survives first cycles.

### Preset B — Bastion Choir

Tests whether defensive sustain is readable. Uses Arc Rifle, Reactive Plate, Prism Shield, Thermal Sink, and Power Conduit. Expected: beats beam burst, loses to armor-piercing rail/artillery.

### Preset C — Choir Breaker

Tests whether counter-build depth is readable. Uses Rail Javelin, Missile Hive, Targeting Fin, Thermal Sink, and minimal armor. Expected: beats slow shield builds, loses to blade rush.

### Preset D — Bad Lab Rig

Tests failure explanation. Uses too many weapons, poor conduit placement, inactive Capacitor, and a shield against the wrong damage type. Expected: loses with clear debrief about starvation and inactive adjacency.

## Build-slice implications

If this spec feeds the ready backpack comparator slice, the smallest build should implement:

- Aster Frame only.
- 6×5 canvas.
- 12–14 starter items.
- placement, rotation, overlap rejection, and board dump.
- adjacency preview.
- pure deterministic simulator.
- three presets plus one bad build.
- debrief facts and a comparison note.

Do not add shop, economy, animation polish, pilot relationship, war theatre, or unlock UI until the comparator proves the grammar is worth keeping.

## Decision pressure

This spec should let the branch answer the real question: does a single spatial item system make the machine feel more authored and easier to understand than the body-plus-deck split? If yes, the project can pivot through a proper cross-version transition. If no, the dual-layer direction should keep only the useful pieces: item tags, adjacency previews, energy pressure, and original ace-package flavor.
