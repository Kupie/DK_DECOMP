extends "res://content/caves/Cave.gd"

signal hit(keeper: Keeper)

var hasHelmet: = true

func _ready():
	super._ready()
	%Sprite2D.play("default")

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasHelmet"] = hasHelmet
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasHelmet = data["hasHelmet"]
	if not hasHelmet:
		%Sprite2D.play("empty")
	if currentState == State.REVEALED:
		%AmbSound.startSound()

func onRevealed():
	%AmbSound.startSound()

func canFocusUse(keeper: Keeper) -> bool:
	return hasHelmet

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not hasHelmet:
		return false

	hit.emit(keeper)
	return true

func registerHit(playerId: String) -> void :
	if not hasHelmet:
		return

	var keeper: = Keepers.getKeeper(playerId)

	$HelmetTakenSound.startSound()
	%Sprite2D.play("empty")
	hasHelmet = false



	if multiplayer.is_server():
		Data.apply(keeper.playerId + ".keeper.zoominmine", 3.05)
