extends Node2D
## Spear trap: waits a random delay, then the spear stabs up out of the ground.
## The AnimationPlayer "push" enables the collision only while the spear is out.

@export var min_delay := 0.5
@export var max_delay := 2.5

func _ready() -> void:
	$AnimationPlayer.animation_finished.connect(_on_finished)
	_next()

func _next() -> void:
	await get_tree().create_timer(randf_range(min_delay, max_delay)).timeout
	$AnimationPlayer.play("push")

func _on_finished(_name) -> void:
	_next()
