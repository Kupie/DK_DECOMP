class_name PingIndicator extends MarginContainer

@onready var _indicator_img: TextureRect = $IndicatorImg

func update_ping(new_ping: int) -> void :
	var new_texture: Texture = _get_texture_for_ping(new_ping)
	if _indicator_img.texture != new_texture:
		_indicator_img.texture = new_texture

func _get_texture_for_ping(in_ping: int) -> Texture:
	if in_ping < 110:
		return preload("res://content/pause/ping_indicator/assets/ping_green.svg")
	elif in_ping < 200:
		return preload("res://content/pause/ping_indicator/assets/ping_yellow.svg")
	elif in_ping < 300:
		return preload("res://content/pause/ping_indicator/assets/ping_orange.svg")
	else:
		return preload("res://content/pause/ping_indicator/assets/ping_red.svg")
