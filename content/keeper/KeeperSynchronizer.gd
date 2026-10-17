class_name KeeperSynchronizer
extends Synchronizer

var keeper: Keeper
var position_buffer: PositionBuffer

func _ready():
	keeper = owner as Keeper
	position_buffer = PositionBuffer.new()
	position_buffer.expected_tick_gap = 20.0
	var tween: = create_tween()
	tween.tween_property(position_buffer, "expected_tick_gap", 2.0, 5.0)

	super._ready()

func _physics_process(delta):
	if not keeper.is_multiplayer_authority():
		position_buffer.update_correction(delta)
		var sample: = position_buffer.sample(keeper.global_position)
		keeper.global_position = sample.position

func get_delta_data(_peer_id: int) -> PackedByteArray:
	var data: = PackedVector2Array([keeper.global_position, keeper.moveDirectionInput, keeper.velocity, keeper.get_camera_target_pos()])
	return var_to_bytes(data)

func set_delta_data(buffer: PackedByteArray) -> void :
	var data: PackedVector2Array = bytes_to_var(buffer)
	position_buffer.push_packet(server_tick, data[0], data[2])
	keeper.moveDirectionInput = data[1]
	keeper._remote_camera_target = data[3]
