extends Node2D
## Spins the node (saw blades, spike balls)
@export var speed := 6.0
func _process(delta: float) -> void:
	rotation += speed * delta
