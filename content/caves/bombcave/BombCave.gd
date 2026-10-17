extends "res://content/caves/Cave.gd"

@export var synchronizer: BombCaveSynchronizer

signal hit(keeper: Keeper)

var hasBomb: = true

func _ready():
	super._ready()
	%Sprite2D.play("default")

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasBomb"] = hasBomb
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasBomb = data["hasBomb"]
	setInitialState()

func setInitialState() -> void :
	if not hasBomb:
		%Sprite2D.play("empty")
	if currentState == State.REVEALED:
		%AmbSound.startSound()

func onRevealed():
	%AmbSound.startSound()

func canFocusUse(keeper: Keeper) -> bool:
	return hasBomb

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not hasBomb:
		return false

	hit.emit(keeper)
	return true

func registerHit(playerId: String) -> void :
	%BombTakenSound.startSound()
	%Sprite2D.play("empty")
	hasBomb = false

	var teamId = Keepers.getKeeper(playerId).teamId

	if multiplayer.is_server():
		var bomb: CaveBomb = Level.drops.network_spawn({
			"type": CONST.CAVEBOMB, 
			"position": %Usable.global_position, 
			"carriers": [playerId], 
			"team": teamId, 
		})
		bomb.state_updated.connect(synchronizer.on_bomb_state_updated.bind(bomb))
