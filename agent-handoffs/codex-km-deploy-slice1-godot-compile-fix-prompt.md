# Codex Follow-up: Fix KM-DEPLOY Godot Compile Blockers Only

You are in `D:/Claude/Mech Bags` on branch `main`.

Context: You just implemented `godot_spike/` KM-DEPLOY Slice 1. Controller QA can run Godot 4.6.3 from Git Bash, but the project fails to compile. Fix only the compile/runtime blockers needed for the existing verification commands to pass. Do not expand scope.

## Controller QA failure

Command run by controller:

```bash
godot --version && \
  godot --headless --path godot_spike --import && \
  godot --headless --path godot_spike --quit && \
  rm -f godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json && \
  godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run1.json && \
  godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run2.json && \
  diff godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json
```

Failure output:

```text
SCRIPT ERROR: Parse Error: Cannot infer the type of "part" variable because the value doesn't have a set type.
   at: GDScript::reload (res://scripts/main.gd:136)
ERROR: Failed to load script "res://scripts/main.gd" with error "Parse error".

SCRIPT ERROR: Parse Error: The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)
   at: GDScript::reload (res://scripts/deploy_slice_core.gd:124)
SCRIPT ERROR: Parse Error: The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)
   at: GDScript::reload (res://scripts/deploy_slice_core.gd:168)
SCRIPT ERROR: Parse Error: The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)
   at: GDScript::reload (res://scripts/deploy_slice_core.gd:169)
SCRIPT ERROR: Parse Error: The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)
   at: GDScript::reload (res://scripts/deploy_slice_core.gd:186)
SCRIPT ERROR: Parse Error: The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)
   at: GDScript::reload (res://scripts/deploy_slice_core.gd:187)
SCRIPT ERROR: Parse Error: The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)
   at: GDScript::reload (res://scripts/deploy_slice_core.gd:342)
SCRIPT ERROR: Parse Error: The variable type is being inferred from a Variant value, so it will be typed as Variant. (Warning treated as error.)
   at: GDScript::reload (res://scripts/deploy_slice_core.gd:361)
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
   at: GDScript::reload (res://scripts/deploy_slice_check.gd:0)
ERROR: Failed to load script "res://scripts/deploy_slice_check.gd" with error "Compilation failed".
SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'.
   at: _init (res://scripts/deploy_slice_check.gd:16)
```

The controller command then timed out after 300s, likely because the check script did not exit cleanly after the compile failure.

## Scope

Allowed:
- `godot_spike/scripts/main.gd`
- `godot_spike/scripts/deploy_slice_core.gd`
- `godot_spike/scripts/deploy_slice_check.gd`
- `agent-handoffs/codex-km-deploy-slice1-report.md` only if you need to update verification status/caveats after successful verification

Do not touch unrelated docs/code. Do not commit or push.

## Required fixes

- Add explicit type annotations or casts so Godot 4.6 GDScript compiles with warnings treated as errors.
- Fix the `deploy_slice_check.gd` `GDScript.new`/preload/new usage so the script can instantiate or call the core successfully when run with `--script`.
- Ensure the verification script exits with non-zero on failure and zero on success; no hangs.

## Verification you must run if Godot is available

```bash
godot --headless --path godot_spike --import
godot --headless --path godot_spike --quit
rm -f godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json
godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run1.json
godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run2.json
diff godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json
```

## Final output

Update `agent-handoffs/codex-km-deploy-slice1-report.md` with a short "Controller follow-up" section including:
- Files changed in this follow-up
- Exact verification commands run
- Whether determinism diff passed
- Any remaining blocker/caveat

Return a concise summary. Do not commit or push.
