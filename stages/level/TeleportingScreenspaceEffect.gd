class_name TeleportingScreenspaceEffect extends ColorRect

@export var styleColor: = Color("#2035a0")

func _ready():
	Style.init(self)
	material = material.duplicate()

func updateStyleColor():
	material.set_shader_parameter("color", Style.mapColor(styleColor))
