extends TextureRect

var goalDir: float = 0.0

func _process(delta):
	if goalDir - rotation > 180:
		goalDir -= 360
	elif goalDir - rotation < -180:
		goalDir += 360
	rotation = rotation + (goalDir - rotation) * delta
