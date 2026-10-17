class_name GoblinsSynchronizer
extends Synchronizer


var holes: Dictionary = {}
var holes_by_tile: Dictionary = {}
var goblins: Goblins


func _ready() -> void :
	super._ready()
	goblins = owner

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	var spawn_entrance_hole: = is_instance_valid(goblins.entrance_hole)
	stream.encode_bool(spawn_entrance_hole)

	stream.encode_u16(holes.size())
	for hole: GoblinHole in holes.values():
		var hole_state: = hole.to_bytes()
		stream.encode_u16(hole_state.size())

		stream.encode_u32(hole.UID)
		var coord: Vector2 = Level.map.getTileCoord(hole.global_position)
		stream.encode_s16(int(coord.x))
		stream.encode_s16(int(coord.y))
		stream.encode_u8(Utils.encode_player_id(hole.playerId))
		stream.append_array(hole.to_bytes())

	stream.encode_u16(goblins.all_goblins.size())
	for goblin: Goblin in goblins.all_goblins:
		stream.encode_u32(goblin.UID)
		stream.encode_bool(goblin.is_squad_goblin)
		stream.encode_u8(Utils.encode_player_id(goblin.playerId))
		var goblin_state: = goblin.to_bytes()
		stream.encode_u16(goblin_state.size())
		stream.append_array(goblin_state)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	if stream.decode_bool():
		goblins._spawn_entrance_hole()

	var hole_count: = stream.decode_u16()
	for _i in range(hole_count):
		var state_size: = stream.decode_u16()
		var uid: = stream.decode_u32()
		var x: = stream.decode_s16()
		var y: = stream.decode_s16()
		var playerId: = Utils.decode_player_id(stream.decode_u8())

		var hole: = goblins.server_spawn_hole(playerId, Level.map.getTilePos(Vector2(x, y)), uid)
		holes[uid] = hole
		holes_by_tile[Level.map.getTileCoord(hole.global_position)] = hole

		hole.from_bytes(stream.slice(state_size).data)

	var goblin_count: = stream.decode_u16()
	for _i in range(goblin_count):
		var uid: = stream.decode_u32()
		var is_squad_goblin: = stream.decode_bool()
		var playerId: = Utils.decode_player_id(stream.decode_u8())
		var state_size: = stream.decode_u16()
		goblins.server_spawn_goblin(playerId, uid, is_squad_goblin, stream.slice(state_size).data)

func get_full_sync_data(peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_u16(goblins.all_goblins.size())
	for goblin: Goblin in goblins.all_goblins:
		stream.encode_u32(goblin.UID)
		var goblin_state: = goblin.to_bytes()
		stream.encode_u16(goblin_state.size())
		stream.append_array(goblin_state)

	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var goblin_count: = stream.decode_u16()
	for _i in range(goblin_count):
		var uid: = stream.decode_u32()
		var state_size: = stream.decode_u16()
		var state_data: = stream.slice(state_size).data
		var goblin: Goblin = goblins.goblins_by_uid.get(uid)
		if not is_instance_valid(goblin):
			continue

		goblin.from_bytes(state_data)


@rpc("reliable", "any_peer")
func trigger_squad(player_id: int, hole_UID: int) -> void :
	if holes.has(hole_UID):
		goblins._on_squad_triggered(Utils.decode_player_id(player_id), holes[hole_UID])

func network_spawn_goblin(goblin: Goblin) -> void :
	var stream: = PackedByteStream.new()
	stream.encode_u32(goblin.UID)
	stream.encode_bool(goblin.is_squad_goblin)
	stream.encode_u8(Utils.encode_player_id(goblin.playerId))
	stream.append_array(goblin.to_bytes())

	network_rpc(spawn_goblin_from_bytes.bind(stream.data))

@rpc("reliable")
func spawn_goblin_from_bytes(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var uid: = stream.decode_u32()
	var is_squad_goblin: = stream.decode_bool()
	var playerId: = Utils.decode_player_id(stream.decode_u8())
	goblins.server_spawn_goblin(playerId, uid, is_squad_goblin, stream.remaining())

func network_update_goblin(goblin: Goblin) -> void :
	var stream: = PackedByteStream.new()
	stream.encode_u32(goblin.UID)
	stream.append_array(goblin.to_bytes())
	network_rpc(update_goblin.bind(stream.data))

@rpc("reliable")
func update_goblin(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var uid: = stream.decode_u32()
	var goblin: Goblin = goblins.goblins_by_uid.get(uid)
	if not is_instance_valid(goblin):
		return

	goblin.from_bytes(stream.remaining())

func network_free_goblin(goblin: Goblin) -> void :
	network_rpc(free_goblin.bind(goblin.UID))

@rpc("reliable")
func free_goblin(uid: int) -> void :
	var goblin: Goblin = goblins.goblins_by_uid.get(uid)
	if is_instance_valid(goblin):
		goblin.queue_free()

func network_spawn_hole(hole: GoblinHole) -> void :
	var coord: Vector2i = Level.map.getTileCoord(hole.global_position)
	holes[hole.UID] = hole
	holes_by_tile[Level.map.getTileCoord(hole.global_position)] = hole
	hole.tree_exiting.connect(on_hole_tree_exiting.bind(hole))

	if not multiplayer.is_server():
		hole.hole_punched.connect(on_client_hole_punched.bind(hole))
		rpc_server(client_register_hole.bind(hole.playerId, hole.UID, coord))

	else:
		var stream: = PackedByteStream.new()
		stream.encode_u32(hole.UID)
		stream.encode_s16(coord.x)
		stream.encode_s16(coord.y)
		stream.encode_u8(Utils.encode_player_id(hole.playerId))
		stream.append_array(hole.to_bytes())
		hole.state_updated.connect(on_hole_state_updated.bind(hole))
		hole.vines_updated.connect(on_hole_vines_updated.bind(hole))
		network_rpc(spawn_hole_from_bytes.bind(stream.data))

@rpc("reliable", "any_peer")
func client_register_hole(playerId: String, uid: int, coord: Vector2i) -> void :

	if holes_by_tile.get(coord, null) != null:
		return

	goblins.spawn_hole(playerId, Level.map.getTilePos(Vector2(coord)), uid)

@rpc("reliable")
func spawn_hole_from_bytes(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var hole: GoblinHole
	var uid: int = stream.decode_u32()
	var coord: Vector2i = Vector2i(stream.decode_s16(), stream.decode_s16())
	var playerId: = Utils.decode_player_id(stream.decode_u8())

	var same_uid: bool = false

	if holes_by_tile.has(coord):

		hole = holes_by_tile[coord]
		if hole.UID == uid:
			same_uid = true
		else:
			hole.UID = uid

	else:
		hole = goblins.server_spawn_hole(playerId, Level.map.getTilePos(Vector2(coord)), uid)
		holes[uid] = hole
		holes_by_tile[Level.map.getTileCoord(hole.global_position)] = hole

	hole.from_bytes(stream.remaining(), same_uid)

@rpc("reliable")
func network_update_hole(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var uid: int = stream.decode_u32()
	if holes.has(uid):
		holes[uid].from_bytes(stream.remaining(), true)

@rpc("reliable")
func network_update_vines(uid: int) -> void :
	if holes.has(uid):
		holes[uid]._update_vine_height()

func on_client_hole_punched(hole: GoblinHole) -> void :
	rpc_server(client_punch_hole.bind(hole.UID))

@rpc("reliable", "any_peer")
func client_punch_hole(uid: int) -> void :
	if not holes.has(uid):
		return

	holes[uid].receive_punch()
	var stream: = PackedByteStream.new()
	stream.encode_u32(uid)
	stream.append_array(holes[uid].to_bytes())
	network_rpc(network_update_hole.bind(stream.data))

func on_hole_state_updated(hole: GoblinHole) -> void :
	var stream: = PackedByteStream.new()
	stream.encode_u32(hole.UID)
	stream.append_array(hole.to_bytes())
	network_rpc(network_update_hole.bind(stream.data))

func on_hole_vines_updated(hole: GoblinHole) -> void :
	network_rpc(network_update_vines.bind(hole.UID))

func on_hole_tree_exiting(hole: GoblinHole) -> void :
	holes.erase(hole.UID)
	if is_instance_valid(Level.map):
		holes_by_tile.erase(Level.map.getTileCoord(hole.global_position))

func get_goblin_hole(uid: int) -> GoblinHole:
	return holes.get(uid, null)

func register_hole(goblin_hole: GoblinHole) -> void :
	holes[goblin_hole.UID] = goblin_hole
	holes_by_tile[Level.map.getTileCoord(goblin_hole.global_position)] = goblin_hole
