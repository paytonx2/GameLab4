class_name Player
extends CharacterBody2D

signal hit_enemy
signal hit_trap


# --------- VARIABLES ---------- #

@export_category("Player Properties") # You can tweak these changes according to your likings
@export var move_speed : float = 300
@export var jump_force : float = 700
@export var gravity : float = 30
@export var max_jump_count : int = 2
@export var bullet_scene : PackedScene
@export var shoot_cooldown_time : float = 0.35
@export var bullet_lifetime = 0.45
@export var trap_damage : int = 15
@export var stomp_damage : int = 40
## Falling below this Y kills the player (set by the level from the map size)
@export var fall_limit : float = 3000

var jump_count : int = 2
var flip_x = false

@export_category("Toggle Functions") # Double jump feature is disable by default (Can be toggled from inspector)
@export var double_jump : = true

var is_grounded : bool = false
var movement_enabled : bool = true
var spawn_point = Vector2(0,0)
var is_attacking = false
var shoot_cooldown_timer = 0.0
var can_damage = true
var is_dead = false

@onready var knight : AnimatedSprite2D = $Knight
@onready var bullet_marker = $BulletMarker
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles
@onready var boost_particles = $BoostParticles



# --------- BUILT-IN FUNCTIONS ---------- #
func _ready() -> void:
	spawn_point = global_position
	if GameManager.save_player_position.x != 0:
		global_position =  GameManager.save_player_position
		GameManager.save_player_position = Vector2.ZERO
	knight.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta):
	is_grounded = is_on_floor()
	movement()
	_check_stomp()
	_handle_enemy_contact()
	if global_position.y > fall_limit and movement_enabled:
		GameManager.death()

func _process(_delta):
	player_animations()
	flip_player()
	handle_shooting()
	if shoot_cooldown_timer > 0:
		shoot_cooldown_timer -= _delta
	boost_particles.emitting = GameManager.speed_boost_time > 0 or GameManager.jump_boost_time > 0

# --------- CUSTOM FUNCTIONS ---------- #

func current_speed() -> float:
	return move_speed * (1.5 if GameManager.speed_boost_time > 0 else 1.0)

func current_jump() -> float:
	return jump_force * (1.3 if GameManager.jump_boost_time > 0 else 1.0)

# <-- Player Movement Code -->
func movement():
	# Gravity
	if !is_on_floor():
		velocity.y += gravity
	elif is_on_floor():
		jump_count = max_jump_count
		if abs(velocity.x)>0.5:
			velocity.x *= 0.6
		else:
			velocity.x =0

	handle_jumping()

	# Move Player
	if movement_enabled:
		if Input.is_action_pressed("Left"):
			velocity.x = -current_speed()
			flip_x = true
		if Input.is_action_pressed("Right"):
			velocity.x = current_speed()
			flip_x = false
	velocity.y = min(velocity.y, 1400)
	move_and_slide()

# Handles jumping functionality (double jump or single jump, can be toggled from inspector)
func handle_jumping():
	if Input.is_action_just_pressed("Jump") and movement_enabled:
		if is_on_floor() and !double_jump:
			jump()
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

# Player jump
func jump():
	jump_tween()
	AudioManager.play("jump", 0.1)
	velocity.y = -current_jump()

# Called by jump boards (springs)
func bounce(force: float):
	velocity.y = -force
	jump_count = max_jump_count - 1
	AudioManager.play("jump_high")

# Handle Player Animations
func player_animations():
	particle_trails.emitting = false
	if is_dead or is_attacking:
		return

	if is_on_floor():
		if abs(velocity.x) > 0:
			particle_trails.emitting = true
			knight.play("run")
		else:
			knight.play("idle")
	else:
		knight.play("jump" if velocity.y < 0 else "fall")


# Flip player sprite based on X velocity
func flip_player():
	knight.flip_h = flip_x
	bullet_marker.position.x = -abs(bullet_marker.position.x) if flip_x else abs(bullet_marker.position.x)

# Tween Animations
func death_tween(game_over := false):
	is_dead = true
	movement_enabled = false
	velocity = Vector2.ZERO
	AudioManager.death_sfx.play()
	knight.play("dead")
	await get_tree().create_timer(1.0).timeout
	if game_over:
		return
	death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tween.finished
	global_position = spawn_point
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.3).timeout
	is_dead = false
	movement_enabled = true
	AudioManager.respawn_sfx.play()
	respawn_tween()

func respawn_tween():
	var tween = create_tween()
	tween.stop(); tween.play()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	tween.parallel().tween_property(self, "position", spawn_point, 0.15)
	damage_tween()

func jump_tween():
	var tween = create_tween()
	tween.tween_property(knight, "scale", Vector2(0.8, 1.2), 0.1)
	tween.tween_property(knight, "scale", Vector2(1.0,1.0), 0.1)

func damage_tween():
	var tween = create_tween()
	tween.stop(); tween.play()
	can_damage = false
	for i in range(1,8):
		tween.tween_property(knight , "modulate", Color(1,0.3,0.3,0.6), 0.1)
		tween.tween_property(knight , "modulate", Color.WHITE, 0.1)
	await tween.finished
	can_damage = true

# Called by GameManager.damage()
func hurt_feedback():
	AudioManager.play("hurt")
	var cam = $Camera2D
	var tween = create_tween()
	for i in 4:
		tween.tween_property(cam, "offset", Vector2(randf_range(-6,6), randf_range(-6,6)), 0.03)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.03)

func _handle_enemy_contact() -> void:
	if !can_damage or is_dead:
		return
	var bodies = $Collision.get_overlapping_bodies()
	for body in bodies:
		if body != null:
			_on_collision_body_entered(body)
			if !can_damage:
				return

func _knockback_from(pos: Vector2) -> void:
	velocity.y = -400
	velocity.x = -300 if pos.x > global_position.x else 300

func _apply_enemy_damage(body) -> void:
	_knockback_from(body.global_position)
	damage_tween()
	GameManager.damage(body.atk if "atk" in body else 10)
	hit_enemy.emit()

# Jump on top of a monster to defeat it (Mario style)
func _check_stomp() -> void:
	if is_dead:
		return
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var body = col.get_collider()
		if body is Enemy and body.alive and col.get_normal().y < -0.6:
			body.take_damage(stomp_damage, global_position.x)
			if body.has_method("stomp_effect"):
				body.stomp_effect()
			velocity.y = -550
			jump_count = max_jump_count - 1
			AudioManager.play("stomp")
			can_damage = false
			get_tree().create_timer(0.25).timeout.connect(func(): can_damage = true)
			return

# --------- SIGNALS ---------- #

# Traps no longer kill instantly: they hurt and push the knight back
func _on_collision_body_entered(body):
	if body.is_in_group("Traps"):
		_knockback_from(body.global_position)
		damage_tween()
		GameManager.damage(trap_damage)
		hit_trap.emit()
	elif body.is_in_group("Bullet_Enemy"):
		_knockback_from(body.global_position)
		damage_tween()
		GameManager.damage(15)
		body.queue_free()
	elif body.is_in_group("Enemy") and can_damage:
		if body is Enemy and not body.alive:
			return
		_apply_enemy_damage(body)

func handle_shooting():
	if Input.is_action_just_pressed("Shoot") and movement_enabled and shoot_cooldown_timer <= 0:
		shoot()

# Sword attack: plays the slash animation and releases a short-range sword wave
func shoot():
	if bullet_scene == null:
		return
	is_attacking = true
	knight.play("attack")
	AudioManager.play("slash", 0.15)
	var bullet = bullet_scene.instantiate()
	bullet.global_position = bullet_marker.global_position
	var dir = Vector2(-1.0 if flip_x else 1.0, 0)
	get_parent().add_child(bullet)
	bullet.shoot(dir, 900, bullet_lifetime)
	shoot_cooldown_timer = shoot_cooldown_time

func _on_animation_finished() -> void:
	if knight.animation == "attack":
		is_attacking = false

