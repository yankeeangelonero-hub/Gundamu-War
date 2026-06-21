# Handoff — Combat Choreography Grammar complete + the weight pass

Date: 2026-06-21. Branch: `combat-feel-restart`. Author: this session (Opus).
Prior state: increment 1 (the grammar measurement spine) was committed at `c78af67`.

## What this session delivered

Three blocks of work, all on `combat-feel-restart`, all gate-clean (18 test suites green):

1. **Phase 2 — the full choreography grammar** (`509201c` → `2ec4a84`).
2. **Stub clearing S1–S6** — everything the architecture exposed a seam for (`ab45da8` → `da1158d`).
3. **The weight pass** — grounded weighty motion + per-build weight dials (`ad5f88c` → `7385f67`).

The authoritative design is `docs/superpowers/specs/2026-06-20-choreography-grammar-design.md`
(rev 7, IMPLEMENTATION-READY). Combat-feel north star: `Research/Research Documents/
research-synthesis-2026-06-13-gundam-uc-combat-feel.md` (F1–F10) + `…-2026-06-15-weighty-mecha…`
(F11–F21). The weight pass is grounded in F1 (mass-ramp), F3 (burst-coast), F11 (cadence),
F13 (follow-through).

## The pipeline (who owns what)

```
truth log → choreographer.gd (stage: schedule → exchange → advance beats + presentation hooks)
          → [throwaway shot→fire_* bridge] → director (shot grammar, camera) → mech_actor (render)
```

- **Choreographer** (`scripts/sim/choreographer.gd`) — owns WAYPOINTS + timing + the presentation
  hooks. Pure, deterministic, fully tested. Zero render-layer risk.
- **`mech_actor.gd`** (the proven viewer) — owns HOW a body moves between waypoints: momentum
  integrator, AMBAC, boost flare, footfall, banking, rigged anim.
- **`director.gd` / `directors/hybrid.gd` / `director/shot_grammar.gd`** — camera + shot grammar
  (proven/locked).

## What's live (the handles)

**Exchange / build → feel (all in the choreographer, fully tested):**
- **Four exchange modes** — beam-trade (mid strafe), swarm (stand-off + target weave),
  dodge-pursuit (charge + sustained weave), melee (dash to clash). Each has a contrast metric in
  `grammar_metrics.gd`. The pass-1 `gate_mode` is REMOVED — the selected mode is staged.
- **Mode selection** — `select_mode(mode_mix, weapon_weights, mode_map)`, `score = weight × feel`.
  `data/grammar_mode_map.json` (feel→grammar mode), `data/grammar_motif_weights.json`
  (motif→4-mode weights). A neutral pilot lets the weapon drive the mode; a leaning pilot biases it.
- **FeelProfile** heft/tempo wired into the exchange (`_feel`); archetype presets via
  `data/grammar_presets.json` + `apply_preset()`; const overrides reach the exchange via `_param`.
- **Layer 4** — `presentation()` → side-channel hook block (shape/template, climax_window,
  apparent_initiative, phrase_bounds, lethal_ref, per-beat range_band/is_background, per-actor heft).

**Weight pass (ground-plane only — airborne boost is disabled):**
- **Grounded boost-dash** — `_dash_profile()` = burst-coast-snap (anticipation load-back → thrust
  burst past the mark → settle), heft-scaled. Constants `ANTICIPATE`/`OVERSHOOT`.
- **Mass-ramp (F1)** — `mech_actor.apply_feel(heft)` sets `max_accel = lerp(30,14,heft)`.
- **Committed-held pose (smooth F11)** — `pose_rate = lerp(1.0,0.5,heft)` slows the upper-body
  facing/lean/AMBAC easing for heavy builds (smooth, NEVER stepped). NOTE: a literal snap-stepping
  "on threes" cadence was tried and REVERTED — it reads as a frame-drop glitch in realtime 3D.
- **The heft→render wire** — `presentation()` carries per-actor `{heft,tempo}` in `actors`;
  `main.gd` reads it via `FightLog.load_presentation()` and calls `apply_feel()`. This is what makes
  per-build weight possible at all (it didn't exist before — `main.gd` read only the log).

## The gate harness (never spoils the outcome; all green)

`grammar_*_check.gd` under `tests/`: compose, schedule, stage, prosody, presentation, blind
(CG-BLIND mirror + prefix-blindness), edge (6 shapes), feel, modes, presets, diagnostics, seam,
metrics — plus the unregressed director/shot_grammar/feel_profile suites. CG-NO-PRESPOIL, CG-BLIND,
per-mode contrast, range, determinism all hold. Truth is never edited; sim re-sim verification intact.

## Deferred (the one remaining large piece)

**The v2 director CAMERA cutover.** The director's runtime camera does not yet *consume* the
presentation hooks (climax_window killcam timing, range_band framing). The hooks ride with the log
and `main.gd` reads/prints them and applies the per-actor weight, but the camera still runs its own
logic. Driving the camera from the hooks is gated behind the golden-hash re-baseline (don't bolt it
onto the proven director without that process). So: the BODY-weight side of the cutover is done; the
CAMERA side is not.

Also cosmetic: `PROXEMIC_SCALE` is still an unused constant.

## How to render / test

- **Tests (headless):** `godot --headless -s tests/<name>_check.gd` from the spike root. Test runner
  prints PASS/FAIL + `---- ALL PASS`. Godot 4.6.3 at `~/.local/bin/godot`.
- **Render the new exchange in the proven viewer** via throwaway `shot→fire_*` bridges:
  - `tests/_render_demo.gd` → `data/grammar_demo.json` (single contested duel)
  - `tests/_render_long.gd` → `data/longfight.json` (~200-tick weapon-varied grind, heavy build)
  - `tests/_render_showcase.gd` → `data/showcase_<mode>.json` (one fight per mode)
  - `tests/_render_feel.gd` → heavy/light comparison logs
  Generate: `godot --headless -s tests/_render_<x>.gd`. Watch:
  `godot --path . -- --director=hybrid --log=<name>` (record: add `--write-movie out.avi --fixed-fps 30`).
- **Block models vs rigged:** the user prefers BLOCK-OUT for now (rigged Mixamo anim read as
  distracting). Block-out is the default — `--mesh` enables the rig. Keep `--mesh` OFF.

## Suggested next steps

1. **Camera cutover** — let the director consume the hooks (climax-window timing, range-band
   framing); the golden-hash re-baseline gate applies. Highest-value remaining feel work.
2. **More archetypes / weapons** — pure data rows now (`grammar_presets.json`,
   `grammar_motif_weights.json`). No code.
3. **Tuning** — isolated knobs: `pose_rate` (pose weight), `max_accel` range (momentum),
   `ANTICIPATE`/`OVERSHOOT` (dash), `ORBIT_AMP`/`KNOCK` (strafe/sell).
