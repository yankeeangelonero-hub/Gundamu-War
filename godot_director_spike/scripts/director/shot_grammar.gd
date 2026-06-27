extends Resource
class_name ShotGrammar
## ShotGrammar — the single authored home for the director's camera/timing
## parameters, grouped by sub-block. Spec: docs/superpowers/specs/2026-06-16-director-grammar-design.md
## Phase 1 holds Timing + Composition (per-mode framing). Lighting/Color/Continuity
## sub-blocks arrive in later phases. `default()` returns the current shipped values
## so lifting these out of hybrid.gd changes nothing visually.

# --- Timing / Cut (F5, F14, F37, F38) ---
@export var os_len: float = 4.0       # over-shoulder intercut length (tuned independently of cut_len)
@export var cut_len: float = 4.0      # hero-cut intercut length (tuned independently of os_len)
@export var min_iso: float = 1.0      # shortest legible iso re-establish BETWEEN cinematic shots; a
                                      # gap below this is absorbed into the prior shot (no flash-cut)
@export var camera_min_duration: float = 1.5 # ordinary perspective cut-ins shorter than this are skipped
@export var camera_max_duration: float = 5.0 # longest ordinary perspective hold before returning to iso
@export var camera_speed_scale: float = 0.25 # global camera follow/cap speed multiplier
@export var dolly_cap: float = 42.0   # max camera linear speed (u/s wall) for the eased orbiting
                                      # shots, so a fast/violent subject is tracked, never whip-panned
@export var melee_radius_factor: float = 1.4  # melee_cut orbit radius grows with mech separation by
                                              # this factor, so both mechs stay framed through a recoil

# --- Render: body feel (F1 mass-ramp + F11 weight + tempo cadence) ---
# How a build's FeelProfile maps to the rendered body in mech_actor.apply_feel(). Each entry is
# [value-at-param-0, value-at-param-1], lerped by the named param. Lifting these here makes the
# fast-vs-slow spread a tunable grammar value instead of a hardcoded curve in the actor.
@export var feel: Dictionary = {
	"max_speed": [64.0, 28.0],   # by HEFT: cruise cap — light darts, heavy lumbers
	"max_accel": [34.0, 10.0],   # by HEFT: accel — light snaps up to speed, heavy ramps slowly
	"pose_rate": [1.0, 0.5],     # by HEFT: upper-body ease rate — heavy commits/holds a pose (F11)
	"gait":      [0.6, 1.7],     # by TEMPO: walk-bob/footfall cadence — high tempo = busy/twitchy legs
}
@export var bt_pre: float = 0.2       # bullet-time lead before the lethal hit
@export var bt_post: float = 0.55     # bullet-time hold past the lethal hit (covers the kill)
@export var bt_scale: float = 0.07    # bullet-time time-scale (slow-mo)

# --- Melee framing (Phase 3 Slice 3) ---
@export var melee_cut_pre: float = 0.5     # lead-in before the clash tick
@export var melee_cut_post: float = 1.7    # hold after the clash tick
@export var melee_cut_scale: float = 0.5   # melee close-up slow-mo
@export var melee_cut_spacing: float = 4.0 # minimum seconds between melee close-ups; rapid
                                           # A/B saber trades stay one readable exchange

# --- Time-emphasis arbiter (Phase 3 Slice 1; F37/F14) ---
# One tool owns a contact beat: bullet-time (kill cam) > hitstop (heavy hit) >
# impact-frame (minor hit). hitstop/impact-frame partition by damage vs threshold.
@export var hitstop_dur: float = 0.07          # the brief freeze length on a heavy ranged hit
@export var melee_hitstop_dur: float = 0.12    # a melee clash holds longer than a ranged hit (more weight)
@export var hitstop_threshold: float = 25.0    # damage above this → hitstop; at/below → impact-frame
@export var impact_frame_len: int = 2          # impact-frame insert length in frames
@export var impact_frame_strength: float = 0.15  # impact-frame contrast/flash magnitude (subtle-on)

# --- Composition: iso backbone (F6, F4, F34) ---
@export var iso_offset: Vector3 = Vector3(-45, 90, 18)
@export var iso_zoom_min: float = 50.0
@export var iso_zoom_max: float = 118.0
@export var iso_zoom_factor: float = 0.7   # * mech separation
@export var iso_zoom_base: float = 30.0    # + base
@export var aftermath_zoom: float = 58.0
@export var iso_follow_rate: float = 1.2   # slower tactical pan; melee dashes should not yank the plate
@export var iso_dolly_cap: float = 42.0    # max iso camera linear speed (u/s wall)

# --- Composition: per-shot-mode framing table (F6, F8) ---
# Each entry holds the framing numbers the runtime camera reads for that mode.
# NOTE: framing values are untyped Dictionaries — a mistyped key (e.g. "rool") or a
# missing key on an entry fails silently at runtime. Acceptable for Phase 1; revisit
# with typed per-mode structs when later sub-blocks (Lighting/Color/Continuity) land.
@export var framing: Dictionary = {
	"hero_os":     {"pullback": 18.0, "lateral": 8.0, "height": 16.0, "fov": 40.0},
	"hero_cut":    {"pullback": 2.0,  "lateral": 9.0, "height": 5.0,  "fov": 46.0, "roll": -0.05},
	"melee_cut":   {"radius": 26.0, "height": 11.0, "fov": 46.0},
	"melee_chase": {"pullback": 20.0, "lateral": 6.0, "height": 9.0, "fov": 50.0, "roll": -0.03},
	"melee_profile": {"distance": 34.0, "height": 13.0, "fov": 42.0},
	"melee_high":  {"radius": 38.0, "height": 28.0, "fov": 52.0},
	"bullet_time": {"radius": 32.0, "height_base": 8.0, "height_rise": 9.0, "depth": 14.0, "fov": 48.0},
}


# --- Lighting (F22, F24) ---
# chromatic_fill: the ambient shadow tint — shadows take a cool, non-black tint
# (F22) and are never crushed to black. Equals the current scene ambient so a
# normal beat is unchanged; moods shift around it via `warmth`.
@export var chromatic_fill: Color = Color(0.10, 0.12, 0.20)
# ambient_energy: the ambient fill strength (F22). Grade owns this; default
# equals the prior city_builder value so the live look is unchanged.
@export var ambient_energy: float = 1.6
# fx_light_energy: global multiplier garnish applies to its (now re-enabled) FX
# OmniLights (F24). 1.0 = author-tuned baseline; raise for a punchier light.
@export var fx_light_energy: float = 1.0

# --- Color: mood variants (F26, F27) ---
# Named grade states the Grade node lerps between when the director signals a
# beat. Each entry: brightness/contrast/saturation feed Environment.adjustment_*;
# `warmth` shifts the ambient tint warm (+) or cool (-) around chromatic_fill.
# `base` MUST be identity (1/1/1, warmth 0) so a normal beat reads like today.
@export var mood_variants: Dictionary = {
	"base":  {"brightness": 1.0, "contrast": 1.0,  "saturation": 1.0, "warmth": 0.0},
	"hero":  {"brightness": 1.06, "contrast": 1.04, "saturation": 1.12, "warmth": 0.18},
	"death": {"brightness": 0.92, "contrast": 1.08, "saturation": 0.55, "warmth": -0.05},
}
# How fast (per wall-clock second) the grade eases toward the active mood.
@export var mood_lerp_rate: float = 1.5


# --- Spectacle: yield-by-class (Phase 3 Slice 2; F16/F17) ---
# A weapon's event kind maps to a yield TIER (1 = sidearm, 3 = capital/payload).
# The kill spectacle (staggered blast) scales by the killing weapon's tier — a
# capital discharge gets the outsized "fear beat", a sidearm stays modest.
@export var yield_by_class: Dictionary = {
	"fire_buster": 3,
	"fire_plasma": 3,
	"fire_railgun": 2,
	"fire_missiles": 2,
	"fire_beam": 2,
	"melee": 2,
	"fire_burst": 1,
}

## The yield tier for a weapon event kind; unmapped/empty → 1 (a modest single
## blast — the safe floor). Pure lookup, unit-tested.
func yield_tier(kind: String) -> int:
	return int(yield_by_class.get(kind, 1))

# --- Lens: compression (Phase 3 Slice 4; F31) ---
# A continuous long-lens dial per shot mode (0 = the authored FOV, no change).
# On a compressed beat the camera drops FOV and pulls back to keep the subject
# the same size — flattening perspective (the looming graphic-plane look). The
# camera reads this via compression_by_mode.get(mode, 0.0).
@export var compression_by_mode: Dictionary = {
	"hero_cut": 0.5,
}
@export var compression_fov_floor: float = 0.5   # FOV at full compression = base_fov * this floor

# --- Composition: search arc (Slice B2) ---
# How far (radians for orbits / scaled for cut-ins) the composition search may swing
# a perspective shot to find a clear sightline to the mech (Slice B2).
@export var composition_search_arc: float = 0.6

# --- Lens: x-ray window occlusion ---
@export var xray_radius: float = 14.0     # window radius around the camera->mech sightline (world units)
@export var xray_softness: float = 5.0    # soft-edge width of the window

static func default() -> ShotGrammar:
	return new()
