extends SceneTree
## X-ray wiring (headless): the four global shader parameters are declared (project.godot)
## and readable. Checks the wiring, not the pixels (headless has no rendering).
var fails := 0
func check(c: bool, l: String) -> void:
	if c: print("PASS  %s" % l)
	else: print("FAIL  %s" % l); fails += 1
func _init() -> void:
	check(typeof(RenderingServer.global_shader_parameter_get("xray_radius")) == TYPE_FLOAT, "xray_radius global exists")
	check(typeof(RenderingServer.global_shader_parameter_get("xray_softness")) == TYPE_FLOAT, "xray_softness global exists")
	check(typeof(RenderingServer.global_shader_parameter_get("xray_mech_a")) == TYPE_VECTOR3, "xray_mech_a global exists")
	check(typeof(RenderingServer.global_shader_parameter_get("xray_mech_b")) == TYPE_VECTOR3, "xray_mech_b global exists")
	print("---- %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	quit(1 if fails > 0 else 0)
