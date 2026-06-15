extends SceneTree
## Headless check: ShotGrammar.default() returns the current shipped grammar values.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	var ShotGrammar := load("res://scripts/director/shot_grammar.gd")
	check(ShotGrammar != null, "shot_grammar.gd loads")
	if ShotGrammar != null:
		var g = ShotGrammar.default()
		check(g != null, "default() returns an instance")
		# Timing
		check(g.os_len == 1.8, "os_len == 1.8")
		check(g.cut_len == 1.8, "cut_len == 1.8")
		check(g.bt_pre == 0.2, "bt_pre == 0.2")
		check(g.bt_post == 0.55, "bt_post == 0.55")
		check(g.bt_scale == 0.07, "bt_scale == 0.07")
		# Composition / iso
		check(g.iso_offset == Vector3(-45, 90, 18), "iso_offset == (-45,90,18)")
		check(g.iso_zoom_min == 50.0, "iso_zoom_min == 50")
		check(g.iso_zoom_max == 118.0, "iso_zoom_max == 118")
		check(g.iso_zoom_factor == 0.7, "iso_zoom_factor == 0.7")
		check(g.iso_zoom_base == 30.0, "iso_zoom_base == 30")
		check(g.aftermath_zoom == 58.0, "aftermath_zoom == 58")
		# Per-mode framing table (one representative key each)
		check(g.framing.hero_os.fov == 40.0, "hero_os.fov == 40")
		check(g.framing.hero_cut.roll == -0.05, "hero_cut.roll == -0.05")
		check(g.framing.melee_cut.fov == 36.0, "melee_cut.fov == 36")
		check(g.framing.bullet_time.radius == 32.0, "bullet_time.radius == 32")
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
