extends SceneTree
## Unit test for FeelProfile (spec: docs/superpowers/specs/2026-06-18-feel-profile-design.md):
## a PURE function of a build's resolved feel-stats -> a per-mech bias bundle
## {heft, tempo, mode_mix}. Verifies determinism, monotonicity (directions pinned),
## bounds, the empty/zero-damage fallback, and outcome-independence. No combat truth.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func approx(a: float, b: float) -> bool:
	return abs(a - b) < 1e-6

# --- fixture helpers (ResolvedBuildFeelStats shape) ------------------------------
func weapon(cooldown: float, damage: float, mode_weights: Dictionary) -> Dictionary:
	return {"cooldown": cooldown, "damage": damage, "feel_mode_weights": mode_weights}

func build(total_weight: float, armor: float, weapons: Array) -> Dictionary:
	return {"total_weight": total_weight, "armor": armor, "weapons": weapons}

func mode_sum(mix: Dictionary) -> float:
	var s := 0.0
	for k in mix:
		s += float(mix[k])
	return s

func _init() -> void:
	var F := load("res://scripts/sim/feel_profile.gd")
	check(F != null, "feel_profile.gd loads")
	if F == null:
		print("---- %d FAIL" % maxi(fails, 1))
		quit(1)
		return

	var ranged_w := {"ranged": 1.0}
	var melee_w := {"melee": 1.0}

	# A representative mid build: one ranged + one melee weapon.
	var mid := build(100.0, 40.0, [
		weapon(1.0, 80.0, ranged_w),
		weapon(0.8, 40.0, melee_w),
	])
	var p: Dictionary = F.derive(mid)

	# shape
	check(p.has("heft") and p.has("tempo") and p.has("mode_mix"), "derive returns heft/tempo/mode_mix")

	# bounds
	check(p.heft >= 0.0 and p.heft <= 1.0, "heft in [0,1]")
	check(p.tempo >= 0.0 and p.tempo <= 1.0, "tempo in [0,1]")
	check(approx(mode_sum(p.mode_mix), 1.0), "mode_mix normalized to sum 1")

	# determinism — same build, same profile (Godot Dictionary == is by value)
	check(F.derive(mid) == F.derive(mid), "derive is pure/deterministic")

	# monotonic heft — heavier build never lowers heft
	var light := build(50.0, 0.0, [weapon(1.0, 80.0, ranged_w)])
	var heavy := build(180.0, 80.0, [weapon(1.0, 80.0, ranged_w)])
	check(F.derive(heavy).heft >= F.derive(light).heft, "heavier build => heft non-decreasing")

	# monotonic tempo — faster cooldown never lowers tempo
	var slow := build(100.0, 0.0, [weapon(2.0, 80.0, ranged_w)])
	var fast := build(100.0, 0.0, [weapon(0.4, 80.0, ranged_w)])
	check(F.derive(fast).tempo >= F.derive(slow).tempo, "faster cooldown => tempo non-decreasing")

	# monotonic mode — adding a melee weapon never lowers the melee weight
	var ranged_only := build(100.0, 0.0, [weapon(1.0, 80.0, ranged_w)])
	var ranged_plus_melee := build(100.0, 0.0, [
		weapon(1.0, 80.0, ranged_w),
		weapon(1.0, 80.0, melee_w),
	])
	check(float(F.derive(ranged_plus_melee).mode_mix.get("melee", 0.0)) >= float(F.derive(ranged_only).mode_mix.get("melee", 0.0)),
		"adding melee weapon => melee weight non-decreasing")

	# tempo independent of heft — a heavy build can fire fast
	var heavy_fast := build(180.0, 80.0, [weapon(0.4, 80.0, ranged_w)])
	check(F.derive(heavy_fast).tempo >= F.derive(slow).tempo, "heavy build can still be high-tempo (axes independent)")

	# empty build fallback — tempo 0, neutral uniform mode_mix, heft still valid
	var empty := build(120.0, 50.0, [])
	var pe: Dictionary = F.derive(empty)
	check(approx(pe.tempo, 0.0), "empty build => tempo 0")
	check(approx(float(pe.mode_mix.get("ranged", -1.0)), 1.0 / 3.0)
		and approx(float(pe.mode_mix.get("melee", -1.0)), 1.0 / 3.0)
		and approx(float(pe.mode_mix.get("barrage", -1.0)), 1.0 / 3.0),
		"empty build => uniform mode_mix (1/3 each)")
	check(pe.heft >= 0.0 and pe.heft <= 1.0, "empty build => heft still in [0,1]")

	# zero-damage build behaves like empty (no positive damage share to weight)
	var zero_dmg := build(120.0, 50.0, [weapon(1.0, 0.0, ranged_w), weapon(0.8, 0.0, melee_w)])
	var pz: Dictionary = F.derive(zero_dmg)
	check(approx(pz.tempo, 0.0), "zero-damage build => tempo 0")
	check(approx(mode_sum(pz.mode_mix), 1.0) and approx(float(pz.mode_mix.get("melee", -1.0)), 1.0 / 3.0),
		"zero-damage build => uniform mode_mix")

	# outcome-independence — extra non-stat fields (e.g. a 'winner') are ignored;
	# the profile reads only the build's feel-stats, never an outcome.
	var with_outcome := mid.duplicate(true)
	with_outcome["winner"] = "left"
	with_outcome["hp_remaining"] = 17
	check(F.derive(with_outcome) == F.derive(mid), "ignores non-stat/outcome fields (outcome-independent)")

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
