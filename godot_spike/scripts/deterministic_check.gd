# deterministic_check.gd — KM-STACK-SPIKE determinism proof
#
# Runs a pure integer/fixed-point combat simulation from fixed inputs + seed,
# writes a byte-stable JSON event log, then quits.
# No _process, no physics, no animation, no frame-rate dependency.
#
# Usage (normal run):
#   $GODOT --headless --path godot_spike --script res://scripts/deterministic_check.gd \
#          -- --out res://tmp/events_run1.json
#
# Usage (compare two runs):
#   $GODOT --headless --path godot_spike --script res://scripts/deterministic_check.gd \
#          -- --out res://tmp/events_run1.json
#   $GODOT --headless --path godot_spike --script res://scripts/deterministic_check.gd \
#          -- --out res://tmp/events_run2.json
#   diff godot_spike/tmp/events_run1.json godot_spike/tmp/events_run2.json
#   # Expected: no output (files are byte-identical)
#   # => PASS deterministic event log identical
#
# Extends SceneTree so it runs as the main loop when passed via --script.
extends SceneTree

# Fixed inputs — never vary between runs
const FIXED_SEED := 42
const FIXED_BUILDS := [
	{"id": "build_alpha", "power": 120, "armor": 80},
	{"id": "build_beta",  "power": 100, "armor": 100},
]
const MAX_TICKS := 60  # safety ceiling; prevents runaway loops

func _init() -> void:
	var out_path := "res://tmp/events_check.json"

	# Custom args arrive after "--" separator; use get_cmdline_user_args()
	var user_args := OS.get_cmdline_user_args()
	for i in range(user_args.size() - 1):
		if user_args[i] == "--out":
			out_path = user_args[i + 1]
			break

	var events := _run_sim(FIXED_SEED, FIXED_BUILDS)
	var ok := _write_events(events, out_path)
	quit(0 if ok else 1)

# ── pure deterministic simulation ────────────────────────────────────────────
# Integer-only arithmetic; seeded PCG32 RNG (RandomNumberGenerator.seed).
# Same seed → identical randi_range outputs → identical event sequence.

func _run_sim(seed_val: int, builds: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val  # PCG32, reproducible per docs

	var events: Array = []
	var tick := 0

	var hp_a := 1000  # fixed-point: 1000 = full health
	var hp_b := 1000

	var power_a: int = builds[0]["power"]
	var armor_a: int = builds[0]["armor"]
	var power_b: int = builds[1]["power"]
	var armor_b: int = builds[1]["armor"]

	while hp_a > 0 and hp_b > 0 and tick < MAX_TICKS:
		# Integer-only damage formula:
		#   base = power * roll / 100
		#   net  = base - (armor * 20) / 100   (armor reduces by 0–20%)
		#   min  = 5 (always deal something)
		var roll_a: int = rng.randi_range(80, 120)
		var roll_b: int = rng.randi_range(80, 120)

		var dmg_on_b: int = max((power_a * roll_a) / 100 - (armor_b * 20) / 100, 5)
		var dmg_on_a: int = max((power_b * roll_b) / 100 - (armor_a * 20) / 100, 5)

		hp_b -= dmg_on_b
		hp_a -= dmg_on_a

		# Keys in insertion order → JSON key order is deterministic
		events.append({
			"tick":   tick,
			"source": builds[0]["id"],
			"target": builds[1]["id"],
			"roll":   roll_a,
			"dmg":    dmg_on_b,
			"hp_a":   max(hp_a, 0),
			"hp_b":   max(hp_b, 0),
		})
		tick += 1

		events.append({
			"tick":   tick,
			"source": builds[1]["id"],
			"target": builds[0]["id"],
			"roll":   roll_b,
			"dmg":    dmg_on_a,
			"hp_a":   max(hp_a, 0),
			"hp_b":   max(hp_b, 0),
		})
		tick += 1

	var winner: String = builds[0]["id"] if hp_a > 0 else builds[1]["id"]
	events.append({
		"tick":       tick,
		"type":       "result",
		"winner":     winner,
		"final_hp_a": max(hp_a, 0),
		"final_hp_b": max(hp_b, 0),
	})

	return events

# ── file output ───────────────────────────────────────────────────────────────

func _write_events(events: Array, out_path: String) -> bool:
	# Create output directory if it lives inside res://
	var out_dir := out_path.get_base_dir()
	if out_dir.begins_with("res://") and out_dir != "res://":
		var rel := out_dir.substr(6)  # strip "res://"
		var da := DirAccess.open("res://")
		if da:
			da.make_dir_recursive(rel)

	# JSON.stringify with tab indent — deterministic because GDScript Dictionary
	# preserves insertion order, so key sequence is identical across runs.
	var json_text := JSON.stringify(events, "\t")

	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		print("PASS wrote %d events → %s" % [events.size(), out_path])
		return true
	else:
		var err := FileAccess.get_open_error()
		printerr("FAIL cannot write to %s (error %d)" % [out_path, err])
		return false
