extends "res://content/caves/Cave.gd"

signal hit(keeper: Keeper)

var hasMushroom: = true
var timeUntilNewMushroom: = 0.0
var lastKeeper: String
var speedBuffAmount: = 45.0

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasMushroom"] = hasMushroom
	data["timeUntilNewMushroom"] = timeUntilNewMushroom
	data["lastKeeper"] = lastKeeper
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasMushroom = data["hasMushroom"]
	timeUntilNewMushroom = data["timeUntilNewMushroom"]
	lastKeeper = data["lastKeeper"]
	if not hasMushroom:
		%Mushroom.visible = false
	if currentState == State.REVEALED:
		%AmbSound.startSound()

func _process(delta):
	if GameWorld.paused:
		return

	if timeUntilNewMushroom > 0.0:
		timeUntilNewMushroom -= delta
		if timeUntilNewMushroom <= 0.0:
			hasMushroom = true
			%Mushroom.visible = true

func onRevealed():
	%AmbSound.startSound()

func canFocusUse(keeper: Keeper) -> bool:
	return hasMushroom

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not hasMushroom:
		return false

	hit.emit(keeper)
	return true

func registerHit(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	if not hasMushroom:
		return

	$MushroomConsumedSound.startSound()
	%Mushroom.visible = false
	hasMushroom = false
	lastKeeper = keeper.playerId
	var cycleTime = GameWorld.getTimeBetweenWaves(keeper.teamId)
	keeper.addTemporaryBuff("keeper.speedbuff", speedBuffAmount, cycleTime * 0.6, "mushroomcave")
	timeUntilNewMushroom = cycleTime * 2.0
