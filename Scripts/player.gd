extends CharacterBody2D
@export var speed = 100
@export var last_direction = "down"
@export var max_health = 10
@export var attack_damage = 1
@export var knockback_force = 150

var current_health = 10
var is_attacking = false

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox
@onready var hitbox_collision = $AttackHitbox/CollisionShape2D

func _ready():
	sprite.connect("animation_finished", _on_animation_finished)
	# Disable looping for attack animations
	sprite.sprite_frames.set_animation_loop("attack_sideways", false)
	sprite.sprite_frames.set_animation_loop("attack_front", false)
	sprite.sprite_frames.set_animation_loop("attack_back", false)
	
	# Start facing front
	last_direction = "down"
	sprite.play("idle_front")
	
	# Connect attack hitbox
	attack_hitbox.body_entered.connect(_on_attack_hit)

func get_input():
	# Don't process input during attack
	if is_attacking:
		velocity = Vector2.ZERO
		return
	
	var input_direction = Input.get_vector("left","right","up","down")
	velocity = input_direction * speed
	
	# Check attack first
	if Input.is_action_just_pressed("attack"):
		perform_attack()
		return
	
	if Input.is_action_pressed("left"):
		sprite.flip_h = true
		sprite.play("run_sideways")
		last_direction = "left"
	elif Input.is_action_pressed("right"):
		sprite.flip_h = false
		sprite.play("run_sideways")
		last_direction = "right"
	elif Input.is_action_pressed("down"):
		sprite.play("run_front")
		last_direction = "down"
	elif Input.is_action_pressed("up"):
		sprite.play("run_back")
		last_direction = "up"
	
	if input_direction == Vector2(0,0):
		if last_direction == "left":
			sprite.flip_h = true
			sprite.play("idle_sideways")
		elif last_direction == "right":
			sprite.flip_h = false
			sprite.play("idle_sideways")
		elif last_direction == "down":
			sprite.play("idle_front")
		elif last_direction == "up":
			sprite.play("idle_back")

func perform_attack():
	is_attacking = true
	velocity = Vector2.ZERO
	
	# Position hitbox based on direction
	position_attack_hitbox()
	
	# Enable hitbox briefly
	hitbox_collision.disabled = false
	
	# Play attack animation
	if last_direction == "left":
		sprite.flip_h = true
		sprite.play("attack_sideways")
	elif last_direction == "right":
		sprite.flip_h = false
		sprite.play("attack_sideways")
	elif last_direction == "down":
		sprite.play("attack_front")
	else:
		sprite.play("attack_back")
	
	# Disable hitbox after short delay
	await get_tree().create_timer(0.2).timeout
	hitbox_collision.disabled = true

func position_attack_hitbox():
	# Position hitbox in front of player based on direction
	if last_direction == "left":
		attack_hitbox.position = Vector2(-30, 0)
	elif last_direction == "right":
		attack_hitbox.position = Vector2(30, 0)
	elif last_direction == "down":
		attack_hitbox.position = Vector2(0, 30)
	elif last_direction == "up":
		attack_hitbox.position = Vector2(0, -30)

func _on_attack_hit(body):
	if body.is_in_group("enemy"):
		# Deal damage
		if body.has_method("take_damage"):
			var knockback_dir = (body.global_position - global_position).normalized()
			body.take_damage(attack_damage, knockback_dir)

func take_damage(amount: int):
	current_health -= amount
	
	# Show damage number
	show_damage_number(amount)
	
	# Flash red
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE
	
	if current_health <= 0:
		die()

func show_damage_number(damage: int):
	var damage_label = Label.new()
	damage_label.text = "-" + str(damage)
	damage_label.position = Vector2(-4, -20)  # Just above player
	damage_label.z_index = 100
	
	# Load Minecraft font
	var font = load("res://Assets/Fonts/Minecraft.ttf")
	
	# Pixel-perfect settings
	damage_label.add_theme_font_override("font", font)
	damage_label.add_theme_font_size_override("font_size", 8)
	damage_label.add_theme_color_override("font_color", Color.RED)
	damage_label.add_theme_color_override("font_outline_color", Color.BLACK)
	damage_label.add_theme_constant_override("outline_size", 1)
	
	# Disable font filtering for crisp pixels
	damage_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	add_child(damage_label)
	
	# Wait 0.2 seconds before starting animation
	await get_tree().create_timer(0.1).timeout
	
	# Quick animation - small distance, fast fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 8, 0.3)  # Small rise
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.3)  # Quick fade
	tween.finished.connect(damage_label.queue_free)

func die():
	print("Player died!")
	# Add death logic here

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	print("Player healed! Health: ", current_health)

func _on_animation_finished():
	is_attacking = false

func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
