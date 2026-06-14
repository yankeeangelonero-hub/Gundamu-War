extends RefCounted
## LoadoutView — shared presentation helper for showing a build's weapons on a mech.
##
## Runs the pure mount cascade (BuildMounts) and hangs placeholder block-out weapon
## meshes on the resolved hardpoints. Used by both the build screen's frame view and
## the combat scene, so the mech you build is the mech that fights.

const BuildMounts := preload("build_mounts.gd")

## Placeholder block-out weapon, oriented along +Z so the grip sits at the hardpoint
## and the barrel extends forward.
static func weapon_mesh(def_id: String) -> Node3D:
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
	# muzzle marker at the barrel tip, so beams can originate from this weapon
	var mz := Node3D.new()
	mz.name = "muzzle"
	mz.position = Vector3(0, 0, size.z * 0.5)
	mi.add_child(mz)
	return mi

## Run the cascade and hang the loadout on `mech` (which must expose the hardpoint
## registry: register_hardpoints / mount / clear_mounts). Accepts a raw placement
## (entries with def_id/rot/anchor; anchor as Vector2i or [row,col]; iid optional).
static func mount_loadout(mech: Node3D, raw_placed: Array) -> void:
	if mech == null or not mech.has_method("mount"):
		return
	var placed: Array = []
	var i := 0
	for r in raw_placed:
		i += 1
		var anc: Variant = r.get("anchor", Vector2i.ZERO)
		if anc is Array:
			anc = Vector2i(int(anc[0]), int(anc[1]))
		placed.append({
			"iid": r.get("iid", "m%d" % i),
			"def_id": r.def_id,
			"rot": int(r.get("rot", 0)),
			"anchor": anc,
		})
	if mech.has_method("clear_mounts"):
		mech.clear_mounts()
	var res := BuildMounts.assign(placed)
	for p in placed:
		if res.mounts.has(p.iid):
			mech.mount(res.mounts[p.iid], weapon_mesh(p.def_id))
