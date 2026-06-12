extends Node3D

const CityBuilder := preload("res://scripts/city_builder.gd")

var camera: Camera3D

func _ready() -> void:
	CityBuilder.build_environment(self)
	CityBuilder.build(self)
	camera = Camera3D.new()
	camera.position = Vector3(0, 45, 90)
	camera.fov = 55
	add_child(camera)
	camera.look_at(Vector3(0, 10, 0), Vector3.UP)
	print("KM-DIRECTOR-SPIKE boot ok")
	if "--still" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2.0).timeout
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("res://tmp")
		img.save_png("res://tmp/still.png")
		print("still saved")
		get_tree().quit()
