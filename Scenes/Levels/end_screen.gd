extends Node2D
## Shared script for the Game Over and Victory screens.

@export var victory := false
@export var jingle : AudioStream
@export var music : AudioStream

func _ready() -> void:
	var s = GameManager.player_stats
	$UI/Stats.text = "คะแนน  %d      เหรียญ  %d      ซอมบี้ที่กำจัด  %d" % [
		s.data_get("score"), s.data_get("coins"), s.data_get("killed_enemy")]
	var title = $UI/Title
	title.pivot_offset = title.size / 2
	title.scale = Vector2(2.5, 2.5)
	title.modulate.a = 0
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(title, "scale", Vector2.ONE, 0.9)
	tween.parallel().tween_property(title, "modulate:a", 1.0, 0.4)
	$Jingle.stream = jingle
	$Jingle.play()
	await $Jingle.finished
	if music:
		$Jingle.stream = music
		$Jingle.play()
		$Jingle.finished.connect($Jingle.play)

func _process(_delta: float) -> void:
	if victory and randf() < 0.03:
		_firework()

func _firework() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(randf_range(100, 1100), randf_range(80, 300))
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 60
	p.lifetime = 1.4
	p.spread = 180
	p.initial_velocity_min = 120
	p.initial_velocity_max = 220
	p.gravity = Vector2(0, 120)
	p.damping_min = 40
	p.damping_max = 60
	p.scale_amount_min = 2
	p.scale_amount_max = 4
	p.color = Color.from_hsv(randf(), 0.6, 1.0)
	$Fireworks.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	AudioManager.play("stomp", 0.3)

func _on_btn_retry_pressed() -> void:
	GameManager.restart()
	var level := "res://Scenes/Levels/level_01.tscn"
	if not victory and GameManager.current_level in GameManager.LEVELS:
		level = GameManager.current_level  # continue from the level where the knight fell
	get_tree().change_scene_to_file(level)

func _on_btn_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/menu.tscn")
