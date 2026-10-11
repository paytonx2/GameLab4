class_name Enemy
extends CharacterBody2D

## Enemy AI Help
# This script is the shared base controller for all enemies in the project.
# It is intentionally designed as an abstract action-platformer AI layer.
#
# - Use this file as the reference for shared enemy behavior.
# - Extend this class for concrete monsters, bosses, and special units.
# - Keep state logic centralized to make balancing and debugging easier.
#
## AI Overview
# Enemies in this project follow a classic action-game pattern:
# 1. Detect player and decide whether to patrol, chase, or retreat.
# 2. Move according to the selected state.
# 3. Attack only when the distance and cooldown rules allow it.
# 4. Recover or die when HP reaches critical values.
#
## State Machine
# AI state machine used by the enemy. Each state represents a distinct combat or
# movement behavior that can be entered from the main update loop.
enum State { IDLE, WALK, PATROL, REST, CHASE, ATTACK, DEAD, DAMAGED }

# Enemy archetype. Type determines how the AI evaluates distance and engagement.
enum Type { DUMMY, PINGPONG, NEAR, FAR, DEFENSE, BOSS }

@export_category("Enemy Stats")
# Base move speed used by the AI while walking, chasing, or patrolling.
@export var speed: float = 100.0
# Current horizontal direction of the enemy. -1 = left, 1 = right.
@export var direction: int = 1
# Sprite flip flag for visual facing, derived from direction in update logic.
@export var flip: bool = false
# Current and maximum health values.
@export var hp: int = 50
@export var hp_max: int = 50
# Base attack power used by subclasses when they define damage application.
@export var atk: int = 10
# Reward data for score and pickups.
@export var score: int = 1
@export var coin: int = 1
# Active AI state for the enemy.
@export var state: State = State.IDLE
# AI archetype, which changes behavior logic and player reaction rules.
@export var type: Type = Type.PINGPONG

@export var label : String = "Monster"
  
# Distance thresholds used by patrol and chase logic.
@export var patrol_range: float = 300.0
@export var attack_range: float = 20.0
@export var chase_range: float = 200.0
# Time-based patrol and attack pacing values.
@export var patrol_wait_time: float = 1.2
@export var attack_cooldown_time: float = 0.8
# Threshold value for low-HP retreat behavior for defensive and boss enemies.
@export var rest_hp_threshold: int = 10
# Recovery ratio required before leaving the REST state and resuming combat.
@export var rest_recovery_ratio: float = 0.6
# Regeneration rate used when the enemy enters REST state under low HP.
@export var regen_hp_per_second: float = 2.0
# Gravity multiplier to allow tuning of enemy physics behavior.
@export var gravity_scale: float = 1.0
# Knockback strength when the enemy is hit.
@export var knockback_force: float = 180.0

# Runtime state flags and behavior timers.
var alive: bool = true
var can_walk: bool = true
var can_move: bool = true
var patrol_timer: float = 0.0
var attack_timer: float = 0.0
# Reference to the player object detected by raycasts.
var player_ref: Node2D = null
# Position used by advanced AI logic when a target point must be tracked.
var target_position: Vector2 = Vector2.ZERO
# Facing direction used for sprite and decision making.
var facing_dir: int = 1
# Tween handle used for the REST visual pulse effect.
var rest_tween: Tween = null

@onready var wall_ray: RayCast2D = $Sprite/Ray/wallRay
@onready var player_ray_back: RayCast2D = $Sprite/Ray/playerRayBack
@onready var player_ray_front: RayCast2D = $Sprite/Ray/playerRayFront
@onready var floor_ray: RayCast2D = $Sprite/Ray/floorRay

# Emitted when the enemy is defeated.
signal died
# Emitted whenever the AI state changes.
signal state_changed(new_state: State)

# Initializes enemy runtime values and applies the initial state.
func _ready() -> void:
	$Label.text = label
	_setup_health_bar()
	_setup_runtime_state()
	set_state(state)
	_on_enter_state(state)

# Updates the health bar and sprite orientation each frame.

func _process(_delta: float) -> void:
	if has_node("ProgressBar"):
		$ProgressBar.value = hp
	_update_sprite_facing()
	


# Core physics update loop. This is where the enemy decides AI behaviour and
# applies gravity and movement. Subclasses may override this if needed, but the
# default structure is designed for standard platformer action-game AI.
func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y += get_gravity().y * delta * gravity_scale
	if can_move:
		_update_ai(delta)
	move_and_slide()

func _setup_runtime_state() -> void:
	alive = true
	can_walk = true
	can_move = true
	patrol_timer = 0.0
	attack_timer = 0.0
	direction = clamp(direction, -1, 1)
	facing_dir = direction
	if has_node("DeathParticles"):
		$DeathParticles.one_shot = true

func _setup_health_bar() -> void:
	if has_node("ProgressBar"):
		$ProgressBar.max_value = hp_max
		$ProgressBar.value = hp

# Transition to a new AI state.
# This centralizes state changes so all behavior begins from the same decision
# point and keeps custom enemy logic consistent.
func set_state(next_state: State) -> void:
	if not alive and next_state != State.DEAD:
		return
	if state == next_state:
		return
	state = next_state
	_on_enter_state(state)

# Called when an enemy enters a new state. Subclasses can override or extend this
# behavior for specialized state transitions if needed.
func _on_enter_state(new_state: State) -> void:
	state_changed.emit(new_state)
		
	if new_state == State.REST:
		_play_rest_effect()
	else:
		_stop_rest_effect()
	

# Main decision loop for enemy AI.
# One scan of this function determines whether the enemy should idle, patrol,
# chase, or attack based on its Type and current player detection state.
func _update_ai(delta: float) -> void:
	if not alive:
		return
	if hp <= 0:
		die()
		return
	if should_enter_rest():
		if state != State.REST:
			set_state(State.REST)
		return
	if get_target_distance() <= attack_range and type == Type.BOSS:
		set_state(State.ATTACK)
		return
	if type == Type.DUMMY and state != State.ATTACK:
		set_state(State.IDLE)
	if type == Type.PINGPONG and state != State.ATTACK:
		set_state(State.WALK)	
	if type == Type.NEAR or type == Type.FAR or state == State.IDLE:
		set_state(State.PATROL)

	if player_ray_back.is_colliding() or player_ray_front.is_colliding():
		detect_player()

	match state:
		State.IDLE:
			idle_behavior()
		State.WALK:
			walk_behavior()
		State.PATROL:
			patrol_behavior()
		State.REST:
			rest_behavior()
		State.CHASE:
			chase_behavior()
		State.ATTACK:
			attack_behavior()
		State.DAMAGED:
			damaged_behavior()
		State.DEAD:
			dead_behavior()
		_:
			idle_behavior()


# Detects the player using the enemy's raycasts and translates the result into a
# proper combat state. This method is the bridge between perception and AI logic.
func detect_player() -> void:
	var ray: RayCast2D = player_ray_back if player_ray_back.is_colliding() else player_ray_front
	var point = ray.get_collision_point()
	if point == Vector2.ZERO:
		return
	var distance = global_position.distance_to(point)
	player_ref = ray.get_collider() as Node2D
	if distance <= attack_range:
		set_state(State.ATTACK)
		return
	if type == Type.NEAR:
		if distance <= chase_range:
			set_state(State.CHASE)
		else:
			set_state(State.PATROL)
	elif type == Type.FAR:
		if distance >= chase_range:
			set_state(State.CHASE)
		else:
			set_state(State.REST)
	elif type == Type.DEFENSE:
		if distance <= attack_range:
			set_state(State.ATTACK)
		else:
			set_state(State.IDLE)
	else:
		if distance <= chase_range:
			set_state(State.CHASE)
		else:
			set_state(State.PATROL)

# Returns the horizontal distance between the enemy and the current player target.
# Used for AI decisions such as chase, retreat, and attack range checks.
func get_target_distance() -> float:
	if player_ref == null:
		return INF
	return abs(global_position.x - player_ref.global_position.x)

func should_enter_rest() -> bool:
	if type != Type.DEFENSE and type != Type.BOSS:
		return false
	return hp <= rest_hp_threshold

func should_exit_rest() -> bool:
	return float(hp) / float(max(hp_max, 1)) >= rest_recovery_ratio

# Flips the sprite to match the current facing direction.
var sy=1
func _update_sprite_facing() -> void:
	if direction < 0:
		flip = false
		facing_dir = -1
	elif direction > 0:
		flip = true
		facing_dir = 1
	if has_node("Sprite"):
		$Sprite.scale.x = -1 if flip else 1
	if state==State.IDLE:
		sy+=0.1
		if sy>314 : sy=0
		$Sprite.scale.y = 1+cos(sy)*0.05
	else:
		$Sprite.scale.y = 1	


# Applies horizontal movement toward a direction while respecting terrain checks
# and the enemy's current movement lock flags.
func _move_with_direction(move_speed: float = 0.0) -> void:
	if not can_walk:
		return	
	var desired_velocity = move_speed if move_speed != 0.0 else speed * direction
	var difference = desired_velocity - velocity.x
	if abs(difference) > 0.1:
		velocity.x += clamp(difference, -8.0, 8.0)
	else:
		velocity.x = desired_velocity

# REST animation effect for low-HP recoveries.
# The enemy pulse is a soft visual cue that communicates defensive behavior.
func _play_rest_effect() -> void:
	if not has_node("Sprite"):
		return
	if rest_tween != null and rest_tween.is_valid():
		rest_tween.kill()
	rest_tween = create_tween()
	rest_tween.set_loops()
	rest_tween.tween_property($Sprite, "modulate", Color(0.45, 1.0, 0.8, 1.0), 0.18)
	rest_tween.tween_property($Sprite, "scale", Vector2(1.08, 1.08), 0.12)
	rest_tween.tween_property($Sprite, "modulate", Color.WHITE, 0.18)
	rest_tween.tween_property($Sprite, "scale", Vector2.ONE, 0.12)

func _stop_rest_effect() -> void:
	if rest_tween != null and rest_tween.is_valid():
		rest_tween.kill()
		rest_tween = null
	if has_node("Sprite"):
		$Sprite.modulate = Color.WHITE
		$Sprite.scale = Vector2.ONE

func _face_player() -> void:
	if player_ref == null:
		return
	# Only face toward the player when the enemy is actively pursuing or attacking.
	# This must not override a turn caused by wall or edge detection, because that
	# behavior is more important for platformer movement safety.
	if state == State.CHASE or state == State.ATTACK:
		direction = -1 if global_position.x > player_ref.global_position.x else 1
		_update_sprite_facing()

func _apply_ground_turnaround() -> void:
	if is_on_wall() or wall_ray.is_colliding() or (is_on_floor() and not floor_ray.is_colliding()):
		direction *= -1
		velocity.y = -200
		_update_sprite_facing()
		# print("Enemy hit wall or edge, turning around. New direction: %d" % direction)

func idle_behavior(_delta: float = 0.0) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0)


func walk_behavior(_delta: float = 0.0) -> void:
	_apply_ground_turnaround()
	_move_with_direction(speed * direction)

func patrol_behavior(_delta: float = 0.0) -> void:
	patrol_timer -= _delta
	if patrol_timer <= 0.0:
		patrol_timer = patrol_wait_time
		direction *= -1
	_apply_ground_turnaround()
	_move_with_direction(speed * direction)

func rest_behavior(_delta: float = 0.0) -> void:
	# Low-HP retreat state.
	# Defensive and boss enemies recover by disengaging from the player. They may
	# not attack again until HP has recovered beyond the configured threshold.
	if player_ref == null:
		velocity.x = move_toward(velocity.x, 0.0, 8.0)
		if should_exit_rest():
			set_state(State.PATROL)
		return

	if should_exit_rest():
		if player_ref != null:
			if get_target_distance() <= attack_range:
				set_state(State.ATTACK)
			else:
				set_state(State.CHASE)
		else:
			set_state(State.PATROL)
		return

	hp = min(hp_max, hp + regen_hp_per_second * _delta)
	var distance = get_target_distance()
	var retreat_direction = 1 if global_position.x < player_ref.global_position.x else -1
	direction = retreat_direction

	if distance <= chase_range:
		_move_with_direction(speed * direction * 1.2)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0)

	# Attack is intentionally blocked inside REST. Combat resumes only once the
	# recovery threshold is reached.
	if should_exit_rest():
		if distance <= attack_range:
			set_state(State.ATTACK)
		else:
			set_state(State.CHASE)

func chase_behavior(_delta: float = 0.0) -> void:
	if player_ref == null:
		set_state(State.PATROL)
		return
	_face_player()
	_move_with_direction(speed * direction * 1.35)
	if get_target_distance() <= attack_range:
		set_state(State.ATTACK)

func attack_behavior(_delta: float = 0.0) -> void:
	if player_ref == null:
		set_state(State.PATROL)
		return
	if should_enter_rest():
		set_state(State.REST)
		return
	_face_player()
	velocity.x = move_toward(velocity.x, 0.0, 8.0)
	if attack_timer <= 0.0:
		perform_attack()
		attack_timer = attack_cooldown_time
	else:
		attack_timer -= _delta
	if get_target_distance() > attack_range * 1.6:
		set_state(State.CHASE)

func damaged_behavior(_delta: float = 0.0) -> void:
	can_walk = false
	velocity.x = knockback_force * -direction
	velocity.y = -200
	await get_tree().create_timer(0.2).timeout
	can_walk = true
	set_state(State.PATROL)

func dead_behavior(_delta: float = 0.0) -> void:
	velocity.x = 0.0
	if has_node("Sprite"):
		$Sprite.hide()
	if has_node("DeathParticles"):
		$DeathParticles.emitting = true
	if has_node("DeathSfx"):
		$DeathSfx.play()

## AI Extension Points
# Concrete enemy types should override these methods to define their unique
# behavior while preserving the shared base AI logic.
#
# - perform_attack(): define melee, projectile, or special attacks.
# - take_damage(): central handling for damage and knockback.
# - die(): enemy death and cleanup.

# Hook for attack logic.
# Concrete enemy types should override this method to perform melee, projectile,
# or special attacks while respecting their attack cooldown and range.
func perform_attack() -> void:
	pass

# Applies damage to the enemy and triggers the damaged state.
# This method is the canonical entry point for incoming player attacks or traps.
func take_damage(amount: int, hit_from_x: float = 0.0) -> void:
	if not alive:
		return
	hp -= amount
	if hit_from_x != 0.0:
		direction = -1 if global_position.x > hit_from_x else 1
	if hp <= 0:
		die()
		return
	set_state(State.DAMAGED)
	_damage_flash()

func _damage_flash() -> void:
	if has_node("DamageParticles"):
		$DamageParticles.emitting = true
	if has_node("DeathSfx"):
		$DeathSfx.play()
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.10)

# Handles the enemy death sequence. This method should be considered the final
# lifecycle step for enemy defeat and cleanup.
func die() -> void:
	if not alive:
		return
	alive = false
	set_state(State.DEAD)
	if has_node("ProgressBar"):
		$ProgressBar.visible = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("Sprite"):
		$Sprite.hide()
	if has_node("DeathParticles"):
		$DeathParticles.emitting = true
	if has_node("DeathSfx"):
		$DeathSfx.play()
	if GameManager != null:
		GameManager.add_score()
	died.emit()
	GameManager.enemy_died(self)
	await get_tree().create_timer(1.0).timeout
	queue_free()

# Called when a body enters the enemy's hurt area. This method is used for both
# projectile contact and trap damage handling.
func _on_hit_area_body_entered(body: Node2D) -> void:
	if not alive:
		return
	if body.is_in_group("Bullet") or body.is_in_group("Trap"):
		var hit_x = body.global_position.x
		take_damage(10, hit_x)
		body.queue_free()
