extends Path2D

@export var length: = 400.0

func attenuate(val: float):
	var lastPoint = curve.get_point_position(curve.get_point_count() - 1)
	var normalizedVal = (lastPoint.x / length) * val
	return ( - curve.sample_baked(normalizedVal).y - curve.get_point_position(0).y) / - lastPoint.y
