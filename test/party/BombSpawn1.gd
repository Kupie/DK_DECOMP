extends Marker2D


func _ready():
	$Tween.interpolate_callback(self, randf() * 1.0, "fire")
	$Tween.start()

func fire():
	var b = preload("res://test/party/Mine.tscn").instantiate()
	b.position = position
	get_parent().add_child(b)
	b.apply_central_impulse(Vector2( - position.x * 0.3 * (0.9 + randf() * 0.2), -150 + randf() * 15))
	$Tween.interpolate_callback(self, 6.0 + randf() * 6.0, "fire")
	$Tween.start()
