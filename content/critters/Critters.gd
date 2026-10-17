extends Node


const PROBABILITY_roach = 0.4
const MAXAMOUNT_roach = 20
const PROBABILITY_eyes = 0.5
const MAXAMOUNT_eyes = 8
const PROBABILITY_worm = 0.2
const MAXAMOUNT_worm = 3
const PROBABILITY_rat = 0.15
const MAXAMOUNT_rat = 2
const PROBABILITY_shroomer = 0.2
const MAXAMOUNT_shroomer = 4

const CRITTER_MIN_DISTANCE = 50
const EYE_MAX_DISTANCE_TO_RESOURCE = 30

var critterByBiome: = {
	"green": ["shroomer"], 
	"red": ["roach", "eyes"], 
	"yellow": ["rat", "eyes"], 
	"blue": ["worm"], 
}

const COORD_ABOVE = Vector2(0, -1)

@export var synchronizer: CrittersSynchronizer

var map: Map

func _init() -> void :

	CrittersSynchronizer.register_critter("shroomer", preload("res://content/critters/mushroomman/Shroomer.tscn"))
	CrittersSynchronizer.register_critter("roach", preload("res://content/critters/roach/Roach.tscn"))
	CrittersSynchronizer.register_critter("eyes", preload("res://content/critters/eyes/CaveCritterEyes.tscn"))
	CrittersSynchronizer.register_critter("rat", preload("res://content/critters/rat/Rat.tscn"))
	CrittersSynchronizer.register_critter("worm", preload("res://content/critters/worm/Worm.tscn"))

func init() -> void :
	if multiplayer.is_server():
		$Timer.start()
	map = owner as Map

func _on_Timer_timeout():
	if Keepers.allInsideDome():
		return

	for keeper in Keepers.getAll():
		var keeperCoord = map.getTileCoord(keeper.global_position)
		var tilesByBiome: = {}
		for x in range(-10, 10):
			for y in range(-8, 8):
				if abs(x) <= 3 and abs(y) <= 3:
					continue
				var offset = Vector2i(x, y)
				var coord = keeperCoord + offset
				if coord.y < 3:
					continue
				var t = map.getTile(coord)
				if t and t.type:
					var tiles
					if tilesByBiome.has(t.biome):
						tiles = tilesByBiome.get(t.biome)
					else:
						tiles = []
						tilesByBiome[t.biome] = tiles
					tiles.append(t)
		var dropsNearKeeper = getDropsNearKeeper()

		var closeBiomes: = []
		for offsetY in [-4, 0, 4]:
			var biome = map.getBiomeOfCoord(keeperCoord + Vector2i(0, offsetY))
			if biome and not closeBiomes.has(biome):
				closeBiomes.append(biome)

		for biome in closeBiomes:
			for critter in critterByBiome.get(biome, []):
				if randf() <= get("PROBABILITY_" + critter):
					var critters = get_tree().get_nodes_in_group("critters_" + critter)
					if critters.size() < get("MAXAMOUNT_" + critter):
						call("spawn_" + critter, tilesByBiome.get(biome, []), critters, dropsNearKeeper)








func spawn_eyes(tiles: Array, critters: Array, dropsNearKeeper: Array):
	for drop in dropsNearKeeper:
		if randf() > 0.2:

			continue

		var skip = false
		for e in critters:
			if e.global_position.distance_to(drop.global_position) < CRITTER_MIN_DISTANCE:

				skip = true
		if skip:
			continue

		var tileCoord = map.getTileCoord(drop.global_position)
		var randDir: Array = CONST.DIRECTIONS.duplicate()
		randDir.shuffle()
		for offset in randDir:
			var tile = map.getTile(tileCoord + Vector2i(offset))
			if tile and tiles.has(tile):
				var stream: = PackedByteStream.new()
				stream.encode_vector2(tile.global_position + Vector2(randf_range(0, 8), 0).rotated(randf() * TAU))
				stream.encode_u32(randi())
				stream.encode_vector2(tile.coord)
				synchronizer.network_spawn("eyes", stream.data)
				break








func spawn_roach(tiles: Array, critters: Array, dropsNearKeeper: Array):
	for d: Carryable in dropsNearKeeper:
		if randf() > 0.4:

			continue
		var tileCoord = map.getTileCoord(d.global_position)
		var tile = null
		CONST.DIRECTIONS.shuffle()
		for offset in CONST.DIRECTIONS:
			tile = map.getTile(Vector2(tileCoord) + offset)
			if tile and tiles.has(tile):
				var stream: = PackedByteStream.new()
				stream.encode_vector2(tile.global_position + Vector2(randf_range(0, 8), 0).rotated(randf() * TAU))
				stream.encode_u32(randi())
				stream.encode_u32(d.UID)
				synchronizer.network_spawn("roach", stream.data)






func spawn_worm(tiles: Array, critters: Array, dropsNearKeeper: Array):
	tiles.shuffle()
	var randDir: Array = CONST.DIRECTIONS.duplicate()
	randDir.shuffle()
	for offset in randDir:
		var tile = getFreeTile(tiles, offset)
		if tile:
			var stream: = PackedByteStream.new()
			var spawn_position: Vector2 = tile.global_position + offset * GameWorld.TILE_SIZE * 0.93
			spawn_position += Vector2(randf_range(-8, 8), 0).rotated(offset.angle() + PI / 2)
			stream.encode_vector2(spawn_position)
			stream.encode_float(offset.angle())
			stream.encode_u32(randi())
			stream.encode_vector2(tile.coord)
			synchronizer.network_spawn("worm", stream.data)
			return





func spawn_rat(tiles: Array, critters: Array, dropsNearKeeper: Array):
	tiles.shuffle()
	var tile = getFreeTile(tiles, COORD_ABOVE)
	if tile:
		var stream: = PackedByteStream.new()
		stream.encode_vector2(tile.global_position + COORD_ABOVE * GameWorld.TILE_SIZE)
		stream.encode_u32(randi())
		var rat: = synchronizer.network_spawn("rat", stream.data)
		if is_instance_valid(rat):
			rat.state_changed.connect(on_rat_state_changed.bind(rat.UID))

func on_rat_state_changed(state: int, direction: Vector2, UID: int) -> void :
	synchronizer.network_rpc(synchronizer.critter_state_update.bind(state, direction, UID), false)

func spawn_shroomer(tiles: Array, critters: Array, dropsNearKeeper: Array):
	tiles.shuffle()
	var tile = getFreeTile(tiles, COORD_ABOVE)
	if tile:
		var stream: = PackedByteStream.new()
		stream.encode_vector2(tile.global_position + COORD_ABOVE * GameWorld.TILE_SIZE * 0.45)
		stream.encode_u32(randi())
		synchronizer.network_spawn("shroomer", stream.data)


func getDropsNearKeeper() -> Array[Carryable]:

	var drops = get_tree().get_nodes_in_group("drops")
	var selectedDrops: Array[Carryable] = []
	for i in range(drops.size() - 1, -1, -1):
		var d = drops[i]
		for keeper in Keepers.getAll():
			var distance_from_keeper = keeper.global_position.distance_to(d.global_position)
			if distance_from_keeper > CRITTER_MIN_DISTANCE and distance_from_keeper <= 250:
				selectedDrops.append(d)
	selectedDrops.shuffle()
	return selectedDrops

func getFreeTile(tiles: Array, offset: Vector2):
	for tile in tiles:
		var biome = map.getBiomeOfCoord(tile.coord + offset)
		var resource = map.tileData.get_resourcev(tile.coord + offset)
		var hardness = map.tileData.get_hardnessv(tile.coord + offset)
		if biome and resource == -1 and hardness >= 0:
			return tile
	return null

func pauseChanged():
	if GameWorld.paused:
		$Timer.paused = true
	else:
		$Timer.paused = false
