extends Node2D
## Moves the first child (a platform or a trap) back and forth between its start and `offset`.
## Used by moving platforms, elevators and moving saw blades.

@export var offset := Vector2(192, 0)
@export var duration := 2.5
@export var pause := 0.5

func _ready() -> void:
	var body := get_child(0) as Node2D
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(body, "position", offset, duration)
	tween.tween_interval(pause)
	tween.tween_property(body, "position", Vector2.ZERO, duration)
	tween.tween_interval(pause)
