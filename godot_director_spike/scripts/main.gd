extends Node3D

const CityBuilder := preload("res://scripts/city_builder.gd")
const MechActor := preload("res://scripts/mech_actor.gd")

var camera: Camera3D
var mech_a: Node3D
var mech_b: Node3D

func _ready() -> void:
	CityBuilder.build_environment(self)
	CityBuilder.build(self)
	mech_a = MechActor.new()
	mech_a.setup("A", Color(0.30, 0.45, 0.75), -40.0)
	add_child(mech_a)
	mech_b = MechActor.new()
	mech_b.setup("B", Color(0.70, 0.30, 0.25), 40.0)
	add_child(mech_b)
	camera = Camera3D.new()
	camera.position = Vector3(0, 45, 90)
	camera.fov = 55
	add_child(camera)
	camera.look_at(Vector3(0, 10, 0), Vector3.UP)
	print("KM-DIRECTOR-SPIKE boot ok")
	if "--still" in OS.get_cmdline_user_args():
		# Behind mech A (x=-55), looking toward B (x=+40) — sees both mechs + city flanks
		camera.position = Vector3(-55, 22, 8)
		camera.fov = 72
		camera.look_at(Vector3(20, 8, 0), Vector3.UP)
		await get_tree().create_timer(2.0).timeout
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("res://tmp")
		img.save_png("res://tmp/still.png")
		print("still saved")
		get_tree().quit()
