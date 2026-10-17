extends AnimatedSprite2D

func _ready():
	Style.init(self)

	play()
	var tw = create_tween()
	tw.tween_property(self, "self_modulate", Color(1, 1, 1, 0.0), 0.6).set_delay(0.5)
	tw.tween_callback(queue_free)
