extends SceneTree
## Regression for melee playback contact: melee setup must not be clamped to the ranged ring.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		print("FAIL  %s" % label)
		fails += 1

func _initialize() -> void:
	var Director := load("res://scripts/director.gd")
	check(Director != null, "director.gd loads")
	if Director == null:
		_finish()
		return

	var d = Director.new()
	var advance := {
		"tick": 10,
		"actor": "A",
		"kind": "advance",
		"payload": {"to_x": 2.0, "to_y": 0.0, "to_z": 0.0, "boost": true, "end_tick": 14},
	}
	var melee := {
		"tick": 14,
		"actor": "A",
		"kind": "melee",
		"payload": {"hit": true, "damage": 15},
	}
	d.events = [advance, melee]
	check(d._advance_sets_up_melee(advance), "advance ending on melee is flagged as melee setup")

	var enemy := Vector3.ZERO
	var melee_to: Vector3 = d._melee_engage(Vector3(2, 0, 0), enemy)
	var ranged_to: Vector3 = d._engage(Vector3(2, 0, 0), enemy)
	check(_flat(melee_to, enemy) <= 17.001, "melee setup can land inside saber hit range")
	check(_flat(melee_to, enemy) >= 7.999, "melee setup keeps a readable contact gap")
	check(_flat(ranged_to, enemy) >= 33.999, "normal engagement still keeps ranged duel spacing")

	var unrelated := advance.duplicate(true)
	d.events = [unrelated, {
		"tick": 24,
		"actor": "A",
		"kind": "fire_beam",
		"payload": {"hit": true, "damage": 10},
	}]
	check(not d._advance_sets_up_melee(unrelated), "non-melee advance keeps ranged behavior")
	d.free()
	_finish()

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _finish() -> void:
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	quit(0 if fails == 0 else 1)
