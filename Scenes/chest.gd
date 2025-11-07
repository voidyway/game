extends StaticBody2D

var animated_sprite
var is_open = false
var player_nearby = false

func _ready():
	animated_sprite = $AnimatedSprite2D
	
	# Make sure animations don't loop
	if animated_sprite.sprite_frames.has_animation("open_chest"):
		animated_sprite.sprite_frames.set_animation_loop("open_chest", false)
	
	# Play idle/closed animation at start
	animated_sprite.play("idle")

func _process(_delta):
	if player_nearby and Input.is_action_just_pressed("ui_accept"):
		toggle_chest()

func toggle_chest():
	if is_open:
		close_chest()
	else:
		open_chest()

func open_chest():
	is_open = true
	animated_sprite.play("open_chest")

func close_chest():
	is_open = false
	animated_sprite.play("idle")

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true

func _on_area_2d_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
