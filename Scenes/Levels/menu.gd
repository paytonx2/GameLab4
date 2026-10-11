extends Node2D

@onready var btn_continue: Button = $UI/Buttons/btnContinue
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	$UI.size = get_viewport_rect().size
	btn_continue.disabled = !GameManager.has_gamesaved()
	GameManager.load_option()
	# quitting is not possible in a web browser
	$UI/Buttons/btnExit.visible = not OS.has_feature("web")
	$UI/Buttons/btnStart.grab_focus()
	$Music.finished.connect($Music.play)
	# title animation
	var title = $UI/Title
	title.pivot_offset = title.size / 2
	title.scale = Vector2(0.6, 0.6)
	title.modulate.a = 0
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(title, "scale", Vector2.ONE, 0.8)
	tween.parallel().tween_property(title, "modulate:a", 1.0, 0.6)
	for b in $UI/Buttons.get_children():
		b.mouse_entered.connect(func(): AudioManager.play("select"))

func _process(_delta: float) -> void:
	# slow glow on the title
	$UI/Title.add_theme_color_override("font_outline_color", Color(0.5 + sin(Time.get_ticks_msec() / 400.0) * 0.2, 0.05, 0.1))


func _on_btn_start_pressed() -> void:
	AudioManager.play("select")
	GameManager.restart()
	get_tree().change_scene_to_file("res://Scenes/Levels/story.tscn")


func _on_btn_option_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/options.tscn")


func _on_btn_credit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/credit.tscn")


func _on_btn_continue_pressed() -> void:
	GameManager.load_game()


func _on_btn_exit_pressed() -> void:
	get_tree().quit()
