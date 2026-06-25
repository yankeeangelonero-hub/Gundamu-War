extends CanvasLayer
## Debug Director - live feel/balance tuning bench (behind main.gd --debug).
## Spec: docs/superpowers/specs/2026-06-22-debug-director-tuning-ui-design.md
## Slice 1: scaffold - a side panel with the title and a Replay button that re-films the
## current fight. Later slices add the live ShotGrammar sliders, shot-type toggles, preset
## drop-in, the parametric build controls, and the metrics HUD.

signal replay_requested

func _ready() -> void:
	layer = 10
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	root.position = Vector2(-230, 12)
	root.custom_minimum_size = Vector2(218, 0)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)
	var title := Label.new()
	title.text = "DEBUG DIRECTOR"
	title.add_theme_font_size_override("font_size", 16)
	col.add_child(title)
	var hint := Label.new()
	hint.text = "live feel/balance bench"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.6)
	col.add_child(hint)
	col.add_child(HSeparator.new())
	var replay := Button.new()
	replay.text = "Replay  (re-film)"
	replay.pressed.connect(func(): replay_requested.emit())
	col.add_child(replay)
