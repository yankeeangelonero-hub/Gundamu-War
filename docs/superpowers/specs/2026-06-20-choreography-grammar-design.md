# Combat Choreography Grammar — design

> Status: DESIGN (rev 4, post third Codex review), 2026-06-20. Branch: `combat-feel-restart`.
>
> Grounds the choreographer (`build → sim → log → CHOREOGRAPHER → director`) in named film/animation
> theory and makes it extensible the way the rest of the project is ("a new weapon = data + art, never
> code"). Supersedes the ambient-only `2026-06-17-combat-choreographer-design.md`.
>
> Theory basis (cited): `Research/Research Documents/research-synthesis-2026-06-20-fight-choreography-theory.md`
> (`C0`–`C40`). Combat-feel north star: F1–F40. Truth contract:
> `2026-06-17-fight-event-log-contract-design.md`. Per-build lean: `2026-06-18-feel-profile-design.md`.
>
> **rev 3 changes** (2nd Codex review + owner intent): CG-SUSPENSE reframed into a **no-pre-spoil**
> gate + an **exciting-shape** coverage goal; suspense *availability* flagged as **sim/balance**; an
> **edge-fight fixture suite** made first-class; hooks moved to a root `presentation` block; scheduler,
> composition, contrast metrics made precise; paths corrected.
>
> **rev 5/6 changes** (4th–5th Codex review): no-pre-spoil enforced **by construction** via a new
> **outcome-blind structural-staging invariant (CG-BLIND)** — beat prominence/mode/range never depend
> on who wins — closing the foreground/background pre-spoil channel; `staged_dom` gains the stagger/sell
> channel and exact closing-rate/sell formulas; the gate bound is validator-derived (`LATE_FRAC`); the
> shape classifier is reordered and its terms defined; the per-beat hook splits `reaction_background`
> from `is_background`; mutual same-tick lethal is clarified as sim-owned.
>
> **rev 4 changes** (3rd Codex review): the no-pre-spoil gate is made **test-independent** — the
> validator computes staged dominance from the **raw staged trace**, never the choreographer's own
> `apparent_initiative` hook (the circularity Codex blocked); `truth_dom`/`staged_dom`/`reveal()` are
> fully specified incl. asymmetric HP, cap/stalemate, draw, melee, `post_decision`; the **beat
> scheduler is made total** (mode selected per-shot before coalescing, `cue_tick` defined, lethal/heavy
> **preempt** a normal commit — a lethal can never be demoted); the contract amendment lists its four
> touchpoints (root schema, loader unknown-key policy, outcome projection, canonical-hash exclusion);
> a concrete **shape classifier + template registry** and an exact **`decided_tick`** are defined;
> mode-composition gains input validation + pass-1 gating to implemented modes; `MODE_MAP` gets a path.

## Problem and goal

The shipped choreographer stages a fixed ambient pattern; recreating the hand-authored reference
through it read busy and loose (flat mid-speed churn, distance to 191 vs the reference's 30–48 /
speed ~2–3). It encodes no weight, no exchange structure, no dramatic shaping — one sentence, not a
grammar.

The goal: **most fights look cinematic and cool, and the staging never *spoils* the outcome early.**
**Stomps are part of the fun** — a one-sided truth is staged as a *decisive, spectacular* kill, not a
boring foregone one. The choreographer cannot change who wins (truth), but it controls whether the
*motion betrays* who wins, and how exciting each outcome-shape looks.

## Two universal laws

The choreographer controls **how a fight is staged**, never **who wins**. Two cross-cutting laws,
both owned and testable on the staged output:

- **CG-CONTRAST (prosody).** Weight and snap come from the *contrast* between stillness and sudden
  displacement, not velocity (C0). Its expression is **per-mode**, declared by a small **closed
  contrast-metric registry** (one per exchange mode — four total, below): a global bimodal-speed rule
  would wrongly reject a sustained weave (Codex). Bimodal-speed is the beam-trade instance, not a
  universal.
- **CG-SUSPENSE (dramaturgy) — split into two parts** (the literal "viewer can't predict the result"
  is unachievable for fast stomps without faking outcomes; Codex P1):
  - **CG-NO-PRESPOIL (hard gate).** The staging must not reveal the outcome *earlier than the truth
    itself does*. It may keep a losing mech reading as an agent-in-contest **only as long as the truth
    keeps the result open** — it never *pre-announces*. Defined precisely under Testing as a
    staged-dominance-vs-truth-dominance comparison (no ML, no trained predictor).
  - **Two scales of suspense.** CG-NO-PRESPOIL governs *macro* suspense (per-fight: who wins). There is
    also *micro* suspense (per-exchange: **will this hit land or be dodged?**), and it is **already
    enabled by CG-BLIND's causal rule** — because a hit and a miss are staged *identically until the
    impact tick*, the viewer genuinely cannot tell per-shot whether a weave will beat the shot until it
    resolves. The choreographer stages real **near-misses** for `outcome:"miss"` and real connects for
    `outcome:"hit"`, decided only at impact. This per-exchange tension is a first-class goal and
    complements (never fakes) the truth — a `miss` is a real resolved shot that missed.
  - **CG-EXCITING-SHAPE (coverage goal).** Every truth *shape* (close / reversal / fast-kill / stomp /
    stalemate) maps to a named exciting staging template — a stomp → **hero-stomp** (tense apparent
    contest → sudden decisive spectacle). Suspense is delivered *where the truth leaves room*;
    excitement is delivered *always*.

## Flag — suspense availability is a sim/balance concern, not the choreographer's

**This is flagged for the sim/balance design (out of scope here).** The choreographer guarantees
no-pre-spoil + an exciting staging for *any* truth. But whether a fight *can* be suspenseful — whether
the outcome stays open long enough to anticipate — is a property of **combat balance and the sim**:
how early fights are decided, how often a build stomps. If balance produces constant 3-second kills,
no staging can create suspense. The **edge-fight fixtures** below emit a **decided-tick distribution**
that is the metric the balance layer should watch; closing the loop (tuning builds/sim so fights stay
open) is a separate, flagged sim/balance + roadmap concern. The choreographer's contract is only:
*don't pre-spoil, and make every shape exciting.*

## What the choreographer does NOT assert

A valid sim legitimately produces stomps, fast kills, non-escalating tiers (Codex P1). The
choreographer cannot make the *truth* a 3-act arc and must not try (reordering outcomes would violate
INV-CLOCKS/INV-ORDER). Arc properties (escalation, peripeteia, lethal-late) are therefore **staging
tools** + **advisory diagnostics on the reference fixture**, never gates on arbitrary truth. The hard
universal gates are CG-CONTRAST (per-mode), CG-NO-PRESPOIL, determinism, and range/measure — all
properties of *staging*.

## Outcome-blind structural staging — how CG-NO-PRESPOIL is enforced (CG-BLIND)

CG-NO-PRESPOIL is enforced **two ways**: the `staged_dom` **gate** (movement + sell channels, below)
*and* an **invariant on construction** that closes the channels a gate can't cheaply measure.

**CG-BLIND has two parts — an outcome-blindness rule and a stronger temporal (causal) rule.**

**(1) Outcome-blind.** No structural staging branches on *who wins* / who is ahead. The only place the
final outcome is read is the Layer-4 suspense plan (shape→template, `climax_window`, hero-kill scale),
governed by the gate.

**(2) Causal / prefix-blind (Codex P1, rev 7).** The staging *visible at display tick t* is a pure
function of the **truth prefix knowable by t** — staging is causal in sim time. Split structural
inputs by display time:
- **Pre-impact** staging — cue, telegraph, approach, mode, range, **and the cue/fire-phase prominence
  (full-CRA vs background) decision** — may read only **fire-time-knowable** attributes: weapon,
  FeelProfile, `motif`, `tier`, `travel`, derived range, scheduling conflicts. It may **not** read
  `outcome`/`damage`/`lethal`/`hp_after` (those are resolved only *at* impact; `tick` is the impact
  tick and `fire_tick = tick − travel`, `travel ≥ 1`, per the contract).
- **At or after impact** — the impact frame, the victim sell/reaction, and any hero-kill treatment —
  may read the resolution (`outcome`/`damage`/`lethal`/`hp_after`).

So a lethal kill-shot is staged **identically to an ordinary shot of the same weapon/tier/travel until
its impact tick**; only at impact does the resolution change the staging — exactly when the truth
itself reveals it. Heavy-for-prominence is therefore a **`tier`** decision (fire-knowable), never a
`damage`/`lethal` one. A losing mech's heavy shot is foregrounded identically to a winning mech's.

*Testable (two tests):* **mirror test** — apply the canonical fixture transform (swap actor labels A↔B
and mirror positions about x, keeping each beat's fire-knowable attributes) → structural staging is
identical up to that relabeling; only the suspense plan differs. **Prefix-blindness test** — take a
fixture and a variant differing *only* in a shot's post-impact resolution (e.g. lethal vs not) → the
staged trace on `[0, impact_tick)` for that beat is **byte-identical**. Between CG-BLIND (construction)
and CG-NO-PRESPOIL (`staged_dom` gate) every choreographer-owned dominance channel is covered;
grade/framing/hero-kill rendering remain the director's own no-pre-spoil responsibility.

## Architecture — four layers + a director seam

`stage(truth_events, seed, feel_profiles) → staged_log`. **`feel_profiles` is required** (one per
actor); an absent profile is a programming error, not a fallback branch. Staging determinism is
conditioned on pinning the build resolver, FeelProfile normalization constants, and the
**archetype-preset-table version**; with those pinned, same `(truth, seed, feel_profiles)` → identical
staged log. Otherwise presentation logs are explicitly **version-local** — combat truth is unaffected
either way, so PvP re-sim of the *truth* is never at risk.

Four layers, applied outer-to-inner:

1. **Dramaturgy (Layer 4) — stage for suspense.** Reads truth + outcome, classifies the **shape**,
   selects an **exciting-shape template** + a **suspense plan** (where to stage apparent initiative
   swings/near-reversals, the `climax_window` = when the outcome is allowed to read, the hero-kill
   framing scaled by lethal `tier`). It deploys arc *tools* to satisfy CG-NO-PRESPOIL; it does not
   assert the truth has an arc. Pure function of truth + seed.
2. **Exchanges (Layer 3).** A **beat scheduler** groups/ranks shots (below); per beat, selects an
   **exchange mode** (closed: beam-trade, swarm, dodge-pursuit, melee — C30–C33) via the composition
   rule (below), places both mechs in the correct **range band** (C27/C28), and structures the beat as
   **Cue·Reaction·Action** (C21–C26).
3. **Primitives (Layer 2).** Emits atomic moves (telegraph C14, AMBAC C15, burst-dash C16, weave C17,
   apex-hold C19) and marks impact/smear as **structural facts** (C18/C20).
4. **Prosody (Layer 1).** Shapes how each primitive executes (ease C6, anticipation C7,
   follow-through/settle C8/C13, burst-and-coast C12, hold-then-snap C11, timing-as-weight C9), biased
   by FeelProfile `heft`/`tempo`. Enforces **CG-CONTRAST** for the active mode.

Output = presentation `advance` beats + spawn `{x,z}` **plus** the root `presentation` hook block.
Truth passes through unedited.

### The beat scheduler (total & deterministic — Codex P1 #2)

A **total** function of the truth shots; all ordering by `(tick, seq)`.
- **Step 0 — mode per shot.** Each shot's grammar-mode comes from the composition rule below
  (shooter + weapon + profile only — it does **not** depend on a beat existing, breaking the rev-3
  chicken-and-egg).
- **Step 1 — coalesce.** Shots with the same shooter and the same step-0 mode within
  `COALESCE_WINDOW` ticks form one candidate **beat**. Representative = `(tick,seq)`-earliest shot;
  `impact_tick` = latest impact in the group; `fire_tick` = `impact_tick − travel` of the
  representative; **`cue_tick` = max(`fire_tick − TELEGRAPH`, actor spawn tick)** — clamped only to
  spawn, with **no** forward-reference to commitment, so Step 1 is independent of Step 3 ordering (all
  overlap is resolved in Step 3; Codex P2).
- **Step 2 — rank (fire-knowable only; causal).** Cue/commit priority is `heavy` (`tier ≥ HEAVY_TIER`)
  > `normal` — a **`tier`** decision, knowable at fire time. It must **not** read `lethal`/`damage`
  (post-impact), so a kill-shot's cue is never foregrounded for *being* a kill (CG-BLIND part 2). The
  `lethal` resolution elevates only the **impact/hero treatment at `impact_tick`** (the kill blast +
  hero beat), not the pre-impact cue. `HEAVY_DMG` therefore applies only to the at-impact emphasis,
  never to cue prominence.
- **Step 3 — commit, with preemption (total rule).** Assign actor commitment in
  **(priority desc, tick asc, seq asc)** order. A full-CRA beat claims **two** spans: the shooter's
  `cue_tick`..`impact_tick` (cue→fire→track) **and** the target's `impact_tick`..`impact_tick+REACT`
  (the victim's sell, C23). The two claims are demoted **independently**: if the
  shooter span overlaps a higher-or-equal-priority claim it sets `is_background:true`; if the target's
  reaction span overlaps one (e.g. the target is busy in its own beat) it sets
  `reaction_background:true` (a background sell) while the shooter span may still be foreground. A claim
  overlapping an already-committed **lower-priority** beat **preempts** it (truncated to background).
  Because heavy (high-`tier`) beats are assigned first by the fire-knowable rank, **a high-tier beat is
  never demoted by an earlier normal commit**; the kill is staged at `impact_tick` as the hero beat
  regardless (its lethal emphasis is an at-impact treatment, not a cue contest). Background beats keep
  `is_impact`/outcome rendering (suppressive framing, no CRA); truth hit/miss always renders.
- **Simultaneous (same-tick) lethal:** whether a later same-tick lethal counts damage or is
  `post_decision` is **the sim's determination, not the choreographer's** (INV-ORDER resolves it in the
  truth layer). The choreographer simply stages what it receives: the `(tick,seq)`-earliest lethal owns
  the kill/hero beat; any later same-tick shot is staged as a background presentation beat. It never
  alters which damage counts — that is already fixed in the truth.

### Exchange-mode composition (total — Codex P2 #5 / P2 #3)

Per shot, using the **shooter's** FeelProfile and the **firing weapon's** `mode_weights`:
- `feel_g[g] = Σ_{f → g in MODE_MAP} shooter.mode_mix[f]` — maps FeelProfile feel-modes to grammar
  modes via the versioned data table **`res://data/grammar_mode_map.json`** (schema:
  `{ "<feel_mode>": "<grammar_mode>" }`, many-to-one). **Load-time validation:** `MODE_MAP` must cover
  **every** FeelProfile feel-mode key (missing key = load error), and every value is one of the four
  grammar modes.
- `score[g] = weapon.mode_weights[g] × feel_g[g]`, then normalize to sum 1.
- Pick **argmax** (ties → fixed order beam-trade<swarm<dodge-pursuit<melee).
- **Input validation (total):** `weapon.mode_weights` is a 4-key map, finite, non-negative,
  renormalized if it drifts from sum 1; any NaN/∞ or all-zero `score` → fall back to
  `argmax(weapon.mode_weights)`; if that is also degenerate → `beam-trade`.
- **Pass-1 gating:** only beam-trade is implemented this pass, so any non-beam-trade selection **falls
  back to beam-trade** and logs a `mode-stub` notice — the first pass therefore only ever *stages*
  beam-trade, while the selection seam is real and exercised.

### Shape classification & exciting-shape templates (Layer 4 — Codex P2 #2)

`decided_tick` (exact, data-only) = `reveal(truth_dom)` if finite, else `end_tick` (a true draw is
"decided" only at the end). `decided_frac = decided_tick / duration`; `margin = |truth_dom(end_tick)|`;
`has_kill` = `result.cause == "kill"` (equivalently, a `lethal` shot exists); `lead_flips` = the number
of times `truth_dom` completes a hysteresis-stable sign transition (enters a `≥ CONF` run of the
opposite sign to the previous stable run — same enter/exit rule as `reveal`), counted over the fight.

**Shape classifier** (deterministic decision tree on the truth; order fixed — `stalemate` precedes
`photofinish` so a zero-damage draw cannot fall into `photofinish`, Codex P1):
- `has_kill ∧ decided_frac ≤ INSTANT_FRAC` → **instant**
- else `lead_flips ≥ 1` → **reversal**
- else `¬has_kill ∧ margin < CONF` → **stalemate**
- else `margin ≥ STOMP_MARGIN ∧ decided_frac ≤ STOMP_FRAC` → **stomp**
- else `has_kill ∧ decided_frac ≥ LATE_FRAC ∧ margin ≤ CLOSE_MARGIN` → **photofinish**
- else → **grind**

**Template registry** (data, `res://data/grammar_templates.json`, `{ "<shape>": "<template_id>" }`):
`instant`/`stomp` → `hero_stomp`, `reversal` → `comeback`, `photofinish` → `photo_finish`, `grind` →
`escalating_duel`, `stalemate` → `standoff`. Each template parameterises the suspense plan (where to
stage apparent contest, the hero-kill spectacle scale). New shapes/templates are data rows, not code.

## The choreographer ↔ director seam — structural facts in a root `presentation` block

The choreographer owns **movement + arc-of-positions**; the director (built) owns **cuts, framing,
lens, grade, dwell, impact-frame rendering, reaction policy** (C39/C40). The choreographer exposes
only **structural facts** — no dwell multipliers, no render flags (Codex P2). To avoid touching the
frozen event shape (Codex P1 #3), hooks live in a **new root-level `presentation` block, outside
`events`** — so they change neither the `{tick,seq,actor,kind,payload}` event shape nor the verified
projection (which reads only `events` + `result`):

```jsonc
"presentation": {
  "beats": [ { "truth_ref": {"tick":int,"seq":int},   // binds to the truth beat
               "exchange_mode": "beam-trade", "range_band": "mid",
               "cue_tick": int, "fire_tick": int, "impact_tick": int,
               "is_background": bool,        // shooter span backgrounded (no CRA)
               "reaction_background": bool,  // target's sell backgrounded independently
               "is_impact": bool } ],
  "fight": { "phrase_bounds": [[t0,t1], …],            // tick spans
             "apparent_initiative": [ {"tick":int,"lead":float}, … ],  // staged momentum, [-1,1]
             "climax_window": [t0,t1],                 // tick span; outcome may read here on
             "lethal_ref": {"tick":int,"seq":int} } }  // the kill's truth beat (or null)
}
```

Per-beat hooks bind by `truth_ref:{tick,seq}`. **Per-fight hooks bind by tick spans / lists, not a
single `{tick,seq}`** (Codex P2 #7): `phrase_bounds`/`climax_window` are spans, `lethal_ref` is the
one `{tick,seq}`, and **`apparent_initiative` is a series with sorted, unique `tick`s and a finite
`lead` quantized to `Q`** (so it is canonically serializable and order-stable).

**Prerequisite — the contract amendment (four explicit touchpoints; Codex P2 #1).** The event-log
contract is frozen, so blessing `presentation` is a deliberate, minimal revision that must update **all
four**: (1) **root schema** — add the optional `presentation` object as the sole presentation-layer
root key; (2) **loader policy** — the loader **ignores every root key not in the truth set**
`{schema, tick_seconds, seed, builds, result, events}` (forward-compatible; unknown roots, incl.
`presentation`, never fold into truth); (3) **outcome projection** — explicitly reads only `events` +
`result`, never `presentation`; (4) **canonical serialization / INV-DET hash** — computed over the
**canonical truth document** = exactly the truth-set keys, sorted, integer fields as integers, with
`presentation` (and any non-truth root key) **omitted by construction** — so the truth hash and PvP
re-sim are provably unaffected. Until ratified, the hooks ride as a side file, not in the log.

## Extensibility — data at named seams

Stable frame: four layers + closed four-mode vocabulary + the primitive registry + the four contrast
metrics. Extensions are data:
- **New weapon** → `motif` row + `tier`/`travel` + **per-weapon `mode_weights`** over the four grammar
  modes (a weight map, not a single tag — hybrids weight several). No code.
- **`MODE_MAP`** (feel-mode → grammar-mode) is a versioned **data table**; new feel modes add rows.
- **New archetype** → a `FeelProfile {heft, tempo, mode_mix}` bias or an authored preset in the
  **data resource** `res://data/grammar_presets.json` (loaded by `grammar_params.gd`; *not* a `.gd`
  file, so "never code" is literal). `mode_mix` sets the exchange proportion; `tempo` cadence; `heft`
  intensity + range-band preference.
- **New primitive** → a rare, deliberate registry row (the choreography equivalent of a contract `kind`).

## Scope — broad skeleton, deep toe-to-toe (lean first pass — Codex P3)

Define the four layers + four mode *slots*, but **implement and tune only the beam-trade path** first,
with a **lean file set** (paths under the existing spike root):
- `godot_director_spike/scripts/sim/choreographer.gd` — orchestrator + Layer 4 (suspense plan) +
  Layer 3 (scheduler, beam-trade exchange, range/CRA) + Layer 1 prosody inline for now.
- `godot_director_spike/scripts/sim/grammar_params.gd` — tuning constants + loads
  `res://data/grammar_presets.json` (archetype presets; schema: `{name, heft_bias, tempo_bias,
  mode_mix, overrides:{<const>:value}}`).
- `godot_director_spike/scripts/sim/movement_trace.gd` — the trace + grammar metrics (extracted from
  today's in-choreographer `movement_trace`).

`prosody.gd`, `primitives.gd`, `modes/*.gd`, `arc.gd` split out **only when** a second mode or a
growing prosody set needs it — not preemptively. The FeelProfile + mode-weight seams are wired (bias is
real for beam-trade); only the one archetype is deeply tuned.

## Testing — defined metrics, hard gates vs advisory

Metrics are defined precisely — **sampling:** per tick over the staged trace; **aggregation:** stated
per metric; **tolerance:** vs the reference fixture. (Codex P2 #8.)

**Hard gates (any staged fight):**
- **CG-CONTRAST — closed per-mode registry (4):**
  - *beam-trade:* passes if **either** speed histogram is bimodal (bimodality ≥ `BIMODAL_MIN`, pauses
    ≥ `PAUSE_MIN`) **or** aim/recoil alternation is present (bearing snaps to target + a recoil
    micro-retreat per shot) — so a frantic point-blank duel is not false-failed (Codex P2 #6).
  - *swarm:* salvo present + target weave (bearing oscillation ≥ `WEAVE_MIN`).
  - *dodge-pursuit:* sustained weave over the pursuit window (oscillation ≥ `WEAVE_MIN`, low hit rate).
  - *melee:* clash contrast — close-range speed spike → contact dwell (apex-hold/impact) → separation.
- **CG-NO-PRESPOIL (no ML; test-independent — Codex P1 #1).** Both series are computed by the
  **validator**; `staged_dom` reads the **raw staged motion trace only**, never the choreographer's
  `apparent_initiative` hook (so a choreographer cannot pass by self-reporting neutral initiative while
  its motion telegraphs the winner).
  - `truth_dom(t) ∈ [-1,1] = frac_lost_B(t) − frac_lost_A(t)`, where `frac_lost_X(t) = clamp(Σ damage
    to X through tick t / spawn_hp_X, 0, 1)`. Per-side normalization handles **asymmetric spawn HP**;
    damage sums all connecting `shot`/`melee` (ordered by `(tick,seq)`); `post_decision` shots carry no
    damage so contribute nothing. Positive = A ahead.
  - `staged_dom(t) ∈ [-1,1] = clamp(pressure_A(t) − pressure_B(t) + κ·(sells_B(t) − sells_A(t)))`,
    where `pressure_X(t) = EMA_α( clamp(closing_rate_X(t)/REF_SPEED, -1, 1) )`, `α = 2/(W+1)`, seeded
    `pressure_X(spawn)=0`. **`closing_rate_X(t)` is separable even when both move:**
    `closing_rate_X(t) = dot( X_pos(t−1) − X_pos(t), unit(enemy_pos(t−1) − X_pos(t−1)) )` — the
    projection of X's own displacement onto the direction to where the enemy was (so each actor's
    contribution is independent of the other's motion that tick). `sells_X(t) = EMA_α(` of an
    **explicit detector**: 1 on a tick in an impact window `[impact, impact+REACT]` where X (the struck
    actor) displaces **away from the shooter** — `dot(X_pos(t)−X_pos(t−1), unit(X_pos(t−1)−shooter_pos))
    ≥ SELL_MIN` — else 0`)`. Both terms are read **straight from the raw staged trace** — never from
    `apparent_initiative` or any hook. `κ`, `W`, `REF_SPEED` are constants. **Numeric pins:**
    `shooter_pos` is sampled at the shot's `impact_tick`; `unit(0) ≡ (0,0)` (a coincident position
    contributes 0); `sells_X` EMA is seeded `0` at spawn; all scheduler/impact spans are half-open
    `[start, end)`. This captures both "who presses" and "who is visibly taking hits."
    *(Director-owned channels — grade, hero framing, cut emphasis — can also pre-announce a winner; that
    is the **director's** no-pre-spoil responsibility, flagged for the director layer, outside this
    choreographer gate.)*
  - `reveal(series)` = the start tick of the **final contiguous run** to fight-end with constant sign,
    using hysteresis: a run **enters** "revealed" at the first tick `|series| ≥ CONF` and **exits** when
    `|series| < CONF·(1−HYST)`; `reveal` = the entry tick of the last run that reaches `end_tick`; `∞`
    if none (true draw / zero-damage).
  - **Gate (bound is validator-derived — Codex P1):** let `late_gate = LATE_FRAC · duration` (a
    constant fraction, **not** the choreographer's `climax_window`). Require
    `reveal(staged_dom) ≥ min(reveal(truth_dom), late_gate) − SLACK`. Decided fights: staging may not
    reveal more than `SLACK` before the truth does (a fast stomp has tiny `reveal(truth_dom)`, so
    staging may match — suspense isn't claimed, excitement is). Draws (`reveal(truth_dom)=∞`): staging
    must hold the result open until `late_gate`. **Reversals** are allowed (`reveal` keys off the
    *final* stable lead). Separately, an **advisory** check asserts the hook `climax_window.start ≥
    reveal(truth_dom)` (the choreographer must not *claim* its climax before the truth decides) — but
    the hard gate never uses the hook, closing the self-authorization hole.
- **CG-BLIND (two tests):** the **mirror test** (canonical transform: swap actor labels A↔B + mirror
  positions about x, keep each beat's fire-knowable attributes → structural staging identical up to the
  relabeling) and the **prefix-blindness test** (a fixture vs a variant differing only in a shot's
  post-impact resolution → the **entire** visible staged output — the whole staged trace **and** all
  causal `presentation` fields — on `[0, impact_tick)` is byte-identical, not just the changed beat, so
  the resolution cannot leak into concurrent beats or hooks before its own impact).
- **Determinism + pass-through:** same `(truth, seed, feel_profiles)` → identical log; truth
  re-projects equal; the `presentation` block is excluded from the projection.
- **Range/measure:** every connecting `shot` is in-band (C27) or has a preceding boost-close (C28).

**Edge-fight fixture suite (first-class — owner request).** A library of edge **truths**, each a
fixture asserting the hard gates + the correct exciting-shape template, and each emitting a balance
diagnostic `decided_tick / duration`:
instant-kill, fast-stomp, long-grind, photo-finish, reversal, cap/timeout, zero-damage stalemate. Each
fixture pins its **expected `shape` + `template_id`** (per the classifier/registry above) and its exact
**`decided_tick`**, and asserts CG-NO-PRESPOIL holds and the right template is applied (e.g.
instant/stomp → `hero_stomp`, not a boring telegraph; stalemate → `standoff` held open to the end). The
`decided_tick` distribution across the suite is the **balance signal** flagged above.

**Advisory diagnostics (reported, not gating; expected on the reference fixture):** ease, anticipation
reverse-pulse, overshoot-settle, ramp↔`heft` correlation, CRA windows on heavy beats, the weave
signature, and the **reference-diff** (recreated reference metrics within tolerance of the
hand-authored reference — the test that exposed the rev-0 failure). Arc shape
(escalation/peripeteia/lethal-late) is **diagnostic only**, on the reference fixture, never a gate.

## Tuning constants (design values, not literature — `grammar_params.gd`)

`PAUSE_MIN`, `BIMODAL_MIN`, `WEAVE_MIN`, `COAST_MIN`, ease ramp floor, anticipation amplitude, settle δ,
`heft→ramp` curve, `PROXEMIC_SCALE` + four range-band edges, per-mode weapon-reach, `COALESCE_WINDOW`,
`TELEGRAPH`, `REACT`, `HEAVY_TIER`/`HEAVY_DMG`, no-pre-spoil `W`/`α`(=2/(W+1))/`κ`/`REF_SPEED`/`SELL_MIN`/`CONF`/
`HYST`/`SLACK`/`LATE_FRAC`, initiative quantum `Q`, shape thresholds `INSTANT_FRAC`/`STOMP_MARGIN`/
`STOMP_FRAC`/`CLOSE_MARGIN`, hero-kill spectacle scale by `tier`. All per-archetype overridable via presets; seeded
from the reference fight and tuned by the reference-diff diagnostic + the edge-fixture suite.

## Migration / relationship to the shipped choreographer

Shipped reactive triggers become special cases: evade = a weave primitive (C17); stagger = the
victim's "sell" (C23); range-tighten = a low-`heft`/low-HP range-band shift (C27). Nothing discarded.
The v2 director cutover (separately gated by the golden hash) is unchanged; this design produces the
same *kind* of presentation log, plus the root `presentation` hook block (pending the contract
amendment above).

## Out of scope / deferred

- **Suspense availability / combat balance** — flagged for the sim/balance layer; the edge-fixture
  `decided_tick` distribution is its signal. Not fixable in the choreographer.
- The contract amendment to bless the `presentation` root key (small, separate, ratified in the
  contract spec).
- The v2 director-side cutover + golden-hash re-baseline (separate, gated).
- Deep swarm/dodge-pursuit/melee implementation (slots only this pass).
- Multi-archetype tuning beyond toe-to-toe (seam built; one archetype tuned).
- HP/UI display of who's winning — a director/UI choice that can fight CG-NO-PRESPOIL; flagged there,
  out of choreographer scope.
- Cockpit/interior, terrain, >2 actors; all camera/cut/lens/grade/dwell/impact-frame *rendering*
  (Director-owned, built).
