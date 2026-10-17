class_name DropSynchronizer
extends Synchronizer

const DELTA_STREAM_SIZE: = 15
const MAX_DROP_SYNCS_PER_PEER_PER_FRAME: = 32
const MAX_ACKNOWLEDGED_DROP_SYNCS_PER_PEER_PER_FRAME: = 32

signal drop_spawned(drop: Carryable)
signal bundle_spawned(bundle: Bundle)
signal carrier_spawned(bundle: KunaiCarrier)
signal drop_picked_up(drop: Carryable, keeper: Keeper)

var drops: Dictionary = {}
var bundles: Dictionary = {}
var carriers: Dictionary = {}
var current_drop_index_by_peer: = {}
var forced_visible_drops: = {}



var _acknowledged_rpc_server_side: AcknowledgedRpc
var _drops_to_acknowledged_sync: Dictionary = {

}
var _peers_visibility_update_tick: Dictionary = {

}
var _server_perspective_prev_peer_drops_visibility = {



}
var _peer_perspective_drop_visibility = {



}
var _prev_peer_perspective_drop_visibility = {



}
var _last_sync_at_frame: Dictionary = {

}

var _last_sync_translation: Dictionary = {

}



var _acknowledged_rpc_client_side: AcknowledgedRpc
var _drop_network_data: Dictionary = {




}

var _drop_data_queue: Dictionary = {

}
var _last_time_aprox_visibility: Dictionary = {

}

var _nearby_drops: Dictionary = {

}

func _ready() -> void :
	super._ready()
	Network.client_ready.connect(_on_network_client_ready)
	multiplayer.peer_connected.connect(_on_network_client_ready)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	_acknowledged_rpc_server_side = AcknowledgedRpc.new()
	_acknowledged_rpc_client_side = AcknowledgedRpc.new()
	_acknowledged_rpc_server_side.name = "acknowledged_rpc_server_side"
	_acknowledged_rpc_client_side.name = "_acknowledged_rpc_client_side"
	add_child.bind(_acknowledged_rpc_server_side).call_deferred()
	add_child.bind(_acknowledged_rpc_client_side).call_deferred()

	for peer_id: int in multiplayer.get_peers():
		if multiplayer.get_unique_id() != peer_id:
			_prepare_data_for_peer(peer_id)

func _on_multiplayer_peer_connected(new_peer: int) -> void :
	_prepare_data_for_peer(new_peer)

func _on_network_client_ready(new_peer: int) -> void :
	_prepare_data_for_peer(new_peer)

func _prepare_data_for_peer(in_peer: int) -> void :
	if not _drops_to_acknowledged_sync.has(in_peer):
		_drops_to_acknowledged_sync[in_peer] = {}
	if not _peers_visibility_update_tick.has(in_peer):
		_peers_visibility_update_tick[in_peer] = {}
	if not _peer_perspective_drop_visibility.has(in_peer):
		_peer_perspective_drop_visibility[in_peer] = {}
	if not _server_perspective_prev_peer_drops_visibility.has(in_peer):
		_server_perspective_prev_peer_drops_visibility[in_peer] = {}
	if not _prev_peer_perspective_drop_visibility.has(in_peer):
		_prev_peer_perspective_drop_visibility[in_peer] = {}
	if not _last_sync_at_frame.has(in_peer):
		_last_sync_at_frame[in_peer] = {}
	if not _last_sync_translation.has(in_peer):
		_last_sync_translation[in_peer] = {}

func _on_multiplayer_peer_disconnected(in_peer: int) -> void :
	_drops_to_acknowledged_sync.erase(in_peer)
	_peers_visibility_update_tick.erase(in_peer)
	_peer_perspective_drop_visibility.erase(in_peer)
	_server_perspective_prev_peer_drops_visibility.erase(in_peer)
	_prev_peer_perspective_drop_visibility.erase(in_peer)
	_last_sync_at_frame.erase(in_peer)
	_last_sync_translation.erase(in_peer)


@rpc("unreliable")
func _unreliable_remote_set_data(tick_sent: int, buffer: PackedByteArray) -> void :
	server_tick = tick_sent
	set_delta_data(buffer)
	_mark_tick()


func get_delta_data(peer_id: int) -> PackedByteArray:
	assert (is_multiplayer_authority())
	if not current_drop_index_by_peer.has(peer_id):
		current_drop_index_by_peer[peer_id] = 0

	var available_sync_slots: int = MAX_DROP_SYNCS_PER_PEER_PER_FRAME
	var stream: = PackedByteStream.new()
	var active_drops: Array = []

	var local_keepers: = Keepers.get_peer(peer_id).getAll()
	var server_perspective_nearby_drops_list: Array[Carryable] = []
	for keeper: Keeper in local_keepers:
		var visible_rect: Rect2 = Network.get_visible_rect_by_keeper(keeper)
		var nearby_objects: Array = Proximiter.estimate_objects_in_area(visible_rect, ProximityProxy.Group.CARRYABLE)
		server_perspective_nearby_drops_list.append_array(nearby_objects)

	var server_perspective_drops_near_peer: Dictionary = {}
	for drop in server_perspective_nearby_drops_list:
		server_perspective_drops_near_peer[drop.UID] = drop
	var drops_to_process: Array[Carryable] = server_perspective_nearby_drops_list
	for drop_uid: int in _peer_perspective_drop_visibility[peer_id]:
		if not server_perspective_drops_near_peer.has(drop_uid):
			drops_to_process.append(_peer_perspective_drop_visibility[peer_id][drop_uid])

	for drop: Carryable in drops_to_process:
		if not is_instance_valid(drop) or not drop.is_inside_tree():
			continue

		var server_perspective_drop_become_visible_for_peer: bool = not _server_perspective_prev_peer_drops_visibility[peer_id].has(drop.UID)\
		and server_perspective_drops_near_peer.has(drop.UID)
		var peer_perspective_just_become_visible: bool = not _prev_peer_perspective_drop_visibility[peer_id].has(drop.UID)\
		and _peer_perspective_drop_visibility[peer_id].has(drop.UID)
		if server_perspective_drop_become_visible_for_peer or peer_perspective_just_become_visible:
			_drops_to_acknowledged_sync[peer_id][drop.UID] = true
			continue

		if not _last_sync_translation[peer_id].has(drop.UID):
			_last_sync_translation[peer_id][drop.UID] = drop.sync_transform.origin
		var transform_delta: float = drop.sync_transform.origin.distance_squared_to(_last_sync_translation[peer_id][drop.UID])
		const half_a_pixel_sqr: float = 0.5 * 0.5
		var drop_still: bool = drop.sleeping or (transform_delta < half_a_pixel_sqr)
		if drop_still:
			continue
		active_drops.append(drop)
	var drop_sync_count: int = min(active_drops.size(), available_sync_slots)
	var can_serve_all_drops_through_one_rpc: bool = active_drops.size() <= drop_sync_count
	if not can_serve_all_drops_through_one_rpc:
		active_drops.sort_custom(_oldest_fastest_sync_first.bind(peer_id))

	_prev_peer_perspective_drop_visibility = _peer_perspective_drop_visibility.duplicate()
	_server_perspective_prev_peer_drops_visibility[peer_id] = server_perspective_drops_near_peer

	stream.encode_u32(server_tick)
	stream.encode_u16(active_drops.size())
	stream.encode_u16(drop_sync_count)
	available_sync_slots -= drop_sync_count

	var updated_now_drops_uids: = {}
	if can_serve_all_drops_through_one_rpc:
		for drop in active_drops:
			stream.append_array(pack_delta_data(drop))
			updated_now_drops_uids[drop.UID] = true
			_last_sync_at_frame[peer_id][drop.UID] = server_tick
			_last_sync_translation[peer_id][drop.UID] = drop.sync_transform.origin
	else:
		var idx_drop: = 0
		while idx_drop < active_drops.size():
			if idx_drop < drop_sync_count:
				if current_drop_index_by_peer[peer_id] >= active_drops.size():
					current_drop_index_by_peer[peer_id] = 0

				var drop = active_drops[current_drop_index_by_peer[peer_id]]
				stream.append_array(pack_delta_data(drop))
				_last_sync_translation[peer_id][drop.UID] = drop.sync_transform.origin
				current_drop_index_by_peer[peer_id] += 1
				updated_now_drops_uids[drop.UID] = true
				_last_sync_at_frame[peer_id][drop.UID] = server_tick
			idx_drop += 1
	var active_bundles: Array[Bundle] = []
	for bundle in bundles.values():
		if not is_instance_valid(bundle):
			continue
		active_bundles.append(bundle)

	if active_bundles.is_empty() and active_drops.is_empty():
		return PackedByteArray()

	stream.encode_u16(active_bundles.size())
	for bundle in active_bundles:
		stream.encode_u32(bundle.UID)
		stream.encode_vector2(bundle.center)

	return stream.data

func _oldest_fastest_sync_first(a: Carryable, b: Carryable, peer_id: int) -> bool:
	var peer_keepers = Keepers.get_peer(peer_id).getAll()
	var is_a_carried_by_peer: bool = false
	var is_b_carried_by_peer: bool = false
	var a_last_sync_at_frame: int = _last_sync_at_frame[peer_id].get(a, 0)
	var b_last_sync_at_frame: int = _last_sync_at_frame[peer_id].get(b, 0)
	for keeper: Keeper in peer_keepers:
		is_a_carried_by_peer = is_a_carried_by_peer or a.isCarriedBy(keeper)
		is_b_carried_by_peer = is_b_carried_by_peer or a.isCarriedBy(keeper)

	if is_a_carried_by_peer and is_b_carried_by_peer:
		return a_last_sync_at_frame < b_last_sync_at_frame
	if is_a_carried_by_peer:
		return true
	if is_b_carried_by_peer:
		return false

	var a_velocity: float = a.sync_linear_velocity.length()
	var b_velocity: float = b.sync_linear_velocity.length()
	var ab_velocity_delta: float = a_velocity - b_velocity
	const max_speed_diff: float = 50.0
	const priority_diff_at_max_speed_diff: float = 10.0
	var diff_ratio: float = ab_velocity_delta / max_speed_diff
	var clamped_priority_change_int: int = roundi(lerp(0.0, priority_diff_at_max_speed_diff, diff_ratio))
	clamped_priority_change_int = clampi(clamped_priority_change_int, - int(priority_diff_at_max_speed_diff), int(priority_diff_at_max_speed_diff))


	a_last_sync_at_frame -= clamped_priority_change_int
	return a_last_sync_at_frame < b_last_sync_at_frame

func _can_peer_see_drop(in_peer: int, in_drop: Carryable) -> bool:
	assert (is_multiplayer_authority())
	return _peer_perspective_drop_visibility[in_peer].has(in_drop.UID) or _server_perspective_prev_peer_drops_visibility[in_peer].has(in_drop.UID)

func _check_different_keys(in_dict1: Dictionary, in_dict2: Dictionary) -> bool:
	for key1 in in_dict1:
		if in_dict2.has(key1):
			return false
	return true


func set_delta_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var current_tick: int = stream.decode_u32()
	var desired_sync_count: int = stream.decode_u16()
	var drop_count: int = stream.decode_u16()
	for _i in range(drop_count):
		unpack_delta_data(stream.slice(DELTA_STREAM_SIZE).data, current_tick, desired_sync_count)

	var bundle_count: int = stream.decode_u16()
	for _i in range(bundle_count):
		var uid: int = stream.decode_u32()
		if bundles.has(uid) and is_instance_valid(bundles[uid]):
			bundles[uid].center = stream.decode_vector2()
			var delta: = Engine.time_scale / Engine.physics_ticks_per_second
			bundles[uid].run_process(delta)

func _physics_process(delta: float) -> void :
	if multiplayer.is_server():
		set_physics_process(false)
		return
	_process_client_physics(delta)

func _process_client_physics(delta: float) -> void :
	for drop in _nearby_drops.values():
		if is_instance_valid(drop) and drop.is_inside_tree():
			drop._clientPhysics(delta)


func on_network_tick(tick_counter: int) -> void :
	super.on_network_tick(tick_counter)
	if StageManager.isSwitchingStage():
		return
	if paused:
		return
	if is_multiplayer_authority():
		assert (_drop_data_queue.is_empty())
		_update_acknowledged_rpc(tick_counter)
		return

	_acknowledged_rpc_client_side.update()
	_sync_newly_visible_drops()
	_apply_queue_data()

func _update_acknowledged_rpc(tick_counter: int) -> void :
	assert (is_multiplayer_authority())
	_acknowledged_rpc_server_side.update()
	for client: Client in Network.clients:
		if target_connection_states.has(client.connection_state):
			if inital_syncs.has(client.peer_id):
				var payload: = _get_acknowledged_delta_data(client.peer_id, tick_counter)
				if payload.size() > 0:
					var callable: Callable = _set_data_require_acknowledgment.bind(payload)
					_acknowledged_rpc_server_side.push_acknowledged_message(client.peer_id, callable)

func _get_acknowledged_delta_data(peer_id: int, server_tick: int) -> PackedByteArray:
	assert (is_multiplayer_authority())
	if not _drops_to_acknowledged_sync.has(peer_id):

		return PackedByteArray()

	var drops_to_sync: Array = _drops_to_acknowledged_sync[peer_id].keys()
	if drops_to_sync.is_empty():
		return PackedByteArray()
	var nmb_acknowledged_drops_sync: int = min(drops_to_sync.size(), MAX_ACKNOWLEDGED_DROP_SYNCS_PER_PEER_PER_FRAME)
	if nmb_acknowledged_drops_sync == 0:
		return PackedByteArray()
	var stream: = BitPackedByteStream.new()
	stream.encode_u32(server_tick)
	stream.encode_u16(drops_to_sync.size())
	stream.encode_u16(nmb_acknowledged_drops_sync)
	for i in nmb_acknowledged_drops_sync:
		var uid = drops_to_sync[i]
		_drops_to_acknowledged_sync[peer_id].erase(uid)
		if not drops.has(uid):
			continue
		var drop: Carryable = drops[uid]
		stream.append_array(pack_delta_data(drop))
		if not _last_sync_translation[peer_id].has(drop.UID):
			_last_sync_translation[peer_id][drop.UID] = {}
		_last_sync_translation[peer_id][drop.UID] = drop.sync_transform.origin
	return stream.data

@rpc("any_peer", "call_remote", "unreliable")
func _set_data_require_acknowledgment(in_packet_id: int, buffer: PackedByteArray) -> void :
	assert ( not is_multiplayer_authority())
	_set_acknowledged_data(buffer)
	_acknowledged_rpc_server_side.acknowledge_sender(in_packet_id)

func _set_acknowledged_data(buffer: PackedByteArray) -> void :
	if buffer.is_empty():
		return
	var stream: = BitPackedByteStream.from_bytes(buffer)
	var current_tick: int = stream.decode_u32()
	var desired_sync_count: int = stream.decode_u16()
	var drop_count: int = stream.decode_u16()
	for _i in range(drop_count):
		var stream2: = BitPackedByteStream.from_bytes(stream.slice(DELTA_STREAM_SIZE).data)
		var UID: = stream2.unpack_bits(UID_BIT_SIZE)
		if not drops.has(UID):

			_drop_data_queue[UID] = [stream2.data.duplicate(), current_tick]
			continue
		var last_tick: int = _drop_network_data[UID].get("last_server_tick", current_tick)
		if last_tick > current_tick:
			continue
		_drop_network_data[UID]["last_server_tick"] = current_tick

		var rotation: = stream2.unpack_rotation(ROTATION_BIT_SIZE)
		var x_position: = stream2.unpack_signed_float(POSITION_BIT_SIZE, POSITION_FACTOR)
		var y_position: = stream2.unpack_unsigned_float(POSITION_BIT_SIZE, POSITION_FACTOR, Y_POSITION_SHIFT)
		var x_velocity: = stream2.unpack_signed_float(VELOCITY_BIT_SIZE, VELOCITY_FACTOR)
		var y_velocity: = stream2.unpack_signed_float(VELOCITY_BIT_SIZE, VELOCITY_FACTOR)
		var sleeping: = stream2.unpack_bit()
		var transform: = Transform2D(rotation, Vector2(x_position, y_position))
		var linear_velocity: = Vector2(x_velocity, y_velocity)
		var drop: Carryable = drops[UID]
		var visible_locally: bool = false
		var local_keepers: Array = Keepers.local.getAll()
		for keeper: Keeper in local_keepers:
			visible_locally = visible_locally or Network.is_point_visible_by_keeper(transform.origin, keeper)

		if not sleeping and visible_locally:
			drop.applySyncData(current_tick, transform, linear_velocity, desired_sync_count)
		else:
			drop.applySyncData(current_tick, transform, linear_velocity, desired_sync_count)
			drop.transform = transform
			drop.clearSyncBuffer()

func _sync_newly_visible_drops() -> void :
	assert ( not is_multiplayer_authority())
	_nearby_drops.clear()
	var drops_to_request: PackedInt32Array = PackedInt32Array()
	var local_keepers: = Keepers.local.getAll()
	for keeper: Keeper in local_keepers:
		var visible_rect: Rect2 = Network.get_visible_rect_by_keeper(keeper)
		var nearby_objects: Array = Proximiter.estimate_objects_in_area(visible_rect, ProximityProxy.Group.CARRYABLE)
		for drop: Carryable in nearby_objects:
			_nearby_drops[drop.UID] = drop

	var near_drops: Array = _nearby_drops.values()
	for drop: Carryable in near_drops:
		var is_visible_now: bool = true
		var uid: int = drop.UID
		var drop_data: Dictionary = _drop_network_data[uid]
		var has_been_visible_already: bool = _last_time_aprox_visibility.erase(uid)
		var just_become_visible = not has_been_visible_already
		drop_data["visible"] = is_visible_now
		if just_become_visible:
			drops_to_request.append(uid)
		if is_visible_now:
			drop.visible = not drop.forceHide

	for drop_uid: int in _last_time_aprox_visibility:

		var drop: Carryable = drops[drop_uid]
		var drop_data: Dictionary = _drop_network_data[drop_uid]
		drop_data["visible"] = false
		drops_to_request.append(drop.UID)
		drop.hide()

	_last_time_aprox_visibility.clear()
	for drop: Carryable in near_drops:
		_last_time_aprox_visibility[drop.UID] = true

	if drops_to_request.size() == 0:
		return

	var stream: = BitPackedByteStream.new()
	stream.encode_u16(drops_to_request.size())
	for uid: int in drops_to_request:
		var is_visible: bool = _drop_network_data[uid]["visible"]
		var tick: int = _drop_network_data[uid].get("last_server_tick", 0)
		stream.pack_bits(uid, UID_BIT_SIZE)
		stream.encode_bool(is_visible)
		stream.encode_vector2(drops.get(uid).global_position)
		stream.encode_u32(tick)
	_acknowledged_rpc_client_side.push_acknowledged_message(1, _update_peer_drop_visibility.bind(multiplayer.get_unique_id(), stream.data))

@rpc("any_peer", "call_remote", "unreliable")
func _update_peer_drop_visibility(in_packet_id: int, peer_id: int, bytes: PackedByteArray) -> void :
	assert (is_multiplayer_authority())
	_acknowledged_rpc_client_side.acknowledge_sender(in_packet_id)
	var stream: BitPackedByteStream = BitPackedByteStream.from_bytes(bytes)
	var nmb_of_drops: int = stream.decode_u16()
	for drop_idx in nmb_of_drops:
		var drop_uid: int = stream.unpack_bits(UID_BIT_SIZE)
		if not drops.has(drop_uid):

			Logger.warn("Client requests drop uid update, but server does not have it, this is normal if not often for the same uid: " + str(drop_uid), "DropSynchronizer._update_peer_drop_visibility")
			continue

		var new_drop_visibility_status: bool = stream.decode_bool()
		var drop_client_position: Vector2 = stream.decode_vector2()
		var packet_tick: int = stream.decode_u32()
		if not _peers_visibility_update_tick[peer_id].has(drop_uid):
			_peers_visibility_update_tick[peer_id][drop_uid] = packet_tick - 1
		if packet_tick < _peers_visibility_update_tick[peer_id][drop_uid]:
			continue
		if new_drop_visibility_status:
			_peer_perspective_drop_visibility[peer_id][drop_uid] = drops[drop_uid]
		else:
			_peer_perspective_drop_visibility[peer_id].erase(drop_uid)
		_peers_visibility_update_tick[peer_id][drop_uid] = packet_tick
		if new_drop_visibility_status:
			var server_drop_position: Vector2 = drops[drop_uid].global_position
			var need_to_sync: = drop_client_position.distance_squared_to(server_drop_position) > 0.001
			if need_to_sync:
				_drops_to_acknowledged_sync[peer_id][drop_uid] = true

func _apply_queue_data() -> void :
	if _drop_data_queue.is_empty():
		return

	var served_data: = PackedInt32Array()
	for drop_UID: int in _drop_data_queue:
		var stream = BitPackedByteStream.new()
		stream.data = _drop_data_queue[drop_UID][0]
		var update_server_tick: int = _drop_data_queue[drop_UID][1]
		var UID: = stream.unpack_bits(UID_BIT_SIZE)
		if not drops.has(UID):
			continue
		var last_tick: int = _drop_network_data[UID].get("last_server_tick", 0)
		if last_tick > update_server_tick:
			served_data.append(UID)
			continue
		_drop_network_data[UID]["last_server_tick"] = update_server_tick
		served_data.append(UID)
		var rotation: = stream.unpack_rotation(ROTATION_BIT_SIZE)
		var x_position: = stream.unpack_signed_float(POSITION_BIT_SIZE, POSITION_FACTOR)
		var y_position: = stream.unpack_unsigned_float(POSITION_BIT_SIZE, POSITION_FACTOR, Y_POSITION_SHIFT)
		var x_velocity: = stream.unpack_signed_float(VELOCITY_BIT_SIZE, VELOCITY_FACTOR)
		var y_velocity: = stream.unpack_signed_float(VELOCITY_BIT_SIZE, VELOCITY_FACTOR)
		var transform: = Transform2D(rotation, Vector2(x_position, y_position))
		var linear_velocity: = Vector2(x_velocity, y_velocity)
		var drop: Carryable = drops[UID]
		drop.applySyncData(update_server_tick, transform, linear_velocity, drops.size())
		drop.transform = transform

	for uid_to_remove in served_data:
		_drop_data_queue.erase(uid_to_remove)


func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_u16(drops.size())
	for drop: Carryable in drops.values():
		stream.encode_u16(drop.UID)
		var type_index: int = Data.DROP_TYPES.find(drop.type)
		stream.encode_u8(type_index)
		stream.encode_u8(int(drop.teamId.lstrip("team")))
		stream.encode_vector2(drop.position)
		stream.encode_vector2(Vector2.ZERO)
		stream.encode_float(drop.gravity_scale)
		stream.encode_float(drop.linear_damp)

		var keepers_carrying: Array[String] = []
		for carrier in drop.carriedBy:
			if is_instance_valid(carrier) and carrier is Keeper:
				keepers_carrying.append(carrier.playerId)

		stream.encode_u8(keepers_carrying.size())
		for c in keepers_carrying:
			stream.encode_u8(Utils.encode_player_id(c))

		stream.encode_bool(drop.has_method("get_initial_data"))
		if drop.has_method("get_initial_data"):
			stream.encode_var(drop.get_initial_data())

	var hidden: Array[Carryable] = []
	for drop: Carryable in drops.values():
		if not drop.visible:
			hidden.append(drop)

	stream.encode_u16(hidden.size())
	for drop in hidden:
		stream.encode_u16(drop.UID)

	stream.encode_u16(bundles.size())
	for bundle in bundles.values():
		if not is_instance_valid(bundle):
			continue
		stream.encode_u32(bundle.UID)
		stream.encode_u8(Utils.encode_player_id(bundle.playerId))
		stream.encode_vector2(bundle.direction)
		stream.encode_float(bundle.goalSpeed)
		stream.encode_bool(is_instance_valid(bundle.leaderNode))

		stream.encode_u16(bundle.carryInfluences.size())
		for carryInfluence: CarryInfluence in bundle.carryInfluences:
			stream.encode_u16(carryInfluence.carryable.UID)
			stream.encode_float(carryInfluence.strength)

	stream.encode_u16(carriers.size())
	for carrier: KunaiCarrier in carriers.values():
		stream.encode_u32(carrier.UID)
		stream.encode_vector2(carrier.global_position)
		stream.encode_u8(Utils.encode_player_id(carrier.playerId))
		stream.encode_u8(Utils.encode_team_id(carrier.teamId))
		stream.encode_u8(Utils.encode_player_id(carrier.ownerKeeperId))
		stream.encode_bool(carrier.attached)
		stream.encode_bool(carrier.chainHanging)
		stream.encode_float(carrier.gravity_multiplier)
		stream.encode_vector2(carrier.launch_direction)
		stream.encode_vector2(carrier.lastVelocity)
		stream.encode_vector2(carrier.linear_velocity)
		stream.encode_float(carrier.angular_velocity)
		if carrier.carriedCarryables.size() > 0:
			stream.encode_u16(carrier.carriedCarryables.size())
			for carryable: Carryable in carrier.carriedCarryables:
				stream.encode_u32(carryable.UID)
		else:
			stream.encode_u16(carrier._savedCarryableUids.size())
			for carryableUID: int in carrier._savedCarryableUids:
				stream.encode_u32(carryableUID)
		var anchor_coord: = Vector2.ZERO
		if carrier.anchorTile != null and is_instance_valid(carrier.anchorTile) and carrier.anchorTile is Tile:
			anchor_coord = (carrier.anchorTile as Tile).coord
		stream.encode_vector2(anchor_coord)
		var anchor_type: = ""
		var anchor_uid: = -1
		var anchor_node_path: = ""
		if carrier.anchorTile != null and is_instance_valid(carrier.anchorTile):
			if carrier.anchorTile is Tile:
				anchor_type = "tile"
			elif carrier.anchorTile is KunaiCarrier:
				anchor_type = "carrier"
				anchor_uid = (carrier.anchorTile as KunaiCarrier).UID
			elif carrier.anchorTile is Carryable:
				anchor_type = "carryable"
				anchor_uid = (carrier.anchorTile as Carryable).UID
			else:
				anchor_type = "node"
				anchor_node_path = str(carrier.anchorTile.get_path())
		stream.encode_var(anchor_type)
		stream.encode_u32(anchor_uid)
		stream.encode_var(anchor_node_path)
		stream.encode_u8(carrier._lift_dock_state)
		stream.encode_float(carrier._lift_dock_target_x)

	return stream.data


func set_initial_data(buffer: PackedByteArray) -> void :
	if not Keepers.has_initial_keepers_spawned:
		await Keepers.initial_keepers_spawned

	var stream: = PackedByteStream.from_bytes(buffer)
	var drop_count: = stream.decode_u16()

	for _i in range(drop_count):
		_spawn_from_stream(stream)


	var hidden_count: = stream.decode_u16()
	for _i in range(hidden_count):
		var hidden_uid: int = stream.decode_u16()
		if drops.has(hidden_uid):
			drops[hidden_uid].hide()

	var remaining: = stream.remaining()
	spawn_bundles_and_carriers_from_bytes.call_deferred(remaining)

func spawn_bundles_and_carriers_from_bytes(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	var bundleCount: = stream.decode_u16()
	for _i in range(bundleCount):
		var scene: Bundle = preload("res://content/keeper/keeper2/Bundle.tscn").instantiate()
		var bundle_id: = stream.decode_u32()
		scene.UID = bundle_id
		scene.name = "Bundle-%d" % bundle_id
		var player_id: = stream.decode_u8()
		var playerId: = "player%d" % player_id
		var direction: = stream.decode_vector2()
		var speed: = stream.decode_float()
		var hasLeaderNode: = stream.decode_bool()
		var leaderNode: Keeper = null
		if hasLeaderNode:
			leaderNode = Keepers.getKeeper(playerId)

		var carryableCount: = stream.decode_u16()
		for _j in range(carryableCount):
			var carryableUID: = stream.decode_u16()
			var strength: = stream.decode_float()
			scene.addCarryable(drops[carryableUID], strength)

		scene.clientStart(direction, speed, leaderNode, playerId)

		bundles[bundle_id] = scene
		bundle_spawned.emit(scene)

	var carrier_count: = stream.decode_u16()
	for _i in range(carrier_count):
		var carrier: KunaiCarrier = preload("res://content/keeper/keeper3/KunaiCarrier.tscn").instantiate()
		carrier.UID = stream.decode_u32()
		carrier.global_position = stream.decode_vector2()
		carrier.playerId = Utils.decode_player_id(stream.decode_u8())
		carrier.teamId = Utils.decode_team_id(stream.decode_u8())
		carrier.ownerKeeperId = Utils.decode_player_id(stream.decode_u8())
		if carrier.ownerKeeperId != "":
			var keeper: = Keepers.getKeeper(carrier.ownerKeeperId)
			if keeper:
				carrier.ownerKeeper = keeper
		carrier._savedAttachedState = stream.decode_bool()
		carrier.chainHanging = stream.decode_bool()
		carrier.gravity_multiplier = stream.decode_float()
		carrier.launch_direction = stream.decode_vector2()
		carrier.lastVelocity = stream.decode_vector2()
		carrier._savedLinearVelocity = stream.decode_vector2()
		carrier._savedAngularVelocity = stream.decode_float()
		var carryable_count: = stream.decode_u16()
		var carryables: = []
		for _j in range(carryable_count):
			var drop_uid: = stream.decode_u32()
			if not drops.has(drop_uid):
				continue
			carryables.append(drops[drop_uid])

		carrier._savedAnchorCoord = stream.decode_vector2()
		carrier._savedAnchorType = stream.decode_var()
		carrier._savedAnchorUid = stream.decode_u32()
		carrier._savedAnchorNodePath = stream.decode_var()

		carrier._lift_dock_state = stream.decode_u8()
		carrier._lift_dock_target_x = stream.decode_float()

		carriers[carrier.UID] = carrier
		carrier_spawned.emit(carrier)

		carrier._apply_loaded_state()
		for carryable in carryables:
			carrier.attachCarryable(carryable)

func network_spawn(data: Dictionary) -> Carryable:
	var stream: = _internal_network_spawn(data)

	network_rpc(_spawn_from_bytes.bind(stream.data), false)
	var carryable: = _spawn_from_stream(stream.duplicate())
	return carryable

@rpc("reliable")
func _spawn_from_bytes(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	_spawn_from_stream(stream)


func local_spawn(data: Dictionary) -> Carryable:
	var stream: = _internal_network_spawn(data)
	var carryable: = _spawn_from_stream(stream.duplicate())
	carryable.isLocal = true
	return carryable

func _internal_network_spawn(data: Dictionary) -> PackedByteStream:
	var stream: = PackedByteStream.new()

	stream.encode_u16(_get_carryable_id())

	var type_index: int = Data.DROP_TYPES.find(data["type"])
	if type_index == -1:
		push_error("Invalid drop type attempting to spawn: ", data["type"])
		return null

	stream.encode_u8(type_index)
	stream.encode_u8(int(data.get("team", "team0").lstrip("team")))
	stream.encode_vector2(data["position"])
	stream.encode_vector2(data.get("impulse", Vector2.ZERO))
	stream.encode_float(data.get("gravity_scale", 1))
	stream.encode_float(data.get("linear_damp", 0))

	var carriers: Array = data.get("carriers", [])
	stream.encode_u8(carriers.size())
	for c in carriers:
		stream.encode_u8(Utils.encode_player_id(c))

	var has_data_from_droppable_get_initial_data: = false
	stream.encode_bool(has_data_from_droppable_get_initial_data)
	return stream

func _get_carryable_id() -> int:
	for _i in range(1000):
		var uid: = randi() >> 20
		if not drops.has(uid):
			return uid

	push_error("Failed to create an unused drop ID")
	return -1

func _spawn_from_stream(stream: PackedByteStream) -> Carryable:
	var UID: = stream.decode_u16()
	if drops.has(UID):
		return null

	var type_index: = stream.decode_u8()
	var teamId = "team%d" % stream.decode_u8()
	var scene_type: String = Data.DROP_TYPES[type_index]
	var drop: Carryable = Data.DROP_SCENES[scene_type].instantiate()

	drop.UID = UID
	if teamId != "team0":
		drop.teamId = teamId
	drop.position = stream.decode_vector2()
	var impulse: = stream.decode_vector2()
	if not impulse.is_zero_approx():
		drop.apply_central_impulse(impulse)

	var gravity_scale: = stream.decode_float()
	var linear_damp: = stream.decode_float()

	if gravity_scale != 1 or linear_damp != 0:
		var po = CarryablePhysicsOverride.new(self)
		po.gravity_scale = gravity_scale
		po.linear_damp = linear_damp
		drop.addPhysicsOverride(po)

	drop_spawned.emit(drop)
	track_drop(drop)

	for _i in range(stream.decode_u8()):
		pickup.call_deferred(drop.UID, stream.decode_u8())

	var doppable_has_initial_data: bool = stream.decode_bool()
	if doppable_has_initial_data:
		assert (drop.has_method("set_initial_data"), "Initial data available, yet drop don't have set_initial_data method")
		var drop_initial_data: PackedByteArray = stream.decode_var() as PackedByteArray
		drop.set_initial_data(drop_initial_data)
	return drop

func network_drop_message(peer_id: int, buffer: PackedByteArray, drop: Carryable) -> void :
	on_drop_message.rpc_id(peer_id, drop.UID, buffer)

@rpc("reliable", "any_peer")
func on_drop_message(UID: int, buffer: PackedByteArray) -> void :
	if drops.has(UID):
		if drops[UID].has_method(&"on_drop_message"):
			drops[UID].on_drop_message(multiplayer.get_remote_sender_id(), buffer)

func on_server_drop_event(buffer: PackedByteArray, drop: Carryable) -> void :
	network_rpc(remote_drop_event.bind(drop.UID, buffer), true)

@rpc("reliable")
func remote_drop_event(UID: int, buffer: PackedByteArray) -> void :
	if drops.has(UID):
		if drops[UID].has_method(&"on_drop_event"):
			drops[UID].on_drop_event(buffer)

@rpc("reliable", "any_peer")
func request_pickup(UID: int, player_id: int) -> void :
	if drops.has(UID) and not drops[UID].is_queued_for_deletion() and not drops[UID].independent and (drops[UID] is not Drop or not drops[UID].absorbed):
		network_rpc(pickup.bind(UID, player_id), true)

@rpc("reliable")
func pickup(UID: int, player_id: int) -> void :
	if drops.has(UID):
		var playerId: = Utils.decode_player_id(player_id)
		if Keepers.hasKeeper(playerId):
			var carrier: = Keepers.getKeeper(playerId)
			carrier._attachCarryInternal(drops[UID])
			drop_picked_up.emit(drops[UID], carrier)


@rpc("reliable", "any_peer")
func drop(UID: int, player_id: int) -> void :
	if drops.has(UID):
		var playerId: = Utils.decode_player_id(player_id)
		if not Keepers.hasKeeper(playerId):

			drops[UID].freeByPlayerId.call_deferred(playerId)
			return

		var carrier: = Keepers.getKeeper(playerId)
		carrier._dropCarryInternal(drops[UID])

@rpc("reliable", "any_peer")
func drop_from_all(UID: int) -> void :
	if not drops.has(UID):
		return

	var carryable: = drops[UID] as Carryable
	for i in range(carryable.carriedBy.size() - 1, -1, -1):
		var carrier = carryable.carriedBy[i]
		if is_instance_valid(carrier):
			carrier._dropCarryInternal(carryable)

@rpc("reliable")
func shred(UID: int, teamId: String) -> void :
	if drops.has(UID):
		drops[UID].shred(teamId)

@rpc("reliable")
func set_independent(UID: int, value: bool) -> void :
	if drops.has(UID):
		drops[UID].setIndependent(value)

@rpc("reliable")
func shrink(UID: int, teamId: String) -> void :
	if drops.has(UID):
		drops[UID].shrink(teamId)

@rpc("reliable")
func free_drop(UID: int) -> void :
	if drops.has(UID):
		drops[UID].queue_free()
		drops.erase(UID)
		_drop_network_data.erase(UID)

@rpc("reliable")
func hide_drop(UID: int) -> void :
	if drops.has(UID):
		drops[UID].hide()
		drops[UID].forceHide = true

@rpc("reliable")
func show_drop(UID: int) -> void :
	if drops.has(UID):
		drops[UID].forceHide = false

@rpc("reliable")
func goblin_carry(UID: int, teamId: String, goblin_uid: int) -> void :
	if drops.has(UID):
		var drop: Carryable = drops[UID]

		var goblin: Goblin = Level.getDome(teamId).goblins.goblins_by_uid.get(goblin_uid)
		if not is_instance_valid(goblin):
			return

		drop.rotation = 0
		drop.setCarriedBy(goblin)
		drop.carry_sprite.hide()
		_wake_drops_near(drop)
		drop.collision_layer = 0
		drop.collision_mask = 0
		drop.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		drop.freeze = true
		drop.linear_velocity = Vector2.ZERO
		drop.angular_velocity = 0.0
		if not drop.has_meta("goblin_prev_z"):
			drop.set_meta("goblin_prev_z", drop.z_index)
		goblin._set_carried_resource_uid(UID)

@rpc("reliable")
func goblin_release(UID: int, collision_layer: int, collision_mask: int, freeze_mode: int, freeze: bool, teamId: String, goblin_uid: int) -> void :
	if drops.has(UID):
		var drop: Carryable = drops[UID]

		drop.collision_layer = collision_layer
		drop.collision_mask = collision_mask
		drop.freeze_mode = freeze_mode as RigidBody2D.FreezeMode
		drop.freeze = freeze
		if drop.has_meta("goblin_prev_z"):
			drop.z_index = drop.get_meta("goblin_prev_z")
			drop.remove_meta("goblin_prev_z")

		var goblin: Goblin = Level.getDome(teamId).goblins.goblins_by_uid.get(goblin_uid)
		if not is_instance_valid(goblin):
			return

		goblin._dropCarryInternal(drop)

const WAKE_NEIGHBOR_RADIUS: = 5.0

func _wake_drops_near(drop: Carryable) -> void :
	var shape: = CircleShape2D.new()
	shape.radius = WAKE_NEIGHBOR_RADIUS
	var query: = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, drop.global_position)
	query.collision_mask = drop.collision_layer
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [drop.get_rid()]
	var space: = drop.get_world_2d().direct_space_state
	for hit in space.intersect_shape(query, 16):
		Utils.wakeUpDrop(hit.collider, true)

@rpc("reliable")
func free_bundle(UID: int) -> void :
	if bundles.has(UID):
		if is_instance_valid(bundles[UID]):
			bundles[UID].queue_free()
		bundles.erase(UID)

@rpc("reliable")
func free_carrier(UID: int) -> void :
	if carriers.has(UID):
		if is_instance_valid(carriers[UID]):
			carriers[UID].queue_free()
		carriers.erase(UID)

@rpc("reliable")
func set_drop_team(drop_UID: int, new_team_id: String) -> void :
	if drops.has(drop_UID):
		var drop = drops[drop_UID]
		drop.teamId = new_team_id

@rpc("reliable")
func set_drop_target(drop_UID: int, drop_target_path: NodePath) -> void :
	var target: Node = get_node(drop_target_path)
	if not is_instance_valid(target):
		return
	if drops.has(drop_UID):
		var drop = drops[drop_UID]
		drop.dropTargetRef = target

@rpc("reliable")
func float_drop_target_as_self(drop_UID) -> void :
	if drops.has(drop_UID):
		var drop = drops[drop_UID]
		drop.dropTargetRef = drop

func on_drop_tree_exiting(drop: Carryable) -> void :
	if not is_inside_tree():

		return
	if drop.tree_entered.is_connected(on_drop_tree_entering):
		drop.tree_entered.disconnect(on_drop_tree_entering)
		drop.tree_exiting.disconnect(on_drop_tree_exiting)
	drops.erase(drop.UID)
	_drop_data_queue.erase(drop.UID)
	_drop_network_data.erase(drop.UID)
	_last_time_aprox_visibility.erase(drop.UID)

	for peer_id: int in _peers_visibility_update_tick:
		_peers_visibility_update_tick[peer_id].erase(drop.UID)

	for peer_id: int in _drops_to_acknowledged_sync:
		_drops_to_acknowledged_sync[peer_id].erase(drop.UID)

	for peer_id: int in _server_perspective_prev_peer_drops_visibility:
		_server_perspective_prev_peer_drops_visibility[peer_id].erase(drop.UID)

	for peer_id: int in _peer_perspective_drop_visibility:
		_peer_perspective_drop_visibility[peer_id].erase(drop.UID)

	for peer_id in _prev_peer_perspective_drop_visibility:
		_prev_peer_perspective_drop_visibility[peer_id].erase(drop.UID)

	for peer_id in _last_sync_translation:
		_last_sync_translation[peer_id].erase(drop.UID)

	for peer_id in _last_sync_at_frame:
		_last_sync_at_frame[peer_id].erase(drop.UID)

func on_drop_tree_entering(drop: Carryable) -> void :
	track_drop(drop)

func on_bundle_tree_exiting(bundle: Bundle) -> void :
	bundles.erase(bundle.UID)

func on_carrier_tree_exiting(carrier: KunaiCarrier) -> void :
	carriers.erase(carrier.UID)

func track_drop(drop: Carryable) -> void :
	drops[drop.UID] = drop
	_drop_network_data[drop.UID] = {}

	if not drop.tree_exiting.is_connected(on_drop_tree_exiting):
		drop.tree_exiting.connect(on_drop_tree_exiting.bind(drop))
	if multiplayer.is_server() and not drop.drop_event.is_connected(on_server_drop_event):
		drop.drop_event.connect(on_server_drop_event.bind(drop))
	if not drop.drop_message.is_connected(network_drop_message):
		drop.drop_message.connect(network_drop_message.bind(drop))
	if not drop.sleeping_state_changed.is_connected(_drop_sleep_changed):
		drop.sleeping_state_changed.connect(_drop_sleep_changed.bind(drop))

func _drop_sleep_changed(drop: Carryable) -> void :
	if not is_multiplayer_authority():
		return
	if not drop.sleeping:
		return
	if drop.independent:
		return
	if drop.isCarried():
		return

	var clients: Array[Client] = Network.clients
	for client: Client in clients:
		var is_visible = _can_peer_see_drop(client.peer_id, drop)
		if not is_visible:
			continue
		_drops_to_acknowledged_sync[client.peer_id][drop.UID] = true

func track_bundle(bundle: Bundle) -> void :
	bundles[bundle.UID] = bundle

	if not bundle.tree_exiting.is_connected(on_bundle_tree_exiting):
		bundle.tree_exiting.connect(on_bundle_tree_exiting.bind(bundle))

func track_carrier(carrier: KunaiCarrier) -> void :
	carriers[carrier.UID] = carrier

	if not carrier.tree_exiting.is_connected(on_carrier_tree_exiting):
		carrier.tree_exiting.connect(on_carrier_tree_exiting.bind(carrier))

@rpc("reliable", "any_peer")
func bundle(bundle_id: int, resources: PackedInt64Array, bundle_position: Vector2, aim_direction: Vector2, speed: float, duration: float, carryable_id: int, keeper_id: int, playerId: String) -> Bundle:
	var scene: Bundle = preload("res://content/keeper/keeper2/Bundle.tscn").instantiate()
	scene.UID = bundle_id
	scene.position = bundle_position
	scene.name = "Bundle-%d" % bundle_id
	bundles[bundle_id] = scene
	bundle_spawned.emit(scene)

	var bundleGroup: Array[Carryable] = []
	for UID in resources:
		if drops.has(UID):
			bundleGroup.append(drops[UID])

	for carryable in bundleGroup:
		Level.drops.network_drop_from_all(carryable)

	var leader: Node = null
	if keeper_id != -1:
		leader = Keepers.getKeeper("player%d" % keeper_id)
	elif carryable_id != -1:
		leader = drops.get(carryable_id)

	scene.start(aim_direction, bundleGroup, speed, duration, leader, playerId)
	return scene

@rpc("reliable", "any_peer")
func kunai_carrier(carrier_id: int, uids: PackedInt64Array, aim_direction: Vector2, start_position: Vector2, player_id: String) -> void :
	var carrier_scene = preload("res://content/keeper/keeper3/KunaiCarrier.tscn")
	var kunai_carrier: = carrier_scene.instantiate()
	kunai_carrier.UID = carrier_id
	track_carrier(kunai_carrier)
	kunai_carrier.name = "KunaiCarrier-%d" % carrier_id
	kunai_carrier.playerId = player_id
	if kunai_carrier is Node2D:
		(kunai_carrier as Node2D).position = start_position
	var keeper: = Keepers.getKeeper(player_id) as Keeper3
	if "ownerKeeper" in kunai_carrier:
		kunai_carrier.ownerKeeper = keeper
		kunai_carrier.teamId = keeper.teamId
	Style.init(kunai_carrier)
	Level.map.addDrop(kunai_carrier)

	for uid in uids:
		if not drops.has(uid):
			continue
		var drop: = drops[uid] as Carryable
		keeper._carrierDetachBody(drop)
		if not is_instance_valid(drop):
			continue
		drop.set_meta("kunai_carrier", kunai_carrier)
		kunai_carrier.attachCarryable(drop)

	kunai_carrier.launch(aim_direction)

@rpc("reliable", "any_peer")
func request_transfer_kunai_carrier(player_id: String, kunai_carrier_uid: int) -> void :
	if not carriers.has(kunai_carrier_uid):
		return
	if not is_instance_valid(carriers[kunai_carrier_uid]):
		carriers.erase(kunai_carrier_uid)
		return
	if not Keepers.hasKeeper(player_id):
		return
	var kunai_carrier: = carriers[kunai_carrier_uid] as KunaiCarrier
	kunai_carrier.transferToKeeper(Keepers.getKeeper(player_id))

@rpc("reliable", "any_peer")
func transfer_kunai_carrier(player_id: String, attached: bool, transfer_resource_uids: PackedInt64Array, kunai_carrier_uid: int) -> void :
	if not carriers.has(kunai_carrier_uid):
		return
	if not is_instance_valid(carriers[kunai_carrier_uid]):
		carriers.erase(kunai_carrier_uid)
		return
	var kunai_carrier: = carriers[kunai_carrier_uid] as KunaiCarrier
	var keeper: = Keepers.getKeeper(player_id) as Keeper3

	if keeper == null or not is_instance_valid(keeper):
		return
	for uid in transfer_resource_uids:
		if not drops.has(uid):
			continue
		var carryable: = drops[uid] as Carryable
		if carryable == null or not is_instance_valid(carryable):
			continue
		if not kunai_carrier.carriedCarryables.has(carryable):
			continue
		kunai_carrier.detachChainBodySync(carryable)
		kunai_carrier._carrierDetachBody(carryable)
		if keeper.has_method("attachCarry"):
			keeper.attachCarry(carryable)

@rpc("reliable")
func attach_to_tile(sending_kunai_carrier_uid: int, coord: Vector2, current_position: Vector2) -> void :
	if not carriers.has(sending_kunai_carrier_uid):
		return
	var sending: = carriers[sending_kunai_carrier_uid] as KunaiCarrier
	sending.global_position = current_position
	sending.attachToSurface(Level.map.getTile(coord))

@rpc("reliable")
func attach_to_node(sending_kunai_carrier_uid: int, node_path: NodePath, current_position: Vector2) -> void :
	var sending: KunaiCarrier = carriers[sending_kunai_carrier_uid]
	sending.global_position = current_position
	sending.attachToSurface(get_node(node_path))

@rpc("reliable")
func release_resources_from_kunai_carrier(uid: int) -> void :
	if not carriers.has(uid):
		return
	var carrier: = carriers[uid] as KunaiCarrier
	carrier.releaseResourcesAndDestroy()

@rpc("reliable")
func begin_carrier_lift_docking(uid: int, lift_center_x: float) -> void :
	if not carriers.has(uid):
		return
	var carrier: = carriers[uid] as KunaiCarrier
	carrier._begin_lift_docking(lift_center_x)

@rpc("reliable")
func release_next_resource_from_dock(uid: int) -> void :
	if not carriers.has(uid):
		return
	var carrier: = carriers[uid] as KunaiCarrier
	carrier._release_next_resource()

@rpc("reliable")
func begin_carrier_shredder_docking(uid: int) -> void :
	if not carriers.has(uid):
		return
	var carrier: = carriers[uid] as KunaiCarrier
	carrier._begin_shredder_docking()

@rpc("reliable", "any_peer")
func throw_drop(uid: int, force: Vector2) -> void :
	if not drops.has(uid):
		return

	var drop: = drops[uid] as Carryable
	var gravity_comp: = sqrt(maxf(drop.gravity_scale, Keeper4GameplaySettings.THROW_MIN_GRAVITY_SCALE))
	drop.apply_central_impulse((force * gravity_comp - drop.linear_velocity) * drop.mass)

const UID_BIT_SIZE: int = 12

const POSITION_BIT_SIZE: int = 26
const POSITION_FACTOR: float = 1000.0

const Y_POSITION_SHIFT: int = 100

const VELOCITY_BIT_SIZE: int = 23
const VELOCITY_FACTOR: float = 10000.0

const ROTATION_BIT_SIZE: int = 9
const ROTATION_FACTOR: float = 512.0


func pack_delta_data(drop: Carryable) -> PackedByteArray:











	var stream: = BitPackedByteStream.new()
	stream.resize(DELTA_STREAM_SIZE)
	stream.pack_bits(drop.UID, UID_BIT_SIZE)
	stream.pack_rotation(drop.sync_transform.get_rotation(), ROTATION_BIT_SIZE)
	stream.pack_signed_float(drop.sync_transform.origin.x, POSITION_BIT_SIZE, POSITION_FACTOR)
	stream.pack_unsigned_float(drop.sync_transform.origin.y, POSITION_BIT_SIZE, POSITION_FACTOR, Y_POSITION_SHIFT)
	stream.pack_signed_float(drop.sync_linear_velocity.x, VELOCITY_BIT_SIZE, VELOCITY_FACTOR)
	stream.pack_signed_float(drop.sync_linear_velocity.y, VELOCITY_BIT_SIZE, VELOCITY_FACTOR)
	stream.pack_bit(drop.sleeping)
	assert (stream.offset + signi(stream.bit_offset) == DELTA_STREAM_SIZE, "Wrong value of DELTA_STREAM_SIZE")
	return stream.data

func unpack_delta_data(buffer: PackedByteArray, current_tick: int, desired_sync_count: int) -> void :
	var stream: = BitPackedByteStream.from_bytes(buffer)

	var UID: = stream.unpack_bits(UID_BIT_SIZE)
	if not drops.has(UID):
		return

	var last_tick: int = _drop_network_data[UID].get("last_server_tick", current_tick)
	if last_tick > current_tick:
		return
	_drop_network_data[UID]["last_server_tick"] = current_tick

	var rotation: = stream.unpack_rotation(ROTATION_BIT_SIZE)
	var x_position: = stream.unpack_signed_float(POSITION_BIT_SIZE, POSITION_FACTOR)
	var y_position: = stream.unpack_unsigned_float(POSITION_BIT_SIZE, POSITION_FACTOR, Y_POSITION_SHIFT)

	var x_velocity: = stream.unpack_signed_float(VELOCITY_BIT_SIZE, VELOCITY_FACTOR)
	var y_velocity: = stream.unpack_signed_float(VELOCITY_BIT_SIZE, VELOCITY_FACTOR)

	var _sleeping: = stream.unpack_bit()
	assert (stream.offset + signi(stream.bit_offset) == DELTA_STREAM_SIZE, "Some bytes are still unpacked")

	var transform: = Transform2D(rotation, Vector2(x_position, y_position))
	var linear_velocity: = Vector2(x_velocity, y_velocity)

	var drop: Carryable = drops[UID]
	drop.applySyncData(current_tick, transform, linear_velocity, desired_sync_count)
