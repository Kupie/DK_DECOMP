extends Node2D

const ROCKET_FLY_TIME: = 5.5
var drops: = []

func _ready():
	Style.init(self)

func setCargo(cargo: String, amount: int):











	match cargo:
		CONST.IRON:
			$Sprite2D / Cargo.texture = preload("res://content/gamemode/prestige/mini_iron.png")
		CONST.WATER:
			$Sprite2D / Cargo.texture = preload("res://content/gamemode/prestige/mini_water.png")
		CONST.SAND:
			$Sprite2D / Cargo.texture = preload("res://content/gamemode/prestige/mini_cobalt.png")

func launch():
	$Sprite2D.play("rocket_fly")
	$Tween.interpolate_property(self, "position:y", position.y, -2000, ROCKET_FLY_TIME, Tween.TRANS_QUINT, Tween.EASE_IN)
	$Tween.interpolate_callback(self, ROCKET_FLY_TIME, "queue_free")
	$Tween.start()

func queue_free():
	for d in drops:
		d.queue_free()
	super.queue_free()

func pauseChanged():
	if GameWorld.paused:
		$Tween.stop_all()
		$Sprite2D.speed_scale = 0.0
	else:
		$Sprite2D.speed_scale = 1.0
		$Tween.resume_all()
