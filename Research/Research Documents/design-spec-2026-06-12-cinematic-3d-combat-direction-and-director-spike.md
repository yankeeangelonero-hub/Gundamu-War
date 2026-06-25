---
project: kitbash-mecha
repo: gundamu-war
artefact: research-document
doc_type: design-spec
kind: finding
status: draft
created: 2026-06-12
source_request: "Owner request: make the watched autobattler combat visually interesting; brainstormed from the anime-grail vision (08th MS Team / Char's Counterattack city battles) to a committed presentation direction and spike"
branch: backpack-system-test
ip_guardrail: "Original identity only; no Gundam names, V-fin, split twin-eye visor, RX-78 silhouette, or other licensed terms/silhouettes. Reference works are cited as feel targets, never as content."
feeds:
  - docs/slices/KM-STACK-SPIKE-godot-platform-confirmation.md
  - docs/adrs/2026-06-06-build-stack-decision.md
supersedes_pending_routing:
  - "CLAUDE.md / High Level Spec: no-3D rule (presentation layer only)"
  - "CLAUDE.md / High Level Spec: mobile-app-compatible second platform target"
---

# Design Spec 2026-06-12 — Cinematic 3D Combat Direction + KM-DIRECTOR-SPIKE

## Context

Feel-testing the backpack comparator (this branch) surfaced that the fight resolves instantly
into a text log — there is no watched fight at all, and the watched fight is the core of the
session loop ("workshop, deploy, watch, homecoming"). The owner's stated holy grail is an
anime-worthy cinematic mech battle — the 08th MS Team / Char's Counterattack register: mechs
that feel giant, beams and ballistics flying through a city, big explosions, adrenaline, and
intense emotion — with a director's camera inside a live 3D battle (MechWarrior physicality,
cinematic framing).

Brainstorming decisions reached with the owner on 2026-06-12, in order:

1. **Watch goal: spectacle.** The watched fight optimizes for drama and felt intensity. The
   debrief carries analysis/legibility; the fight does not have to be a readable ledger.
2. **Presentation is 3D.** Kitbashed player-authored mechs argue *for* 3D: modular parts on a
   procedural rig animate from any camera angle, while 2D sprite kitbash locks the camera to
   drawn facings and caps quality at cutout-puppet. Customizable + polished 2D animation is a
   structurally bad combination (market evidence: customizable mech games are 3D; celebrated 2D
   mech animation is fixed-design).
3. **Mobile target dropped; PC-first all-in.** Frees the visual ceiling. Requires canon routing
   (see Routing).
4. **Engine: Godot 4.6 stays, with an exit criterion.** Owner has an engine-agnostic 3D art team
   (DCC asset producers, no Unreal pipeline specialism). Honest ceiling assessment: Godot reaches
   ~80% of the cinematic read at the team's sustainable art bar (volumetric fog, emissive beams,
   SDFGI, full post stack, IK/procedural animation, code-driven camera); the missing ~20% is
   Lumen-grade photoreal GI / hardware RT / Niagara-peak set pieces. Deciding inversion: Unreal's
   power tools are GUI-first and human-authored (would require staffing a tech-artist seat),
   while Godot is text-all-the-way-down, so coding agents fill the tech-artist role and artists
   stay in DCC. The money-shot spike below is the exit test: **fail → Unreal re-opens, with the
   Niagara tech-artist seat costed in.**
5. **Sim stays deterministic and authoritative; renderer garnishes.** The future sim gains
   *coarse space* (positions, ranges, cover, movement — owned fixed-point code, never engine
   physics, preserving byte-identical PvP re-simulation). Bullets, ricochets, and debris are
   cosmetic VFX synced to log outcomes: a tracer that sparks off a building was always a miss in
   the log. MechWarrior look, autobattler truth. The existing sim/renderer separation invariant
   is load-bearing and survives unchanged.
6. **The director pattern.** Because a fight is a deterministic event log, the presentation
   layer can read the entire script before playing one frame — it knows where the killing blow
   lands and stages, frames, and paces accordingly (establishing wides, punch-ins, time dilation
   on peaks, fast-forward through filler). This is the riskiest novel piece and the spike's real
   test subject.

The 2D harnesses (dual-layer deck combat, backpack comparator) remain mechanics test-beds; this
direction governs presentation only and does not decide the build-surface comparison this branch
exists to run.

## KM-DIRECTOR-SPIKE — money-shot director spike

A throwaway Godot 4.6 scene proving two things at once: (a) Godot delivers the cinematic
city-fight feel (engine exit-test), and (b) the **log → director → spectacle** pipeline works.
Roughly 25 seconds of watchable fight, judged as a money shot.

### Components

1. **Fight log (data, hand-authored).** JSON, ~15–20 events over ~25s: spawn, advance, beam
   fire, ballistic burst, hits, misses, one blocked shot, one overkill kill. Schema shaped like
   a plausible future sim contract — `{tick, actor, kind, payload}` with coarse stage positions —
   because documenting that contract is a spike output. The log is fake; its shape is real.
2. **Stage (scene).** Night city block: grey-box instanced buildings, ground plane, volumetric
   fog, practical lights, skybox. Two block-out mechs with crude articulation (separate
   torso/arms/legs so recoil, look-at, and weight read). No production assets; mood and motion
   carry the verdict. Optionally one real textured part from the art team to calibrate the
   material/post stack, kept off the critical path.
3. **Director (GDScript).** Reads the full log up front and builds a shot list mapping events to
   staging and camera grammar: establishing wide → low-angle dolly on the approach →
   over-shoulder on first exchange → punch-in + time dilation on the kill. Playback synced to
   log ticks via a tick→seconds scale.
4. **Garnish layer (VFX + audio).** Beams (emissive + volumetric light + impact flash), cosmetic
   tracers with ricochet sparks off buildings, multi-stage kill explosion (flash, fireball,
   smoke column, shockwave, debris), camera shake and hitstop, bloom/grade post stack. Minimal
   placeholder audio — beam crack, explosion boom, one music sting — because intensity without
   sound is untestable. Garnish never affects outcomes.

### Pass criteria (written before anyone watches)

1. Scale reads: mechs feel giant against the city.
2. The beam exchange produces an involuntary reaction from at least one viewer who didn't
   build it.
3. The kill moment lands with the camera treatment.
4. Stable 60 fps on a mid-range PC.
5. Verdict is rendered on the shot as graded — no "imagine it with better assets."

Judges: owner, art team, one cold viewer.

### Deliverables

- Runnable Godot scene.
- Captured video of the full shot.
- The assumed sim event contract (the log schema), written up for the future spatial-sim design.
- A verdict note recording pass/fail per criterion and the engine decision consequence.

### Non-goals

No real sim, no kitbash/build system, no UI beyond the fight view, no networking, no production
art, no economy. The spike answers feel and pipeline questions only.

## Routing (flagged, not silently changed)

- **No-3D rule** (CLAUDE.md "Agents should not", High Level Spec): needs revision via
  `vouse-routing-changes` — 3D becomes the presentation direction; the prohibition should narrow
  to "no engine-physics-authoritative combat" rather than "no 3D".
- **Mobile-app-compatible second target** (CLAUDE.md, High Level Spec): dropped per owner
  decision 2026-06-12; PC (Steam) first and only for the current horizon. Needs routing.
- **Stack ADR** (`docs/adrs/2026-06-06-build-stack-decision.md`): was provisional pending a
  confirmation spike. KM-DIRECTOR-SPIKE absorbs/supersedes the ready slice spec
  `docs/slices/KM-STACK-SPIKE-godot-platform-confirmation.md` — do not run both; reconcile the
  old spike spec when KM-DIRECTOR-SPIKE is specced as a slice.
- **Wishlist/journeys**: the watch step's spectacle framing (this spec, decision 1) should feed
  the next wishlist revision rather than be patched in now.
