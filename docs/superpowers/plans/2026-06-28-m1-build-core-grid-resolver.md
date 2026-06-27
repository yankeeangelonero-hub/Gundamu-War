# M1 Build Core — Grid + Resolver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The pure, unit-tested core of the M1 backpack build editor: a 5×4 `BuildGrid` (shapes, rotation, placement validity) and a `BuildResolver` (placed items → per-weapon effective damage/cost + build totals via Path-of-Exile increased/more algebra). No rendering, no UI, no 3D — just the deterministic logic the build screen and the later M0 sim both consume.

**Architecture:** Two pure GDScript modules (`extends RefCounted`, static funcs) under `scripts/build/`, mirroring the existing pure-sim modules (e.g. `spectacle_profile.gd`). `BuildGrid` owns grid geometry; `BuildResolver` owns the economy math and depends on `BuildGrid` for cell geometry. A starter item palette in `data/build_items.json`. Headless SceneTree tests like the rest of `tests/`.

**Tech Stack:** Godot 4.6.3, GDScript. Tests run via the Godot console exe headless.

**Spec:** `docs/superpowers/specs/2026-06-14-m1-build-grid-and-power-economy-design.md` (§2 data model, §3 resolution math, §4 grid, §7 testing).

**Scope of THIS plan:** the pure core only (spec §6 `BuildGrid` + `BuildResolver`, §7 resolver + grid tests). OUT of scope, separate later plans: the Build UI scene (§4 interaction, §6 Build UI), and the `MechActor` hardpoint registry + mount cascade (§5, §6). Per spec §3 the resolver must be a pure function of the placement with no randomness, so the same placement always yields the same output.

**Commit policy:** Per `CLAUDE.md`, do NOT run `git commit` without the owner's explicit go-ahead. Treat each "Commit" step as a checkpoint: stage, show the diff, request approval.

**Godot console exe:** `C:\Users\Yanjie\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe`
Run a test: `& $godotConsole --headless --path godot_director_spike --script res://tests/<name>.gd`

---

## File Structure

- Create: `godot_director_spike/scripts/build/build_grid.gd` — pure grid geometry: rotate cells, occupied cells, in-grid + no-overlap validity. ONE responsibility: where shapes sit on the 5×4 grid.
- Create: `godot_director_spike/scripts/build/build_resolver.gd` — pure economy: placements → per-weapon effective damage/cost via the increased/more/flat formula, plus total pool/regen. Depends on `build_grid.gd` for cell geometry.
- Create: `godot_director_spike/data/build_items.json` — the starter dev palette (builders, weapons, supports) as data.
- Create: `godot_director_spike/tests/build_grid_check.gd` — grid geometry + validity tests.
- Create: `godot_director_spike/tests/build_resolver_check.gd` — resolution math + determinism tests over the palette.

**Cell convention:** a cell is `{"x": int, "y": int}`. Grid is 5 wide (x 0..4) × 4 tall (y 0..3). A shape is an Array of cells relative to the item origin. A support's `buff_slots` is also an Array of relative cells — it rotates with the shape. A placement is `{"item": <item def dict>, "x": int, "y": int, "rot": int}` (rot 0..3 = 90°·rot clockwise).

---

## Task 1: BuildGrid geometry (rotation + occupancy)

**Files:**
- Create: `godot_director_spike/scripts/build/build_grid.gd`
- Test: `godot_director_spike/tests/build_grid_check.gd`

- [ ] **Step 1: Write the failing test**

Create `godot_director_spike/tests/build_grid_check.gd`:

```gdscript
extends SceneTree
## Pure grid geometry: rotation (shape AND buff-slots rotate together) + occupancy + validity.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func has_cell(cells: Array, x: int, y: int) -> bool:
	for c in cells:
		if int(c.x) == x and int(c.y) == y:
			return true
	return false


func _initialize() -> void:
	var Grid := load("res://scripts/build/build_grid.gd")
	check(Grid != null, "build_grid.gd loads")
	if Grid == null:
		_finish()
		return

	check(Grid.GRID_W == 5 and Grid.GRID_H == 4, "grid is 5x4")

	# A horizontal domino [(0,0),(1,0)] rotated 90deg CW becomes vertical [(0,0),(0,1)].
	var domino := [{"x": 0, "y": 0}, {"x": 1, "y": 0}]
	var r1: Array = Grid.rotate_cells(domino, 1)
	check(has_cell(r1, 0, 0) and has_cell(r1, 0, 1) and r1.size() == 2,
		"rotate 90deg: horizontal domino -> vertical")
	# Full turn returns to the original.
	check(has_cell(Grid.rotate_cells(domino, 4), 1, 0), "rotate by 4 == identity")

	# Buff-slots rotate by the SAME function, so they track the shape.
	var slots := [{"x": 1, "y": 0}, {"x": -1, "y": 0}]   # left/right of origin
	var rs: Array = Grid.rotate_cells(slots, 1)            # -> up/down of origin
	check(has_cell(rs, 0, 1) and has_cell(rs, 0, -1), "buff-slots rotate with the same transform")

	# Occupancy offsets the rotated shape to the placement.
	var occ: Array = Grid.occupied_cells(domino, 2, 1, 0)
	check(has_cell(occ, 2, 1) and has_cell(occ, 3, 1), "occupied_cells offsets to (px,py)")

	# In-grid bounds.
	check(Grid.in_grid({"x": 0, "y": 0}) and Grid.in_grid({"x": 4, "y": 3}), "corners are in grid")
	check(not Grid.in_grid({"x": 5, "y": 0}) and not Grid.in_grid({"x": 0, "y": -1}), "out-of-bounds rejected")

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
```

- [ ] **Step 2: Run it and confirm RED**

Run: `& $godotConsole --headless --path godot_director_spike --script res://tests/build_grid_check.gd`
Expected: FAIL / error — `build_grid.gd` does not exist yet. (If a SceneTree test hangs because a referenced symbol is missing, that still confirms RED; kill it.)

- [ ] **Step 3: Implement BuildGrid geometry**

Create `godot_director_spike/scripts/build/build_grid.gd`:

```gdscript
extends RefCounted
## Pure 5x4 build grid geometry: shape rotation, occupied cells, bounds, placement validity.
## No rendering, no state — every function is pure of its arguments. Cells are {"x":int,"y":int}.

const GRID_W := 5
const GRID_H := 4

## Rotate a list of relative cells by rot (any int) * 90deg CLOCKWISE about the origin.
## Shapes and buff-slots both rotate through this, so they always track each other.
static func rotate_cells(cells: Array, rot: int) -> Array:
	var r := ((rot % 4) + 4) % 4
	var out: Array = []
	for c in cells:
		var x := int(c.x)
		var y := int(c.y)
		match r:
			1:
				out.append({"x": -y, "y": x})
			2:
				out.append({"x": -x, "y": -y})
			3:
				out.append({"x": y, "y": -x})
			_:
				out.append({"x": x, "y": y})
	return out

## World cells a relative shape occupies when placed at (px,py) with rotation rot.
static func occupied_cells(shape: Array, px: int, py: int, rot: int) -> Array:
	var out: Array = []
	for c in rotate_cells(shape, rot):
		out.append({"x": int(c.x) + px, "y": int(c.y) + py})
	return out

static func in_grid(cell: Dictionary) -> bool:
	return int(cell.x) >= 0 and int(cell.x) < GRID_W and int(cell.y) >= 0 and int(cell.y) < GRID_H

static func cell_key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell.x), int(cell.y)]
```

- [ ] **Step 4: Run it and confirm GREEN**

Run: `& $godotConsole --headless --path godot_director_spike --script res://tests/build_grid_check.gd`
Expected: `---- ALL PASS`

- [ ] **Step 5: Commit (checkpoint — request approval first)**

```bash
git add godot_director_spike/scripts/build/build_grid.gd godot_director_spike/tests/build_grid_check.gd
git commit -m "feat(m1): pure build-grid geometry (rotation + occupancy)"
```

---

## Task 2: BuildGrid placement validity

**Files:**
- Modify: `godot_director_spike/scripts/build/build_grid.gd`
- Test: `godot_director_spike/tests/build_grid_check.gd` (extend)

- [ ] **Step 1: Add the failing test**

In `godot_director_spike/tests/build_grid_check.gd`, insert these checks immediately BEFORE the final `_finish()` call in `_initialize()`:

```gdscript
	# Validity: a placement is legal only when every cell is in-grid and no cell overlaps.
	var occupied := {}   # set of occupied cell-keys from already-placed items
	for c in Grid.occupied_cells(domino, 0, 0, 0):
		occupied[Grid.cell_key(c)] = true
	# A domino at (2,0) is clear.
	check(Grid.is_valid_placement(domino, 2, 0, 0, occupied), "non-overlapping placement is valid")
	# A domino at (0,0) collides with the already-placed one.
	check(not Grid.is_valid_placement(domino, 0, 0, 0, occupied), "overlapping placement is rejected")
	# A domino at (4,0) sticks off the right edge (cell x=5).
	check(not Grid.is_valid_placement(domino, 4, 0, 0, occupied), "out-of-grid placement is rejected")
	# Rotated vertical domino at (4,0) -> cells (4,0),(4,1) fit the right column.
	check(Grid.is_valid_placement(domino, 4, 0, 1, occupied), "rotated placement fitting the edge is valid")
```

- [ ] **Step 2: Run it and confirm RED**

Run: `& $godotConsole --headless --path godot_director_spike --script res://tests/build_grid_check.gd`
Expected: FAIL — `is_valid_placement` does not exist yet.

- [ ] **Step 3: Implement validity**

In `godot_director_spike/scripts/build/build_grid.gd`, append:

```gdscript
## True when the shape placed at (px,py,rot) lies fully in-grid and overlaps no already-occupied
## cell. `occupied` is a Dictionary used as a set of cell-keys (see occupied_set).
static func is_valid_placement(shape: Array, px: int, py: int, rot: int, occupied: Dictionary) -> bool:
	for c in occupied_cells(shape, px, py, rot):
		if not in_grid(c):
			return false
		if occupied.has(cell_key(c)):
			return false
	return true

## Build the occupied-cell set for a list of placements (each {shape,x,y,rot}). Used by callers
## to test the next placement against the current board.
static func occupied_set(placements: Array) -> Dictionary:
	var occ := {}
	for p in placements:
		for c in occupied_cells(p.shape, int(p.x), int(p.y), int(p.rot)):
			occ[cell_key(c)] = true
	return occ
```

- [ ] **Step 4: Run it and confirm GREEN**

Run: `& $godotConsole --headless --path godot_director_spike --script res://tests/build_grid_check.gd`
Expected: `---- ALL PASS`

- [ ] **Step 5: Commit (checkpoint — request approval first)**

```bash
git add godot_director_spike/scripts/build/build_grid.gd godot_director_spike/tests/build_grid_check.gd
git commit -m "feat(m1): build-grid placement validity (in-grid + no overlap)"
```

---

## Task 3: Item palette + BuildResolver (economy math)

**Files:**
- Create: `godot_director_spike/data/build_items.json`
- Create: `godot_director_spike/scripts/build/build_resolver.gd`
- Test: `godot_director_spike/tests/build_resolver_check.gd`

- [ ] **Step 1: Create the item palette data**

Create `godot_director_spike/data/build_items.json`:

```json
{
  "reactor_small": {"kind": "builder", "shape": [{"x":0,"y":0},{"x":1,"y":0}], "pool": 100, "regen": 10},
  "reactor_core":  {"kind": "builder", "shape": [{"x":0,"y":0},{"x":1,"y":0},{"x":0,"y":1},{"x":1,"y":1}], "pool": 220, "regen": 22},
  "beam_rifle":    {"kind": "weapon", "shape": [{"x":0,"y":0},{"x":1,"y":0}], "base_damage": 11, "base_power_cost": 8, "cadence": 25, "preferred_mount": "hand_r", "fallback_mounts": ["hand_l","shoulder_r"]},
  "buster_cannon": {"kind": "weapon", "shape": [{"x":0,"y":0},{"x":1,"y":0},{"x":2,"y":0}], "base_damage": 30, "base_power_cost": 24, "cadence": 48, "preferred_mount": "hand_r", "fallback_mounts": ["back_r","shoulder_r"]},
  "amp_link":      {"kind": "support", "shape": [{"x":0,"y":0}], "buff_slots": [{"x":1,"y":0},{"x":-1,"y":0},{"x":0,"y":1},{"x":0,"y":-1}], "increased": 0.30, "cost_multiplier": 1.20},
  "overcharge":    {"kind": "support", "shape": [{"x":0,"y":0}], "buff_slots": [{"x":1,"y":0},{"x":-1,"y":0},{"x":0,"y":1},{"x":0,"y":-1}], "more": 0.25, "cost_multiplier": 1.50},
  "tuned_barrel":  {"kind": "support", "shape": [{"x":0,"y":0}], "buff_slots": [{"x":1,"y":0},{"x":-1,"y":0},{"x":0,"y":1},{"x":0,"y":-1}], "flat_added": 5, "cost_multiplier": 1.10}
}
```

- [ ] **Step 2: Write the failing resolver test**

Create `godot_director_spike/tests/build_resolver_check.gd`:

```gdscript
extends SceneTree
## Pure resolver: placements -> per-weapon effective damage/cost + totals, via PoE algebra.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1


func approx(a: float, b: float, tol := 0.001) -> bool:
	return absf(a - b) <= tol


func _initialize() -> void:
	var Resolver := load("res://scripts/build/build_resolver.gd")
	check(Resolver != null, "build_resolver.gd loads")
	if Resolver == null:
		_finish()
		return
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_items.json"))
	check(db != null and db.has("beam_rifle"), "item palette loads")

	# Helper to build a placement from a palette id.
	var P := func(id: String, x: int, y: int, rot := 0) -> Dictionary:
		var item: Dictionary = (db[id] as Dictionary).duplicate(true)
		item["id"] = id
		return {"item": item, "x": x, "y": y, "rot": rot}

	# --- Totals: two reactors sum pool + regen ---
	var r0: Dictionary = Resolver.resolve([P.call("reactor_small", 0, 0), P.call("reactor_core", 0, 2)])
	check(approx(r0.total_pool, 320.0), "total_pool sums builders (100+220)")
	check(approx(r0.total_regen, 32.0), "total_regen sums builders (10+22)")

	# --- Bare weapon: no supports -> base damage/cost ---
	var r1: Dictionary = Resolver.resolve([P.call("beam_rifle", 0, 0)])
	var w1: Dictionary = r1.weapons[0]
	check(approx(w1.effective_damage, 11.0), "bare weapon = base damage")
	check(approx(w1.effective_cost, 8.0), "bare weapon = base cost")

	# --- One adjacent 'increased' support covers the rifle ---
	# rifle occupies (0,0),(1,0); amp_link at (0,1) buffs cells (1,1),(-1,1),(0,2),(0,0) -> covers (0,0).
	var r2: Dictionary = Resolver.resolve([P.call("beam_rifle", 0, 0), P.call("amp_link", 0, 1)])
	var w2: Dictionary = r2.weapons[0]
	check(approx(w2.effective_damage, 11.0 * 1.30), "increased: 11 * (1+0.30) = 14.3")
	check(approx(w2.effective_cost, 8.0 * 1.20), "cost x1.20 from the covering support")

	# --- Stack: flat + increased + more, costs multiply ---
	# Place tuned_barrel (flat 5) at (0,1) and overcharge (more 0.25) at (1,1): both buff (0,0)/(1,0).
	var r3: Dictionary = Resolver.resolve([
		P.call("beam_rifle", 0, 0),
		P.call("amp_link", 0, 1),       # increased 0.30, covers (0,0)
		P.call("tuned_barrel", 1, 1),   # flat 5, covers (1,0)
		P.call("overcharge", 2, 0),     # more 0.25, buff cell (1,0) covers the rifle
	])
	var w3: Dictionary = r3.weapons[0]
	# (11 + 5) * (1 + 0.30) * (1 + 0.25) = 16 * 1.30 * 1.25 = 26.0
	check(approx(w3.effective_damage, 26.0), "flat+increased+more: 16 * 1.30 * 1.25 = 26.0")
	# 8 * 1.20 * 1.10 * 1.50 = 15.84
	check(approx(w3.effective_cost, 8.0 * 1.20 * 1.10 * 1.50), "costs multiply across covering supports")

	# --- A support that covers nothing applies nothing ---
	var r4: Dictionary = Resolver.resolve([P.call("beam_rifle", 0, 0), P.call("amp_link", 4, 3)])
	check(approx(r4.weapons[0].effective_damage, 11.0), "far support does not cover the weapon")

	# --- Determinism: same placement -> identical output ---
	var pls := [P.call("beam_rifle", 0, 0), P.call("amp_link", 0, 1), P.call("overcharge", 2, 0)]
	check(Resolver.resolve(pls) == Resolver.resolve(pls), "resolve is deterministic for the same placement")

	_finish()


func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
```

- [ ] **Step 3: Run it and confirm RED**

Run: `& $godotConsole --headless --path godot_director_spike --script res://tests/build_resolver_check.gd`
Expected: FAIL / error — `build_resolver.gd` does not exist yet.

- [ ] **Step 4: Implement BuildResolver**

Create `godot_director_spike/scripts/build/build_resolver.gd`:

```gdscript
extends RefCounted
## Pure build resolver: placed items -> per-weapon effective damage/cost + build totals, using
## Path-of-Exile increased/more algebra (spec section 3). No rendering, no randomness — the same
## placement always yields the same output, so the M0 sim can reproduce it from {build, seed}.

const Grid := preload("res://scripts/build/build_grid.gd")

## placements: Array of {"item": <def dict with kind/shape/...>, "x":int, "y":int, "rot":int}.
## Returns {"weapons": [{id, effective_damage, effective_cost}], "total_pool", "total_regen"}.
static func resolve(placements: Array) -> Dictionary:
	var total_pool := 0.0
	var total_regen := 0.0
	var supports: Array = []   # each: {cells: Dictionary set of buff-slot keys, flat, inc, more, cost_mult}
	var weapons: Array = []

	for pl in placements:
		var item: Dictionary = pl.item
		match str(item.get("kind", "")):
			"builder":
				total_pool += float(item.get("pool", 0.0))
				total_regen += float(item.get("regen", 0.0))
			"support":
				var slot_cells := {}
				for c in Grid.occupied_cells(item.get("buff_slots", []), int(pl.x), int(pl.y), int(pl.rot)):
					slot_cells[Grid.cell_key(c)] = true
				supports.append({
					"cells": slot_cells,
					"flat": float(item.get("flat_added", 0.0)),
					"inc": float(item.get("increased", 0.0)),
					"more": float(item.get("more", 0.0)),
					"cost_mult": float(item.get("cost_multiplier", 1.0)),
				})
			"weapon":
				weapons.append(pl)

	var resolved: Array = []
	for wpl in weapons:
		var item: Dictionary = wpl.item
		var wcells := {}
		for c in Grid.occupied_cells(item.get("shape", []), int(wpl.x), int(wpl.y), int(wpl.rot)):
			wcells[Grid.cell_key(c)] = true
		var flat := 0.0
		var inc := 0.0
		var more_prod := 1.0
		var cost_mult := 1.0
		for s in supports:
			if _covers(s.cells, wcells):
				flat += float(s.flat)
				inc += float(s.inc)
				more_prod *= (1.0 + float(s.more))
				cost_mult *= float(s.cost_mult)
		var eff_dmg := (float(item.get("base_damage", 0.0)) + flat) * (1.0 + inc) * more_prod
		var eff_cost := float(item.get("base_power_cost", 0.0)) * cost_mult
		resolved.append({
			"id": str(item.get("id", "")),
			"effective_damage": eff_dmg,
			"effective_cost": eff_cost,
		})

	return {"weapons": resolved, "total_pool": total_pool, "total_regen": total_regen}

## A support covers a weapon when any of its buff-slot cells coincides with a weapon cell.
static func _covers(support_cells: Dictionary, weapon_cells: Dictionary) -> bool:
	for k in support_cells:
		if weapon_cells.has(k):
			return true
	return false
```

- [ ] **Step 5: Run it and confirm GREEN**

Run: `& $godotConsole --headless --path godot_director_spike --script res://tests/build_resolver_check.gd`
Expected: `---- ALL PASS`

- [ ] **Step 6: Commit (checkpoint — request approval first)**

```bash
git add godot_director_spike/data/build_items.json godot_director_spike/scripts/build/build_resolver.gd godot_director_spike/tests/build_resolver_check.gd
git commit -m "feat(m1): pure build resolver (PoE increased/more economy) + item palette"
```

---

## Task 4: Regression sweep

- [ ] **Step 1: Run the two new suites + confirm no breakage elsewhere**

Run each, expect `---- ALL PASS`:
```
& $godotConsole --headless --path godot_director_spike --script res://tests/build_grid_check.gd
& $godotConsole --headless --path godot_director_spike --script res://tests/build_resolver_check.gd
& $godotConsole --headless --path godot_director_spike --script res://tests/loadout_generator_check.gd
```
(The build core is standalone — it shares no files with the sim/viewer — so existing suites are unaffected; the loadout check just confirms the project still loads clean.)

- [ ] **Step 2: Whitespace check**

Run: `git diff --check`
Expected: no output.

---

## Self-review notes

- **Spec coverage:** §2 data model → `build_items.json` (builder pool/regen; weapon base_damage/base_power_cost/cadence/preferred_mount/fallback_mounts; support shape/buff_slots/cost_multiplier/flat_added/increased/more). §3 resolution math → `BuildResolver.resolve` (the exact `(base+Σflat)·(1+Σinc)·Π(1+more)` and `base_cost·Πcost_mult`, totals = Σ builder pool/regen). §4 grid (5×4, validity, rotation of shape+buff-slots) → `BuildGrid`. §7 testing → resolver tests (known placement → expected damage/cost; determinism), grid tests (in-grid, no-overlap, rotation transforms shape AND buff-slots), all covered.
- **Out of scope (separate plans), per spec:** §4 drag/click/rotate UI interaction, §5 3D mount cascade + hardpoint registry, §6 Build UI scene + build screen scene. The `preferred_mount`/`fallback_mounts` fields are carried in the weapon data now so the later mount-cascade plan consumes them unchanged.
- **Type consistency:** placements are `{item, x, y, rot}` throughout; cells are `{x, y}`; `cell_key` formats `"x,y"`; resolver returns `{weapons:[{id, effective_damage, effective_cost}], total_pool, total_regen}` — used consistently in tests and impl.
- **Determinism:** no rng anywhere; `resolve` is pure of its args (spec §3) and the test asserts equal output for equal input.
