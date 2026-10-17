class_name Client
extends RefCounted

var connection_state: Network.ConnectionState
var peer_id: int
var data_changes: Dictionary = {}
var handshake_data: Dictionary = {}
var block_list: Dictionary = {}

func full_data_sync():
	var buffer: = var_to_bytes(Data.values)
	Network.chunker.send(peer_id, Chunker.ChunkRequestType.DATA_FULL_SYNC, Network.remote_full_data_sync.bind(buffer.size(), buffer.compress(FileAccess.CompressionMode.COMPRESSION_ZSTD)))

func sync_ticks(server_ticks: int) -> void :
	Network.remote_sync_ticks.rpc_id(peer_id, server_ticks)

func accept_handshake(server_ticks: int, crossplay: bool) -> void :
	Network.remote_accept_handshake.rpc_id(peer_id, server_ticks, crossplay)

func reject_handshake(reason: String) -> void :
	Network.remote_reject_handshake.rpc_id(peer_id, reason)

func server_disconnect() -> void :
	Network.remote_disconnect_client.rpc_id(peer_id)

func mods_mismatch(expected_mods: String) -> void :
	Network.remote_mods_mismatch.rpc_id(peer_id, expected_mods)

func session_ended() -> void :
	Network.remote_reject_due_game_end.rpc_id(peer_id)

func start_stage(stage: String, data: Array = []) -> void :
	Network.chunker.send(peer_id, Chunker.ChunkRequestType.START_STAGE, Network.remote_start_stage.bind(stage, data))

func set_map_data(map_data: Dictionary) -> void :
	var buffer: PackedByteArray = var_to_bytes(map_data)
	Network.chunker.send(peer_id, Chunker.ChunkRequestType.SET_MAP_DATA, Network.remote_set_map_data.bind(buffer.size(), buffer.compress(FileAccess.CompressionMode.COMPRESSION_ZSTD)))

func set_upgrade_data(upgrade_data: Dictionary) -> void :
	var buffer: PackedByteArray = var_to_bytes(upgrade_data)
	Network.chunker.send(peer_id, Chunker.ChunkRequestType.SET_UPGRADE_DATA, Network.remote_set_upgrade_data.bind(buffer.size(), buffer.compress(FileAccess.CompressionMode.COMPRESSION_ZSTD)))

func set_landmark_data(biomes: Array, chamber_placements: Dictionary, cave_placements: Dictionary) -> void :
	Network.chunker.send(peer_id, Chunker.ChunkRequestType.SET_LANDMARK_DATA, Network.remote_set_landmark_data.bind(biomes, chamber_placements, cave_placements))

func set_gadgets(gadgets: Dictionary) -> void :
	Network.chunker.send(peer_id, Chunker.ChunkRequestType.SET_GADGETS, Network.remote_set_gadgets.bind(gadgets))

func set_tile_state_data(tile_state_data: PackedByteArray) -> void :
	Network.chunker.send(peer_id, Chunker.ChunkRequestType.SET_TILE_STATE_DATA, Network.remote_set_tile_state_data.bind(tile_state_data))

func set_chamber_ids(chamber_ids: Dictionary) -> void :
	Network.remote_set_chamber_ids.rpc_id(peer_id, chamber_ids)

func isInDeviceSelectionScreen() -> bool:
	return connection_state in [Network.ConnectionState.DEVICE_SELECTION_CLIENT_ONLY, 
		Network.ConnectionState.DEVICE_SELECTION_STAGE_SPAWN, 
		Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC]

func show_crossplay_system_popup() -> void :
	Network.remote_show_crossplay_system_popup.rpc_id(peer_id)
