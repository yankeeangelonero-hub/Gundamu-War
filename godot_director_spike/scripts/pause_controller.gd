extends Node
## Toggles the SceneTree pause on Space / P.
##
## Runs in PROCESS_MODE_ALWAYS so it keeps receiving input while the rest of the
## scene (left PAUSABLE) is frozen. It is added as a *leaf* child of main — never
## as an ancestor of the gameplay nodes — so its ALWAYS mode does not propagate
## via PROCESS_MODE_INHERIT and accidentally keep the director/mechs running.

var overlay: CanvasLayer  ## the "PAUSED" overlay to show/hide; set by main

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_SPACE or event.keycode == KEY_P):
		var tree := get_tree()
		tree.paused = not tree.paused
		if overlay:
			overlay.visible = tree.paused
