# Handoff — KM-DIRECTOR-SPIKE executed, three combat-viewer variations (2026-06-13)

Pause point after an **execution** session: the 9-task KM-DIRECTOR-SPIKE plan from the
2026-06-12 handoff was run end-to-end via orchestrated subagents, extended (owner-requested)
with a director-variant system, and **three watchable viewer variations now exist, committed
and pushed**. Judging has NOT happened. Read the prior handoff
(`agent-handoffs/handoff-2026-06-12-cinematic-3d-combat-direction-and-director-spike.md`)
for the design rationale; read this for what now exists and how to resume.

---

## 1. The one-paragraph state

The owner chose orchestrated execution ("orchestrate the combat system as much as you can")
and asked for **3 variations of the combat viewer**. The full spike was built per plan —
fight log + validated loader, shot-list builder (TDD), procedural night city, articulated
block-out mechs, director runtime, VFX garnish, synthesized audio, FPS/fade instrumentation —
then refactored so the director grammar is swappable via `--director=<name>`, and two
additional grammars were built in parallel. All headless suites are green, all work is
committed on `backpack-system-test` and **pushed to origin** (owner instruction, for remote
testing). Three full movies were rendered locally and screenshots delivered to the owner.
`VERDICT.md` is still the empty template: feel iteration is partially done (known issues
below), judges have not been convened, and no canon routing has happened.

---

## 2. What exists now

### The three viewer variations (the session deliverable)

| # | Variant | Run command (from repo root) | Grammar |
|---|---|---|---|
| 1 | **Cinematic** (the plan's) | `godot --path godot_director_spike` (default) | wide → dolly/two-shot → over-shoulder → punch-in on block → 0.25× killcam → wreck orbit |
| 2 | **Ground Witness** | `godot --path godot_director_spike -- --director=witness` | documentary cam at human height (1.7–2.5 m) inside the battle; handheld sway (layered sines, shake-driven); scramble-to-cover beats; locked-off `kill_gaze` slow-mo; ground push-in aftermath |
| 3 | **Combat Broadcast** | `godot --path godot_director_spike -- --director=broadcast` | telephoto long-lens (FOV 16) + drone orbits + hard snap cut-ins per exchange; signature `bullet_time` kill: 0.07× time over a 270° wall-clock camera arc; aerial pullback |

Each run plays the whole fight (~40–47 s wall), fades, prints `FPS min/p5/avg`, exits itself.
Movie capture: `godot --path godot_director_spike --write-movie tmp/out.avi -- --director=<name>`.

### Architecture of the variant system

- `scripts/director.gd` — base class: static `build_shot_list(events, dur)` + runtime
  (clock, event dispatch to actors, shot switching incl. `Engine.time_scale`, camera posing).
- `scripts/directors/<name>.gd` — variants extend the base and override `build_shot_list`
  and `_update_camera` only. Subclass **static** override dispatch via the loaded script
  resource was probe-verified to work in Godot 4.6.3.
- `main.gd` parses `--director=<name>` from user args (default `cinematic`), errors loudly
  on unknown names. Variants share log/stage/actors/garnish/audio untouched.
- Contract every variant must keep: shot list contiguous 0→dur, every `t1 > t0`, exactly one
  sub-1.0 `time_scale` shot and it spans the lethal beam (tick 230 → t=23.0); never touch
  `Engine.time_scale` directly (the base shot-switcher owns it).
- Tests: `tests/director_check.gd` (40 checks, base + cinematic-identity),
  `tests/witness_check.gd` (14), `tests/broadcast_check.gd` (30). All green at handoff.
  Pattern: `godot --headless --path godot_director_spike --script res://tests/<file>.gd`.

### Commits (all on `backpack-system-test`, pushed to origin)

`2e33530` scaffold → `90cdad6` fight log/loader → `300f48d` shot-list builder →
`9835790` night city → `e176379` mech actors → `f0d5679` director runtime →
`818794b` garnish → `48dfb0e` audio → `d39c895` instrumentation/contract/verdict →
`2a4028e` variant loader → `912a878` witness variant → `adaa5ed` broadcast variant →
`a7fe3af` fix: kill explosion at the destroyed mech (a bug in the plan itself, caught by
the spec-compliance review pass).

### Deviations from the plan (all recorded, all reviewed)

- Explicit type annotations where Godot 4.6.3 inference fails (`.duplicate()`/Variant returns).
- `city_builder.gd` lighting tuned brighter than plan values (fog 0.025→0.01, lamps 3→15
  energy / 22→35 range, ambient 0.3→1.0, moon 0.5→1.5, windows 2→5) — plan values read as murk.
- `--still` mode repositions the camera (still-only) and writes `tmp/still_<director>.png`.
- `spike_audio.gd` lambda-in-call syntax from the plan does not parse in 4.6.3; restructured
  into named generator locals, logic identical. (The plan also had a stray paren in `wire()`.)
- Task 9's movie-capture step was done by the controller, not the implementer.
- Plan bug fixed post-review: `garnish.gd` `"destroyed"` → explosion now at `shooter`
  (= `e.actor`, the destroyed mech), was `target` (the survivor).

### Local-only artifacts (gitignored `godot_director_spike/tmp/`, NOT pushed)

`money-shot-cinematic.avi` (39.5 s), `money-shot-witness.avi` (40.5 s),
`money-shot-broadcast.avi` (45.4 s), per-variant contact sheets (`sheet_*.png`) and hero
frames (`hero_*.png`). Screenshots were delivered to the owner in-session. A remote machine
re-renders its own.

---

## 3. Evidence toward the pass criteria (NOT a verdict)

- **Criterion 4 (60 fps mid PC):** live windowed runs on this dev box (RTX 5070 Ti, 1080p,
  Forward+): `p5 ≈ 43–55, avg ≈ 57–58` across variants. `min=1` is a startup/shader-compile
  sampling artifact — quote p5/avg. Movie-mode FPS lines are offline-render numbers and are
  **not valid** for this criterion. A genuinely mid-range PC has not been tested; the owner
  pushed the branch specifically to test remotely.
- **Criteria 1–3 + 5 (scale, involuntary reaction, kill lands, as-is):** require human judges.
  Frame-level observations for the judging session:
  - **Witness** has the strongest giant-scale read (criterion 1) — mechs loom from street level.
  - **Broadcast** has the cleanest fight legibility and the strongest demonstration of the
    pre-read director pattern (the camera is already arcing before the lethal beam lands).
  - **Cinematic** has the most varied coverage but its warm close-ups flatten the block-out
    mechs, and its kill treatment currently reads weakest of the three.

### Known feel issues (iterate before convening judges; criteria are not renegotiable)

1. Cinematic: transient bad frame at ~t=12 s — a filler `two_shot` clips a building.
2. All three end too dark: aftermath/orbit/pullback shots land in smoke + the 2 s fade.
3. Cinematic killcam framing is the weakest kill of the three grammars.
4. Tuning knobs: camera constants in `director.gd` / variant files, VFX scale in `garnish.gd`.

---

## 4. Pending (unchanged from 2026-06-12 handoff unless noted)

- **`VERDICT.md`** (`godot_director_spike/VERDICT.md`): empty template. Convene owner +
  art team + one cold viewer; grade as-is; record FPS evidence; pick the outcome box
  (Godot confirmed vs Unreal re-opens).
- **Canon routing** still not applied: no-3D rule narrowing, mobile-target drop, stack-ADR
  supersession of `docs/slices/KM-STACK-SPIKE-godot-platform-confirmation.md`, wishlist
  spectacle framing — all via `vouse-routing-changes` per the design spec's Routing section.
- **Backpack-vs-dual-layer comparison** (this branch's original purpose) still has no
  recorded verdict (`Research/Research Documents/test-brief-2026-06-08-comparable-backpack-system.md`).
- New since last handoff: the **director-pattern observations** section of VERDICT.md now has
  real material — three grammars over one log is direct evidence the log→director pipeline
  generalizes; the bullet-time shot is the cleanest single proof.
- This handoff file itself is uncommitted (standing rule: no commits without instruction;
  the execution-mode sanction covered the plan's commits, which are done).

---

## 5. Environment facts

- Godot 4.6.3 on PATH as `godot`. Local Godot docs mirror:
  `G:\My Drive\Vault_2_0\Knowledge\Tech\Godot` (classes/, tutorials/).
- `godot_spike/` is the separate GL-Compatibility deploy slice — still do not touch it.
- Remote testing: owner had the branch pushed to
  `git@github.com:yankeeangelonero-hub/Gundamu-War.git`; clone → one-time
  `godot --headless --path godot_director_spike --import` → run commands in §2.
- Transient WASAPI `init_output_device` errors appear when two Godot instances run
  concurrently (audio device contention); the engine falls back to the dummy driver and the
  run is otherwise fine. Environmental, not a code bug.
- ffmpeg 8.1.1 is installed (used for contact sheets / frame extraction from the AVIs).

## 6. How to resume

1. Feel-iterate the known issues in §3 (constants only; re-render, re-extract frames).
2. Owner picks a favourite grammar (or a blend — e.g. witness scale shots inside cinematic
   coverage; that is a new variant file, ~200 lines, the pattern is established).
3. Render the judging cut of the chosen variant, convene judges, fill `VERDICT.md`.
4. Route the outcome per §4 (stack ADR, canon changes, old spike spec supersession).
