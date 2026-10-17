extends Node2D

const DEFAULT_DIRECTION: = Vector2.UP

@onready var smoke: GPUParticles2D = get_node_or_null("Smoke")
@onready var debris: GPUParticles2D = get_node_or_null("Debris")
@onready var cleanup_timer: Timer = get_node_or_null("CleanupTimer")

var _direction: Vector2 = DEFAULT_DIRECTION
var _started: = false

func _ready() -> void :
	Style.init(self)
	if not _started:

		_restart_particles()
	if is_instance_valid(cleanup_timer):
		cleanup_timer.start()

func setup(normal: Vector2) -> void :
	_direction = normal.normalized() if normal.length_squared() > 0.0 else DEFAULT_DIRECTION
	rotation = _direction.angle() - DEFAULT_DIRECTION.angle()
	_restart_particles()
	_started = true

func _restart_particles() -> void :
	if is_instance_valid(debris):
		debris.restart()
	if is_instance_valid(smoke):
		smoke.restart()


func _on_cleanup_timer_timeout() -> void :
	queue_free()
