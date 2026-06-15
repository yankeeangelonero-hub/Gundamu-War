# Research synthesis — weighty mecha combat craft across four titles, with the cockpit lens

> **SEEDING DOCUMENT — combat & camera feel.** Canonical reference; read before any combat,
> camera, or fight-choreography work. Companion to the F1–F10 record
> (`research-synthesis-2026-06-13-gundam-uc-combat-feel.md`); adds F11–F21.

Date: 2026-06-15. Companion to `research-synthesis-2026-06-13-gundam-uc-combat-feel.md` (the F1–F10
record). Source: a deep-research pass (20 sources fetched, 75 claims extracted, 25 adversarially
verified by 3-vote, 20 confirmed / 5 killed). The harness's auto-synthesis step failed on an API
overload, so this synthesis was assembled by hand from the verified-claim set — the findings below
are the ones that survived verification, not the raw search dump.

Titles examined: Gundam Unicorn (UC / RE:0096), Gundam 0083 Stardust Memory, Gundam 08th MS Team,
Neon Genesis Evangelion (TV + End of Eva + Rebuild).

**Purpose:** broaden the evidence base for the build-driven combat-feel system (the
[[combat-feel-restart]] direction) — each finding is tagged to a tunable parameter or primitive in
one of five buckets: **movement dials, camera/shot grammar, exchange modes, cockpit rules,
environmental-yield rules**. New findings continue the F-numbering from the 2026-06-13 doc (F11+).

**IP guardrail (CLAUDE.md):** everything here is craft — cadence, staging, framing, feedback
mapping. None of it is Gundam/Eva IP. The named units, pilots, and events are cited only as
evidence of a technique, never to copy. Implement with original mecha identity.

---

## What's new vs F1–F10 (the headline)

The 2026-06-13 doc concluded the camera grammar was on-target and the gap was the movement model.
This pass holds that up and adds three things F1–F10 did not have:

1. **Cadence as the master weight dial (F11–F12).** The strongest, most repeated finding across the
   non-Gundam sources: weight is sold by *drawing-rate / motion cadence*, not just accel curves. A
   heavy thing moves at a lower effective sampling rate ("on threes") with slower, more deliberate
   pose changes; a light thing samples high and reads twitchy-fast. This is a cleaner, more powerful
   "weight" lever than F1's accel/decel alone, and it is explicitly a per-actor dial — exactly what a
   build-driven system needs.
2. **A real cockpit lens (F20–F21)** — entirely absent from F1–F10. But note the contradiction below:
   the *intercut-rhythm* rule I went looking for did **not** survive verification. What survived is the
   *feedback mapping* and the *framing language*, not a cadence for cutting to the cockpit.
3. **Yield keyed to weapon CLASS, and staggered destruction (F16–F17)** — sharpens F9 from "big hit =
   bigger effect" into two concrete rules that bear directly on the kill-cam work already done.

---

## Movement dials

- **F11 — Mass-via-cadence (drawing-rate modulation).** Heavy, massive objects are animated at a
  deliberately *low* cadence; the slowness itself reads as titanic weight, and cadence can be varied
  per-actor and per-action within one scene to show scale differences. → **Movement dial:** a build's
  mass sets an effective motion cadence (pose-update rate / interpolation snappiness) — heavy builds
  step at a lower cadence with held poses, light builds at a high cadence. *Extends F1.* (3 verified
  claims; wavemotioncannon framerate-modulation primer.)
- **F12 — Subdued vs energetic register.** Restrained, low-amplitude "understated" mech movement is a
  distinct and deliberate register (cited as the rare craft of UC / Zeta: A New Translation), separate
  from raw speed. → **Movement dial:** a "register" axis (subdued↔energetic) independent of the speed
  dial; weighty realism = low amplitude, economical motion. *Extends F1; corroborates F1's "economical,
  never twitchy."* (Sejoon Kim interview, primary.)
- **F13 — Joint-swing follow-through & lunge weight.** Weight is conveyed through the depicted physics
  of joints swinging and bodies colliding/lunging — follow-through and mass in the limb arc, not camera
  alone. → **Movement/exchange dial:** follow-through magnitude and lunge commitment on melee and hard
  vector-changes; pairs with F2 (AMBAC limb-driven reorientation). (Mitsuo Iso analysis.)

## Camera / shot grammar

- **F4 (corroborated, primary source).** "Camera as active second actor" is now backed by the Sejoon
  Kim interview directly: *"the back and forth between the cameraman and the subject,"* constantly
  shifting camera and subject across planes. Keep doing this; it's the verified core of the grammar.
- **F14 — Hold-on-impact.** Reducing the drawing rate at the moment of impact — holding the impact
  pose/frame longer than its neighbours — makes the hit register as more forceful, independent of the
  surrounding cut's pacing. → **Camera/time dial:** a per-hit "impact dwell" that extends the hold on
  the contact pose. This is a refinement of the existing `garnish` hitstop — make dwell scale with hit
  weight (and with mass, via F11). (wavemotioncannon.)
- **F15 — Motion-via-frame-and-streak.** Speed and charge are sold by moving the frame over a
  relatively static subject with a streaked/blurred background, rather than by animating the figure
  itself. → **Shot-grammar primitive:** for a fast pass/charge beat, move the camera and streak the
  background instead of relying on the actor's own animation. Cheap, and on-grammar with F4. (Routt,
  Evangelion style analysis.)

## Exchange modes

- **F19 — All-range evasion beat.** Evasive maneuvering against multi-source incoming fire (dodging
  beams + missiles at once) is called out as a distinct, famously hard choreography problem in its own
  right. → **Exchange mode:** a dedicated "evasion / dodge-pursuit" beat where one mech weaves a storm
  of multi-source fire — sharpens F7's third mode from a vague "dodge-pursuit run" into a first-class
  beat with its own staging. (Sejoon Kim, primary.)
- *(F7's three-mode model — aimed beam / all-range swarm / dodge-pursuit — stands. See "Do NOT use":
  the evidence did **not** support adding a separate "missile/laser chase" mode or an attritional
  high-time-to-kill ballistic mode.)*

## Cockpit rules (new lens — read the contradiction)

- **F20 — Exterior-damage → interior-feedback mapping, scaled by bond.** Damage to the machine maps
  to a pilot bodily reaction, and the *intensity* of that reaction scales with the pilot's sync ratio
  (higher sync → stronger felt impact). → **Cockpit rule / feedback-intensity dial:** a tunable mapping
  from an exterior hit's weight to an interior reaction's intensity, gated by a bond/sync value. This is
  the cockpit hook the project's deferred pilot-fit / sync layer should own — reserve the parameter now,
  build it in v0.2. (evageeks Synchronization; corroborated.)
- **F21 — Wraparound cockpit framing.** The reference interior is a near-360° surround that maps the
  exterior directly onto the pilot's view, with HUD elements appearing on demand and the display's
  blind spots reading as an outline of the machine's own body. → **Cockpit framing language** for any
  future interior shot: surround-mapped exterior, HUD-on-demand (not persistent chrome), body-aware
  negative space. (evageeks Entry plug.)
- **Contradiction / honest gap:** the hypothesized **three-beat exterior→cockpit→exterior intercut
  rhythm** (wide threat → cockpit reaction → consequence) was **refuted 0-3** — no solid support that
  this specific causal cutting structure is a real, teachable rule. So the cockpit lens gives us a
  *feedback mapping* and a *framing language*, but **not** a verified cut-cadence. Treat cockpit
  intercut timing as author-by-feel / an open question, not a codified rule.

## Environmental-yield rules

- **F16 — Staggered multi-explosion kill staging.** A big kill is staged as a *series* of distinct
  explosions seen from varied distances/perspectives, not one sweeping blast — scale comes from
  compositional variety. → **Environmental-yield rule:** on a lethal / capital-tier hit, emit several
  staggered explosion events at varied camera distances rather than a single effect. *Extends F9, and
  directly relevant to the kill-cam hold we just tuned — the slow-mo orbit is the right place to play a
  multi-stage blast.* (Unicorn / Takashi Hashimoto sakuga analysis.)
- **F17 — Yield keyed to weapon CLASS, with a fear beat.** A top-tier weapon discharge (the 0083 nuke)
  is dramatized as catastrophic spectacle with an outsized staging-and-reaction beat — the *class* of
  the weapon, not just its damage number, triggers the treatment. → **Environmental-yield rule:** map
  weapon class → staging intensity (camera, collateral, a held reaction beat), so a capital/payload-tier
  shot reads as fearful spectacle and a sidearm does not. *Extends F9; pairs with the hero-weapon yield
  framing already noted.* (0083.)
- **F18 — Terrain acts on the mech.** The environment degrades or disables a build (sand fouling a
  mobile suit; mud/jungle as grounding conditions), rather than being inert backdrop. → **Environmental
  rule:** terrain can modify a build's effective dials (mobility penalty, footing), and a "groundedness"
  setting biases the whole fight toward footwork over flight. Title-specific to the grounded register,
  not universal. (08th MS Team.)

---

## Shared weighty craft vs title-specific

- **Shared across all four:** weight = *cadence + follow-through + economy of motion* (F11–F13), and
  scale = *compositional consequence* (F16) rather than a single bigger number. These are the universal,
  highest-confidence levers.
- **Gundam-lineage specific:** real-robot grounding — terrain that acts on the machine, mud-and-boots
  footwork (08th, F18); yield keyed to weapon class with a fear beat (0083, F17); the all-range evasion
  beat (UC-era, F19).
- **Evangelion specific:** the cockpit body-feedback link (F20) and wraparound interior framing (F21).
  Note the much-cited "stillness" style did **not** survive verification as a combat primitive (below) —
  Eva's transferable contribution here is the cockpit lens and the frame-and-streak motion trick (F15),
  not held-frame stillness.

## Parameter-bucket map (for the build→feel design)

| Bucket | Findings | Build-spec input that should drive it |
|---|---|---|
| Movement dials | F1, F2, F3, **F11, F12, F13** | mass → cadence + register; thrust → burst-coast; frame → AMBAC/follow-through |
| Camera / shot grammar | F4, F5, F6, **F14, F15** | weapon class / hit weight → impact dwell; speed beat → frame-and-streak |
| Exchange modes | F7, F8, **F19** | weapon set → beam / swarm / evasion / melee mix |
| Cockpit rules | **F20, F21** | bond/sync value → feedback intensity (reserve for v0.2 pilot-fit) |
| Environmental-yield | F9, F10, **F16, F17, F18** | weapon class → staggered-blast count + fear beat; terrain → mobility mod |

---

## Do NOT use (refuted or weak in this pass)

- **Three-beat exterior→cockpit→exterior causal intercut (refuted 0-3).** No solid support; do not
  codify a cockpit cut-cadence rule. Cockpit intercut timing stays author-by-feel.
- **"Stillness / held frame" as a combat primitive (1-2), and silence + held frame to stretch time
  (0-3).** Not supported for our weighty-*combat* use; Eva's stillness is a different (dialogue/mood)
  register, not a fight lever.
- **08th attritional high-time-to-kill, "full magazine to kill one unit," no-beam ballistic exchange
  mode (0-3).** Not a verified exchange mode; don't build TTK around it.
- **A distinct "missile/laser chase" exchange mode (0-3).** F7's three modes stand; do not add a fourth
  "chase" mode on this evidence.

## Open design questions this pass surfaced

1. The numeric cadence ladder for F11 — what effective pose-update rates / interpolation stiffness map
   to which mass bands so the weight difference reads without looking like a frame-drop bug.
2. How impact-dwell (F14) composes with the existing bullet-time kill-cam and hitstop without
   double-counting the slow-down.
3. The staggered-blast (F16) authoring: count, spacing, and camera-distance spread as a function of
   weapon class (F17), and whether it's emitted by the sim or the director.
4. The cockpit feedback mapping (F20) shape — deferred to the v0.2 pilot-fit layer, but the
   exterior-hit → interior-intensity curve and its bond-gating should be reserved in the data model now.
