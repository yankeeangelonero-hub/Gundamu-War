# KM-DEPLOY Slice 1 Report

Summary verdict: IMPLEMENTED_BUT_PARTIALLY_VERIFIED

## Files changed/created

- `godot_spike/project.godot`
- `godot_spike/data/deploy_parts.json`
- `godot_spike/scripts/deploy_slice_core.gd`
- `godot_spike/scripts/deploy_slice_check.gd`
- `godot_spike/scripts/main.gd`
- `godot_spike/scripts/rig_spike.gd`
- `godot_spike/scripts/deterministic_check.gd`
- `agent-handoffs/codex-km-deploy-slice1-report.md`

No commits or pushes were made.

## Playable controls

- Workshop part toggles:
  - Weapon: `Light Rifle` / `Heavy Saber`
  - Booster: `Stable Thruster` / `High Booster`
  - Armor: `Light Plating` / `Heavy Shield`
- Forecast panel:
  - Pilot capacity and sync ceiling
  - Current build demand
  - Combat stats
  - Safe / Stretched / Over-demanding forecast text
- Deployment:
  - Large `Deploy Safe` button
  - Large `Push for Breakthrough` button
  - Projected demand, XP, and breakthrough text for both paths
- Duel watch:
  - Deterministic precomputed event playback
  - Sync/event log
  - Player attack events call `rig_spike.gd` playback
- Homecoming:
  - Win/loss
  - Sync gained
  - XP gained
  - Breakthrough progress
  - Fit/sync explanation
  - Explicit `Pilot harm: none. No permanent pilot harm.`

## Part slots and part effects

- `Light Rifle`: demand +4; damage +10, initiative +3, sync gain +2; visual uses rifle.
- `Heavy Saber`: demand +16; damage +24, defense -1, initiative -2, sync gain +5; visual uses saber.
- `Stable Thruster`: demand +5; initiative +4, dodge +3, sync gain +2.
- `High Booster`: demand +18; defense -2, initiative +10, dodge +5, sync gain +4.
- `Light Plating`: demand +4; defense +5, dodge +1, sync gain +1.
- `Heavy Shield`: demand +13; damage -1, defense +13, initiative -1, dodge -2, sync gain +1.

Every part changes both fit demand and at least one combat output.

## Fit forecast states

- Safe: demand <= pilot capacity. Copy: `Safe fit: pilot can handle this cleanly.`
- Stretched: demand is above capacity but within capacity +15. Copy: `Push fit: breakthrough possible, fight gets harder.`
- Over-demanding: demand > capacity +15. Copy explains uneven sync/output lag and safe return.

Default build is safe. Swapping `Light Rifle` to `Heavy Saber` raises demand enough to become stretched. Equipping all high-demand choices becomes over-demanding.

## Safe vs push behavior

- Safe deployment:
  - Effective demand is reduced by 8, floored at base mech demand.
  - Player HP gets a stability bonus.
  - Player output is detuned.
  - Ghost pressure is lower.
  - XP and breakthrough gains are modest.
- Push deployment:
  - Effective demand increases by 6.
  - Ghost HP and pressure increase.
  - Player output gets a push bonus, then fit pressure can reduce damage/sync.
  - XP and breakthrough upside are larger when the fit performs.
  - Over-demanding builds produce legible underperformance through fit pressure.

## Determinism implementation

- `deploy_slice_core.gd` is renderer-agnostic and does not use `_process`, physics, animation timing, or frame rate.
- `deploy_slice_check.gd` runs:
  - AC-1 default vs high-demand part forecast
  - AC-2 safe deployment
  - AC-3 push deployment comparison
  - AC-4 same-input same-seed repeat comparison
  - AC-5 over-demanding positive-valence underperformance case
- Existing `deterministic_check.gd` bug was fixed by replacing invalid `OS.exit_code` usage with a boolean write result and `quit(0 if ok else 1)`.

## Verification commands and outputs

Attempted required command:

```text
godot --version
```

Observed output from this PowerShell sandbox:

```text
Program 'godot' failed to run: Access is denied
```

Attempted direct WinGet Godot console executable:

```text
C:\Users\Yanjie\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe --version
```

Observed output:

```text
Program 'Godot_v4.6.3-stable_win64_console.exe' failed to run: Access is denied
```

Attempted Git Bash path:

```text
bash -lc "godot --version"
```

Observed output:

```text
C:\Program Files\Git\usr\bin\bash.exe: *** fatal error - couldn't create signal pipe, Win32 error 5
```

Because the sandbox blocked Godot and Git Bash before the engine started, these commands could not be completed here:

```text
godot --headless --path godot_spike --import
godot --headless --path godot_spike --quit
godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run1.json
godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run2.json
diff godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json
```

No successful Godot runtime output is claimed in this report.

## Known caveats

- Godot runtime parsing/import/load could not be verified in this sandbox due the access-denied executable blocker.
- GUI smoke was not possible for the same reason.
- Weapon swapping is visual. Booster and armor swaps are stat/UI only.
- The UI is code-built and intended for 1280x720 desktop with large touch-friendly controls, but visual layout still needs an owner/editor smoke.

## Owner playtest command

```bash
godot --path godot_spike
```

Owner determinism command after opening a shell where Godot is executable:

```bash
rm -f godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json
godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run1.json
godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run2.json
diff godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json
```

Expected diff result: no output, exit 0.

## Acceptance coverage

- AC-1: Implemented in workshop UI and `deploy_slice_check.gd`; runtime evidence blocked.
- AC-2: Implemented in core/UI/check script; runtime evidence blocked.
- AC-3: Implemented in core/UI/check script with different safe/push numbers; runtime evidence blocked.
- AC-4: Implemented in `deploy_slice_check.gd`; runtime evidence blocked.
- AC-5: Implemented in over-demanding push case and homecoming copy; runtime evidence blocked.

No acceptance check is intentionally left out of the implementation, but all Godot-executed evidence remains pending until the engine can run from the owner shell.

## Controller follow-up

Files changed in this follow-up:

- `godot_spike/scripts/main.gd`
- `godot_spike/scripts/deploy_slice_core.gd`
- `godot_spike/scripts/deploy_slice_check.gd`
- `agent-handoffs/codex-km-deploy-slice1-report.md`

Controller verification command run from Hermes Git Bash:

```bash
rm -f godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json; \
  godot --headless --path godot_spike --import && \
  godot --headless --path godot_spike --quit && \
  godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run1.json && \
  godot --headless --path godot_spike --script res://scripts/deploy_slice_check.gd -- --out res://tmp/deploy_run2.json && \
  diff godot_spike/tmp/deploy_run1.json godot_spike/tmp/deploy_run2.json
```

Results:

- Godot version available to controller: `4.6.3.stable.official.7d41c59c4`.
- Godot import/load smoke passed.
- `deploy_slice_check.gd` wrote both `res://tmp/deploy_run1.json` and `res://tmp/deploy_run2.json`.
- Determinism diff passed: `diff` produced no output and exited 0.
- The playable was launched with `godot --path godot_spike` as background process `proc_0ae5a738b48a`; the process is running.

Remaining blocker/caveat:

- No known compile/determinism blocker remains after controller QA.
- GUI/manual owner smoke is still pending: confirm the Godot window renders the workshop, part toggles, safe/push buttons, duel log, and homecoming result as intended.
