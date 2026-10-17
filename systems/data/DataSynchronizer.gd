class_name DataSynchronizer
extends Synchronizer

var changes_by_peer_id: Dictionary = {}

func prepare_data() -> void :

	if not Data.recently_changed.size():
		return

	for client in Network.clients:

		if not inital_syncs.has(client.peer_id):
			continue
		if not changes_by_peer_id.has(client.peer_id):
			changes_by_peer_id[client.peer_id] = {}

		for key in Data.recently_changed.keys():
			if not Data.values.has(key):
				continue
			changes_by_peer_id[client.peer_id][key] = Data.values[key]


	Data.recently_changed.clear()

func get_delta_data(peer_id: int) -> PackedByteArray:

	var changes: Dictionary = changes_by_peer_id.get(peer_id, {})
	if not changes.size():
		return PackedByteArray()

	changes_by_peer_id[peer_id] = {}
	return var_to_bytes(changes)

func set_delta_data(buffer: PackedByteArray) -> void :
	var values_delta: Dictionary = bytes_to_var(buffer)
	for key in values_delta.keys():
		Data.server_apply(key, values_delta[key])

func get_initial_data(_peer_id: int) -> PackedByteArray:
	return var_to_bytes(Data.values)

func set_initial_data(buffer: PackedByteArray) -> void :
	Data.values = bytes_to_var(buffer)

func on_network_tick(tick_counter: int) -> void :







	if paused:
		return

	if not is_multiplayer_authority():
		return

	_mark_tick()


	prepare_data()


	for client in Network.clients:
		if target_connection_states.has(client.connection_state):
			if inital_syncs.has(client.peer_id):
				var data: = get_delta_data(client.peer_id)
				if not data.size():
					continue

				Network.chunker.send(client.peer_id, Chunker.ChunkRequestType.DATA_DELTA_SYNC, remote_data_call.bind(tick_counter, data))
			else:

				var data: = get_initial_data(client.peer_id)
				if data.size():
					Network.chunker.send(client.peer_id, Chunker.ChunkRequestType.DATA_FULL_SYNC, _remote_set_initial_data.bind(tick_counter, data.size(), data.compress(FileAccess.CompressionMode.COMPRESSION_ZSTD)))
				inital_syncs.append(client.peer_id)
