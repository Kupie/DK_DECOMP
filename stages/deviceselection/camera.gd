extends CameraBase

func _process(delta: float) -> void :
	var keeper_position: = Vector2()
	var i: = 0
	var max_dist = 0.0
	for keeper in Keepers.local.getAll():
		keeper_position += keeper.position
		i += 1
		for keeper2 in Keepers.local.getAll():
			max_dist = max(max_dist, keeper.position.distance_to(keeper2.position))

	if i > 0:
		keeper_position /= float(i)
		position = keeper_position

	zoom = Vector2.ONE * (4 - max(max_dist - 300, 0) / 250.0)
