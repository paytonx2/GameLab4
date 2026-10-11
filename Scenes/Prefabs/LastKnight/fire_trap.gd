extends StaticBody2D
## Brazier that bursts into a column of fire every few seconds.

@export var on_time := 1.4
@export var off_time := 1.8
@export var start_delay := 0.0

func _ready() -> void:
	$Flame.emitting = false
	$CollisionShape2D.disabled = true
	await get_tree().create_timer(start_delay + randf() * 0.5).timeout
	while is_inside_tree():
		$Warn.emitting = true
		await get_tree().create_timer(0.5).timeout
		$Warn.emitting = false
		$Flame.emitting = true
		$CollisionShape2D.set_deferred("disabled", false)
		await get_tree().create_timer(on_time).timeout
		$Flame.emitting = false
		$CollisionShape2D.set_deferred("disabled", true)
		await get_tree().create_timer(off_time).timeout
