extends HudElement

var unlockedMeters: = [CONST.IRON]
var tilesToScan: = {}
var cooldown: = 0.0

var meterSpots: = [3, 10, 17, 24]

func init():
	super.init()
	tilesToScan[Data.TILE_IRON] = []
	$Iron1.visible = true
	$Water1.visible = false
	$Sand1.visible = false
	$Gadget.visible = false
	Data.listen(self, teamId + ".prospectionmeter.water", true)
	Data.listen(self, teamId + ".prospectionmeter.sand", true)
	Data.listen(self, teamId + ".prospectionmeter.gadget", true)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".prospectionmeter.water":
		if newValue == 1:
			unlockedMeters.append(CONST.WATER)
			$Water1.visible = true
			tilesToScan[Data.TILE_WATER] = []
	elif property == teamId + ".prospectionmeter.sand":
		if newValue == 1:
			unlockedMeters.append(CONST.SAND)
			$Sand1.visible = true
			tilesToScan[Data.TILE_SAND] = []
	elif property == teamId + ".prospectionmeter.gadget":
		if newValue == 1:
			unlockedMeters.append(CONST.GADGET)
			$Gadget.visible = true
			tilesToScan[Data.TILE_GADGET] = []
	updateSize()

func updateSize():
	var i: = 0
	for m in get_children():
		if m is Control and m.visible:
			m.position.y = meterSpots[i]
			i += 1

	element_size.y = 1 + i
	request_rebuild.emit()

func _process(delta: float) -> void :
	if GameWorld.paused:
		return

	if cooldown > 0.0:
		cooldown -= delta
		return

	if visible:
		cooldown = Data.of(teamId + ".prospectionMeter.scandelay")
		for r in tilesToScan:
			tilesToScan[r].clear()
		var radius: int = Data.of(teamId + ".prospectionMeter.range")
		var keeper = Keepers.getKeeper(playerId)
		var keeperCoord = Level.map.getTileCoord(keeper.global_position)
		var td = Level.map.getTileData()
		for x in range( - radius, radius + 1):
			for y in range( - radius, radius + 1):
				if abs(x) + abs(y) > radius:
					continue
				var absCoords = Vector2(keeperCoord.x + x, keeperCoord.y + y)
				var res = td.get_resourcev(absCoords)
				if res == Data.TILE_SUPPLEMENT or res == Data.TILE_RELIC_SWITCH or res == Data.TILE_RELIC:
					res = Data.TILE_GADGET
				if tilesToScan.has(res):
					var tile = Level.map.getTile(absCoords)
					if not tile or not tile.hasTileOverlay():
						var tileOffset = Vector2(x, y)
						tilesToScan[res].append(tileOffset)

		for res in tilesToScan:
			var best = null
			var dist = 9999999
			for tileOffset in tilesToScan[res]:
				var d = tileOffset.length()
				if d < dist:
					dist = d
					best = tileOffset

			var type = Data.TILE_ID_TO_STRING_MAP.get(res, "dirt")

			if type == Const.RELIC or type == Const.RELICSWITCH or type == Const.POWERCORE:
				type = Const.GADGET

			var meter = find_child(type.capitalize() + "Meter")
			if best:
				if meter.goalFilling == 0.0:
					play_detect_sound(type)
				var floatDist = max(0, Level.map.getTilePos(Vector2(keeperCoord) + best).distance_to(keeper.global_position) - GameWorld.TILE_SIZE)
				var detectionRange = float(radius * GameWorld.TILE_SIZE - GameWorld.TILE_SIZE)
				var exponent = 0.8
				var relativeDist = pow(floatDist, exponent) / pow(detectionRange, exponent)
				meter.goalFilling = 1.0 - clamp(relativeDist, 0.0, 1.0)
			else:
				meter.goalFilling = 0.0

func play_detect_sound(type):
	$DetectSound.startSound()
	if type == CONST.GADGET:
		$DetectChamberSound.startSound()
