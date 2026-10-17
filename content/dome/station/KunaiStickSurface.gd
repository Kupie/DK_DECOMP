extends StaticBody2D

signal deactivated

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func set_active(active: bool) -> void :
	var was_active: = not collision_shape.disabled
	collision_shape.disabled = not active
	if was_active and not active:
		deactivated.emit()
