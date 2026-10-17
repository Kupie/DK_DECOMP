extends RigidBody2D

var off = 1.0

func _physics_process(delta):
	if off > 0.0:
		off -= delta
		return

	if abs(linear_velocity.y) < 10.0:
		var ex = load("res://content/gadgets/blastMining/Explosion.tscn").instantiate()
		ex.position = global_position
		get_parent().add_child(ex)
		queue_free()
