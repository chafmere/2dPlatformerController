extends KinematicBody2D

const UP = Vector2(0,-1)
const GRAVITY = 5
const MAX_SPEED = 150
const ACCELERATION = 50
const JUMP_HEIGHT = -200

var velocity = Vector2(0,0)

#func _ready():
#	pass

# warning-ignore:unused_argument
func _physics_process(delta):
	
	velocity.y += GRAVITY
	var friction = false
	
	if Input.is_action_pressed("right"):
		velocity.x = min(velocity.x + ACCELERATION, MAX_SPEED)
		$Sprite.play("Run")
		$Sprite.flip_h = false
	elif Input.is_action_pressed("left"):
		velocity.x = min(velocity.x + ACCELERATION, -MAX_SPEED)
		$Sprite.flip_h = true
		$Sprite.play("Run")
	else:
		friction = true
		$Sprite.play("Idle")
		
	if is_on_floor():
		#print("floor gang")
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_HEIGHT
		if friction == true:
			velocity.x = lerp(velocity.x,0,0.2)
	else:
		if velocity.y < 0:
			$Sprite.play("Jump")
		else:
			$Sprite.play("Fall")
		if friction == true:
			velocity.x = lerp(velocity.x,0,0.05)
	
	velocity = move_and_slide(velocity, UP)
	

#World_Complete_body_entered(body):
#	print(body)
#	if body.name == "Character":
#		get_tree().change_scene("res://Scenes/darkforest.tscn")
