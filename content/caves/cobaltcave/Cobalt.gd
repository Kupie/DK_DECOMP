extends Sprite2D

signal hit(keeper: Keeper)

var taken: = false

func _ready():
	Style.init(self)

func canFocusUse(keeper: Keeper) -> bool:
	return not taken

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if taken:
		return false

	hit.emit(keeper)
	return true

func registerHit(playerId: String) -> void :
	if taken:
		return

	taken = true

	var teamId = Keepers.getKeeper(playerId).teamId

	if multiplayer.is_server():
		Level.drops.network_spawn({
			"type": CONST.SAND, 
			"position": $FocusSprite.global_position, 
			"carriers": [playerId], 
			"team": teamId, 
		})

	visible = false
