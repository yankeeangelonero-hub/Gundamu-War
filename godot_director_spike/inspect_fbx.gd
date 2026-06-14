extends SceneTree
## Throwaway: dump the skeleton + animations of an imported model so we can verify
## a rig/clip is usable. Run: godot --headless --path godot_director_spike --script res://inspect_fbx.gd

func _initialize() -> void:
	var path := "res://models/run_rifle.fbx"
	if not ResourceLoader.exists(path):
		print("NOT IMPORTED (run --import first): ", path)
		quit()
		return
	var packed: PackedScene = load(path)
	var root := packed.instantiate()
	print("=== root: %s (%s) ===" % [root.name, root.get_class()])
	_walk(root, 0)
	quit()

func _walk(n: Node, d: int) -> void:
	var indent := "  ".repeat(d)
	var extra := ""
	if n is Skeleton3D:
		extra = " [Skeleton3D bones=%d]" % (n as Skeleton3D).get_bone_count()
	if n is AnimationPlayer:
		extra = " [AnimationPlayer anims=%s]" % str((n as AnimationPlayer).get_animation_list())
	if n is MeshInstance3D:
		extra = " [Mesh surfaces=%d]" % (n as MeshInstance3D).get_surface_override_material_count()
	print(indent, n.name, " : ", n.get_class(), extra)
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		var names: Array = []
		for i in mini(sk.get_bone_count(), 40):
			names.append(sk.get_bone_name(i))
		print(indent, "  bones[0..40]: ", names)
	for c in n.get_children():
		_walk(c, d + 1)
