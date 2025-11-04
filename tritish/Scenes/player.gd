extends CharacterBody2D

@export var speed = 100
	
@export var last_direction = ""

func get_input():
	var input_direction = Input.get_vector("left","right","up","down")
	velocity = input_direction * speed
	
	
	if Input.is_action_pressed("left"):
		$AnimatedSprite2D.flip_h = true
		$AnimatedSprite2D.play("run_sideways")
		last_direction = "left"
	elif Input.is_action_pressed("right"):
		$AnimatedSprite2D.flip_h = false
		$AnimatedSprite2D.play("run_sideways")
		last_direction = "right"
	elif Input.is_action_pressed("down"):
		$AnimatedSprite2D.play("run_front")
		last_direction = "down"
	elif Input.is_action_pressed("up"):
		$AnimatedSprite2D.play("run_back")
		last_direction = "up"
	
	
	if input_direction == Vector2(0,0) and last_direction == "left":
		$AnimatedSprite2D.flip_h = true
		$AnimatedSprite2D.play("idle_sideways")
	elif input_direction == Vector2(0,0) and last_direction == "right":
		$AnimatedSprite2D.flip_h = false
		$AnimatedSprite2D.play("idle_sideways")
	elif input_direction == Vector2(0,0) and last_direction == "down":
		$AnimatedSprite2D.play("idle_front")
	elif input_direction == Vector2(0,0) and last_direction == "up":
		$AnimatedSprite2D.play("idle_back")
		
	#if Input.is_action_pressed("attack") and last_direction == "left":
		#$AnimatedSprite2D.flip_h = true
		#$AnimatedSprite2D.play("attack_sideways")
	#elif Input.is_action_pressed("attack") and last_direction == "right":
		#$AnimatedSprite2D.flip_h = false
		#$AnimatedSprite2D.play("attack_sideways")
	#elif Input.is_action_pressed("attack") and last_direction == "down":
		#$AnimatedSprite2D.play("attack_front")
	#elif Input.is_action_pressed("attack") and last_direction == "up":
		#$AnimatedSprite2D.play("attack_back")


	

	
	
func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
