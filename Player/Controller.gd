extends KinematicBody2D

const UP = Vector2(0,-1)

signal grounded_update(is_grounded)
signal wall_grab_update(is_wallgrab)

##Editor Variables
export(bool) var JumpOn #Enables the Character to be able to Jump
export(bool) var DashOn #Enables the Character to be able to Dash(also called dodge in other areas of Code)
export(bool) var ClimbOn #Enables the Character to be able to press shift to hold onto the wall while wall sliding
export(bool) var WallSlideOn #Enables the Character to be able to WallSlide/WallGrab
export(bool) var AttackOn #Enables the Character to have an attack cycle/animation
export(bool) var dodgeHasCoolDown #Turns on a cool down for the dodge/dash with this enable the dodge can be used 
									#after x amount of time rather than after touching the ground again

export(int) var JUMP_HEIGHT = 5 #the number of pixels a character can jump
export(float) var timeToJumpApex = .8 #the amount of time to reach the peak of the jump Higher = slower jump
export(int) var MAX_SPEED = 200 #Max speed in pixels per second
export(int) var ACCELERATION = 50 #acceleration rate
export(int) var FRICTION = 10 #deceleration rate
export(int) var dodgeSpeed = 3  #a value to multiply max speed by when dodging/dashing
export(int) var dodgeCD = 5 #the cooldown for the dodgespeed mod
export(float) var wallJumpSpeed = 1.3 #wall jump speed multiplier
export(int) var minJump = 0 #minimum jump height ## after space is release if height > than this variable the charact will fall immediately
export(int) var wallClimbSpeed = 30 #the speed at which the player can climb a wall

var GRAVITY
var dodge
var jumpVelocity
var velocity = Vector2(0,0)
var input_vector = Vector2.ZERO
var currentPosition = Vector2.ZERO
var positionUpdate = Vector2.ZERO


#Attack Combo Variables
var attackAnimations = ["attack","attack2","attack3"]
var attackCount = 0

##BOOLS
var friction = false
var attackcomplete = true
var dodgeAnimation = false
var canjump = true
var jumpPressed = false
var canDodge = true
var grabbingWall = false
var justWallJumped = false
var wallJump = false
var is_jumping = false
var is_grounded
var is_wallgrab
var wallAbove = false

onready var animationTree = $AnimationTree
onready var sprite = $Sprite
onready var animationState = animationTree.get("parameters/playback")
onready var hitBox = $PlayerHitBox/Hitbox/HitBoxCollision
onready var hitBoxPosition = $PlayerHitBox
onready var hitBoxKockback = $PlayerHitBox/Hitbox
onready var rayCastRight = $raycastRight
onready var rayCastLeft = $raycastLeft
onready var	rayCastLedgeRight = $raycastLedgeRight
onready var rayCastLedgeLeft = $raycastLedgeLeft
onready var rayCastDown = $rayCastDown
#onready var joystick = get_parent().get_node("UI/touchLayer/VBoxContainer/HBox/Control/Joystick/joystick_button")
onready var joypads = Input.get_connected_joypads()
onready var walljumptimeout = $WallJumpDisabler
onready var attackTimer = $AttackComboTimer

#state machine enabled by enum -- credit to HeartBeast for this technique
enum {
	MOVE,
	JUMP,
	ATTACK,
	DODGE,
	WALLGRAB,
	WALLHOLD
}

var state = MOVE

func _ready():
#	stats.connect("no_health",self, "queue_free")
	GRAVITY = (2 * JUMP_HEIGHT)/ pow(timeToJumpApex,2)
	jumpVelocity = abs(GRAVITY) * timeToJumpApex

# warning-ignore:unused_argument
func _physics_process(delta):
	gravity()
	playerInput()
		
	match state:
		MOVE:
			moveState()
		JUMP:
			jumpState()
		ATTACK:
			attackState()
		DODGE:
			dodgeState()
		WALLGRAB:
			wallGrabState()
			ledgeCheck()
		WALLHOLD:
			holdOnToWall()
			
	animationPlayer()
	cameraMovement()

#move and slide handler
func move():
	velocity = move_and_slide(velocity, UP)

func animationPlayer():
	
	if state == ATTACK:
		animationState.travel(attackAnimations[attackCount])
	elif dodgeAnimation == true:
		animationState.travel("dodge")
	elif state == WALLHOLD:
		animationState.travel("wallClimb") ##occasionally blend position is set incorrecty
	elif (rayCastLeft.is_colliding() && !rayCastLedgeLeft.is_colliding()) && (state == WALLGRAB || state == WALLHOLD):
		animationState.travel("wallClimb")
		animationTree.set("parameters/wallClimb/blend_position",Vector2(1,0))	
	elif rayCastRight.is_colliding() && !rayCastLedgeRight.is_colliding():
		animationState.travel("wallClimb")
		animationTree.set("parameters/wallClimb/blend_position",Vector2(-1,0))	
	elif rayCastLeft.is_colliding() && state == WALLGRAB:
		animationState.travel("wallSlide")
		animationTree.set("parameters/wallSlide/blend_position",Vector2(-1,0))	
	elif rayCastRight.is_colliding() && state == WALLGRAB:
		animationState.travel("wallSlide")
		animationTree.set("parameters/wallSlide/blend_position",Vector2(1,0))
	elif velocity.y != 0:
		animationState.travel("jump")
	elif velocity.y == 0:
		if input_vector.x <0:
			animationState.travel("run")
			hitBoxKockback.knockback_vector = input_vector
			hitBoxPosition.rotation_degrees = 90
		elif input_vector.x > 0:
			animationState.travel("run")
			hitBoxKockback.knockback_vector = input_vector
			hitBoxPosition.rotation_degrees = -90
		else:
			animationState.travel("idle")

#player physics logic
func playerPhysics():
	
	leftRightMovement()
	
	groundRules()
	
func playerInput():
#	ENABLE THIS IF YOU NEED TOUCH SCREEN CONTROLS AND YOU HAVE A JOYSTICK canvas layer CALLED Joystick
#	input_vector = joystick.get_value() 
#	if joystick.ongoing_drag == -1:    
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")	
	input_vector.y =  Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	animationTree.set("parameters/run/blend_position", input_vector)
	animationTree.set("parameters/dodge/blend_position", input_vector)
	animationTree.set("parameters/idle/blend_position", input_vector)
	animationTree.set("parameters/jump/blend_position", velocity)
			
	if Input.is_action_just_pressed("ui_accept") && JumpOn:
		jumpPressed = true
		jumpTime()
		if canjump == true:
			state = JUMP
		if wallJump == true:
			state = JUMP
			
	if Input.is_action_just_released("ui_accept") && velocity.y < minJump:
		velocity.y = 0
	
	if (Input.is_action_just_pressed("attack") && state != WALLGRAB) && AttackOn:
		state = ATTACK
	
	if (Input.is_action_just_pressed("dodge") && canDodge == true) && DashOn:
		state = DODGE
	
	if (Input.is_action_just_pressed("holdWall") && grabbingWall == true) && ClimbOn:
		state = WALLHOLD
	
	if Input.is_action_just_released("holdWall") && grabbingWall == true:
		state = MOVE

func holdOnToWall():
	if rayCastLeft.enabled == true:
		if !rayCastLeft.is_colliding():
			state = MOVE
		elif rayCastLedgeLeft.is_colliding():
			wallClimb()
			currentPosition = get_global_position()
		else:
			positionUpdate = get_global_position()
			wallAbove = false
			## this condition will stop the player 15 pixels from the top of the wall.
			if currentPosition.y-positionUpdate.y >= 15 && Input.is_action_pressed("ui_up"):
				velocity.y = 0
			else:
				wallClimb()
			
	if rayCastRight.enabled == true:
		if !rayCastRight.is_colliding():
			state = MOVE
		elif rayCastLedgeRight.is_colliding():
			wallClimb()
			currentPosition = get_global_position()
		else:
			positionUpdate = get_global_position()
			wallAbove = false
			## this condition will stop the player 15 pixels from the top of the wall.
			if currentPosition.y-positionUpdate.y >= 15 && Input.is_action_pressed("ui_up"):
				velocity.y = 0
			else:
				wallClimb()
	move()

func wallClimb():
	velocity.y = move_toward(velocity.y, input_vector.y*wallClimbSpeed, ACCELERATION)

func moveState():
	hitBox.disabled = true	
	playerPhysics()

	move()

func leftRightMovement():
	if justWallJumped == true: #this prevents the player from scaling one sided walls
		pass
	else:	
		if input_vector != Vector2.ZERO:
			#where the magic(movement) happens
			velocity.x = move_toward(velocity.x, input_vector.x*MAX_SPEED, ACCELERATION) 
		else:
			friction = true
			
func attackState():
	attackcomplete = false
	if is_on_floor():
		velocity.x = 0 #stops player from moving when attacking
	move()

func groundRules():
	if is_on_floor():
		canDodge = true
		grabbingWall = false
		canjump = true
		
		if jumpPressed == true:
			state = JUMP
		
		if friction == true:
			velocity.x = move_toward(velocity.x, 0, FRICTION)
		
		# we don't ray cast when we don't need to
		disableRayCasts()
		
	else:
		coyote()
		if friction ==  true:
			velocity.x = move_toward(velocity.x, 0, FRICTION*.5)
		
		if !rayCastDown.is_colliding():
			if input_vector.x < 0:
				rayCastLeft.enabled = true
				rayCastLedgeLeft.enabled = true
			elif input_vector.x > 0:
				rayCastRight.enabled = true
				rayCastLedgeRight.enabled = true
			else:
				disableRayCasts()

			if (rayCastLeft.is_colliding() or rayCastRight.is_colliding()) && WallSlideOn:
				state = WALLGRAB
				
		else:
			pass

func disableRayCasts():
	rayCastRight.enabled = false
	rayCastLeft.enabled = false
	rayCastLedgeRight.enabled = false
	rayCastLedgeLeft.enabled = false
	
func jumpState():
	
	if grabbingWall == true && wallAbove == true:
		doWallJump()
	else:
		velocity.y = -jumpVelocity*30 #I'm bad at math and this 30x fixes all my problems...
		canjump = false
		wallJump = false
	
	state = MOVE
	move()

func dodgeState():
	performdodge()
	dodgeAnimation = true
	move()

func wallGrabState():
	grabbingWall = true
	wallJump = true
	
	if rayCastDown.is_colliding():
		wallJumpTime()
		state = MOVE	
	elif !rayCastLeft.is_colliding() && !rayCastRight.is_colliding():
		wallJumpTime()
	elif input_vector == Vector2.ZERO:
		wallJumpTime()
		
	leftRightMovement()
	move()

func ledgeCheck():
	
	if rayCastLedgeLeft.is_colliding() || rayCastLedgeRight.is_colliding():
		wallAbove = true
	elif !rayCastLedgeLeft.is_colliding() || !rayCastLedgeRight.is_colliding():
		wallAbove = false

func gravity():
	if state == WALLGRAB: #walljumpgravity
		if velocity.y < 0 && (rayCastLedgeLeft.is_colliding() || rayCastLedgeRight.is_colliding()):
			velocity.y = 0
		else:
			velocity.y += GRAVITY*.2
			velocity.y = clamp(velocity.y,-300,30)
	elif state == WALLHOLD:
		pass 
	else:
		velocity.y += GRAVITY

func coyote():
	yield(get_tree().create_timer(.1), "timeout")
	canjump = false
	pass

func jumpTime():
	yield(get_tree().create_timer(.1), "timeout")
	jumpPressed = false
	
func wallJumpTime():
	if walljumptimeout.is_stopped():
		walljumptimeout.start()

func dodgeCoolDown():
	yield(get_tree().create_timer(dodgeCD), "timeout")
	print("dodge available")
	canDodge = true
	
func justWallJumpedTimer():
	yield(get_tree().create_timer(.4), "timeout")
	justWallJumped = false
	
func attackComplete():
	attackcomplete = true
	state = MOVE
	
func attackCombo():
	attackCount = attackCount+1
	attackTimer.start()

func attackComboReset():
	attackCount = 0

func performdodge():
		if canDodge == true:
			dodge = dodgeSpeed*MAX_SPEED
			velocity = input_vector.normalized()*dodge
		canDodge = false
		if dodgeHasCoolDown:
			dodgeCoolDown()
	
func doWallJump():
		velocity.y = -jumpVelocity*30
		if rayCastLeft.is_colliding():
			rayCastLeft.enabled = false
			velocity.x = (MAX_SPEED*wallJumpSpeed)
		elif rayCastRight.is_colliding():
			rayCastRight.enabled = false
			velocity.x = -(MAX_SPEED*wallJumpSpeed) #compensates for lack of input
		grabbingWall = false
		wallJump = false
		justWallJumped = true #prevents direction movement after wall jump
		justWallJumpedTimer()
		
func dodgeAnim():
	state = MOVE
	dodgeAnimation = false
	sprite.rotation_degrees = 0
	
func cameraMovement():
	if state == MOVE:
		var was_grounded = is_grounded
		is_grounded = is_on_floor()
		if was_grounded == null || is_grounded != was_grounded:
			emit_signal("grounded_update", is_grounded)

	if state == WALLGRAB:
		is_wallgrab = true
		emit_signal("wall_grab_update", is_wallgrab)
	elif is_on_floor():
		is_wallgrab = false
		emit_signal("wall_grab_update", is_wallgrab)

func _on_WallJumpDisabler_timeout():
	print("walljumpoff")
	rayCastLeft.enabled = false
	rayCastRight.enabled = false
	grabbingWall = false
	wallJump = false
	state = MOVE

func _on_AttackComboTimer_timeout():
	print("attack Time out")
	attackCount = 0

func _on_Hurtbox_area_entered(area):
	pass
#	stats.health -= 1
