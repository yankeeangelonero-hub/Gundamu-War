# Archetype Showcase Fights — Tier 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three fully-expressed archetype showcase fights (rifle/missile, buster, saber) launchable by a single `--showcase=NAME` flag, so the owner can watch each archetype's identity in motion and tune distinctness by eye.

**Architecture:** Pure data + a thin resolver. Three richer `*_showcase` kits and a `showcases` map go in the existing `m0_loadout_kits.json`; a pure `LoadoutGenerator.resolve_showcase()` maps a showcase name to its (kit, foil, seed, chaos); `main.gd` gains a `--showcase=` branch that reuses the existing `--auto-fight` render path. No new render code — identity is expressed through loadout cadence + the existing grammar presets (gunner/anvil/lancer) + the already-tuned camera. Tier 2 (the Remote Bit Swarm render feature) is a separate plan.

**Tech Stack:** Godot 4.6.3, GDScript, headless SceneTree tests run via the Godot console exe.

**Spec:** `docs/superpowers/specs/2026-06-27-archetype-showcase-fights-design.md`

**Commit policy:** Per `CLAUDE.md`, do NOT run `git commit` without the owner's explicit go-ahead. Treat each "Commit" step as a checkpoint: stage the files, show the diff, and request approval before committing.

**Godot console exe (for test runs):**
`C:\Users\Yanjie\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe`
Run a test: `& $godotConsole --headless --path godot_director_spike --script res://tests/<name>.gd`

---

## File Structure

- Modify: `godot_director_spike/data/m0_loadout_kits.json` — add a `showcases` map + three `*_showcase` kits (the fully-expressed loadouts).
- Modify: `godot_director_spike/scripts/sim/loadout_fight_generator.gd` — add the pure `resolve_showcase()`.
- Modify: `godot_director_spike/scripts/main.gd` — add a `--showcase=` branch to `_auto_fight_from_args()`.
- Create: `godot_director_spike/tests/showcase_kits_check.gd` — TDD the resolver + fully-expressed kits.
- Create: `godot_director_spike/tests/showcase_distinct_check.gd` — regression: the three are deterministic and measurably distinct.

---

## Task 1: Showcase data + resolver

**Files:**
- Modify: `godot_director_spike/data/m0_loadout_kits.json`
- Modify: `godot_director_spike/scripts/sim/loadout_fight_generator.gd`
- Test: `godot_director_spike/tests/showcase_kits_check.gd`

- [ ] **Step 1: Write the failing test**

Create `godot_director_spike/tests/showcase_kits_check.gd`:

```gdscript
extends SceneTree
## TDD: showcase resolver + fully-expressed showcase kits.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func _initialize() -> void:
	var Gen := load("res://scripts/sim/loadout_fight_generator.gd")
	check(Gen != null, "loadout_fight_generator.gd loads")
	if Gen == null:
		_finish()
		return
	var catalog: Dictionary = Gen.load_catalog()

	var rifle: Dictionary = Gen.resolve_showcase(catalog, "rifle")
	check(str(rifle.get("kit", "")) == "rifle_missile_showcase", "rifle showcase resolves to its kit")
	check(str(rifle.get("opponent", "")) == "artillery_ghost", "rifle showcase foil is artillery_ghost")
	check(int(rifle.get("seed", -1)) == 77, "rifle showcase seed is 77")
	check(absf(float(rifle.get("chaos", -1.0)) - 0.5) < 0.001, "rifle showcase chaos is 0.5")

	var buster: Dictionary = Gen.resolve_showcase(catalog, "buster")
	check(str(buster.get("kit", "")) == "buster_artillery_showcase", "buster showcase resolves to its kit")
	check(str(buster.get("opponent", "")) == "pressure_ghost", "buster showcase foil is pressure_ghost")

	var saber: Dictionary = Gen.resolve_showcase(catalog, "saber")
	check(str(saber.get("kit", "")) == "saber_booster_showcase", "saber showcase resolves to its kit")
	check(str(saber.get("opponent", "")) == "pressure_ghost", "saber showcase foil is pressure_ghost")

	var loadout: Dictionary = Gen.resolve_player_loadout(catalog, str(rifle.get("kit", "")), "pilot_aya")
	check((loadout.get("weapons", []) as Array).size() >= 3, "rifle showcase kit is fully expressed (>=3 weapons)")

	check(str(Gen.resolve_showcase(catalog, "nope").get("kit", "")) == "", "unknown showcase resolves empty")

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& $godotConsole --headless --path godot_director_spike --script res://tests/showcase_kits_check.gd`
Expected: FAIL — `resolve_showcase` does not exist yet, so the script errors / the tree idles. (If it hangs, that confirms the missing method; kill it.)

- [ ] **Step 3: Add the showcase data**

In `godot_director_spike/data/m0_loadout_kits.json`, add three kits inside the `"kits"` object (alongside the existing three) and a new top-level `"showcases"` map. Add these kit entries:

```json
"rifle_missile_showcase": {
  "name": "Rifle / Missile — Fully Expressed",
  "archetype": "rifle_missile_pressure",
  "grammar_preset": "gunner",
  "hp": 195,
  "power_identity": "relentless ranged pressure",
  "defense_beats": ["evade"],
  "spectacle_intent": {"matchup_shape": "ranged pressure", "summary": "A relentless gunner ace: beam, missiles and sustained fire never let up."},
  "weapons": [
    {"id": "beam_rifle", "motif": "beam", "viewer_kind": "fire_beam", "tier": 2, "damage": 11, "cooldown": 22, "accuracy": 0.88, "initiative": 20, "travel": 5, "variance": 0.12, "start": 10},
    {"id": "micro_missiles", "motif": "missiles", "viewer_kind": "fire_missiles", "tier": 2, "damage": 9, "cooldown": 28, "accuracy": 0.80, "initiative": 15, "travel": 8, "variance": 0.18, "start": 16, "count": 8},
    {"id": "long_beam", "motif": "beam", "viewer_kind": "fire_beam", "tier": 2, "damage": 9, "cooldown": 30, "accuracy": 0.84, "initiative": 14, "travel": 6, "variance": 0.12, "start": 20},
    {"id": "head_vulcan", "motif": "vulcan", "viewer_kind": "fire_burst", "tier": 1, "damage": 4, "cooldown": 18, "accuracy": 0.70, "initiative": 12, "travel": 3, "variance": 0.20, "start": 13, "rounds": 4}
  ]
},
"buster_artillery_showcase": {
  "name": "Buster Artillery — Fully Expressed",
  "archetype": "buster_artillery",
  "grammar_preset": "anvil",
  "hp": 215,
  "power_identity": "heavy executioner",
  "defense_beats": ["block"],
  "spectacle_intent": {"matchup_shape": "artillery execution", "summary": "A heavy executioner: slow charge commits and a devastating finisher behind a shield."},
  "weapons": [
    {"id": "buster_cannon", "motif": "buster", "viewer_kind": "fire_buster", "tier": 3, "damage": 30, "cooldown": 46, "accuracy": 0.76, "initiative": 8, "travel": 10, "variance": 0.20, "start": 22},
    {"id": "heavy_beam", "motif": "beam", "viewer_kind": "fire_beam", "tier": 2, "damage": 11, "cooldown": 32, "accuracy": 0.82, "initiative": 11, "travel": 6, "variance": 0.12, "start": 15},
    {"id": "scatter_missiles", "motif": "missiles", "viewer_kind": "fire_missiles", "tier": 2, "damage": 8, "cooldown": 38, "accuracy": 0.74, "initiative": 9, "travel": 9, "variance": 0.20, "start": 26, "count": 6}
  ]
},
"saber_booster_showcase": {
  "name": "Saber / Booster — Fully Expressed",
  "archetype": "saber_booster_chase",
  "grammar_preset": "lancer",
  "hp": 185,
  "power_identity": "aggressive duelist",
  "defense_beats": ["evade", "parry"],
  "spectacle_intent": {"matchup_shape": "melee chase", "summary": "An aggressive duelist: boost-closes, twin-saber pressure, blade finish."},
  "weapons": [
    {"id": "twin_sabers", "motif": "saber", "viewer_kind": "melee", "tier": 2, "damage": 17, "cooldown": 22, "accuracy": 0.85, "initiative": 30, "travel": 1, "variance": 0.15, "start": 10, "style": "cleave"},
    {"id": "snap_beam", "motif": "beam", "viewer_kind": "fire_beam", "tier": 1, "damage": 7, "cooldown": 30, "accuracy": 0.80, "initiative": 18, "travel": 4, "variance": 0.14, "start": 17},
    {"id": "shield_breaker", "motif": "vulcan", "viewer_kind": "fire_burst", "tier": 1, "damage": 5, "cooldown": 24, "accuracy": 0.72, "initiative": 22, "travel": 2, "variance": 0.18, "start": 14, "rounds": 3}
  ]
}
```

Then add this top-level key (sibling to `"kits"` and `"opponents"`):

```json
"showcases": {
  "rifle":  {"kit": "rifle_missile_showcase",   "opponent": "artillery_ghost", "seed": 77, "chaos": 0.5},
  "buster": {"kit": "buster_artillery_showcase", "opponent": "pressure_ghost",  "seed": 77, "chaos": 0.5},
  "saber":  {"kit": "saber_booster_showcase",    "opponent": "pressure_ghost",  "seed": 77, "chaos": 0.5}
}
```

- [ ] **Step 4: Add the resolver**

In `godot_director_spike/scripts/sim/loadout_fight_generator.gd`, add this static function after `resolve_opponent_loadout()`:

```gdscript
static func resolve_showcase(catalog: Dictionary, name: String) -> Dictionary:
	var showcases: Dictionary = catalog.get("showcases", {}) if catalog.get("showcases", {}) is Dictionary else {}
	var entry: Dictionary = showcases.get(name, {}) if showcases.get(name, {}) is Dictionary else {}
	return {
		"kit": str(entry.get("kit", "")),
		"opponent": str(entry.get("opponent", "")),
		"seed": int(entry.get("seed", 77)),
		"chaos": float(entry.get("chaos", 0.5)),
	}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `& $godotConsole --headless --path godot_director_spike --script res://tests/showcase_kits_check.gd`
Expected: `---- ALL PASS`

- [ ] **Step 6: Commit (checkpoint — request approval first)**

```bash
git add godot_director_spike/data/m0_loadout_kits.json godot_director_spike/scripts/sim/loadout_fight_generator.gd godot_director_spike/tests/showcase_kits_check.gd
git commit -m "feat(showcase): add fully-expressed archetype showcase kits + resolver"
```

---

## Task 2: Distinctness + determinism regression

**Files:**
- Test: `godot_director_spike/tests/showcase_distinct_check.gd`

- [ ] **Step 1: Write the test**

Create `godot_director_spike/tests/showcase_distinct_check.gd`:

```gdscript
extends SceneTree
## Regression: the three showcases are deterministic and read as distinct fights
## (different weapon-motif signatures). NOT a quality grade — only a "not accidentally
## identical" guard.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func _motifs(events: Array) -> Dictionary:
	var m := {}
	for e in events:
		if e is Dictionary:
			var payload: Dictionary = e.get("payload", {}) if e.get("payload", {}) is Dictionary else {}
			var motif := str(payload.get("motif", ""))
			if motif != "":
				m[motif] = true
	return m


func _initialize() -> void:
	var Gen := load("res://scripts/sim/loadout_fight_generator.gd")
	if Gen == null:
		_finish()
		return
	var catalog: Dictionary = Gen.load_catalog()
	var motif_sets := {}
	for name in ["rifle", "buster", "saber"]:
		var s: Dictionary = Gen.resolve_showcase(catalog, name)
		var player: Dictionary = Gen.resolve_player_loadout(catalog, str(s.get("kit", "")), "pilot_aya")
		var opp: Dictionary = Gen.resolve_opponent_loadout(catalog, str(s.get("opponent", "")))
		var first: Dictionary = Gen.generate(player, opp, int(s.get("seed", 77)), float(s.get("chaos", 0.5)))
		var second: Dictionary = Gen.generate(player, opp, int(s.get("seed", 77)), float(s.get("chaos", 0.5)))
		check(first == second, "%s showcase is deterministic" % name)
		motif_sets[name] = _motifs(first.get("events", []))

	check(motif_sets["rifle"] != motif_sets["buster"], "rifle vs buster motif signatures differ")
	check(motif_sets["rifle"] != motif_sets["saber"], "rifle vs saber motif signatures differ")
	check(motif_sets["buster"] != motif_sets["saber"], "buster vs saber motif signatures differ")

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
```

- [ ] **Step 2: Run the test**

Run: `& $godotConsole --headless --path godot_director_spike --script res://tests/showcase_distinct_check.gd`
Expected: `---- ALL PASS`. (Motif sets: rifle={beam,missiles,vulcan}, buster={buster,beam,missiles}, saber={saber,beam,vulcan} — pairwise distinct.)
If a pair is NOT distinct, that is a real signal the showcase loadouts overlap too much — adjust the weapon motifs in `m0_loadout_kits.json` until they diverge, then re-run.

- [ ] **Step 3: Commit (checkpoint — request approval first)**

```bash
git add godot_director_spike/tests/showcase_distinct_check.gd
git commit -m "test(showcase): guard showcase determinism + pairwise distinctness"
```

---

## Task 3: `--showcase=` launch flag

**Files:**
- Modify: `godot_director_spike/scripts/main.gd` (function `_auto_fight_from_args`)

- [ ] **Step 1: Add the showcase branch**

In `godot_director_spike/scripts/main.gd`, replace the body of `_auto_fight_from_args()` with:

```gdscript
func _auto_fight_from_args() -> void:
	var showcase := _arg_value("--showcase=", "")
	if showcase != "":
		var s := LoadoutGenerator.resolve_showcase(LoadoutGenerator.load_catalog(), showcase)
		if str(s.get("kit", "")) == "":
			push_error("Unknown showcase '%s'" % showcase)
			return
		_on_build_launcher_fight_requested(str(s.get("kit")), str(s.get("opponent")), float(s.get("chaos")), int(s.get("seed")))
		return
	var player_kit := _arg_value("--player-kit=", "rifle_missile_pressure")
	var opponent := _arg_value("--opponent=", "artillery_ghost")
	var chaos := float(_arg_value("--chaos=", "0.50"))
	var seed := int(_arg_value("--seed=", "77"))
	_on_build_launcher_fight_requested(player_kit, opponent, chaos, seed)
```

- [ ] **Step 2: Smoke-verify the flag renders the showcase**

Run (note `--quit-after` is a Godot engine arg, before the `--`):
```
& $godotConsole --headless --path godot_director_spike --quit-after 6000 -- --director=hybrid --build-ui --auto-fight --showcase=rifle --armor
```
Expected: console contains `KM-BUILD-UI fight A=rifle_missile_showcase B=artillery_ghost chaos=0.50 seed=77 events=` followed by an event count > 0.

Repeat for `--showcase=buster` (expect `A=buster_artillery_showcase B=pressure_ghost`) and `--showcase=saber` (expect `A=saber_booster_showcase B=pressure_ghost`).

- [ ] **Step 3: Commit (checkpoint — request approval first)**

```bash
git add godot_director_spike/scripts/main.gd
git commit -m "feat(showcase): launch a named archetype showcase with --showcase="
```

---

## Task 4: Full regression sweep

- [ ] **Step 1: Run the existing + new headless checks**

Run each and confirm `---- ALL PASS`:
```
& $godotConsole --headless --path godot_director_spike --script res://tests/showcase_kits_check.gd
& $godotConsole --headless --path godot_director_spike --script res://tests/showcase_distinct_check.gd
& $godotConsole --headless --path godot_director_spike --script res://tests/loadout_generator_check.gd
& $godotConsole --headless --path godot_director_spike --script res://tests/build_launcher_check.gd
& $godotConsole --headless --path godot_director_spike --script res://tests/spectacle_report_matrix_check.gd
```
Expected: all `---- ALL PASS` (the showcase kits must not break catalog loading or the matrix runner).

- [ ] **Step 2: Whitespace check**

Run: `git diff --check`
Expected: no output.

- [ ] **Step 3: Hand the owner the watch commands**

Provide these three launch commands (the `$godot` non-console exe for an actual window) so the owner can watch and judge distinctness:
```
& $godot --path godot_director_spike -- --director=hybrid --build-ui --auto-fight --showcase=rifle  --armor
& $godot --path godot_director_spike -- --director=hybrid --build-ui --auto-fight --showcase=buster --armor
& $godot --path godot_director_spike -- --director=hybrid --build-ui --auto-fight --showcase=saber  --armor
```
where `$godot = 'C:\Users\Yanjie\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe'`.

---

## Self-review notes

- **Spec coverage:** rifle/buster/saber fully-expressed loadouts (Task 1 data), foils per spec (rifle→artillery_ghost, buster→pressure_ghost, saber→pressure_ghost; Task 1 `showcases` map), `--showcase=` single-arg launch (Task 3), determinism + distinctness tests (Tasks 1–2). The Remote Bit Swarm (Tier 2) is intentionally excluded — separate plan.
- **No new render code** — consistent with the spec's "three data-only showcases."
- **Type consistency:** `resolve_showcase` returns `{kit, opponent, seed, chaos}` and is consumed with those exact keys in Task 3 and the tests.
- **Tuning loop:** after Task 4, the owner watches the three; any "these read too similar" feedback is addressed by editing the grammar preset / loadout cadence data and re-watching — no code changes needed.
