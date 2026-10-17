class_name Extractor
extends Carryable

signal idleSet(UID: int)
signal goingToIron(UID: int)
signal extractionVisualsPlayed(UID: int, stopTileOverlay: bool, tileCoords: Vector2)
signal initialAttachmentStarted(UID: int, tileCoords: Vector2)
signal attachmentFinished(UID: int)
signal wasKilled(UID: int)

var type: = CONST.EXTRACTOR
var timeUntilNextTick: float = 2.0
var softEmitNext: bool
var idling: = false
var sticks: = false
var attaching: = false
var killed: = false
var tileToMine
var stickingTo: Vector2
var animationSuffix: String
var attachedTile
var additionalIronByTileCoord: = {}
var station: ExtractorStation
var finishingAttachment: = false

func _ready() -> void :
	super._ready()
	Style.init(self)
	self.add_to_group("pauseL")

func _notification(what: int) -> void :
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		contact_monitor = false
		$CageSprite.play("floating")
		$ExtractorSprite.visible = false
		idling = true

func serialize() -> Dictionary:
	var data = super.serialize()
	data["timeUntilNextTick"] = timeUntilNextTick
	data["idling"] = idling
	data["attaching"] = attaching
	data["sticks"] = sticks
	data["stickingTo"] = var_to_str(stickingTo)
	data["additionalIronByTileCoord"] = var_to_str(additionalIronByTileCoord)
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	timeUntilNextTick = data["timeUntilNextTick"]
	idling = data["idling"]
	attaching = data["attaching"]
	sticks = data["sticks"]
	additionalIronByTileCoord = str_to_var(data["additionalIronByTileCoord"])
	stickingTo = BackwardCompatibilityUtils.str_to_var(data["stickingTo"])

	if sticks:
		startAttachment()
		attachedTile = Level.map.getTile(Level.map.getTileCoord(stickingTo))
		attachedTile.connect("destroyed", attachedTileDestroyed)

	if sticks and stickingTo:
		changeToStatic.call_deferred()

	_registerInRelatedStation()

func _registerInRelatedStation() -> void :
	var relatedDome: Dome = Level.getDome(teamId)
	var cellarGadgets: Array[CellarGadget] = relatedDome.getCellarGadgets()
	for gadget: CellarGadget in cellarGadgets:
		if gadget is ExtractorStation:
			var extractorStation: ExtractorStation = gadget as ExtractorStation
			extractorStation.registerExtractor(self)

func get_initial_data() -> PackedByteArray:
	assert (Network.is_server())
	var byteStream: = PackedByteStream.new()
	Utils.encode_animated_sprite2d_state(byteStream, $CageSprite)
	Utils.encode_animated_sprite2d_state(byteStream, $ExtractorSprite)
	return byteStream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	assert (Network.is_client())
	var byteStream: = PackedByteStream.from_bytes(buffer)
	Utils.decode_animated_sprite2d_state(byteStream, $CageSprite)
	Utils.decode_animated_sprite2d_state(byteStream, $ExtractorSprite)
	_registerInRelatedStation()

func canFocusCarry(carrierTeamId: = "") -> bool:
	return attaching or not attachedTile

func startAttachment():
	$CageSprite.visible = false

	$ExtractorSprite.visible = true

	$IronDetector.monitoring = false

	$ExtractorSprite.play("attach1")
	attaching = true
	lock_rotation = true

func stopAttachment():
	$CageSprite.visible = true

	$ExtractorSprite.visible = false
	$IronDetector.monitoring = true

	lock_rotation = false
	attaching = false
	finishingAttachment = false
	sticks = false
	if attachedTile:
		attachedTile.disconnect("destroyed", attachedTileDestroyed)
		attachedTile = null

func onDropped(keeper_or_kunaicarrier):
	contact_monitor = true
	$CageSprite.play("floating")
	$DetectingIronSound.startSound()
	idling = true

func onCarried(p):
	contact_monitor = false
	stopAttachment()
	$DetectingIronSound.stop()


func getOrCreateCarryInfluence(carrier):
	onCarried(carrier)
	return super.getOrCreateCarryInfluence(carrier)

func _physics_process(delta):
	if not multiplayer.is_server():
		super._physics_process(delta)
		var shouldBeCarryable: bool = not is_instance_valid(attachedTile)
		var isCarryable: bool = $CollisionShape2D.disabled == false
		if not isCarryable and shouldBeCarryable:
			$CollisionShape2D.disabled = false
		return

	if GameWorld.paused or killed:
		return

	var shouldBeRigid: bool = not is_instance_valid(attachedTile)
	var isRigid: bool = not freeze
	if shouldBeRigid and ( not isRigid):
		freeze = false

	if isCarried():
		return

	if attaching:
		var dir: = getStickToDirection()
		dir = dir.normalized()
		var goalRot: = dir.angle() - CONST.PI_HALF
		var goalPos = attachedTile.global_position - dir * GameWorld.TILE_SIZE * 0.65

		if finishingAttachment:
			rotation = goalRot
			position = goalPos
			return

		rotation = lerp_angle(rotation, dir.angle() - CONST.PI_HALF, delta * 2)
		var dist: Vector2 = goalPos - position
		apply_central_impulse(dist.normalized())

		var drot = wrapf(dir.angle() - rotation - CONST.PI_HALF, - PI, PI)
		if abs(drot) < 0.05 and dist.length() < 2.0:
			attachmentFinished.emit(UID)
		return

	if not is_instance_valid(attachedTile):
		if $CollisionShape2D.disabled:

			$CollisionShape2D.disabled = false
			freeze = false
			$ExtractorSprite.offset.y = -0.5
		if not isCarried() and $IronDetector.monitoring:
			var drot = 0.0 - rotation
			apply_torque_impulse(drot * 1.5)

			var tiles: Array = $IronDetector.get_overlapping_bodies()
			if tiles.is_empty():
				if not idling:
					idleSet.emit(UID)
			else:
				for tile in tiles:
					if tile.type == CONST.IRON:
						var impulse = (tile.global_position - global_position).normalized() * 1
						apply_central_impulse(impulse)
						if idling:
							goingToIron.emit(UID)
							idling = false
						return
		return

	if not attachedTile.hasTileOverlay():
		infestWithWorms(attachedTile)
		timeUntilNextTick = Data.of(teamId + ".extractor.processingtime")
		return

	if timeUntilNextTick > 0.0:
		timeUntilNextTick -= delta * GameWorld.cycleSpeed
		return

	if tileToMine:
		var type = tileToMine.type
		var coord = tileToMine.coord
		extractionVisualsPlayed.emit(UID, Data.of(teamId + ".extractor.wormanimationspeed") <= 2.0, coord)
		create_tween().tween_callback(spawnDrop.bind(type)).set_delay(0.35)

		var addedRichness = additionalIronByTileCoord.get(tileToMine.coord, 0)
		if addedRichness > 0:
			additionalIronByTileCoord[tileToMine.coord] = addedRichness - 1
		else:
			tileToMine.richness -= 1

		if tileToMine.richness <= 0:
			Level.map.changeTileType(tileToMine, Data.TILE_DIRT_START)

		tileToMine.disconnect("destroyed", tileToMineDestroyed)
		tileToMine = null
		return

	var wormedTiles = handleSpread()
	if wormedTiles:
		wormedTiles.shuffle()
		for r in wormedTiles:
			if r.richness > 0:
				tileToMine = r
				timeUntilNextTick = Data.of(teamId + ".extractor.processingtime")

				if $BlockedDetection.get_overlapping_bodies().size() >= 5:
					timeUntilNextTick += 0.3
					softEmitNext = true
				tileToMine.connect("destroyed", tileToMineDestroyed)

				Level.map.tiles_node.network_play_tile_overlay(tileToMine.coord)
				return

		kill()
	else:
		timeUntilNextTick = Data.of(teamId + ".extractor.processingtime") * 0.5
		return


	kill()

func playExtractionVisuals(stopTileOverlay: bool, tileCoords: Vector2) -> void :

	create_tween().tween_callback( func(): $DrillHitParticles.restart()).set_delay(0.35)
	$ExtractingSound.startSound()
	$ExtractorSprite.play("extract")
	if stopTileOverlay and Level.map.tiles.has(tileCoords):
		Level.map.tiles[tileCoords].getTileOverlay().stop()

func playTileOverlay(tile: Tile) -> void :
	tile.getTileOverlay().play()

func infestWithWorms(tile):
	Level.map.tiles_node.network_infest_with_worms(tile.coord, teamId, UID)

	if not additionalIronByTileCoord.has(tile.coord):
		additionalIronByTileCoord[tile.coord] = Data.of(teamId + ".extractor.additionalresources")

func spawnDrop(type):
	var dir = getStickToDirection().normalized().rotated(PI)
	var impulse: = Vector2.ZERO
	if softEmitNext:
		softEmitNext = false
	else:
		impulse = dir.rotated(randf_range(-0.4, 0.4)) * randf_range(30, 60)

	Level.drops.network_spawn({
		"type": type, 
		"position": position + dir * 10, 
		"impulse": impulse, 
		"team": teamId
	})
	GameWorld.incrementRunStat("resources_mined", teamId)

func tileToMineDestroyed(_teamId: String, _keeperTechId: String):
	tileToMine = null

func handleSpread():
	var wormedTiles: = [attachedTile]
	var i: = 0
	while true:
		if i >= wormedTiles.size() or i > 1000:
			break

		var tile = wormedTiles[i]
		i += 1

		CONST.DIRECTIONS.shuffle()
		for d in CONST.DIRECTIONS:
			var otherCoord: Vector2 = tile.coord + d
			var otherTile = Level.map.getTile(otherCoord)
			var res = Level.map.getTileData().get_resourcev(otherCoord)

			if otherTile:
				if otherTile.isTileOverlayType(Data.TILE_OVERLAY_WORMS):
					if not wormedTiles.has(otherTile):
						wormedTiles.append(otherTile)
				elif res == Data.TILE_IRON and not otherTile.hasTileOverlay():
					infestWithWorms(otherTile)
					return null
			else:
				if res == Data.TILE_IRON:
					Level.map.revealTile(otherCoord)
					var t = Level.map.getTile(otherCoord)
					if not t.hasTileOverlay():
						infestWithWorms(t)
					return null
	return wormedTiles

func getWormedTiles():
	var wormedTiles: = [attachedTile]
	var i: = 0
	$ExtractingSound.startSound()
	while true:
		if i >= wormedTiles.size() or i > 1000:
			break

		var tile = wormedTiles[i]
		i += 1

		CONST.DIRECTIONS.shuffle()
		for d in CONST.DIRECTIONS:
			var otherCoord: Vector2 = tile.coord + d
			var otherTile = Level.map.getTile(otherCoord)
			var res = Level.map.getTileData().get_resourcev(otherCoord)

			if otherTile:
				if otherTile.isTileOverlayType(Data.TILE_OVERLAY_WORMS):
					if not wormedTiles.has(otherTile):
						wormedTiles.append(otherTile)
				elif res == Data.TILE_IRON and not otherTile.hasTileOverlay():
					infestWithWorms(otherTile)
					return
			else:
				if res == Data.TILE_IRON:
					Level.map.revealTile(otherCoord)
					var t = Level.map.getTile(otherCoord)
					if not t.hasTileOverlay():
						infestWithWorms(t)
					return

func kill():
	wasKilled.emit(UID)

func remoteKill() -> void :
	killed = true
	if multiplayer.is_server():
		if is_instance_valid(attachedTile):
			var wormedTiles: = [attachedTile]
			var i: = 0
			while i < wormedTiles.size():
				var tile = wormedTiles[i]
				i += 1
				for d in CONST.DIRECTIONS:
					var otherCoord: Vector2 = tile.coord + d
					var otherTile = Level.map.getTile(otherCoord)
					if otherTile:
						if otherTile.isTileOverlayType(Data.TILE_OVERLAY_WORMS):
							if not wormedTiles.has(otherTile):
								wormedTiles.append(otherTile)
			if Data.of(teamId + ".extractor.destroyonfinish"):
				var tween: = DeprecatedTween.new()
				Level.map.add_child(tween)
				$DetatchSound.startSound()
				var delay = 0.5
				for tile in wormedTiles:
					tween.interpolate_callback(tile, delay, "hit", Vector2.ZERO, tile.max_health, teamId)
					CONST.DIRECTIONS.shuffle()
					for d in CONST.DIRECTIONS:
						delay += randf_range(0.03, 0.1)
						tween.interpolate_callback(self, delay, "destroyTile", tile.coord + d)
					delay += randf_range(0.1, 0.2)
				tween.interpolate_callback(tween, delay + 0.1, "queue_free")
				$ExtractingSound.stop()
				tween.start()
			else:
				for tile in wormedTiles:
					Level.map.tiles_node.network_remove_tile_overlay(tile.coord)
	$ExtractorSprite.play("vanish")
	$ExtractingSound.stop()

func destroyTile(coord):
	var otherTile = Level.map.getTile(coord)
	if otherTile and not otherTile.isTileOverlayType(Data.TILE_OVERLAY_WORMS)\
	and not otherTile.exploded and Data.isDestructable(otherTile):
		otherTile.exploded = true
		otherTile.hit(Vector2.ZERO, otherTile.max_health, teamId)

func getStickToDirection() -> Vector2:
	var delta = stickingTo - global_position
	if abs(delta.x) > abs(delta.y):
		delta.y = 0
	else:
		delta.x = 0
	return delta

func _on_Mine_body_entered(body):
	if not body.has_meta("destructable") or not body.get_meta("destructable"):
		return

	if body.type != CONST.IRON:
		return

	if not attachedTile:
		initialAttachmentStarted.emit(UID, body.coord)

func startInitialAttachment(tileCoords: Vector2) -> void :
	var tile = Level.map.tiles[tileCoords] as Tile

	startAttachment.call_deferred()
	sticks = true
	stickingTo = tile.global_position
	attachedTile = tile
	attachedTile.destroyed.connect(attachedTileDestroyed)

func finishAttachement():
	if not $CollisionShape2D.disabled:
		$StartAttachSound.startSound()
		$CollisionShape2D.disabled = true
		$ExtractorSprite.play("attach2")
		$ExtractorSprite.offset.y = -2.5






		finishingAttachment = true

func attachedTileDestroyed(inTeamID: String, _inTechId: String) -> void :
	if attaching:
		stopAttachment()
	else:
		kill()
	attachedTile = null

func changeToStatic() -> void :
	if not multiplayer.is_server():
		return
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true

func _on_sprite_animation_finished() -> void :
	match $CageSprite.animation:
		"floating":
			if randf() > 0.8:
				$CageSprite.play("come_out")
			else:
				$CageSprite.play("floating")
		"come_out":
			$CageSprite.play("idle")
		"idle":
			if randf() > 0.7:
				$CageSprite.play("hide")
			else:
				$CageSprite.play("idle")
		"hide":
			$CageSprite.play("floating")

func _on_extractor_sprite_animation_finished() -> void :
	match $ExtractorSprite.animation:
		"attach2":
			if not attachedTile or not is_instance_valid(attachedTile):
				pass
			$ActivateSound.startSound()
			attaching = false
			finishingAttachment = false
			changeToStatic.call_deferred()
			$ExtractorSprite.play("extract_idle")
		"extract":
			$ExtractorSprite.play("extract_idle")
		"vanish":
			queue_free()

func pauseChanged():

	if not sticks or not stickingTo:
		super.pauseChanged()

func set_idle() -> void :
	$CageSprite.play("floating")
	idling = true

func set_going_to_iron() -> void :
	$NoticedIronSound.startSound()
	$DetectingIronSound.stop()
	$CageSprite.play("going_to_iron")
	idling = false
