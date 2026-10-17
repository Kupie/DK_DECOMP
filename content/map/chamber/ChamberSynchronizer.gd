class_name ChamberSynchronizer
extends Synchronizer

func _ready() -> void :
	super._ready()


	owner.hit.connect(on_chamber_hit)

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	var chamber: Chamber = owner
	stream.encode_u8(chamber.currentState)
	stream.encode_u8(chamber.additionalState)
	if not is_instance_valid(chamber.tileCover):
		stream.encode_u8(0)
		return stream.data

	var usedCells = chamber.tileCoords
	stream.encode_u8(usedCells.size())
	for c in usedCells:
		stream.encode_vector2(c)
		var v: = chamber.tileCover.get_cell_source_id(MapData.DEFAULT_LAYER, c)
		stream.encode_s32(v)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var chamber: Chamber = owner

	chamber.currentState = stream.decode_u8() as Chamber.State
	chamber.additionalState = stream.decode_u8()
	chamber.tileCover.clear()
	var size = stream.decode_u8()
	for i: int in range(size):
		var c: = stream.decode_vector2()
		var v: = stream.decode_s32()
		chamber.tileCover.set_cell(MapData.DEFAULT_LAYER, Vector2i(c.x, c.y), v, Vector2i.ZERO)

	chamber.onStateUpdated()

func get_full_sync_data(peer_id: int) -> PackedByteArray:
	return get_initial_data(peer_id)

func set_full_sync_data(buffer: PackedByteArray) -> void :
	set_initial_data(buffer)

func on_chamber_hit(keeper: Keeper) -> void :
	if not Network.is_server():
		rpc_server(request_chamber_hit.bind(keeper.playerId))
	else:
		network_rpc(remote_chamber_hit.bind(keeper.playerId), true)

@rpc("reliable", "any_peer")
func request_chamber_hit(playerId: String) -> void :
	var chamber: Chamber = owner
	if chamber.currentState != Chamber.State.OPEN:
		return

	network_rpc(remote_chamber_hit.bind(playerId), true)

@rpc("reliable")
func remote_chamber_hit(playerId: String) -> void :
	owner.registerHit(playerId)

func on_chamber_used() -> void :
	network_rpc(remote_chamber_used)

@rpc("reliable")
func remote_chamber_used():
	owner.onUsed()
