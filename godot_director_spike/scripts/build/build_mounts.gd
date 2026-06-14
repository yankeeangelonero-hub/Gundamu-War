extends RefCounted
## BuildMounts — pure mount cascade for the M1 3D loadout (spec §5).
##
## Each placed weapon resolves to a hardpoint by trying its preferred_mount, then
## walking its fallback_mounts, then any remaining hardpoint in canonical order.
## Deterministic (placement order), no rendering — the M0 fight inherits the same
## assignment so the mech that fights is the mech you built.

const BuildData := preload("build_data.gd")

## Canonical hardpoint order — also the final fallthrough so a maxed loadout still
## finds a free point. Must match MechActor.HARDPOINT_OFFSETS' keys.
const HARDPOINTS := [
	"hand_r", "hand_l", "forearm_r", "forearm_l",
	"shoulder_r", "shoulder_l", "hip_r", "hip_l", "back",
]

## placed: Array of { iid, def_id, ... }. Returns { mounts: {iid->hardpoint}, overflow: [iid] }.
static func assign(placed: Array) -> Dictionary:
	var taken: Dictionary = {}     # hardpoint -> iid
	var mounts: Dictionary = {}    # iid -> hardpoint
	var overflow: Array = []
	for p in placed:
		var def := BuildData.get_def(p.def_id)
		if def.get("kind", "") != "spender":
			continue
		var chain: Array = [def.get("preferred_mount", "")]
		chain.append_array(def.get("fallback_mounts", []))
		for hp in HARDPOINTS:
			if hp not in chain:
				chain.append(hp)
		var chosen := ""
		for hp in chain:
			if hp != "" and not taken.has(hp):
				chosen = hp
				break
		if chosen == "":
			overflow.append(p.iid)
		else:
			taken[chosen] = p.iid
			mounts[p.iid] = chosen
	return {"mounts": mounts, "overflow": overflow}
