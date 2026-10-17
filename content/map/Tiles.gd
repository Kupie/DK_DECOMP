extends Node2D

var tiles: Dictionary = {}
var tiles_to_destroy: Dictionary = {}

func on_tile_hit(dir: Vector2, dmg: float, teamId: String, keeperTechId: String, tile: Tile) -> void :
	for client in Network.clients:
		if client.connection_state == Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC or client.connection_state == Network.ConnectionState.LOADOUT_STAGE_SYNC or client.connection_state == Network.ConnectionState.LEVEL_STAGE_SYNC:
			propagate_hit.rpc_id(client.peer_id, tile.coord, dir, dmg, teamId, keeperTechId)

@rpc("reliable", "any_peer")
func propagate_hit(coord: Vector2, dir: Vector2, dmg: float, teamId: String, keeperTechId: String) -> void :
	if tiles.has(coord):
		if is_instance_valid(tiles[coord]):
			tiles[coord].remote_hit(dir, dmg, teamId, keeperTechId)
		else:
			tiles.erase(coord)

func on_tile_destroyed(teamId: String, keeperTechId: String, tile: Tile) -> void :
	if not Network.is_server():
		return

	for client in Network.clients:
		var can_sync_now: = client.connection_state in [Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC, Network.ConnectionState.LOADOUT_STAGE_SYNC, Network.ConnectionState.LEVEL_STAGE_SYNC]
		if can_sync_now:
			propagate_destroyed.rpc_id(client.peer_id, tile.coord, tile.exploded, teamId, keeperTechId)
		else:
			if not tiles_to_destroy.has(client.peer_id):
				tiles_to_destroy[client.peer_id] = PackedVector2Array()
			tiles_to_destroy[client.peer_id].append(tile.coord)

@rpc("reliable", "any_peer")
func propagate_destroyed(coord: Vector2, exploded: bool, teamId: String, techId: String = "") -> void :
	if tiles.has(coord) and is_instance_valid(tiles[coord]):
		tiles[coord].destroyed.disconnect(on_tile_destroyed)
		tiles[coord].exploded = exploded
		tiles[coord].destroyed.emit(teamId, techId)

@rpc("reliable")
func propagate_bulk_destroyed(buffer: PackedVector2Array) -> void :
	for tileCoord in buffer:
		propagate_destroyed(tileCoord, false, "")

func on_tile_exiting(tile: Tile) -> void :
	tiles.erase(tile.coord)

func add_tile(tile: Tile) -> void :
	tile.name = "%dx%d" % [tile.coord.x, tile.coord.y]
	tiles[tile.coord] = tile
	tile.tile_hit.connect(on_tile_hit.bind(tile))
	tile.destroyed.connect(on_tile_destroyed.bind(tile))

	add_child(tile)



func network_tiles_to_destroy(peer_id: int) -> void :
	if not tiles_to_destroy.has(peer_id) or tiles_to_destroy[peer_id].size() == 0:
		return

	var tileCoords = tiles_to_destroy[peer_id]
	propagate_bulk_destroyed.rpc_id(peer_id, tileCoords)

	tiles_to_destroy[peer_id].clear()

func network_infect_tile(tileCoords: Vector2, teamId: String, overlaySeed: int) -> void :
	Network.rpc_if_state(infect_tile.bind(tileCoords, teamId, overlaySeed), Network.ConnectionState.LEVEL_STAGE_SYNC, true)

@rpc("reliable")
func infect_tile(tileCoords: Vector2, teamId: String, overlaySeed: int) -> void :
	if not tiles.has(tileCoords):
		return
	var tile: = tiles[tileCoords] as Tile
	tile.setTileOverlay.call_deferred(Data.TILE_OVERLAY_MYZEL, teamId, overlaySeed)

func network_infest_with_worms(tileCoords: Vector2, teamId: String, overlaySeed: int) -> void :
	Network.rpc_if_state(infest_with_worms.bind(tileCoords, teamId, overlaySeed), Network.ConnectionState.LEVEL_STAGE_SYNC, true)

@rpc("reliable")
func infest_with_worms(tileCoords: Vector2, teamId: String, overlaySeed: int) -> void :
	if not Level.map.visuallyRevealedTiles.has(tileCoords):
		Level.map.revealTile(tileCoords)

	if not tiles.has(tileCoords):
		return

	var tile: = tiles[tileCoords] as Tile

	tile.setTileOverlay.call_deferred(Data.TILE_OVERLAY_WORMS, teamId, overlaySeed)

func network_play_tile_overlay(tileCoords: Vector2) -> void :
	Network.rpc_if_state(play_tile_overlay.bind(tileCoords), Network.ConnectionState.LEVEL_STAGE_SYNC, true)

@rpc("reliable")
func play_tile_overlay(tileCoords: Vector2) -> void :
	if not tiles.has(tileCoords):
		return

	var tile: = tiles[tileCoords] as Tile

	tile.getTileOverlay().play()

func network_change_tile_type(tileCoords: Vector2, typeId: int) -> void :
	Network.rpc_if_state(change_tile_type.bind(tileCoords, typeId), Network.ConnectionState.LEVEL_STAGE_SYNC, true)

@rpc("reliable")
func change_tile_type(tileCoords: Vector2, typeId: int) -> void :
	if not tiles.has(tileCoords):
		return

	var tile: = tiles[tileCoords] as Tile
	tile.setType(Data.TILE_ID_TO_STRING_MAP.get(typeId, "dirt"))
	Level.map.getTileData().set_resourcev(tile.coord, typeId)
	Level.map.updateBorderSpriteOfTileCoord(tile.coord)
	Recorder.recordTileChangedType(tile.coord, typeId)

func network_remove_tile_overlay(tileCoords: Vector2) -> void :
	Network.rpc_if_state(remove_tile_overlay.bind(tileCoords), Network.ConnectionState.LEVEL_STAGE_SYNC, true)

@rpc("reliable")
func remove_tile_overlay(tileCoords: Vector2) -> void :
	if not tiles.has(tileCoords):
		return
	if not is_instance_valid(tiles[tileCoords]):

		tiles.erase(tileCoords)
		return

	var tile: = tiles[tileCoords] as Tile
	tile.removeTileOverlay()
