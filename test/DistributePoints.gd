extends Node2D


func _process(delta):
	if Input.is_action_pressed("cheats"):
		add_point()

	var size: = Vector2(600, 400)
	for point in $ColorRect.get_children():
		var push: Vector2 = Vector2()
		for p2 in $ColorRect.get_children():
			if p2 == point:
				continue
			var d = point.position - p2.position
			if d.length() > 50:
				continue
			push += p2.get_meta("weight") * size * d / pow(d.length(), 2)
			if d.length() < 5:
				push += Vector2.ONE.rotated(randf() * TAU) * 500

		var wallpush: = Vector2()
		var d = Vector2(point.position.x, 0)
		wallpush += size * d / pow(d.length(), 2)
		d = Vector2(point.position.x - size.x, 0)
		wallpush += size * d / pow(d.length(), 2)
		d = Vector2(0, point.position.y - size.y)
		wallpush += size * d / pow(d.length(), 2)
		d = Vector2(0, point.position.y)
		wallpush += size * d / pow(d.length(), 2)
		push += wallpush * $ColorRect.get_child_count() * 0.25
		point.position += push * 2.1 * delta

func add_point():
	var v = ColorRect.new()
	v.size = Vector2.ONE * 3
	v.position = Vector2(randf_range(0, 600), randf_range(0, 400))
	$ColorRect.add_child(v)
	v.set_meta("weight", randf_range(0.6, 1.4))
