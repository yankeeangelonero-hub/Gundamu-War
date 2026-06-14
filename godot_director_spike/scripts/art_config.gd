# Art-direction knobs for the cel-shaded daytime look (run with --cel).
# Palette borrowed from a UC daytime city reference: off-white surfaces (never
# pure white — that washes out), cool-tinted shadows, warm sun, vivid blue sky.
# EDIT and re-run; with --tune you also get live sliders.

# ---- Daytime sun + sky ----
const SUN_ROTATION := Vector3(-55, 130, 0)   # sun angle, degrees (x = height, y = compass)
const SUN_ENERGY := 1.5
const SUN_COLOR := Color(1.0, 0.95, 0.82)     # warm midday
const SKY_COLOR := Color(0.42, 0.62, 0.85)    # vivid sky
const AMBIENT_COLOR := Color(0.56, 0.67, 0.86) # cool sky fill
const AMBIENT_ENERGY := 0.8                     # lower so surfaces don't lift toward white

# ---- Cel diffuse bands — COLOURED. The cool-tinted shadow is the key anime move
#      (shadows shift blue-grey instead of just going darker). Sampled by N·L. ----
const BAND_SHADOW := Color(0.42, 0.49, 0.64)  # cool blue-grey shadow
const BAND_MID := Color(0.66, 0.70, 0.78)
const BAND_LIT := Color(0.92, 0.92, 0.9)      # bright, but not pure white
const BAND_SHADOW_THRESHOLD := 0.42   # N·L below this = shadow band
const BAND_MID_THRESHOLD := 0.72      # N·L below this = mid, above = lit

# ---- Scene surfaces (off-white / muted, never pure white) ----
const BUILDING_COLOR := Color(0.56, 0.58, 0.60)  # muted cool grey concrete (NOT white)
const WINDOW_COLOR := Color(0.28, 0.35, 0.46)    # dark glass bands (daytime, not glowing)
const GROUND_COLOR := Color(0.44, 0.45, 0.48)    # street grey

# ---- Hard anime specular highlight ----
const SPECULAR_COLOR := Color(1.0, 1.0, 1.0)
const SPECULAR_STRENGTH := 0.15  # subtle anime glint on the mechs
const SPECULAR_SMOOTHNESS := 0.08

# ---- Fresnel rim light ----
const FRESNEL_COLOR := Color(0.85, 0.92, 1.0)
const FRESNEL_STRENGTH := 0.35
const FRESNEL_SMOOTHNESS := 0.1

# ---- Ink outline (inverted-hull: bold silhouettes) ----
const OUTLINE_COLOR := Color(0.07, 0.07, 0.10)
const OUTLINE_WIDTH := 3.0

# ---- Screen-space ink (interior creases + where objects occlude / stack) ----
const LINE_THICKNESS := 1.1       # screen-space line width
const INTERIOR_EDGE := 0.5        # crease sensitivity (lower = more interior lines)
const OCCLUSION_EDGE := 0.03      # depth-jump sensitivity (lower = inks shallower overlaps)
const LINE_STRENGTH := 0.9        # ink opacity
