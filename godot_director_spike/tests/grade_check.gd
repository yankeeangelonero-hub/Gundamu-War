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
	check(is_equal_approx(live_env.ambient_light_energy, g.ambient_energy),
		"grade owns ambient energy on the live env (A1)")
	host.queue_free()

	# --- beat -> mood mapping ---
	# Event kinds verified against data/fight_log_everything.json + garnish.gd/director.gd
	# readers (codex #6): fire_buster / destroyed / fire_beam+payload.lethal are real kinds.
	check(grade.mood_for_event({"kind": "fire_buster"}) == "hero", "buster -> hero mood")
	check(grade.mood_for_event({"kind": "destroyed"}) == "death", "destroyed -> death mood")
	check(grade.mood_for_event({"kind": "advance"}) == "", "advance -> no mood change")
	check(grade.mood_for_event({"kind": "fire_beam", "payload": {"lethal": true}}) == "death",
		"lethal beam -> death mood")
	check(grade.mood_for_event({"kind": "fire_beam", "payload": {}}) == "",
		"ordinary beam -> no mood change")
	# codex #9: malformed payload must not crash and must read as no-mood.
	check(grade.mood_for_event({"kind": "fire_beam"}) == "", "beam with no payload -> no mood")
	check(grade.mood_for_event({"kind": "fire_beam", "payload": 7}) == "", "beam with non-dict payload -> no mood")

	# --- lerp eases toward target, clamped, deterministic ---
	grade.apply_base()
	grade.set_mood("death")
	for i in 200:
		grade.tick(1.0 / 60.0)   # ~3.3s of eased stepping
	check(env.adjustment_saturation < 0.6, "lerp reaches near death saturation")
	check(env.adjustment_saturation >= 0.55, "lerp never overshoots target")
	check(env.adjustment_brightness <= 1.0, "death never brightens past base")

	# --- F22: ambient fill is never crushed to black, even with a black grammar fill ---
	var black_g = ShotGrammarScript.default()
	black_g.chromatic_fill = Color(0.0, 0.0, 0.0)
	var benv := _make_env()
	var bgrade = Grade.new()
	bgrade.bind(benv, black_g)
	bgrade.apply_base()
	check(benv.ambient_light_color.v >= 0.029, "F22: black chromatic_fill is floored to non-black (base)")
	for mood_name in black_g.mood_variants.keys():
		bgrade.set_mood(mood_name)
		# write the target immediately (no easing) by ticking with k=1
		bgrade.tick(1000.0)
		check(benv.ambient_light_color.v >= 0.029, "F22: mood '%s' ambient stays non-black" % mood_name)

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
