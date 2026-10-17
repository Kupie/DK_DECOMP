class_name MuzzleFlash extends Node2D

@export var auto_start_and_delete: bool = true

@onready var _tween: DeprecatedTween = $Tween

var _base_rotation: float
var _base_scale: Vector2
func _ready():
	hide()
	_base_rotation = rotation
	_base_scale = scale
	Style.init($Sprite2D)
	if auto_start_and_delete:
		show()
		var newScale = Vector2(randf_range(1.1, 1.4), randf_range(1.1, 1.4)) * scale.x
		_tween.interpolate_property(self, "scale", Vector2.ZERO, newScale, 0.03, Tween.TRANS_EXPO, Tween.EASE_OUT)
		_tween.interpolate_property(self, "scale", newScale, Vector2.ZERO, 0.35, Tween.TRANS_QUINT, Tween.EASE_OUT, 0.03)
		_tween.interpolate_callback(self, 0.08, "queue_free")
		_tween.start()

func reset(in_global_position: Vector2) -> void :
	global_position = in_global_position
	rotation = _base_rotation
	scale = _base_scale
	show()
	var newScale = Vector2(randf_range(1.1, 1.4), randf_range(1.1, 1.4)) * scale.x
	_tween.remove_all()
	_tween.interpolate_property(self, "scale", Vector2.ZERO, newScale, 0.03, Tween.TRANS_EXPO, Tween.EASE_OUT)
	_tween.interpolate_property(self, "scale", newScale, Vector2.ZERO, 0.35, Tween.TRANS_QUINT, Tween.EASE_OUT, 0.03)
	_tween.interpolate_callback(self, 0.08, "hide")
	_tween.start()
