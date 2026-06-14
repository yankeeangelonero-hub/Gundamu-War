extends SceneTree
## Headless checks for BuildResolver — the M1 PoE increased/more/flat math, the
## power-economy totals, support coverage via authored buff-slots, and determinism.

const BuildResolver := preload("res://scripts/build/build_resolver.gd")

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.05

func _initialize() -> void:
	_single_more()
	_stack_increased_and_more()
	_flat_added()
	_no_coverage()
	_determinism()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

# reactor (pool/regen) + a rifle covered by one "more" support.
func _single_more() -> void:
	var placed := [
		{"iid": "rc", "def_id": "reactor_core", "rot": 0, "anchor": Vector2i(0, 0)},
		{"iid": "br", "def_id": "beam_rifle", "rot": 0, "anchor": Vector2i(0, 3)},
		{"iid": "pc", "def_id": "power_cell", "rot": 0, "anchor": Vector2i(0, 4)},
	]
	var r := BuildResolver.resolve(placed)
	var w: Dictionary = r.weapons["br"]
	check(near(w.damage, 18.2), "single more: 14 ×1.30 = 18.2 (got %s)" % w.damage)
	check(near(w.cost, 12.0), "single more: cost 8 ×1.5 = 12.0 (got %s)" % w.cost)
	check(w.buffed, "single more: rifle reads as buffed")
	check(near(r.totals.pool, 120.0), "totals: pool = Σ builder pool = 120 (got %s)" % r.totals.pool)
	check(near(r.totals.regen, 14.0), "totals: regen = Σ builder regen = 14 (got %s)" % r.totals.regen)
	check(r.totals.weapon_count == 1, "totals: one weapon counted")

# rifle covered by a more support AND an increased support — increased sums into
# (1+Σinc), more is its own factor; costs multiply.
func _stack_increased_and_more() -> void:
	var placed := [
		{"iid": "br", "def_id": "beam_rifle", "rot": 0, "anchor": Vector2i(0, 3)},
		{"iid": "pc", "def_id": "power_cell", "rot": 0, "anchor": Vector2i(0, 4)},
		{"iid": "ts", "def_id": "targeting_scope", "rot": 0, "anchor": Vector2i(1, 4)},
	]
	var r := BuildResolver.resolve(placed)
	var w: Dictionary = r.weapons["br"]
	# 14 × (1+0.40) × (1+0.30) = 25.48 → 25.5
	check(near(w.damage, 25.5), "stack: 14 ×1.40 ×1.30 = 25.5 (got %s)" % w.damage)
	# 8 × 1.5 × 1.15 = 13.8
	check(near(w.cost, 13.8), "stack: cost 8 ×1.5 ×1.15 = 13.8 (got %s)" % w.cost)
	check(w.contributors.size() == 2, "stack: two supports contribute (got %d)" % w.contributors.size())

# amplifier adds flat damage to a weapon its right-hand buff-slots cover.
func _flat_added() -> void:
	var placed := [
		{"iid": "am", "def_id": "amplifier", "rot": 0, "anchor": Vector2i(0, 0)},
		{"iid": "br", "def_id": "beam_rifle", "rot": 0, "anchor": Vector2i(0, 1)},
	]
	var r := BuildResolver.resolve(placed)
	var w: Dictionary = r.weapons["br"]
	check(near(w.damage, 20.0), "flat: (14+6) = 20.0 (got %s)" % w.damage)
	check(near(w.cost, 10.0), "flat: cost 8 ×1.25 = 10.0 (got %s)" % w.cost)

# a weapon with no support covering it stays at base; no synergies.
func _no_coverage() -> void:
	var placed := [
		{"iid": "br", "def_id": "beam_rifle", "rot": 0, "anchor": Vector2i(0, 0)},
		{"iid": "pc", "def_id": "power_cell", "rot": 0, "anchor": Vector2i(3, 4)},
	]
	var r := BuildResolver.resolve(placed)
	var w: Dictionary = r.weapons["br"]
	check(near(w.damage, 14.0), "no coverage: base 14.0 (got %s)" % w.damage)
	check(near(w.cost, 8.0), "no coverage: base cost 8.0 (got %s)" % w.cost)
	check(not w.buffed, "no coverage: rifle not buffed")
	check(r.synergies.is_empty(), "no coverage: zero synergies")

# same placement → identical result (PvP re-sim guarantee).
func _determinism() -> void:
	var placed := [
		{"iid": "br", "def_id": "beam_rifle", "rot": 0, "anchor": Vector2i(0, 3)},
		{"iid": "pc", "def_id": "power_cell", "rot": 0, "anchor": Vector2i(0, 4)},
		{"iid": "ts", "def_id": "targeting_scope", "rot": 0, "anchor": Vector2i(1, 4)},
	]
	var a := BuildResolver.resolve(placed)
	var b := BuildResolver.resolve(placed)
	check(near(a.weapons["br"].damage, b.weapons["br"].damage)
		and near(a.weapons["br"].cost, b.weapons["br"].cost),
		"determinism: identical placement yields identical effective stats")
