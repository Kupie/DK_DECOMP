extends Node2D

func _ready() -> void :
	Style.init(self)
	var p: = $GPUParticles2D
	var t: = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(p, "scale", Vector2.ONE * 4.0, 0.5)
	t.tween_property(p, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free).set_delay(0.5)
