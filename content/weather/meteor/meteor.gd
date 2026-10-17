extends AnimatedSprite2D

var phase = 1
var dir = Vector2()
var speed = 0.0
var depth = 0.0
var can_explode = false
var done: = false
var _teamId: String

var rand: RandomNumberGenerator

func initialize(inRandomNumberGenerator: RandomNumberGenerator, inTeam: String) -> void :
	_teamId = inTeam
	rand = inRandomNumberGenerator
	dir = Vector2(1, 0.3).rotated(rand.randf_range(-0.1, 0.1)).normalized()
	rotation = dir.angle()
	depth = rand.randf_range(0.5, 1.0)
	speed = rand.randf_range(400, 600) * depth
	$GPUParticles2D.amount *= depth
	scale.x = depth
	scale.y = depth
	var domePosition: Vector2 = Utils.get_dome_position(inTeam)
	global_position.x = domePosition.x - 800
	global_position.y = rand.randf_range(-550, -200)
	can_explode = false


	play("default")

func _process(delta):
	if GameWorld.paused:
		return

	var x_delete_border: float = (Utils.get_dome_position(_teamId) + Vector2(480, 0)).x
	global_position += dir * speed * delta
	if can_explode and global_position.y >= get_parent().global_position.y and global_position.x < x_delete_border:
		can_explode = false
		var x = load("res://content/shared/explosions/Explosion99.tscn").instantiate()
		get_parent().add_child(x)
		x.global_position = global_position
		queue_free()

	if not $Tween.is_active() and (global_position.x > x_delete_border or global_position.y > 0):
		$Tween.interpolate_callback(self, 2.0, "queue_free")
		$Tween.start()
