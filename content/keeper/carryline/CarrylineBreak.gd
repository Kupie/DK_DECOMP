extends Node2D

var target: Vector2

func _ready():
	var angle = global_position.angle_to_point(target)
	rotation = angle








	Style.init(self)


func _on_AnimationPlayer_animation_finished(anim_name):
	queue_free()
