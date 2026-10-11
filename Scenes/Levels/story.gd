extends Node2D
## Opening story: the text is revealed line by line, then level 1 starts.

const STORY := """ณ อาณาจักรเอลโดเรีย ที่เคยสงบสุขภายใต้แสงแห่งรุ่งอรุณ...

"มอร์ธัส" อดีตแม่ทัพแห่งภาคีอัศวินรุ่งอรุณ ได้ทรยศและทำสัญญากับความตาย
เขากลายเป็น "อัศวินเนโคร" และปลดปล่อยคำสาปแห่งราตรีนิรันดร์

ผู้คนกลายเป็นซอมบี้ สัตว์ป่าเน่าเปื่อยลุกขึ้นอาละวาด
อัศวินทุกคนล้มลง... เหลือเพียงคนเดียว

"เอเรน" อัศวินคนสุดท้าย ผู้ถือดาบแห่งรุ่งอรุณที่ปล่อยคลื่นแสงได้
จงฝ่าผืนป่า สุสาน และบุกปราสาท เพื่อโค่นมอร์ธัส และนำแสงอรุณกลับคืนมา!"""

var done := false

func _ready() -> void:
	$Text.text = STORY
	$Text.visible_ratio = 0.0
	var tween = create_tween()
	tween.tween_property($Text, "visible_ratio", 1.0, 14.0)
	tween.tween_callback(func(): done = true)
	tween.tween_interval(4.0)
	tween.tween_callback(start_game)
	$Music.finished.connect($Music.play)

func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch):
		if done or $Text.visible_ratio > 0.98:
			start_game()
		else:
			# first press shows the whole text
			$Text.visible_ratio = 1.0
			done = true

var started := false
func start_game() -> void:
	if started:
		return
	started = true
	if not OS.has_feature("web") and not OS.is_debug_build():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	SceneTransition.load_scene(load("res://Scenes/Levels/level_01.tscn"))
