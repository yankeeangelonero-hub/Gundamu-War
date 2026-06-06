---
project: kitbash-mecha
repo: gundamu-war
spec_id: KM-STACK-SPIKE
doc_type: slice-spec
status: ready-for-implementation-spike
version: "0.4"
created: 2026-06-06
updated: 2026-06-06
owner_decision: "Steam PC first, mobile-app compatible second, web optional"
parent_spec: docs/pilot-and-war-front-high-level-spec-and-work-map.md
stack_adr: docs/adrs/2026-06-06-build-stack-decision.md
---

# KM-STACK-SPIKE — Godot Platform Confirmation Slice

## 0. Parent change proposals

None. This slice implements the parent platform decision: Godot 4.6 + GDScript, Steam PC primary, mobile-app compatible secondary, optional web demos/playtests.

## 1. Purpose

Build a bounded, throwaway Godot 4.6 + GDScript spike that proves the chosen stack can carry Kitbash Mecha's load-bearing requirements before the larger v0.4 port begins.

This is not the deploy-decision game slice. It is the platform proof that unblocks it.

## 2. Product target confirmed

- Primary release target: Steam PC / desktop.
- Secondary release target: mobile app compatibility.
- Optional: web export for demos/playtests only.
- Not web-first. Do not optimize the architecture around browser constraints.

## 3. Scope

### In scope

1. Create a small Godot 4.6 GDScript project under `godot_spike/`.
2. Import a minimal subset of existing art from `output/kitbash-approved-0e22-payload/`.
3. Build a hard-surface cutout rig from 3–5 parts using `Sprite2D` / `Node2D` hierarchy.
4. Position parts from a small manifest-derived data file or hardcoded extracted anchors.
5. Swap one mounted part at runtime, e.g. saber ↔ rifle.
6. Play one authored attack animation and one flipbook FX sequence.
7. Drive the animation from a canned deterministic event list.
8. Implement a tiny deterministic GDScript sim/check script that writes a byte-stable event log from fixed inputs + seed.
9. Run the same deterministic check in normal/editor mode and `--headless`, then compare outputs.
10. Smoke desktop/Steam-PC viability: runnable project or Windows export if export templates are available.
11. Smoke mobile compatibility: touch-target/layout check in Godot, Android export if templates/device are available, otherwise document the exact blocker.
12. Optional: web export if cheap; it is not a blocking acceptance gate.

### Out of scope

- Full `prototype/game-core.js` port.
- KM-DEPLOY gameplay.
- Pilot record, growth, fit/sync model, or war-state implementation.
- Real backend or networking.
- Production art cleanup.
- Full Steam packaging.
- App store packaging.
- Polished UI theme.
- Multiple enemies or full ATB simulator.
- Any licensed Gundam IP motifs or new trademark-adjacent art.

## 4. May touch / must not touch

### May touch

- Create: `godot_spike/`
- Create: `godot_spike/project.godot`
- Create: `godot_spike/scenes/`
- Create: `godot_spike/scripts/`
- Create: `godot_spike/data/`
- Create: `godot_spike/tests/`
- Create: `agent-handoffs/claude-godot-km-stack-spike-report.md`
- Read/copy assets from: `output/kitbash-approved-0e22-payload/`
- Read only: `prototype/game-core.js` for deterministic-sim reference patterns

### Must not touch

- `prototype/` implementation files
- Root product docs except the final report if explicitly requested
- Existing v0.1/v0.2/v0.3 historical docs
- Any file outside `D:/Claude/Mech Bags` except Godot editor/export-cache output
- Any Hermes profile/skills/memory files

### Escalate if touching

- Production architecture outside `godot_spike/`
- Full sim-core port
- New art-generation pipeline
- Backend/networking code
- Any change requiring C# or GDExtension

## 5. Required implementation shape

The spike should be intentionally small and inspectable.

Suggested files:

```text
godot_spike/
  project.godot
  scenes/
    Main.tscn
    RigSpike.tscn
  scripts/
    main.gd
    rig_spike.gd
    deterministic_check.gd
  data/
    spike_parts.json
    canned_events.json
  tests/
    expected_events.json
  assets/
    rig_frame.png
    rig_torso.png
    rig_forearm.png
    rig_saber.png
    rig_rifle.png
    fx_saber_blade_00.png
    fx_saber_blade_01.png
    fx_saber_blade_02.png
    fx_saber_blade_03.png
    fx_hit_spark_00.png
    fx_hit_spark_01.png
    fx_hit_spark_02.png
    fx_hit_spark_03.png
```

Asset names can vary if Godot import creates `.import` files, but the final report must list the exact files created.

## 6. Behaviour requirements

### Rig proof

- A visible mech rig appears in the main scene.
- The rig is assembled as a node hierarchy, not one flat image.
- At least one child part moves when its parent moves.
- A button or key toggles one hand/weapon part between two textures/nodes.
- The swap is driven by data or a single clearly isolated function, not duplicated scene hacks.

### Animation + FX proof

- One authored attack animation plays from the rig.
- One flipbook FX sequence plays at the source or target anchor.
- Only one primary attack animation plays at a time.
- Animation playback reads a canned event with at least `{t, source, target, clip}` fields.

### Determinism proof

- `deterministic_check.gd` writes an event log from fixed inputs and seed.
- Running the check twice produces byte-identical JSON.
- Running under `--headless` produces the same JSON as normal/editor mode.
- The deterministic check uses integer/fixed-point style logic. Do not depend on `_process(delta)`, physics, animation timing, or frame rate.

### Desktop proof

- The project opens and runs in Godot 4.6.
- If export templates are installed, produce a Windows desktop export or document the exact export command/settings used.
- If export templates are not installed, document the blocker and provide the run command used instead.

### Mobile compatibility proof

- The spike scene includes a touch-friendly UI path: large button(s), no hover-only controls, and readable layout in a narrow/mobile-sized viewport.
- If Android export templates and environment are available, attempt an Android export.
- If not available, do not fake it; document the missing prerequisite and include a viewport/mobile-layout smoke screenshot or written observation.

### Optional web proof

- Attempt only if cheap after the above passes.
- Failure does not fail the slice unless it exposes a deeper Godot project problem.

## 7. Acceptance checks

The slice is accepted when all required checks below are satisfied:

1. `godot_spike/` exists and is a minimal Godot 4.6 GDScript project.
2. The main scene displays a modular cutout mech rig built from multiple parts.
3. Runtime part swap works for at least one weapon/hand part.
4. One attack animation plus one FX flipbook plays from a canned event.
5. The deterministic check writes byte-identical JSON for repeated runs from the same seed.
6. The deterministic check also passes under `--headless` or the report records a concrete environment blocker.
7. Desktop/Steam-PC viability is smoked through a runnable project or Windows export.
8. Mobile compatibility is smoked through touch-friendly UI/layout and, if possible, Android export.
9. Web export is marked optional and does not block acceptance.
10. Final report explains whether Godot remains approved, approved-with-caveats, or should be re-opened.

## 8. Suggested verification commands

The implementing agent must first discover the Godot executable name on this machine. Try, in order:

```bash
godot --version
godot4 --version
Godot_v4.6-stable_win64.exe --version
```

If no Godot executable exists, stop and report the missing prerequisite. Do not invent results.

Example commands once executable is known; replace `$GODOT` with the working executable:

```bash
$GODOT --version
$GODOT --headless --path godot_spike --script res://scripts/deterministic_check.gd -- --out user://events_headless.json
$GODOT --path godot_spike --script res://scripts/deterministic_check.gd -- --out user://events_normal.json
```

If writing to `user://` makes diffing awkward, write to a repo-local ignored `godot_spike/tmp/` folder instead.

Expected determinism result:

```text
PASS deterministic event log identical
```

Desktop export command depends on installed templates and presets. If templates are not installed, the report must say so and provide the editor/run smoke result instead.

## 9. Final report requirements

Create `agent-handoffs/claude-godot-km-stack-spike-report.md` with:

- Godot executable/version used.
- Files created/modified.
- Assets imported.
- Rig hierarchy summary.
- Runtime swap tested.
- Animation/FX tested.
- Determinism commands and outputs.
- Headless result.
- Desktop export/run result.
- Mobile compatibility result.
- Optional web result, if attempted.
- Problems found.
- Recommendation: continue with Godot, continue with caveats, or re-open stack decision.

## 10. Implementation-agent instruction

Use the prompt at `agent-handoffs/claude-godot-km-stack-spike-prompt.md` when dispatching Claude Code. The prompt is self-contained and should be sent from the repo root `D:/Claude/Mech Bags`.
