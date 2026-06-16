# Director Grammar — Phase 3, Slice 4: Compression (F31) — completes Phase 3

> Status: PROPOSED plan, 2026-06-16. The LAST behaviour of the spec's build-sequence step 3
> (`compression, impact_frames + arbiter, staggered_blast / yield_by_class`) — the other two shipped
> in Slices 1–2. After this, Phase 3 (new behaviours) is complete; Phase 4 = continuity.
> Design: spec Lens § (F31). Determinism gate: shot-list hash `2543717900` unchanged.

## Goal
**Compression (F31):** a continuous long-lens dial. On a chosen beat the camera drops to a **low FOV**
and **pulls back** proportionally so the subject keeps its screen size while the perspective flattens
— foreground and background mechs read at similar size (the looming "graphic-plane" telephoto look).
Owner decision: apply a **moderate compression (0.5) to `hero_cut`** (the low city-wrecking beam
beat); every other mode stays at 0 (today's look unchanged).

## What exists today (grounded)
`hybrid.gd _update_camera`: the perspective `match s.mode` block sets `pos`, `aim`, `fov` per mode;
then (`:162-169`) `camera.fov = fov`, `pos = _resolve_occlusion(pos, aim)`, shake, `camera.position
= pos`. The `iso` path returns earlier (`:108`), so the match is perspective-cuts only. FOVs are
already lifted into the framing table (Phase 1).

## Design
A per-mode compression value (0 = no compression). After the match sets `pos/aim/fov` and **before**
`camera.fov = fov`, apply:
- `comp_fov = lerp(fov, fov * compression_fov_floor, c)` — lower the FOV toward a floor.
- `keep = tan(fov/2) / tan(comp_fov/2)` — the distance multiplier that holds the subject's screen
  size as the FOV narrows.
- `pos = aim + (pos - aim) * keep` — pull the lens back along the view direction.
- `fov = comp_fov`.
At `c=0` (every mode but hero_cut) the block is skipped → byte-identical to today. At hero_cut `c=0.5`,
floor `0.5`: `comp_fov = lerp(46, 23, 0.5) = 34.5°`, `keep ≈ 1.37` → a moderate flattening loom.

Determinism: this only changes the runtime camera `pos`/`fov` (presentation); the shot LIST is
untouched → hash `2543717900` holds.

## Files
- **Modify** `scripts/director/shot_grammar.gd` — add a Lens block:
  `compression_by_mode: Dictionary = {"hero_cut": 0.5}` and `compression_fov_floor: float = 0.5`.
  Assert defaults in `shot_grammar_check.gd`.
- **Modify** `scripts/directors/hybrid.gd` — insert the compression block right after the perspective
  `match` (after `:161`, before `camera.fov = fov` at `:162`), reading `_grammar.compression_by_mode`
  / `_grammar.compression_fov_floor`.

## Tasks
- **C.1** — grammar params (`compression_by_mode`, `compression_fov_floor`) + assert defaults
  (incl. `compression_by_mode.get("hero_cut") == 0.5` and unmapped mode → 0.0). TDD headless.
- **C.2** — apply compression in `hybrid.gd _update_camera` (FOV drop + pull-back-to-keep-size).
  Boot smoke + the golden hash unchanged (compression is runtime camera only).
- **C.3** — regression (all suites + hash) + windowed `--frames` capture on `fight_log_everything`:
  the hero_cut beam beat should read flatter/loomier (mechs + city stacked), other beats unchanged.
  Review.

## Open owner decision (surface, don't block)
- `0.5` strength + `0.5` FOV floor are starting values; the S=hero_cut loom is tuned from the C.3
  capture. If too strong/weak, adjust `compression_by_mode["hero_cut"]` (and/or the floor).

## Execution method
Subagent-driven (implementer → spec review → quality review), standard guardrails.
