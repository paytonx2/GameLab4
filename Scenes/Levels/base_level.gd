extends Node2D

## Name shown when the level starts
@export var level_title := "Level x"
@export_multiline var level_subtitle := ""
@export var music : AudioStream

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.player = %Player
	if music:
		$MusicPlayer.stream = music
	$MusicPlayer.play(0)
	_setup_camera()
	_setup_boss_door()

	var label : Label = $UserInterface/Label
	label.text = level_title + ("\n" + level_subtitle if level_subtitle != "" else "")
	label.pivot_offset = label.size / 2
	var tween = create_tween()
	label.scale = Vector2.ZERO
	tween.stop(); tween.play()
	tween.tween_property(label, "scale", Vector2.ONE, 1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(3).timeout
	tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	await tween.finished
	label.queue_free()

# Limit the camera to the painted part of the Ground tile map
func _setup_camera() -> void:
	var ground : TileMapLayer = get_node_or_null("Level/Ground")
	if ground == null:
		return
	var rect := ground.get_used_rect()
	var ts := ground.tile_set.tile_size
	var cam : Camera2D = %Player.get_node("Camera2D")
	cam.limit_left = rect.position.x * ts.x
	cam.limit_right = rect.end.x * ts.x
	cam.limit_top = rect.position.y * ts.y - 400
	cam.limit_bottom = rect.end.y * ts.y
	%Player.fall_limit = rect.end.y * ts.y + 64

# On the boss level the exit door appears only after the boss is defeated
func _setup_boss_door() -> void:
	var boss = get_tree().get_first_node_in_group("Boss")
	if boss == null:
		return
	var door = $LevelFinishDoor
	door.visible = false
	door.process_mode = Node.PROCESS_MODE_DISABLED
	boss.boss_defeated.connect(func():
		door.visible = true
		door.process_mode = Node.PROCESS_MODE_INHERIT
		door.scale = Vector2.ZERO
		create_tween().tween_property(door, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK)
		$UserInterface.alert("ประตูแห่งรุ่งอรุณเปิดแล้ว!")
	)

func _on_player_hit_enemy() -> void:
	pass # damage is applied by the Player (GameManager.damage)

func _on_player_hit_trap() -> void:
	pass # traps hurt the player instead of killing instantly


func _on_music_player_finished() -> void:
	$MusicPlayer.play(0)
