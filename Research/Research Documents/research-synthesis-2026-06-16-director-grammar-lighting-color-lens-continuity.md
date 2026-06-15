# Research synthesis — the director-grammar gaps: lighting, color, lens, spatial continuity

> **SEEDING DOCUMENT — combat & camera feel.** Canonical reference; read before any combat,
> camera, lighting, color, or fight-choreography work. Third in the set, after
> `research-synthesis-2026-06-13-gundam-uc-combat-feel.md` (F1–F10) and
> `research-synthesis-2026-06-15-weighty-mecha-multi-title-and-cockpit.md` (F11–F21). Findings F22+.

Date: 2026-06-16. Source: a second deep-research pass (14 sources, 25 claims 3-vote verified,
21 confirmed / 4 killed) targeting the four director dimensions the prior passes were silent on —
lighting, color/grade, lens, and spatial continuity. As before, the harness's auto-synthesis step
was cut short, so this was assembled by hand from the verified-claim set; only confirmed claims
appear as findings.

**Why this pass exists:** F1–F21 are deep on movement, camera-as-actor, cut rhythm, time, and
spectacle staging, but silent on the four dimensions below — exactly the ones needed to make the
**Director Grammar** a first-class, fully-tunable spectacle layer. The game is the spectacle; these
are the missing levers.

**IP guardrail (CLAUDE.md):** craft only — lighting, color, lens, continuity technique. The named
works (Evangelion, Gundam, Koe no Katachi, Kizumonogatari) are cited as evidence of a technique,
never to copy. Original mecha identity.

---

## Lighting (→ lighting-rig params)

- **F22 — Chromatic shadows, never pure black.** Shadows should carry a non-grey hue (a light-blue
  was mixed in) so they have *presence* rather than just being a loss of brightness. → **Dial:** tint
  shadow/ambient with a chromatic fill colour, not a crush-to-black. *High confidence (primary —
  Koe no Katachi colour roundtable).*
- **F23 — Lighting is a post-render compositing (satsuei) layer.** The mood-defining light and
  ambiance are added as a deliberate finishing pass *on top of* the rendered space, separate from and
  after the asset/CG work. → **Architecture:** treat lighting/grade as its own grammar stage applied
  over the scene, not baked per-asset. *High (primary — Kizumonogatari VFX).*
- **F24 — Inter-surface light bounce sells believable light.** Global illumination (surfaces bouncing
  light into each other) is what makes a 3D space read as photographically real, vs flat per-object
  lighting. → **Dial:** favour GI / bounce; beam-and-muzzle flashes should cast onto mechs *and*
  environment. *High (primary — Kizumonogatari).* (Godot Forward+ already does GI/SDFGI — lean on it.)
- **F25 — A discrete effects-primitive vocabulary.** A single combat sequence is built from named,
  role-specialized FX elements — light-flare (radial beam/muzzle burst), impact frames, debris,
  explosions, smoke, sparks, lightning, missiles — each authored as its own element. → **Primitives:**
  model the FX layer as a set of independently-tunable named primitives, not one blob. *High (primary —
  Eva sakuga breakdown).* Pairs with the project's existing `garnish` layer.

## Color / grade (→ color-script params)

- **F26 — Color is a first-class authored global layer.** Anime has a dedicated colour-designer role
  that fixes the entire palette as a canonical reference artifact. → **Architecture:** COLOR/GRADE is
  its own tunable grammar layer with a canonical palette, distinct from per-shot lighting. *Medium
  (secondary — colour-designer glossary).*
- **F27 — Per-beat palette variants by mood/environment.** The authored palette is not flat; colour
  schemes are explicitly designed to shift with lighting and mood. → **Dials:** a baseline palette plus
  mood variants keyed to fight state (cool ambient default, warm hero/charge push, desaturated death).
  *Medium (secondary).*
- **F28 — Per-cut colour correction over the base palette.** Colour was tuned cut-by-cut against the
  composited image for minute beat-specific adjustments, not set once globally. → **Dial:** allow
  per-shot grade offsets layered over the canonical palette. *High (primary — Koe no Katachi).*
- **F29 — Emotional accent-hue overrides.** Accent colours were deliberately added *against* an
  element's literal colour (pink into tears, green into sweat) to load a beat with feeling. → **Dial:**
  a per-beat accent-hue override on key elements (e.g. a colour push on a hero beam beyond its literal
  colour). *High (primary).*
- **F30 — Colour-as-cut-bridge / palette pairing per exchange.** A clash is carried across a cut by
  palette: a warm/red aggressor and a cool/blue counterpart reconciled in a shared reflective element.
  → **Dial:** actor-keyed hues (warm vs cool), a saturation push on the dominant colour, and a shared
  reflective surface that fuses the pair. *Medium (secondary — Eva/Slant; 2-1 vote).*

## Lens (→ lens / FOV / DoF params)

- **F31 — Telephoto compression as a scale-flattening tool.** A long lens minimises depth so fore- and
  background subjects read at nearly the same size — the frame becomes a graphic plane; used as a
  deliberate distancing effect characteristic of Japanese film. → **Dial:** a continuous focal-length /
  FOV+compression control; long-lens to flatten and stack scale (tension, looming), wide for depth and
  awe. *Medium (blog).* **Note the killed claim below:** the idea that anime only uses a few discrete
  perspective *presets* was refuted 0-3 — so model lens as a **continuous** dial, not a preset list.
  *Relates to F6 (framing-for-scale): F6 sells scale by angle/distance, F31 by lens compression — two
  different scale levers.*

## Spatial continuity & readability (→ continuity rules)

- **F32 — 180° axis-of-action.** Confine successive shots to one side of the line between the two
  engaged actors to preserve screen direction. → **Rule:** define the axis between the two mechs; all
  hero/cut cameras stay on one side. *Medium (blog; 2-1).* *Bounds where F4/F5 authored cameras may
  legally sit.*
- **F33 — Persistent screen direction.** Establish each actor on a screen side in the opening shots and
  hold it across the scene unless deliberately reversed. → **Rule:** key each mech a persistent screen
  side at fight start; enforce across cuts. *Medium (blog).*
- **F34 — Authored establishing-layout fixes geography first.** Layout is the structural backbone — one
  layout sets the framing *and* the background geography all later work conforms to. → **Rule:** an
  establishing-layout pass locks who-is-where before fast cutting. *Medium (secondary — layout-crisis).*
  *This is exactly what the project's iso/orthographic backbone already provides — F34 is its
  justification.*
- **F35 — Spatial coherence beats per-shot polish.** A broken or mismatched environment is the single
  strongest immersion-breaker — worse than any drawing/animation error. → **Rule:** prioritise
  consistent geography/perspective over local shot polish. *Medium (secondary).*
- **F36 — Split-screen for parallel hero actions.** A literal screen-split shows two mechs acting
  simultaneously while keeping who-is-where legible. → **Primitive:** an optional split-screen beat for
  synchronized parallel action. *Medium (primary — Eva sakuga; 2-1).*

## Emphasis & time (extends F5 / F14 / F16)

- **F37 — Impact frames (shock koma).** Special 1–2 frame inserts (flash / high-contrast / inverted
  plate) appear for a split second to make an impact register harder. → **Primitive:** a sub-perceptual
  impact-frame override fired on a contact/kill/overload beat. *Medium (secondary).* *Extends F14: where
  F14 **holds** the impact pose, F37 momentarily **replaces** it. The stricter claim that it must be
  timed to exactly the contact frame was killed 1-2 — so allow a small timing window, don't hard-pin it.*
- **F38 — Beat-driven cut cadence.** Storyboards "expand during emotional highs, then race during
  combat" — fast cuts for urgency, long near-static frames for weight. → **Dial:** cut-cadence varies by
  beat type. *Medium (blog).* *Corroborates F5.*
- **F39 — The kill-explosion is its own authored beat.** The destruction explosion was handed off to a
  different specialist and authored separately from the attack animation. → **Rule:** stage the kill
  blast as its own grammar beat with its own timing, not a side-effect of the hit. *High (primary — Eva
  sakuga).* *Corroborates F16 (staggered multi-explosion) and the kill-cam work already shipped.*

## Process note

- **F40 — Lock the director look in pre-production previz.** The decisive step for CG quality is
  front-loaded planning; composites were pre-visualised straight from CG for director approval *before*
  the animation stage. → **Practice:** lock lighting/staging intent in previz, don't discover it in post.
  *High (primary — Kizumonogatari).*

---

## Director-grammar bucket map (the first-class ShotGrammar)

| Bucket | New findings (this pass) | Prior findings |
|---|---|---|
| Lighting-rig | **F22 chromatic shadows, F23 post-render grade, F24 GI bounce, F25 FX primitives** | — (new dimension) |
| Color / grade | **F26 first-class layer, F27 mood variants, F28 per-cut correction, F29 accent overrides, F30 cut-bridge** | — (new dimension) |
| Lens / FOV / DoF | **F31 telephoto compression (continuous)** | F6 (framing-for-scale) |
| Continuity rules | **F32 180° axis, F33 screen direction, F34 establishing layout, F35 coherence>polish, F36 split-screen** | — (new dimension) |
| Cut rhythm & time | **F37 impact frames, F38 beat cadence, F39 kill-as-own-beat** | F5, F14, F16 |

All of these are **global director craft — not build-driven.** The build→feel `FeelProfile` modulates
*emphasis* (which build leans into which beat), but lighting/color/lens/continuity are the grammar's
own dials.

## Do NOT use (refuted this pass)

- **"Anime uses only discrete perspective presets, not continuous focal length" (refuted 0-3).** Model
  lens as a **continuous** FOV/compression dial (F31), not a fixed preset list.
- **"Depth-staged two-actor framing (fg/bg + opposed facing) as a readability primitive" (refuted 0-3).**
  Not verified; rely on the axis/screen-direction rules (F32–F33) for two-mech legibility instead.
- **"Impact frame must be timed strictly to the single contact frame" (refuted 1-2).** Allow a small
  timing window around the beat (F37).
- **"CG light is co-designed against the 2D layout in real time" (refuted 1-2).** The verified model is
  the opposite — lighting is a **post-render compositing layer** (F23).

## Open design questions

1. How the lighting grade (F23) composes with Godot's Forward+ GI/SDFGI and the existing `garnish`
   FX — what's a render setting vs an authored grammar dial.
2. The canonical palette + mood-variant data shape (F26/F27): one base palette plus N named state
   variants, and what fight states trigger each (charge, hit, kill, aftermath).
3. Impact-frame (F37) authoring vs the existing bullet-time/hitstop — three time-emphasis tools that
   must not stack into mush.
4. Whether the 180°/screen-direction rules (F32/F33) are enforced as hard constraints on the director's
   camera solver or as authored guidance per shot.
