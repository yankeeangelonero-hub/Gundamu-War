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
		check(g.os_len == 4.0, "os_len == 4.0")
		check(g.cut_len == 4.0, "cut_len == 4.0")
		check(g.min_iso == 1.0, "min_iso == 1.0")
		check(is_equal_approx(g.camera_min_duration, 1.5), "camera_min_duration == 1.5")
		check(is_equal_approx(g.camera_max_duration, 5.0), "camera_max_duration == 5.0")
		check(is_equal_approx(g.camera_speed_scale, 0.25), "camera_speed_scale == 0.25")
		check(g.dolly_cap == 42.0, "dolly_cap == 42.0")
		check(g.melee_radius_factor == 1.7, "melee_radius_factor == 1.7")
		check(g.feel.has("max_speed") and g.feel.has("gait"), "feel curves present (heft->speed/accel/pose, tempo->gait)")
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
		check(is_equal_approx(g.iso_follow_rate, 1.2), "iso_follow_rate == 1.2")
		check(is_equal_approx(g.iso_dolly_cap, 42.0), "iso_dolly_cap == 42")
		# Per-mode framing table (one representative key each)
		check(g.framing.hero_os.fov == 40.0, "hero_os.fov == 40")
		check(g.framing.hero_cut.roll == -0.05, "hero_cut.roll == -0.05")
		check(g.framing.hero_cut.pullback == 2.0, "hero_cut.pullback == 2")
		check(g.framing.hero_cut.lateral == 9.0, "hero_cut.lateral == 9")
		check(g.framing.hero_cut.height == 5.0, "hero_cut.height == 5")
		check(g.framing.hero_cut.fov == 46.0, "hero_cut.fov == 46")
		check(g.framing.melee_cut.fov == 46.0, "melee_cut.fov == 46 (pulled out to read full mechs)")
		check(g.framing.melee_chase.fov == 50.0, "melee_chase.fov == 50")
		check(g.framing.melee_profile.distance == 44.0, "melee_profile.distance == 44")
		check(g.framing.melee_high.height == 30.0, "melee_high.height == 30")
		check(g.framing.bullet_time.radius == 32.0, "bullet_time.radius == 32")
		# --- Phase 2: Lighting block ---
		check(g.chromatic_fill.is_equal_approx(Color(0.10, 0.12, 0.20)), "chromatic_fill == cool non-black ambient")
		check(is_equal_approx(g.ambient_energy, 1.6), "ambient_energy == 1.6")
		check(is_equal_approx(g.fx_light_energy, 1.0), "fx_light_energy == 1.0")
		# --- Phase 2: Color block (mood variants) ---
		check(is_equal_approx(g.mood_lerp_rate, 1.5), "mood_lerp_rate == 1.5")
		check(g.mood_variants.has("base"), "mood_variants has base")
		check(g.mood_variants.has("hero"), "mood_variants has hero")
		check(g.mood_variants.has("death"), "mood_variants has death")
		var base_m: Dictionary = g.mood_variants["base"]
		check(is_equal_approx(base_m["brightness"], 1.0), "base mood brightness == 1.0 (identity)")
		check(is_equal_approx(base_m["saturation"], 1.0), "base mood saturation == 1.0 (identity)")
		check(is_equal_approx(base_m["warmth"], 0.0), "base mood warmth == 0.0 (neutral)")
		var death_m: Dictionary = g.mood_variants["death"]
		check(death_m["saturation"] < 1.0, "death mood desaturates")
		check(death_m["brightness"] <= 1.0, "death mood never brighter than base")
		var hero_m: Dictionary = g.mood_variants["hero"]
		check(hero_m["warmth"] > 0.0, "hero mood pushes warm")
		# --- Phase 3 Slice 1: time-emphasis arbiter params (Timing block) ---
		check(is_equal_approx(g.hitstop_dur, 0.07), "hitstop_dur == 0.07")
		check(is_equal_approx(g.melee_hitstop_dur, 0.12), "melee_hitstop_dur == 0.12 (clash holds longer)")
		check(is_equal_approx(g.hitstop_threshold, 25.0), "hitstop_threshold == 25.0")
		check(g.impact_frame_len == 2, "impact_frame_len == 2")
		check(is_equal_approx(g.impact_frame_strength, 0.15), "impact_frame_strength == 0.15 (subtle-on)")
		# --- Phase 3 Slice 2: yield-by-class (Spectacle, F17) ---
		check(g.yield_tier("fire_buster") == 3, "fire_buster -> tier 3 (capital)")
		check(g.yield_tier("fire_missiles") == 2, "fire_missiles -> tier 2")
		check(g.yield_tier("fire_beam") == 2, "fire_beam -> tier 2")
		check(g.yield_tier("melee") == 2, "melee -> tier 2")
		check(g.yield_tier("fire_burst") == 1, "fire_burst -> tier 1 (sidearm)")
		check(g.yield_tier("") == 1, "unknown/empty -> tier 1 (safe floor)")
		check(g.yield_tier("nonsense") == 1, "unmapped kind -> tier 1")
		# --- Phase 3 Slice 3: melee framing + occlusion (Composition/Timing) ---
		check(is_equal_approx(g.melee_cut_pre, 0.5), "melee_cut_pre == 0.5")
		check(is_equal_approx(g.melee_cut_post, 1.7), "melee_cut_post == 1.7")
		check(is_equal_approx(g.melee_cut_scale, 0.5), "melee_cut_scale == 0.5")
		check(is_equal_approx(g.melee_cut_spacing, 4.0), "melee_cut_spacing == 4.0")
		# --- Phase 3 Slice 4: compression / Lens (F31) ---
		check(is_equal_approx(float(g.compression_by_mode.get("hero_cut", 0.0)), 0.5), "hero_cut compression == 0.5")
		check(is_equal_approx(float(g.compression_by_mode.get("iso", 0.0)), 0.0), "unmapped mode compression == 0.0")
		check(is_equal_approx(g.compression_fov_floor, 0.5), "compression_fov_floor == 0.5")
		# --- Phase 4/Slice B2: composition search ---
		check(is_equal_approx(g.composition_search_arc, 0.6), "composition_search_arc == 0.6 rad")
		# --- X-ray window occlusion ---
		check(is_equal_approx(g.xray_radius, 14.0), "xray_radius == 14.0")
		check(is_equal_approx(g.xray_softness, 5.0), "xray_softness == 5.0")
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
