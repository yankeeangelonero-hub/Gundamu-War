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

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
