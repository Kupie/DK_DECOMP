class_name ExtractorStation
extends "res://content/gadgets/CellarGadget.gd"

signal state_changed

@export var synchronizer: GadgetSynchronizer

var producing: = false
var hasExtractor: = false
var growth: = 0.0
var grownAfter: = 0.0

var extractors: = {}

func _ready():
	if not SaveGame.currentLoadingSavegame:
		addExtractor()

		hasExtractor = true

	$ExtraExtractor.visible = false
	$Sprite / WormSprite1.visible = false
	$Sprite / WormSprite2.visible = false

	Level.addTutorial(self, "extractor", teamId)

	Style.init(self)
	Level.drops.synchronizer.drop_spawned.connect(on_drop_spawned, CONNECT_DEFERRED)

func on_drop_spawned(carryable: Carryable) -> void :
	if not multiplayer.is_server():
		if carryable is Extractor and carryable.teamId == teamId:
			extractors[carryable.UID] = carryable
			carryable.station = self
		return

	if not carryable is Extractor or carryable.teamId != teamId:
		return

	var extractor: = carryable as Extractor
	registerExtractor(extractor)

func registerExtractor(outExtractor: Extractor) -> void :
	extractors[outExtractor.UID] = outExtractor
	outExtractor.station = self
	if not multiplayer.is_server():
		return
	outExtractor.idleSet.connect(network_set_extractor_idle)
	outExtractor.goingToIron.connect(network_set_extractor_going_to_iron)
	outExtractor.extractionVisualsPlayed.connect(network_play_extraction_visuals)
	outExtractor.initialAttachmentStarted.connect(network_extractor_start_initial_attachment)
	outExtractor.attachmentFinished.connect(network_extractor_finish_attachment)
	outExtractor.wasKilled.connect(network_extractor_kill)

func serialize() -> Dictionary:
	var data = super.serialize()
	data["producing"] = producing
	data["hasExtractor"] = hasExtractor
	data["growth"] = growth
	data["grownAfter"] = grownAfter
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	producing = data["producing"]
	hasExtractor = data["hasExtractor"]
	growth = data["growth"]
	grownAfter = data["grownAfter"]

	if hasExtractor:
		addExtractor()
	else:
		$ExtraExtractor.visible = false

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(producing)
	stream.encode_bool(hasExtractor)
	stream.encode_float(growth)
	stream.encode_float(grownAfter)
	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	producing = stream.decode_bool()
	hasExtractor = stream.decode_bool()
	growth = stream.decode_float()
	grownAfter = stream.decode_float()

	if grownAfter > 0:
		if growth >= grownAfter * 0.5 and not $Sprite / WormSprite1.visible:
			playWormSpriteComingOutVisual(0)
		if growth >= grownAfter * 0.8 and not $Sprite / WormSprite2.visible:
			playWormSpriteComingOutVisual(1)

	if hasExtractor:
		addExtractor()
	else:
		$ExtraExtractor.visible = false
		$Sprite.play("empty")

func _process(delta):
	if not multiplayer.is_server():
		return
	if GameWorld.softPaused(teamId):
		return

	if producing and growth < grownAfter:
		growth += delta * GameWorld.cycleSpeed
		if growth >= grownAfter * 0.5 and not $Sprite / WormSprite1.visible:
			synchronizer.network_rpc(playWormSpriteComingOutVisual.bind(0), true)
		if growth >= grownAfter * 0.8 and not $Sprite / WormSprite2.visible:
			synchronizer.network_rpc(playWormSpriteComingOutVisual.bind(1), true)
		return

	if grownAfter > 0.0 and growth >= grownAfter:
		synchronizer.network_rpc(addExtractor, true)

@rpc("reliable")
func playWormSpriteComingOutVisual(wormSpriteNumber: int) -> void :
	var sprite
	match wormSpriteNumber:
		0:
			sprite = $Sprite / WormSprite1
		1:
			sprite = $Sprite / WormSprite2

	sprite.visible = true
	sprite.play("coming_out")

@rpc("reliable")
func addExtractor():
	$Sprite.play("producing")
	growth = 0.0
	producing = false

func canFocusUse(keeper: Keeper) -> bool:
	return hasExtractor

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if canFocusUse(keeper):
		synchronizer.network_rpc(registerHit.bind(keeper.playerId), true)
		return true
	return false

@rpc("reliable", "any_peer")
func registerHit(playerId: String) -> void :
	if hasExtractor:
		$ExtraExtractor.visible = false
		$Sprite.play("empty")
		$ExtractorPickup.startSound()
		$Sprite / WormSprite1.visible = false
		$Sprite / WormSprite2.visible = false

		if not multiplayer.is_server():
			return

		hasExtractor = false
		producing = true
		grownAfter = Data.of(teamId + ".extractor.buildcycles") * GameWorld.getTimeBetweenWaves(teamId)
		growth = 0

		state_changed.emit()

		for _i in Data.of(teamId + ".extractor.units"):
			Level.drops.network_spawn({
				"type": CONST.EXTRACTOR, 
				"position": $ExtractorPosition.global_position, 
				"carriers": [playerId], 
				"team": teamId
			})


func _on_sprite_animation_finished() -> void :
	if $Sprite.animation == "producing":
		$Sprite.play("ready")
		hasExtractor = true
		if Data.of(teamId + ".extractor.units") > 1:
			if not $ExtraExtractor.visible:
				$Sprite.play("producing")
				$ExtraExtractor.visible = true

				$ExtraExtractor.position = Vector2(-2, -3)
				create_tween().tween_property($ExtraExtractor, "position", Vector2(-9, -1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _on_worm_sprite_1_animation_finished() -> void :
	if $Sprite / WormSprite1.animation == "coming_out":
		$Sprite / WormSprite1.play("idle")

func _on_worm_sprite_2_animation_finished() -> void :
	if $Sprite / WormSprite2.animation == "coming_out":
		$Sprite / WormSprite2.play("idle")

func network_set_extractor_idle(carryableUID: int) -> void :
	synchronizer.network_rpc(set_extractor_idle.bind(carryableUID), true)

func network_set_extractor_going_to_iron(carryableUID: int) -> void :
	synchronizer.network_rpc(set_extractor_going_to_iron.bind(carryableUID), true)

func network_play_extraction_visuals(carryableUID: int, stopTileOverlay: bool, tileCoords: Vector2) -> void :
	synchronizer.network_rpc(play_extraction_visuals.bind(carryableUID, stopTileOverlay, tileCoords), true)

func network_extractor_start_initial_attachment(carryableUID: int, tileCoords: Vector2) -> void :
	synchronizer.network_rpc(extractor_start_initial_attachment.bind(carryableUID, tileCoords), true)

func network_extractor_finish_attachment(carryableUID: int) -> void :
	synchronizer.network_rpc(extractor_finish_attachment.bind(carryableUID), true)

func network_extractor_kill(carryableUID: int) -> void :
	synchronizer.network_rpc(extractor_kill.bind(carryableUID), true)

@rpc("reliable")
func set_extractor_idle(UID: int) -> void :
	if extractors.has(UID):
		extractors[UID].set_idle()

@rpc("reliable")
func set_extractor_going_to_iron(UID: int) -> void :
	if extractors.has(UID):
		extractors[UID].set_going_to_iron()

@rpc("reliable")
func play_extraction_visuals(UID: int, stopTileOverlay: bool, tileCoords: Vector2) -> void :
	if extractors.has(UID):
		extractors[UID].playExtractionVisuals(stopTileOverlay, tileCoords)

@rpc("reliable")
func extractor_start_initial_attachment(UID: int, tileCoords: Vector2) -> void :
	if extractors.has(UID):
		extractors[UID].startInitialAttachment(tileCoords)

@rpc("reliable")
func extractor_finish_attachment(UID: int) -> void :
	if extractors.has(UID):
		extractors[UID].finishAttachement()

@rpc("reliable")
func extractor_kill(UID: int) -> void :
	if extractors.has(UID):
		extractors[UID].remoteKill()
