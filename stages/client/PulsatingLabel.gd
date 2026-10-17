@tool
extends Label

@export var color_gradient: Gradient

var color_value: float = 0.0
var increasing: bool = true

func _process(delta: float) -> void :
	color_value = clampf(color_value + delta * (1.0 if increasing else -1.0), 0.0, 1.0)
	if is_equal_approx(color_value, 0.0):
		increasing = true
	elif is_equal_approx(color_value, 1.0):
		increasing = false
	label_settings.font_color = color_gradient.sample(color_value)
