extends SceneTree
## Headless check for the debug director tuning panel. This keeps the debug-only
## UI script parseable and verifies that its live controls emit the expected
## tuning signals without launching the full viewer.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func _initialize() -> void:
	var DebugDirector := load("res://scripts/debug_director.gd")
	var ShotGrammar := load("res://scripts/director/shot_grammar.gd")
	check(DebugDirector != null, "debug_director.gd loads")
	if DebugDirector == null:
		_finish()
		return
	var panel = DebugDirector.new()
	root.add_child(panel)
	await process_frame
	panel.configure(ShotGrammar.default(), {"A": {"heft": 0.2, "tempo": 0.8}}, {"hero_os": true})
	var hits := {"grammar": 0, "feel": 0, "shot": 0}
	panel.grammar_number_changed.connect(func(property_name: String, value: float) -> void:
		if property_name == "os_len" and is_equal_approx(value, 2.25):
			hits.grammar += 1
		if property_name == "camera_speed_scale" and is_equal_approx(value, 1.35):
			hits.grammar += 1
	)
	panel.feel_number_changed.connect(func(actor: String, property_name: String, value: float) -> void:
		if actor == "A" and property_name == "heft" and is_equal_approx(value, 0.65):
			hits.feel += 1
	)
	panel.shot_mode_changed.connect(func(mode: String, enabled: bool) -> void:
		if mode == "hero_os" and enabled == false:
			hits.shot += 1
	)
	var sliders: Dictionary = panel.get("_sliders")
	var checks: Dictionary = panel.get("_shot_checks")
	var os_slider: HSlider = sliders["grammar:os_len"] as HSlider
	var speed_slider: HSlider = sliders["grammar:camera_speed_scale"] as HSlider
	var heft_slider: HSlider = sliders["feel:A:heft"] as HSlider
	var hero_os: CheckBox = checks["hero_os"] as CheckBox
	check(sliders.has("grammar:camera_min_duration"), "camera min duration slider exists")
	check(sliders.has("grammar:camera_max_duration"), "camera max duration slider exists")
	check(sliders.has("grammar:camera_speed_scale"), "camera speed slider exists")
	check(os_slider.get_signal_connection_list("value_changed").size() > 0,
		"camera slider has a value_changed handler")
	check(speed_slider.get_signal_connection_list("value_changed").size() > 0,
		"camera speed slider has a value_changed handler")
	check(heft_slider.get_signal_connection_list("value_changed").size() > 0,
		"feel slider has a value_changed handler")
	check(hero_os.get_signal_connection_list("toggled").size() > 0,
		"shot toggle has a toggled handler")
	check(panel.get_signal_connection_list("grammar_number_changed").size() > 0,
		"panel grammar signal has a test listener")
	check(panel.get("_suppress") == false, "panel leaves configure unsuppressed")
	var os_callable: Callable = os_slider.get_signal_connection_list("value_changed")[0].callable
	var speed_callable: Callable = speed_slider.get_signal_connection_list("value_changed")[0].callable
	var heft_callable: Callable = heft_slider.get_signal_connection_list("value_changed")[0].callable
	var shot_callable: Callable = hero_os.get_signal_connection_list("toggled")[0].callable
	check(os_callable.is_valid(), "camera slider callable is valid")
	check(speed_callable.is_valid(), "camera speed slider callable is valid")
	check(heft_callable.is_valid(), "feel slider callable is valid")
	check(shot_callable.is_valid(), "shot toggle callable is valid")
	os_callable.call(2.25)
	speed_callable.call(1.35)
	heft_callable.call(0.65)
	shot_callable.call(false)
	check(hits.grammar == 2, "camera sliders emit grammar_number_changed")
	check(hits.feel == 1, "feel slider emits feel_number_changed")
	check(hits.shot == 1, "shot toggle emits shot_mode_changed")
	panel.queue_free()
	_finish()

func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
