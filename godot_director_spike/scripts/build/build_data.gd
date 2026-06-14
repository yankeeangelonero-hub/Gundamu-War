extends RefCounted
## BuildData — pure catalogue + shape/rotation math for the M1 build grid.
##
## No rendering, no node tree. Offsets are Vector2i(row, col). The one subtle
## invariant: an item's footprint (shape) and a support's buff-slots rotate
## TOGETHER under a single normalization, so a rotated support still buffs the
## same cells relative to its body. See rotate_item().

const DATA_PATH := "res://data/build_items.json"

static var _cache: Dictionary = {}

static func _data() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		assert(f != null, "build_items.json not found at %s" % DATA_PATH)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		assert(parsed is Dictionary, "build_items.json did not parse to a Dictionary")
		_cache = parsed
	return _cache

static func get_def(id: String) -> Dictionary:
	var items: Dictionary = _data().get("items", {})
	assert(items.has(id), "unknown item id '%s'" % id)
	return items[id]

static func all_ids() -> Array:
	return _data().get("items", {}).keys()

static func dev_palette() -> Array:
	return _data().get("dev_palette", [])

static func category(kind: String) -> Dictionary:
	return _data().get("categories", {}).get(kind, {"label": kind, "color": "#888888"})

# ---- shape offsets -----------------------------------------------------------

## Raw (un-rotated, un-normalized) shape offsets for a def, as Vector2i(row, col).
static func shape_offsets(def: Dictionary) -> Array:
	var shapes: Dictionary = _data().get("shapes", {})
	var key: String = def.get("shape", "1x1")
	var raw: Array = shapes.get(key, [[0, 0]])
	return raw.map(func(p): return Vector2i(int(p[0]), int(p[1])))

## Raw buff-slot offsets (supports only), as Vector2i(row, col). Empty otherwise.
static func buff_offsets(def: Dictionary) -> Array:
	var raw: Array = def.get("buff_slots", [])
	return raw.map(func(p): return Vector2i(int(p[0]), int(p[1])))

# ---- rotation ----------------------------------------------------------------

## Rotate one offset rot×90° clockwise. (r, c) -> (c, -r).
static func _rot_one(p: Vector2i, rot: int) -> Vector2i:
	var q := p
	for _i in (((rot % 4) + 4) % 4):
		q = Vector2i(q.y, -q.x)
	return q

## Rotate shape + buff-slots together, then normalize so the SHAPE's top-left is
## (0,0). The same normalization offset is applied to the buff-slots, which keeps
## them aligned to the body (buff offsets may legitimately go negative — that just
## means a slot above/left of the anchor cell).
## Returns { "shape": Array[Vector2i], "buff": Array[Vector2i] }.
static func rotate_item(def: Dictionary, rot: int) -> Dictionary:
	var rshape: Array = shape_offsets(def).map(func(p): return _rot_one(p, rot))
	var rbuff: Array = buff_offsets(def).map(func(p): return _rot_one(p, rot))
	var min_r := int(rshape.map(func(p): return p.x).min())
	var min_c := int(rshape.map(func(p): return p.y).min())
	var shift := Vector2i(min_r, min_c)
	return {
		"shape": rshape.map(func(p): return p - shift),
		"buff": rbuff.map(func(p): return p - shift),
	}

## Absolute footprint cells for an item placed with top-left anchor (Vector2i).
static func placed_cells(def: Dictionary, rot: int, anchor: Vector2i) -> Array:
	return rotate_item(def, rot)["shape"].map(func(p): return p + anchor)

## Absolute buff-slot cells for a support placed at anchor (Vector2i).
static func buff_cells(def: Dictionary, rot: int, anchor: Vector2i) -> Array:
	return rotate_item(def, rot)["buff"].map(func(p): return p + anchor)

## Bounding span {r, c} of a rotated shape (for palette glyphs / sizing).
static func span(def: Dictionary, rot: int) -> Vector2i:
	var s: Array = rotate_item(def, rot)["shape"]
	var max_r := int(s.map(func(p): return p.x).max())
	var max_c := int(s.map(func(p): return p.y).max())
	return Vector2i(max_r + 1, max_c + 1)
