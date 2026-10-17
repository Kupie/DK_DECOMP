extends Sprite2D

func _process(delta):
	if visible:
		rotation = randf_range(-0.15, 0.15)

	else:
		rotation = 0
