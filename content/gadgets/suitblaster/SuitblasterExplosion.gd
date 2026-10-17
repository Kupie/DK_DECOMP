extends Node2D

var teamId: String

var dir: Vector2

func setup(keeper: Keeper):
	global_position = keeper.global_position
	dir = keeper.moveDirectionInput

func _ready():
	$ChargupParticles.amount = Data.of(teamId + ".suitblaster.radius") * 40.0
	$ChargeupSound.startSound()
	$ChargupParticles.restart()
	var tw = create_tween()
	tw.tween_callback(explode).set_delay(0.6)

func explode():
	var ex = load("res://content/gadgets/blastMining/Explosion.tscn").instantiate()
	ex.position = position
	get_parent().add_child(ex)

	if Level.map and multiplayer.is_server():
		if Data.of(teamId + ".suitblaster.directionalexplosions") and dir.length() > 0:
			var dir = Data.snapVectorToDirections(dir, CONST.PI_HALF)
			Level.map.damageTileDirection(global_position, dir, round(0.5 + pow(Data.of(teamId + ".suitblaster.radius"), 2) * 1.25), Data.of(teamId + ".suitblaster.damage"), teamId)
		else:
			Level.map.damageTileCircleArea(global_position, Data.of(teamId + ".suitblaster.radius"), Data.of(teamId + ".suitblaster.damage"), teamId)
