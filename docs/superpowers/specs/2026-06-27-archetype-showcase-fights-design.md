# Archetype Showcase Fights — Design

Date: 2026-06-27
Branch: combat-feel-restart
Status: design, pending owner review
Roadmap: advances `m0-sandbox-sim` (the "archetypes read distinctly" requirement). Introduces one
new render feature (Remote Bit Swarm) that the data-as-archetype rule does not cover.

## What this is

Four signature showcase fights — one per archetype — where each archetype is *fully expressed*:
a fuller-than-base loadout, fought against a foil opponent chosen to flatter its identity, rendered
through the locked hybrid director. They are the visual target we tune archetype distinctness
against. The loop they enable: watch all four back to back, name what does not read differently
enough, tune the grammar/loadout data, re-watch. The showcase is the artifact we tune toward; we are
deliberately not building an automated quality ruler to do this — the eye is the judge.

The honest art reality: the game has essentially one mech body and weapons read through effects,
mounted props, motion, and framing rather than bespoke per-build sculpts. So for the three
data-only archetypes, identity is expressed through weapon cadence, feel/grammar (heft, tempo,
mode mix), range bands, and finisher — not through three unique mech models. The fourth archetype
(Remote Bit Swarm) is the exception the owner explicitly chose to build as a real render feature.

## The four archetypes

"Fully expressed" means the aspirational peak of the build — the feared-ace version — not the
current two-weapon starter kit.

| Archetype | Fully-expressed loadout | Identity in motion | Foil ghost |
|---|---|---|---|
| Rifle / Missile Pressure — *relentless gunner ace* | beam rifle + micro-missiles + sustained second beam/vulcan + targeting supports | never lets up, holds mid/far range, constant beam+missile rhythm, kites, clean beam finish | `artillery_ghost` (slow heavy it picks apart at range) |
| Buster Artillery — *heavy executioner* | buster cannon + heavy beam + shield + charge/cooling supports | slow, deliberate, big punctuated charge commits, shield tanks, devastating finisher | `pressure_ghost` (pokes it, so commits read as risk→payoff) |
| Saber / Booster Chase — *aggressive duelist* | twin sabers + booster + vulcan/shield-break for the approach | closes with boost dashes, melee pressure, fast chase, saber-strike finish | `pressure_ghost` (a runner it has to catch) |
| Remote Bit Swarm — *the encircler* (funnel) | bit-swarm core + a sidearm beam + control supports | mech hangs back, deploys bits that surround the enemy and fire from all angles, converging-volley finish | `duelist_ghost` (a lone aggressor the swarm overwhelms) |

The Remote Bit Swarm name is original on purpose — the funnel concept inspires it, but the project
bars real IP, so the in-game identity uses original naming.

## Tier 1 — three data-only showcases

The rifle, buster, and saber showcases need no new engine code. They are:

- Three new `*_showcase` entries in `data/m0_loadout_kits.json` carrying the fuller loadouts above,
  each with its foil opponent and a chosen showcase seed and chaos recorded alongside.
- A `--showcase=rifle|buster|saber|swarm` convenience flag on `main.gd` that resolves a showcase
  name to its (kit, foil, seed, chaos) and plays it through the existing `--auto-fight` render path,
  so the owner launches with one clean argument instead of five.

Identity is expressed through the existing levers: weapon cadence in the loadout, the grammar preset
per archetype (gunner = light/fast/ranged, anvil = heavy/slow, a melee-aggressive preset for saber),
range bands, and finisher. The already-tuned camera films it unchanged.

## Tier 2 — the Remote Bit Swarm feature

This is the one archetype whose attacks do not originate from the player mech. Every other attack
fires from the mech; bits fire from detached points surrounding the enemy. That is new to the
renderer, and it is the funnel fantasy, so it is built for real — kept minimal but honest.

Sim side (small): a new `bit_swarm` weapon motif. The player mech emits a deploy event, then
bit-volley shot events where each shot's payload carries its origin (`origin: "bit"`, a `bit_index`,
and a deterministic orbit angle), and a recall/converge event on the finisher. The two-mech position
sim is untouched — bits are driven entirely by these logged events, so the same seed reproduces the
same bit angles and volley timing.

Render side (the new part): a `BitSwarm` set of small glowing drones owned by the player MechActor.
On deploy, six bits fly out and take orbit positions around the enemy at fixed deterministic angles.
On each bit-shot event, that bit fires a beam at the enemy from its position. On the finisher, the
bits converge for an all-angles volley, then recall. Six bits is enough to read as encirclement
without clutter.

Staging and camera: bits orbit the enemy at a set radius. The existing wide/iso shots already frame
both mechs, so they should catch the encirclement. A dedicated "swarm wraps the target" framing is
not assumed up front; if watching shows it is needed, that is a small grammar addition flagged then,
not built speculatively.

Identity in motion: the player mech hangs back (low self-movement, a director-not-brawler feel),
omnidirectional beams rain onto the enemy from around it, and the converging volley finishes. This is
maximally distinct from the forward-firing rifle ace.

Scope guard: bits are indestructible in the showcase — no bit HP, no bit-targeting AI, no
reposition between volleys. Deploy → orbit → fire → converge → recall, and nothing more. Bit combat
depth is a later concern, not this mockup. (Owner to confirm: six bits, indestructible, this
behavior set.)

## Determinism

All four showcases obey the project invariant: same showcase (loadout + foil) + seed + chaos
produces the identical normalized event log, including bit angles and volley timing. The bit feature
preserves this by deriving bit positions from the logged events and a fixed deterministic layout
rather than from any runtime randomness.

## Testing (TDD)

- All four showcases load and generate contract-valid logs; same inputs reproduce identical logs.
- The four are measurably distinguishable from each other (different weapon mix / finisher / tempo
  signature) — a light "these are not accidentally identical" regression, not a quality grade.
- Bit-swarm logs carry valid deploy / bit-origin / recall events with deterministic angles.
- Bits render at the expected orbit positions around the enemy (a headless position check, in the
  style of the existing camera/occlusion checks).

## Sequencing

Tier 1 (three data showcases) ships first so the eye-tuning loop starts immediately. Tier 2 (the bit
swarm) follows as its own build. They do not block each other.

## Out of scope

- Team battles (2v2 / 4v4) — a separate milestone with its own brainstorm, parked deliberately.
  Distinct archetypes from this work are a prerequisite for squads to read, so this comes first.
- Bit destructibility, bit AI, bit repositioning.
- Bespoke per-archetype mech sculpts or sculpted weapon models — an art-track dependency. Today's
  identity is effects + motion + framing.
- An automated bad/average/good spectacle ruler — explicitly rejected; the eye is the judge at this
  scale.

## Relationship to the roadmap

This work is the core of `m0-sandbox-sim`'s "different archetypes must produce distinct logs and
distinct camera/staging reads" requirement. The three data showcases are pure tuning over the
existing pipeline. The Remote Bit Swarm adds a contained render feature; per the project's
data-as-archetype rule a new archetype is normally just data, and this is the deliberate exception
(remote-origin attacks need real rendering), recorded here so the exception is explicit.
