class_name Pinger extends Node

const PING_EVERY_X_SECONDS = 1.0

signal new_read(ping_ms: int)

var _waiting_for_reply: bool = false
var _last_send_at_time: int = Time.get_ticks_msec()
var _current_ping_ms: int = 0
var _timer: Timer

func _ready() -> void :
	_timer = Timer.new()
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)
	_timer.autostart = true
	_timer.start(PING_EVERY_X_SECONDS)

func get_current_ping_ms() -> int:
	return _current_ping_ms

@rpc("reliable", "any_peer")
func _rpc_ping_peer() -> void :
	assert (multiplayer.is_server())
	var ping_back_to: int = multiplayer.get_remote_sender_id()
	_ping_return.rpc_id(ping_back_to)

@rpc("reliable", "any_peer")
func _ping_return() -> void :
	assert ( not multiplayer.is_server())
	_waiting_for_reply = false
	var ping_ms = Time.get_ticks_msec() - _last_send_at_time





	_current_ping_ms = lerp(_current_ping_ms, ping_ms, 0.5)

	new_read.emit(_current_ping_ms)

func _on_timer_timeout() -> void :
	var connected: bool = is_instance_valid(multiplayer.multiplayer_peer) and \
	multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if not connected:
		_waiting_for_reply = false
		return
	if Network.is_client():
		_ping_server()

func _ping_server() -> void :
	if _waiting_for_reply:
		var time_since_last_send_ms: int = Time.get_ticks_msec() - _last_send_at_time
		if time_since_last_send_ms > 10000:

			_waiting_for_reply = false
		return

	_last_send_at_time = Time.get_ticks_msec()
	_rpc_ping_peer.rpc_id(1)
	_waiting_for_reply = true
