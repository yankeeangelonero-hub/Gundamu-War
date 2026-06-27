extends RefCounted
## Pure candidate-vs-baseline matrix report for the CF-FIREWORKS slice.
##
## SpectacleProfile measures one log; SpectacleReport aggregates a whole archetype/opponent
## matrix against the fireworks-floor baseline and emits one report artifact (matrix dict +
## text table + JSON). It owns no thresholds of its own — every cell verdict comes from
## SpectacleProfile.compare(), so the report stays a measurement layer, not a tuning layer.

const Profile := preload("res://scripts/sim/spectacle_profile.gd")


## baseline: a profile dict (from SpectacleProfile.profile).
## candidates: Array of { "label": String, "profile": Dictionary } cells.
## options: forwarded to SpectacleProfile.compare (floor overrides).
static func build(baseline: Dictionary, candidates: Array, options := {}) -> Dictionary:
	var cells := []
	var pass_count := 0
	var floors := {}
	for entry in candidates:
		var cell_in: Dictionary = entry if entry is Dictionary else {}
		var profile: Dictionary = cell_in.get("profile", {}) if cell_in.get("profile", {}) is Dictionary else {}
		var comparison: Dictionary = Profile.compare(profile, baseline, options)
		floors = comparison.get("floors", floors)
		var passes := bool(comparison.get("passes", false))
		if passes:
			pass_count += 1
		cells.append({
			"label": str(cell_in.get("label", str(profile.get("log_id", "")))),
			"candidate_id": str(profile.get("log_id", "")),
			"matchup_shape": str(profile.get("matchup_shape", "unclassified")),
			"passes": passes,
			"checks": comparison.get("checks", {}),
			"notes": comparison.get("notes", []),
			"metrics": _cell_metrics(profile),
		})
	var cell_count := cells.size()
	return {
		"schema": "km-spectacle-report-v0",
		"baseline_id": str(baseline.get("log_id", "")),
		"cell_count": cell_count,
		"pass_count": pass_count,
		"fail_count": cell_count - pass_count,
		"all_pass": cell_count > 0 and pass_count == cell_count,
		"floors": floors,
		"cells": cells,
	}


static func format_report(report: Dictionary) -> String:
	var cells: Array = report.get("cells", []) if report.get("cells", []) is Array else []
	var lines := []
	lines.append("SPECTACLE REPORT — baseline %s" % str(report.get("baseline_id", "")))
	lines.append("%d/%d cells pass the fireworks floor" % [int(report.get("pass_count", 0)), int(report.get("cell_count", 0))])
	var floors: Dictionary = report.get("floors", {}) if report.get("floors", {}) is Dictionary else {}
	if not floors.is_empty():
		lines.append("floors: density>=%.2f/s  dead-air<=%.1fs  weapons>=%d" % [
			float(floors.get("attack_density_per_sec", 0.0)),
			float(floors.get("dead_air_limit_sec", 0.0)),
			int(floors.get("min_weapon_kinds", 0)),
		])
	lines.append("")
	for cell in cells:
		var c: Dictionary = cell if cell is Dictionary else {}
		var metrics: Dictionary = c.get("metrics", {}) if c.get("metrics", {}) is Dictionary else {}
		lines.append("[%s] %s" % ["PASS" if bool(c.get("passes", false)) else "FAIL", str(c.get("label", ""))])
		lines.append("       %.1fs | %d atk | %.2f/s | dead %.1fs | %d weapons | finish %s" % [
			float(metrics.get("duration_sec", 0.0)),
			int(metrics.get("attack_count", 0)),
			float(metrics.get("attack_density_per_sec", 0.0)),
			float(metrics.get("longest_dead_air_sec", 0.0)),
			int(metrics.get("weapon_kind_count", 0)),
			str(metrics.get("finisher_kind", "none")),
		])
		var notes: Array = c.get("notes", []) if c.get("notes", []) is Array else []
		if not bool(c.get("passes", false)) and not notes.is_empty():
			lines.append("       ! %s" % ", ".join(notes))
	return "\n".join(lines)


static func to_json(report: Dictionary) -> String:
	return JSON.stringify(report, "  ")


static func _cell_metrics(profile: Dictionary) -> Dictionary:
	var finisher: Dictionary = profile.get("finisher", {}) if profile.get("finisher", {}) is Dictionary else {}
	return {
		"duration_sec": float(profile.get("duration_sec", 0.0)),
		"attack_count": int(profile.get("attack_count", 0)),
		"attack_density_per_sec": float(profile.get("attack_density_per_sec", 0.0)),
		"longest_dead_air_sec": float(profile.get("longest_dead_air_sec", 0.0)),
		"weapon_kind_count": int(profile.get("weapon_kind_count", 0)),
		"heavy_beat_count": int(profile.get("heavy_beat_count", 0)),
		"finisher_kind": str(finisher.get("kind", "none")),
		"finisher_lethal": bool(finisher.get("lethal", false)),
	}
