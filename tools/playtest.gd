extends Node
## Bot for quick playtests: walks right, jumps and slashes.
##   Godot --path . res://tools/playtest.tscn -- level=2 x=60
## (x = tile column where the knight starts)

var t := 0.0

func _ready() -> void:
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		# re-create the bot outside of the current scene so it survives scene changes
		var bot = load("res://tools/playtest.gd").new()
		bot.name = "Bot"
		get_tree().root.add_child.call_deferred(bot)
		set_process(false)
		return
	var level := 1
	var start_x := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level = int(a.substr(6))
		if a.begins_with("x="):
			start_x = int(a.substr(2))
	GameManager.restart()
	get_tree().change_scene_to_file.call_deferred("res://Scenes/Levels/level_%02d.tscn" % level)
	if start_x >= 0:
		await get_tree().create_timer(0.3).timeout
		var p = get_tree().current_scene.get_node("Player")
		p.global_position.x = start_x * 32
		p.spawn_point = p.global_position

func _process(delta: float) -> void:
	t += delta
	if OS.get_cmdline_user_args().has("debug") and fmod(t, 1.0) < delta:
		var b = get_tree().get_first_node_in_group("Boss")
		var p = get_tree().current_scene.get_node_or_null("Player")
		if b and p:
			print("t=%.0f player=%s boss=%s state=%d hp=%d alive=%s" % [t, p.global_position, b.global_position, b.state, b.hp, b.alive])
	if t < 1.0:
		return
	Input.action_press("Right")
	if fmod(t, 1.1) < delta:
		Input.action_press("Jump")
	elif fmod(t, 1.1) < 0.4:
		Input.action_release("Jump")
	if fmod(t, 0.7) < delta:
		Input.action_press("Shoot")
	else:
		Input.action_release("Shoot")
