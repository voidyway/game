extends CharacterBody2D
@export var speed = 100
@export var attack_damage = 1
@export var max_health = 10

var current_health = 10
var is_attacking = false

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox
@onready var hitbox_collision = $AttackHitbox/CollisionShape2D

func _ready():
	sprite.connect("animation_finished", _on_animation_finished)
	# Disable looping for attack animation
	sprite.sprite_frames.set_animation_loop("attack", false)
	
	# Start with idle
	sprite.play("idle")
	
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
	
	# Movement animations
	if input_direction != Vector2.ZERO:
		sprite.play("run")
		
		# Flip sprite based on horizontal movement
		if input_direction.x < 0:
			sprite.flip_h = true
		elif input_direction.x > 0:
			sprite.flip_h = false
	else:
		sprite.play("idle")

func perform_attack():
	is_attacking = true
	velocity = Vector2.ZERO
	
	# Enable hitbox briefly
	hitbox_collision.disabled = false
	
	# Play attack animation
	sprite.play("attack")
	
	# Disable hitbox after short delay
	await get_tree().create_timer(0.2).timeout
	hitbox_collision.disabled = true

func _on_attack_hit(body):
	if body.is_in_group("player"):  # Change group based on what you want to attack
		if body.has_method("take_damage"):
			var knockback_dir = (body.global_position - global_position).normalized()
			body.take_damage(attack_damage, knockback_dir)

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO):
	current_health -= amount
	
	# Apply knockback if direction provided
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 200
	
	# Flash red
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	
	# Safety check
	if not is_instance_valid(self):
		return
		
	sprite.modulate = Color.WHITE
	
	if current_health <= 0:
		die()

func die():
	queue_free()

func _on_animation_finished():
	is_attacking = false

func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
