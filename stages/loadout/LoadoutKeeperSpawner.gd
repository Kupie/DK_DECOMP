class_name LoadoutKeeperSpawner
extends Node

signal keeper_removed(keeper: Keeper)
signal spawned(loadout_keeper: LoadoutKeeper)
signal keeper_replaced(new_keeper: Keeper, old_keeper: Keeper)
signal initial_spawned

func get_connection_states() -> Array[Network.ConnectionState]:
	return [get_spawn_connection_state(), get_sync_connection_state()]

func get_sync_connection_state() -> Network.ConnectionState:
	return Network.ConnectionState.LOADOUT_STAGE_SYNC

func get_spawn_connection_state() -> Network.ConnectionState:
	return Network.ConnectionState.LOADOUT_STAGE_SPAWN

func network_spawn(buffer: PackedByteArray):
	spawn_from_bytes(buffer)
	for client in Network.clients:
		if get_connection_states().has(client.connection_state):
			client.full_data_sync()
			spawn_from_bytes.rpc_id(client.peer_id, buffer)

@rpc("reliable")
func spawn_from_bytes(buffer: PackedByteArray, replace_keeper: = false, old_player_id: String = ""):
	var lk = LoadoutKeeper.from_bytes(buffer)
	var playerId: String = lk.playerId

	var lk_to_replace: LoadoutKeeper
	if replace_keeper:
		var player_id_to_replace: String = old_player_id if old_player_id != "" else lk.playerId
		for l in Level.loadout.keepers:
			if l.playerId == player_id_to_replace:
				lk_to_replace = l
		if is_instance_valid(lk_to_replace):
			lk_to_replace.keeper.name += "-freed"
			Level.loadout.keepers.erase(lk_to_replace)

	var scenes = GameWorld.addUpgrade(lk.keeperId, lk.playerId)
	lk.keeper = scenes["keeper"]
	lk.keeper.peerId = lk.peerId
	lk.keeper.position = lk.position
	lk.keeper.deviceId = lk.deviceId
	lk.keeper.playerId = lk.playerId
	lk.keeper.playerName = lk.playerName
	lk.keeper.teamId = lk.teamId
	lk.keeper.name = playerId
	lk.keeper.remapColorIdPerPalette = lk.remapColorIdPerPalette
	lk.keeper.tutorialsActive = lk.tutorialsActive
	lk.keeper.setSkin(lk.skinId, lk.colorId)
	if replace_keeper:
		Keepers.replaceKeeper(lk.keeper, lk_to_replace.keeper)
		keeper_replaced.emit(lk.keeper, lk_to_replace.keeper)
	else:
		Keepers.registerKeeper(lk.keeper)
	Level.loadout.keepers.append(lk)

	spawned.emit(lk)

@rpc("reliable")
func spawn_initial(data: PackedByteArray):
	var buffer: = PackedByteStream.from_bytes(data)
	var to_spawn: int = buffer.decode_u8()
	for _i in range(to_spawn):
		var offset: int = buffer.decode_u8()
		spawn_from_bytes(buffer.slice(offset).data)

	initial_spawned.emit()
	Keepers.initial_keepers_spawned.emit()

func network_replace(playerId: String, techId: String):
	Network.rpc_if_state(replace.bind(playerId, techId), get_sync_connection_state(), true)

@rpc("reliable")
func replace(playerId: String, techId: String):
	var keeper: = Keepers.getKeeper(playerId)
	keeper.kill()

	var split = techId.split("-")
	var loadoutKeeper: LoadoutKeeper
	for lk in Level.loadout.keepers:
		if lk.playerId == playerId:
			loadoutKeeper = lk
			break

	loadoutKeeper.keeperId = split[0]
	loadoutKeeper.skinId = split[1]
	var member = Lobby.get_member_by_player_id(playerId)
	member.keeper_id = int(loadoutKeeper.keeperId.lstrip("keeper"))
	member.skin_id = int(loadoutKeeper.skinId.lstrip("skin"))
	loadoutKeeper.tutorialsActive = true
	loadoutKeeper.position = loadoutKeeper.keeper.position

	if Data.loadoutKeepers.has(split[0]):
		Audio.sound("loadout_" + loadoutKeeper.keeperId)

		var data = loadoutKeeper.to_bytes()
		spawn_from_bytes(data, true)

	if member.peer_id == multiplayer.get_unique_id():
		GameWorld.ostKeeperId = loadoutKeeper.keeperId
		Audio.fadeIntro()


func network_replace_player_id(new_lk_buffer: PackedByteArray, old_player_id: String) -> void :
	Network.rpc_if_state(replace_player_id.bind(new_lk_buffer, old_player_id), get_sync_connection_state(), true)

@rpc("reliable")
func replace_player_id(new_lk_buffer: PackedByteArray, old_player_id: String) -> void :
	spawn_from_bytes(new_lk_buffer, true, old_player_id)

func network_despawn(peer_id: int, device_id: int) -> void :
	despawn(peer_id, device_id)
	Network.rpc_for_states(despawn.bind(peer_id, device_id), get_connection_states())

@rpc("reliable")
func despawn(peer_id: int, device_id: int) -> void :
	var loadoutKeeper: LoadoutKeeper
	for lk in Level.loadout.keepers:
		if lk.peerId == peer_id and lk.deviceId == device_id:
			loadoutKeeper = lk
			break

	if is_instance_valid(loadoutKeeper):
		Level.loadout.keepers.erase(loadoutKeeper)
		if is_instance_valid(loadoutKeeper.keeper):
			keeper_removed.emit(loadoutKeeper.keeper)
