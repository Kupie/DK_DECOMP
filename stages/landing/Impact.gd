extends Node2D

signal landed
signal revealed

const Debris = preload("res://stages/landing/Debris.tscn")
var canEnd: = false
var dome

var countdown: = 8.0

func _ready():
	Style.init($Impact)
	Style.init($SmokeParticles)

	dome.hide()
	for keeper in Keepers.getAll():
		keeper.hide()
	Level.map.hideTiles()

	global_position = dome.global_position

	$AnimationPlayer.play("landing")

func impact():
	$Impact.play("impact")
	InputSystem.teamShake(dome.teamId, 200, 4.0)
	for w in Level.worldsByTeamId.values():
		w.domeImpact()
	for _i in range(20):
		var d = Debris.instantiate()
		add_child(d)

func reveal():
	dome.show()
	for keeper in Keepers.getAll():
		keeper.show()
	Level.map.showTiles()
	revealed.emit()

func _process(delta):
	if canEnd and not GameWorld.paused:
		countdown -= delta
		var input: bool = false
		for keeper in Keepers.local.getAll():
			input = input or keeper.moveDirectionInput.length() > 0.0
		if input or countdown <= 0.0:
			canEnd = false
			for keeper in Keepers.local.getAll():
				keeper.goalCameraZoom = 4
			queue_free()

func allowEnd():
	emit_signal("landed")
	canEnd = true
