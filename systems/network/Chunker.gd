class_name Chunker
extends Node

const MAX_CHUNK_SIZE: int = 900
const CHUNKS_PER_FRAME: int = 5

enum ChunkRequestType{
	DATA_FULL_SYNC, 
	DATA_DELTA_SYNC, 
	START_STAGE, 
	SET_MAP_DATA, 
	SET_UPGRADE_DATA, 
	SET_LANDMARK_DATA, 
	SET_GADGETS, 
	SET_TILE_STATE_DATA, 
	SET_CLIENT_BLOCK_LIST, 
	ASK_LOBBY_TO_ADD_NEW_LOCAL_KEEPER, 
	ADD_MOVEABLE_MEMBER, 
}

class OutgoingRPC:
	var request_id: int
	var request_type: ChunkRequestType
	var target_peer_id: int
	var chunks: Array[PackedByteArray]
	var current_chunk_index: int
	var total_chunks: int

	func _init(_request_id: int, _request_type: ChunkRequestType, _target_peer_id: int, _chunks: Array[PackedByteArray]) -> void :
		request_id = _request_id
		request_type = _request_type
		target_peer_id = _target_peer_id
		chunks = _chunks
		current_chunk_index = 0
		total_chunks = chunks.size()

	func is_sent() -> bool:
		return current_chunk_index == total_chunks

class IncomingRPC:
	var request_id: int
	var request_type: ChunkRequestType
	var sender_peer_id: int
	var received_chunks: Dictionary
	var total_chunks: int

	func _init(_request_id: int, _request_type: ChunkRequestType, _sender_peer_id: int, _total_chunks: int) -> void :
		request_id = _request_id
		request_type = _request_type
		sender_peer_id = _sender_peer_id
		total_chunks = _total_chunks
		received_chunks = {}

	func is_complete() -> bool:
		return received_chunks.size() == total_chunks

	func get_data() -> PackedByteArray:
		var buffer: PackedByteArray = PackedByteArray()
		for idx: int in range(total_chunks):
			buffer.append_array(received_chunks[idx])
		return buffer

	func finish() -> void :
		var args: Array = bytes_to_var(get_data())
		match request_type:
			ChunkRequestType.DATA_FULL_SYNC:
				Network.remote_full_data_sync.callv(args)
			ChunkRequestType.DATA_DELTA_SYNC:
				Data.synchronizer.remote_data_call.callv(args)
			ChunkRequestType.START_STAGE:
				Network.remote_start_stage.callv(args)
			ChunkRequestType.SET_MAP_DATA:
				Network.remote_set_map_data.callv(args)
			ChunkRequestType.SET_UPGRADE_DATA:
				Network.remote_set_upgrade_data.callv(args)
			ChunkRequestType.SET_LANDMARK_DATA:
				Network.remote_set_landmark_data.callv(args)
			ChunkRequestType.SET_GADGETS:
				Network.remote_set_gadgets.callv(args)
			ChunkRequestType.SET_TILE_STATE_DATA:
				Network.remote_set_tile_state_data.callv(args)
			ChunkRequestType.SET_CLIENT_BLOCK_LIST:
				Network.set_client_block_list.callv(args)
			ChunkRequestType.ASK_LOBBY_TO_ADD_NEW_LOCAL_KEEPER:
				if StageManager.isInLoadout():
					StageManager.currentStage._askLobbyToAddNewLocalKeeper.callv(args)
			ChunkRequestType.ADD_MOVEABLE_MEMBER:
				if StageManager.isInDeviceSelection():
					StageManager.currentStage.addMoveableMember.callv(args)

var request_counter: int = 0
var outgoing_rpcs: Dictionary = {}
var incoming_rpcs: Dictionary = {}

func send(target_peer_id: int, request_type: ChunkRequestType, callable: Callable) -> void :
	var args: Array = callable.get_bound_arguments()
	var data: PackedByteArray = var_to_bytes(args)


	if data.size() < MAX_CHUNK_SIZE:
		callable.rpc_id(target_peer_id)
		return


	var request_id: = _get_next_request_id()
	var chunks: Array[PackedByteArray] = []
	var total_size: = data.size()
	var chunk_count: = ceili(float(total_size) / float(MAX_CHUNK_SIZE))

	for chunk_idx: int in range(chunk_count):
		var start_pos: = chunk_idx * MAX_CHUNK_SIZE
		var end_pos: = mini(start_pos + MAX_CHUNK_SIZE, total_size)
		var chunk = data.slice(start_pos, end_pos)
		chunks.append(chunk)

	print("Sending large data in %d chunks (total size: %d bytes) for method: %s, request: %s, type: %s" %\
	[chunk_count, total_size, callable.get_method(), request_id, _get_request_type_string(request_type)])

	var chunked: = OutgoingRPC.new(request_id, request_type, target_peer_id, chunks)
	outgoing_rpcs[request_id] = chunked

@rpc("reliable", "any_peer")
func receive(request_id: int, request_type: int, chunk_index: int, total_chunks: int, chunk: PackedByteArray) -> void :
	if multiplayer.is_server():
		match request_type as ChunkRequestType:
			[ChunkRequestType.SET_CLIENT_BLOCK_LIST, ChunkRequestType.ASK_LOBBY_TO_ADD_NEW_LOCAL_KEEPER, ChunkRequestType.ADD_MOVEABLE_MEMBER]:
				return

	if not incoming_rpcs.has(request_id):

		incoming_rpcs[request_id] = IncomingRPC.new(request_id, request_type as ChunkRequestType, multiplayer.get_remote_sender_id(), total_chunks)

	var request: IncomingRPC = incoming_rpcs[request_id]
	request.received_chunks[chunk_index] = chunk
	if request.is_complete():
		request.finish()
		incoming_rpcs.erase(request_id)

func _process(_delta: float) -> void :
	if not outgoing_rpcs.size():
		return

	var chunks_sent: int = 0
	var finished_requests: Array[int] = []
	for request_id: int in outgoing_rpcs.keys():
		if chunks_sent >= CHUNKS_PER_FRAME:
			break

		var request: OutgoingRPC = outgoing_rpcs[request_id]
		if request.current_chunk_index >= request.total_chunks:
			finished_requests.append(request_id)
			continue

		for _idx in range(request.current_chunk_index, request.total_chunks + 1):
			if chunks_sent >= CHUNKS_PER_FRAME:
				break

			receive.rpc_id(request.target_peer_id, request_id, int(request.request_type), request.current_chunk_index, request.total_chunks, request.chunks[request.current_chunk_index])
			request.current_chunk_index += 1

			chunks_sent += 1


			if request.current_chunk_index >= request.total_chunks:
				finished_requests.append(request_id)
				break

	for request_id: int in finished_requests:
		outgoing_rpcs.erase(request_id)

func _get_next_request_id() -> int:
	request_counter += 1
	return request_counter

func _get_request_type_string(request_type: ChunkRequestType) -> String:
	match request_type:
		ChunkRequestType.DATA_FULL_SYNC:
			return "Full Data Sync"
		ChunkRequestType.DATA_DELTA_SYNC:
			return "Delta Data Sync"
		ChunkRequestType.START_STAGE:
			return "Start Stage"
		ChunkRequestType.SET_MAP_DATA:
			return "Set Map Data"
		ChunkRequestType.SET_UPGRADE_DATA:
			return "Set Upgrade Data"
		ChunkRequestType.SET_LANDMARK_DATA:
			return "Set Landmark Data"
		ChunkRequestType.SET_GADGETS:
			return "Set Gadgets"
		ChunkRequestType.SET_TILE_STATE_DATA:
			return "Set Tile State Data"
		ChunkRequestType.SET_CLIENT_BLOCK_LIST:
			return "Set Client Block List"
		ChunkRequestType.ASK_LOBBY_TO_ADD_NEW_LOCAL_KEEPER:
			return "Ask Lobby To Add New Local Keeper"
		ChunkRequestType.ADD_MOVEABLE_MEMBER:
			return "Add Moveable Member"

	return "Invalid Request Type"

func reset() -> void :
	request_counter = 0
	outgoing_rpcs.clear()
	incoming_rpcs.clear()
