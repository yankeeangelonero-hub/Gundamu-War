# FeelProfile — the per-build presentation lean

> Status: DESIGN, approved 2026-06-18 (rev. 2026-06-18, post-Codex review). The per-build bias that
> makes a build look like *itself* on screen, without touching combat truth. Modulates the two
> presentation stages (Director Grammar + Choreographer). Branch: `combat-feel-restart`.
>
> Consumes (out of scope here): the resolved build aggregate stats from the backpack `resolve(build)`
> — the same seam the sim's attacker list comes from. The sim only consumes the attacker *combat*
> stats (`damage, cooldown, accuracy, initiative, travel, motif, tier`); the FeelProfile additionally
> requires a small **`ResolvedBuildFeelStats`** view from that seam — **total weight, armor, and each
> weapon's `cooldown`, resolved expected `damage`, and `feel_mode_weights`** — so it never has to infer
> feel from motif strings, item ids, or the fight log. Defining that shape is the backpack spec's job;
> this spec only pins what it needs from it. Consumers:
> `docs/superpowers/specs/2026-06-16-director-grammar-design.md` (names the hooks `framing_emphasis`,
> `cut_cadence`, `mode_mix`) and `docs/superpowers/specs/2026-06-17-combat-choreographer-design.md`
> (movement cadence: `STRIDE`, boost frequency, ring radius).

## What this is

The Director Grammar is **global craft** — one body of cinematic technique films every fight the same
expert way. The Choreographer stages every fight the same way. The **FeelProfile is the per-build
*lean*** on top of both: a small bias bundle that makes a heavy bruiser read heavy and a nimble
gunner read nimble, **without rewriting** the grammar or choreographer.

It is a **pure function of a build's resolved stats** → a per-mech bias bundle. Deterministic,
per-BUILD (one per mech; two per fight). It is **not in the per-fight log, not combat truth, not
verified** — it is presentation modulation, re-derivable from the build. It is deterministic-but-cosmetic
*like* `motif`/`tier`, but **unlike** them it is never serialized in the combat-truth layer at all:
`motif`/`tier` ride in the log's truth layer and are merely *excluded from verification*, whereas the
FeelProfile rides nowhere in the log. It is passed to the presentation stages as a per-actor side
input; it does **not** touch the frozen log contract.

It supplies a **bias**; it never writes grammar/choreographer params. Consumers read the axes and
apply them as multipliers/offsets on their *own* params. (Per the grammar spec: "the FeelProfile
does not write any of these values… it supplies a per-mech bias the consumers apply on top.")

## Output (per mech)

Continuous axes + a normalized mode weighting + a reserved label:

- **`heft` ∈ [0,1]** — `0` nimble … `1` heavy. From total build weight (and armor). Biases framing
  toward weighty/over-the-shoulder and *slows* cadence.
- **`tempo` ∈ [0,1]** — `0` deliberate … `1` frenetic. From the build's **aggregate fire cadence**
  (its weapon cooldowns — the same cooldowns the sim's ATB fires on; a weapon fires only when its
  cooldown elapses, so attack speed is a build property). *Quickens* cadence. **Independent of
  `heft`** — a heavy build can fire fast (weighty framing, quick cuts).
- **`mode_mix`** — normalized weights over a small **open** set of exchange modes, **v1 =
  `{ranged, melee, barrage}`**, aggregated from each weapon's own mode weights (see Derivation). Biases
  which beats are favored. (`evasion`
  is a **reserved** mode, added when mobility/survivability stats feed it — the weighting gains a
  mode additively, no mechanism change.)
- **`archetype` (reserved, label only)** — a name for a *region* of `(heft, tempo, mode_mix)` space
  (e.g. high-`heft` + `melee` → "bruiser"; low-`heft` + high-`tempo` + `barrage` → "skirmisher").
  **Not built in v1**: defined as a thin derived function (region → name, a data table) to add when a
  UI/debug view wants to *display* it. New archetypes = new named regions, no mechanism change.

The mechanism is the **axes** (open: any new weapon feeds them via its stats; a new axis is additive);
the label is the **expandable archetype vocabulary** on top. This is the motif-registry philosophy
applied to feel.

## Derivation (build stats → axes)

Pure and deterministic from the resolved build aggregate. Directions are pinned; exact normalization
ranges/weights are tunable constants (a small param set), not frozen here:

- **`heft`** = normalize(total weight, + armor) against a reference build-weight range, clamped 0..1.
  Heavier ⇒ higher.
- **`tempo`** = normalize(aggregate fire-rate), where fire-rate summarizes the build's weapon
  cooldowns (e.g. a damage-weighted mean of `1 / cooldown`). Faster-cycling ⇒ higher.
- **`mode_mix`** = the **per-weapon mode weights carried by each weapon's definition** (an open map,
  e.g. `feel_mode_weights: {ranged: 0.7, barrage: 0.3}`), aggregated across the build weighted by each
  weapon's **resolved damage share** — its *pre-sim* expected damage per activation, **not** observed
  fight-log `damage` (the log omits misses and post-decision shots, so log-derived shares would make the
  profile per-fight / outcome-derived) — then normalized to sum 1. FeelProfile **aggregates** these
  maps; it does **not** switch-match weapon classes, so a new weapon (or a new mode key) feeds `mode_mix`
  purely through its own data and the open set stays open. (Authoring guidance, not a hard enum: a
  single-shot beam/cannon leans `ranged`; a high-rate / missile / burst weapon leans `barrage`; a melee
  weapon leans `melee`.)

**Empty / zero-damage build** (the sim permits no-attacker stalemates): the derivation has a pinned
deterministic fallback — `tempo = 0` and `mode_mix` = the neutral uniform distribution over the v1
modes (each `1/3`, still summing to 1) — so sum-to-1 is never impossible and the profile stays total.
`heft` is unaffected (weight/armor exist without weapons).

Monotonic by construction: a heavier build never lowers `heft`; faster cooldowns never lower `tempo`;
adding melee weapons never lowers the `melee` weight.

## Consumers (the bias, applied)

Each presentation stage reads the **per-actor** FeelProfile and applies it to its own params (the
FeelProfile never writes them):

- **Director Grammar** — `heft` → `framing_emphasis` toward weighty/OTS + longer `cut_cadence`;
  `tempo` → shorter `cut_cadence`; `mode_mix` → beat favoring (e.g. `melee` weight → more
  `melee_cut`; `barrage` → more projectile/track beats; the grammar's `evasion_beat` reads the
  reserved `evasion` weight when it lands).
- **Choreographer** — `heft` → longer `STRIDE`, fewer boosts (lower movement cadence); `tempo` →
  shorter `STRIDE`, more boosts; `mode_mix` → e.g. `barrage` lean biases the ring outward, `melee`
  lean closes it in.

`heft` and `tempo` both touch cadence and **compose** — each consumer blends them per its own tuning
(the FeelProfile only supplies the two axes; it does not pre-combine them). Because the two axes push
the same cadence params in *opposite* directions, each consumer **clamps** the blended result to its own
readable min/max — stride length, boost interval, and cut duration all have floors/ceilings so a light,
high-`tempo` build cannot collapse movement or cuts below a legible limit. The clamps live in the
consumers (the FeelProfile supplies unclamped axes); the exact limits are look-lock tuning, not pinned
here.

## Determinism & boundary

- Pure function of the build; same build → same FeelProfile. Re-derivable, so it never needs to ride
  in the log; it is **not** part of the verified projection (contract INV-VERIFY).
- It does **not** affect the sim or the outcome (INV-DET / INV-CLOCKS): two different FeelProfiles
  over the *same* combat log produce the same who-won, different presentation only.
- **Not the spectacle channel.** Kill/hero spectacle is per-shot `tier` carried in the log by the sim;
  `tempo` (attack speed) is the build property. So `tempo` is an axis and spectacle deliberately is
  **not** — the FeelProfile has no spectacle axis.

## Files (at implementation time — not now)

- New `godot_director_spike/scripts/sim/feel_profile.gd` — pure: `resolved build aggregate →
  {heft, tempo, mode_mix}`. No scene/render dependencies.
- New `godot_director_spike/tests/feel_profile_check.gd` — determinism (same build → same profile),
  **monotonicity** (heavier ⇒ ≥ `heft`; faster cooldowns ⇒ ≥ `tempo`; more melee weapons ⇒ ≥ `melee`
  weight), **bounds** (axes in `[0,1]`, `mode_mix` normalized to sum 1 — including the empty / zero-damage
  build's pinned `tempo = 0` + uniform-`mode_mix` fallback), and **outcome-independence**
  (the FeelProfile is never read by the sim — combat truth cannot depend on it).
- Consumer wiring (the grammar + choreographer reading the per-actor profile) lives in *those* stages'
  plans, gated by their tests — out of scope here.

## Out of scope / deferred

- **The archetype label function** (region → name) — reserved, not built in v1.
- **`evasion` mode + mobility/survivability-driven axes** — reserved (additive when those stats feed
  it).
- **The build `resolve(build)` → aggregate stats** — backpack spec (the input seam).
- **Exact tuning constants** (normalization ranges, blend weights) — set during the look-lock previz,
  not pinned in design.
- **Pilot-fit / sync (v0.2)** — a different system; the FeelProfile is the *build's* mechanical
  character, not the pilot bond.
