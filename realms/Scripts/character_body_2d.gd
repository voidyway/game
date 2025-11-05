extends CharacterBody2D

const SPEED = 300.0

func _physics_process(delta: float) -> void:
	# Get the input direction for top-down movement
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction != Vector2.ZERO:
		$AnimatedSprite2D.play("run")
		# Flip sprite based on horizontal movement
		if direction.x != 0:
			$AnimatedSprite2D.flip_h = direction.x < 0
		velocity = direction * SPEED
	else:
		$AnimatedSprite2D.play("idle")
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
	
	move_and_slide()
