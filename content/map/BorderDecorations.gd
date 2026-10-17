extends Node2D

var tilesOfDecorative: = {}
var decorativeOfTile: = {}
var dirtyTiles: = []
var tilesToDecorate: = []
var tileCoordsUndecoratable: = []
var borderSprites = null
var process_deco_cooldown: = 0.0

func init():
	tilesOfDecorative = {}
	decorativeOfTile = {}
	dirtyTiles = []
	tilesToDecorate = []


	markTileUndecoratable(Vector2(-1, -2))
	markTileUndecoratable(Vector2(0, -2))
	markTileUndecoratable(Vector2(-1, -1))
	markTileUndecoratable(Vector2(0, -1))


var decorPatterns: = {
	"blue": {
	[[3]]: [false, preload("res://content/map/decorations/square/Ceiling1.tscn")], 
	[[3], [3], [3]]: [false, preload("res://content/map/decorations/square/Ceiling2.tscn")], 
	[[12]]: [false, preload("res://content/map/decorations/square/Floor1.tscn")], 
	[[8]]: [false, preload("res://content/map/decorations/square/EdgeFloor1.tscn")], 
	[[4]]: [true, preload("res://content/map/decorations/square/EdgeFloor1.tscn")], 
	[[1]]: [false, preload("res://content/map/decorations/square/EdgeCeiling1.tscn")], 
	[[2]]: [true, preload("res://content/map/decorations/square/EdgeCeiling1.tscn")], 
	}, 
	"grey": {
	[[3], [3]]: [false, preload("res://content/map/decorations/grass/Ceiling1.tscn")], 
	[[11, 9], [3, 0]]: [false, preload("res://content/map/decorations/grass/CornerCeiling1.tscn")], 
	[[0, 3], [7, 6]]: [true, preload("res://content/map/decorations/grass/CornerCeiling1.tscn")], 
	[[12]]: [false, preload("res://content/map/decorations/grass/Floor1.tscn")], 
	[[12], [12]]: [false, preload("res://content/map/decorations/grass/Floor2.tscn")], 
	[[9, 13], [0, 12]]: [false, preload("res://content/map/decorations/grass/CornerFloor1.tscn")], 
	[[0, 12], [6, 14]]: [true, preload("res://content/map/decorations/grass/CornerFloor1.tscn")], 
	[[8]]: [false, preload("res://content/map/decorations/grass/EdgeFloor1.tscn")], 
	[[4]]: [true, preload("res://content/map/decorations/grass/EdgeFloor1.tscn")], 
	[[1]]: [false, preload("res://content/map/decorations/grass/EdgeCeiling1.tscn")], 
	[[2]]: [true, preload("res://content/map/decorations/grass/EdgeCeiling1.tscn")], 
	}, 
	"green": {
	[[3], [3]]: [false, preload("res://content/map/decorations/mushroom/Ceiling1.tscn")], 
	[[11, 9], [3, 0]]: [false, preload("res://content/map/decorations/mushroom/CornerCeiling1.tscn")], 
	[[0, 3], [7, 6]]: [true, preload("res://content/map/decorations/mushroom/CornerCeiling1.tscn")], 
	[[12]]: [false, preload("res://content/map/decorations/mushroom/Floor1.tscn")], 
	[[12], [12], [12]]: [false, preload("res://content/map/decorations/mushroom/Floor2.tscn")], 
	[[9]]: [false, preload("res://content/map/decorations/mushroom/Wall1.tscn")], 
	[[6]]: [true, preload("res://content/map/decorations/mushroom/Wall1.tscn")], 
	[[9, 9]]: [false, preload("res://content/map/decorations/mushroom/Wall2.tscn")], 
	[[6, 6]]: [true, preload("res://content/map/decorations/mushroom/Wall2.tscn")], 
	}, 
	"yellow": {
	[[12]]: [false, preload("res://content/map/decorations/seaweed/Floor1.tscn")], 
	[[12]]: [false, preload("res://content/map/decorations/seaweed/Floor2.tscn")], 
	[[3]]: [false, preload("res://content/map/decorations/seaweed/Ceiling1.tscn")], 
	[[11, 9], [3, 0]]: [false, preload("res://content/map/decorations/seaweed/CornerCeiling1.tscn")], 
	[[3, 7], [0, 6]]: [true, preload("res://content/map/decorations/seaweed/CornerCeiling1.tscn")], 
	[[9]]: [false, preload("res://content/map/decorations/seaweed/Wall1.tscn")], 
	[[6]]: [true, preload("res://content/map/decorations/seaweed/Wall1.tscn")], 
	}, 
	"red": {
	[[9, 13], [0, 12]]: [false, preload("res://content/map/decorations/fuzzy/CornerFloor1.tscn")], 
	[[0, 12], [6, 14]]: [true, preload("res://content/map/decorations/fuzzy/CornerFloor1.tscn")], 
	[[3], [3]]: [true, preload("res://content/map/decorations/fuzzy/Ceiling1.tscn")], 
	[[11, 9], [3, 0]]: [false, preload("res://content/map/decorations/fuzzy/CornerCeiling1.tscn")], 
	[[3, 7], [0, 6]]: [true, preload("res://content/map/decorations/fuzzy/CornerCeiling1.tscn")], 
	[[8]]: [false, preload("res://content/map/decorations/fuzzy/EdgeFloor1.tscn")], 
	[[4]]: [true, preload("res://content/map/decorations/fuzzy/EdgeFloor1.tscn")], 
	[[2]]: [false, preload("res://content/map/decorations/fuzzy/EdgeCeiling1.tscn")], 
	[[1]]: [true, preload("res://content/map/decorations/fuzzy/EdgeCeiling1.tscn")], 
	[[12], [12]]: [false, preload("res://content/map/decorations/fuzzy/Floor1.tscn")], 
	[[12]]: [false, preload("res://content/map/decorations/fuzzy/Floor2.tscn")], 
	[[9]]: [false, preload("res://content/map/decorations/fuzzy/Wall2.tscn")], 
	[[6]]: [true, preload("res://content/map/decorations/fuzzy/Wall2.tscn")], 
	[[9, 9]]: [false, preload("res://content/map/decorations/fuzzy/Wall1.tscn")], 
	[[6, 6]]: [true, preload("res://content/map/decorations/fuzzy/Wall1.tscn")], 
	}
}

func _ready():
	for teamId in Level.teams:
		Data.listen(self, teamId + ".monsters.wavepresent")

func propertyChanged(property: String, oldValue, newValue):
	if not newValue:
		for deco in get_tree().get_nodes_in_group("growing_decorations"):
			deco.progress()
		runDecoration()

func _process(delta):
	handleDirtyTiles()

	process_deco_cooldown -= delta
	if process_deco_cooldown <= 0.0:
		process_deco_cooldown = 5.0
		for deco in get_tree().get_nodes_in_group("growing_decorations"):
			if deco.visibility > deco.visibleAt:
				var ok: = true
				for keeper in Keepers.getAll():
					if keeper.position.distance_squared_to(deco.position) < 122500:
						ok = false
						break
				if ok:
					deco.makeVisible()

	if GameWorld.devMode and Input.is_action_just_pressed("f4"):
		for deco in get_tree().get_nodes_in_group("growing_decorations"):
			deco.progress()

func runDecoration():
	applyDecoratives(tilesToDecorate)
	tilesToDecorate.clear()

func handleDirtyTiles():
	if dirtyTiles.size() == 0:
		return


	var decosToDissolve: = []
	for dirtyTile in dirtyTiles:
		if not decorativeOfTile.has(dirtyTile):
			continue

		var deco = decorativeOfTile.get(dirtyTile)

		if tileCoordsUndecoratable.has(dirtyTile):
			decosToDissolve.append(deco)
			continue

		var pattern = deco.get_meta("pattern")
		var startTile = tilesOfDecorative[deco].front()
		var stillFits: = doesDecorativeFit(pattern, startTile, deco)
		if not stillFits and not decosToDissolve.has(deco):
			decosToDissolve.append(deco)

	for tile in dirtyTiles:
		if not tileCoordsUndecoratable.has(tile):
			tilesToDecorate.append(tile)
	dirtyTiles.clear()

	for deco in decosToDissolve:
		removeDecorative(deco)

func removeDecorative(deco):
	for t in tilesOfDecorative.get(deco, []):
		decorativeOfTile.erase(t)
		markDirtyTile(t)
	deco.dissolve()
	tilesOfDecorative.erase(deco)

func markDirtyTile(tileCoord):
	if not dirtyTiles.has(tileCoord):
		dirtyTiles.append(tileCoord)

func applyDecoratives(tilesToDecorate: Array) -> Array:
	var placedDecorations: = []
	while not tilesToDecorate.is_empty():
		var baseKey = tilesToDecorate.front()
		tilesToDecorate.remove_at(0)
		var borderSprite = borderSprites.get(baseKey, null)
		if borderSprite and borderSprite[1] == "mixed":
			tileCoordsUndecoratable.append(baseKey)

			continue

		if decorativeOfTile.has(baseKey):

			continue

		if not borderSprite:
			continue

		var biome = borderSprite[1]
		if not decorPatterns.has(biome):

			continue

		var applicablePatterns = decorPatterns.get(biome)
		var randomPatternKey = applicablePatterns.keys()

		var rng: = RandomNumberGenerator.new()
		rng.seed = Level.levelSeed + hash(baseKey)
		Utils.shuffle(randomPatternKey, rng)

		for pattern in randomPatternKey:
			if decorativeOfTile.has(baseKey):
				break
			var lengthX: int = pattern.size()
			var lengthY: int = pattern.front().size()
			var applied: = false
			for startX in range(0, lengthX):
				for startY in range(0, lengthY):
					var topLeftCoord = baseKey - Vector2(startX, startY)
					var fits: = doesDecorativeFit(pattern, topLeftCoord, null, biome)
					if fits:
						var data = applicablePatterns[pattern]
						var isFlip = data[0]
						var deco = data[1].instantiate()
						deco.set_meta("pattern", pattern)
						deco.position = Vector2(topLeftCoord.x + lengthX * 0.5, topLeftCoord.y + lengthY * 0.5) * GameWorld.TILE_SIZE - GameWorld.HALF_TILE_SIZE * Vector2.ONE
						if isFlip:
							deco.flipH()
						add_child(deco)
						deco.init(rng)
						placedDecorations.append(deco)

						var tiles: = []
						for x in range(0, lengthX):
							for y in range(0, lengthY):
								var key = Vector2(x + topLeftCoord.x, y + topLeftCoord.y)
								tiles.append(key)


								decorativeOfTile[key] = deco
						tilesOfDecorative[deco] = tiles
						applied = true


					if applied:
						break
				if applied:
					break
	return placedDecorations

func doesDecorativeFit(pattern: Array, coord: Vector2, decorative = null, biome: = "") -> bool:
	for x in range(0, pattern.size()):
		for y in range(0, pattern.front().size()):
			var patternVal = pattern[x][y]
			if patternVal == -1:

				continue

			var key = coord + Vector2(x, y)
			if decorativeOfTile.has(key):

				if not decorative:
					return false
				elif decorativeOfTile.get(key) != decorative:
					return false

			if borderSprites.has(key):
				var borderSprite = borderSprites.get(key)
				if biome != "" and borderSprite[1] != biome:
					return false
				if borderSprite[0] != patternVal:

					return false
			elif patternVal == 0:

				continue
			else:
				return false
	return true

func markTileUndecoratable(c: Vector2):
	if decorativeOfTile.has(c):
		removeDecorative(decorativeOfTile.get(c))
	if not tileCoordsUndecoratable.has(c):
		tileCoordsUndecoratable.append(c)
