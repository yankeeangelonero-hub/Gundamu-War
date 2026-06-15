extends RefCounted
## ShopState — the economy layer for a run: inventory, shop offers, buy/sell/reroll.
##
## Inventory: items the player OWNS. Only owned items can be placed in the grid.
## Shop offers: a rack of N items drawn from the shop table, seeded from (run seed,
## round, reroll count) so the same run always offers the same sequence.
## All gold changes go through this module. No rendering.

const BuildData := preload("res://scripts/build/build_data.gd")

const SHOP_SIZE     := 4
const REROLL_COST   := 2
const SELL_FRACTION := 0.5   # sell returns floor(buy_price * SELL_FRACTION)

## { instance_id -> { def_id, locked } }  — locked items won't merge (P2 recipes).
static var inventory: Dictionary = {}
## Current shop rack: Array of { def_id, price }.
static var shop_offers: Array = []

static var _inv_counter := 0
static var _reroll_count := 0

## Seed the offer generator for this round.
static var _offer_seed := 0

# ---- lifecycle ---------------------------------------------------------------

static func begin_round(run_seed: int, round: int) -> void:
	_reroll_count = 0
	_offer_seed = _mix(run_seed, round)
	_draw_offers()

static func clear() -> void:
	inventory.clear()
	shop_offers.clear()
	_inv_counter = 0
	_reroll_count = 0
	_offer_seed = 0

# ---- inventory ---------------------------------------------------------------

static func add_to_inventory(def_id: String) -> String:
	_inv_counter += 1
	var iid := "inv_%d" % _inv_counter
	inventory[iid] = {"def_id": def_id, "locked": false}
	return iid

static func remove_from_inventory(iid: String) -> void:
	inventory.erase(iid)

static func has_item(iid: String) -> bool:
	return inventory.has(iid)

static func item_def_id(iid: String) -> String:
	return inventory.get(iid, {}).get("def_id", "")

## All inventory item def_ids (for grid seeding / display).
static func inventory_def_ids() -> Array:
	var out: Array = []
	for iid in inventory:
		out.append(inventory[iid].def_id)
	return out

static func set_locked(iid: String, locked: bool) -> void:
	if inventory.has(iid):
		inventory[iid].locked = locked

static func is_locked(iid: String) -> bool:
	return inventory.get(iid, {}).get("locked", false)

# ---- shop --------------------------------------------------------------------

## Buy the item at offer index. Returns true + deducts gold if affordable.
static func buy(offer_idx: int, gold: int) -> Dictionary:
	if offer_idx < 0 or offer_idx >= shop_offers.size():
		return {"ok": false, "reason": "invalid offer index"}
	var offer: Dictionary = shop_offers[offer_idx]
	if gold < offer.price:
		return {"ok": false, "reason": "not enough gold"}
	var iid := add_to_inventory(offer.def_id)
	shop_offers.remove_at(offer_idx)
	return {"ok": true, "gold_spent": offer.price, "iid": iid, "def_id": offer.def_id}

## Sell an owned item by inventory iid. Returns sell value (caller adjusts gold).
static func sell(iid: String) -> Dictionary:
	if not inventory.has(iid):
		return {"ok": false, "reason": "item not in inventory"}
	var def_id: String = inventory[iid].def_id
	var price := _price(def_id)
	var refund := int(floor(price * SELL_FRACTION))
	remove_from_inventory(iid)
	return {"ok": true, "gold_gained": refund, "def_id": def_id}

## Reroll shop offers. Returns gold cost (caller deducts). Returns -1 if broke.
static func reroll(gold: int) -> int:
	if gold < REROLL_COST:
		return -1
	_reroll_count += 1
	_offer_seed = _mix(_offer_seed, _reroll_count)
	_draw_offers()
	return REROLL_COST

# ---- internals ---------------------------------------------------------------

static func _draw_offers() -> void:
	var pool := _shop_pool()
	if pool.is_empty():
		shop_offers = []
		return
	var rng_state := _offer_seed
	var picks: Array = []
	var count := mini(SHOP_SIZE, pool.size())
	var available := pool.duplicate()
	for _i in count:
		var r := _lcg(rng_state)
		rng_state = r
		var idx := r % available.size()
		picks.append(available[idx])
		available.remove_at(idx)
	shop_offers = picks.map(func(def_id): return {"def_id": def_id, "price": _price(def_id)})

## Items available in the shop for the current pilot run.
static func _shop_pool() -> Array:
	var data := BuildData._data()
	var table: Array = data.get("shop_table", [])
	return table

static func _price(def_id: String) -> int:
	var def := BuildData.get_def(def_id)
	return int(def.get("price", 4))

## Linear-congruential step; returns the next state (unsigned 32-bit).
static func _lcg(state: int) -> int:
	return ((1664525 * state) + 1013904223) & 0x7FFFFFFF

## Mix two ints into a seed.
static func _mix(a: int, b: int) -> int:
	return _lcg(a ^ (b * 2654435761))
