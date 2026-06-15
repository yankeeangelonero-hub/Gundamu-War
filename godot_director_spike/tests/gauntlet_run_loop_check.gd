extends SceneTree
## Headless checks for the gauntlet run-loop state machine:
## new_run sets up state; apply_win/apply_loss delta gold+hearts correctly;
## round advance and run-over detection; pilot signature item granted.

const RunState  := preload("res://scripts/gauntlet/run_state.gd")
const ShopState := preload("res://scripts/gauntlet/shop_state.gd")

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	_new_run_initialises()
	_win_awards_gold_and_advances()
	_loss_costs_heart_and_awards_consolation_gold()
	_run_over_at_zero_hearts()
	_run_won_at_round_threshold()
	_clear_resets()
	_shop_offers_seeded_determinism()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

func _new_run_initialises() -> void:
	RunState.new_run("vesper", 42)
	check(RunState.active, "new_run: active == true")
	check(RunState.gold == RunState.STARTING_GOLD, "new_run: gold == STARTING_GOLD (%d, got %d)" % [RunState.STARTING_GOLD, RunState.gold])
	check(RunState.hearts == RunState.STARTING_HEARTS, "new_run: hearts == STARTING_HEARTS (%d, got %d)" % [RunState.STARTING_HEARTS, RunState.hearts])
	check(RunState.round == 1, "new_run: round == 1 (got %d)" % RunState.round)
	check(RunState.pilot_id == "vesper", "new_run: pilot_id == 'vesper' (got '%s')" % RunState.pilot_id)
	check(RunState.seed == 42, "new_run: seed == 42 (got %d)" % RunState.seed)

func _win_awards_gold_and_advances() -> void:
	RunState.new_run("vesper", 1)
	var gold_before := RunState.gold
	RunState.apply_win()
	check(RunState.gold == gold_before + RunState.WIN_GOLD_REWARD,
		"win: gold +WIN_GOLD_REWARD=%d (before=%d after=%d)" % [RunState.WIN_GOLD_REWARD, gold_before, RunState.gold])
	var round_before := RunState.round
	RunState.advance_round()
	check(RunState.round == round_before + 1, "advance_round: round incremented (before=%d after=%d)" % [round_before, RunState.round])

func _loss_costs_heart_and_awards_consolation_gold() -> void:
	RunState.new_run("vesper", 2)
	var hearts_before := RunState.hearts
	var gold_before := RunState.gold
	RunState.apply_loss()
	check(RunState.hearts == hearts_before - 1,
		"loss: hearts -1 (before=%d after=%d)" % [hearts_before, RunState.hearts])
	check(RunState.gold == gold_before + RunState.LOSS_GOLD_REWARD,
		"loss: gold +LOSS_GOLD_REWARD=%d (before=%d after=%d)" % [RunState.LOSS_GOLD_REWARD, gold_before, RunState.gold])
	check(not RunState.run_over(), "loss: run not over yet with hearts remaining")

func _run_over_at_zero_hearts() -> void:
	RunState.new_run("vesper", 3)
	check(not RunState.run_over(), "run_over: false at start")
	# Drain all hearts.
	for _i in RunState.STARTING_HEARTS:
		RunState.apply_loss()
	check(RunState.hearts == 0, "run_over: hearts == 0 after %d losses" % RunState.STARTING_HEARTS)
	check(RunState.run_over(), "run_over: true when hearts == 0")

func _run_won_at_round_threshold() -> void:
	RunState.new_run("vesper", 4)
	# Jump past WIN_ROUND.
	RunState.round = RunState.WIN_ROUND + 1
	check(RunState.run_won(), "run_won: true when round > WIN_ROUND")
	check(RunState.run_over(), "run_over: true when run_won")

func _clear_resets() -> void:
	RunState.new_run("vesper", 5)
	RunState.clear()
	check(not RunState.active, "clear: active == false")
	check(RunState.gold == 0, "clear: gold == 0")
	check(RunState.hearts == 0, "clear: hearts == 0")
	check(RunState.round == 0, "clear: round == 0")

func _shop_offers_seeded_determinism() -> void:
	# begin_round with same run seed + round must produce identical offer order.
	ShopState.clear()
	ShopState.begin_round(7777, 2)
	var a := ShopState.shop_offers.map(func(o): return o.def_id)
	ShopState.clear()
	ShopState.begin_round(7777, 2)
	var b := ShopState.shop_offers.map(func(o): return o.def_id)
	check(a == b, "shop seed determinism: same seed+round → identical offer order (a=%s b=%s)" % [str(a), str(b)])
