## Loads and validates the hand-authored fight log.
## This file's schema doubles as the assumed future sim event contract.

const REQUIRED := ["tick", "actor", "kind", "payload"]
const KINDS := ["spawn", "advance", "fire_beam", "fire_burst", "destroyed"]

static func load_events(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "fight log missing: " + path)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	assert(parsed is Dictionary and parsed.has("events"), "bad fight log root")
	var events: Array = parsed.events
	for e in events:
		for k in REQUIRED:
			assert(e.has(k), "event missing field '%s': %s" % [k, str(e)])
		assert(e.kind in KINDS, "unknown event kind: " + str(e.kind))
		assert(e.actor in ["A", "B"], "unknown actor: " + str(e.actor))
	events.sort_custom(func(a, b): return int(a.tick) < int(b.tick))
	return events

static func duration_sec(events: Array, tick_seconds := 0.1, tail := 5.0) -> float:
	return float(events[-1].tick) * tick_seconds + tail
