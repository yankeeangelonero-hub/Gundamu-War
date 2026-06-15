extends SceneTree
## Headless checks for the gauntlet economy — ShopState buy/sell/reroll gold
## accounting and inventory changes, seeded offer determinism.

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
	_buy_deducts_gold()
	_sell_returns_gold()
	_reroll_costs_gold_and_reshuffles()
	_cannot_buy_when_broke()
	_cannot_reroll_when_broke()
	_offer_seeding_determinism()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

func _setup() -> void:
	ShopState.clear()
	ShopState.begin_round(12345, 1)

func _buy_deducts_gold() -> void:
	_setup()
	var offers_before := ShopState.shop_offers.size()
	check(offers_before > 0, "buy: shop has offers after begin_round")
	var offer: Dictionary = ShopState.shop_offers[0]
	var price: int = offer.price
	var gold := 50
	var result := ShopState.buy(0, gold)
	check(result.ok, "buy: result.ok with sufficient gold (got %s)" % result)
	check(result.gold_spent == price, "buy: gold_spent == offer price %d (got %d)" % [price, result.gold_spent])
	check(ShopState.inventory.has(result.iid), "buy: iid appears in inventory")
	check(ShopState.shop_offers.size() == offers_before - 1, "buy: offer removed from rack")
	check(result.def_id == offer.def_id, "buy: result def_id matches offer")

func _sell_returns_gold() -> void:
	_setup()
	# Manually add an item to inventory.
	var iid := ShopState.add_to_inventory("beam_rifle")
	check(ShopState.has_item(iid), "sell: item in inventory before sell")
	var result := ShopState.sell(iid)
	check(result.ok, "sell: result.ok")
	check(result.gold_gained > 0, "sell: gold_gained > 0 (got %d)" % result.gold_gained)
	check(not ShopState.has_item(iid), "sell: item removed from inventory after sell")
	# beam_rifle price = 5, fraction = 0.5 → refund = 2
	check(result.gold_gained == 2, "sell: beam_rifle refund = floor(5*0.5) = 2 (got %d)" % result.gold_gained)

func _reroll_costs_gold_and_reshuffles() -> void:
	_setup()
	var offers_before := ShopState.shop_offers.duplicate()
	var gold := 20
	var cost := ShopState.reroll(gold)
	check(cost == ShopState.REROLL_COST, "reroll: cost == REROLL_COST (got %d)" % cost)
	check(ShopState.shop_offers.size() > 0, "reroll: offers still non-empty after reroll")
	# Offers may differ — just assert the call succeeded and gold cost is correct.
	check(cost >= 0, "reroll: returned non-negative cost")

func _cannot_buy_when_broke() -> void:
	_setup()
	var offer: Dictionary = ShopState.shop_offers[0]
	var gold: int = int(offer.price) - 1   # one short
	var result := ShopState.buy(0, gold)
	check(not result.ok, "buy broke: result.ok == false when gold < price")
	check(ShopState.shop_offers.size() > 0, "buy broke: offer still on rack")

func _cannot_reroll_when_broke() -> void:
	_setup()
	var gold: int = ShopState.REROLL_COST - 1
	var cost := ShopState.reroll(gold)
	check(cost == -1, "reroll broke: returns -1 when gold < REROLL_COST (got %d)" % cost)

func _offer_seeding_determinism() -> void:
	# Two begin_round calls with the same seed+round must produce identical offers.
	ShopState.clear()
	ShopState.begin_round(99999, 3)
	var offers_a := ShopState.shop_offers.duplicate(true)
	ShopState.clear()
	ShopState.begin_round(99999, 3)
	var offers_b := ShopState.shop_offers.duplicate(true)
	check(offers_a.size() == offers_b.size(), "determinism: same offer count")
	var all_match := true
	for i in offers_a.size():
		if offers_a[i].def_id != offers_b[i].def_id:
			all_match = false
			break
	check(all_match, "determinism: identical offer sequence for same seed+round")
	# Different rounds must differ.
	ShopState.clear()
	ShopState.begin_round(99999, 4)
	var offers_c := ShopState.shop_offers.duplicate(true)
	# It's extremely unlikely round 3 and 4 match — assert they don't all match.
	var any_diff := false
	for i in mini(offers_a.size(), offers_c.size()):
		if offers_a[i].def_id != offers_c[i].def_id:
			any_diff = true
			break
	check(any_diff, "determinism: different round → different offers")
