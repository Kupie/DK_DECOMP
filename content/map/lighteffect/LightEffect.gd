class_name LightEffect extends Node2D

const FLICKER_SPEED: = 1.0

@onready var _inner_light: Polygon2D = $InnerLight
@onready var _ray_light_polygon: Polygon2D = $RayLightPolygon
@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var _flicker_strength: float = 0.0
var _flicker_speed: float = 1.0
var _flicker_tween: Tween

func _ready() -> void :
	_animation_player.speed_scale = randf_range(0.95, 1.1)

func update_polygon(new_polygon: PackedVector2Array, in_inner_light_enabled: bool) -> void :
	_ray_light_polygon.polygon = new_polygon
	if in_inner_light_enabled:
		_inner_light.polygon = new_polygon
	else:
		_inner_light.hide()

func set_main_color(new_color: Color) -> void :
	_ray_light_polygon.color = new_color

func set_inner_color(new_color: Color) -> void :
	_inner_light.color = new_color

func set_flicker_strength(new_flicker_strength: float, light_radius: float, new_flicker_speed) -> void :
	var nothingToUpdate: bool = _flicker_strength == new_flicker_strength and _flicker_speed == new_flicker_speed
	if nothingToUpdate:
		return
	_flicker_speed = new_flicker_speed
	_flicker_strength = new_flicker_strength
	_start_flicker(light_radius, )

func _start_flicker(in_light_radius: float):
	var strength: float = randf_range(_flicker_strength, _flicker_strength * 2)
	var flicker_percent: float = strength / in_light_radius
	var target_scale: Vector2 = Vector2.ONE + Vector2.ONE * flicker_percent
	if is_instance_valid(_flicker_tween):
		_flicker_tween.kill()
	_flicker_tween = create_tween()
	_flicker_tween.tween_property(self, "scale", target_scale, 0.08 * _flicker_speed)
	_flicker_tween.finished.connect(_start_flicker.bind(in_light_radius))
