extends ColorRect

var goalFilling: float = 0.0

func _process(delta):
	var diff = 13 * goalFilling - size.x
	diff = clamp(diff + sign(diff) * 1.0, 0, size.x)
	size.x = 13 * goalFilling
