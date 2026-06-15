# Director Grammar — Phase 1: ShotGrammar extraction + parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lift the `hybrid` director's hardcoded camera/timing constants into a single `ShotGrammar` resource that the director reads, with characterization tests proving the shot list and camera framing are byte-identical to today (a pure, parity-safe refactor).

**Architecture:** A new `ShotGrammar` resource (extends `Resource`) holds the grammar's parameters grouped into sub-blocks (Timing, Composition with a per-shot-mode framing table). A static `ShotGrammar.default()` returns an instance pre-filled with the current shipped values. `hybrid.gd`'s static `build_shot_list` gains an optional `grammar` parameter (defaulting to `ShotGrammar.default()`); its runtime `_update_camera` reads framing from an instance member `_grammar`. No shot math changes — only where the numbers come from. This is spec build-sequence step 1 (`docs/superpowers/specs/2026-06-16-director-grammar-design.md`).

**Tech Stack:** Godot 4.6.3, GDScript. Tests are headless `SceneTree` scripts run via `godot --headless --path godot_director_spike -s res://tests/<name>.gd` (pattern: `tests/hybrid_check.gd`). The Godot binary is `~/.local/bin/godot.cmd` (Bash) on this machine.

---

## File structure

- **Create** `godot_director_spike/scripts/director/shot_grammar.gd` — the `ShotGrammar` resource: typed parameter fields grouped by sub-block + `static func default()`. One responsibility: hold authored grammar values.
- **Create** `godot_director_spike/tests/shot_grammar_check.gd` — headless check that `ShotGrammar.default()` returns the exact current values.
- **Modify** `godot_director_spike/tests/hybrid_check.gd` — add a characterization assertion: a fixed golden snapshot of the shot list for `fight_log_everything` so any drift from the refactor is caught.
- **Modify** `godot_director_spike/scripts/directors/hybrid.gd` — read constants/framing from `ShotGrammar` instead of local `const`s; add the optional `grammar` param and the `_grammar` instance member.
- **No change** to `scripts/main.gd` — it calls `Hybrid.build_shot_list(events, shots, ...)` and constructs the director; the default-grammar fallback keeps it working untouched (verified by the still capture in Task 6).

---

## Current values being extracted (source of truth: `scripts/directors/hybrid.gd`)

These are the live constants and inline framing numbers as of commit `b316635`. The refactor must reproduce them exactly.

- Timing: `OS_LEN = 1.8`, `CUT_LEN = 1.8`, `BT_PRE = 0.2`, `BT_POST = 0.55`, `BT_SCALE = 0.07`.
- Composition / iso: `ISO_OFFSET = Vector3(-45, 90, 18)`; iso zoom `clampf(separation * 0.7 + 30.0, 50.0, 118.0)`; aftermath zoom `58.0`.
- Per-shot-mode framing (from the `match s.mode` block in `_update_camera`):
  - `hero_os`: pullback `18.0`, lateral `8.0`, height `16.0`, fov `40`.
  - `hero_cut`: pullback `2.0`, lateral `9.0`, height `5.0`, fov `46`, roll `-0.05`.
  - `melee_cut`: orbit radius `15.0`, height `4.0`, fov `36`.
  - `bullet_time`: radius `32.0`, height_base `8.0`, height_rise `9.0`, depth `14.0`, fov `48`.

---

### Task 1: Create the `ShotGrammar` resource

**Files:**
- Create: `godot_director_spike/scripts/director/shot_grammar.gd`
- Test: `godot_director_spike/tests/shot_grammar_check.gd`

- [ ] **Step 1: Write the failing test**

Create `godot_director_spike/tests/shot_grammar_check.gd`:

```gdscript
extends SceneTree
## Headless check: ShotGrammar.default() returns the current shipped grammar values.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	var ShotGrammar := load("res://scripts/director/shot_grammar.gd")
	check(ShotGrammar != null, "shot_grammar.gd loads")
	if ShotGrammar != null:
		var g = ShotGrammar.default()
		check(g != null, "default() returns an instance")
		# Timing
		check(g.os_len == 1.8, "os_len == 1.8")
		check(g.cut_len == 1.8, "cut_len == 1.8")
		check(g.bt_pre == 0.2, "bt_pre == 0.2")
		check(g.bt_post == 0.55, "bt_post == 0.55")
		check(g.bt_scale == 0.07, "bt_scale == 0.07")
		# Composition / iso
		check(g.iso_offset == Vector3(-45, 90, 18), "iso_offset == (-45,90,18)")
		check(g.iso_zoom_min == 50.0, "iso_zoom_min == 50")
		check(g.iso_zoom_max == 118.0, "iso_zoom_max == 118")
		check(g.iso_zoom_factor == 0.7, "iso_zoom_factor == 0.7")
		check(g.iso_zoom_base == 30.0, "iso_zoom_base == 30")
		check(g.aftermath_zoom == 58.0, "aftermath_zoom == 58")
		# Per-mode framing table (one representative key each)
		check(g.framing.hero_os.fov == 40.0, "hero_os.fov == 40")
		check(g.framing.hero_cut.roll == -0.05, "hero_cut.roll == -0.05")
		check(g.framing.melee_cut.fov == 36.0, "melee_cut.fov == 36")
		check(g.framing.bullet_time.radius == 32.0, "bullet_time.radius == 32")
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/shot_grammar_check.gd`
Expected: FAIL — "shot_grammar.gd loads" fails (file does not exist yet), process exits 1.

- [ ] **Step 3: Write the `ShotGrammar` resource**

Create `godot_director_spike/scripts/director/shot_grammar.gd`:

```gdscript
extends Resource
## ShotGrammar — the single authored home for the director's camera/timing
## parameters, grouped by sub-block. Spec: docs/superpowers/specs/2026-06-16-director-grammar-design.md
## Phase 1 holds Timing + Composition (per-mode framing). Lighting/Color/Continuity
## sub-blocks arrive in later phases. `default()` returns the current shipped values
## so lifting these out of hybrid.gd changes nothing visually.

# --- Timing / Cut (F5, F14, F37, F38) ---
@export var os_len: float = 1.8       # over-shoulder intercut length
@export var cut_len: float = 1.8      # hero-cut intercut length
@export var bt_pre: float = 0.2       # bullet-time lead before the lethal hit
@export var bt_post: float = 0.55     # bullet-time hold past the lethal hit (covers the kill)
@export var bt_scale: float = 0.07    # bullet-time time-scale (slow-mo)

# --- Composition: iso backbone (F6, F4, F34) ---
@export var iso_offset: Vector3 = Vector3(-45, 90, 18)
@export var iso_zoom_min: float = 50.0
@export var iso_zoom_max: float = 118.0
@export var iso_zoom_factor: float = 0.7   # * mech separation
@export var iso_zoom_base: float = 30.0    # + base
@export var aftermath_zoom: float = 58.0

# --- Composition: per-shot-mode framing table (F6, F8) ---
# Each entry holds the framing numbers the runtime camera reads for that mode.
@export var framing: Dictionary = {
	"hero_os":     {"pullback": 18.0, "lateral": 8.0, "height": 16.0, "fov": 40.0},
	"hero_cut":    {"pullback": 2.0,  "lateral": 9.0, "height": 5.0,  "fov": 46.0, "roll": -0.05},
	"melee_cut":   {"radius": 15.0, "height": 4.0, "fov": 36.0},
	"bullet_time": {"radius": 32.0, "height_base": 8.0, "height_rise": 9.0, "depth": 14.0, "fov": 48.0},
}

static func default() -> Resource:
	return load("res://scripts/director/shot_grammar.gd").new()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/shot_grammar_check.gd`
Expected: PASS — all checks PASS, "---- ALL PASS", exit 0.

- [ ] **Step 5: Commit**

```bash
cd /d/claude/Gundamu-War
git add godot_director_spike/scripts/director/shot_grammar.gd godot_director_spike/tests/shot_grammar_check.gd
git commit -m "feat(grammar): ShotGrammar resource with current-value defaults (Timing + Composition)"
```

---

### Task 2: Characterization snapshot of the current shot list

This locks today's `build_shot_list` output so the Task 3 refactor is provably parity-safe. It runs against the unmodified `hybrid.gd`, so it passes before the refactor and must keep passing after.

**Files:**
- Modify: `godot_director_spike/tests/hybrid_check.gd` (append a new check method + call it)

- [ ] **Step 1: Write the failing test**

In `godot_director_spike/tests/hybrid_check.gd`, add a call inside `_initialize()` right after `_check_hybrid_shot_list()`:

```gdscript
	_check_hybrid_parity_snapshot()
```

Then append this method at the end of the file:

```gdscript
func _check_hybrid_parity_snapshot() -> void:
	var FightLog := load("res://scripts/fight_log.gd")
	var Hybrid := load("res://scripts/directors/hybrid.gd")
	var events: Array = FightLog.load_events("res://data/fight_log_everything.json")
	var dur: float = FightLog.duration_sec(events)
	var shots: Array = Hybrid.build_shot_list(events, dur)
	# Snapshot signature: count + per-shot (mode, rounded t0, rounded t1, time_scale).
	# Rounding to 1e-4 avoids float-format noise while catching any real drift.
	var sig := "%d|" % shots.size()
	for s in shots:
		sig += "%s,%.4f,%.4f,%.4f;" % [s.mode, float(s.t0), float(s.t1), float(s.time_scale)]
	var hash_now := sig.hash()
	# Golden hash is recorded on first run (see Step 2), then frozen.
	check(hash_now == GOLDEN_SHOTLIST_HASH, "hybrid shot list matches golden snapshot (got hash %d)" % hash_now)
```

And add this constant near the top of the file (after `var fails := 0`), initially set to `0`:

```gdscript
const GOLDEN_SHOTLIST_HASH := 0  # placeholder; frozen to the real value in Step 2
```

- [ ] **Step 2: Run it once to capture the golden hash, then freeze it**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/hybrid_check.gd`
Expected: the new check FAILs and prints `got hash <N>` (a non-zero integer). Copy that exact `<N>` and replace the constant:

```gdscript
const GOLDEN_SHOTLIST_HASH := <N>  # frozen from current hybrid.gd output, fight_log_everything
```

- [ ] **Step 3: Re-run to verify the snapshot now passes on current code**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/hybrid_check.gd`
Expected: PASS — "hybrid shot list matches golden snapshot", "---- ALL PASS", exit 0. This confirms the golden is correct against the unrefactored director.

- [ ] **Step 4: Commit**

```bash
cd /d/claude/Gundamu-War
git add godot_director_spike/tests/hybrid_check.gd
git commit -m "test(grammar): freeze golden shot-list snapshot for hybrid parity"
```

---

### Task 3: Refactor `build_shot_list` to read Timing from the grammar

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` (the static `build_shot_list` + the `const`s)

- [ ] **Step 1: Add the grammar import and the optional parameter**

At the top of `hybrid.gd`, after the `extends` line, add:

```gdscript
const ShotGrammar := preload("res://scripts/director/shot_grammar.gd")
```

Change the function signature from:

```gdscript
static func build_shot_list(events: Array, dur: float) -> Array:
```

to:

```gdscript
static func build_shot_list(events: Array, dur: float, grammar: Resource = null) -> Array:
	if grammar == null:
		grammar = ShotGrammar.default()
```

- [ ] **Step 2: Replace the Timing constants with grammar reads inside `build_shot_list`**

In `build_shot_list`, replace the `const`-based uses with grammar fields. Specifically:
- `first_t + OS_LEN` → `first_t + grammar.os_len`
- `float(mid.t) + CUT_LEN` → `float(mid.t) + grammar.cut_len`
- the bullet-time append: `lethal_t - BT_PRE` → `lethal_t - grammar.bt_pre`; `lethal_t + BT_POST` → `lethal_t + grammar.bt_post`; `"time_scale": BT_SCALE` → `"time_scale": grammar.bt_scale`

Leave the `const OS_LEN`, `const CUT_LEN`, `const BT_PRE`, `const BT_POST`, `const BT_SCALE` declarations in place for now (the runtime camera in Task 4 still references `BT_SCALE`); they are removed in Task 4 once nothing reads them.

- [ ] **Step 3: Run the parity snapshot to verify no drift**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/hybrid_check.gd`
Expected: PASS — "hybrid shot list matches golden snapshot" still passes (default grammar reproduces the constants), all checks PASS, exit 0.

- [ ] **Step 4: Commit**

```bash
cd /d/claude/Gundamu-War
git add godot_director_spike/scripts/directors/hybrid.gd
git commit -m "refactor(grammar): build_shot_list reads Timing from ShotGrammar (parity held)"
```

---

### Task 4: Refactor the runtime camera to read Composition/framing from the grammar

The runtime camera (`_update_camera`) is an instance method, so it reads a `_grammar` instance member rather than the static default.

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` (instance member + `_update_camera` + remove dead consts)

- [ ] **Step 1: Add the `_grammar` instance member**

Near the other instance vars in `hybrid.gd` (e.g. beside `var _zoom := 90.0`), add:

```gdscript
var _grammar: Resource = ShotGrammar.default()
```

- [ ] **Step 2: Replace inline framing numbers in `_update_camera` with grammar reads**

In the iso branch:
- `clampf(a.position.distance_to(b.position) * 0.7 + 30.0, 50.0, 118.0)` →
  `clampf(a.position.distance_to(b.position) * _grammar.iso_zoom_factor + _grammar.iso_zoom_base, _grammar.iso_zoom_min, _grammar.iso_zoom_max)`
- aftermath `want = 58.0` → `want = _grammar.aftermath_zoom`
- `focus_pt + ISO_OFFSET` → `focus_pt + _grammar.iso_offset`

In the `match s.mode` block, read the framing table (`var fr := _grammar.framing[s.mode]` at the top of each branch):
- `hero_os`: `pos = f.position - d * fr.pullback + d.cross(Vector3.UP) * fr.lateral + Vector3(0, fr.height, 0)`; `fov = fr.fov`
- `hero_cut`: `pos = f.position - d * fr.pullback + d.cross(Vector3.UP) * fr.lateral + Vector3(0, fr.height, 0)`; `fov = fr.fov`; `_roll = fr.roll`
- `melee_cut`: `pos = contact + Vector3(cos(ang) * fr.radius, fr.height, sin(ang) * fr.radius)`; `fov = fr.fov`
- `bullet_time`: `pos = center + Vector3(cos(ang) * fr.radius, fr.height_base + p * fr.height_rise, sin(ang) * fr.depth)`; `fov = fr.fov`; and replace the `wall_len := (float(s.t1) - float(s.t0)) / BT_SCALE` with `/ _grammar.bt_scale`

- [ ] **Step 3: Remove the now-dead Timing/Composition constants**

Delete the `const OS_LEN`, `const CUT_LEN`, `const BT_PRE`, `const BT_POST`, `const BT_SCALE`, and `const ISO_OFFSET` lines from `hybrid.gd` — nothing references them now (grep to confirm).

Run: `cd /d/claude/Gundamu-War && grep -nE "BT_SCALE|BT_PRE|BT_POST|OS_LEN|CUT_LEN|ISO_OFFSET" godot_director_spike/scripts/directors/hybrid.gd`
Expected: no matches.

- [ ] **Step 4: Run the full hybrid + grammar checks**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/hybrid_check.gd`
Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/shot_grammar_check.gd`
Expected: both "---- ALL PASS", exit 0. (The shot-list parity proves the static path; the camera math now reads identical values from the grammar.)

- [ ] **Step 5: Commit**

```bash
cd /d/claude/Gundamu-War
git add godot_director_spike/scripts/directors/hybrid.gd
git commit -m "refactor(grammar): runtime camera reads Composition framing from ShotGrammar"
```

---

### Task 5: Visual-parity capture (the look-lock, F40)

A headless still confirms the rendered framing is unchanged after the refactor — the spec's F40 look-lock for Phase 1.

**Files:**
- No code change. Uses the existing `--still` path in `scripts/main.gd`.

- [ ] **Step 1: Capture a still with the refactored director**

Run:
```bash
~/.local/bin/godot.cmd --path godot_director_spike --quit-after 1200 -- --director=hybrid --log=fight_log_everything --still
```
Expected: console prints `still saved: tmp/still_hybrid.png`, exit 0.

- [ ] **Step 2: Eyeball the still for parity**

Open `godot_director_spike/tmp/still_hybrid.png`. Expected: the same establishing framing as before the refactor — two mechs in the block-out city, behind-A look-toward-B angle. Any change in framing means a grammar value diverged from the original constant; re-check Task 4.

- [ ] **Step 3: No commit** (the PNG is a throwaway under `tmp/`, already gitignored — confirm with `git status` showing it untracked/ignored).

---

### Task 6: Full regression + wrap

**Files:**
- No code change.

- [ ] **Step 1: Run the full director-related check suite**

Run each and confirm "ALL PASS", exit 0:
```bash
~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/shot_grammar_check.gd
~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/hybrid_check.gd
~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/director_check.gd
```
Expected: all three exit 0. (`director_check.gd` exercises the base `director.gd`, which Phase 1 did not touch — a guard that the refactor was contained to `hybrid.gd`.)

- [ ] **Step 2: Confirm `main.gd` still launches the live fight**

Run:
```bash
~/.local/bin/godot.cmd --path godot_director_spike --quit-after 300 -- --director=hybrid --log=fight_log_everything
```
Expected: console prints `KM-DIRECTOR-SPIKE boot ok`, no `SCRIPT ERROR` / `Parse Error` lines, exit 0. This confirms `main.gd`'s untouched `Hybrid.build_shot_list(...)` call works against the default-grammar fallback.

- [ ] **Step 3: Final commit (if any uncommitted refactor remains)**

```bash
cd /d/claude/Gundamu-War
git status -s
# if hybrid.gd or tests have uncommitted changes:
git add godot_director_spike/scripts/directors/hybrid.gd godot_director_spike/tests/
git commit -m "chore(grammar): Phase 1 ShotGrammar extraction complete — parity verified"
```

---

## Phase 1 done — what's next (separate plans)

This plan deliberately stops at the parity-safe extraction. The remaining spec build-sequence steps each get their own plan, written after Phase 1 is verified:
- **Phase 2** — the `Grade` node (Lighting + Color v1: chromatic fill, GI beam-light on, mood variants).
- **Phase 3** — new behaviors: `compression` (lens), `impact_frames` + the time-emphasis arbiter, `staggered_blast` / `yield_by_class`, `cockpit_pov`, `frame_and_streak`, `melee_cut` framing tuning.
- **Phase 4** — soft continuity constraints (`axis_of_action`, `screen_direction`) + the test-runner line/side check.
