extends CharacterBody2D

@export var speed = 100
@export var chase_speed = 150
@export var detection_range = 500
@export var max_health = 5
@export var attack_damage = 1
@export var attack_range = 50
@export var attack_cooldown = 2.0


var current_health = 5
var player = null
var can_see_player = false
var is_chasing = false
var knockback_velocity = Vector2.ZERO
var can_attack = true

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
	# Apply knockback
	if knockback_velocity.length() > 0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500 * delta)
		move_and_slide()
		return
	
	if player == null:
		return
	
	check_line_of_sight()
	
	if can_see_player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Attack if in range
		if distance_to_player < attack_range and can_attack:
			attack_player()
		else:
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
	
	can_attack = false
	velocity = Vector2.ZERO
	
	# Play attack animation if you have one
	sprite.play("idle")  # Change to "attack" if you have attack animation
	
	# Deal damage to player
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)
	
	# Cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount: int, knockback_direction: Vector2):
	current_health -= amount
	
	# Apply knockback - REDUCED from 300 to 150
	knockback_velocity = knockback_direction * 150  # Lower = less knockback
	
	# Flash red
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE
	
	if current_health <= 0:
		die()

func die():
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
	
	# Play death animation
	if $AnimatedSprite2D.sprite_frames.has_animation("death"):
		$AnimatedSprite2D.play("death")
		await $AnimatedSprite2D.animation_finished
	else:
		# No death animation? Just wait 2 seconds with fade
		var tween = create_tween()
		tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, 2.0)
		await get_tree().create_timer(2.0).timeout
	
	# Vanish
	queue_free()

func _on_chase_timer_timeout():
	if is_chasing and player != null:
		nav_agent.target_position = player.global_position
		
