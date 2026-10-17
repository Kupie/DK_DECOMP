class_name MushroomStation
extends "res://content/gadgets/CellarGadget.gd"

signal state_changed

@export var synchronizer: GadgetSynchronizer

var hasMushroom: = false
var timeUntilGrown: = 0.0
var popup
var spores: = {}

func _ready():
	hasMushroom = true
	$Sprite.play("ready")

	Style.init(self)

	Level.addTutorial(self, "mushroomfarm", teamId)
	Level.drops.synchronizer.drop_spawned.connect(on_drop_spawned)

func on_drop_spawned(carryable: Carryable) -> void :
	if carryable is Spore and carryable.teamId == teamId:
		var spore: = carryable as Spore
		spores[spore.UID] = spore

		if not multiplayer.is_server():
			return

		spore.infectSoundPlayed.connect(networkPlaySporeInfectSound)

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasMushroom"] = hasMushroom
	data["timeUntilGrown"] = timeUntilGrown
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasMushroom = data["hasMushroom"]
	timeUntilGrown = data["timeUntilGrown"]

	if not hasMushroom:
		$Sprite.play("empty")

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(hasMushroom)
	stream.encode_float(timeUntilGrown)
	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	hasMushroom = stream.decode_bool()
	timeUntilGrown = stream.decode_float()

	if not hasMushroom:
		$Sprite.play("empty")

func canFocusUse(keeper: Keeper) -> bool:
	return hasMushroom

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if canFocusUse(keeper):
		synchronizer.network_rpc(registerHit.bind(keeper.playerId), true)
		return true
	return false

@rpc("reliable", "any_peer")
func registerHit(playerId: String) -> void :
	if not hasMushroom:
		return

	$Sprite.play("empty")
	$TakeSound.startSound()
	$poof.stop()
	$poof.play()

	if not multiplayer.is_server():
		return

	hasMushroom = false
	timeUntilGrown = Data.of(teamId + ".mushroomfarm.growthtime") * GameWorld.getTimeBetweenWaves(teamId)
	state_changed.emit()

	Level.drops.network_spawn({
		"type": CONST.SPORE, 
		"position": $poof.global_position, 
		"carriers": [playerId], 
		"team": teamId, 
	})

func _physics_process(delta: float) -> void :
	if GameWorld.paused or not multiplayer.is_server():
		return

	if not hasMushroom:
		timeUntilGrown -= delta
		if timeUntilGrown <= 0.0:
			hasMushroom = true
			synchronizer.network_rpc(growMushroomVisual, true)
			state_changed.emit()

@rpc("reliable", "call_local")
func growMushroomVisual() -> void :
	$Sprite.play("grow")
	$poof.play()

func _on_sprite_animation_finished() -> void :
	match $Sprite.animation:
		"grow":
			$Sprite.play("ready")
		"ready":
			$Sprite.play("idle")
		"idle":
			$Sprite.play("idle" if randf() > 0.4 else "ready")

func networkPlaySporeInfectSound(UID: int) -> void :
	synchronizer.network_rpc(playSporeInfectSound.bind(UID), true)

@rpc("reliable")
func playSporeInfectSound(UID: int) -> void :
	if not spores.has(UID):
		return
	var spore: = spores[UID] as Spore
	var s = spore.infectSound
	spore.remove_child(s)
	spore.get_parent().add_child(s)
	spore.playInfectSound()
