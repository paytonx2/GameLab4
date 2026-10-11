extends Node2D

func _ready() -> void:
	GameManager.load_option()
	$Music.button_pressed = GameManager.music_on
	$Sound.button_pressed = GameManager.sfx_on

func _on_music_toggled(on: bool) -> void:
	GameManager.music_on = on
	GameManager.update_option()
	GameManager.save_option()

func _on_sound_toggled(on: bool) -> void:
	GameManager.sfx_on = on
	GameManager.update_option()
	GameManager.save_option()
	AudioManager.play("select")
