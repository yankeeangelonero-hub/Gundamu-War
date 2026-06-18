extends RefCounted
## FeelProfile — the per-build presentation lean.
## Spec: docs/superpowers/specs/2026-06-18-feel-profile-design.md
##
## A PURE, deterministic function of a build's resolved feel-stats -> a per-mech bias
## bundle {heft, tempo, mode_mix}. It is cosmetic, never combat truth, never in the log,
## and is never read by the sim (outcome-independent). Consumers (Director Grammar,
## Choreographer) apply it as a bias on top of their own params; this never writes them.
##
## Input (ResolvedBuildFeelStats), supplied by the backpack `resolve(build)` seam:
##   { total_weight: float, armor: float,
##     weapons: [ { cooldown: float, damage: float, feel_mode_weights: { <mode>: float } } ] }
##   `damage` is the weapon's resolved PRE-SIM expected damage, never observed fight-log damage.

## The v1 exchange-mode basis for the neutral fallback. The mechanism stays open: a build's
## mode_mix keys come from the weapons' own feel_mode_weights, so new modes need no change here.
const V1_MODES := ["ranged", "melee", "barrage"]

## Normalization references. Directions are pinned by the spec; these magnitudes are
## look-lock tuning, not frozen — only the monotonic ordering and [0,1] bounds are contractual.
const HEFT_REF_MIN := 0.0
const HEFT_REF_MAX := 300.0   # total_weight + armor
const TEMPO_REF_MIN := 0.0
const TEMPO_REF_MAX := 3.0    # damage-weighted mean of 1/cooldown (≈ shots/sec)


static func derive(build: Dictionary) -> Dictionary:
	return {
		"heft": _heft(build),
		"tempo": _tempo(build),
		"mode_mix": _mode_mix(build),
	}


static func _heft(build: Dictionary) -> float:
	var metric: float = float(build.get("total_weight", 0.0)) + float(build.get("armor", 0.0))
	return clampf((metric - HEFT_REF_MIN) / (HEFT_REF_MAX - HEFT_REF_MIN), 0.0, 1.0)


static func _tempo(build: Dictionary) -> float:
	var weighted_rate := 0.0
	var total_damage := 0.0
	for w in build.get("weapons", []):
		var damage: float = float(w.get("damage", 0.0))
		var cooldown: float = float(w.get("cooldown", 0.0))
		if damage <= 0.0 or cooldown <= 0.0:
			continue
		weighted_rate += damage * (1.0 / cooldown)
		total_damage += damage
	if total_damage <= 0.0:
		return 0.0  # empty / zero-damage build: deterministic neutral
	var fire_rate := weighted_rate / total_damage
	return clampf((fire_rate - TEMPO_REF_MIN) / (TEMPO_REF_MAX - TEMPO_REF_MIN), 0.0, 1.0)


static func _mode_mix(build: Dictionary) -> Dictionary:
	# Aggregate each weapon's own (open) mode-weight map, weighted by its resolved
	# damage share. Never switch-matches weapon classes, so the mode set stays open.
	var acc := {}
	for w in build.get("weapons", []):
		var damage: float = float(w.get("damage", 0.0))
		if damage <= 0.0:
			continue
		for mode in w.get("feel_mode_weights", {}):
			acc[mode] = float(acc.get(mode, 0.0)) + damage * float(w["feel_mode_weights"][mode])
	var total := 0.0
	for mode in acc:
		total += float(acc[mode])
	if total <= 0.0:
		return _uniform_mix()  # empty / zero-damage / mode-less build: neutral uniform
	var mix := {}
	for mode in acc:
		mix[mode] = float(acc[mode]) / total
	return mix


static func _uniform_mix() -> Dictionary:
	var w := 1.0 / float(V1_MODES.size())
	var mix := {}
	for mode in V1_MODES:
		mix[mode] = w
	return mix
