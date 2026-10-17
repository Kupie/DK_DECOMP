class_name Synchronizer
extends Node

const TPS_UPDATE_TIME: float = 1000000

@export var target_connection_states: Array[Network.ConnectionState] = []
@export var reliable: bool = false
@export var periodic_full_syncs: bool = false
@export var ticks_between_full_sync: int = 300

var remote_data_call: Callable


var _tps: float = 0.0
var _tps_ticks: int = 0
var _tps_update: float = Time.get_ticks_usec() + TPS_UPDATE_TIME


var ticks_until_full_sync: int = 0
var full_sync_next_tick: bool = false
var inital_syncs: Array[int]
var server_tick: int = 0
var paused: bool = false


func prepare_data() -> void :
	pass

func get_delta_data(peer_id: int) -> PackedByteArray:
	return PackedByteArray()

func set_delta_data(buffer: PackedByteArray) -> void :
	pass

func get_initial_data(peer_id: int) -> PackedByteArray:
	return get_delta_data(peer_id)

func set_initial_data(buffer: PackedByteArray) -> void :
	set_delta_data(buffer)

func get_full_sync_data(peer_id: int) -> PackedByteArray:
	return get_delta_data(peer_id)

func set_full_sync_data(buffer: PackedByteArray) -> void :
	pass




func network_rpc(rpc_call: Callable, call_local: bool = false) -> void :
	if target_connection_states.size() == 0:
		push_warning("Synchronizer has no target connection states.")
	if call_local:
		rpc_call.call()
	Network.rpc_for_states(rpc_call, target_connection_states)

func rpc_server(rpc_call: Callable) -> void :
	Network.rpc_server(rpc_call)

func rpc_or_local(peer_id: int, rpc_call: Callable) -> void :
	Network.rpc_or_local(peer_id, rpc_call)

func manual_tick() -> void :
	on_network_tick(Network.tick_count)



func _enter_tree() -> void :
	paused = false

func _exit_tree() -> void :
	paused = true

func _get_configuration_warnings():
	if not target_connection_states.size():
		return ["Synchronizer has no target connection states."]

func _mark_tick() -> void :

	_tps_ticks += 1
	if Time.get_ticks_usec() > _tps_update:
		_tps = float(_tps_ticks)
		_tps_ticks = 0
		_tps_update = Time.get_ticks_usec() + TPS_UPDATE_TIME

@rpc("unreliable")
func _unreliable_remote_set_data(tick_sent: int, buffer: PackedByteArray) -> void :
	if server_tick > tick_sent:
		return

	server_tick = tick_sent
	set_delta_data(buffer)
	_mark_tick()

@rpc("reliable")
func _reliable_remote_set_data(tick_sent: int, buffer: PackedByteArray) -> void :
	server_tick = tick_sent
	set_delta_data(buffer)
	_mark_tick()

@rpc("reliable")
func _remote_set_initial_data(tick_sent: int, buffer: PackedByteArray) -> void :
	server_tick = tick_sent
	set_initial_data(buffer)
	_mark_tick()

@rpc("reliable")
func _remote_set_full_sync_data(tick_sent: int, buffer: PackedByteArray) -> void :
	server_tick = tick_sent
	set_full_sync_data(buffer)
	_mark_tick()

func _ready():
	remote_data_call = _reliable_remote_set_data if reliable else _unreliable_remote_set_data
	ticks_until_full_sync = ticks_between_full_sync

	Network.network_tick.connect(on_network_tick)

func on_network_tick(tick_counter: int) -> void :
	if paused:
		return

	if not is_multiplayer_authority():
		return

	_mark_tick()
	server_tick = tick_counter


	prepare_data()

	var full_sync: bool = (periodic_full_syncs and ticks_until_full_sync <= 0) or full_sync_next_tick

	for client in Network.clients:
		if target_connection_states.has(client.connection_state):
			if inital_syncs.has(client.peer_id):
				if full_sync:
					full_sync_next_tick = false
					var data: = get_full_sync_data(client.peer_id)
					if not data.size():
						continue

					_remote_set_full_sync_data.rpc_id(client.peer_id, tick_counter, data)

				var data: = get_delta_data(client.peer_id)
				if not data.size():
					continue
				remote_data_call.rpc_id(client.peer_id, tick_counter, data)
			else:

				var data: = get_initial_data(client.peer_id)
				if data.size():
					_remote_set_initial_data.rpc_id(client.peer_id, tick_counter, data)
				inital_syncs.append(client.peer_id)

	if periodic_full_syncs:
		if full_sync:
			ticks_until_full_sync = ticks_between_full_sync
		else:
			ticks_until_full_sync -= 1
