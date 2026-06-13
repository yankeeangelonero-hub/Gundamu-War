# KM-DIRECTOR-SPIKE verdict — engine exit-test

Judged per the pass criteria in
`Research/Research Documents/design-spec-2026-06-12-cinematic-3d-combat-direction-and-director-spike.md`.
Grade the shot AS-IS. No "imagine it with better assets."

Judges: owner ☑  art team ☐  cold viewer ☐
Artifact judged: the 2026-06-13 iteration set (`tmp/everything.mp4` and the variant/weapon clips).

| # | Criterion | Verdict | Evidence/notes |
|---|---|---|---|
| 1 | Mechs read as giant against the city | ☑ pass | iso scale read + pedestrian-angle ground-shake; full-armour silhouette |
| 2 | Beam exchange got an involuntary reaction from a non-builder | ☑ pass | owner: "pretty insane" |
| 3 | The kill moment lands with the camera treatment | ☑ pass | bullet-time kill-cam on beam / melee cleave / buster finish |
| 4 | Stable 60 fps on a mid PC | ⚠ partial | dev box (RTX 5070 Ti) avg ~190–230; p5 dips to ~42 on the building-fade overdraw — needs the deferred perf pass; mid-PC not yet measured |
| 5 | Graded as-is | ☑ confirmed | grey-box / block-out mechs, no "imagine better assets" |

**Outcome (owner verdict, 2026-06-13):** ☑ **Godot confirmed** — owner: "godot is really good
enough and entertaining enough for this kind of product." The stack ADR's confirmation condition is
met; move `docs/adrs/2026-06-06-build-stack-decision.md` from provisional → confirmed and supersede
the old `docs/slices/KM-STACK-SPIKE-...` spec (routing TODO). Caveat carried forward, not blocking:
criterion 4 — close the building-fade perf cliff and measure on a genuine mid-range PC
(see [[director-spike-deferred-tuning]]).
☐ Fail → Unreal re-opens, Niagara tech-artist seat costed in

**Director-pattern observations** (what the shot-list grammar got right/wrong — feeds the real director design):

_Updated 2026-06-13 after an interactive feel-iteration session. Judges not yet formally convened;
this records what the exploration found. See
`agent-handoffs/handoff-2026-06-13-km-director-iso-hybrid-direction-and-barrage.md`._

- **Owner's emerging direction: iso base + destructible environments + cinematic intercut.** Built
  as the `hybrid` grammar — an orthographic tactical view is the legible backbone, perspective hero
  shots cut in on the beats (opening exchange, mid-fight city-wrecking beam, the kill), then cut
  back to iso. Six grammars now exist (`cinematic`, `witness`, `broadcast`, `blend`, `iso`,
  `hybrid`); the owner converged on `hybrid` as the production direction.
- **One log → six grammars is direct proof the log→director pipeline generalises.** The bullet-time
  kill is the cleanest single proof a pre-read director can pre-stage a beat (camera already arcing
  before the lethal beam lands).
- **Readability vs spectacle was the real tension, and the iso-hybrid resolves it** — the fixed
  ortho backbone gives the player a stable tactical read; the cuts deliver the cinema without losing
  them. This is the spike's main design finding.
- **Occlusion: dissolve, don't dodge.** Repositioning the camera to avoid buildings read as the
  camera "bouncing off" them. Replaced with a see-through pass (lens flies through; occluders
  dissolve via alpha-hash near-clip). Open question: dither can look grainy in freeze-frame.
- **Engine criterion met in practice:** ortho+perspective switching mid-fight, destructible city,
  DOF/letterbox/fog, deterministic log-driven staging, and **p5 155 / avg 217 fps under a
  1,700-round barrage** (12× gunfire). Godot 4.6.3 + GDScript did everything asked. Formal judge
  boxes above still need a convened sitting before the stack ADR condition is ticked closed.
