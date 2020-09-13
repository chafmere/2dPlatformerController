extends ColorRect

signal fade_finished

func fadeIn():
	$AnimationPlayer.play("Fade_in")

func _on_AnimationPlayer_animation_finished(anim_name):
	emit_signal("fade_finished")
