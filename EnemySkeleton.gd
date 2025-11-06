extends CharacterBody2D

@export var speed = 80
@export var chase_speed = 100
@export var detection_range = 200
@export var max_health = 15
@export var attack_damage = 2
@export var attack_range = 40
@export var attack_cooldown = 1.5
@export var heal_amount = 0  # Set to 0 for no heal, or any number to drop heal on death

var current_health = 15
var player = null
var can_see_player = false
var is_chasing = false
var knockback_velocity = Vector2.ZERO
var can_attack = true
var last_direction = "front"

@onready var raycast = $RayCast2D
@onready var nav_agent = $NavigationAgent2D
@onready var sprite = $AnimatedSprite2D
@onready var chase_timer = $ChaseTimer

func _ready():
	chase_timer.timeout.connect(_on_chase_timer_timeout)
	chase_timer.wait_time = 0.5
	chase_timer.start()
	
	# Disable loop for death animation
	if sprite.sprite_frames.has_animation("death"):
		sprite.sprite_frames.set_animation_loop("death", false)
	
	sprite.play("idle_front")
	add_to_group("enemy")
	
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
		idle_behavior()
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
	
	# Just check distance - ignore walls for now
	can_see_player = true
	is_chasing = true

func idle_behavior():
	# Play idle animation based on last direction
	if last_direction == "left":
		sprite.flip_h = true
		sprite.play("idle_sideways")
	elif last_direction == "right":
		sprite.flip_h = false
		sprite.play("idle_sideways")
	elif last_direction == "front":
		sprite.play("idle_front")
	elif last_direction == "back":
		sprite.play("idle_back")

func chase_player():
	# Direct movement toward player
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * chase_speed
	
	# Update direction and play appropriate animation
	if abs(direction.x) > abs(direction.y):
		# Moving horizontally
		if direction.x < 0:
			sprite.flip_h = true
			sprite.play("angry_sideways")
			last_direction = "left"
		else:
			sprite.flip_h = false
			sprite.play("angry_sideways")
			last_direction = "right"
	else:
		# Moving vertically
		if direction.y < 0:
			sprite.play("angry_back")
			last_direction = "back"
		else:
			sprite.play("angry_front")
			last_direction = "front"

func attack_player():
	if player == null or not can_attack:
		return
	
	can_attack = false
	velocity = Vector2.ZERO
	
	# Calculate knockback direction (away from skeleton)
	var attack_dir = (player.global_position - global_position).normalized()
	
	# Play attack animation based on direction to player
	var direction_to_player = attack_dir
	if abs(direction_to_player.x) > abs(direction_to_player.y):
		if direction_to_player.x < 0:
			sprite.flip_h = true
			sprite.play("angry_sideways")
			last_direction = "left"
		else:
			sprite.flip_h = false
			sprite.play("angry_sideways")
			last_direction = "right"
	else:
		if direction_to_player.y < 0:
			sprite.play("angry_back")
			last_direction = "back"
		else:
			sprite.play("angry_front")
			last_direction = "front"
	
	# Deal damage to player with knockback
	if player.has_method("take_damage"):
		player.take_damage(attack_damage, attack_dir)
	
	# Cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount: int, knockback_direction: Vector2):
	current_health -= amount
	
	# Apply knockback
	knockback_velocity = knockback_direction * 200
	
	# Show damage number
	show_damage_number(amount)
	
	# Flash red
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	
	if not is_instance_valid(self):
		return
	
	sprite.modulate = Color.WHITE
	
	if current_health <= 0:
		die()

func show_damage_number(damage: int):
	var damage_label = Label.new()
	damage_label.text = "-" + str(damage)
	damage_label.position = Vector2(-4, -25)
	damage_label.z_index = 100
	
	# Load Minecraft font
	var font = load("res://Assets/Fonts/Minecraft.ttf")
	
	# Pixel-perfect settings
	damage_label.add_theme_font_override("font", font)
	damage_label.add_theme_font_size_override("font_size", 10)
	damage_label.add_theme_color_override("font_color", Color.RED)
	damage_label.add_theme_color_override("font_outline_color", Color.BLACK)
	damage_label.add_theme_constant_override("outline_size", 1)
	
	# Disable font filtering for crisp pixels
	damage_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	add_child(damage_label)
	
	# Fast animation - less distance, quicker fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 12, 0.4)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.4)
	tween.finished.connect(damage_label.queue_free)

func die():
	# Drop heal if heal_amount is set
	if heal_amount > 0:
		drop_heal()
	
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
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	else:
		await get_tree().create_timer(0.3).timeout
	
	# VANISHING EFFECT - Fade out in 0.5 seconds
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	queue_free()

func drop_heal():
	# Find player and heal them
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("heal"):
		player_node.heal(heal_amount)

func _on_chase_timer_timeout():
	if is_chasing and player != null:
		nav_agent.target_position = player.global_position
