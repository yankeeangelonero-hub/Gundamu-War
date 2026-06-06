# Build Stack for Rigged 2D + Relationship + War-Front Layers — Decision Spike / ADR

Status: Active — provisional lean to Godot 4.6 + GDScript after reading the 4.6 docs
against the hardened vision. Evidence is now strong enough to lead with Godot; a focused
confirmation spike (§6) remains before it is final.
Created: 2026-06-06
Revised: 2026-06-06 (evidence pass against the local Godot 4.6 docs corpus; vision
hardened to async-PvP endgame; recommendation flipped from web-native lean to Godot lean)
Blocker ID: STACK-ADR-01 (to be registered in the root work map at
docs/pilot-and-war-front-high-level-spec-and-work-map.md)

## 1. Decision needed

Choose the rendering and runtime stack for the real game — one that can show animated
2D sprites and effects with rigged characters whose parts are customizable at runtime
(the kitbash tree), carry a UI-heavy relationship layer, and reach the defining endgame:
a living war where the player's ace fights other real players' stored builds in async PvP.
This decision is kept separate from the simulation-core decision; the core stays a pure,
renderer-agnostic, deterministic module regardless of stack.

## 2. Why this blocks downstream work

The stack determines how the kitbash tree maps onto a 2D rig, how parts swap at runtime,
how attack animations and hit effects are authored, the art pipeline the art handoff
targets, the deploy/playtest-sharing story, whether the existing pure JS sim is reused or
ported, and — newly load-bearing — how the deterministic sim is run server-side to verify
async-PvP results. The duel-watch spec (KM-WATCH) and the rig half of the workshop spec
(KM-WORKSHOP) cannot be written concretely until this is settled. It does not block the
experience-mockup pass, which is stack-agnostic HTML/CSS.

## 3. Current known facts

Repo facts:

- FACT-001 — game-core.js is a pure UMD module (sim, build tree, resolve) with no DOM
  dependency; portable to any stack, but written in JavaScript.
- FACT-002 — The current rig "view" is plain DOM (createElement / innerHTML). There is no
  2D engine, skeletal runtime, or effects system in the repo.
- FACT-003 — The art payload already exists as hard-surface part sprites with an anchor
  map (output/kitbash-approved-0e22-payload/, kb-art-manifest.json: per-part canvas,
  pivot, depth, mirror, exposed child anchors) and FX as flipbook PNG strips
  (fx_beam_muzzle_00..03, fx_hit_spark_00..03, etc.).
- FACT-004 — The mechanics handoff states the art pipeline as: hard-surface kitbash =
  rigid part-swaps + procedural juice; AI makes part/FX sprites, not motion; mech motion =
  authored clips on one skeleton + procedural code; pilot cut-ins a separate Live2D
  candidate.

Vision facts that moved the decision:

- FACT-005 — The defining endgame is async PvP: the player's ace fights other real
  players' stored builds in a persistent contested war. This needs a backend (stored
  builds, matchmaking, result verification), not real-time netcode.
- FACT-006 — Determinism (same build + seed → identical fight) is the enabler of fair,
  verifiable async PvP: the server can re-simulate to verify a client result.

Godot 4.6 capability facts (read from the local 4.6 docs corpus, mirror of
docs.godotengine.org/en/4.6):

- FACT-007 — Godot supports hard-surface cutout rigs natively: a character is a hierarchy
  of Sprite2D nodes (hip → torso → arm …), each child mounted at an adjustable pivot, with
  the animation system able to animate pivots, textures, opacity, color, and to trigger
  particles/shaders/scripts. AnimatedSprite2D allows cel/flipbook frames alongside cutout.
  (tutorials/animation/cutout_animation.md, 2d_skeletons.md.) This maps directly onto the
  kitbash tree and kb-art-manifest; runtime part-swap = swap the child node/texture.
- FACT-008 — Flipbook FX strips map to AnimatedSprite2D / SpriteFrames; GPUParticles2D and
  canvas_item shaders are available for effects.
  (tutorials/2d/particle_systems_2d.md, tutorials/shaders/.)
- FACT-009 — Deterministic RNG is supported: Godot uses the PCG PRNG family;
  RandomNumberGenerator gives per-instance seed + state, and seed() gives "deterministic
  results across runs." (tutorials/math/random_number_generation.md.) A pure
  integer/fixed-point logic sim with a seeded PRNG is therefore reproducible.
- FACT-010 — Since 4.0, --headless runs Godot with no GPU/display and no special server
  binary, suitable for dedicated servers. (tutorials/export/exporting_for_dedicated_servers.md.)
  The same sim code can run headless server-side to verify PvP results.
- FACT-011 — HTTPRequest/HTTPClient are available for REST calls to a backend.
  (tutorials/networking/http_request_class.md.)
- FACT-012 — Web export works (WebAssembly + WebGL 2.0 / Compatibility renderer);
  single-threaded web export is the default since 4.3 and is compatible with itch.io/Poki/
  CrazyGames. (tutorials/export/exporting_for_web.md.)
- FACT-013 — Godot 4 C# projects CANNOT be exported to the web. To keep web playtest
  sharing open, the project must use GDScript, not C#. (tutorials/export/exporting_for_web.md.)
- FACT-014 — Multiple languages are available (GDScript, C#, C/C++ via GDExtension); C++
  GDExtension is the performance escape hatch if a hot path needs it.
  (getting_started/step_by_step/scripting_languages.md.)

Assumptions:

- ASSUMPTION-001 — Web playtest sharing is wanted near-term (lightweight build links) and a
  web client is plausible long-term. If web is firmly never needed, the C# constraint
  (FACT-013) stops mattering.
- ASSUMPTION-002 — The combat sim is a turn/ATB logic sim, not a physics sim, so float
  cross-platform nondeterminism is avoidable by integer/fixed-point logic and a seeded PRNG.

## 4. Options

| Option | Description | What it enables | Main risk |
|---|---|---|---|
| A — Godot 4.6 + GDScript (lean) | Native cutout Sprite2D rig = the kitbash tree; AnimatedSprite2D/particles/shaders for FX; AnimationTree + procedural code for juice; seeded PCG sim ported to deterministic GDScript; --headless for server re-sim verification; HTTPRequest for backend; web + native export. | Native coverage of the central rig/FX requirement and the full PvP-infra requirement (determinism, headless verify, HTTP) in one engine that matches the existing art pipeline. | UI-heavy meta layers less ergonomic than web; web build heavier than a web app; must port the JS sim to GDScript; C# foreclosed if web is kept. |
| B — Web-native (Pixi + skeletal runtime + component UI) | Reuse the JS sim; render rig/effects with PixiJS + DragonBones/Spine/own bone-tree; meta UI in React/Svelte; Node server re-runs the JS sim to verify PvP. | Best meta-UI ergonomics; lightest web sharing; one language (JS) on client and verify-server; reuses game-core.js. | You assemble the rig + skeletal + procedural-juice + FX systems yourself — exactly the part Godot gives natively and the art pipeline already targets. |
| C — Unity (2D) | Sprite Library/Resolver for swappable parts; strong live-service backend ecosystem; mature effects; C#. | Best-in-class swappable-part rigging and live-service tooling. | Heaviest; slow iteration; licensing; poor lightweight web sharing; full sim rewrite to C#; overkill now. |
| D — Phaser + skeletal runtime | Lighter web game framework with a Spine/DragonBones plugin. | Simpler than hand-assembling Pixi; stays web. | Weaker than B for the heavy meta-UI and weaker than A for the action/FX/procedural layer; middle option that wins nothing outright. |

Principle independent of the option: the simulation stays a pure, deterministic,
renderer-agnostic core, and opponent builds are an injected data source (static / designer
/ real-player) behind one interface, so the client simulates any build identically.

## 5. Evaluation criteria

| Criterion | Required? | Why it matters | A (Godot) | B (Web) |
|---|---:|---|---|---|
| Runtime-swappable parts on a hard-surface 2D rig driven by the kitbash tree | Yes | The kitbash concept itself. | Native (cutout Sprite2D tree) | Build it (Pixi + runtime) |
| Reuses/hosts a deterministic sim without weakening determinism | Yes | Determinism is a hard invariant + PvP enabler. | Port to GDScript; seeded PCG (FACT-009) | Reuse JS as-is |
| Server-side re-simulation for PvP verification | Yes (endgame) | Fair, verifiable async PvP. | Native --headless (FACT-010) | Node runs the JS sim |
| Authored clips + procedural juice + flipbook FX | Yes | The watch-with-stakes experience; matches existing art. | Native (FACT-007/008) | Build it |
| Sim ⊥ animation separation | Yes | Skippable/replayable battles. | Yes (sim is pure) | Yes |
| Strong UI for relationship + macro layers | Yes | Those layers are half the game. | Control nodes (workable) | React/Svelte (best) |
| Web playtest sharing | Preferred | Frequent playtest; possible web client. | Yes, GDScript only (FACT-012/013) | Best (native web) |
| Backend/REST for stored builds + matchmaking | Preferred | The endgame. | HTTPRequest (FACT-011) | fetch + Node |
| Matches the existing art pipeline | Preferred | Art already produced as cutout parts + FX strips. | Direct (FACT-003/007) | Adapter work |
| License/cost | Preferred | — | Free/OSS | Free (Spine paid if used) |
| No 3D; no IP | Yes | Project constraints. | Yes | Yes |

## 6. Evidence plan

Evidence status: doc evidence is sufficient to lead with Godot 4.6 + GDScript. Docs prove
*capability*; a focused confirmation spike is still warranted to prove *ergonomics in
practice* before the rendering specs are written. This is no longer an open A-vs-B spike.

Run STACK-ADR-01 as a bounded, throwaway Godot 4.6 (GDScript) spike:

| Step | Action | Output |
|---|---|---|
| 1 | Build a cutout rig from 3–4 of the existing rig_*.png parts, positioned via kb-art-manifest pivots/anchors. | Confirms manifest → cutout pivot mapping. |
| 2 | Swap a part at runtime (e.g. saber → rifle on the hand anchor) driven by a small kitbash-tree structure. | Confirms runtime part-swap ergonomics. |
| 3 | Play one authored attack clip + one flipbook FX strip (fx_saber_blade / fx_hit_spark) with a little procedural juice. | Confirms the animation + FX + juice pipeline. |
| 4 | Drive the scene from a canned deterministic event list and a seeded RandomNumberGenerator; run the same script with --headless and diff the result. | Confirms determinism + headless server-verify parity. |
| 5 | Single-threaded web export of the spike. | Confirms web playtest-sharing build. |

Keep it throwaway. Do not productionize without explicit approval.

## 7. Recommendation

Recommendation: Decide now to build on Godot 4.6 + GDScript (provisional pending the §6
confirmation spike). Keep the simulation a pure, deterministic, renderer-agnostic core.
Confidence: high that Godot covers every load-bearing requirement natively; medium-high on
the overall choice pending the spike's ergonomics check; high that, if Godot, the language
must be GDScript (C# forecloses web export, FACT-013).

Why this flips my earlier web-native lean: the vision hardened in two ways that web-native
no longer answers best. First, the experience now centers on a rich animated rigged-2D +
FX + procedural-juice combat layer that matches the already-produced cutout art pipeline —
Godot gives that natively (FACT-007/008) where web-native means assembling Pixi + a
skeletal runtime yourself. Second, the endgame is async PvP whose fairness rests on
deterministic re-simulation server-side — Godot does this natively with seeded PCG RNG and
--headless (FACT-009/010), and HTTPRequest covers the backend (FACT-011). Web-native's two
real advantages — best meta-UI ergonomics and lightest web sharing — remain true but no
longer outweigh native coverage of the harder requirements, especially since Godot also
exports to the web (GDScript) (FACT-012).

Costs accepted: porting the small game-core.js to a deterministic GDScript core (tractable,
and arguably needed for client/server parity anyway); less ergonomic data-heavy UI in
Control nodes than in a web component framework; a heavier web build than a plain web app;
and committing to GDScript over C# to preserve web export (with C++ GDExtension as the perf
escape hatch). None touch a load-bearing requirement.

Fallback: if the §6 spike shows runtime part-swap ergonomics or the data-heavy UI are worse
in practice than the docs imply, fall back to Option B (web-native), reusing game-core.js
directly. Options C and D are not recommended.

## 8. Consequences

Choosing Godot + GDScript unblocks concrete drafting of KM-WATCH and the rig half of
KM-WORKSHOP once the spike confirms ergonomics, and lets the art handoff target a cutout
Sprite2D pipeline with the manifest anchors it already has.

The pure logic/data contracts in the work map — KM-PILOT, KM-DET, KM-GATE, KM-WAR,
KM-GHOST — stay largely stack-independent; only their presentation waits on this. The
existing game-core.js becomes a reference to port, not the shipping core.

New constraints to add to the root spec: (1) the simulation stays a pure, deterministic,
renderer-agnostic core; (2) opponent builds are an injected data source behind one
interface; (3) if Godot is confirmed, the project language is GDScript to preserve web
export. The near-term "no backend" rule stands for the prototype but is explicitly
near-term; the endgame adds a backend the architecture must not preclude.

Risk accepted: a short confirmation spike before rendering specs, and a one-time sim port.

The experience-mockup pass is unaffected and continues in parallel.

## 9. Open questions

- Non-blocking: confirm the §6 spike result before finalizing (ergonomics of manifest-driven
  part-swap and data-heavy Control UI). Owner/build session.
- Non-blocking: confirm web playtest sharing is actually wanted — it is the main reason to
  prefer GDScript over C#. If web is firmly out, C# reopens (but loses web). Owner.
- Non-blocking: where the PvP verify-server runs headless Godot (own host vs managed) —
  a backend/ops question for the endgame, not the near-term renderer. Owner; can wait.
- Resolved by evidence: C# is not viable if web export is wanted (FACT-013) → GDScript.

The ADR is provisional pending the §6 spike, but the lead candidate (Godot 4.6 + GDScript)
is now evidence-backed rather than vibe-based.

## 10. Handoff back to root spec

Register STACK-ADR-01 in docs/pilot-and-war-front-high-level-spec-and-work-map.md (§12 as a
decision now provisionally resolved, §13 as a decision-spike artifact with a confirmation
spike pending). Add the three new constraints from §8 as root invariants/architecture
constraints.

Root blockers resolved: the stack fork is provisionally resolved (Godot 4.6 + GDScript),
pending the §6 confirmation spike.

Artifacts unblocked once the spike confirms: KM-WATCH and the rig half of KM-WORKSHOP, plus
the art-pipeline target (cutout Sprite2D + manifest anchors).

Artifacts independent of this regardless: KM-PILOT, KM-DET, KM-GATE, KM-WAR, KM-GHOST.

## 11. ADR self-check

- [x] §1 states one decision and links it to a parent blocker/artifact ID (STACK-ADR-01).
- [x] §2 explains why downstream specs/plans are blocked.
- [x] §3 separates inspected repo facts, vision facts, doc-grounded Godot facts, and assumptions.
- [x] §4 lists only realistic options.
- [x] §5 defines evaluation criteria and scores the two lead options against them.
- [x] §6 gives a bounded confirmation spike; evidence status is stated honestly.
- [x] §7 gives a recommendation type and confidence level, and explains the reversal.
- [x] §8 states consequences, unblocked work, remaining blockers, and accepted risks.
- [x] §9 marks remaining questions as blocking or non-blocking and records the resolved one.
- [x] §10 hands back to the root spec and names resolved/unresolved blockers.
- [ ] Any unblocked vertical feature spec is now Haiku-buildable — rendering specs stay
  blocked until the confirmation spike returns, which is intended.
- [x] The ADR does not start a feature spec, implementation plan, or code change.
- [x] Godot claims are grounded in the 4.6 docs corpus with cited pages, not memory.
