extends SceneTree
## Headless guard for F35 (coherence_over_polish): the hero cut-in pose search can
## never cross the A<->B action axis (the 180deg / screen-direction rule). Exercises
## the REAL candidate path (_hero_candidates) plus the occlusion pick
## (_pick_clear_pose) across many duel geometries, both keyed sides, and several
## building layouts. melee_cut is intentionally NOT covered (it orbits the clash and
## may sit on either side). Pure + headless; mirrors continuity_check / sightline_check.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func _bld(pos: Vector3, size: Vector3) -> Node3D:
	var n := Node3D.new()
	n.set_meta("aabb", AABB(pos, size))
	return n

func _init() -> void:
	var Director := load("res://scripts/director.gd")
	check(Director != null, "director.gd loads")

	# Representative hero framing magnitudes; the SIGN is chosen by _keyed_lateral.
	var pullback := 18.0
	var height := 12.0
	var lateral := 9.0

	# Duel geometries: axis-aligned, rotated 90deg, diagonal, and off-origin.
	var geometries := [
		[Vector3(-40, 0, 0), Vector3(40, 0, 0)],
		[Vector3(0, 0, -40), Vector3(0, 0, 40)],
		[Vector3(-30, 0, -30), Vector3(35, 0, 25)],
		[Vector3(120, 0, -10), Vector3(60, 0, 50)],
	]
	# Building layouts the occlusion search must dodge (incl. one straddling the line).
	var layouts := [
		[],
		[_bld(Vector3(-10, 0, -8), Vector3(20, 30, 16))],
		[_bld(Vector3(-30, 0, -30), Vector3(60, 40, 60))],
	]

	for gi in geometries.size():
		var a: Vector3 = geometries[gi][0]
		var b: Vector3 = geometries[gi][1]
		# Each mech takes a turn as the cut-in focus (f); the other is o.
		for pair in [[a, b], [b, a]]:
			var f: Vector3 = pair[0]
			var o: Vector3 = pair[1]
			for keyed in [1, -1]:
				var lat: float = Director._keyed_lateral(f, o, pullback, height, lateral, a, b, keyed)
				var cands: Array = Director._hero_candidates(f, o, pullback, height, lat)
				check(cands.size() == 5, "geo %d keyed %d: 5 hero candidates" % [gi, keyed])
				# (a) every candidate lands on the keyed side of the axis
				var all_keyed := true
				for c in cands:
					if Director._axis_side(c, a, b) != keyed:
						all_keyed = false
				check(all_keyed, "geo %d keyed %d: all hero candidates on keyed side" % [gi, keyed])
				# (b) the occlusion pick stays keyed-side for EVERY building layout
				var aim: Vector3 = o + Vector3(0, 10, 0)
				var pick_keyed := true
				for layout in layouts:
					var pk: Dictionary = Director._pick_clear_pose(cands, aim, layout, -1, 2)
					if Director._axis_side(pk.pos, a, b) != keyed:
						pick_keyed = false
				check(pick_keyed, "geo %d keyed %d: picked pose keyed-side across all layouts" % [gi, keyed])

	for layout in layouts:
		for n in layout:
			n.free()

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
