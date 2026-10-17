extends AnimatedSprite2D


func _ready() -> void :
	play("default")
	Style.init(self)
	if get_node_or_null("LightNode") != null:
		var t: = create_tween()
		t.tween_property($LightNode, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_OUT).set_delay(0.1)
		Level.map.lights.add_simple_light(self, $LightNode)


func _on_animation_finished() -> void :
	queue_free()
