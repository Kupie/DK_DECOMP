class_name LightLineOfSight extends Node2D

@export var light_name: String = "default"
@export var light_color: Color = Color.WHITE
@export var light_inner_color: Color = Color.WHITE
@export var light_inner_enabled: bool = false
@export var light_expansion: float = 3.0: set = set_light_expansion
@export var light_size: float = 64.0: set = set_light_size
@export var light_active: bool = true: set = set_light_active
@export var light_flicker_speed: float = 1.0
@export var can_sleep: bool = true
@export var light_flicker_strength: float = 0.0

var is_on_screen: = true
var visibility_notifier: = VisibleOnScreenNotifier2D.new()

@onready var orig_color: Color = light_color
@onready var orig_inner_color: Color = light_inner_color

var rayQuery: PhysicsRayQueryParameters2D
var collision_previous_frame: bool = true
var circleShape: = CircleShape2D.new()
var previous_position: Vector2 = Vector2.ZERO


func _enter_tree():
	add_to_group("customStyle")
	add_to_group("LightLineOfSight")

func isOnScreen() -> bool:
	return visibility_notifier.is_on_screen()

func _ready() -> void :
	Style.init(self)
	light_name += "_" + str(get_instance_id())
	circleShape.radius = light_size + light_expansion

	visibility_notifier.rect = Rect2( - light_size * 1.5, - light_size * 1.5, light_size * 3.0, light_size * 3.0)
	visibility_notifier.screen_entered.connect(_on_screen_entered)
	visibility_notifier.screen_exited.connect(_on_screen_exited)
	add_child(visibility_notifier)

func set_light_expansion(new_expansion: float) -> void :
	light_expansion = new_expansion
	circleShape.radius = light_size + light_expansion

func set_light_size(new_size: float):
	light_size = new_size
	circleShape.radius = light_size + light_expansion

func updateStyleColor():
	light_color = Style.mapColor(orig_color)
	light_inner_color = Style.mapColor(orig_inner_color)

func set_light_active(value: bool):
	if light_active == value:
		return
	light_active = value
	if not light_active and Level.map:
		Level.map.lights.remove_light(light_name)

func _on_screen_entered():
	if not can_sleep:
		return
	is_on_screen = true

func _on_screen_exited():
	if not can_sleep:
		return
	is_on_screen = false
