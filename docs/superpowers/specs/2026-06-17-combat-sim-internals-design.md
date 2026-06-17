# Combat Sim Internals — deterministic ATB resolution (produces the v2 fight log)

> Status: DESIGN, approved 2026-06-17. The deterministic engine that resolves a duel from two
> builds + a seed into the v2 fight event log. Second link in `build → sim → log → director`.
> Branch: `combat-feel-restart`.
>
> Targets the contract: `docs/superpowers/specs/2026-06-17-fight-event-log-contract-design.md`.
> Consumes (out of scope here): the grid build resolution + PoE damage algebra from
> `docs/superpowers/specs/2026-06-14-backpack-engineering-system-design.md`.

## Supersession

This design **supersedes** the earlier combat designs:
- `Project Version/Version 0.1/Slices/Slice-05-deterministic-atb-simulator.md` (the original ATB
  slice — its `simulate()` return shape and instant-damage event model are replaced).
- The part-*tree* combat assumptions in `prototype/game-core.js` — the build model is now the
  unified grid, and damage is no longer applied at the fire tick.

What carries forward from `game-core.js` is the **ATB resolution core itself** — it is proven and
deterministic; we port it to GDScript and extend it. What does not carry forward: the recursive
part-tree input, and instant (travel-less) damage.

## The model in one paragraph

Active-time-battle. Each weapon has a `cooldown`; it fires when its timer comes due. A fire rolls
hit/miss against the weapon's own `accuracy` (seeded), and — on a hit — a predetermined damage amount.
The shot then *travels*: its **impact** lands `travel` ticks later, and damage/HP only change at
the impact. The sim advances chronologically over **both** fire and impact events, resolving
impacts in impact-tick order. The first lethal impact decides the winner; after it, no new shots
fire, but shots already in the air still land (logged, zero damage). Same `(builds, seed)` →
identical combat-truth layer.

Combat is **whole-mech HP** in a two-mech duel: the target is always the other actor (no
target-node selection — that was a part-tree artifact and is dropped).

## What we keep from the proven core (`game-core.js`)

Ported to GDScript, behavior-preserving where it applies:

- **ATB scheduling.** Per-weapon `cooldown`; `next_fire` starts at `cooldown`; advance to the
  minimum due timer; after firing, `next_fire += cooldown`.
- **Seeded LCG PRNG, with the arithmetic pinned** (contract INV-DET). `s = (1664525 * s +
  1013904223) mod 2^32` with explicit **uint32 wrapping**; tick math is integer; damage rounding is
  **round-half-up** (matching JS `Math.round`). No `Time`/`randi`/wall-clock/float-position inputs.
  A miss still consumes the damage-variance rng slot so the stream shape is identical across
  hit/miss branches. These rules are what make a re-sim match across implementations, not just
  within one run.
- **Deterministic ordering of ready weapons.** When several weapons are due on the same tick, fire
  them in `initiative → stable hash → lexical` order (the `orderReadyAttackers` rule). The stable
  hash is **FNV-1a 32-bit** over `"<seed>|<side>|<id>"` (the JS `hashString`/`stableRank`), pinned
  like the LCG. (Target selection is gone — the target is always the other mech.)
- **Safety caps.** `MAX_BATTLE_TICKS` / `MAX_EVENTS` bound a runaway/stalemate fight; hitting a cap
  ends the fight with `result.cause = "cap"`, and zero attackers ⇒ `"stalemate"`. When the fight
  ends without a kill, `result.winner` = the mech with higher current HP (`"draw"` if equal).

## What we add (the v2 deltas)

### 1. Chronological fire + impact simulation (the core change)

The JS loop advances by fire time and applies damage at the same instant. With `travel`, fire and
resolution decouple, so the loop becomes a **single chronological event simulation** over two kinds
of scheduled event:

- a **fire** is due at a weapon's `next_fire` tick;
- an **impact** is scheduled at `fire_tick + travel` when that fire happens.

Each step advances time to the earliest pending fire-or-impact. **Phase rule within one tick:
impacts resolve before fires** (so a mech killed at tick T cannot also fire at T), and among
simultaneous fires the `orderReadyAttackers` order applies. Every emitted *event* gets the next
monotonic `seq`, so the log carries the frozen `(tick, seq)` total order the contract's INV-ORDER
requires. This single-pass loop is preferred over "generate all fires, then truncate" — no
after-the-fact truncation reasoning, obviously correct.

**At a fire** (weapon comes due, fight not yet decided):
- Roll `hit = rng() <= accuracy`; on a hit, roll the damage amount now (`base * variance`,
  round-half-up) — the outcome is *predetermined at fire* (matches the contract's "impact is already
  determined").
- Schedule its impact at `fire_tick + travel`. Do **not** change HP yet.
- Set `next_fire += cooldown`.
- (No log event is emitted at the fire tick — see §3, events are impact-anchored.)

**At an impact** (a shot lands):
- If the fight is already decided (an earlier lethal impact landed), emit the shot event with its
  rolled `outcome` and `post_decision: true`, **omitting** `damage`/`lethal`/`hp_after` — no HP
  change. This is the trailing "let the shots still land" volley.
- Otherwise, on a hit, subtract the predetermined damage from the target's current HP. Emit the
  `shot` event (with `damage`/`hp_after`) anchored at this impact tick. If HP reached 0, this is the
  **lethal impact**: the shot also carries `lethal: true`, and is *immediately followed* by a
  `destroyed` event (next `seq`, `actor` = the killed mech); mark the fight decided at this tick,
  set `result.winner`, and stop scheduling new fires.
- (A miss simply emits the `shot` with `outcome: "miss"` and no damage fields.)

Because lethality is evaluated at impact time in impact order, a fast weapon fired later can land
and kill before a slow weapon fired earlier — and the slow one then lands `post_decision`. Melee is
a single contact event resolved in the impact phase at its tick (no travel split).

### 2. `travel` is feasibility-bounded on the fire side

`impact = fire + travel`, and a weapon's first fire is at `first_fire_tick = spawn_tick + cooldown`.
So the earliest impact for any weapon is `first_fire_tick + travel` — the sim never produces an
impossible impact (contract `INV-FEASIBLE`). `travel ≥ 1` (fire and impact never share a tick).
`travel` is a weapon stat (from the build resolution), and it is a real tempo lever: heavy slow
weapons resolve late, light weapons trade early.

### 3. Emit the v2 contract directly

The sim writes the v2 **combat-truth layer** only, not the JS `{t, source, target, …}` shape:
- Events are **impact-anchored** (`tick` = impact tick), each with `seq`, in canonical `(tick, seq)`
  order (contract `INV-ORDER`).
- Each ranged shot → one `shot` event: `{motif, tier, travel, outcome, damage?, lethal?, hp_after?,
  post_decision?}` — **one resolved discharge per event** (no `rounds`/`hits`; multi-round bursts
  deferred). `damage`/`lethal`/`hp_after` only on a connecting, fight-not-yet-decided hit
  (`INV-IMPACT`).
- `melee` stays its own kind (~0 travel, `result: lock|knockback`).
- The sim emits the **combat-truth** structural events: `spawn` with **HP only**, and `destroyed`.
  Positional **placement** (`spawn` x/z) and `advance` movement are *presentation staging* supplied
  by the choreographer (out of scope here), not in the sim's output — the sim is positionless
  (`INV-CLOCKS`).
- The root `result {winner, cause}` is emitted at the end (`kill` / `cap` / `stalemate`).
- `motif` and `tier` are copied from the weapon definition onto each shot — deterministic-but-
  cosmetic; verification ignores them.

### 4. Outcomes are hit / miss only

Two outcomes, per the simplified contract. A "miss" is the suppressive-fire / ricochet volume; the
*renderer* chooses a whiff-vs-bounce visual by motif. No armor-deflection mechanic in the sim
(YAGNI; revisit only if armor should mechanically negate a hit).

## The seam to the backpack (out of scope here)

The loop consumes a **resolved attacker list** — one entry per weapon with `damage, cooldown,
accuracy, initiative, travel, motif, tier`. Producing that list from the unified grid build
(socketing, supports, PoE increased/more damage algebra, synergies) is the backpack spec's job. The
old `resolve(tree)` is the reference for *what* fields an attacker needs; the grid `resolve(build)`
replaces *how* they are computed. This spec assumes that list as input.

## Determinism checklist (carry from `ARC-001` / contract `INV-DET`)

- No `Time`, `randi`, `Math.random`, wall-clock, or frame-rate inputs anywhere in the sim.
- Single seeded LCG with **uint32-wrapping** arithmetic, integer ticks, round-half-up damage; rng
  draws in a fixed order (miss consumes the variance slot).
- All collection iteration is over deterministically sorted keys; all ties broken explicitly; every
  event stamped with monotonic `seq` so the order is total.
- `simulate(build_a, build_b, seed)` run twice → **identical combat-truth layer under canonical
  serialization** (sorted keys, integers as integers). This is the headless re-sim PvP verification
  relies on. (Raw file-byte equality is not required — the presentation layer may be regenerated.)

## Files (at implementation time — not now)

- New `godot_director_spike/scripts/sim/combat_sim.gd` (or a `sim/` module) — the ported +
  extended ATB engine; pure, no scene/render dependencies.
- New `godot_director_spike/tests/combat_sim_check.gd` — determinism (identical truth layer on
  re-run), canonical `(tick, seq)` ordering and the impact-before-fire phase rule (`INV-ORDER`),
  feasibility (`earliest impact = first_fire_tick + travel`), the death rule (first lethal impact decides;
  `destroyed` follows the lethal shot; trailing shots carry `post_decision` and no damage), and the
  terminal `result` for kill / cap / stalemate.
- The resolved-attacker input type is shared with the backpack spec (defined there).

## Acceptance

- Two runs of `simulate` with identical `(builds, seed)` produce an identical combat-truth layer
  under canonical serialization.
- The emitted log validates against the v2 contract (`fight_log.gd` v2 loader accepts it, including
  the `(tick, seq)` order assertion and the root `result`).
- HP sequencing is correct when a later-fired fast shot kills before an earlier-fired slow shot
  lands; the slow shot is then emitted `post_decision` with no damage.
- A lethal impact at tick D emits `destroyed` immediately after, ends new fire, and sets
  `result.winner`; every shot fired before D still appears, those landing after D carry
  `post_decision: true` and omit damage fields.
- Cap and no-attacker fights end with `result.cause` `"cap"` / `"stalemate"` respectively.
- No non-deterministic source is reachable from the sim (grep clean for `Time`/`randi`/etc.).

## Out of scope / deferred

- **Grid build resolution + PoE damage algebra** — backpack spec.
- **FeelProfile** (per-build lean) — separate spec; derived from this log, not part of the sim.
- **Positional combat** (range/cover affecting hit/miss) — rejected; the sim stays abstract
  (`INV-CLOCKS`). Travel is a weapon stat, not a distance computation.
- **Armor deflection / bounce as a mechanic** — deferred (YAGNI); outcomes are hit/miss.
- **Multi-target / AoE, status effects beyond the JS `emp`/`blast` flavor** — not in this pass.
