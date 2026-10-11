extends Area2D
## Banner of the Order of Dawn: becomes the respawn point when touched.

var active := false

func _on_body_entered(body: Node2D) -> void:
	if active or not body is Player:
		return
	active = true
	body.spawn_point = global_position + Vector2(0, -4)
	$Sprite.play("active")
	$Particles.emitting = true
	AudioManager.play("magic")
	GameManager.add_hp(25)
	var ui = get_tree().current_scene.get_node_or_null("UserInterface")
	if ui:
		ui.alert("Checkpoint!")
