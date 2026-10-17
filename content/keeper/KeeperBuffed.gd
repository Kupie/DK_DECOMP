extends Node2D

@onready var light_node: Sprite2D = $LightNode

func _ready() -> void :
	if not GameWorld.is_current_stage_level_stage():
		return

	Style.init(self)
	light_node.modulate = Color.WHITE * 2.0
	Level.map.lights.add_simple_light(self, light_node)


func _on_visibility_changed() -> void :
	if light_node != null:
		light_node.visible = visible
