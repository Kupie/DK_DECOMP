class_name MineralTree
extends Node2D

signal fruits_grown(growthStage: int)
signal stem_grown(growthStage: int)
signal grown_on_tile(coord: Vector2)
signal collapsed(seedSpawnPosition: Vector2)


@export var synchronizer: MineralTreeSynchronizer

var stage5Tiles: = [Vector2(0, 0), Vector2(0, -1)]
var stage10Tiles: = [Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(-1, -1), Vector2(1, -1)]
var stage15Tiles: = [Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, -2), Vector2(1, -2), Vector2(0, -2)]

var teamId: String
var UID: int
var cave_UID: int

var fruits: = {}

var currentGrowthStage: int = 0
var rootCoords: = []
var fruitStage: int = 0

var growthCooldown: = 0.0

func _notification(what: int) -> void :
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		fruits[1] = [$FruitPosition1_1]
		fruits[2] = [$FruitPosition2_1, $FruitPosition2_2]
		fruits[3] = [$FruitPosition3_1, $FruitPosition3_2, $FruitPosition3_3]

	if what == NOTIFICATION_READY:
		Data.listen(self, teamId + ".monsters.cycle")
		$Stem.frame = currentGrowthStage
		$TreeAmbience.startSound()
		resetGrowthCooldown()
		if Data.ofOr("world.inversegravity", false):
			self.rotation = PI
		synchronizer.init()

func serialize() -> Dictionary:
	var data = {
		"rootCoords": var_to_str(rootCoords), 
		"currentGrowthStage": currentGrowthStage, 
		"growthCooldown": growthCooldown, 
		"fruitStage": fruitStage, 
		"fruitsData": [], 
		"UID": UID, 
		"caveUID": cave_UID
	}

	for fs in fruits.get(fruitStage, []):
		data["fruitsData"].append({
			"type": fs.type, 
			"remainingCycles": fs.remainingCycles
		})

	data["meta.priority"] = 100
	data["meta.kind"] = "generic"

	return data

func deserialize(data: Dictionary):
	var caves: Array = Level.get_tree().get_nodes_in_group("cave")
	cave_UID = data["caveUID"]
	UID = data["UID"]
	self.name = str(UID)
	for cave in caves:
		if cave is SeedCave and cave.UID == cave_UID:

			cave.registerTree(self)
			break

	currentGrowthStage = int(data.get("currentGrowthStage", 0))
	growthCooldown = float(data.get("growthCooldown", 0))
	$Stem.frame = currentGrowthStage
	fruitStage = int(data.get("fruitStage", 0))
	if data.has("rootCoords"):
		rootCoords = BackwardCompatibilityUtils.str_to_var(data["rootCoords"])
	for coord in rootCoords:
		Level.map.addTileDestroyedListener(self, coord)
	if data.has("fruitsData") and fruits.has(fruitStage):
		var fruitsData = data["fruitsData"]
		for i in range(fruitsData.size()):
			if fruits[fruitStage].size() > i:
				var fs = fruits[fruitStage][i]
				fs.setType(fruitsData[i].get("type", "iron"))
				fs.remainingCycles = int(fruitsData[i].get("remainingCycles", 1))
				if fs.remainingCycles == 0:
					fs.show()

func propertyChanged(property: String, oldValue, newValue):
	if not multiplayer.is_server():
		return

	if not oldValue or oldValue == newValue:
		return

	tryRooting()
	fruits_grown.emit(currentGrowthStage)

func _process(delta: float) -> void :
	if GameWorld.softPaused(teamId):
		return
	if not multiplayer.is_server():
		return

	if growthCooldown > 0.0:
		growthCooldown -= delta
		return

	resetGrowthCooldown()
	stem_grown.emit(currentGrowthStage)

func growFruits(growthStage: int):
	currentGrowthStage = growthStage
	if currentGrowthStage < 5:
		return

	var newFruitStage = currentGrowthStage / 5
	var wasReset: = false
	if newFruitStage != fruitStage and fruitStage > 0:

		for fs in fruits[fruitStage]:
			fs.clear()
		wasReset = true
	fruitStage = newFruitStage
	updateFruitType()
	for fs in fruits[fruitStage]:
		fs.progressCycle()
	updateFruitType()

	if wasReset:
		for fs in fruits[fruitStage]:
			fs.progressCycle()
			fs.progressCycle()

func updateFruitType():
	var rootedResources: = {CONST.IRON: 1}
	for rootCoord in rootCoords:
		var res = Level.map.getTileData().get_resourcev(rootCoord)
		match int(res):
			0: rootedResources[CONST.IRON] = 1 + rootedResources.get(CONST.IRON, 0)
			1: rootedResources[CONST.WATER] = 1 + rootedResources.get(CONST.WATER, 0)
			2: rootedResources[CONST.SAND] = min(1, 1 + rootedResources.get(CONST.SAND, 0))

	for f in fruits[fruitStage]:
		match f.type:
			CONST.IRON: rootedResources[CONST.IRON] = rootedResources.get(CONST.IRON, 0) - 1
			CONST.WATER: rootedResources[CONST.WATER] = rootedResources.get(CONST.WATER, 0) - 1
			CONST.SAND: rootedResources[CONST.SAND] = rootedResources.get(CONST.SAND, 0) - 1

	for fs in fruits[fruitStage]:
		if not fs.type or fs.type == "":

			var type: String
			if rootedResources.get(CONST.SAND, 0) > 0:
				type = CONST.SAND
				rootedResources[CONST.SAND] = rootedResources.get(CONST.SAND, 0) - 1
			elif rootedResources.get(CONST.WATER, 0) > 0:
				type = CONST.WATER
				rootedResources[CONST.WATER] = rootedResources.get(CONST.WATER, 0) - 1
			elif rootedResources.get(CONST.IRON, 0) > 0:
				type = CONST.IRON
				rootedResources[CONST.IRON] = rootedResources.get(CONST.IRON, 0) - 1

			if type:
				fs.setType(type)
			else:
				for t in [CONST.SAND, CONST.WATER, CONST.IRON]:
					for fs2 in fruits[fruitStage] and fs.totalCycles >= 5:
						if fs2 == t:
							fs.setType(t)

func resetGrowthCooldown():
	growthCooldown = Data.stabilizedRandomFloat(15, 20, "mineraltree", 5.0)

func tryGrowingStem(growthStage: int):
	var resourceTiles: = 0
	for rootCoord in rootCoords:
		var res = Level.map.getTileData().get_resourcev(rootCoord)
		if res >= 0 and res <= 2:
			resourceTiles += 1

	var baseCoord = rootCoords.front()
	baseCoord.y += 1 if Data.ofOr("world.inversegravity", false) else -1

	var relevantTiles: Array
	currentGrowthStage = growthStage
	if currentGrowthStage < 5:
		relevantTiles = stage5Tiles
	elif currentGrowthStage < 10:
		relevantTiles = stage10Tiles
	else:
		relevantTiles = stage15Tiles


	if Data.ofOr("world.inversegravity", false):
		relevantTiles = relevantTiles.duplicate()
		for x in relevantTiles.size():
			relevantTiles[x].y *= -1

	for d in relevantTiles:
		var tile = Level.map.getTile(baseCoord + d)
		if tile != null and Data.isDestructable(tile):
			tile.hit(Vector2.ZERO, tile.max_health, teamId)

	if currentGrowthStage < 5:
		currentGrowthStage += 1
	if currentGrowthStage == 5 and resourceTiles >= 2:
		currentGrowthStage = 10
	elif currentGrowthStage == 10 and resourceTiles >= 3:
		currentGrowthStage = 15
	$Stem.frame = currentGrowthStage

func tryRooting():



	var baseCoord = rootCoords.front()

	var randDir: Array = CONST.DIRECTIONS.duplicate()
	randDir.shuffle()
	var roots = rootCoords.duplicate()
	roots.shuffle()
	var freeTiles: = []
	for root in roots:
		for d in randDir:
			var coord = root + d
			if rootCoords.has(coord) or (baseCoord - coord).length() >= 30:
				continue
			var res = Level.map.getTileData().get_resourcev(root + d)
			if res >= 0 and res <= 2:
				grown_on_tile.emit(coord)
				return
			elif res == 10:
				freeTiles.append(coord)

	if freeTiles.size() > 0:
		var coord = freeTiles[randi() % freeTiles.size()]
		grown_on_tile.emit(coord)

func growOnTile(coord):
	var tile = Level.map.getTile(coord)
	if not tile:
		Level.map.revealTile(coord)
		if not Level.map.tiles.has(coord):
			return
		tile = Level.map.getTile(coord)
	tile.setTileOverlay(Data.TILE_OVERLAY_ROOTS)
	rootCoords.append(coord)
	Level.map.addTileDestroyedListener(self, coord)

func tileDestroyed(tileCoord: Vector2):
	if rootCoords.has(tileCoord):
		if rootCoords.front() == tileCoord:
			collapsed.emit(global_position)
			return
		else:
			rootCoords.erase(tileCoord)

	var unreachableRoots = rootCoords.duplicate()
	var open: = [unreachableRoots.pop_front()]
	while open.size() > 0:
		var rootCoord = open.pop_front()
		for d in CONST.DIRECTIONS:
			var coord = rootCoord + d
			if unreachableRoots.has(coord):
				unreachableRoots.erase(coord)
				open.append(coord)

	for unreachableRoot in unreachableRoots:
		rootCoords.erase(unreachableRoot)
		Level.map.removeTileDestroyedListener(self, unreachableRoot)

func collapse():
	for root in rootCoords:
		Level.map.removeTileDestroyedListener(self, root)
	queue_free()

	for fs in fruits.get(fruitStage, []):
		if fs.visible and fs.type != "":
			fs.spawnResource()
