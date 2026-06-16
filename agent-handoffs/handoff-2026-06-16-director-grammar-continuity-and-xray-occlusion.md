# Handoff — Director Grammar through Phase 3 + Continuity + X-Ray Occlusion (resume 2026-06-17)

Picks up a long 2026-06-16 session on the `combat-feel-restart` branch. The short version: the
Director Grammar is built through **Phase 3** (all of the spec's "new behaviours" step), the
**screen-side continuity** + **camera-angle search** framing work landed, and the occlusion approach
was reworked twice — the building-FADE was tried, rejected by the owner as inelegant, and **replaced
by an x-ray window shader** (the current, shipping occlusion). Everything below is where to pick up.

## Where the build is
- **Branch:** `combat-feel-restart`, pushed to `origin` — HEAD = `dbd9eac` (origin in sync). This is
  the active combat-feel line; `main` still holds the archived backpack-editor experiment (do not use).
- **Run it (the proven viewer):** `godot --path godot_director_spike -- --director=hybrid --log=fight_log_everything --armor`
  (windowed). Headless logic + determinism: `godot --headless --path godot_director_spike -s res://tests/<name>.gd`.
- **Godot 4.6.3**, GDScript + one spatial shader. Godot on PATH as `godot` (also `~/.local/bin/godot.cmd`).
- **GOTCHA — stale class cache:** a brand-new `class_name` (or .gdshader first use) needs one
  `godot --headless --path godot_director_spike --import` pass before the engine registers it. If the
  engine reports "Could not find type X" / a script that declares `var _x: X` fails to parse, that's
  the stale cache — run `--import` once, re-run. (This bit us twice; it is NOT a missing file.)

## The invariant that gates everything
The combat sim is pure/deterministic; the hybrid shot list is frozen by a golden hash. **Every camera/
render change must keep `tests/hybrid_check.gd` printing `got hash 2543717900`.** All the work below is
presentation-only (camera pose, shot timing values lifted at identical defaults, GPU shader) and holds
that hash. If the hash moves, something leaked into the deterministic path — stop and find it.

## What shipped this session (≈50 commits)
Built with brainstorm → spec → plan → subagent-driven execution (implementer + spec review + code
review per task). Specs in `docs/superpowers/specs/`, plans in `docs/superpowers/plans/`.

1. **Phase 2 — Grade node (Lighting + Color).** `scripts/director/grade.gd`: chromatic shadow fill
   (F22, with a non-black floor), mood variants base/hero/death (F26/F27, beat-driven wall-clock lerp),
   FX/beam lights re-enabled (F24, incl. ordinary-beam muzzle+impact light). One shared `ShotGrammar`
   instance threaded through shot-gen / director / grade / garnish. (`grade_check.gd`.)
2. **Phase 3 — new behaviours** (the spec's build-step 3, now complete):
   - **Time-emphasis arbiter + impact frames** — `scripts/director/time_emphasis.gd` (pure
     `decide()`), an escalation ladder: minor hit → sub-perceptual impact-frame flash, heavy hit →
     hitstop, kill → bullet-time, mutually exclusive. (`time_emphasis_check.gd`.)
   - **Staggered blast + yield-by-class** — the kill blast is a series scaled by the killing weapon's
     `yield_tier` (capital `fire_buster` = 3-blast chain "fear beat"; sidearm = single).
   - **Compression (F31)** — `hero_cut` drops FOV + pulls back to flatten perspective (looming
     telephoto); `compression_by_mode`/`compression_fov_floor` in the grammar.
   - **Melee framing** — the `melee_cut` timing (pre/post/scale) lifted into the grammar (closed the
     Phase-1 B2 seam).
   - **Bonus fix:** `build_shot_list` arity — `main.gd` called it 3-arg but only hybrid had the
     signature, so the DEFAULT `cinematic` director crashed; all directors now accept the optional grammar.
3. **Section A — ambient ownership.** The Grade/grammar own the full ambient fill (source+color+
   `ambient_energy`); `city_builder` no longer authors ambient.
4. **Screen-side continuity (the 180° rule).** `director.gd _axis_side` + `_axis_keyed_side` (keyed at
   fight start) + `_keyed_lateral`: the `hero_os`/`hero_cut` cut-ins stay on one side of the A↔B axis
   so the two mechs never swap screen sides on a cut. (`continuity_check.gd`.)
5. **Camera-angle search.** `scripts/director/sightline.gd` (pure multi-ray AABB occlusion test) +
   `director.gd _pick_clear_pose` (scores candidate poses by clear-ray count, hysteresis). `melee_cut`
   searches its orbit angle; `hero_os`/`hero_cut` search their keyed-side lateral. Picks a clearer
   framing; bullet_time (kill cam) + iso are untouched. (`sightline_check.gd`.)
6. **Occlusion: the x-ray window (CURRENT approach).** `scripts/shaders/xray_occluder.gdshader` on
   every building + window mesh dissolves a soft hashed-dither window through any wall **along the
   camera→mech sightline** (capsule, not a sphere — a sphere missed mid-distance walls). Fed each
   frame by the director via global shader params (`xray_mech_a/b`, `xray_radius`, `xray_softness`,
   declared in `project.godot [shader_globals]`). It **replaced both old fades** (`_resolve_occlusion`,
   `_fade_building`, `_fade_for_iso` — all deleted). Lit parity (`roughness 0.7`); dead mechs keep
   their window (aftermath frames the wreck); destruction tweens the shader's `albedo` uniform.

## History worth knowing (so you don't redo it)
- The **building-fade occlusion was tried and reverted** — the owner found whole-building fading
  inelegant and the aggressive version "broke the battle choreography." The fade is gone; the x-ray is
  the replacement. Superseded specs: `2026-06-16-sightline-aware-camera-composition-occlusion-design.md`
  (folded into `2026-06-16-continuity-and-sightline-camera-design.md`, whose *fade* half is in turn
  superseded by `2026-06-16-xray-window-occlusion-design.md`). The **continuity + camera-angle-search**
  halves of the continuity spec are still in force.
- The x-ray spec got **one codex review** (verdict needs-rework → fixed): the load-bearing catch was
  the sightline **capsule** vs a mech-sphere; also project-level globals (must exist at shader compile),
  an atomic material swap (the old fade hard-casts `StandardMaterial3D` and would crash on the new
  material), window child-meshes needing the shader, dead-mech windows, and lit parity.
- **Subagents must not run `git checkout`/branch ops** — one stranded the branch on `main` mid-run
  (recovered, no loss). All dispatches now forbid branch-changing git.
- **Global shader params are NOT queryable from a headless `-s` run** (no render server) — a wiring
  unit-test gave false failures and was removed; the x-ray is validated by the render boot (shader
  compiles + feed runs) + the visual.

## Current tuning state / owner's open review
The x-ray is shipping at **`xray_radius = 28`** (in `project.godot [shader_globals]`; 14 was too small
for the city's big walls, 60 over-cleared). The owner is reviewing the build. Known tuning dials, all
no-code:
- **`xray_radius`** (window size) and **`xray_softness` = 5** (edge) in `project.godot` (or the grammar
  `xray_radius`/`xray_softness`, which the director could be wired to drive live — currently it only
  feeds the mech positions; radius/softness use the project-global defaults).
- **The dither look:** the see-through is a **stippled** alpha-hash dissolve (order-independent, no
  sorting). It reads as stipple, not a smooth gradient. If the owner wants it smoother, that trades in
  true transparency (with depth-sorting caveats) or a tighter softness — an open aesthetic call.
- Latest capture frames: `godot_director_spike/tmp/frame_hybrid_*.png` (regenerate with
  `--log=fight_log_melee ... --frames`). frame_07 shows the dither dissolve; frame_11 both mechs reading.

## How to resume / what's next
1. **Owner feedback on the x-ray** (radius / dither / softness) — tune from the capture. If "drive
   radius/softness from the grammar live" is wanted, wire the director to `RenderingServer.global_shader_parameter_set`
   them at `start()` from `_grammar.xray_radius/xray_softness`.
2. **Phase 4 — soft continuity constraints (F32–F36).** The screen-side 180° rule (F33) already
   shipped (item 4); remaining: `establishing_layout` (the iso backbone already is this — formalize),
   `coherence_over_polish` test guard, and `split_screen` (F36, optional). Spec: the Continuity § of
   `2026-06-16-director-grammar-design.md`.
3. **Deferred / parked** (in `2026-06-16-director-grammar-phase3-scope-and-deferred-items.md` + the
   slice specs): the camera-angle-search **iso fallback** (cut to iso when no clear same-side pose —
   deferred as "B2b"); a melee-search **radius/height** extension (the angle-only search can't clear a
   fully boxed-in clash — pulling back/up would); `cockpit_pov` + `frame_and_streak` (Composition shots
   not in the build sequence); the distinct **aftermath** mood (needs a director→Grade signal).
4. **Test suite (all green, hash held):** `shot_grammar_check`, `grade_check`, `time_emphasis_check`,
   `continuity_check`, `sightline_check`, `hybrid_check` (the hash), `director_check`, plus the variant
   `blend/broadcast/iso/witness_check`. Run all before/after any camera change.

## Files map (the new/changed core, all under `godot_director_spike/`)
- `scripts/director/shot_grammar.gd` — the single tunable home (Timing/arbiter, Composition/framing,
  Lighting, Color/moods, Spectacle/yield, Lens/compression+xray, search-arc).
- `scripts/director.gd` — base: axis/keyed-side helpers, `_pick_clear_pose`, `_silhouette_points`, the
  per-frame x-ray global feed. (Fade code deleted.)
- `scripts/directors/hybrid.gd` — the production director: iso backbone + perspective cuts with
  continuity + angle search + compression.
- `scripts/director/grade.gd`, `scripts/director/sightline.gd`, `scripts/director/time_emphasis.gd`.
- `scripts/shaders/xray_occluder.gdshader` + `project.godot [shader_globals]`.
- `scripts/city_builder.gd` (buildings/windows use the x-ray ShaderMaterial), `scripts/garnish.gd`
  (FX lights, staggered blast, destruction tweens the shader albedo).
