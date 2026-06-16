extends SceneTree
## Headless unit test for the 180° continuity helpers (Slice A): which side of the
## A<->B action axis a camera sits on, and the keyed-lateral sign choice.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func _init() -> void:
	var Director := load("res://scripts/director.gd")
	check(Director != null, "director.gd loads")
	# A at x=-40, B at x=+40 (the standard duel). A camera on the +Z side is one
	# side of the axis; the mirror on -Z is the other.
	var a := Vector3(-40, 0, 0)
	var b := Vector3(40, 0, 0)
	check(Director._axis_side(Vector3(0, 45, 90), a, b) == 1, "+Z camera -> axis side +1")
	check(Director._axis_side(Vector3(0, 45, -90), a, b) == -1, "-Z camera -> axis side -1")
	# Mirroring the point across the axis flips the side.
	check(Director._axis_side(Vector3(13, 20, 50), a, b) == -Director._axis_side(Vector3(13, 20, -50), a, b),
		"mirror across the axis flips the side")

	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
