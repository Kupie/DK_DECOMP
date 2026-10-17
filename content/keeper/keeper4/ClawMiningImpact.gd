extends Node2D

var power: = 1.0

func _ready() -> void :
	%LightNode.rotation = - rotation
	$Sparks.restart()
	var t: = create_tween()
	t.tween_callback($LightNode.hide).set_delay(0.05)
	t.tween_callback(queue_free)
