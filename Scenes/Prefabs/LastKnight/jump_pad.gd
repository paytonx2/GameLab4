extends Area2D
## Spring board: launches the knight high into the air.

@export var force := 1250.0

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.bounce(force)
		$Sprite.play("boing")
