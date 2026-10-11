extends Area2D
## Dark magic orb fired by the boss. Hurts the knight, destroyed by the sword wave.

var velocity := Vector2.ZERO

func shoot(direction: Vector2, speed: float, lifetime: float):
	velocity = direction * speed
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	rotation += delta * 8

func _on_body_entered(body: Node) -> void:
	if body is Player:
		if body.can_damage:
			body._knockback_from(global_position)
			body.damage_tween()
			GameManager.damage(15)
		queue_free()
	elif body.is_in_group("Bullet"):
		body.queue_free()
		queue_free()
	elif body is TileMapLayer or body is StaticBody2D:
		queue_free()
