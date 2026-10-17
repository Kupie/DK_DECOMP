extends Map


func spawnDrop(tile: Tile, teamId: String) -> void :
	var dss: = StageManager.currentStage as DeviceSelectionStage
	if not dss.clientOnlyMode:
		super.spawnDrop(tile, teamId)
		return

	var data: = {}
	data["type"] = tile.type
	data["position"] = tile.global_position + 0.6 * Vector2(GameWorld.HALF_TILE_SIZE - randf() * GameWorld.TILE_SIZE, GameWorld.HALF_TILE_SIZE - randf() * GameWorld.TILE_SIZE)
	data["impulse"] = Vector2(0, 40).rotated(randf() * TAU)
	var drop: = drop_system.local_spawn(data)
	drop.set_multiplayer_authority(multiplayer.get_unique_id())


func is_server() -> bool:
	var dss: = StageManager.currentStage as DeviceSelectionStage
	return dss.clientOnlyMode or multiplayer.is_server()
