extends RigidBody2D
## Sword wave released by the knight's slash (group "Bullet": monsters take damage on contact)

func shoot(direction: Vector2, speed: float, lifetime: float):
	linear_velocity = direction * speed
	$Sprite.flip_h = direction.x < 0
	$Sprite.play("default")
	var tween = create_tween()
	tween.tween_interval(lifetime * 0.6)
	tween.tween_property(self, "modulate:a", 0.0, lifetime * 0.4)
	tween.tween_callback(queue_free)

func _on_body_entered(_body: Node) -> void:
	# hit a wall: vanish
	queue_free()
