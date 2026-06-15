# Director Grammar — design spec

Date: 2026-06-16. Branch: `combat-feel-restart`. Status: approved design, pre-implementation.

## What this is

The Director Grammar is the first-class, tunable home for every cinematic-director parameter the
combat viewer uses — composition, lens, lighting, color, continuity, cut/timing, and spectacle
staging. The game's appeal is the spectacle, so the camera/staging craft is treated as a primary
system, not as scattered magic numbers.

Today that craft is half-encoded as constants inside `scripts/directors/hybrid.gd` (`ISO_OFFSET`,
`OS_LEN`, `CUT_LEN`, `BT_PRE/POST/SCALE`, inline FOVs and roll) and half-implicit in the shot math.
This spec lifts the *parameters* into one documented `ShotGrammar` resource — each parameter tagged
to the research finding that justifies it — while leaving the *shot logic* in the director. It also
adds the one render layer the grammar was missing: a lighting/color grade pass.

This is **global craft**: one grammar drives every fight identically. It is NOT build-driven. The
separate build→feel `FeelProfile` (its own later spec) sits on top and only *modulates emphasis*
per mech (e.g. a heavier build leans framing toward over-the-shoulder and slows cut cadence). The
grammar is the canon; the FeelProfile is the lean.

## Grounding

Every parameter here traces to the three combat-feel seeding documents (read them first):
`research-synthesis-2026-06-13-gundam-uc-combat-feel.md` (F1–F10),
`research-synthesis-2026-06-15-weighty-mecha-multi-title-and-cockpit.md` (F11–F21), and
`research-synthesis-2026-06-16-director-grammar-lighting-color-lens-continuity.md` (F22–F40). The
F-tags below point back to those findings.

Two findings from the seeding set are already validated in the current build: F34/F35 (an
establishing layout fixes geography; spatial coherence beats per-shot polish) justify the existing
iso/orthographic backbone, and F39 (the kill is its own authored beat) was confirmed by the
kill-cam hold shipped at commit 9c9000e.

## Architecture

`ShotGrammar` is one resource composed of seven named sub-blocks, one per dimension:

```
ShotGrammar
├── Composition   placement, angle, framing-for-scale, OTS,       F4, F6, F8,
│                 shot vocabulary (iso/hero_os/hero_cut/           F15, F21
│                 melee_cut/cockpit_pov/frame_and_streak)
├── Lens          FOV / focal length, compression, DoF            F31, F6
├── Lighting      key/fill, chromatic shadows, GI bounce, FX prims F22–F25
├── Color         base palette + mood variants, accents, cut-bridge F26–F30
├── Continuity    180° axis, screen direction, establishing layout F32–F36
├── Timing/Cut    cut cadence, hold-on-impact, impact frames, BT   F5, F14, F37–F38
└── Spectacle     kill-as-own-beat, staggered blast, yield staging F9, F16, F17, F39
```

The design rule is **parameters move, logic stays**:

- The shot math and the director loop stay in `director.gd` (base) and `hybrid.gd` (variant): how a
  camera position is computed, how `build_shot_list` schedules beats, the iso backbone, occlusion
  solving. This is the proven F4–F6 machinery and is not rewritten.
- The constants come out of `hybrid.gd` into `ShotGrammar`. The director reads the grammar instead
  of hardcoding. Defaults equal the current shipped values, so lifting them changes nothing visually
  until the values are tuned.

Consumers, each reading its sub-block, with no structural change to their role:

- `director.gd` / `hybrid.gd` → Composition, Lens, Continuity, Timing/Cut.
- a new `Grade` node → Lighting, Color (the one genuinely new render layer).
- `garnish.gd` → Spectacle, the FX primitives (F25), and impact frames (F37).

Determinism is preserved: the grammar is parameters plus the existing playback path, so the same log
and the same grammar produce the identical event sequence and camera solve. This matters for the
PvP re-simulation the project's architecture must not preclude.

## The dimensions

### Composition (F6, F4)

Mostly a lift of today's proven values into named parameters: the `iso` backbone (`iso_offset`
currently `(-45, 90, 18)`, zoom clamp `50–118` driven by mech separation, aftermath zoom `58`); the
`hero_os` corner frame (pullback `18`, lateral `8`, height `16`); the `hero_cut` low beside-the-shooter
angle with roll `-0.05`. The one new parameter is `framing_emphasis` — a scale-versus-impact bias the
director reads to pick a framing register per beat (low/wide/distant for awe versus tight
over-the-shoulder for weight). `framing_emphasis` is also the hook the FeelProfile later biases per
build.

The Composition block also owns the **shot vocabulary** — the named shot types the director can
schedule, each with its framing parameters. It lifts `hybrid.gd`'s existing vocabulary (`iso`,
`hero_os`, `hero_cut`, `bullet_time`, `melee_cut`) and adds two:

- `melee_cut` (F8) — melee is a distinct visceral mode, so its shot carries the closest/heaviest
  framing and, paired with `cut_cadence`, the densest cuts, not merely an OTS bias. The shot already
  exists in `hybrid.gd`; the grammar makes its framing tunable.
- `frame_and_streak` (F15) — a fast-pass / charge primitive that sells speed by moving the frame over
  the subject with a streaked/blurred background, rather than relying on the actor's own animation.
- `cockpit_pov` (F21) — the outward cockpit shot: camera at the firing mech's head/cockpit anchor
  looking out at the enemy, with a lightweight on-demand HUD overlay (target bracket, thin edge chrome,
  body-aware vignette, per F21). No modeled interior, no pilot, no feedback — purely a camera position
  plus overlay. Placement is author-by-feel on chosen beats (the opening squared-up read, a hero/charge
  beat); it is NOT auto-scheduled on a cut-rhythm (the cockpit three-beat intercut was refuted). It is
  additive punctuation that never displaces the iso backbone or the bullet-time kill. (`bullet_time`'s
  framing lives here; its timing parameters live in Timing/Cut.)

### Lens (F31, F6)

`fov_per_mode` lifts the existing FOVs (`40 / 45 / 46 / 48`). New: `compression` — a continuous
long-lens control. On tension or scale-stack beats the director uses a low FOV plus a pulled-back
distance so foreground and background mechs read at similar size (the frame-as-graphic-plane looming
effect, F31). It is a continuous dial, not a preset list — the "anime uses only discrete perspective
presets" claim was refuted 0-3. `dof` names the focus strength the director already applies
(`_set_focus(dist, 0.07)`) and makes it tunable per shot; `rack_focus` is an optional focus pull on a
chosen beat. Scale is now sellable two ways — by composition angle/distance (F6) and by lens
compression (F31) — and the grammar lets a beat choose.

### Lighting (F22–F25)

Rides on Godot Forward+ (GI, `WorldEnvironment`, tonemap/adjustments). `key/fill/rim` with a
**chromatic fill** (F22): shadows take a non-black tint (a cool blue), never crushed to black — one
color parameter does most of the work. `gi_bounce` (F24): lean on Forward+ SDFGI/GI so beam and muzzle
flashes cast onto mechs and the city. Note the current build *disables* `garnish`'s flash lights
(`flash.visible = false`, "scene lit by directional + sky only"); F24 says turn dynamic beam-light
back on — the single biggest "anime light" win. `fx_primitives` (F25): the named, individually-tunable
FX set (light-flare, debris, explosions, smoke, sparks, lightning, missiles), formalizing what
`garnish` half-has.

Lighting ownership is split to avoid the three-way ambiguity the review flagged: **render** owns the
GI/SDFGI solve and the static directional + sky (engine settings); **`garnish`** owns the transient FX
lights and the FX primitives above (beam/muzzle flashes that cast onto mechs and city, F24); the
**`Grade` node** owns the post-render mood grade and color (F23, below). The grammar's Lighting block
holds the authored values each reads; it does not itself render.

### Color (F26–F30)

Driven by a new `Grade` node that owns `WorldEnvironment` adjustments plus a post pass (per F23, the
grade is a finishing layer applied over the render). `base_palette` plus named `mood_variants`
(F26/F27): a canonical palette plus state variants — cool ambient default, warm hero/charge push,
desaturated death/aftermath — with the Grade node lerping between them when the director signals a
beat. `per_cut_offset` (F28): small grade nudges layered on the base per shot. `accent_override`
(F29): a per-beat accent hue on key elements (e.g. push a hero beam's color past its literal value).
`cut_bridge` (F30): actor-keyed hues (warm aggressor, cool counter), a saturation push on the dominant
color, optionally fused in a shared reflective surface.

Scope call: v1 of the Grade node is `WorldEnvironment` adjustments (brightness/contrast/saturation/tint),
the mood-variant lerps, AND the per-cut offsets (F28) and per-beat accent overrides (F29) — those are
data/params applied through the same adjustment path, so they are in v1. Only a full per-element
LUT/color-correction pipeline is deferred as a later refinement; `cut_bridge` (F30) beyond a simple
two-actor hue pairing is also later.

### Continuity (F32–F36)

`axis_of_action` (F32): the line between the two engaged mechs; perspective cut-ins stay on one side,
with the iso backbone as the safe fallback. `screen_direction` (F33): each mech is keyed a persistent
screen side at fight start and held across cuts. `establishing_layout` (F34): the existing iso/ortho
backbone already is this — formalized as the geography-fixing pass. `coherence_over_polish` (F35): a
guardrail principle, plus a continuity check added to the test runner (the suite already asserts camera
occlusion; add a line/side check). `split_screen` (F36): an optional primitive for parallel
simultaneous action.

Scope call: v1 enforces axis and screen-direction as **soft constraints** on shot placement (flip-safe,
with the iso fallback), not a hard camera solver — this keeps the proven grammar intact rather than
rebuilding the camera math.

### Timing / Cut (F5, F14, F37–F38)

`cut_cadence` (F5/F38): per-beat shot durations (lifting `OS_LEN`, `CUT_LEN`); fast in combat,
expanding on emotional/aftermath beats. `hold_on_impact` (F14): names the impact dwell already added via
hitstop. `impact_frames` (F37, new): a sub-perceptual 1–2 frame flash/contrast insert on contact beats,
allowed a small timing window rather than pinned to a single frame (the strict-contact-only claim was
refuted 1-2). `bullet_time`: lifts `BT_PRE/POST/SCALE`.

Scope call: the three time-emphasis tools (bullet-time, hold-on-impact, impact-frame) get a **precedence
arbiter** so they do not stack into mush — one tool owns a given beat.

### Spectacle (F9, F16, F17, F39)

`kill_beat` (F39): the destruction is its own authored beat with its own timing — exactly what the
kill-cam fix validated. `staggered_blast` (F16): on a lethal or capital-tier hit, emit a series of
explosions at varied camera distances rather than one. `yield_by_class` (F17): weapon class maps to
staging intensity plus a fear beat — a capital/payload-tier discharge gets outsized treatment, a
sidearm does not.

`evasion_beat` (F19): an all-range evasion / dodge-pursuit beat (one mech weaving a storm of
multi-source fire) gets its own staging — a distinct camera-and-cut treatment. The *choice* to run an
evasion exchange is the FeelProfile's domain (driven by weapon mix); the grammar owns how that beat is
staged when it occurs. Cross-references the FeelProfile spec's `mode_mix`.

Out of grammar scope by design: **F10 (momentum-swing fight arc)** is whole-fight dramaturgy expressed
in the authored event log / choreography, not a camera-grammar parameter — the grammar stages the beats
the log produces. **F18 (terrain acts on the mech / groundedness)** is a sim/environment-interaction
concern (it modifies movement, which is the FeelProfile/`mech_actor` domain), not director craft. Both
are noted here so their absence from the seven dimensions is deliberate, not an oversight.

## Relationship to FeelProfile (next spec)

The FeelProfile does not write any of these values. It supplies a per-mech bias that the consumers
apply on top of the grammar — for example a high-`weight` build leans `framing_emphasis` toward OTS,
slows `cut_cadence`, and lowers movement cadence. The grammar is the global canon; the FeelProfile is
the per-build lean. The grammar must be designed and tuned first because the FeelProfile modulates it.

## Testing

Unit-level: the `ShotGrammar` resource loads and the director reads it with defaults equal to the
current shipped constants (a regression guard — the lifted grammar must reproduce today's look). The
time-emphasis arbiter is unit-tested (given overlapping beats, exactly one tool owns the beat). The
continuity check (line/side) is added to the existing headless test runner alongside the occlusion
assertion.

Visual: capture frames of a fight with the grammar driving the camera and confirm parity with the
current look before tuning; then capture the new behaviors (a compression beat, a mood-variant
transition on the kill, an impact frame, a staggered kill blast, a `cockpit_pov` shot with HUD overlay)
for review.

Process (F40): lock the director look in a previz pass — capture and approve the grammar's lighting,
color, and key shots on a reference fight *before* tuning per-fight values, rather than discovering the
look in post. The parity-capture in step 1 of the build sequence doubles as this look-lock.

## Scope boundaries (must-not-touch)

- Do not rewrite the proven shot math or the camera solver; lift parameters only.
- Do not make the grammar build-driven; per-build behavior belongs to the FeelProfile spec.
- Do not build the cockpit feedback / bond / sync system (deferred to v0.2 pilot-fit).
- Do not auto-schedule a cockpit intercut cut-rhythm (refuted; author-by-feel only).
- Do not displace the iso backbone or the bullet-time kill; new shots are additive punctuation.
- v1 Grade is WorldEnvironment adjustments + mood lerps, not a full LUT pipeline.

## Open questions for the implementation plan

1. The lighting-ownership split is pinned in the Lighting section (render = GI/static; garnish = FX
   lights; Grade = post-render mood). Remaining detail for the plan: the exact handoff order per frame
   so the Grade pass and garnish FX lights don't double-expose a beam flash.
2. The canonical palette plus mood-variant data shape (one base plus N named state variants) and which
   fight states trigger each (charge, hit, kill, aftermath).
3. The exact precedence rules of the time-emphasis arbiter across bullet-time, hold-on-impact, and
   impact frames.
4. Whether the 180° / screen-direction constraints are enforced on the shot-placement step or left as
   authored guidance with a test-time check.

## Suggested build sequence (for the plan, not committed here)

1. Extract `ShotGrammar` with Composition/Lens/Continuity/Timing sub-blocks at current-value defaults;
   point `hybrid.gd` at it; prove visual parity. (Pure refactor, lowest risk.)
2. Add the `Grade` node (Lighting + Color v1: chromatic fill, GI beam-light on, mood variants).
3. Add the new behaviors: `compression`, `impact_frames` + arbiter, `staggered_blast` / `yield_by_class`.
4. Add the soft continuity constraints + the test-runner line/side check.
