extends Camera2D

const LOOK_AHEAD_FACTOR = 0.1
const Y_LOOK_AHEAD_FACTOR = 0.2
const SHIFT_TRANS = Tween.TRANS_SINE
const SHIFT_EASE = Tween.EASE_OUT
const Y_SHIFT_EASE = Tween.EASE_OUT
const SHIFT_DURATION = 2.0
const SHIFT_Y_DURATION = 2.0

var facing = 0
var yFacing = 0
var wallgrab

onready var prev_camera_pos = get_camera_position()
onready var tween = $ShiftTween

func _process(delta):
	_check_facing()
	_check_y_facing()
	prev_camera_pos = get_camera_position()

func _check_facing():
	var new_facing = sign(get_camera_position().x - prev_camera_pos.x)
	if new_facing != 0 && facing != new_facing:
		facing = new_facing
		var target_offset = get_viewport_rect().size.x * LOOK_AHEAD_FACTOR * facing
		tween.interpolate_property(self, "position:x", position.x, target_offset, SHIFT_DURATION, SHIFT_TRANS, SHIFT_EASE)
		tween.start()

func _on_Character_grounded_update(is_grounded):
	pass
	#drag_margin_v_enabled = !is_grounded #not sure if this is actually any good


func _on_Character_wall_grab_update(is_wallgrab):
	wallgrab = is_wallgrab

func _check_y_facing():
		drag_margin_top = .2
		drag_margin_bottom = .2

		var newYFacing = sign(get_camera_position().y -prev_camera_pos.y )
		if newYFacing != 0 && yFacing != newYFacing:
			yFacing = newYFacing
			var y_targetOffset = get_viewport_rect().size.y * Y_LOOK_AHEAD_FACTOR * yFacing
			tween.interpolate_property(self, "position:y", position.y, y_targetOffset, SHIFT_Y_DURATION, SHIFT_TRANS, Y_SHIFT_EASE)
			tween.start()	
	
