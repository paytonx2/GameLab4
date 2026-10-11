extends Area2D

# Define the next scene to load in the inspector (empty = the game is won)
@export var next_scene : PackedScene
var used := false

# Load next level scene when player collide with level finish door.
func _on_body_entered(body):
	if used or not body.is_in_group("Player"):
		return
	used = true
	AudioManager.level_complete_sfx.play()
	body.movement_enabled = false
	var tween = create_tween()
	tween.tween_property(body, "modulate:a", 0.0, 0.4)
	await tween.finished
	if next_scene != null:
		SceneTransition.load_scene(next_scene)
	else:
		SceneTransition.load_scene(load("res://Scenes/Levels/game_win.tscn"))
