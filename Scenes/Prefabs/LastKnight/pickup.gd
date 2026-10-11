extends Area2D
## Collectible item. kind: coin, gem, heart, life, speed, jump

@export_enum("coin", "gem", "heart", "life", "speed", "jump") var kind := "coin"
@export var amplitude := 5.0
@export var frequency := 3.0

var _t := 0.0
var _base_y := 0.0
var taken := false

func _ready() -> void:
	_base_y = position.y
	_t = randf() * 10.0

func _process(delta: float) -> void:
	if taken:
		return
	_t += delta
	position.y = _base_y + sin(_t * frequency) * amplitude

func _on_body_entered(body: Node2D) -> void:
	if taken or not body is Player:
		return
	taken = true
	var text := ""
	match kind:
		"coin":
			GameManager.add_coin(1)
			AudioManager.play("coin", 0.1)
		"gem":
			GameManager.add_score(5)
			AudioManager.play("gem")
			text = "+5"
		"heart":
			GameManager.add_hp(30)
			AudioManager.play("gem")
			text = "HP +30"
		"life":
			GameManager.add_life()
			AudioManager.play("magic")
			text = "1 UP!"
		"speed":
			GameManager.speed_boost_time = 10.0
			AudioManager.play("magic")
			text = "SPEED UP! (10s)"
		"jump":
			GameManager.jump_boost_time = 10.0
			AudioManager.play("magic")
			text = "SUPER JUMP! (10s)"
	if text != "":
		var ui = get_tree().current_scene.get_node_or_null("UserInterface")
		if ui:
			ui.alert(text)
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 60, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(self, "scale", Vector2(1.6, 1.6), 0.4)
	tween.tween_callback(queue_free)
