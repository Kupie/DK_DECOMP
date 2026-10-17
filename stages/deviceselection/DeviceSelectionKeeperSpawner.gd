class_name DeviceSelectionKeeperSpawner
extends LoadoutKeeperSpawner

func get_sync_connection_state() -> Network.ConnectionState:
	return Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC

func get_spawn_connection_state() -> Network.ConnectionState:
	return Network.ConnectionState.DEVICE_SELECTION_STAGE_SPAWN
