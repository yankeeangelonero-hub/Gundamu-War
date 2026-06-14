extends RefCounted
## OpponentSource — the KM-OPP injected opponent source (M0).
##
## Serves a ghost build as a placement, drawn deterministically from a static pool.
## It returns only a build; it knows nothing of provenance (CON-D03), so the same
## interface later serves designer or real-player ghosts unchanged. The sim consumes
## a resolved ghost identically to the player's own build.

const DATA_PATH := "res://data/ghost_builds.json"

static var _cache: Array = []

static func _ghosts() -> Array:
	if _cache.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		assert(f != null, "ghost_builds.json not found at %s" % DATA_PATH)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		assert(parsed is Dictionary and parsed.has("ghosts"), "ghost_builds.json malformed")
		_cache = parsed.ghosts
	return _cache

static func count() -> int:
	return _ghosts().size()

## Pick a ghost deterministically (pick modulo pool size). Returns the full entry
## { name, callsign, blurb, placement }.
static func get_ghost(pick: int) -> Dictionary:
	var pool := _ghosts()
	assert(not pool.is_empty(), "ghost pool is empty")
	return pool[((pick % pool.size()) + pool.size()) % pool.size()]

## Convenience: just the placement for a pick.
static func get_placement(pick: int) -> Array:
	return get_ghost(pick).placement
