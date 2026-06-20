# Research synthesis — film/animation choreography theory for a deterministic mech-fight grammar

> Status: RESEARCH, 2026-06-20. Companion to the Gundam-UC combat-feel findings
> (`research-synthesis-2026-06-13-gundam-uc-combat-feel.md` F1–F10,
> `…-2026-06-15-weighty-mecha-…` F11–F21, `…-2026-06-16-director-grammar-…` F22–F40).
>
> Those docs answered *what makes combat read Gundam-UC*. This one answers a narrower,
> structural question the F-docs left open (06-13 open-Qs #1/#3): **how do we decompose
> fight choreography into a deterministic, extensible GRAMMAR — and what in a movement log
> proves each principle is present?** Findings are tagged `C#` and mapped to (a) the grammar
> layer they ground and (b) the *traceable signal* in our per-tick movement log
> (`{tick, actor, x, y, z, dist_to_enemy, speed, bearing_deg, boost}`) + the event log
> (`shot {tier, travel, outcome, lethal}`, `destroyed`, `result`).
>
> Consumer: `docs/superpowers/specs/2026-06-20-choreography-grammar-design.md`.

## How to read this

Every finding is `C# — name. layer · claim · traceable signal · confidence`. **Layer** is one of
the four grammar layers (Prosody / Primitive / Exchange / Dramaturgy) or **Director** (camera/cut
grammar — already built; listed only where research validates or bounds it, never to rebuild it).

**One caveat applies to every numeric threshold below:** the literature gives the *principle and the
curve shape*; specific tick counts and ratios (e.g. "pause ≥ 3 ticks", "coast-ratio > 0.5") are
**design constants we tune against the reference fight**, not values from the sources. They are
written as starting points, flagged where they are ours.

---

## The unifying law — Pause·Burst·Pause (the spine)

Four independent bodies converge on one statement, and it is also the exact diagnosis of why the
first choreographer recreation read "busy/loose" against the hand-authored reference:

- **C0 — Weight and snap come from the CONTRAST between stillness and sudden displacement, not from
  velocity.** `Spine` · The speed signal across a fight must be **bimodal** — a low/near-zero
  *coast/pause* cluster and a high *burst* cluster with a clear valley between — never a flat
  mid-speed hum. *Traceable:* histogram of `speed` over all ticks is bimodal (bimodality coefficient
  past a cutoff); every burst is bracketed by ≥2–3 contiguous near-zero ticks. The reference fight
  is bimodal (~2–3 with held pauses); the failed recreation was unimodal (flat 4–18). · **High.**
  Sources: Bordwell *Planet Hong Kong* "pause-burst-pause" + *liang hsiang*; Laban *Time* effort
  (sudden); Disney slow-in/out + anticipation; Kanada "hold then snap, no in-between."

This is the grammar's first invariant and its first automatic regression check.

---

## Layer 1 — Prosody (how any motion executes; the weight)

**Laban Movement Analysis — the Effort system.** The vocabulary of movement *quality*.
- **C1 — Weight (light↔strong).** `Prosody` · committed force/intensity of an action (not mass). ·
  *Traceable:* **deceleration magnitude** at contact — a strong hit shows a steep velocity cliff over
  1–2 ticks; light tapers. · High.
- **C2 — Time (sustained↔sudden).** `Prosody` · decisiveness/timing; sudden = no ramp. · *Traceable:*
  **ramp length** (ticks from baseline to speed-peak); a good fight's ramp-length histogram is
  bimodal. · High.
- **C3 — Space (direct↔indirect).** `Prosody` · path intentionality; direct = straight to target,
  indirect = arc/sweep. · *Traceable:* `bearing_delta` per tick during a move — near-0 (direct) vs
  oscillating ≥15°/tick (indirect). · High.
- **C4 — Flow (free↔bound).** `Prosody` · committed/uninterruptible vs controlled/stoppable. ·
  *Traceable:* **overshoot** — free flow keeps closing 2–4 ticks past the speed-peak; bound
  decelerates before/at target. · High. *Caveat: literature treats Flow as a continuum; the per-move
  binary below is a tendency, not a hard pole.*
- **C5 — The eight Basic Effort Actions** (Punch, Slash, Glide, Float, Dab, Wring, Press, Flick) are
  the named combinations of C1–C4. `Prosody→Primitive bridge` · e.g. **Punch** = direct+sudden+
  strong+bound (1–2 tick spike to target then hard stop); **Glide** = direct+sustained+light+free
  (long ramp, plateau, no cliff); **Slash** = indirect+sudden+strong+free (short ramp, arcing
  bearing, overshoot). · *Traceable:* each action is a ⟨ramp, bearing_delta, cliff, overshoot⟩
  fingerprint — i.e. a classifier from the trace. · High.

**Disney principles (weight/timing subset).**
- **C6 — Slow-In/Slow-Out (ease).** `Prosody` · velocity is an S-curve, never a step. · *Traceable:*
  `d(speed)/dt` finite (gradual) at move start/end; ramp-up and ramp-down each ≥2 ticks; a 0→max
  jump in one tick is a violation. · High.
- **C7 — Anticipation.** `Prosody` · a small reverse motion precedes a burst. · *Traceable:* a brief
  `dist_to_enemy` *increase* (or bearing rotation away) in the 1–2 ticks before a max-speed approach.
  · High.
- **C8 — Follow-through / overshoot-and-settle.** `Prosody` · parts overshoot the stop and damp back.
  · *Traceable:* after a move ends, a **damped speed tail** (1–2 low micro-bursts opposite the
  approach) before rest; absence = reads weightless. · High.
- **C9 — Timing-as-weight.** `Prosody` · frame/tick count encodes mass; heavier = longer. ·
  *Traceable:* mean ramp length correlates with the mech's mass/heft; light < ~3 ticks, heavy ≥ ~6
  (*our constants*). Interacts with boost — heavy classes must suppress boost-start snappiness. · Med.

**Anime timing craft.**
- **C10 — On 2s/3s baseline + framerate modulation.** `Prosody` · anime holds a rate, then switches
  (slow on 3s/4s → 1s burst → back) so *felt* contrast >> real velocity delta. · *Traceable:*
  non-monotonic speed: plateau (hold) → single-tick displacement spike → plateau; distinct from a
  smooth ramp. · High.
- **C11 — Kanada hold-then-snap.** `Prosody` · "hold ~6 frames with no in-betweens, then snap to the
  next extreme with max distance between poses." · *Traceable:* `speed≈0` for N ticks (N≥~15 at
  60tps), then one tick at peak displacement; `peak/mean speed >> 3`; `bearing_deg` may snap >45° in
  one tick. · High.
- **C12 — UC thruster burst-and-coast.** `Prosody` · burn to start → coast at `boost=0` → reverse
  burn to stop; the "realistic mass" of UC mecha. · *Traceable:* boost spike → long `boost=0`
  plateau → boost spike; `coast_ticks/total_ticks > 0.5` for a heavy move. · Med (reception-attested,
  not a named production rule).
- **C13 — Settle/overshoot after a snap.** `Prosody` · without a settle a Kanada snap reads as a
  teleport; small overshoot then decaying oscillation lands the pose. · *Traceable:* position
  overshoots target by δ then oscillates back; δ scales with incoming speed. · High (principle).

---

## Layer 2 — Primitives (the verbs; atomic moves)

Primitives are the Effort Actions (C5) instantiated as named, parameterized mech moves. The set is
**closed-ish** — re-weighted/re-parameterized by weapons & archetypes, not extended per weapon.
- **C14 — Telegraph / Prep.** `Primitive` · every move has a readable wind-up before it commits. ·
  *Traceable:* `speed` rises (and `bearing_deg` locks to target) in the ticks *before* the shot fire
  tick; a flat-to-fire move is unreadable (a flag). · High.
- **C15 — AMBAC reorientation.** `Primitive` · limb-swing reorients the body with **no thrust** (UC
  canon justification for humanoid mecha). · *Traceable:* `bearing_deg` rotates while `boost=0` and
  `speed`≈const. Distinct from a thruster turn (boost spike). · Med (concept canonical; frame
  technique inferred).
- **C16 — Thruster burst-dash.** `Primitive` · rapid reposition across distance via a boost impulse.
  · *Traceable:* `boost=true` + speed spike + `dist` change. Pairs with C12 coast. · High.
- **C17 — The weave (evasive run).** `Primitive` (the body of the Itano exchange) · high-speed lateral
  dodging through incoming fire. · *Traceable:* `bearing_deg` oscillating rapidly (±30–90°/tick) at
  near-max `speed`, `dist` varying erratically. · High.
- **C18 — Impact frame (shock koma).** `Primitive` · a 1–2 frame stylized/monochrome insert *at* the
  collision instant; the minimum grammar atom of a meaningful blow. · *Traceable:* a 1–2 tick dwell
  (`speed≈0`/flag) co-occurring with a `hit`; `color_mode=mono` renderer flag. · High.
- **C19 — Apex-hold (Obari pose).** `Primitive` · a 1–2 tick held still at the *apex* of a strike
  (after commit, before the hit registers) — the climax pose, not the aftermath. · *Traceable:*
  `speed=0` for 1–2 ticks *after* move-commit and *before* the hit event. · Med.
- **C20 — Smear.** `Prosody/Primitive` · a 1-frame stretched/ghosted drawing bridging a fast gap so it
  doesn't read as a teleport. · *Traceable:* a single tick geometrically between A and B at max speed,
  flagged `pose=SMEAR`, duration 1 tick. · High.

---

## Layer 3 — Exchanges (one beat of back-and-forth)

**The atomic exchange unit.**
- **C21 — Cue·Reaction·Action (CRA / "the prep-reaction-action").** `Exchange` · the SAFD's safe,
  legible exchange: aggressor telegraphs a *cue* → victim *reacts* (signals readiness) → both resolve
  the *action* together. · *Traceable:* a non-zero tick window around each `shot`: aggressor
  speed/bearing commit (cue) → a victim dwell/reverse (reaction) → fire+outcome (action). A
  zero-window shot is a missed CRA. · High.
- **C22 — The beat.** `Primitive/Exchange` · one CRA triplet = one beat (one `shot`+`outcome`+victim
  state-change); a miss is still a beat (a resolved crisis). · High.
- **C23 — Victim sells the hit.** `Exchange` · the *receiver* drives the readable result — turns
  away, staggers, stumbles — after the outcome. · *Traceable:* the struck mech's `speed`/`bearing_deg`
  change *after* the `outcome` tick (a boost-stumble); no change = an "unsold" hit. · High.
- **C24 — The phrase.** `Exchange` · a fight is ≥3 phrases, each a continuous run of beats bounded by
  a reset/pause. · *Traceable:* a phrase boundary = both mechs' `speed`<rest for ≥N ticks, or `dist`
  opens past long-range with no shot. Phrase count is a QA check. · High.
- **C25 — Give-and-take / initiative alternation.** `Exchange` · momentum passes — one presses, one
  yields — and flips. · *Traceable:* who is closing `dist` vs opening it; an initiative segment is one
  sign, a flip is the handoff. A fight where one side never opens is a "no give-and-take" violation.
  · High.
- **C26 — Rhythm/tempo as the stakes signal.** `Exchange` · beat intervals tighten as stakes rise; a
  long interval with low speed + static dist is a "standoff" tension beat. · *Traceable:* beat-interval
  (ticks between shots) histogram; negative gradient toward a phrase climax. · High.

**Spatial staging — range bands (proxemics → combat distance).**
- **C27 — Hall's four proxemic zones → range bands.** `Staging` · intimate/personal/social/public map
  to **grapple / knife / mid / long**. · *Traceable:* `dist_to_enemy` should **quantize** into named
  bands (scaled by a `PROXEMIC_SCALE` constant for mech size); a weapon's `tier`/`travel` must match
  the active band (a long-tier shot at knife range, or melee at long range, is a staging violation).
  · High (zones); scaling is *our* constant.
- **C28 — Fencing "measure" (in/out).** `Staging` · an attack is only possible *in measure*; otherwise
  a closing step (`larga`) or pass (`larghissima`) is required first. · *Traceable:* every connecting
  `shot` has `dist ≤ weapon_reach` at fire, or a preceding boost-close. · High.
- **C29 — Clarity-of-space (Chan/Bordwell).** `Staging→Director` · keep the geography legible; place
  mechs in open, readable relation; the move must be fully readable. · *Traceable (choreographer
  part):* both mechs' positions stay within a sane spread so the director *can* frame both; the heavy
  framing/cut rules are Director-layer (already built). · High.

**The exchange-mode vocabulary — CLOSED by prior research (F7/F8).** Four modes only; a fifth is
refused (F-15 Do-Not-Use). A weapon tags into one; it never adds one.
- **C30 — Beam-trade at range.** `Exchange mode` · aimed discrete shots across a gap. · *Traceable:*
  single `shot`, `travel>0`, mechs in mid/long band, moderate bearing change. · High.
- **C31 — All-range swarm = the Itano Circus.** `Exchange mode` · a dense guided-missile salvo with
  individually arcing trails; the target weaves; the camera rides it. Itano's own taxonomy of
  trajectories (straight / predictive-arc / zigzag); "the chase is more interesting than the attack."
  · *Traceable:* many short/medium-travel shots in/near one tick + target `bearing_deg` oscillating
  (C17 weave) + non-linear projectile paths. The single most log-provable exchange. · High.
- **C32 — Dodge-pursuit run.** `Exchange mode` · one suit weaving a sustained storm (the weave without
  the salvo necessarily resolving). · *Traceable:* extended C17 signature with low hit rate. · High.
- **C33 — Melee clash.** `Exchange mode` · close dash → contact → lock/knockback; densest, heaviest
  framing. · *Traceable:* `travel≈0` shots at grapple/knife band, `dist≈0`, contact outcomes. · High.

---

## Layer 4 — Dramaturgy (the whole-fight arc)

- **C34 — Three-act mini-structure.** `Dramaturgy` · setup (probing, equal) → escalation (one gains
  dominance, threat peaks) → resolution (kill/break). · *Traceable:* segment ticks into thirds; expect
  rising `hit_ratio`, rising `mean_tier`, the reversal in act 2, the lethal in act 3. · High (structure);
  segmentation is *our* rule.
- **C35 — Peripeteia (the reversal).** `Dramaturgy` · the initiative flips — the losing side seizes it,
  or the dominant one takes a turning hit. · *Traceable:* the first `hit` whose attacker ≠ the current
  initiative-holder after a ≥2-hit streak; this is the **peripeteia tick** the choreographer should
  expose so the director can mode-switch the cut (axis-cross / collision edit). · High.
- **C36 — Escalation (monotone-ish rising stakes).** `Dramaturgy` · threat rises across the fight. ·
  *Traceable:* `mean_tier_early ≤ mean_tier_mid ≤ mean_tier_climax`; max consecutive hits by the
  dominant side grows. Local ebbs allowed; the trend must hold. · High (principle); monotonicity is a
  design assertion.
- **C37 — Held climax (time-dilation on the kill).** `Dramaturgy` · the lethal beat gets
  disproportionate dwell (slow-mo/freeze) — Kurosawa→anime canon. · *Traceable:* a `dwell_multiplier`
  ≥ ~2.5× on the `lethal` beat (and the 1–2 beats before it); a `playback_rate<1` flag. The
  choreographer **exposes the held-climax flag**; the director owns the actual dilation. · High
  (principle); multiplier is *our* constant.
- **C38 — Lethal lands late.** `Dramaturgy` · the kill belongs in the final quarter. · *Traceable:*
  `lethal.tick / duration ≥ 0.75`. · High (structure); the 0.75 is *our* constant.

---

## Director layer — validates/bounds the existing director (NOT choreographer scope)

These came back strongly but are **camera/cut grammar the hybrid director already implements** (F22–F40).
Listed so the grammar spec can draw the boundary and the choreographer can *expose the beats* the
director needs — never to rebuild them.
- **C39 — Impact assembly** — Kuleshov (meaning from the next shot), Pudovkin constructive editing,
  cut-on-action (cut during `travel`, before `hit`), impact-then-react (a reaction shot within 1–2
  events of a heavy/lethal hit), the numbness guard (no >3 hit-streak without a reaction beat). ·
  *Director.* · High.
- **C40 — Cut cadence & continuity** — intensified continuity (ASL falls toward the climax; bipolar
  lens lengths), Eisenstein metric/rhythmic/tonal montage (cut density rises, shot length ∝ 1/speed,
  alternate tension/release framing), 180°/axis held within a burst and broken only at the
  reversal/kill, "action+reaction in the same frame," film-geography establishing shot per phrase. ·
  *Director.* · High.

**The seam:** the choreographer must *emit* the structural hooks these consume — CRA windows, phrase
boundaries, the peripeteia tick, the held-climax flag, the active exchange-mode, and the range band —
so the director can cut on them. That hook list is the choreographer↔director interface.

---

## Traceability map (what proves the grammar, and what we must add)

| Already in the trace | Derivable (cheap, no new data) | Must add as a label/event |
|---|---|---|
| position, dist, speed, bearing, airtime, boost | range-band (from dist), initiative-holder (who closes), phrase boundaries (pause gaps), arc-phase (thirds), bimodality / ramp / cliff / coast-ratio / overshoot | exchange-mode tag, CRA/telegraph window, impact-frame flag, peripeteia tick, held-climax flag |

Layers 1–2 are measurable **today**; layers 3–4 are mostly derivable, with a short list of labels to
add. Every principle above has a signal — so the grammar is testable and any generated fight is
diffable against the reference (the C0 bimodality check would have caught the recreation failure).

---

## Extensibility (the project's "new weapon = data, not code", extended to choreography)

- **New weapon** = a `motif` row + `tier`/`travel`/mode-tag. The choreographer reads structural fields
  (C1/C2/C27/C28), never weapon identity; the weapon auto-inherits prosody, primitives, and one of the
  **closed** four modes (C30–C33). No code.
- **New archetype** = a `FeelProfile {heft, tempo, mode_mix}` bias (or an authored preset). `mode_mix`
  sets the F7/F8 proportion (06-13 open-Q #3) as *data*; `tempo` sets cadence dials; `heft` sets
  primitive intensity + range-band preference. No code.
- **Stable frame:** four layers + closed mode vocabulary + the primitive registry. **Open seams:**
  motif registry, FeelProfile/archetype presets, prosody dials. A new primitive is a rare, deliberate
  registry row (like adding a contract `kind`).

---

## Caveats / confidence ledger

- Numeric thresholds (ramps, pauses, ratios, multipliers, 0.75 lethal-position, PROXEMIC_SCALE) are
  **design constants**, tuned against the reference — not literature values.
- C4 Flow per-move binary is a tendency (literature: a continuum).
- C12 burst-and-coast and C15 AMBAC animation technique are **reception/inferred**, not named
  production rules (the in-universe concept and the "realistic mass" reception are well-sourced).
- "Victim controls" (C23) is stage-safety doctrine; here it maps to the *receiver's* response, not a
  safety rule.
- A few sources are secondary (Fstoppers, blog analyses); the load-bearing claims (Laban, Disney,
  Bordwell, Hall, Eisenstein/Pudovkin, Itano, Kanada) trace to primary or strong scholarly sources.

## Sources

Laban / movement quality: UXmatters LMA; Theatrefolk "Eight Efforts"; Tandfonline/Essex "Laban's Flow
Effort". Disney: Wikipedia "Twelve basic principles of animation"; Adobe; Academy of Animated Art;
Johnston & Thomas, *The Illusion of Life* (1981). Bordwell: *Planet Hong Kong* (2000); mediacommons
"John Woo Is God"; Offscreen "Action Aesthetics". Stage/screen combat: SAFD Glossary; Weapons of
Choice *Textbook of Stage Combat*; PlayFighting.ca; Tavern Knight (measure). Beat/phrase: MasterClass;
Well-Storied. Proxemics: Hall, *The Hidden Dimension* (1966), via EBSCO/Oxford Reference. Clarity:
Bordwell "Bond vs Chan" (2010); *Every Frame a Painting* "Jackie Chan". Editing/dramaturgy: Wikipedia
Kuleshov, Cutting-on-action, Reaction shot, Dramatic structure; Media Studies "Eisenstein Five
Methods"; StudioBinder (Soviet montage, peripeteia, three-act, slow-motion); Beverly Boy (Pudovkin vs
Eisenstein); Bordwell intensified continuity (Oxford Reference). Anime craft: Wave Motion Cannon
(framerate modulation); Animétudes (Kanada style; subjectivity/modulation); ResearchGate "Dynamism of
Anime Images: Kanada-style"; Canmom (smears; Kanada); Know Your Meme / ArhFoundation (impact frames);
Wikipedia Ichirō Itano; Macross Wiki / sakugabooru (Itano Circus); Vanishing Trooper (Obari);
Gundam Wiki / MechaTalk (AMBAC); Gundam Unicorn reviews (burst-and-coast). Full URLs in the
2026-06-20 research agent returns archived with this synthesis.
