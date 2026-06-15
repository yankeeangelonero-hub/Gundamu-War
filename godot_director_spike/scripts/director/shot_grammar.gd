extends Resource
class_name ShotGrammar
## ShotGrammar — the single authored home for the director's camera/timing
## parameters, grouped by sub-block. Spec: docs/superpowers/specs/2026-06-16-director-grammar-design.md
## Phase 1 holds Timing + Composition (per-mode framing). Lighting/Color/Continuity
## sub-blocks arrive in later phases. `default()` returns the current shipped values
## so lifting these out of hybrid.gd changes nothing visually.

# --- Timing / Cut (F5, F14, F37, F38) ---
@export var os_len: float = 1.8       # over-shoulder intercut length (tuned independently of cut_len)
@export var cut_len: float = 1.8      # hero-cut intercut length (tuned independently of os_len)
@export var bt_pre: float = 0.2       # bullet-time lead before the lethal hit
@export var bt_post: float = 0.55     # bullet-time hold past the lethal hit (covers the kill)
@export var bt_scale: float = 0.07    # bullet-time time-scale (slow-mo)

# --- Composition: iso backbone (F6, F4, F34) ---
@export var iso_offset: Vector3 = Vector3(-45, 90, 18)
@export var iso_zoom_min: float = 50.0
@export var iso_zoom_max: float = 118.0
@export var iso_zoom_factor: float = 0.7   # * mech separation
@export var iso_zoom_base: float = 30.0    # + base
@export var aftermath_zoom: float = 58.0

# --- Composition: per-shot-mode framing table (F6, F8) ---
# Each entry holds the framing numbers the runtime camera reads for that mode.
# NOTE: framing values are untyped Dictionaries — a mistyped key (e.g. "rool") or a
# missing key on an entry fails silently at runtime. Acceptable for Phase 1; revisit
# with typed per-mode structs when later sub-blocks (Lighting/Color/Continuity) land.
@export var framing: Dictionary = {
	"hero_os":     {"pullback": 18.0, "lateral": 8.0, "height": 16.0, "fov": 40.0},
	"hero_cut":    {"pullback": 2.0,  "lateral": 9.0, "height": 5.0,  "fov": 46.0, "roll": -0.05},
	"melee_cut":   {"radius": 15.0, "height": 4.0, "fov": 36.0},
	"bullet_time": {"radius": 32.0, "height_base": 8.0, "height_rise": 9.0, "depth": 14.0, "fov": 48.0},
}

static func default() -> ShotGrammar:
	return new()
