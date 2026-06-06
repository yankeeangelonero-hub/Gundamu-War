# rig_spike.gd — KM-STACK-SPIKE mech cutout rig
#
# Hierarchy built entirely from code against kb-art-manifest.json anchors:
#
#   RigSpike (Node2D)
#   ├── Frame  (Sprite2D, centered=false, z=3)
#   │   ├── Torso    (Sprite2D, centered=false, z=3)
#   │   └── ForearmR (Sprite2D, centered=false, z=5)   ← animated by AnimationPlayer
#   │       └── Weapon (Sprite2D, centered=false, z=6) ← saber or rifle
#   │           └── FX (AnimatedSprite2D)              ← flipbook effect
#   └── AnimationPlayer
#
# Pivot math:  child_pos_in_parent = parent_hardpoint_px - child_pivot_px
# All values from the manifest; frame canvas is 360 × 620.
extends Node2D

const ASSETS := "res://assets/"

# Frame canvas (manifest: frame.canvas)
const FW := 360.0
const FH := 620.0

# Frame hardpoints — anchorNorm from manifest
const HP_TORSO     := Vector2(0.51, 0.41)
const HP_FOREARM_R := Vector2(0.69, 0.46)
const HP_HAND_R    := Vector2(0.70, 0.56)

# Pivots from manifest (px from sprite top-left)
const PIVOT_TORSO   := Vector2(110.0, 30.0)
const PIVOT_FOREARM := Vector2(50.0,  14.0)
const PIVOT_SABER   := Vector2(30.0, 180.0)
const PIVOT_RIFLE   := Vector2(45.0, 205.0)

var _frame:    Sprite2D
var _forearm:  Sprite2D
var _weapon:   Sprite2D
var _fx:       AnimatedSprite2D
var _anim_player: AnimationPlayer

var _is_saber := true
var _attack_active := false

var _saber_frames: SpriteFrames
var _spark_frames: SpriteFrames

func _ready() -> void:
	_build_rig()
	_build_fx_frames()
	_build_animation_player()
	_attach_fx()

# ── rig construction ──────────────────────────────────────────────────────────

func _build_rig() -> void:
	# Frame — root part, centered on 1280 × 720
	_frame = Sprite2D.new()
	_frame.name = "Frame"
	_frame.texture = load(ASSETS + "rig_frame.png")
	_frame.centered = false
	_frame.z_index = 3
	_frame.position = Vector2((1280.0 - FW) / 2.0, (720.0 - FH) / 2.0)
	add_child(_frame)

	# Torso — child of frame, pivot [110, 30], attaches at frame torso hardpoint
	var torso := Sprite2D.new()
	torso.name = "Torso"
	torso.texture = load(ASSETS + "rig_torso.png")
	torso.centered = false
	torso.z_index = 3
	torso.position = Vector2(HP_TORSO.x * FW, HP_TORSO.y * FH) - PIVOT_TORSO
	_frame.add_child(torso)

	# ForearmR — child of frame, pivot [50, 14], attaches at frame forearm.R hardpoint
	_forearm = Sprite2D.new()
	_forearm.name = "ForearmR"
	_forearm.texture = load(ASSETS + "rig_forearm.png")
	_forearm.centered = false
	_forearm.z_index = 5
	_forearm.position = Vector2(HP_FOREARM_R.x * FW, HP_FOREARM_R.y * FH) - PIVOT_FOREARM
	_frame.add_child(_forearm)

	# Weapon — child of forearm (so it moves with forearm during animation)
	_weapon = Sprite2D.new()
	_weapon.name = "Weapon"
	_weapon.centered = false
	_weapon.z_index = 6
	_forearm.add_child(_weapon)
	_set_weapon(true)

func _hand_in_forearm_local() -> Vector2:
	# frame-local hand.R position minus forearm's frame-local position
	return Vector2(HP_HAND_R.x * FW, HP_HAND_R.y * FH) - _forearm.position

func _set_weapon(is_saber: bool) -> void:
	_is_saber = is_saber
	var grip := _hand_in_forearm_local()
	if is_saber:
		_weapon.texture = load(ASSETS + "rig_saber.png")
		_weapon.position = grip - PIVOT_SABER
	else:
		_weapon.texture = load(ASSETS + "rig_rifle.png")
		_weapon.position = grip - PIVOT_RIFLE

# ── FX flipbooks ──────────────────────────────────────────────────────────────

func _build_fx_frames() -> void:
	# Saber blade — 4 frames, looping (continuous blade glow)
	_saber_frames = SpriteFrames.new()
	_saber_frames.add_animation(&"saber_blade")
	_saber_frames.set_animation_loop(&"saber_blade", true)
	_saber_frames.set_animation_speed(&"saber_blade", 8.0)
	for i in 4:
		var tex := load(ASSETS + "fx_saber_blade_%02d.png" % i) as Texture2D
		_saber_frames.add_frame(&"saber_blade", tex)

	# Hit spark — 4 frames, one-shot
	_spark_frames = SpriteFrames.new()
	_spark_frames.add_animation(&"hit_spark")
	_spark_frames.set_animation_loop(&"hit_spark", false)
	_spark_frames.set_animation_speed(&"hit_spark", 12.0)
	for i in 4:
		var tex := load(ASSETS + "fx_hit_spark_%02d.png" % i) as Texture2D
		_spark_frames.add_frame(&"hit_spark", tex)

# ── AnimationPlayer ───────────────────────────────────────────────────────────

func _build_animation_player() -> void:
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	add_child(_anim_player)

	# "melee" — forearm swings 0.4 s (authored attack animation)
	# Track path relative to AnimationPlayer's root (= RigSpike parent)
	var anim := Animation.new()
	anim.length = 0.4

	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, "Frame/ForearmR:rotation")
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	anim.track_insert_key(t, 0.0,  0.0)   # neutral
	anim.track_insert_key(t, 0.10, -0.3)  # wind-up (radians)
	anim.track_insert_key(t, 0.30,  0.7)  # swing through
	anim.track_insert_key(t, 0.40,  0.0)  # return

	var lib := AnimationLibrary.new()
	lib.add_animation(&"melee", anim)
	_anim_player.add_animation_library(&"", lib)

	_anim_player.animation_finished.connect(_on_attack_done)

func _attach_fx() -> void:
	_fx = AnimatedSprite2D.new()
	_fx.name = "FX"
	_fx.centered = true
	_fx.visible = false
	_fx.position = Vector2(10.0, -60.0)  # near blade tip / muzzle
	_weapon.add_child(_fx)

# ── public API ────────────────────────────────────────────────────────────────

func swap_weapon() -> void:
	_set_weapon(not _is_saber)

func set_weapon_visual(visual: String) -> void:
	if visual == "saber":
		_set_weapon(true)
	else:
		_set_weapon(false)

func weapon_is_saber() -> bool:
	return _is_saber

func play_attack_event(event: Dictionary) -> void:
	# BEH-004: only one primary attack animation at a time
	if _attack_active:
		return
	_attack_active = true

	var clip: String = event.get("clip", "melee_saber")

	# Authored attack animation (forearm swing via AnimationPlayer)
	_anim_player.play(&"melee")

	# Flipbook FX sequence
	_fx.stop()
	if "saber" in clip:
		_fx.sprite_frames = _saber_frames
		_fx.animation = &"saber_blade"
	else:
		_fx.sprite_frames = _spark_frames
		_fx.animation = &"hit_spark"
	_fx.visible = true
	_fx.play()

func _on_attack_done(_anim_name: StringName) -> void:
	_attack_active = false
	_fx.stop()
	_fx.visible = false
