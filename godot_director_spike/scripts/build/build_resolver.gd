extends RefCounted
## BuildResolver — pure resolution of a placement into per-weapon effective stats
## and the build's power totals. No rendering, no randomness: the same placement
## always yields the identical result, so the M0 sim can re-derive it from data.
##
## Per spec (docs/.../2026-06-14-m1-build-grid-and-power-economy-design.md §3):
##   effective_damage = (base_damage + Σ flat_added) × (1 + Σ increased) × Π (1 + more_k)
##   effective_cost   = base_power_cost × Π cost_multiplier
##   total_pool = Σ builder pool ;  total_regen = Σ builder regen
## A support covers a weapon when any of the support's (rotated) buff-slots lands
## on any cell the weapon occupies.

const BuildData := preload("build_data.gd")

## placed: Array of { iid, def_id, rot, anchor: Vector2i }. (Extra keys ignored.)
## Returns { weapons, supports, builders, synergies, totals }.
static func resolve(placed: Array) -> Dictionary:
	var weapons: Dictionary = {}    # iid -> { def, cells: Dictionary(cell->true) }
	var supports: Array = []        # { iid, def, buff: Dictionary(cell->true) }
	var total_pool := 0.0
	var total_regen := 0.0

	for p in placed:
		var def := BuildData.get_def(p.def_id)
		match def.get("kind", ""):
			"builder":
				total_pool += float(def.get("pool", 0))
				total_regen += float(def.get("regen", 0))
			"spender":
				var cells := {}
				for cell in BuildData.placed_cells(def, p.rot, p.anchor):
					cells[cell] = true
				weapons[p.iid] = {"def": def, "cells": cells}
			"support":
				var buff := {}
				for cell in BuildData.buff_cells(def, p.rot, p.anchor):
					buff[cell] = true
				supports.append({"iid": p.iid, "def": def, "buff": buff})

	var eff: Dictionary = {}
	var synergies: Array = []

	for wid in weapons:
		var w: Dictionary = weapons[wid]
		var def: Dictionary = w.def
		var base_dmg := float(def.get("base_damage", 0))
		var base_cost := float(def.get("base_power_cost", 0))

		var flat := 0.0
		var inc := 0.0
		var more_factors := 1.0
		var cost_mult := 1.0
		var contributors: Array = []

		for s in supports:
			if not _covers(s.buff, w.cells):
				continue
			var sd: Dictionary = s.def
			flat += float(sd.get("flat_added", 0))
			inc += float(sd.get("increased", 0.0))
			var more: float = float(sd.get("more", 0.0))
			if more != 0.0:
				more_factors *= (1.0 + more)
			cost_mult *= float(sd.get("cost_multiplier", 1.0))
			contributors.append(s.iid)
			synergies.append({
				"support_iid": s.iid, "weapon_iid": wid,
				"support_code": sd.get("code", "?"), "weapon_name": def.get("name", "?"),
				"text": "%s → %s: %s" % [sd.get("code", "?"), def.get("name", "?"), _mod_text(sd)],
			})

		var damage := (base_dmg + flat) * (1.0 + inc) * more_factors
		var cost := base_cost * cost_mult
		eff[wid] = {
			"damage": snappedf(damage, 0.1),
			"cost": snappedf(cost, 0.1),
			"base_damage": base_dmg,
			"base_cost": base_cost,
			"buffed": not contributors.is_empty(),
			"contributors": contributors,
		}

	var firepower := 0.0
	var burst_cost := 0.0
	for wid in eff:
		firepower += eff[wid].damage
		burst_cost += eff[wid].cost

	return {
		"weapons": eff,
		"synergies": synergies,
		"totals": {
			"pool": snappedf(total_pool, 0.1),
			"regen": snappedf(total_regen, 0.1),
			"weapon_count": weapons.size(),
			"firepower": snappedf(firepower, 0.1),
			"burst_cost": snappedf(burst_cost, 0.1),
		},
	}

## True if any buff cell coincides with any weapon cell.
static func _covers(buff: Dictionary, cells: Dictionary) -> bool:
	for cell in buff:
		if cells.has(cell):
			return true
	return false

## Short human-readable modifier summary for a support def (for the synergy list).
static func _mod_text(sd: Dictionary) -> String:
	var parts: Array = []
	if float(sd.get("flat_added", 0)) != 0:
		parts.append("+%d DMG" % int(sd.flat_added))
	if float(sd.get("increased", 0.0)) != 0.0:
		parts.append("+%d%% increased" % roundi(float(sd.increased) * 100.0))
	if float(sd.get("more", 0.0)) != 0.0:
		parts.append("%d%% more" % roundi(float(sd.more) * 100.0))
	var cm := float(sd.get("cost_multiplier", 1.0))
	if cm != 1.0:
		parts.append("×%.2f cost" % cm)
	return ", ".join(parts) if not parts.is_empty() else "—"
