extends SceneTree

const DATA_PATH := "res://data/deploy_parts.json"
const DeploySliceCore = preload("res://scripts/deploy_slice_core.gd")
const MODE_SAFE := "safe"
const MODE_PUSH := "push"

func _init() -> void:
	var out_path: String = "res://tmp/deploy_check.json"
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(user_args.size() - 1):
		if user_args[i] == "--out":
			out_path = user_args[i + 1]
			break

	var core = DeploySliceCore.new()
	if core == null:
		printerr("FAIL deploy core could not be instantiated.")
		quit(1)
		return

	var catalog: Dictionary = core.load_catalog(DATA_PATH)
	if catalog.is_empty():
		printerr("FAIL deploy catalog missing or invalid.")
		quit(1)
		return

	var default_selection: Dictionary = core.get_default_selection(catalog)
	var high_weapon_selection: Dictionary = default_selection.duplicate(true)
	high_weapon_selection["weapon"] = "heavy_saber"

	var stretched_push_selection: Dictionary = default_selection.duplicate(true)
	stretched_push_selection["weapon"] = "heavy_saber"

	var over_push_selection: Dictionary = default_selection.duplicate(true)
	over_push_selection["weapon"] = "heavy_saber"
	over_push_selection["booster"] = "high_output_booster"
	over_push_selection["armor"] = "heavy_shield"

	var fixed_run_a: Dictionary = core.run_deploy(catalog, stretched_push_selection, MODE_PUSH)
	var fixed_run_b: Dictionary = core.run_deploy(catalog, stretched_push_selection, MODE_PUSH)
	var fixed_json_a: String = JSON.stringify(fixed_run_a, "\t")
	var fixed_json_b: String = JSON.stringify(fixed_run_b, "\t")
	var fixed_equal: bool = fixed_json_a == fixed_json_b

	var default_forecast: Dictionary = core.forecast_fit(catalog, default_selection)
	var high_weapon_forecast: Dictionary = core.forecast_fit(catalog, high_weapon_selection)
	var safe_run: Dictionary = core.run_deploy(catalog, default_selection, MODE_SAFE)
	var push_run: Dictionary = fixed_run_a
	var over_run: Dictionary = core.run_deploy(catalog, over_push_selection, MODE_PUSH)

	var safe_result: Dictionary = safe_run.get("result", {})
	var push_result: Dictionary = push_run.get("result", {})
	var over_result: Dictionary = over_run.get("result", {})

	var payload: Dictionary = {
		"summary": {
			"slice": "KM-DEPLOY",
			"seed": int(catalog.get("seed", 0)),
			"deterministic_repeat_equal": fixed_equal,
			"no_permanent_pilot_harm_all_cases": bool(safe_result.get("no_permanent_pilot_harm", false)) and bool(push_result.get("no_permanent_pilot_harm", false)) and bool(over_result.get("no_permanent_pilot_harm", false)),
		},
		"ac_1_editable_parts_change_fit": {
			"default_selection": default_selection,
			"default_forecast": _public_forecast(default_forecast),
			"high_weapon_selection": high_weapon_selection,
			"high_weapon_forecast": _public_forecast(high_weapon_forecast),
			"demand_changed": int(high_weapon_forecast.get("demand", 0)) != int(default_forecast.get("demand", 0)),
			"state_changed": str(high_weapon_forecast.get("state", "")) != str(default_forecast.get("state", "")),
		},
		"ac_2_safe_deploy_modest": safe_run,
		"ac_3_push_deploy_different": {
			"safe_result": safe_result,
			"push_result": push_result,
			"push_run": push_run,
			"actual_numbers_differ": JSON.stringify(safe_result, "\t") != JSON.stringify(push_result, "\t"),
		},
		"ac_4_repeat_same_seed": {
			"fixed_input_a": fixed_run_a.get("input", {}),
			"fixed_input_b": fixed_run_b.get("input", {}),
			"event_logs_equal": JSON.stringify(fixed_run_a.get("events", []), "\t") == JSON.stringify(fixed_run_b.get("events", []), "\t"),
			"full_runs_equal": fixed_equal,
		},
		"ac_5_underperformance_positive_valence": {
			"over_demanding_selection": over_push_selection,
			"over_demanding_run": over_run,
			"result_explanation": str(over_result.get("explanation", "")),
			"pilot_harm": str(over_result.get("pilot_harm", "")),
			"no_permanent_pilot_harm": bool(over_result.get("no_permanent_pilot_harm", false)),
		},
	}

	var ok: bool = _write_json(payload, out_path)
	if not fixed_equal:
		printerr("FAIL fixed deploy run was not deterministic.")
		quit(1)
		return
	if not ok:
		quit(1)
		return
	print("PASS KM-DEPLOY deterministic check wrote " + out_path)
	quit(0)

func _public_forecast(forecast: Dictionary) -> Dictionary:
	return {
		"state": str(forecast.get("state", "")),
		"label": str(forecast.get("label", "")),
		"demand": int(forecast.get("demand", 0)),
		"capacity": int(forecast.get("capacity", 0)),
		"margin": int(forecast.get("margin", 0)),
		"explanation": str(forecast.get("explanation", "")),
	}

func _write_json(payload: Dictionary, out_path: String) -> bool:
	var out_dir: String = out_path.get_base_dir()
	if out_dir.begins_with("res://") and out_dir != "res://":
		var rel: String = out_dir.substr(6)
		var da: DirAccess = DirAccess.open("res://")
		if da:
			da.make_dir_recursive(rel)

	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if not file:
		printerr("FAIL cannot write to %s (error %d)" % [out_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true
