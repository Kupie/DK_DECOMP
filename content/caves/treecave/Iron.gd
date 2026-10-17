extends Sprite2D

signal hit(keeper: Keeper)
signal regrown

var taken: = false
var regrowCooldown: = 0.0

func _ready():
	Style.init($Sprite2D)

func canFocusUse(keeper: Keeper) -> bool:
	return not taken

func _process(delta: float) -> void :
	if GameWorld.paused:
		return

	if not multiplayer.is_server():
		return

	if taken:
		regrowCooldown -= delta
		if regrowCooldown <= 0.0:
			regrown.emit()

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if taken:
		return false

	hit.emit(keeper)
	return true

func registerHit(playerId: String):
	if taken:
		return

	taken = true
	visible = false
	var teamId = Keepers.getKeeper(playerId).teamId

	if multiplayer.is_server():
		Level.drops.network_spawn({
			"type": CONST.IRON, 
			"position": $Sprite2D.global_position, 
			"carriers": [playerId], 
			"team": teamId, 
		})

		regrowCooldown = GameWorld.getTimeBetweenWaves(teamId) * Data.stabilizedRandomFloat(0.2, 2.1, "ironcave", 2)

func regrow():
	visible = true
	taken = false
