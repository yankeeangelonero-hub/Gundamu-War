extends Node
## Grade — the Director Grammar's Lighting + Color render layer (Phase 2).
## Owns the WorldEnvironment's mood grade (F22 chromatic fill, F26/F27 mood
## variants). Reads its values from a ShotGrammar; it is the only authority on
## the post-render mood. It subscribes READ-ONLY to the director's fight_event
## and writes nothing back into the sim or camera — determinism is preserved.
## Spec: docs/superpowers/specs/2026-06-16-director-grammar-design.md

var _env: Environment
var _grammar: ShotGrammar
var _director: Node

# Active and target mood adjustment values, eased each frame toward the target.
var _cur := {"brightness": 1.0, "contrast": 1.0, "saturation": 1.0, "warmth": 0.0}
var _target := {"brightness": 1.0, "contrast": 1.0, "saturation": 1.0, "warmth": 0.0}

## Bind the render target + authored values. director may be null (tests / no
## beat-driven moods); when present, beats drive mood pushes (Task 4).
func bind(env: Environment, grammar: ShotGrammar, director: Node = null) -> void:
	_env = env
	_grammar = grammar
	_director = director

## Apply the chromatic fill (F22) and the neutral base mood. Called once at start.
func apply_base() -> void:
	if _env == null or _grammar == null:
		return
	_env.adjustment_enabled = true
	# Own the ambient source (codex #4): the chromatic fill is only honored when the
	# ambient comes from a color, not the sky. Set it here so the Grade is correct
	# regardless of how city_builder configured the environment.
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var base: Dictionary = _grammar.mood_variants.get("base", _cur)
	_cur = base.duplicate()
	_target = base.duplicate()
	_write(_cur)

## Push the named mood as the new lerp target. Unknown names are ignored.
func set_mood(name: String) -> void:
	if _grammar == null or not _grammar.mood_variants.has(name):
		return
	_target = (_grammar.mood_variants[name] as Dictionary).duplicate()

## Write a mood dict to the Environment: brightness/contrast/saturation to the
## tonemap adjustments, warmth as a tint shift around the chromatic fill.
func _write(m: Dictionary) -> void:
	_env.adjustment_brightness = float(m["brightness"])
	_env.adjustment_contrast = float(m["contrast"])
	_env.adjustment_saturation = float(m["saturation"])
	var w := float(m["warmth"])
	# Warm (+) lifts red, drops blue around the cool fill; cool (-) the reverse.
	var fill: Color = _grammar.chromatic_fill
	_env.ambient_light_color = Color(
		clampf(fill.r + w * 0.10, 0.0, 1.0),
		clampf(fill.g + w * 0.02, 0.0, 1.0),
		clampf(fill.b - w * 0.08, 0.0, 1.0),
		fill.a)
