extends Area2D
## Warp gate. Set `target` to another portal in the same level.

@export var target : NodePath
var locked := false

func _on_body_entered(body: Node2D) -> void:
	if locked or not body is Player or target.is_empty():
		return
	var dest := get_node_or_null(target)
	if dest == null:
		return
	dest.locked = true
	AudioManager.play("magic")
	var tween = create_tween()
	tween.tween_property(body, "scale", Vector2(0.1, 1.6), 0.12)
	tween.tween_callback(func(): body.global_position = dest.global_position + Vector2(0, 40))
	tween.tween_property(body, "scale", Vector2.ONE, 0.15)
	await get_tree().create_timer(1.0).timeout
	dest.locked = false

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		locked = false
