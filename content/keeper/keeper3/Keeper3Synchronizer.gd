extends KeeperSynchronizer

func get_delta_data(_peer_id: int) -> PackedByteArray:
	var buffer: = PackedByteStream.new()
	buffer.encode_vector2(keeper.global_position)
	buffer.encode_vector2(keeper.moveDirectionInput)
	buffer.encode_vector2(keeper.velocity)
	buffer.encode_vector2(keeper.get_camera_target_pos())

	buffer.encode_bool(keeper.justPressedUpThisFrame)
	buffer.encode_bool(keeper.drillClimbActive)

	return buffer.data

func set_delta_data(data: PackedByteArray) -> void :
	var buffer: = PackedByteStream.from_bytes(data)

	var network_position: = buffer.decode_vector2()
	keeper.moveDirectionInput = buffer.decode_vector2()
	var network_velocity: = buffer.decode_vector2()
	keeper.move = network_velocity
	keeper._remote_camera_target = buffer.decode_vector2()

	keeper.justPressedUp = buffer.decode_bool()
	keeper.drillClimbActive = buffer.decode_bool()

	position_buffer.push_packet(server_tick, network_position, network_velocity)
