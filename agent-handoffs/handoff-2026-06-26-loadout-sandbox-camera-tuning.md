# Handoff - Loadout Sandbox Bridge + Melee/Camera Tuning

Date: 2026-06-26  
Branch: `combat-feel-restart`  
Repo: `D:/Claude/Mech Bags`  
Primary commit: `159022b Add loadout combat sandbox and camera tuning`

## What Landed

This session converted the combat viewer from a mostly authored/debug fight into the first crude
loadout-to-fight sandbox slice, while also fixing the immediate melee/camera readability issues.

Main shipped pieces:

- **M0 resolved-loadout scaffold**: `godot_director_spike/data/m0_loadout_kits.json`
  defines pilot wrapper data, three player archetype kits, and opponent ghosts.
- **Deterministic loadout fight generator**:
  `godot_director_spike/scripts/sim/loadout_fight_generator.gd` consumes the future-proof
  resolved-loadout shape and emits v2 truth events from loadout + seed + chaos.
- **Build launcher UI**: `godot_director_spike/scripts/build_launcher.gd` exposes player kit,
  opponent preset, backpack-style kit preview, chaos, and Fight.
- **Spectacle profiler scaffold**:
  `godot_director_spike/scripts/sim/spectacle_profile.gd` profiles baseline/generated fights and
  includes a comparison-floor helper. It is surfaced in the debug panel as a compact metrics readout.
- **Debug archetype tuning**: the `--debug` panel can switch archetype presets, regenerate the
  generated fight, restage, and re-film live.
- **Melee correctness/readability**: melee setup now drives suits into hit range before the strike;
  melee hit VFX/signaling was strengthened.
- **Melee camera variety**: hybrid director now rotates dense melee cut-ins across
  `melee_cut`, `melee_chase`, `melee_profile`, and `melee_high` instead of looping one or two views.
- **Camera duration/speed knobs**: `ShotGrammar` now owns ordinary perspective min/max duration and
  camera speed scale. Current owner-approved defaults are:
  - `os_len = 4.0`
  - `cut_len = 4.0`
  - `camera_min_duration = 1.5`
  - `camera_max_duration = 5.0`
  - `camera_speed_scale = 0.25`
  Bullet-time is exempt from the ordinary min/max duration gate so the kill-cam is not deleted by
  the 1.5s ordinary-shot floor.

## Key Files

- `docs/superpowers/specs/2026-06-26-m0-m1-game-system-bridge-design.md` - owner-decision draft
  connecting the M0 sandbox route to the later M1 grid route.
- `docs/art/2026-06-26-3d-modeling-rigging-artist-handoff-package.md` - art/rigging handoff package.
- `godot_director_spike/scripts/main.gd` - wires build UI, auto-fight args, debug restage, metrics.
- `godot_director_spike/scripts/directors/hybrid.gd` - shot scheduler, melee camera variants,
  speed-scaled eased camera, bullet-time exemption.
- `godot_director_spike/scripts/director/shot_grammar.gd` - camera timing defaults and framing rows.
- `godot_director_spike/scripts/director.gd` and `mech_actor.gd` - melee approach/contact behavior.
- `godot_director_spike/scripts/garnish.gd` - extra impact/hit signaling.

## How To Run

Godot 4.6.3 Windows paths used in this session:

```powershell
$godot = 'C:\Users\Yanjie\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe'
$godotConsole = 'C:\Users\Yanjie\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe'
```

Build launcher:

```powershell
& $godot --path godot_director_spike -- --director=hybrid --build-ui --armor
```

Auto-run a melee-heavy generated fight:

```powershell
& $godotConsole --headless --path godot_director_spike --quit-after 9000 -- `
  --director=hybrid --build-ui --auto-fight `
  --player-kit=saber_booster_chase --opponent=duelist_ghost `
  --chaos=0.50 --seed=77 --camlog --melee-log
```

Debug tuning bench:

```powershell
& $godot --path godot_director_spike -- --director=hybrid --debug --armor --log=fight_log_everything
```

Important: the live camera sliders are in `--debug`, not the clean `--build-ui` launcher.

## Verification

Before commit `159022b`, these headless checks passed:

- `shot_grammar_check.gd`
- `melee_camera_schedule_check.gd`
- `debug_director_check.gd`
- `hybrid_check.gd`
- `melee_contact_check.gd`
- `loadout_generator_check.gd`
- `build_launcher_check.gd`
- `debug_restage_check.gd`
- `git diff --check`

The final owner camera timing values were visually confirmed by the owner. After the owner asked to
stop extra validation, only a quick shot-list smoke/hash bake was run to confirm bullet-time remained
present and contiguous.

Earlier measured camlog pass on the two-saber fixture showed 16 scheduled shots and all four melee
camera variants in rotation. The camera jerk fix that mattered most was replacing random per-frame
shake with smooth procedural shake and easing/capping same-shot movement.

## Roadmap State After This Handoff

Roadmap has been updated to reflect partial delivery:

- `cf-fireworks`: `in-progress` - profiler/compare scaffold exists; still needs a proper
  candidate-vs-baseline report artifact and acceptance coverage across archetypes.
- `dbg-director`: `in-progress` - live archetype/camera tuning and spectacle summary exist; export
  JSON and full camera/framing metrics HUD remain.
- `m0-sandbox-sim`: `in-progress` - deterministic loadout generator + staging bridge exists; still
  needs acceptance hardening and floor comparison across the archetype matrix.
- `build-picker`: `in-progress` - crude launcher exists; still not the richer backpack-facing build
  surface.
- `dec-m0-m1-bridge`: remains a `decision` node pending owner review. Do not graft it into the
  dependency tree until approved.

## Known Gaps / Next Work

1. **Profiler report artifact** - turn `SpectacleProfile.compare()` into an explicit candidate vs
   baseline report for each archetype/opponent pair, with pass/fail output saved or shown.
2. **Debug panel export** - the debug director does not yet export tuned grammar/loadout config to
   JSON.
3. **Camera metrics HUD** - spectacle summary exists, but real per-frame camera jerk/frustum metrics
   are not yet surfaced live in the UI.
4. **Build UI camera controls** - camera sliders are only in debug mode. The clean launcher uses the
   baked defaults.
5. **M0 balance is intentionally fake** - generator is deterministic and useful for spectacle, but
   it is not final combat balance.
6. **M1 grid is still separate** - the current build preview is a kit preview, not draggable grid
   placement/economy.
7. **Local untracked files** - `.codex/` and root `AGENTS.md` are still untracked and were left out
   of commits on purpose.

## Push Context

At the time this handoff was written, branch `combat-feel-restart` was ahead of
`origin/combat-feel-restart` by 3 commits before the handoff/roadmap follow-up commit.
