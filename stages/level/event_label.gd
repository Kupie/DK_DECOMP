extends Label

var event_tween: Tween

func start(t: String):
	if event_tween:
		event_tween.kill()
	event_tween = create_tween()
	text = t
	modulate.a = 1.0
	visible = true
	event_tween.set_parallel(true)
	event_tween.tween_method(shake, 1.0, 0.0, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	event_tween.tween_property(self, "modulate:a", 0.0, 0.2).set_delay(7.5)
	event_tween.tween_callback(set.bind("visible", false)).set_delay(8.0)

func shake(amount: float):
	pivot_offset = size * 0.5
	scale = (1.0 + amount * randf_range(-0.4, 0.4)) * Vector2.ONE
	rotation = amount * randf() * 0.05
