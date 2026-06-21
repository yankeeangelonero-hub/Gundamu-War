# Debug Director — live feel-tuning bench (design spec)

Date: 2026-06-22. Author: this session. Status: DRAFT for review.
Branch context: `combat-feel-restart` (builds on commit `de2f7df`).

## 1. Goal

An in-viewer **debug/authoring panel** to tune the full suite of handles we've exposed —
*live*, against a running fight, with immediate visible impact. Two domains in one tool:

- **Cinematic feel** — the camera grammar (`ShotGrammar`), the per-mech `FeelProfile`
  (heft/tempo), the choreographer constants, and which cinematic shot types are enabled.
- **Gameplay feel** — per-mech HP, weapon attack speed (cadence), and damage.

Drop in different mech presets, change any value, watch the fight re-film. This is a
**debug-only** tool (behind a flag), not shipped UI. It exists so feel/balance is *tuned by
hand and measured*, not guessed — the same discipline as `--camlog`.

## 2. The load-bearing decision: where does the fight come from?

Today every fight is a **hand-authored truth log** (e.g. `_render_contrast2.gd` builds the
`truth` array literally). Tuning *HP / attack-speed / weapons* and seeing the fight change
therefore requires **generating** a truth log from build parameters.

So the debug director needs a **parametric fight generator**:

```
generate(buildA, buildB, seed) -> contract-valid truth log
  buildX = { weapons:[{motif,tier,travel,damage}], hp, attack_speed_ticks, feel }
```

Deterministic: same builds + seed → identical log. It alternates each mech's weapon fire on
its `attack_speed` cadence, applies damage, and ends on the lethal blow when an HP pool is
emptied. **It is an explicit STAND-IN, not the real sim** — no balance, no PoE algebra, no
power economy. But it is architected behind the same `{builds, seed} -> log` seam that
`m0-sandbox-sim` will fill, so it de-risks M0 rather than competing with it.

> DECISION TO CONFIRM: build the parametric generator (needed for HP/attack-speed tuning), vs.
> a weaker tool that only re-films a fixed authored log with presentation tweaks. The request
> ("tune HP / attack speed and see impact") requires the generator. Recommended: build it,
> clearly labelled non-authoritative, as the seed of M0.

## 3. Two update tiers (the cheap path stays cheap)

- **Tier 1 — Presentation tune (instant, no truth change):** camera grammar, feel
  (heft/tempo), enabled shot modes, choreographer overrides → re-`stage(truth)` + rebuild shot
  list + re-film the **same** truth. Cheap; this is most knobs.
- **Tier 2 — Gameplay tune (full rebuild):** HP / attack-speed / weapons / damage →
  `generate()` a new truth → stage → film.

A **Replay ▷** restarts the current fight; a **Live** toggle re-films on every Tier-1 change
and on slider-release for Tier-2. Presentation tuning provably never alters the truth log
(preserves the sim/render separation — INV the project already holds).

## 4. What is live-mutable vs not (architectural reality)

| Handle group | Where | Live-mutable? | How the panel tunes it |
|---|---|---|---|
| Camera/render params | `ShotGrammar` (`@export` Resource) | **Yes** | bind slider → live grammar field → re-film |
| Feel body curves | `ShotGrammar.feel` dict | **Yes** | same |
| Per-mech heft/tempo | `feel_profiles` arg | **Yes** | rebuild profiles → re-stage |
| Preset (archetype) | `grammar_presets.json` | **Yes** | dropdown → `apply_preset()` → re-stage |
| Choreographer consts (KNOCK/WEAVE/ORBIT_AMP/MOBILE_HEFT/STRAFE_AMP) | `grammar_params.gd` `const` | No (const) — **but** reachable per-build | write into the active build's `overrides:{}` (→ `_param()`) |
| Enabled shot typology | `hybrid.build_shot_list` | needs a small change | pass an `enabled_modes` set; disabled → fall back to `iso` |
| Gameplay (HP/atk-speed/dmg/weapons) | the generator input | **Yes** | rebuild truth (Tier 2) |

Two code prerequisites fall out of this table (both already on the fix list from the codex
review): route `MOBILE_HEFT`/`STRAFE_AMP` through `_param()` so they're overridable, and have
`build_shot_list` honour an enabled-modes set.

## 5. Panel layout (Godot CanvasLayer, behind `--debug`)

Collapsible side panel built from stock Control nodes (HSlider + value label, OptionButton,
CheckBox, SpinBox), grouped:

1. **Pilots A / B** — preset dropdown; `heft`, `tempo` sliders; override sliders
   `KNOCK / WEAVE / ORBIT_AMP / MOBILE_HEFT / STRAFE_AMP`.
2. **Builds A / B (gameplay)** — `HP`, `attack_speed` (ticks between shots), per-weapon rows
   (motif, tier, travel, damage), add/remove weapon. Drives the generator (Tier 2).
3. **Cinematics** — enabled-shot toggles (`iso / hero_os / hero_cut / melee_cut /
   bullet_time`); **min & max camera-shot duration** (`min_iso` + a new max-shot cap); per-mode
   durations (`os_len`, `cut_len`, `melee_cut_pre/post`, `bt_pre/post`, `bt_scale`);
   `dolly_cap`; `melee_radius_factor`; `compression`; framing FOVs; mood/grade toggle.
4. **Playback** — `seed`, Replay, Pause/step, Live toggle; live readout of shape/template +
   the **metrics HUD** (below).
5. **Export** — dump the current grammar + feel + builds to JSON, so a dialed-in config saves
   back into `grammar_presets.json` / a `ShotGrammar` `.tres` / a fight fixture.

## 6. Metrics HUD (ties the tool to the fireworks gate)

Surface the `--camlog`/spectacle metrics live while tuning: camera Δpos/Δaim spikes,
both-mechs-in-frustum %, and a **dead-air / spectacle-floor** read per the `cf-fireworks`
doneWhen. So a value change is judged on numbers, not vibes — this is the fireworks profiler,
surfaced in-tool.

## 7. Invocation & re-film seam

- `godot --path . -- --director=hybrid --debug` opens the panel over the block-out viewer.
- Refactor `main.gd`'s fight-bring-up into a callable `film(truth, grammar, feel_profiles)`
  the panel re-invokes on change (Tier 1) / after `generate()` (Tier 2). No change to the
  shipped pipeline; the panel only rebinds inputs and re-runs.

## 8. Non-goals / boundaries

- Debug-only (behind `--debug`); never part of the shipped build screen.
- The generator is a non-authoritative stand-in (no balance / power / PoE); it must not be
  mistaken for M0. Same `{builds,seed}->log` interface so M0 drops in behind it.
- Presentation tuning must never write the truth log (keeps re-sim verification intact).

## 9. Decomposition (slices)

1. `film()` re-bring-up seam + `--debug` flag + empty panel scaffold.
2. `ShotGrammar` live binding (Tier-1 camera sliders) → re-film.
3. `enabled_modes` in `build_shot_list` + the shot-type toggles.
4. Feel + preset binding (heft/tempo/preset dropdown) → re-stage.
5. Choreographer override sliders (needs the `_param` routing fix).
6. Parametric `generate()` + Builds section (HP / attack-speed / weapons) — Tier 2.
   The generator's purpose is **direct control over spectacle and fight length**: attack-speed
   + weapon count drive event density (spectacle); HP + damage drive duration (length).
7. Metrics HUD (live camlog + dead-air floor).
8. Export config.

Slices 1–4 deliver a usable cinematic-tuning bench; 5–8 add gameplay + measurement + save.

## 10. Roadmap placement

New tooling node — `dbg-director` (feel/balance tuning bench). Not on the critical path, but a
precursor that de-risks `cf-fireworks` (the metrics HUD *is* the profiler, surfaced live) and
`m0-sandbox-sim` (the parametric generator is the seed of `{builds,seed}->log`). Suggest
grafting as a `ready` tooling node feeding both; confirm before grafting.
