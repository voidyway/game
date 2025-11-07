extends CharacterBody2D

@export var speed = 100
@export var chase_speed = 150
@export var detection_range = 500
@export var max_health = 5
@export var attack_damage = 1
@export var attack_range = 35
@export var attack_cooldown = 2.0


var current_health = 5
var player = null
var can_see_player = false
var is_chasing = false
var knockback_velocity = Vector2.ZERO
var can_attack = true
var is_dead = false
var is_stunned = false

@onready var raycast = $RayCast2D
@onready var nav_agent = $NavigationAgent2D
@onready var sprite = $AnimatedSprite2D

func _ready():
	$ChaseTimer.timeout.connect(_on_chase_timer_timeout)
	
	# Disable loop for death animation
	if $AnimatedSprite2D.sprite_frames.has_animation("death"):
		$AnimatedSprite2D.sprite_frames.set_animation_loop("death", false)
	
	call_deferred("actor_setup")

func actor_setup():
	await get_tree().physics_frame
	if get_tree().has_group("player"):
		player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	# Don't process if dead
	if is_dead:
		return
	
	# Apply knockback (even when stunned)
	if knockback_velocity.length() > 0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500 * delta)
		move_and_slide()
		return
	
	# Don't move if stunned
	if is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	if player == null:
		return
	
	check_line_of_sight()
	
	if can_see_player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Attack if in range
		if distance_to_player <= attack_range and can_attack:
			attack_player()
		elif distance_to_player > attack_range:
			chase_player()
	else:
		sprite.play("idle")
		velocity = velocity.move_toward(Vector2.ZERO, speed * delta * 5)
	
	move_and_slide()

func check_line_of_sight():
	if player == null:
		can_see_player = false
		return
	
	var direction_to_player = (player.global_position - global_position)
	var distance_to_player = direction_to_player.length()
	
	if distance_to_player > detection_range:
		can_see_player = false
		is_chasing = false
		return
	
	raycast.target_position = direction_to_player
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider == player or collider.is_in_group("player"):
			can_see_player = true
			is_chasing = true
		else:
			can_see_player = false
			is_chasing = false
	else:
		can_see_player = false

func chase_player():
	if nav_agent.is_navigation_finished():
		return
	
	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	velocity = direction * chase_speed
	
	sprite.play("run")
	
	if direction.x < 0:
		sprite.flip_h = true
	elif direction.x > 0:
		sprite.flip_h = false

func attack_player():
	if player == null or not can_attack:
		return
	
	# Double-check distance before attacking
	var distance = global_position.distance_to(player.global_position)
	if distance > attack_range:
		return
	
	can_attack = false
	is_stunned = true
	
	# Push enemy back slightly to prevent sticking
	var push_direction = (global_position - player.global_position).normalized()
	knockback_velocity = push_direction * 100
	
	# Play attack animation if you have one
	sprite.play("idle")  # Change to "attack" if you have attack animation
	
	# Deal damage to player
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)
	
	# Small delay for pushback to apply
	await get_tree().create_timer(0.1).timeout
	knockback_velocity = Vector2.ZERO
	
	# Stun for remaining 0.4 seconds (total 0.5)
	await get_tree().create_timer(0.4).timeout
	is_stunned = false
	
	# Cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount: int, knockback_direction: Vector2):
	if is_dead:
		return
	
	current_health -= amount
	
	# Apply knockback
	knockback_velocity = knockback_direction * 150
	
	# Flash red
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE
	
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	
	# Stop all behavior
	set_physics_process(false)
	can_see_player = false
	is_chasing = false
	can_attack = false
	velocity = Vector2.ZERO
	
	# Disable collisions
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	if has_node("Hurtbox/CollisionShape2D"):
		$Hurtbox/CollisionShape2D.disabled = true
	
	# Play death animation if it exists
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		# Wait for animation to finish
		await sprite.animation_finished
	
	# Fade out effect (0.5 seconds from full opacity to invisible)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	# Vanish
	queue_free()

func _on_chase_timer_timeout():
	if is_chasing and player != null:
		nav_agent.target_position = player.global_position
