# Codex Prompt — Build KM-DEPLOY Slice 1 in Godot

You are running in repo:

`D:/Claude/Mech Bags`

Use Codex CLI as an implementation worker. Do not commit or push.

## Mission

Build the first playable Kitbash Mecha v0.4 slice in the existing Godot project under `godot_spike/`.

This slice is KM-DEPLOY: one pilot, one base mech, 2–3 editable part choices, safe-vs-push deploy decision, one deterministic watched duel, and one homecoming/growth result.

The owner specifically clarified: **the first playable slice must include some editable parts because kitbashing is the main mechanic to play.**

## Required reading before edits

Read these first:

1. `CLAUDE.md`
2. `docs/slices/KM-DEPLOY-first-playable-slice.md`
3. `docs/slices/KM-STACK-SPIKE-godot-platform-confirmation.md`
4. `agent-handoffs/claude-godot-km-stack-spike-report.md`
5. `docs/pilot-and-war-front-high-level-spec-and-work-map.md` sections for KM-DEPLOY, determinism, positive valence, and data-driven contracts
6. Current Godot files under `godot_spike/`

## Current verified baseline

Godot is installed and callable from this Hermes Git Bash shell:

```bash
godot --version
# 4.6.3.stable.official.7d41c59c4
```

Asset import passes:

```bash
godot --headless --path godot_spike --import
```

Headless project-load smoke passes:

```bash
godot --headless --path godot_spike --quit
```

Known current bug from the stack spike:

```text
SCRIPT ERROR: Parse Error: Cannot find member "exit_code" in base "OS".
at: res://scripts/deterministic_check.gd:135
```

Fix this as part of the slice. Do not leave the determinism script broken.

## May touch

- `godot_spike/**`
- `agent-handoffs/codex-km-deploy-slice1-report.md`
- If needed, small notes in `Kanban.md` only to record discovered pitfalls/caveats; do not rewrite planning docs.

## Must not touch

- `prototype/**`
- Root specs/docs other than the allowed report and optional narrow Kanban note
- `docs/slices/KM-DEPLOY-first-playable-slice.md` unless you find a blocking contradiction; if so, report it instead of silently changing scope
- Hermes profile/memory/skills files
- Network/backend/account/PvP code
- C# or GDExtension
- 3D
- Commits/pushes

## Product constraints

- Steam PC first, mobile-app compatible second, web optional.
- Godot 4.6 + GDScript.
- Simulation and animation must stay separable.
- Deterministic logic must not depend on `_process(delta)`, physics, animation timing, or frame rate.
- No permanent pilot harm.
- No Gundam IP/trademark-adjacent names/lore.
- Keep this small. Do not build full workshop, shop, inventory, war map, backend, or multi-pilot roster.

## Required slice shape

Implement in `godot_spike/` a playable local slice with these surfaces:

### 1. Tiny editable-parts workshop

Include 2 required editable slots, 3 max:

- Weapon slot: light rifle vs heavy saber/cannon style part.
- Mobility/booster slot: stable thruster vs high-output booster.
- Optional armor/shield slot only if cheap.

Each part must affect BOTH:

1. Combat output, e.g. damage, defense, initiative, dodge, sync gain.
2. Pilot fit demand.

Show current build demand and forecast state:

- Safe / stretched / over-demanding.
- Explanation line, e.g. `Safe fit: pilot can handle this cleanly` or `Push fit: breakthrough possible, fight gets harder`.

Visual part swapping is preferred if cheap. At minimum, weapon swap must visually change using existing rig assets. Other slots may be stat/UI-only if visual assets are unavailable.

### 2. Deploy decision

Add two large touch-friendly buttons:

- `Deploy Safe`
- `Push for Breakthrough`

Show projected consequences for both.

### 3. Watched deterministic duel

When deployment is chosen:

- Run one deterministic duel using the selected build, one fixed pilot, one fixed seeded ghost opponent, and one fixed seed.
- Show event log / sync log.
- Use one primary attack animation at a time if using rig playback.
- Safe and push paths must differ in actual numbers/outcomes, not just label text.

### 4. Homecoming/result panel

At duel completion show:

- Win/loss.
- Sync gained.
- XP/growth gained.
- Breakthrough progress or breakthrough earned.
- Explanation of underperformance through fit/sync/demand.
- Explicit no permanent pilot harm / positive-valence outcome.

## Implementation guidance

Prefer a simple architecture:

- `scripts/deploy_slice_core.gd` or similar: deterministic pure-ish calculation for build stats, fit forecast, duel event generation, result calculation.
- `scripts/main.gd`: UI/controller.
- `scripts/rig_spike.gd`: continue to own rig animation/weapon visual swap.
- `data/deploy_parts.json` or similar: local part definitions.
- `scripts/deploy_slice_check.gd` or extend `deterministic_check.gd`: scriptable verification for same-input same-seed determinism and safe/push outputs.

Do not over-engineer. Hardcoded local data is acceptable if it is clean and small.

## Required verification commands

Run and report results:

```bash
godot --version
godot --headless --path godot_spike --import
godot --headless --path godot_spike --quit
```

Determinism verification must run at least two equivalent fixed-input runs and diff outputs. You may use either a new check script or the fixed existing one, but it must cover KM-DEPLOY logic, not only the old stack-spike toy sim.

Example shape:

```bash
rm -f godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json
godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run1.json
godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run2.json
diff godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json
```

Expected: diff has no output and the command exits 0.

If a GUI smoke is impossible in this headless terminal, do not fake it. Report that headless checks passed and owner should open with:

```bash
godot --path godot_spike
```

## Acceptance checks to satisfy

From `docs/slices/KM-DEPLOY-first-playable-slice.md`:

- AC-1: Editable parts change fit forecast.
- AC-2: Safe deployment is available and modest.
- AC-3: Push deployment is available and meaningfully different.
- AC-4: Same inputs and seed reproduce the same duel.
- AC-5: Underperformance is legible and positive-valence.

Implement programmatic evidence where possible. At minimum, the verification output JSON should contain enough state to prove AC-1 through AC-5 without relying only on the GUI.

## Final report

Write exactly this report path:

`agent-handoffs/codex-km-deploy-slice1-report.md`

Include:

- Summary verdict: `IMPLEMENTED_AND_VERIFIED`, `IMPLEMENTED_BUT_PARTIALLY_VERIFIED`, or `BLOCKED`.
- Files changed/created.
- What playable controls exist.
- Part slots and part effects.
- Fit forecast states.
- Safe vs push behaviour differences.
- Determinism commands and outputs.
- Godot import/load smoke results.
- Known caveats.
- Exact owner playtest command.
- Whether any acceptance check remains uncovered.

Remember: do not commit or push.
