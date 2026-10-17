class_name LevelKeeperSpawner
extends Node

signal keeper_removed(keeper: Keeper)
signal spawned(keeper: Keeper)
signal initial_spawned

func network_spawn(buffer: PackedByteArray):
	spawn_from_bytes(buffer)
	for client in Network.clients:
		if client.connection_state == Network.ConnectionState.LEVEL_STAGE_SPAWN or client.connection_state == Network.ConnectionState.LEVEL_STAGE_SYNC:
			spawn_from_bytes.rpc_id(client.peer_id, buffer)

@rpc("reliable")
func spawn_from_bytes(buffer: PackedByteArray):
	var lk = LoadoutKeeper.from_bytes(buffer)
	var scenes = GameWorld.addUpgrade(lk.keeperId, lk.playerId)
	lk.keeper = scenes["keeper"]
	lk.keeper.peerId = lk.peerId
	lk.keeper.position = lk.position
	lk.keeper.deviceId = lk.deviceId
	lk.keeper.teamId = lk.teamId
	lk.keeper.playerId = lk.playerId
	lk.keeper.playerName = lk.playerName
	lk.keeper.name = lk.playerId
	lk.keeper.remapColorIdPerPalette = lk.remapColorIdPerPalette
	lk.keeper.tutorialsActive = lk.tutorialsActive
	lk.keeper.setSkin(lk.skinId, lk.colorId)
	for tb in lk.temporaryBuffs:
		lk.keeper.temporaryBuffs.append(tb.duplicate())

	Keepers.registerKeeper(lk.keeper)
	Level.loadout.keepers.append(lk)
	Data.apply(lk.playerId + ".keeper.zoominmine", 4)


	if multiplayer.is_server():
		for team_id in GameWorld.addedGadgetIds.keys():
			if team_id != lk.teamId:
				continue
			for gadget_id: String in GameWorld.addedGadgetIds[team_id]:
				var gadget_id_split: = gadget_id.split(".")
				var teamOrPlayerId: = gadget_id_split[0]
				if teamOrPlayerId != lk.playerId:
					continue
				var base_id: = gadget_id_split[1]
				if Data.gadgets[base_id].get("takeslots", []).has("keepersuit"):
					var upgrade_data: Dictionary = GameWorld.upgrades.get(gadget_id)
					var gadget_scenes = upgrade_data.get("scenes", {})
					for slot in gadget_scenes:
						if slot != "keepersuit":
							continue
						var scene = load("res://" + gadget_scenes[slot])
						var instance = scene.instantiate()
						lk.keeper.addAddition(instance)

	spawned.emit(lk.keeper)

func spawn_initial(data: PackedByteArray):
	Level.loadout.keepers.clear()
	var buffer: = PackedByteStream.from_bytes(data)
	var to_spawn: int = buffer.decode_u8()
	for _i in range(to_spawn):
		var offset: int = buffer.decode_u8()
		spawn_from_bytes(buffer.slice(offset).data)
	initial_spawned.emit()
	Keepers.initial_keepers_spawned.emit()

func network_despawn(peer_id: int, device_id: int) -> void :
	despawn(peer_id, device_id)
	Network.rpc_for_states(despawn.bind(peer_id, device_id), [Network.ConnectionState.LEVEL_STAGE_SPAWN, Network.ConnectionState.LEVEL_STAGE_SYNC])

@rpc("reliable")
func despawn(peer_id: int, device_id: int) -> void :
	var loadoutKeeperToDespawn: LoadoutKeeper
	for lk: LoadoutKeeper in Level.loadout.keepers:
		var areAllDevicesAssignedToKeeper: bool = lk.deviceId == -1
		var isDeviceAssignedToKeeper: bool = areAllDevicesAssignedToKeeper or (lk.deviceId == device_id)
		var isDespawnKeeper: bool = (lk.peerId == peer_id) and isDeviceAssignedToKeeper
		if isDespawnKeeper:
			loadoutKeeperToDespawn = lk
			break

	if is_instance_valid(loadoutKeeperToDespawn):
		Level.loadout.keepers.erase(loadoutKeeperToDespawn)
		if is_instance_valid(loadoutKeeperToDespawn.keeper):
			keeper_removed.emit(loadoutKeeperToDespawn.keeper)
