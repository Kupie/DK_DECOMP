
class_name TickCalibrator extends Node

const SEND_CALIBRATION_INFO_ONCE_EVERY_MS: int = 3 * 1000
const MIN_DELAY_BETWEEN_RECALIBRATIONS: int = 14 * 1000


var _last_check_at_ms: int = Time.get_ticks_msec()


var _client_last_reset_at_ms: int = Time.get_ticks_msec()


func update(in_network_tick: int) -> void :
	if Network.is_offline_mode():
		return
	if not multiplayer.is_server():
		return

	var duration_since_last_check: int = Time.get_ticks_msec() - _last_check_at_ms
	if duration_since_last_check > SEND_CALIBRATION_INFO_ONCE_EVERY_MS:
		_update_calibration_info.rpc(in_network_tick)
		_last_check_at_ms = Time.get_ticks_msec()

@rpc("unreliable_ordered")
func _update_calibration_info(in_server_tick: int) -> void :
	assert ( not multiplayer.is_server())
	_ensure_network_tick_correctness(in_server_tick)

func _ensure_network_tick_correctness(in_server_tick: int) -> void :
	assert ( not multiplayer.is_server())
	var ping: int = Network.get_current_ping_ms()
	var tick_delta: int = in_server_tick - Network.tick_count
	var tick_delta_based_on_ping: int = ceili(float(ping) / Engine.physics_ticks_per_second) + 1
	const margin_factor: float = 2.0
	var time_since_last_network_frame_calibration: int = Time.get_ticks_msec() - _client_last_reset_at_ms
	if time_since_last_network_frame_calibration > MIN_DELAY_BETWEEN_RECALIBRATIONS:
		var client_had_performance_problems: bool = tick_delta > (tick_delta_based_on_ping * margin_factor)
		var server_had_performance_problems: bool = tick_delta < -1 * (tick_delta_based_on_ping * margin_factor)
		var need_to_calibrate: bool = client_had_performance_problems or server_had_performance_problems
		if need_to_calibrate:
			Network.tick_count = in_server_tick
			_client_last_reset_at_ms = Time.get_ticks_msec()
