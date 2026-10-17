extends Node2D

func _ready() -> void :
	Style.init(self)

func as_thrown(radius: float):
	if radius > 3.0:
		$Sparks.emitting = true
	elif radius > 2.0:
		$Sparks.amount_ratio = 0.5
		$Sparks.emitting = true

func updateStyleColor():
	$Sparks.material.set_shader_parameter("palette", Style.palette)
