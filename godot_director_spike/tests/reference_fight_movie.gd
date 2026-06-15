extends SceneTree
## Thin bootstrapper for the reference-fight movie capture.
## The fight_log_everything.json is already checked in under data/ — no simulation
## needed. This script simply boots main.tscn via change_scene_to_file so that the
## --log= / --director= / --write-movie flags picked up by main.gd do the work.
##
## Run WITH --write-movie to capture the AVI:
##   godot --path godot_director_spike --write-movie tmp/reference_fight_hybrid.avi ^
##         -- --director=hybrid --log=fight_log_everything ^
##         -s res://tests/reference_fight_movie.gd

func _initialize() -> void:
	print("reference_fight_movie: booting main.tscn with fight_log_everything + hybrid director")
	change_scene_to_file("res://scenes/main.tscn")
