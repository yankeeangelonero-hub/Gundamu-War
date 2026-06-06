# Claude Code Prompt — KM-STACK-SPIKE Godot Platform Confirmation

You are implementing a bounded spike in the repo:

`D:/Claude/Mech Bags`

## Goal

Build a small, throwaway Godot 4.6 + GDScript spike under `godot_spike/` that proves the Kitbash Mecha v0.4 stack decision:

- Steam PC first.
- Mobile-app compatible second.
- Web optional for demos/playtests only.
- Godot 4.6 + GDScript lead stack.

This is a platform confirmation spike, not the full game and not KM-DEPLOY.

## Required reading before coding

Read these files first:

1. `docs/slices/KM-STACK-SPIKE-godot-platform-confirmation.md`
2. `docs/adrs/2026-06-06-build-stack-decision.md`
3. `docs/pilot-and-war-front-high-level-spec-and-work-map.md`
4. `High Level Project Specifications.md`
5. `G:/My Drive/Vault_2_0/Knowledge/Tech/Godot/README.md`
6. Relevant Godot docs from the offline corpus as needed:
   - `G:/My Drive/Vault_2_0/Knowledge/Tech/Godot/tutorials/animation/cutout_animation.md`
   - `G:/My Drive/Vault_2_0/Knowledge/Tech/Godot/tutorials/animation/2d_skeletons.md`
   - `G:/My Drive/Vault_2_0/Knowledge/Tech/Godot/classes/class_sprite2d.md`
   - `G:/My Drive/Vault_2_0/Knowledge/Tech/Godot/classes/class_animatedsprite2d.md`
   - `G:/My Drive/Vault_2_0/Knowledge/Tech/Godot/classes/class_randomnumbergenerator.md`
   - `G:/My Drive/Vault_2_0/Knowledge/Tech/Godot/tutorials/export/exporting_for_dedicated_servers.md`
   - `G:/My Drive/Vault_2_0/Knowledge/Tech/Godot/tutorials/export/exporting_for_web.md`

Do not guess Godot 4.6 APIs. Use the local docs.

## May touch

- Create/modify only under `godot_spike/`.
- Create final report: `agent-handoffs/claude-godot-km-stack-spike-report.md`.
- Read/copy assets from `output/kitbash-approved-0e22-payload/`.
- Read `prototype/game-core.js` only for reference patterns.

## Must not touch

- Do not modify `prototype/`.
- Do not modify root specs/docs after reading them.
- Do not implement KM-DEPLOY.
- Do not build pilot growth, war-state, backend, networking, full sim-core port, or production art pipeline.
- Do not add C# or GDExtension.
- Do not introduce licensed Gundam names or new trademark-adjacent art.

## Stop conditions

If Godot 4.6 is not installed or no usable Godot executable can be found, stop and write the final report explaining the missing prerequisite. Do not fake screenshots, exports, or verification.

If a requirement cannot be completed because export templates, Android tooling, or web templates are missing, complete the rest and document the exact blocker.

## Build requirements

Create a minimal Godot project:

```text
godot_spike/
  project.godot
  scenes/
  scripts/
  data/
  tests/
  assets/
```

### Rig proof

- Build a visible mech cutout rig from 3–5 existing part sprites.
- Use `Sprite2D` / `Node2D` hierarchy.
- At least one child part must move with its parent.
- Use copied assets from `output/kitbash-approved-0e22-payload/`.
- Implement one runtime part swap, e.g. saber ↔ rifle.

### Animation + FX proof

- Add one authored attack animation.
- Add one flipbook FX sequence using `AnimatedSprite2D` / `SpriteFrames` or equivalent Godot 4.6 pattern.
- Drive playback from a canned event with at least `{t, source, target, clip}`.
- Only one primary attack animation should play at a time.

### Determinism proof

- Implement `scripts/deterministic_check.gd` or equivalent.
- It must produce a byte-stable JSON event log from fixed inputs + seed.
- It must not depend on `_process(delta)`, physics, animation timing, or frame rate.
- Use integer or fixed-point style logic.
- Run it twice and diff the output.
- Run it under `--headless` and compare output to normal/editor script run if possible.

### Desktop / Steam-PC proof

- Confirm the project runs in Godot.
- If export templates are available, create or verify a Windows desktop export preset.
- If export is not possible, document the missing prerequisite and the run command that did work.

### Mobile compatibility proof

- Include touch-friendly controls: large button(s), no hover-only action, readable narrow layout.
- Attempt Android export only if templates/tooling are available.
- If not available, document the missing prerequisite and record a mobile/narrow-layout smoke observation.

### Optional web proof

- Attempt only after required items pass and only if cheap.
- Web export is not a blocking acceptance gate.

## Verification

First find Godot:

```bash
godot --version
godot4 --version
Godot_v4.6-stable_win64.exe --version
```

Use the working executable in commands. Example:

```bash
$GODOT --version
$GODOT --headless --path godot_spike --script res://scripts/deterministic_check.gd -- --out res://tmp/events_headless.json
$GODOT --path godot_spike --script res://scripts/deterministic_check.gd -- --out res://tmp/events_normal.json
```

If `res://tmp` is not appropriate, use a repo-local ignored temp folder and explain it in the report.

Expected determinism result:

```text
PASS deterministic event log identical
```

## Final report

Write `agent-handoffs/claude-godot-km-stack-spike-report.md` with:

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

## Commit discipline

Do not push unless explicitly asked. If you commit, use:

```bash
git add godot_spike agent-handoffs/claude-godot-km-stack-spike-report.md
git commit -m "spike: confirm Godot platform path"
```
