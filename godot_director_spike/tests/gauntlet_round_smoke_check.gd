extends SceneTree
## Smoke test: drive one full round programmatically without scene changes.
## step 0  — new run
## step 1  — shop: buy a reactor + a weapon
## step 2  — simulate a fight (win case) directly through BuildFightSim
## step 3  — apply result, advance round
## step 4  — assert gold, hearts, round deltas at each step

const RunState     := preload("res://scripts/gauntlet/run_state.gd")
const ShopState    := preload("res://scripts/gauntlet/shop_state.gd")
const BuildFightSim := preload("res://scripts/build/build_fight_sim.gd")
const OpponentSource := preload("res://scripts/build/opponent_source.gd")

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _log(msg: String) -> void:
	print("  >> ", msg)

func _initialize() -> void:
	_full_round_win()
	_full_round_loss()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

func _full_round_win() -> void:
	print("-- full round (win path) --")
	# step 0: start run
	RunState.new_run("lance", 777)
	ShopState.clear()
	_log("step 0  new_run: gold=%d hearts=%d round=%d" % [RunState.gold, RunState.hearts, RunState.round])
	check(RunState.gold == RunState.STARTING_GOLD, "round smoke win: initial gold")
	check(RunState.hearts == RunState.STARTING_HEARTS, "round smoke win: initial hearts")
	check(RunState.round == 1, "round smoke win: initial round")

	# step 1: shop phase — begin_round + buy reactor + weapon
	ShopState.begin_round(RunState.seed, RunState.round)
	_log("step 1  shop opened: %d offers" % ShopState.shop_offers.size())
	check(ShopState.shop_offers.size() > 0, "round smoke win: shop has offers")

	# Buy the first available reactor from inventory or shop.
	ShopState.add_to_inventory("reactor_core")   # free start item (simulating pilot grant)
	var rifle_iid := ShopState.add_to_inventory("beam_rifle")
	_log("step 1  inventory after grants: %d items" % ShopState.inventory.size())
	check(ShopState.inventory.size() == 2, "round smoke win: 2 items in inventory")

	# step 2: simulate fight using a minimal player build (reactor + rifle)
	var player_placement := [
		{"def_id": "reactor_core", "rot": 0, "anchor": Vector2i(0, 0)},
		{"def_id": "beam_rifle",   "rot": 0, "anchor": Vector2i(0, 2)},
	]
	var player_build := BuildFightSim.build_from_placement(player_placement)
	_log("step 2  player build: pool=%.0f regen=%.0f weapons=%d" % [
		player_build.pool, player_build.regen, player_build.weapons.size()])
	check(player_build.weapons.size() == 1, "round smoke win: player has 1 weapon")
	check(player_build.pool > 0, "round smoke win: player has power pool")

	var ghost := OpponentSource.get_ghost(0)  # GUNLINE ghost (weakest)
	var ghost_build := BuildFightSim.build_from_placement(ghost.placement)
	_log("step 2  ghost '%s': weapons=%d" % [ghost.callsign, ghost_build.weapons.size()])

	var events := BuildFightSim.simulate(player_build, ghost_build, RunState.seed)
	_log("step 2  fight simulated: %d events" % events.size())
	check(events.size() > 0, "round smoke win: fight produced events")

	# Determine outcome — find last 'destroyed' event.
	var player_won := false
	for i in range(events.size() - 1, -1, -1):
		var e: Dictionary = events[i]
		if e.get("kind", "") == "destroyed":
			player_won = (e.get("actor", "") == "B")
			_log("step 2  last destroyed actor=%s → player_won=%s" % [e.actor, str(player_won)])
			break
	# With beam rifle vs GUNLINE, result may vary — just check consistency.
	check(events.size() > 0, "round smoke win: fight events non-empty (player_won=%s)" % str(player_won))

	# step 3: apply result (force win for this branch)
	var gold_before := RunState.gold
	var hearts_before := RunState.hearts
	RunState.apply_win()
	_log("step 3  apply_win: gold %d→%d (+%d)" % [gold_before, RunState.gold, RunState.WIN_GOLD_REWARD])
	check(RunState.gold == gold_before + RunState.WIN_GOLD_REWARD, "round smoke win: gold +WIN_GOLD_REWARD")
	check(RunState.hearts == hearts_before, "round smoke win: hearts unchanged on win")

	RunState.advance_round()
	_log("step 3  advance_round: round=%d" % RunState.round)
	check(RunState.round == 2, "round smoke win: round advanced to 2")
	check(not RunState.run_over(), "round smoke win: run not over yet")

func _full_round_loss() -> void:
	print("-- full round (loss path) --")
	RunState.new_run("vesper", 888)
	ShopState.clear()
	_log("step 0  new_run: gold=%d hearts=%d round=%d" % [RunState.gold, RunState.hearts, RunState.round])

	var gold_before := RunState.gold
	var hearts_before := RunState.hearts
	RunState.apply_loss()
	_log("step 1  apply_loss: gold %d→%d hearts %d→%d" % [gold_before, RunState.gold, hearts_before, RunState.hearts])
	check(RunState.hearts == hearts_before - 1, "round smoke loss: hearts -1")
	check(RunState.gold == gold_before + RunState.LOSS_GOLD_REWARD, "round smoke loss: consolation gold")

	RunState.advance_round()
	check(RunState.round == 2, "round smoke loss: round advanced")
	check(not RunState.run_over(), "round smoke loss: run continues with %d hearts" % RunState.hearts)

	# Drain remaining hearts → run over.
	for _i in (RunState.STARTING_HEARTS - 1):
		RunState.apply_loss()
	_log("step 2  drained hearts: hearts=%d" % RunState.hearts)
	check(RunState.run_over(), "round smoke loss: run_over after all hearts gone")
