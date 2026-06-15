# Research synthesis — what makes combat read "Gundam UC" vs "MechWarrior"

> **SEEDING DOCUMENT — combat & camera feel.** Canonical reference; read before any combat,
> camera, or fight-choreography work. Camera work makes or breaks the game feel. Findings F1–F10.
> Companion: `research-synthesis-2026-06-15-weighty-mecha-multi-title-and-cockpit.md` (F11–F21).

Date: 2026-06-13. Source: deep-research pass on the Torrington Base battle (Gundam Unicorn,
OVA Ep 4 / RE:0096 Ep 11) and UC mobile-suit combat direction. 15 sources, 25 claims verified
(20 confirmed, 5 killed). Strongest evidence: the Sejoon Kim sakugabooru interview (primary,
a UC key animator). Full raw report in the workflow output.

**Purpose:** the v0.4 director spike currently reads MechWarrior (heavy grounded bipeds trading
fire on a flat plane). This extracts the transferable *craft* that would shift it to UC feel.

**IP guardrail (CLAUDE.md):** every item below is craft — movement, camera, pacing, staging.
None of it is Gundam IP. Implement with original mecha identity (mono-eye / single visor band,
no V-fin, no twin-eye, no RX-78 silhouette). Named units in the research (Unicorn, Byarlant,
Kshatriya, Shamblo, etc.) are cited only as evidence, never to copy.

---

## Diagnosis: why the current spike reads MechWarrior

The camera is NOT the problem. The single highest-confidence research finding — Kim's "back and
forth between cameraman and subject," constant reframing across planes, authored cut rhythm, and
framing-for-scale — is *exactly what the hybrid director already does* (iso base + intercut hero
shots + bullet-time + over-shoulder + fit-to-scale). Our camera grammar is on-target for UC.

The MechWarrior read comes entirely from the **bodies and the movement model**:

| Current spike (MechWarrior) | Gundam UC | Finding |
|---|---|---|
| Locked to `y=0` ground plane | 3D volume — boost up, dive, hover, fight airborne | F3 |
| Constant-velocity linear tweens (a walk) | Burst-thrust → coast → hard vector-change (propellant-aware) | F1, F3 |
| Turret-style yaw rotation | Limb-driven AMBAC snap — arms/legs whip the torso around | F2 |
| Pure ranged tracer/beam trading across a gap | Mixes beam fire + all-range homing swarm + brutal closing melee | F7, F8 |
| Uniform attrition to a kill | Momentum-swing arc: pressure → hero reversal → late marquee duel | F10 |

---

## The principles (verified findings)

**Movement**
- **F1 — Weighted but agile.** Mass/inertia is deliberately emphasized (heavy starts/stops/pivots,
  overshoot-and-settle) yet motion is *economical and controlled*, never twitchy or weightless.
  Heavy ≠ slow; weighted ≠ flailing. *Tunable: accel/decel curves, pivot ramp, stop overshoot.*
- **F2 — Limb-driven reorientation (AMBAC).** A humanoid snaps its facing by swinging limbs
  (angular-momentum counter-rotation, "falling cat"), layered on thruster translation → fast
  snap-pivots that read alive and humanoid, not like a rotating chassis.
- **F3 — Genuinely 3D, burst-coast movement.** Vertical lift, hover, dives, lateral burst-strafes,
  dash-cancels. Movement is *punctuated bursts of thrust with coasting between*, not a constant gait.

**Camera (validates current direction — keep doing this)**
- **F4 — Camera as active second actor.** Constant back-and-forth with the subject, never staying
  in one plane, mixing depth/angle through an exchange. (Our hybrid already does this.)
- **F5 — Authored cut rhythm.** Pacing and composition are primary levers: a shot schedule per
  beat (establish → mid action → close impact → reaction), varied shot durations. (We do this.)
- **F6 — Framing sells scale.** Low/wide/distant = awe + giant scale; tight over-the-shoulder =
  weight + intimacy on impacts. Alternate by intent. (We do this; lean harder on melee OTS.)

**Weapons / exchanges**
- **F7 — Three exchange modes, not one.** (a) aimed beam fire, (b) all-range homing swarms that
  arc and converge from all directions, (c) sustained dodge-pursuit runs (one suit weaving a storm
  of projectiles — "Itano circus"). Far richer than two units hitscanning across a gap.
- **F8 — Melee is a distinct visceral mode.** Closing dashes, grapples, beam-blade clashes,
  structural-tearing contact kills — staged with the closest/heaviest framing and densest cuts.

**Scale & staging**
- **F9 — Scale via consequence.** Sell size through yield and collateral: single shots gouge
  terrain and level buildings; one oversized unit produces screen-filling devastation. A
  hand weapon framed as capital-ship-grade firepower. (We have destructible buildings; push the
  hero-weapon yield framing.)
- **F10 — Asymmetric momentum-swing dramaturgy.** A massed raid reversed by one high-mobility hero
  unit, staggered deployments/arrivals, a marquee duel held for a late escalation beat. The battle
  is a dramatic arc with turning points, not a steady exchange.

---

## Concrete changes for the spike, by leverage

**Tier 1 — kills the MechWarrior read (movement model):**
1. **Add verticality.** `to_y` on advance waypoints; mechs boost up, dive, hover, clash airborne.
   Single biggest shift — UC fights use the vertical volume; we never leave the floor.
2. **Burst-coast-snap motion.** Replace uniform position lerp with a thrust profile: fast accel
   (EASE_OUT thrust), ballistic coast, hard vector-change at the next waypoint. Add a boost flare
   at each thrust onset (directional thruster glow opposite the accel vector).
3. **Limb-driven snap-reorientation.** On hard facing changes, swing the arms (and a leg) as a whip
   that counter-rotates the torso, instead of pure yaw lerp. Even a simple arm-swing sells AMBAC.

**Tier 2 — exchange variety (beyond stand-off fire):**
4. **Melee mode.** Closing dash + beam-blade clash + contact kill, with the heaviest OTS framing and
   densest cuts. Consider making the lethal blow a saber strike, not just a beam.
5. **All-range homing swarm** (original "remote bits"): projectiles that detach, arc wide, and
   converge — one exchange type. And a **dodge-pursuit run** (a weave through a projectile storm).

**Tier 3 — staging & scale:**
6. **Momentum-swing fight arc** in the log: pressure → reversal → late marquee-duel climax, not
   uniform attrition. Staggered "arrivals."
7. **Hero-weapon yield framing** — the kill shot reads as capital-ship-grade (bigger beam, bigger
   collateral, whiteout, screen-fill).

All of this stays **deterministic** — verticality, thrust profile, melee, and swarms are just
event/waypoint data on the existing log → director → garnish pipeline; same seed + log ⇒ same
result, so PvP re-sim verification still holds.

---

## Do NOT use (refuted or weak in research)

- **Refuted 0-3:** "pilot skill beats equipment" framing; and that the Torrington raid's purpose
  was to buy time to unlock a specific super-mode. Don't build narrative around either.
- **Weak 1-2:** "aggressively swing into close-ups during intense moments." Superseded by the
  better-sourced steady *back-and-forth reframing* (F4) — don't add jerky whip-zooms.

## Open design questions the research surfaced (for the build plan)

1. Numeric "weighted but agile" — exact accel/decel curves, pivot ramp, overshoot/settle values.
2. The shot-selection grammar that reproduces "back-and-forth + authored cuts" deterministically
   per beat type (we have a first version in the director variants).
3. The right *proportion* of melee vs ranged vs all-range-swarm within one fight to feel UC.
4. How much destruction is intentional (aimed at structures) vs incidental, modeled deterministically.
