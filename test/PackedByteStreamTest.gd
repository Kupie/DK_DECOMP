extends Node


func _ready() -> void :


	var buffer: = create_packed_carryable_stream(Transform2D(PI / 2, Vector2(-303.2, 532.2)), Vector2(-21.2, 22.3))
	print("============================")
	unpack_carryable_data(buffer)
	get_tree().quit()

func create_byte_array_with_stream() -> PackedByteArray:
	var stream: = PackedByteStream.new()

	var string: = "Cool String"
	stream.encode_u32(3989289)
	stream.encode_var(string)
	stream.encode_float(3.329239)
	stream.encode_var("Inline String")
	stream.encode_var("")
	stream.encode_vector2(Vector2.ONE * 3920.329)

	return stream.data

func read_byte_array_with_stream(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	print(stream.decode_u32())
	print(stream.decode_var())
	print(stream.decode_float())
	print(stream.decode_var())
	print(var_to_str(stream.decode_var()))
	print(stream.decode_vector2())


const POSITION_BIT_SIZE: int = 26
const POSITION_FACTOR: float = 1000.0
const POSITION_BIT_HEX: int = 33554431

const Y_POSITION_SHIFT: int = 100
const Y_POSITION_BIT_HEX: int = 67108863

const VELOCITY_BIT_SIZE: int = 23
const VELOCITY_BIT_HEX: int = 4194303
const VELOCITY_FACTOR: float = 10000.0

const ROTATION_BIT_SIZE: int = 9
const ROTATION_FACTOR: float = 512.0
const ROTATION_BIT_HEX: int = 511
const ROTATION_OFFSET: int = POSITION_BIT_SIZE * 2

const UID_OFFSET: int = 2 * VELOCITY_BIT_SIZE
const UID_BIT_HEX: int = 4095

const X_POSITION_SIGN_BIT: int = 1 << ((POSITION_BIT_SIZE * 2) - 1)
const X_VELOCITY_SIGN_BIT: int = 1 << ((VELOCITY_BIT_SIZE * 2) - 1)
const Y_VELOCITY_SIGN_BIT: int = 1 << (VELOCITY_BIT_SIZE - 1)

func binary_string_with_length(num: int) -> String:
	return "%s (%d)" % [String.num_int64(num, 2), String.num_int64(num, 2).length()]

func create_packed_carryable_stream(transform: Transform2D, linear_velocity: Vector2) -> PackedByteArray:

	var x_bounds: float = (2 ** (POSITION_BIT_SIZE - 1)) / POSITION_FACTOR
	var x_position: int = int(
		POSITION_FACTOR * abs(clampf(transform.origin.x, - x_bounds, x_bounds))
	)

	var y_upper_bound: float = ((2 ** POSITION_BIT_SIZE) / POSITION_FACTOR) - Y_POSITION_SHIFT
	var y_position: int = int(
		POSITION_FACTOR * abs(clampf(transform.origin.y + Y_POSITION_SHIFT, - Y_POSITION_SHIFT, y_upper_bound))
	)

	print("X Position: %d (%.2f)" % [x_position, transform.origin.x])
	print("Binary: %s" % binary_string_with_length(x_position))
	print("Y Position: %d (%.2f)" % [y_position, transform.origin.y])
	print("Binary: %s" % binary_string_with_length(y_position))

	var rng: = RandomNumberGenerator.new()
	rng.seed = 1



	var uid: int = 499
	print("UID: %d" % uid)
	print("Binary: %s" % binary_string_with_length(uid))

	var i1: int = 0
	print("Intialize: %s" % binary_string_with_length(i1))
	i1 = i1 ^ (x_position << POSITION_BIT_SIZE)
	print("With X: %s" % binary_string_with_length(i1))
	i1 = i1 ^ y_position
	print("With Y: %s" % binary_string_with_length(i1))

	if transform.origin.x < 0:
		i1 = i1 ^ X_POSITION_SIGN_BIT

	print("With X S: %s" % binary_string_with_length(i1))

	var rotation: = int(transform.get_rotation() / TAU * ROTATION_FACTOR)
	i1 = i1 ^ (rotation << ROTATION_OFFSET)

	print("With Rotation: %s" % binary_string_with_length(i1))

	var velocity_bounds: float = (2 ** (VELOCITY_BIT_SIZE - 1)) / VELOCITY_FACTOR
	var x_velocity: int = int(
		VELOCITY_FACTOR * abs(clampf(linear_velocity.x, - velocity_bounds, velocity_bounds))
	)

	var y_velocity: int = int(
		VELOCITY_FACTOR * abs(clampf(linear_velocity.y, - velocity_bounds, velocity_bounds))
	)

	print("X Velocity: %d (%.2f)" % [x_velocity, linear_velocity.x])
	print("Binary: %s" % binary_string_with_length(x_velocity))
	print("Y Velocity: %d (%.2f)" % [y_velocity, linear_velocity.y])
	print("Binary: %s" % binary_string_with_length(y_velocity))

	var i2: int = 0
	print("Intialize: %s" % binary_string_with_length(i2))
	i2 = i2 ^ (x_velocity << VELOCITY_BIT_SIZE)
	print("With X: %s" % binary_string_with_length(i2))
	i2 = i2 ^ y_velocity
	print("With Y: %s" % binary_string_with_length(i2))

	if linear_velocity.x < 0:
		i2 = i2 ^ X_VELOCITY_SIGN_BIT
	if linear_velocity.y < 0:
		i2 = i2 ^ Y_VELOCITY_SIGN_BIT

	print("With Sign: %s" % binary_string_with_length(i2))

	i2 = i2 ^ (uid << UID_OFFSET)
	print("With UID: %s" % binary_string_with_length(i2))

	var buffer: = PackedByteArray()
	buffer.resize(16)
	buffer.encode_u64(0, i1)
	buffer.encode_u64(8, i2)
	return buffer

func unpack_carryable_data(buffer: PackedByteArray) -> void :
	var i1 = buffer.decode_u64(0)
	var i2 = buffer.decode_u64(8)

	print("Input: %s" % binary_string_with_length(i1))

	var uid: int = (i2 & (UID_BIT_HEX << UID_OFFSET)) >> UID_OFFSET
	var x_position: float = (i1 & POSITION_BIT_HEX << POSITION_BIT_SIZE) >> POSITION_BIT_SIZE
	if i1 & X_POSITION_SIGN_BIT != 0:
		x_position = - x_position
	var y_position: float = (i1 & Y_POSITION_BIT_HEX)
	var rotation: float = ((i1 & (ROTATION_BIT_HEX << ROTATION_OFFSET)) >> ROTATION_OFFSET)

	var x_velocity: float = (i2 & VELOCITY_BIT_HEX << VELOCITY_BIT_SIZE) >> VELOCITY_BIT_SIZE
	if i2 & X_VELOCITY_SIGN_BIT != 0:
		x_velocity = - x_velocity
	var y_velocity: int = (i2 & VELOCITY_BIT_HEX)
	if i2 & Y_VELOCITY_SIGN_BIT != 0:
		y_velocity = - y_velocity

	print("X Position: %d (%.2f)" % [x_position, x_position / POSITION_FACTOR])
	print("Binary: %s" % binary_string_with_length(x_position))
	print("Y Position: %d (%.2f)" % [y_position, (y_position / POSITION_FACTOR) - Y_POSITION_SHIFT])
	print("Binary: %s" % binary_string_with_length(y_position))

	print("UID: %d" % uid)
	print("Binary: %s" % binary_string_with_length(uid))

	print("Rotation: %d (%.2f)" % [rotation, rotation / ROTATION_FACTOR * TAU])
	print("Binary: %s" % binary_string_with_length(rotation))

	print("X Velocity: %d (%.2f)" % [x_velocity, x_velocity / VELOCITY_FACTOR])
	print("Binary: %s" % binary_string_with_length(x_velocity))
	print("Y Velocity: %d (%.2f)" % [y_velocity, y_velocity / VELOCITY_FACTOR])
	print("Binary: %s" % binary_string_with_length(y_velocity))
