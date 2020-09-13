extends Camera2D

const Y_LOOK_AHEAD_FACTOR = 0.3
const SHIFT_TRANS = Tween.TRANS_SINE
const Y_SHIFT_EASE = Tween.EASE_IN_OUT
const SHIFT_Y_DURATION = 1.0

var yFacing = 0

onready var prev_camera_pos = get_camera_position()
onready var tween = $YShiftTween
onready var moveCamera = get_parent().get_node("Camera2D")


func _ready():
	pass
	
func _process(delta):
	_check_y_facing()
	prev_camera_pos = get_camera_position()

func _on_Character_wall_grab_update(is_wallgrab):
	if is_wallgrab == true:
		make_current()
#		tween.interpolate_property(self, "position", moveCamera.position, position, SHIFT_Y_DURATION, SHIFT_TRANS, Y_SHIFT_EASE)
#		tween.start()


func _check_y_facing():
	var newYFacing = sign(get_camera_position().y -prev_camera_pos.y )
	if newYFacing != 0 && yFacing != newYFacing:
		yFacing = newYFacing
		var y_targetOffset = get_viewport_rect().size.y * Y_LOOK_AHEAD_FACTOR * yFacing
		print(y_targetOffset)
		tween.interpolate_property(self, "position:y", position.y, y_targetOffset, SHIFT_Y_DURATION, SHIFT_TRANS, Y_SHIFT_EASE)
		tween.start()
#	else:
#		tween.interpolate_property(self, "position", moveCamera.position, position, SHIFT_Y_DURATION, SHIFT_TRANS, Y_SHIFT_EASE)
#		tween.start()
