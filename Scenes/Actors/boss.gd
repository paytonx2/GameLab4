extends Zombie
## The Necro Knight - final boss of level 4. When it dies the exit door appears.

signal boss_defeated

@export var summon_scene : PackedScene
var _summon_timer := 6.0

func _ready() -> void:
	super._ready()
	add_to_group("Boss")

func _physics_process(delta: float) -> void:
	# the boss always knows where the knight is once he enters the arena
	var p := GameManager.player
	if alive and p and is_instance_valid(p) and abs(p.global_position.x - global_position.x) < chase_range \
			and abs(p.global_position.y - global_position.y) < 400:
		player_ref = p
		if state in [State.IDLE, State.WALK, State.PATROL]:
			set_state(State.CHASE)
	super._physics_process(delta)
	if not alive or player_ref == null:
		return
	# summon zombies from time to time when the player is around
	_summon_timer -= delta
	if _summon_timer <= 0 and summon_scene:
		_summon_timer = randf_range(7, 10)
		var minions := get_parent().get_children().filter(func(n): return n is Enemy and n != self and n.alive)
		if minions.size() >= 4:
			return
		for i in 2:
			var z = summon_scene.instantiate()
			z.position = position + Vector2(randf_range(-200, 200), -40)
			z.direction = [-1, 1].pick_random()
			get_parent().add_child(z)
		AudioManager.play("magic")

func die() -> void:
	if not alive:
		return
	GameManager.add_score(50)
	boss_defeated.emit()
	super.die()
