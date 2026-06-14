extends SubViewportContainer
## BuildMechView — a 3D sub-viewport showing the shared MechActor in build pose with
## the placed loadout mounted on it. Reuses the combat mech node (spec §5: "the mech
## that fights is the mech you built"). set_loadout() runs the pure mount cascade and
## hangs placeholder block-out weapon meshes on the resolved hardpoints.

const MechActor := preload("res://scripts/mech_actor.gd")
const BuildMounts := preload("res://scripts/build/build_mounts.gd")
const BuildData := preload("res://scripts/build/build_data.gd")

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

## Re-mount the loadout from the current placement. Pure cascade decides where each
## weapon goes; this only builds and hangs the meshes.
func set_loadout(placed: Array) -> void:
	if _mech == null:
		return
	_mech.clear_mounts()
	var res := BuildMounts.assign(placed)
	for p in placed:
		if not res.mounts.has(p.iid):
			continue
		_mech.mount(res.mounts[p.iid], _weapon_mesh(p.def_id))

## Placeholder block-out weapon, oriented along +Z so the grip sits at the hardpoint
## and the barrel extends forward.
func _weapon_mesh(def_id: String) -> Node3D:
	var size := Vector3(0.7, 0.7, 4.0)
	var emissive := false
	match def_id:
		"beam_rifle": size = Vector3(0.7, 0.7, 5.5)
		"gatling": size = Vector3(1.0, 1.0, 4.0)
		"beam_cannon": size = Vector3(1.1, 1.1, 6.5)
		"missile_rack": size = Vector3(2.4, 2.0, 2.2)
		"beam_saber":
			size = Vector3(0.35, 0.35, 5.0)
			emissive = true

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	if emissive:
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.85, 1.0)
		mat.emission_energy_multiplier = 12.0
		mat.albedo_color = Color(0.85, 0.95, 1.0)
	else:
		mat.albedo_color = Color(0.16, 0.16, 0.2)
		mat.metallic = 0.5
		mat.roughness = 0.45
	mesh.material = mat
	mi.mesh = mesh
	mi.position = Vector3(0, 0, size.z * 0.5)
	return mi
