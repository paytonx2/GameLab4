class_name Zombie
extends Enemy
## Animated undead monster (zombie, zombie boar, ghost wasp, boss).
## Uses an AnimatedSprite2D at $Sprite/Anim with animations: walk, attack, hurt (optional), idle (optional)

@export var walk_anim_speed := 1.0
@export var flying := false
@export var hover_amplitude := 30.0
## Bosses / ranged monsters shoot this when attacking
@export var projectile_scene : PackedScene
@export var projectile_speed := 380.0

@onready var anim : AnimatedSprite2D = $Sprite/Anim
var _t := 0.0
var _home := Vector2.ZERO

func _ready() -> void:
	super._ready()
	_home = global_position
	state_changed.connect(_on_state_changed)
	_on_state_changed(state)

func _physics_process(delta: float) -> void:
	if flying:
		_fly(delta)
		return
	super._physics_process(delta)

# Flying monsters ignore gravity, hover around their home point and dive at the player
func _fly(delta: float) -> void:
	if not alive:
		return
	_t += delta
	var target := _home + Vector2(sin(_t * 0.7) * patrol_range * 0.5, sin(_t * 2.0) * hover_amplitude)
	var p := GameManager.player
	if p and is_instance_valid(p) and p.global_position.distance_to(global_position) < chase_range:
		target = p.global_position + Vector2(0, -50)
		if state != State.CHASE:
			set_state(State.CHASE)
	elif state != State.WALK:
		set_state(State.WALK)
	var to := target - global_position
	velocity = velocity.lerp(to.normalized() * min(speed, to.length() * 3), 0.05)
	direction = 1 if velocity.x > 0 else -1
	move_and_slide()

func _on_state_changed(new_state: Enemy.State) -> void:
	if anim == null:
		return
	match new_state:
		State.ATTACK:
			if anim.sprite_frames.has_animation("attack"):
				anim.play("attack")
		State.DAMAGED:
			if anim.sprite_frames.has_animation("hurt"):
				anim.play("hurt")
		State.IDLE, State.REST:
			anim.play("idle" if anim.sprite_frames.has_animation("idle") else "walk")
		State.CHASE:
			anim.play("walk", walk_anim_speed * 1.5)
		_:
			anim.play("walk", walk_anim_speed)

func perform_attack() -> void:
	if anim.sprite_frames.has_animation("attack"):
		anim.play("attack")
	if projectile_scene and player_ref:
		var b = projectile_scene.instantiate()
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(0, -60)
		var dir: Vector2 = (player_ref.global_position + Vector2(0, -40) - b.global_position).normalized()
		b.shoot(dir, projectile_speed, 3.0)

func stomp_effect() -> void:
	if has_node("Explosion"):
		$Explosion.restart()
		$Explosion.emitting = true

func die() -> void:
	if not alive:
		return
	stomp_effect()
	AudioManager.play("vanish", 0.1)
	super.die()
