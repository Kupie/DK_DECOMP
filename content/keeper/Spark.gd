extends RigidBody2D

func _ready():
	scale = Vector2.ONE * randf_range(1, 2.5)
	$Sprite2D.self_modulate = lerp(Style.getColor(Style.keeper_highlight), Color.WHITE, randf())
	$AnimationPlayer.speed_scale = randf_range(1.0, 4.0)
