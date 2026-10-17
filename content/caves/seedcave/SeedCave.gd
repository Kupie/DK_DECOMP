class_name SeedCave
extends "res://content/caves/Cave.gd"

signal hit(keeper: Keeper)

@export var synchronizer: SeedCaveSynchronizer

var hasSeed: = true

var trees: = {}
var seeds: = {

}


var _uid: int = -1
var UID: int:
	get:
		if _uid == -1:
			_uid = randi() >> 20
		return _uid

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasSeed"] = hasSeed
	data["UID"] = UID
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasSeed = data["hasSeed"]
	_uid = data["UID"]
	if not hasSeed:
		%ActiveSprite.queue_free()
		%AmbSound.queue_free()
	if currentState == State.REVEALED:
		%AmbSound.startSound()

func onRevealed():
	%AmbSound.startSound()

func canFocusUse(keeper: Keeper) -> bool:
	return hasSeed

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not hasSeed:
		return false

	hit.emit(keeper)
	return true

func registerHit(playerId: String) -> void :
	if not hasSeed:
		return

	hasSeed = false

	%AmbSound.queue_free()
	%ActiveSprite.queue_free()

	var teamId = Keepers.getKeeper(playerId).teamId

	if multiplayer.is_server():
		var dropSeed: = Level.drops.network_spawn({
			"type": CONST.SEED, 
			"position": $Usable.global_position, 
			"carriers": [playerId], 
			"team": teamId, 
		}) as Seed

		registerSeed(dropSeed)

func networkGrowSeed(pos: Vector2, uid: int) -> void :
	seeds.erase(uid)
	synchronizer.network_rpc(growSeed.bind(uid, pos), true)

@rpc("reliable")
func growSeed(uid: int, pos: Vector2) -> void :
	if not Level.drops.has_drop(uid):
		return

	var dropSeed: = Level.drops.get_drop(uid) as Seed
	var tree: = dropSeed.grow(pos)
	trees[uid] = tree

	if multiplayer.is_server():
		tree.fruits_grown.connect(networkGrowFruits.bind(tree.UID))
		tree.stem_grown.connect(networkTryGrowingStem.bind(tree.UID))
		tree.grown_on_tile.connect(networkGrowOnTile.bind(tree.UID))
		tree.collapsed.connect(networkCollapse.bind(tree.UID))

func networkSettleSeed(pos: Vector2, uid: int) -> void :
	synchronizer.network_rpc(settleSeed.bind(uid, pos), true)

@rpc("reliable")
func settleSeed(uid: int, pos: Vector2) -> void :
	if not Level.drops.has_drop(uid):
		return

	var dropSeed: = Level.drops.get_drop(uid) as Seed
	dropSeed.settled(pos)

func networkTargetTile(coord: Vector2, uid: int) -> void :
	synchronizer.network_rpc(targetTile.bind(coord, uid), true)

@rpc("reliable")
func targetTile(coord: Vector2, uid: int) -> void :
	if not Level.drops.has_drop(uid) or not Level.map.tiles.has(coord):
		return

	var dropSeed: = Level.drops.get_drop(uid) as Seed

	var seededTiles: Array = Data.ofOr(dropSeed.teamId + "seededTiles", [])
	if seededTiles.has(coord):
		return
	else:
		var tile: = Level.map.tiles[coord] as Tile
		dropSeed.targetTile(tile)
		seededTiles.append(coord)
		Data.apply(dropSeed.teamId + "seededTiles", seededTiles)

func networkTryGrowingStem(growthStage: int, uid: int) -> void :
	synchronizer.network_rpc(tryGrowingStem.bind(growthStage, uid), true)

@rpc("reliable")
func tryGrowingStem(growthStage: int, uid: int) -> void :
	if not trees.has(uid):
		return

	var tree = trees[uid] as MineralTree
	tree.tryGrowingStem(growthStage)

func networkGrowFruits(growthStage: int, uid: int) -> void :
	synchronizer.network_rpc(growFruits.bind(growthStage, uid), true)

@rpc("reliable")
func growFruits(growthStage: int, uid: int) -> void :
	if not trees.has(uid):
		return

	var tree = trees[uid] as MineralTree
	tree.growFruits(growthStage)

func networkGrowOnTile(coord: Vector2, uid: int) -> void :
	synchronizer.network_rpc(growOnTile.bind(coord, uid), true)

@rpc("reliable")
func growOnTile(coord: Vector2, uid: int) -> void :
	if not trees.has(uid):
		return

	var tree = trees[uid] as MineralTree
	tree.growOnTile(coord)

func networkCollapse(seedSpawnPosition: Vector2, uid: int) -> void :
	var dropSeed: = Level.drops.network_spawn({
		"type": CONST.SEED, 
		"position": seedSpawnPosition, 
	}) as Seed

	registerSeed(dropSeed)

	synchronizer.network_rpc(collapse.bind(uid), true)

@rpc("reliable")
func collapse(uid: int) -> void :
	if not trees.has(uid):
		return

	var tree = trees[uid] as MineralTree
	trees.erase(uid)
	tree.collapse()

func registerSeed(dropSeed: Seed) -> void :
	if multiplayer.is_server():
		dropSeed.cave_UID = UID
	if not dropSeed.seed_settled.is_connected(networkSettleSeed):
		dropSeed.seed_settled.connect(networkSettleSeed.bind(dropSeed.UID))
		dropSeed.grown.connect(networkGrowSeed.bind(dropSeed.UID))
		dropSeed.tile_targeted.connect(networkTargetTile.bind(dropSeed.UID))
		seeds[dropSeed.UID] = dropSeed

func registerTree(mineralTree: MineralTree) -> void :
	trees[mineralTree.UID] = mineralTree
	if multiplayer.is_server():
		mineralTree.cave_UID = UID
	var needToConnectSignals: bool = multiplayer.is_server() and not \
	mineralTree.fruits_grown.is_connected(networkGrowFruits)
	if needToConnectSignals:
		mineralTree.fruits_grown.connect(networkGrowFruits.bind(mineralTree.UID))
		mineralTree.stem_grown.connect(networkTryGrowingStem.bind(mineralTree.UID))
		mineralTree.grown_on_tile.connect(networkGrowOnTile.bind(mineralTree.UID))
		mineralTree.collapsed.connect(networkCollapse.bind(mineralTree.UID))
