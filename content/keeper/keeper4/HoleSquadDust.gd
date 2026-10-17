extends CPUParticles2D

var dust_color: Color

func _ready():
	modulate = dust_color
	rotation = Vector2.UP.angle()
	restart()

func _on_finished() -> void :
	queue_free()
