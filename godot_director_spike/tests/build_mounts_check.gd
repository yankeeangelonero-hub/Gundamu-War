extends SceneTree
## Headless checks for BuildMounts — the preferred→fallback→any-free cascade (spec §7:
## N weapons resolve to expected hardpoints, with fallback when a preferred is taken).

const BuildMounts := preload("res://scripts/build/build_mounts.gd")

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)

func _initialize() -> void:
	_preferred()
	_fallback_when_taken()
	_ignores_non_weapons()
	_overflow()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)

# a lone rifle takes its preferred hand; a cannon takes the back.
func _preferred() -> void:
	var r := BuildMounts.assign([
		{"iid": "br", "def_id": "beam_rifle"},
		{"iid": "cn", "def_id": "beam_cannon"},
	])
	check(r.mounts["br"] == "hand_r", "rifle → preferred hand_r (got %s)" % r.mounts.get("br"))
	check(r.mounts["cn"] == "back", "cannon → preferred back (got %s)" % r.mounts.get("cn"))
	check(r.overflow.is_empty(), "no overflow for two weapons")

# second weapon preferring the same hand cascades down its fallback list.
func _fallback_when_taken() -> void:
	# rifle (pref hand_r, fb [hand_l, shoulder_r]) then gatling (pref hand_r, fb [shoulder_r, shoulder_l])
	var r := BuildMounts.assign([
		{"iid": "br", "def_id": "beam_rifle"},
		{"iid": "gt", "def_id": "gatling"},
	])
	check(r.mounts["br"] == "hand_r", "first weapon keeps preferred hand_r")
	check(r.mounts["gt"] == "shoulder_r", "second weapon cascades to its fallback shoulder_r (got %s)" % r.mounts.get("gt"))

	# two rifles: second falls back to hand_l (first entry of its fallback list).
	var r2 := BuildMounts.assign([
		{"iid": "a", "def_id": "beam_rifle"},
		{"iid": "b", "def_id": "beam_rifle"},
	])
	check(r2.mounts["a"] == "hand_r" and r2.mounts["b"] == "hand_l",
		"two rifles → hand_r then fallback hand_l (got %s, %s)" % [r2.mounts.get("a"), r2.mounts.get("b")])

# builders/supports never claim a hardpoint.
func _ignores_non_weapons() -> void:
	var r := BuildMounts.assign([
		{"iid": "rc", "def_id": "reactor_core"},
		{"iid": "pc", "def_id": "power_cell"},
		{"iid": "br", "def_id": "beam_rifle"},
	])
	check(r.mounts.size() == 1 and r.mounts.has("br"), "only the weapon is mounted (got %d)" % r.mounts.size())

# more weapons than hardpoints → the extras overflow (logged, not silently dropped).
func _overflow() -> void:
	var placed: Array = []
	for i in 10:
		placed.append({"iid": "w%d" % i, "def_id": "gatling"})
	var r := BuildMounts.assign(placed)
	check(r.mounts.size() == BuildMounts.HARDPOINTS.size(), "all 9 hardpoints fill (got %d)" % r.mounts.size())
	check(r.overflow.size() == 1, "the 10th weapon overflows (got %d)" % r.overflow.size())
