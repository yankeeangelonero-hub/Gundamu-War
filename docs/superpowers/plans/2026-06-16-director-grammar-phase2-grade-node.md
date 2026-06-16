# Director Grammar Phase 2 — Grade Node (Lighting + Color) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first-class Lighting/Color render layer of the Director Grammar — a new `Grade` node that reads authored Lighting/Color sub-blocks from `ShotGrammar` and drives a chromatic shadow fill (F22) + mood-variant grade (F26/F27), and turn the disabled `garnish` FX lights back on (F24, the single biggest "anime light" win) — without perturbing the proven camera solve or the deterministic event sequence.

**Architecture:** Phase 1's rule — *parameters move, logic stays* — extends to a new consumer. A new `scripts/director/grade.gd` (`extends Node`) owns the `WorldEnvironment`'s `Environment`: on ready it applies the grammar's chromatic fill (ambient shadow tint, never crushed to black) and a neutral base mood; it subscribes read-only to the director's `fight_event` signal (the same hook `garnish` uses), maps certain beats to a mood (warm hero push on a charge/buster, desaturated death on a kill), and lerps the `Environment.adjustment_*` + ambient tint toward that mood each frame. `garnish.gd` keeps ownership of the transient FX lights and simply re-enables its four `OmniLight3D` flashes, scaled by one grammar dial. The Grade node never writes into the sim or the camera, so determinism holds and the Phase 1 golden shot-list hash stays a hard regression guard.

**Tech Stack:** Godot 4.6, GDScript. Godot binary on this machine: `~/.local/bin/godot.cmd`. Headless test pattern: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/<name>.gd` (judge PASS/FAIL lines + exit code; RID/leak warnings on shutdown are harmless noise). A brand-new GDScript file may need a `~/.local/bin/godot.cmd --headless --path godot_director_spike --import` pass before the engine registers its `class_name`.

> **Environment note (this machine):** the project lives at `D:\Claude\Mech Bags` (PowerShell primary; a POSIX Bash tool is also available). The `cd /d/claude/Gundamu-War` lines in the commit snippets below are stale — run them from the repo root (`D:\Claude\Mech Bags`). Bash-tool loops/`grep`/redirection work as written under the Bash tool.

---

## Revisions from the codex plan review (2026-06-16)

A pre-execution codex review of this plan was run and adjudicated. Binding changes folded into the tasks below:

- **(#4, Task 3) `apply_base()` sets its own ambient source.** `city_builder.build_environment` already sets `ambient_light_source = AMBIENT_SOURCE_COLOR` (line 80), so the F22 fill works today — but the Grade must own that, not depend on the city. `apply_base()` now sets the source itself.
- **(#8, Task 3) Test against the real environment.** `grade_check.gd` gains a check that runs `apply_base()` against the actual `CityBuilder.build_environment()` output, proving the grade reaches the live env object — not only a hand-built `Environment`.
- **(#2, Tasks 5–6) One shared `ShotGrammar` instance.** `main.gd` creates a single `grammar := ShotGrammar.default()` and threads the *same instance* through `build_shot_list`, the director's runtime `_grammar`, the Grade node, and `garnish` — closing the single-source-of-truth seam instead of handing each consumer a fresh `default()`.
- **(#1, new Task 1b) Close the Phase-1 framing-key guard seam.** One `.has()` guard before the perspective `match s.mode` in `hybrid.gd`, with the golden hash re-asserted unchanged.
- **(#9, Task 4) `mood_for_event` payload-safe.** Normalize a non-Dictionary `payload` to `{}` before `.get("lethal")`.
- **(#6 — verified, no change) Event names are correct.** `fire_buster` / `destroyed` / `fire_beam`+`payload.lethal` were confirmed against `data/fight_log_everything.json` and the readers in `garnish.gd`/`director.gd` — the mood map keys on real event kinds. Codex's "names may not match" worry does not hold; no change needed.
- **Deferred (Tasks 7–8 stay optional/out):** codex #7 (Task 7 polls director internals, breaching the read-only boundary) confirms the existing call to keep F28/F29 out of the core. Build Tasks 1–6 only; do not start 7–8 without an explicit go.

---

## Lighting-ownership split (pinned by the spec — do not redistribute)

The spec resolves the three-way ambiguity the review flagged. Honor it exactly:

- **render** (`city_builder.build_environment`) owns the GI/SDFGI solve and the static directional + sky. This plan touches it only to *return* the `WorldEnvironment` so the Grade node can reach the `Environment` — no lighting values change there.
- **`garnish.gd`** owns the transient FX lights (beam/muzzle/explosion flashes that cast onto mechs and city, F24) and the FX primitives. This plan re-enables the four disabled `OmniLight3D`s and scales them by one grammar dial.
- **`Grade` node** owns the post-render mood grade + ambient color (F22 chromatic fill, F26/F27 mood variants). It is the only new render layer.

The grammar's Lighting/Color blocks hold the authored values each consumer reads; the grammar itself never renders.

**Open question this plan closes (spec §Open Questions 1):** the per-frame handoff order so the Grade pass and garnish FX lights don't double-expose a beam flash. Resolution adopted here: there is no literal double-expose — the FX `OmniLight3D`s are *scene lights* (they light geometry during the render), while the Grade is a *post-tonemap adjustment* applied to the already-composited frame via `Environment.adjustment_*`. They compose in series, not in parallel. The only real risk is the Grade *brightening* a mood on the same frame an explosion flash blows out the highlights. Mitigation baked into this plan: the `death`/aftermath mood is **desaturated and slightly darker, never brighter**, and mood lerps are slow (`mood_lerp_rate` ~1.5/s), so a transient 1-frame flash is gone long before the grade moves. No frame-ordering code is required.

## What stays out of Phase 2 (scope guard)

- **F28 per-cut offset** and **F29 per-beat accent** are in the spec's "v1 Grade" scope but require additional director per-cut / per-beat signalling. They are sequenced as the **last two tasks (Tasks 7–8)** of this plan so the high-value core (chromatic fill, beam lights, base/hero/death moods) lands and is reviewable first. If the reviewer or owner wants to stop after Task 6, that is a clean, shippable cut; Tasks 7–8 can be split into a Phase 2b plan.
- **F30 `cut_bridge`** beyond a simple mapping, and a full per-element **LUT/color-correction** pipeline, are deferred (spec scope call) — not in this plan.
- **F25 `fx_primitives`** formalization (named, individually-tunable FX set) is Phase 3 `garnish` work. This plan only flips the existing lights on and adds one global energy dial; it does not restructure the FX set.

## Files

- **Modify** `godot_director_spike/scripts/director/shot_grammar.gd` — add the Lighting + Color sub-blocks (Task 1).
- **Modify** `godot_director_spike/tests/shot_grammar_check.gd` — assert the new defaults (Task 1).
- **Modify** `godot_director_spike/scripts/directors/hybrid.gd` — guard the framing-table lookup (Task 1b).
- **Modify** `godot_director_spike/scripts/city_builder.gd` — `build_environment` returns the `WorldEnvironment` (Task 2).
- **Create** `godot_director_spike/scripts/director/grade.gd` — the Grade node (Tasks 3–4, 7–8).
- **Create** `godot_director_spike/tests/grade_check.gd` — headless tests for the Grade node logic (Tasks 3–4, 7–8).
- **Modify** `godot_director_spike/scripts/main.gd` — capture the env, instantiate + wire the Grade node, pass grammar to garnish (Tasks 5–6).
- **Modify** `godot_director_spike/scripts/garnish.gd` — re-enable the four FX lights, scale by grammar dial, accept a grammar in `setup` (Task 6).

---

### Task 1: Add Lighting + Color sub-blocks to ShotGrammar

**Files:**
- Modify: `godot_director_spike/scripts/director/shot_grammar.gd`
- Test: `godot_director_spike/tests/shot_grammar_check.gd`

Defaults are chosen so a *normal* beat looks essentially like today (chromatic fill equals the current ambient; base mood is neutral identity), and only the hero/death beats and the now-enabled FX lights change the look. This keeps Phase 2 controlled and reviewable.

- [ ] **Step 1: Write the failing test**

Append to `tests/shot_grammar_check.gd`, inside the run body where the other field checks live (follow the existing `check(...)` pattern in that file):

```gdscript
	# --- Phase 2: Lighting block ---
	check(g.chromatic_fill.is_equal_approx(Color(0.10, 0.12, 0.20)), "chromatic_fill == cool non-black ambient")
	check(is_equal_approx(g.fx_light_energy, 1.0), "fx_light_energy == 1.0")
	# --- Phase 2: Color block (mood variants) ---
	check(is_equal_approx(g.mood_lerp_rate, 1.5), "mood_lerp_rate == 1.5")
	check(g.mood_variants.has("base"), "mood_variants has base")
	check(g.mood_variants.has("hero"), "mood_variants has hero")
	check(g.mood_variants.has("death"), "mood_variants has death")
	var base_m: Dictionary = g.mood_variants["base"]
	check(is_equal_approx(base_m["brightness"], 1.0), "base mood brightness == 1.0 (identity)")
	check(is_equal_approx(base_m["saturation"], 1.0), "base mood saturation == 1.0 (identity)")
	check(is_equal_approx(base_m["warmth"], 0.0), "base mood warmth == 0.0 (neutral)")
	var death_m: Dictionary = g.mood_variants["death"]
	check(death_m["saturation"] < 1.0, "death mood desaturates")
	check(death_m["brightness"] <= 1.0, "death mood never brighter than base")
	var hero_m: Dictionary = g.mood_variants["hero"]
	check(hero_m["warmth"] > 0.0, "hero mood pushes warm")
```

> Note: `g` is the existing `ShotGrammar.default()` instance the test already builds for the Phase 1 checks. If the file names it differently, use that name; do not create a second instance.

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/shot_grammar_check.gd`
Expected: FAIL — `Invalid access to property or key 'chromatic_fill'` (or a FAIL line for the new checks), exit 1.

- [ ] **Step 3: Add the sub-blocks to the resource**

In `scripts/director/shot_grammar.gd`, after the existing `framing` export (before `static func default()`), add:

```gdscript

# --- Lighting (F22, F24) ---
# chromatic_fill: the ambient shadow tint — shadows take a cool, non-black tint
# (F22) and are never crushed to black. Equals the current scene ambient so a
# normal beat is unchanged; moods shift around it via `warmth`.
@export var chromatic_fill: Color = Color(0.10, 0.12, 0.20)
# fx_light_energy: global multiplier garnish applies to its (now re-enabled) FX
# OmniLights (F24). 1.0 = author-tuned baseline; raise for a punchier light.
@export var fx_light_energy: float = 1.0

# --- Color: mood variants (F26, F27) ---
# Named grade states the Grade node lerps between when the director signals a
# beat. Each entry: brightness/contrast/saturation feed Environment.adjustment_*;
# `warmth` shifts the ambient tint warm (+) or cool (-) around chromatic_fill.
# `base` MUST be identity (1/1/1, warmth 0) so a normal beat reads like today.
@export var mood_variants: Dictionary = {
	"base":  {"brightness": 1.0, "contrast": 1.0,  "saturation": 1.0, "warmth": 0.0},
	"hero":  {"brightness": 1.06, "contrast": 1.04, "saturation": 1.12, "warmth": 0.18},
	"death": {"brightness": 0.92, "contrast": 1.08, "saturation": 0.55, "warmth": -0.05},
}
# How fast (per wall-clock second) the grade eases toward the active mood.
@export var mood_lerp_rate: float = 1.5
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/shot_grammar_check.gd`
Expected: PASS — `---- ALL PASS`, exit 0. (If the engine errors that `ShotGrammar` is unknown, run the `--import` pass once and re-run.)

- [ ] **Step 5: Commit**

```bash
git add godot_director_spike/scripts/director/shot_grammar.gd godot_director_spike/tests/shot_grammar_check.gd
git commit -m "feat(grammar): add Lighting + Color sub-blocks to ShotGrammar (F22/F24/F26/F27)"
```

---

### Task 1b: Close the Phase-1 framing-key guard seam (codex #1)

The Phase-1 review deferred a seam: `hybrid.gd` reads `_grammar.framing[s.mode]` at four sites (`:118/:128/:138/:147`) with no guard, so a perspective shot mode with no `framing` entry (a custom grammar, or a future VOCAB mode added without a framing row) returns `null` and crashes on the next property read. All four reads sit at the head of the perspective `match s.mode:` block (the `iso`/`iso_aftermath` path has already `return`ed above it), so one guard before the match covers all four — no per-branch duplication, no new helper. At defaults every perspective mode has a framing entry, so this never triggers and the golden shot-list hash is unchanged.

**Files:**
- Modify: `godot_director_spike/scripts/directors/hybrid.gd` (insert before `match s.mode:` at ~:114)

- [ ] **Step 1: Add the guard**

In `scripts/directors/hybrid.gd`, immediately before the perspective `match s.mode:` line (~:114, right after `var fov := 45.0`), insert:

```gdscript
	# Framing-table guard (Phase-1 deferred seam): a perspective mode with no
	# framing entry would null-crash on fr.* below. Skip the shot, don't crash.
	if not _grammar.framing.has(s.mode):
		return
```

- [ ] **Step 2: Golden hash MUST be unchanged**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/hybrid_check.gd`
Expected: `---- ALL PASS`, and the hash line still reads `got hash 2543717900`, exit 0. A changed hash means the guard altered the shot solve at defaults — it must not. Stop and investigate if so.

- [ ] **Step 3: Commit**

```bash
git add godot_director_spike/scripts/directors/hybrid.gd
git commit -m "fix(grammar): guard framing-table lookup in hybrid director (Phase-1 seam)"
```

---

### Task 2: `build_environment` returns the WorldEnvironment

The Grade node needs the live `Environment` to drive its adjustments. Today `build_environment` creates the `WorldEnvironment`, adds it as a child, and returns nothing; `main.gd` has no handle to it. Return it. No lighting value changes — this is a pure plumbing change, verified by an unchanged boot.

**Files:**
- Modify: `godot_director_spike/scripts/city_builder.gd:76` (`build_environment`)

- [ ] **Step 1: Change the signature and return the node**

In `scripts/city_builder.gd`, change the function header:

```gdscript
static func build_environment(parent: Node3D) -> WorldEnvironment:
```

and at the end of the function (currently `parent.add_child(moon)`), add a return of the `WorldEnvironment` created at the top (the local is named `we`):

```gdscript
	parent.add_child(moon)
	return we
```

No other lines change. The existing caller `CityBuilder.build_environment(self)` in `main.gd` ignores the return value, so it keeps working until Task 5 captures it.

- [ ] **Step 2: Verify boot is unchanged (smoke)**

Run: `~/.local/bin/godot.cmd --path godot_director_spike --quit-after 300 -- --director=hybrid --log=fight_log_everything`
Expected: prints `KM-DIRECTOR-SPIKE boot ok`, no `SCRIPT ERROR` / `Parse Error`, exit 0.

- [ ] **Step 3: Commit**

```bash
cd /d/claude/Gundamu-War
git add godot_director_spike/scripts/city_builder.gd
git commit -m "refactor(render): build_environment returns the WorldEnvironment for the Grade node"
```

---

### Task 3: Grade node — chromatic fill + base mood on ready

Create the Grade node and prove its base application: given an `Environment` + a `ShotGrammar`, it enables adjustments, sets the ambient to the chromatic fill, and writes the `base` mood's identity values. Tested headless by hand-building an `Environment` and a default grammar — no rendering needed (`Environment.adjustment_*` and `ambient_light_color` are plain properties).

**Files:**
- Create: `godot_director_spike/scripts/director/grade.gd`
- Test: `godot_director_spike/tests/grade_check.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/grade_check.gd`:

```gdscript
extends SceneTree
## Headless checks for the Grade node (Lighting + Color, Phase 2). No rendering:
## we assert on Environment property values the node writes.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func _make_env() -> Environment:
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10, 0.12, 0.20)
	return env

func _init() -> void:
	var Grade := load("res://scripts/director/grade.gd")
	check(Grade != null, "grade.gd loads")
	var ShotGrammarScript := load("res://scripts/director/shot_grammar.gd")
	var g = ShotGrammarScript.default()
	var env := _make_env()

	var grade = Grade.new()
	grade.bind(env, g)          # bind without a director: env + grammar only
	grade.apply_base()

	check(env.adjustment_enabled, "apply_base enables adjustments")
	check(is_equal_approx(env.adjustment_brightness, 1.0), "base brightness identity")
	check(is_equal_approx(env.adjustment_contrast, 1.0), "base contrast identity")
	check(is_equal_approx(env.adjustment_saturation, 1.0), "base saturation identity")
	check(env.ambient_light_color.is_equal_approx(g.chromatic_fill),
		"ambient set to chromatic fill (F22, never black)")
	check(env.ambient_light_color.v > 0.05, "chromatic fill is non-black")

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/grade_check.gd`
Expected: FAIL — `grade.gd loads` fails (script missing), exit 1.

- [ ] **Step 3: Create the Grade node (base only)**

Create `scripts/director/grade.gd`:

```gdscript
extends Node
## Grade — the Director Grammar's Lighting + Color render layer (Phase 2).
## Owns the WorldEnvironment's mood grade (F22 chromatic fill, F26/F27 mood
## variants). Reads its values from a ShotGrammar; it is the only authority on
## the post-render mood. It subscribes READ-ONLY to the director's fight_event
## and writes nothing back into the sim or camera — determinism is preserved.
## Spec: docs/superpowers/specs/2026-06-16-director-grammar-design.md

var _env: Environment
var _grammar: ShotGrammar
var _director: Node

# Active and target mood adjustment values, eased each frame toward the target.
var _cur := {"brightness": 1.0, "contrast": 1.0, "saturation": 1.0, "warmth": 0.0}
var _target := {"brightness": 1.0, "contrast": 1.0, "saturation": 1.0, "warmth": 0.0}

## Bind the render target + authored values. director may be null (tests / no
## beat-driven moods); when present, beats drive mood pushes (Task 4).
func bind(env: Environment, grammar: ShotGrammar, director: Node = null) -> void:
	_env = env
	_grammar = grammar
	_director = director

## Apply the chromatic fill (F22) and the neutral base mood. Called once at start.
func apply_base() -> void:
	if _env == null or _grammar == null:
		return
	_env.adjustment_enabled = true
	# Own the ambient source (codex #4): the chromatic fill is only honored when the
	# ambient comes from a color, not the sky. Set it here so the Grade is correct
	# regardless of how city_builder configured the environment.
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var base: Dictionary = _grammar.mood_variants.get("base", _cur)
	_cur = base.duplicate()
	_target = base.duplicate()
	_write(_cur)

## Push the named mood as the new lerp target. Unknown names are ignored.
func set_mood(name: String) -> void:
	if _grammar == null or not _grammar.mood_variants.has(name):
		return
	_target = (_grammar.mood_variants[name] as Dictionary).duplicate()

## Write a mood dict to the Environment: brightness/contrast/saturation to the
## tonemap adjustments, warmth as a tint shift around the chromatic fill.
func _write(m: Dictionary) -> void:
	_env.adjustment_brightness = float(m["brightness"])
	_env.adjustment_contrast = float(m["contrast"])
	_env.adjustment_saturation = float(m["saturation"])
	var w := float(m["warmth"])
	# Warm (+) lifts red, drops blue around the cool fill; cool (-) the reverse.
	var fill: Color = _grammar.chromatic_fill
	_env.ambient_light_color = Color(
		clampf(fill.r + w * 0.10, 0.0, 1.0),
		clampf(fill.g + w * 0.02, 0.0, 1.0),
		clampf(fill.b - w * 0.08, 0.0, 1.0),
		fill.a)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/grade_check.gd`
Expected: PASS — `---- ALL PASS`, exit 0. (Run the `--import` pass once first if the engine reports an unknown script.)

- [ ] **Step 4b: Integration check against the REAL environment (codex #8)**

The checks above use a hand-built `Environment`. Add one check that proves the Grade applies to the *actual* environment the game uses — built by `CityBuilder.build_environment`. Append to `grade_check.gd` before the final `print(...)`/`quit(...)`:

```gdscript
	# --- integration: grade the REAL environment city_builder produces (codex #8) ---
	var CityBuilder := load("res://scripts/city_builder.gd")
	var host := Node3D.new()
	root.add_child(host)
	var we = CityBuilder.build_environment(host)
	check(we != null and we.environment != null, "build_environment returns a live WorldEnvironment")
	var live_env: Environment = we.environment
	var grade2 = Grade.new()
	grade2.bind(live_env, g)
	grade2.apply_base()
	check(live_env.adjustment_enabled, "grade enables adjustments on the LIVE env")
	check(live_env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR,
		"grade owns the ambient source on the live env (F22 fill is honored)")
	check(live_env.ambient_light_color.is_equal_approx(g.chromatic_fill),
		"live env ambient == chromatic fill")
	host.queue_free()
```

> `root` is the `SceneTree` root, available in a `SceneTree`-extending test. `build_environment` adds nodes under `host`; freeing `host` cleans them up. This requires **Task 2** (the return value) to be in place — if running Task 3 before Task 2, do Task 2 first.

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/grade_check.gd`
Expected: PASS — `---- ALL PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot_director_spike/scripts/director/grade.gd godot_director_spike/tests/grade_check.gd
git commit -m "feat(grade): Grade node applies chromatic fill + base mood (F22/F26)"
```

---

### Task 4: Grade node — beat→mood mapping + per-frame lerp

Map fight events to a mood and ease toward it. Pure mapping is unit-testable; the lerp is deterministic given a fixed delta.

**Files:**
- Modify: `godot_director_spike/scripts/director/grade.gd`
- Test: `godot_director_spike/tests/grade_check.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/grade_check.gd`, before the final `print(...)`/`quit(...)` lines:

```gdscript
	# --- beat -> mood mapping ---
	# Event kinds verified against data/fight_log_everything.json + garnish.gd/director.gd
	# readers (codex #6): fire_buster / destroyed / fire_beam+payload.lethal are real kinds.
	check(grade.mood_for_event({"kind": "fire_buster"}) == "hero", "buster -> hero mood")
	check(grade.mood_for_event({"kind": "destroyed"}) == "death", "destroyed -> death mood")
	check(grade.mood_for_event({"kind": "advance"}) == "", "advance -> no mood change")
	check(grade.mood_for_event({"kind": "fire_beam", "payload": {"lethal": true}}) == "death",
		"lethal beam -> death mood")
	check(grade.mood_for_event({"kind": "fire_beam", "payload": {}}) == "",
		"ordinary beam -> no mood change")
	# codex #9: malformed payload must not crash and must read as no-mood.
	check(grade.mood_for_event({"kind": "fire_beam"}) == "", "beam with no payload -> no mood")
	check(grade.mood_for_event({"kind": "fire_beam", "payload": 7}) == "", "beam with non-dict payload -> no mood")

	# --- lerp eases toward target, clamped, deterministic ---
	grade.apply_base()
	grade.set_mood("death")
	for i in 200:
		grade.tick(1.0 / 60.0)   # ~3.3s of eased stepping
	check(env.adjustment_saturation < 0.6, "lerp reaches near death saturation")
	check(env.adjustment_saturation >= 0.55, "lerp never overshoots target")
	check(env.adjustment_brightness <= 1.0, "death never brightens past base")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/grade_check.gd`
Expected: FAIL — `Invalid call ... 'mood_for_event'` / `'tick'`, exit 1.

- [ ] **Step 3: Add mapping, lerp, and the signal hook**

In `scripts/director/grade.gd`, add to `bind(...)` (after `_director = director`) a read-only connection when a director is present:

```gdscript
	if _director != null and _director.has_signal("fight_event"):
		_director.fight_event.connect(_on_event)
```

Add the mapping, the per-frame ease, and the runtime driver:

```gdscript
## Which mood (if any) a fight event triggers. "" means "leave the current mood".
## Pure function of the event — no side effects, unit-tested.
func mood_for_event(e: Dictionary) -> String:
	match str(e.get("kind", "")):
		"fire_buster":
			return "hero"
		"destroyed":
			return "death"
		"fire_beam":
			# codex #9: payload may be absent or non-Dictionary — normalize before .get.
			var p: Variant = e.get("payload", {})
			var lethal: bool = p is Dictionary and bool((p as Dictionary).get("lethal", false))
			return "death" if lethal else ""
		_:
			return ""

func _on_event(e: Dictionary) -> void:
	var m := mood_for_event(e)
	if m != "":
		set_mood(m)

## Ease the active grade one wall-clock step toward the target and write it.
## Separated from _process so tests can step it deterministically.
func tick(wall_delta: float) -> void:
	if _env == null or _grammar == null:
		return
	var k := clampf(_grammar.mood_lerp_rate * wall_delta, 0.0, 1.0)
	for key in _cur:
		_cur[key] = lerpf(float(_cur[key]), float(_target[key]), k)
	_write(_cur)

func _process(delta: float) -> void:
	# Grade in wall-clock time so bullet-time / hitstop don't stall the mood ease.
	var ts: float = 1.0
	if _director != null and _director.has_method("current_time_scale"):
		ts = maxf(_director.current_time_scale(), 0.05)
	tick(delta / ts)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/grade_check.gd`
Expected: PASS — `---- ALL PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd /d/claude/Gundamu-War
git add godot_director_spike/scripts/director/grade.gd godot_director_spike/tests/grade_check.gd
git commit -m "feat(grade): beat->mood mapping + wall-clock mood lerp (F27)"
```

---

### Task 5: Wire the Grade node into main.gd — one shared grammar instance (codex #2)

Capture the env from `build_environment`, create **one** `ShotGrammar` instance, and thread that *same instance* through shot generation, the director's runtime camera, the Grade node, and (Task 6) garnish — so there is a single source of truth instead of three independent `default()` copies that only coincidentally agree.

**Files:**
- Modify: `godot_director_spike/scripts/main.gd` (the `_ready` build sequence around `CityBuilder.build_environment(self)` at :46, the shot-list/director-construction block at :118-123, and the FX block at :124-129)

- [ ] **Step 1: Capture the env at build time**

Change `scripts/main.gd:46` from:

```gdscript
	CityBuilder.build_environment(self)
```

to:

```gdscript
	var world_env := CityBuilder.build_environment(self)
```

- [ ] **Step 2: Create one grammar; feed shot-gen and the director's runtime camera**

In `scripts/main.gd`, change the shot-list + director construction block (~:120-123) from:

```gdscript
	var shots: Array = DirectorScript.build_shot_list(events, dur)
	director = DirectorScript.new()
	add_child(director)
	director.start(events, shots, camera, {"A": mech_a, "B": mech_b}, dur)
```

to (create the single instance, pass it to `build_shot_list`, and set the director's runtime `_grammar` to the same object so the camera solve and the grade read identical values):

```gdscript
	# Single source of truth (codex #2): ONE grammar instance flows to shot-gen,
	# the director's runtime camera (_grammar), the Grade node, and garnish.
	var grammar := ShotGrammar.default()
	var shots: Array = DirectorScript.build_shot_list(events, dur, grammar)
	director = DirectorScript.new()
	add_child(director)
	director._grammar = grammar
	director.start(events, shots, camera, {"A": mech_a, "B": mech_b}, dur)
```

> `_grammar` is the runtime-camera grammar member on `hybrid.gd` (`:76`), defaulting to its own `default()`. Assigning the shared instance before `start()` makes the camera solve and the Grade read the same object. At defaults the values are identical, so the golden hash is unchanged (Task 9 re-asserts it).

- [ ] **Step 3: Instantiate and wire the Grade node with the shared grammar**

In the live-fight block (alongside where `Garnish`/`SpikeAudio` are created at ~:124-129), add:

```gdscript
	var Grade: GDScript = load("res://scripts/director/grade.gd")
	var grade = Grade.new()
	add_child(grade)
	grade.bind(world_env.environment, grammar, director)
	grade.apply_base()
```

- [ ] **Step 4: Smoke — boot**

Run: `~/.local/bin/godot.cmd --path godot_director_spike --quit-after 300 -- --director=hybrid --log=fight_log_everything`
Expected: `KM-DIRECTOR-SPIKE boot ok`, no errors, exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot_director_spike/scripts/main.gd
git commit -m "feat(grade): wire Grade node + share one ShotGrammar instance across director/grade (codex #2)"
```

---

### Task 6: F24 — re-enable garnish FX lights, scaled by the grammar dial

Turn the four disabled `OmniLight3D` flashes back on — the single biggest "anime light" win — and scale their energy by `grammar.fx_light_energy` so it stays tunable. Pass the grammar into `garnish.setup` (backward-compatible default).

**Files:**
- Modify: `godot_director_spike/scripts/garnish.gd` (the four `visible = false` sites: `_charge` :141, `_buster` :321, `_melee_clash` :362, `_explosion` :435; plus `setup` :8)
- Modify: `godot_director_spike/scripts/main.gd` (the `garnish.setup(...)` call at :126)

- [ ] **Step 1: Accept a grammar in setup**

In `scripts/garnish.gd`, add a member near the top (after `var rng := ...`):

```gdscript
var grammar: ShotGrammar = ShotGrammar.default()
```

Change the `setup` signature (`scripts/garnish.gd:8`) to accept an optional grammar and store it:

```gdscript
func setup(p_actors: Dictionary, p_director: Node3D, p_grammar: ShotGrammar = null) -> void:
	actors = p_actors
	director = p_director
	if p_grammar != null:
		grammar = p_grammar
```

(keep the existing body below unchanged)

- [ ] **Step 2: Re-enable each FX light, scaled by the dial**

In `_charge` (`scripts/garnish.gd` ~:140-148), replace:

```gdscript
	var light := OmniLight3D.new()
	light.visible = false   # omni removed: scene lit by directional + sky only
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = 20.0
	mech.muzzle.add_child(light)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(orb, "scale", Vector3.ONE * 1.5, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(light, "light_energy", 9.0, 0.42)
```

with (light visible; peak energy scaled by the dial):

```gdscript
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = 20.0
	mech.muzzle.add_child(light)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(orb, "scale", Vector3.ONE * 1.5, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(light, "light_energy", 9.0 * grammar.fx_light_energy, 0.42)
```

In `_buster` (~:320-327), remove `ol.visible = false` and scale the tween peak:

```gdscript
	var ol := OmniLight3D.new()
	ol.light_color = color
	ol.omni_range = 32.0
	shooter.muzzle.add_child(ol)
	var ctw := create_tween().set_parallel(true)
	ctw.tween_property(orb, "scale", Vector3.ONE * 3.2, 0.35)
	ctw.tween_property(ol, "light_energy", 11.0 * grammar.fx_light_energy, 0.35)
```

In `_melee_clash` (~:361-368), remove `flash.visible = false` and scale the initial energy:

```gdscript
	var flash := OmniLight3D.new()
	flash.light_color = col
	flash.light_energy = 28.0 * grammar.fx_light_energy
	flash.omni_range = 30.0
	add_child(flash)
	flash.global_position = contact
	create_tween().tween_property(flash, "light_energy", 0.0, 0.5)
```

In `_explosion` (~:434-441), remove `flash.visible = false` and scale the initial energy:

```gdscript
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.35)
	flash.light_energy = 60.0 * grammar.fx_light_energy
	flash.omni_range = 90.0
	add_child(flash)
	flash.global_position = pos
	create_tween().tween_property(flash, "light_energy", 0.0, 1.4)
```

- [ ] **Step 3: Pass the grammar from main.gd**

In `scripts/main.gd:126`, change:

```gdscript
	garnish.setup({"A": mech_a, "B": mech_b}, director)
```

to (pass the **same** `grammar` instance created in Task 5 — not a fresh `default()`, codex #2):

```gdscript
	garnish.setup({"A": mech_a, "B": mech_b}, director, grammar)
```

- [ ] **Step 4: Smoke — boot + capture a still and frames to eyeball the new light**

```bash
cd /d/claude/Gundamu-War
~/.local/bin/godot.cmd --path godot_director_spike --quit-after 300 -- --director=hybrid --log=fight_log_everything --still
~/.local/bin/godot.cmd --path godot_director_spike --quit-after 2500 -- --director=hybrid --log=fight_log_everything --frames
```
Expected: `boot ok`, `still saved: tmp/still_hybrid.png`, no errors, exit 0; `tmp/frame_hybrid_*.png` written. Eyeball a frame containing a beam/explosion: the muzzle/beam/explosion flashes should now visibly cast light onto the mechs and nearby buildings (they did not before). Shadows should read cool-blue, not black.

- [ ] **Step 5: Commit**

```bash
cd /d/claude/Gundamu-War
git add godot_director_spike/scripts/garnish.gd godot_director_spike/scripts/main.gd
git commit -m "feat(garnish): re-enable FX OmniLights scaled by grammar.fx_light_energy (F24)"
```

---

### Task 7 (optional — F28 per-cut offset): small grade nudge per shot

A small, additive grade offset layered on the active mood per shot — the per-cut "breath." Sequenced after the core so it can be cut cleanly.

**Files:**
- Modify: `godot_director_spike/scripts/director/shot_grammar.gd` (add `per_cut_offset`)
- Modify: `godot_director_spike/scripts/director/grade.gd`
- Test: `godot_director_spike/tests/grade_check.gd`

- [ ] **Step 1: Add the grammar field + failing test**

Add to `shot_grammar.gd` (Color block):

```gdscript
# Per-cut grade breath (F28): tiny additive nudges keyed by shot mode, layered on
# the active mood. Empty/absent mode = no offset. Values add to brightness/saturation.
@export var per_cut_offset: Dictionary = {
	"hero_cut":    {"brightness": 0.02, "saturation": 0.04},
	"bullet_time": {"brightness": -0.03, "saturation": -0.06},
}
```

Append to `grade_check.gd` before the final print:

```gdscript
	check(grade.offset_for_mode("hero_cut")["saturation"] > 0.0, "hero_cut has a positive per-cut offset")
	check(grade.offset_for_mode("iso").is_empty(), "iso has no per-cut offset")
```

- [ ] **Step 2: Run to verify it fails**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/grade_check.gd`
Expected: FAIL — `Invalid call ... 'offset_for_mode'`, exit 1.

- [ ] **Step 3: Implement the offset lookup + apply it in `_write`**

Add to `grade.gd`:

```gdscript
## The per-cut additive offset for a shot mode, or {} if none (F28). Pure lookup.
func offset_for_mode(mode: String) -> Dictionary:
	return _grammar.per_cut_offset.get(mode, {})
```

In `_write`, after computing brightness/saturation from the mood, fold in the current shot's offset (read from the director, default none):

```gdscript
	var off := {}
	if _director != null and "shots" in _director and "_shot_idx" in _director \
			and _director._shot_idx >= 0 and _director._shot_idx < _director.shots.size():
		off = offset_for_mode(str(_director.shots[_director._shot_idx].get("mode", "")))
	_env.adjustment_brightness = float(m["brightness"]) + float(off.get("brightness", 0.0))
	_env.adjustment_saturation = float(m["saturation"]) + float(off.get("saturation", 0.0))
	_env.adjustment_contrast = float(m["contrast"])
```

(replace the earlier three `adjustment_*` lines in `_write` with the block above; keep the `warmth`/ambient lines)

- [ ] **Step 4: Run to verify it passes**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/grade_check.gd`
Expected: PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
cd /d/claude/Gundamu-War
git add godot_director_spike/scripts/director/shot_grammar.gd godot_director_spike/scripts/director/grade.gd godot_director_spike/tests/grade_check.gd
git commit -m "feat(grade): per-cut grade offset by shot mode (F28)"
```

---

### Task 8 (optional — F29 per-beat accent): push a hero beam's color past its literal value

A per-beat accent that nudges a hero element's hue/intensity past its literal value on chosen beats. v1 keeps it to the firer's beam color on a `fire_buster`/lethal beat, applied in `garnish` where the beam color is chosen.

**Files:**
- Modify: `godot_director_spike/scripts/director/shot_grammar.gd` (add `accent_gain`)
- Modify: `godot_director_spike/scripts/garnish.gd` (`_buster`, and the lethal branch of `_beam`)
- Test: `godot_director_spike/tests/grade_check.gd` is not the home for a garnish color tweak; add a tiny pure helper test instead (below).

- [ ] **Step 1: Add the grammar field + a pure accent helper + failing test**

Add to `shot_grammar.gd` (Color block):

```gdscript
# Per-beat accent gain (F29): how far a hero beat may push an accent color past
# its literal value (emission multiplier bump). 0 = off.
@export var accent_gain: float = 0.35
```

Add a pure static helper to `grade.gd` (kept here so it is unit-testable without garnish):

```gdscript
## Push an accent color brighter by `gain` (F29), clamped. Pure, static.
static func accent(color: Color, gain: float) -> Color:
	return Color(
		clampf(color.r * (1.0 + gain), 0.0, 1.0),
		clampf(color.g * (1.0 + gain), 0.0, 1.0),
		clampf(color.b * (1.0 + gain), 0.0, 1.0),
		color.a)
```

Append to `grade_check.gd`:

```gdscript
	var pushed: Color = Grade.accent(Color(0.5, 0.4, 0.2), 0.5)
	check(pushed.r > 0.5 and pushed.r <= 1.0, "accent pushes brighter, clamped")
```

- [ ] **Step 2: Run to verify it fails**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/grade_check.gd`
Expected: FAIL — `Invalid call ... 'accent'`, exit 1.

- [ ] **Step 3: Implement the helper (Step 1 added it) and apply in garnish**

In `garnish.gd._buster`, after `var color: Color = ...`, push it:

```gdscript
	var Grade := load("res://scripts/director/grade.gd")
	color = Grade.accent(color, grammar.accent_gain)
```

(The buster is always a hero beat; the lethal-beam accent can be added the same way in `_beam`'s `payload.lethal` path if desired — optional, note it.)

- [ ] **Step 4: Run to verify it passes + boot smoke**

Run: `~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/grade_check.gd` → PASS, exit 0.
Run: `~/.local/bin/godot.cmd --path godot_director_spike --quit-after 300 -- --director=hybrid --log=fight_log_everything` → `boot ok`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd /d/claude/Gundamu-War
git add godot_director_spike/scripts/director/shot_grammar.gd godot_director_spike/scripts/director/grade.gd godot_director_spike/scripts/garnish.gd godot_director_spike/tests/grade_check.gd
git commit -m "feat(garnish): per-beat accent push on hero beats (F29)"
```

---

### Task 9: Regression + wrap

**Files:** none (verification only).

- [ ] **Step 1: Full suite — the golden hash MUST be unchanged**

```bash
cd /d/claude/Gundamu-War
for t in shot_grammar_check grade_check hybrid_check director_check; do
  echo "=== $t ==="; ~/.local/bin/godot.cmd --headless --path godot_director_spike -s res://tests/$t.gd 2>/dev/null | grep -E "ALL PASS|FAIL|got hash"
done
```
Expected: every suite `---- ALL PASS`. Critically, `hybrid_check` still prints `got hash 2543717900` — the Grade node and FX lights must NOT have perturbed the shot list / camera solve. A changed hash means something leaked into the deterministic path; stop and find it.

- [ ] **Step 2: Visual eyeball (the look-lock, F40 — here the look CHANGES on purpose)**

Open `godot_director_spike/tmp/still_hybrid.png` and a beam/explosion `tmp/frame_hybrid_*.png`. Confirm: shadows read cool, not black (F22); muzzle/beam/explosion flashes now light the mechs + city (F24); the establishing/non-event framing is unchanged from Phase 1 (the camera did not move). On a buster/kill beat the grade should read warmer/desaturated respectively — subtle, not a slam.

- [ ] **Step 3: Confirm a clean live fight**

Run: `~/.local/bin/godot.cmd --path godot_director_spike --quit-after 2500 -- --director=hybrid --log=fight_log_everything`
Expected: `boot ok`, plays to completion, prints the `FPS min/p5/avg` line, exit 0. Note the FPS line — re-enabled dynamic lights add real-time light cost; if `min` drops below ~30, record it for tuning (lower `omni_range`s or `fx_light_energy`) but it is not a blocker for the spike.

- [ ] **Step 4: Final whole-phase review + finish**

Dispatch a code review over the Phase 2 range (`superpowers:requesting-code-review`), then `superpowers:finishing-a-development-branch`. Then write the Phase 3 plan (new behaviors: compression, impact frames + time-emphasis arbiter, staggered blast, yield-by-class, cockpit_pov, frame_and_streak, melee framing).

---

## Self-review notes (author)

- **Spec coverage:** F22 chromatic fill → Task 1 (`chromatic_fill`) + Task 3 (applied to ambient). F24 GI/FX beam-light on → Task 6. F26/F27 mood variants → Task 1 (`mood_variants`) + Tasks 3–4 (apply + lerp + beat map). F28 per-cut offset → Task 7. F29 accent → Task 8. Lighting-ownership split honored (render/garnish/Grade) — Tasks 2/6/3-4 respectively. Determinism + golden-hash guard → Task 9 Step 1.
- **Out of scope, by design:** F25 fx_primitives restructure, F30 cut_bridge, full LUT pipeline — noted, not built.
- **Type consistency:** `bind(env, grammar, director=null)`, `apply_base()`, `set_mood(name)`, `mood_for_event(e)`, `tick(wall_delta)`, `offset_for_mode(mode)`, static `accent(color, gain)` — names are used identically across grade.gd and grade_check.gd. `build_environment` returns `WorldEnvironment`; main.gd reads `world_env.environment`. `garnish.setup(actors, director, grammar=null)` — third arg optional, supplied from main.gd.
- **Risk:** re-enabled dynamic OmniLights have a real-time render cost (memory `director-spike-deferred-tuning` flags a building-fade perf cliff already). Task 9 Step 3 watches the FPS line; tuning levers (omni_range, fx_light_energy) are in place if needed.
