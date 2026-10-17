class_name Rocket
extends Area2D

signal request_new_target
signal target_hit
signal rocket_destroyed(rocket)

var teamId: String

var target
var flyTime: = 0.0
var speed: = 400
var done: = false
const MAX_LIFETIME: = 20.0

var UID: int

@onready var trail_start = $trail_start
@onready var last_point: Vector2
@onready var bulletSmoke: Node2D = null

func trail_pos():
	return trail_start.global_position

func _exit_tree():
	Data.unlisten(self, teamId + ".monsters.wavepresent")

func _ready() -> void :
	Data.listen(self, teamId + ".monsters.wavepresent")
	Style.init(self)
	var stage: = int(Data.of(teamId + ".rocketlauncher.rocketstage"))
	match stage:
		1:
			$CollisionShape2D.shape.radius = 1
			$CollisionShape2D.shape.height = 10
			$Sprite2D.offset.y = 1
			$AreaDetector / CollisionShape2D.shape.radius = 8
		2:
			$CollisionShape2D.shape.radius = 2
			$CollisionShape2D.shape.height = 12
			$Sprite2D.offset.y = -1
			$AreaDetector / CollisionShape2D.shape.radius = 10
		3:
			$CollisionShape2D.shape.radius = 3
			$CollisionShape2D.shape.height = 16
			$Sprite2D.offset.y = -2
			$AreaDetector / CollisionShape2D.shape.radius = 12

	$Sprite2D.frame = stage - 1

	monitoring = false
	monitorable = false
	setup_trail()

func propertyChanged(property: String, oldValue, newValue):

	if not newValue:
		flyTime = MAX_LIFETIME - 3.0

func setup_trail():
	last_point = trail_pos()
	var smokeSize = 4
	smokeSize += ($Sprite2D.frame * 3)

	bulletSmoke = preload("res://content/weapons/artillery/BulletSmoke.tscn").instantiate()
	Level.map.addPixelEffect(bulletSmoke)
	bulletSmoke.material = preload("res://content/weapons/artillery/MortarSmokeMat.tres")
	bulletSmoke.position = Vector2.ZERO
	bulletSmoke.width = smokeSize
	bulletSmoke.points[0] = trail_pos()
	bulletSmoke.points[1] = trail_pos()
	bulletSmoke.modulate.r = randf()
	bulletSmoke.modulate.g = randf()
	connect("tree_exiting", bulletSmoke.queue_free, CONNECT_ONE_SHOT)
	Style.init(bulletSmoke)
	$Tween.interpolate_property(bulletSmoke, "modulate:b", 1, 0, 0.05, Tween.TRANS_SINE, Tween.EASE_IN)
	$Tween.interpolate_property(bulletSmoke, "modulate:b", 0, 1, 2.5, Tween.TRANS_SINE, Tween.EASE_IN, 1.5)
	$Tween.start()

func update_trail():
	if last_point.distance_to(trail_pos()) > 5.0:
		last_point = trail_pos()
		bulletSmoke.add_point(trail_pos())
	else:
		bulletSmoke.points[-1] = trail_pos()
	if bulletSmoke.get_point_count() > 100:
		bulletSmoke.remove_point(0)

func start(target):
	target.connect("died", targetDied)

func targetDied():
	target = null
	request_new_target.emit()

func _physics_process(delta: float) -> void :
	if GameWorld.paused:
		return

	flyTime += delta
	var targetFactor: = 1.0
	var dir: = Vector2.UP.rotated(rotation)
	if not is_instance_valid(target):
		target = null
		request_new_target.emit()

	if target:
		if flyTime < 1.0:
			targetFactor = pow(flyTime / 1.0, 1.6)
		var targetDir = target.position - position
		var angle = position.angle_to_point(target.position)
		var dirAngle = dir.angle()
		var goal = angle - dirAngle
		if goal > PI:
			goal -= 2 * PI
		if goal < - PI:
			goal += 2 * PI
		rotate(targetFactor * 10 * delta * goal)

	if flyTime > 0.24:
		monitoring = true
	position += dir * (speed + max(0, 0.2 - targetFactor) * 3000) * (0.5 * targetFactor + 0.5) * delta

	if flyTime > MAX_LIFETIME:
		rocket_destroyed.emit(self)

	update_trail()

func _on_area_entered(area: Area2D) -> void :
	if done:
		return

	hit(area)
	done = true

func hit(area):
	if not area or not is_instance_valid(area):
		done = false
		return

	target_hit.emit(area)

	var dmg = Data.of(teamId + ".rocketlauncher.damageperrocket")
	for monster in $AreaDetector.get_overlapping_areas():
		if monster.has_method("canBeHit") and monster.canBeHit():
			monster.hit("rocketlauncher", dmg, 10)

	var ex = preload("res://content/gadgets/rocketlauncher/rocket_impact_effects.tscn").instantiate()
	ex.global_position = global_position
	ex.global_rotation = global_rotation
	ex.setup(Data.of(teamId + ".rocketlauncher.rocketstage") >= 2)
	Level.map.add_child(ex)

	var s = $ExplosionSound
	remove_child(s)
	get_parent().add_child(s)
	s.startSound()
	rocket_destroyed.emit(self)
