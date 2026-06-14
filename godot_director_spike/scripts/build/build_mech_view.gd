extends SubViewportContainer
## BuildMechView — a 3D sub-viewport showing the shared MechActor in build pose with
## the placed loadout mounted on it. Reuses the combat mech node (spec §5: "the mech
## that fights is the mech you built"). set_loadout() runs the pure mount cascade and
## hangs placeholder block-out weapon meshes on the resolved hardpoints.

const MechActor := preload("res://scripts/mech_actor.gd")
const LoadoutView := preload("res://scripts/build/loadout_view.gd")

var _viewport: SubViewport
var _mech: Node3D

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a0910")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.62)
	env.ambient_light_energy = 0.7
	we.environment = env
	_viewport.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -34, 0)
	key.light_energy = 1.3
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 150, 0)
	rim.light_color = Color(0.55, 0.78, 1.0)
	rim.light_energy = 0.55
	_viewport.add_child(rim)

	_mech = MechActor.new()
	_mech.setup("BUILD", Color(0.60, 0.64, 0.72), 0.0, false, false, true)
	_viewport.add_child(_mech)

	var cam := Camera3D.new()
	cam.position = Vector3(11, 12, 40)
	cam.fov = 34
	_viewport.add_child(cam)
	cam.look_at(Vector3(0, 9, 0), Vector3.UP)

## Re-mount the loadout from the current placement (shared with the combat scene).
func set_loadout(placed: Array) -> void:
	LoadoutView.mount_loadout(_mech, placed)
