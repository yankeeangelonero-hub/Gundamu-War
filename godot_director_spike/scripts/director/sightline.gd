extends RefCounted
class_name Sightline
## Multi-ray occlusion test (Slice B1). Casts a ray from the camera to each subject
## silhouette sample point and tests it against the building AABBs (exact for boxes).
## Pure + deterministic. Drives the precise occlusion fade (and later the composition
## search). Spec: docs/superpowers/specs/2026-06-16-continuity-and-sightline-camera-design.md

## Returns { "clear_count": int, "occluders": Array }. clear_count = subject points
## reached with no building between; occluders = buildings blocking >=1 ray (deduped).
static func evaluate(cam_pos: Vector3, subject_points: Array, buildings: Array) -> Dictionary:
	var occluders: Array = []
	var clear := 0
	for sp in subject_points:
		var blocked := false
		for bld in buildings:
			var aabb: AABB = bld.get_meta("aabb")
			if aabb.intersects_segment(cam_pos, sp) != null:
				blocked = true
				if not occluders.has(bld):
					occluders.append(bld)
		if not blocked:
			clear += 1
	return {"clear_count": clear, "occluders": occluders}
