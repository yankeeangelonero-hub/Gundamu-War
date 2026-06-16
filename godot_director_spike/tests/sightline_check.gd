extends SceneTree
## Unit test for the multi-ray occlusion test (Slice B1): which buildings block the
## camera->subject silhouette rays, exact ray-vs-AABB.

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
	var S := load("res://scripts/director/sightline.gd")
	check(S != null, "sightline.gd loads")
	var cam := Vector3(0, 10, 50)
	var subj := [Vector3(0, 2, 0), Vector3(0, 10, 0), Vector3(0, 18, 0), Vector3(-6, 10, 0), Vector3(6, 10, 0)]

	var r0: Dictionary = S.evaluate(cam, subj, [])
	check(r0.clear_count == 5, "no buildings -> all 5 rays clear")
	check(r0.occluders.is_empty(), "no buildings -> no occluders")

	var wall := _bld(Vector3(-10, 0, 20), Vector3(20, 30, 4))
	var r1: Dictionary = S.evaluate(cam, subj, [wall])
	check(r1.occluders.has(wall), "center wall is an occluder")
	check(r1.clear_count < 5, "center wall blocks at least one ray")

	var side := _bld(Vector3(40, 0, 20), Vector3(8, 30, 4))
	var r2: Dictionary = S.evaluate(cam, subj, [side])
	check(r2.occluders.is_empty(), "off-side building does not occlude")
	check(r2.clear_count == 5, "off-side building leaves all rays clear")

	var shoulder := _bld(Vector3(3, 0, 20), Vector3(5, 30, 4))
	var r3: Dictionary = S.evaluate(cam, subj, [shoulder])
	check(r3.occluders.has(shoulder), "off-center shoulder occluder caught (multi-ray > thin line)")
	check(r3.clear_count == 4, "exactly the shoulder ray is blocked")

	wall.free(); side.free(); shoulder.free()
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
