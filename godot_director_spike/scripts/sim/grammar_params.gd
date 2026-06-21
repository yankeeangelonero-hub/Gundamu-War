extends RefCounted
## Combat Choreography Grammar — tuning constants.
## Spec: docs/superpowers/specs/2026-06-20-choreography-grammar-design.md
##   "Tuning constants" section.
##
## All values are design starting points, seeded from the reference fight and the
## choreography theory. EVERY constant is a tuning parameter — nothing here is load-bearing
## for correctness; only the formulas in grammar_metrics.gd are.  Values are tuned by the
## reference-diff diagnostic + the edge-fixture suite (see spec).
##
## Per-archetype overrides are loaded from res://data/grammar_presets.json at runtime
## (schema: {name, heft_bias, tempo_bias, mode_mix, overrides:{<const>:value}}).
## This file holds the global defaults those overrides layer onto.

const PRESETS_PATH := "res://data/grammar_presets.json"

## Load the archetype preset table (data, not code). A new archetype is a data row.
static func load_presets() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESETS_PATH))
	return parsed if parsed is Dictionary else {}

# --- Contrast / prosody ---
## Minimum fraction of ticks below speed REF_SPEED to count as "pause-heavy" for bimodal check.
## TUNING: raise if beam-trade reads too busy; lower if static duels pass too easily.
const PAUSE_MIN   := 0.35

## Minimum bimodality score for beam-trade CG-CONTRAST (0..1; a simple pause-frac proxy here).
## TUNING: 0.35 means 35% of ticks must be in the "pause" mode.
const BIMODAL_MIN := 0.35

## Minimum bearing oscillation amplitude (radians) to count as a sustained weave.
## Used by swarm + dodge-pursuit contrast metrics.
const WEAVE_MIN   := 0.3

## Minimum coast fraction for burst-and-coast prosody detection.
const COAST_MIN   := 0.20

# --- Beat scheduler ---
## Shots within this many ticks of the same actor+mode are coalesced into one beat.
const COALESCE_WINDOW := 6

## Ticks of telegraph before a beat's fire_tick (clamped to spawn).
const TELEGRAPH := 4

## Ticks the target's sell/reaction spans after an impact.
const REACT := 6

## Tier at/above which a shot reads as heavy (determines CRA prominence).
## Fire-knowable (tier is known at fire time). Must NOT be a damage/lethal check.
const HEAVY_TIER := 3

## Damage threshold for heavy-at-impact emphasis (applies only at impact, not cue).
const HEAVY_DMG := 50.0

# --- Exchange movement (mobility) ---
## A shooter whose FeelProfile heft is below this is a MOBILE (light) build: it strafes through
## its firing window instead of planting (plant-then-fire). At/above it, the build plants.
## TUNING: raise to make more builds strafe; lower to make only the lightest strafe.
const MOBILE_HEFT := 0.4

## Mobile-shooter strafe amplitude as a fraction of the build's WEAVE (the lateral throw of the
## attack-while-strafing weave). A build widens its own strafe by overriding WEAVE in its preset.
const STRAFE_AMP := 0.6

# --- Dominance series / no-prespoil ---
## EMA window in ticks for pressure and sell EMAs. alpha = 2/(W+1).
## TUNING: larger W smooths more (longer memory), smaller W reacts faster.
const W := 10

## Closing-rate normalisation: speed above this reads as full closing pressure (=1).
## TUNING: should match typical inter-mech approach speed in the reference fight (~3–5 u/tick).
const REF_SPEED := 4.0

## Sell detector threshold: a displacement dot product must exceed this to register as a sell.
## TUNING: zero means any backward step counts; raise to require a clear knockback.
const SELL_MIN := 0.5

## Sell weight in staged_dom formula: staged_dom = pressure_A - pressure_B + KAPPA*(sells_B - sells_A).
## TUNING: raise to make sells dominate; lower to emphasise closing pressure.
const KAPPA := 0.4

## Hysteresis constants for reveal().
## A run ENTERS "revealed" at |v| >= CONF; EXITS at |v| < CONF*(1-HYST).
## TUNING: CONF=0.5 means half the max dominance; HYST=0.2 allows a 20% dip without resetting.
const CONF := 0.5
const HYST := 0.2

## SLACK: staged reveal may precede truth reveal by at most SLACK ticks (the tolerance).
## TUNING: 0 = zero tolerance; 5 = five-tick grace.
const SLACK := 5

## Fraction of fight duration that defines the "late gate" for draws.
## If truth_reveal is sentinel (draw), staged must hold open until LATE_FRAC * duration.
const LATE_FRAC := 0.70

## Quantisation step for apparent_initiative series (canonical serialisability).
const Q := 0.05

# --- Shape classifier thresholds ---
## A kill decided at or before this fraction of total ticks is classified as "instant".
## TUNING: 0.20 = first fifth of the fight.
const INSTANT_FRAC   := 0.20

## Margin (|truth_dom[-1]|) at/above which a one-sided fight can be "stomp".
const STOMP_MARGIN   := 0.60

## A stomp must be decided at or before this fraction of total ticks.
const STOMP_FRAC     := 0.50

## A photofinish requires the fight to be decided at or after this fraction.
const CLOSE_MARGIN   := 0.20

# --- Range bands (Proxemic) ---
## Scale factor for mapping world units to the four range-band edges.
const PROXEMIC_SCALE := 1.0
## Range-band edges [close, near, mid, far] in world units.
const RANGE_CLOSE := 20.0
const RANGE_NEAR  := 40.0
const RANGE_MID   := 65.0
const RANGE_FAR   := 90.0
