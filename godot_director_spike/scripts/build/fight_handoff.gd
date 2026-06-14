extends RefCounted
## FightHandoff — the static bridge between the build screen and the combat viewer.
##
## Scene changes tear down nodes, so the deploy → fight → return round-trip passes
## data through these static vars (the script resource stays loaded). The build
## screen fills `events` and switches to the combat scene; main.gd plays the events
## when `active`, then returns to `return_scene` and clears `active`. `saved_placement`
## persists the bag so the player comes back to the build they just deployed.

static var active := false
static var events: Array = []
static var director_name := "hybrid"
static var return_scene := "res://scenes/build_screen.tscn"
static var player_label := "VESPER-7"
static var ghost_label := "GHOST"
static var saved_placement: Array = []     # [{def_id, rot, anchor}] — restores the bag on return
static var player_placement: Array = []    # the deployed player loadout (mounted on the fighting mech)
static var ghost_placement: Array = []      # the ghost loadout (mounted on the enemy mech)

static func set_fight(p_events: Array, p_player: String, p_ghost: String) -> void:
	active = true
	events = p_events
	player_label = p_player
	ghost_label = p_ghost

## Clear only the in-flight fight flags; keep saved_placement + return_scene so the
## build screen can restore the bag.
static func clear() -> void:
	active = false
	events = []
