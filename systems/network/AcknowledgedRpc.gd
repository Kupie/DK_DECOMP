





class_name AcknowledgedRpc extends Node

const IDX_ACKNOWLEDGED_QUEUE_PEER: int = 0
const IDX_ACKNOWLEDGED_QUEUE_TIMESTAMP: int = 1
const IDX_ACKNOWLEDGED_QUEUE_CALL: int = 2
const MAX_NMB_OF_RESEND_PER_TICK: int = 32
const PING_UNCERTAINTY_FACTOR: float = 1.2

var _packet_counter: int = -1
var _acknowledgment_packet_queue: Dictionary = {

}
var _estimated_ping: Dictionary = {

	1: 100
}

func _ready() -> void :
	Network.client_ready.connect(_on_network_client_ready)
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	for peer_id: int in multiplayer.get_peers():
		if multiplayer.get_unique_id() != peer_id:
			_prepare_data_for_peer(peer_id)

func _on_network_client_ready(in_peer: int) -> void :
	_prepare_data_for_peer(in_peer)

func _on_multiplayer_peer_connected(in_peer: int) -> void :
	_prepare_data_for_peer(in_peer)

func _on_multiplayer_peer_disconnected(in_peer: int) -> void :
	_estimated_ping.erase(in_peer)

func _prepare_data_for_peer(in_peer: int) -> void :
	_estimated_ping[in_peer] = 100


func update() -> void :
	_resend_acknowledge_requests()

func _resend_acknowledge_requests() -> void :
	var ordered_packet_ids_queue: Array = _acknowledgment_packet_queue.keys()
	var current_max_acknowledgments: int = min(MAX_NMB_OF_RESEND_PER_TICK, _acknowledgment_packet_queue.size())
	for acknowledge_idx in current_max_acknowledgments:
		var packet_id: int = ordered_packet_ids_queue[acknowledge_idx]
		var acknowledge_data: Array = _acknowledgment_packet_queue[packet_id]
		var client_id: int = acknowledge_data[IDX_ACKNOWLEDGED_QUEUE_PEER]
		var is_client_still_connected: bool = _estimated_ping.has(client_id)
		if not is_client_still_connected:
			_acknowledgment_packet_queue.erase(packet_id)
			continue

		var last_send_time_stamp: int = acknowledge_data[IDX_ACKNOWLEDGED_QUEUE_TIMESTAMP]
		var estimate_peer_ping: int = int(_estimated_ping[client_id] * PING_UNCERTAINTY_FACTOR)
		var client_had_chance_to_response: bool = (Time.get_ticks_msec() - last_send_time_stamp) > estimate_peer_ping
		if client_had_chance_to_response:
			var receiver_peer_id: int = acknowledge_data[IDX_ACKNOWLEDGED_QUEUE_PEER]
			var callable: Callable = acknowledge_data[IDX_ACKNOWLEDGED_QUEUE_CALL]
			callable.rpc_id(receiver_peer_id)






func push_acknowledged_message(in_target_peer: int, callable: Callable) -> void :
	_packet_counter += 1
	callable = callable.bind(_packet_counter)
	assert (callable.get_argument_count() == 0, "Improper number of arguments, ensure first argument of "\
	+ callable.get_method() + " is 'packet_id: int', and that this argument is not passed into\t\t\tpush_acknowledged_message() (it will be binded automatically)"\
	)
	_acknowledgment_packet_queue[_packet_counter] = [in_target_peer, Time.get_ticks_msec(), callable]
	callable.rpc_id(in_target_peer)


func acknowledge_sender(in_confirming_packet: int) -> void :
	if not is_instance_valid(multiplayer):

		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	_acknowledge_packet.rpc_id(sender_id, in_confirming_packet)

@rpc("any_peer", "call_remote", "unreliable")
func _acknowledge_packet(in_packet_id: int) -> void :
	var already_acknowledged = not _acknowledgment_packet_queue.has(in_packet_id)
	if already_acknowledged:
		return
	if not is_instance_valid(multiplayer):

		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var current_ping: int = Time.get_ticks_msec() - _acknowledgment_packet_queue[in_packet_id][IDX_ACKNOWLEDGED_QUEUE_TIMESTAMP]
	_estimated_ping[sender_id] = int(lerp(int(_estimated_ping[sender_id]), current_ping, 0.1))
	_acknowledgment_packet_queue.erase(in_packet_id)
