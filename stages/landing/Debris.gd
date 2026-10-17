extends RigidBody2D

func _ready():
	Style.init($Sprite2D)
	$Sprite2D.frame = randi() % $Sprite2D.hframes
	apply_central_impulse(randf_range(100, 500) * (Vector2.UP.rotated(randf_range(-1.8, 1.8))))

func _on_deathTimer_timeout():
	queue_free()

func _physics_process(delta):
	$Sprite2D.modulate.a = ease($deathTimer.time_left / $deathTimer.wait_time, 0.5)
