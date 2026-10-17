class_name BitPackedByteStream
extends PackedByteStream

var bit_offset: int = 0

static func from_bytes(data: PackedByteArray) -> BitPackedByteStream:
	var stream: = BitPackedByteStream.new()
	stream.data = data
	return stream

func clear() -> void :
	super.clear()
	bit_offset = 0

func align_to_byte() -> void :
	if bit_offset > 0:
		offset += 1
		bit_offset = 0

func ensure_space(required: int) -> void :
	align_to_byte()
	if data.size() >= (offset + required):
		return

	data.resize(offset + required)


func pack_bits(value: int, bit_count: int) -> void :

	var current_bit_position: int = offset * 8 + bit_offset
	var end_bit_position: int = current_bit_position + bit_count
	var bytes_needed: int = (end_bit_position + 7) / 8

	if data.size() < bytes_needed:
		data.resize(bytes_needed)


	var mask: int = (1 << bit_count) - 1
	value = value & mask

	var bits_remaining: int = bit_count
	var current_bit_offset: int = bit_offset
	var current_byte_offset: int = offset

	while bits_remaining > 0:

		var bits_available_in_byte: int = 8 - current_bit_offset
		var bits_to_write: int = mini(bits_remaining, bits_available_in_byte)


		var shift_amount: int = bits_remaining - bits_to_write
		var bits_mask: int = (1 << bits_to_write) - 1
		var bits_to_insert: int = (value >> shift_amount) & bits_mask


		var current_byte: int = 0
		if current_byte_offset < data.size():
			current_byte = data.decode_u8(current_byte_offset)


		var clear_mask: int = ((1 << bits_to_write) - 1) << (bits_available_in_byte - bits_to_write)
		current_byte = current_byte & ~ clear_mask


		current_byte = current_byte | (bits_to_insert << (bits_available_in_byte - bits_to_write))


		data.encode_u8(current_byte_offset, current_byte)


		bits_remaining -= bits_to_write
		current_bit_offset += bits_to_write
		if current_bit_offset >= 8:
			current_bit_offset = 0
			current_byte_offset += 1


	var total_bits: int = bit_offset + bit_count
	offset += total_bits / 8
	bit_offset = total_bits % 8

func pack_bit(value: bool) -> void :
	pack_bits(1 if value else 0, 1)

func unpack_bits(bit_count: int) -> int:
	var result: int = 0
	var bits_remaining: int = bit_count
	var current_bit_offset: int = bit_offset
	var current_byte_offset: int = offset

	while bits_remaining > 0 and current_byte_offset < data.size():

		var bits_available_in_byte: int = 8 - current_bit_offset
		var bits_to_read: int = mini(bits_remaining, bits_available_in_byte)

		var current_byte: int = data.decode_u8(current_byte_offset)


		var shift_amount: int = bits_available_in_byte - bits_to_read
		var mask: int = (1 << bits_to_read) - 1
		var extracted_bits: int = (current_byte >> shift_amount) & mask


		result = (result << bits_to_read) | extracted_bits


		bits_remaining -= bits_to_read
		current_bit_offset += bits_to_read
		if current_bit_offset >= 8:
			current_bit_offset = 0
			current_byte_offset += 1


	var total_bits: int = bit_offset + bit_count
	offset += total_bits / 8
	bit_offset = total_bits % 8

	return result

func unpack_bit() -> bool:
	return unpack_bits(1) != 0



func pack_unsigned_float(value: float, bit_count: int, factor: float, offset: float = 0.0) -> void :
	var max_int_value: int = (1 << bit_count)
	value = clampf(value + offset, - offset, (float(max_int_value - 1) / factor) - offset)

	pack_bits(int(roundf(value * factor)), bit_count)

func unpack_unsigned_float(bit_count: int, factor: float, offset: float = 0.0) -> float:
	var int_value: = unpack_bits(bit_count)

	return (float(int_value) / factor) - offset

func pack_signed_float(value: float, bit_count: int, factor: float, offset: float = 0.0) -> void :
	var max_int_value: int = (1 << (bit_count - 1))
	value = clampf(value + offset, ( - float(max_int_value) / factor) - offset, (float(max_int_value - 1) / factor) - offset)
	var int_value: int = int(roundf(value * factor))
	if int_value < 0:
		int_value = (1 << bit_count) + int_value

	pack_bits(int_value, bit_count)

func unpack_signed_float(bit_count: int, factor: float, offset: float = 0.0) -> float:
	var int_value: = unpack_bits(bit_count)
	if int_value & (1 << (bit_count - 1)):
		int_value = int_value - (1 << bit_count)

	return (float(int_value) / factor) - offset



func pack_normalized(value: float, bit_count: int) -> void :

	var max_int_value: int = (1 << (bit_count))
	pack_unsigned_float(value, bit_count, float(max_int_value))

func unpack_normalized(bit_count: int) -> float:
	var max_int_value: int = (1 << (bit_count))
	return unpack_unsigned_float(bit_count, float(max_int_value))

func pack_rotation(value: float, bit_count: int) -> void :

	var max_int_value: int = (1 << (bit_count - 1))
	var factor: float = max_int_value / PI
	pack_signed_float(value, bit_count, factor)

func unpack_rotation(bit_count: int) -> float:
	var max_int_value: int = (1 << (bit_count - 1))
	var factor: float = max_int_value / PI
	return unpack_signed_float(bit_count, factor)



func decode_u8() -> int:
	align_to_byte()
	return super.decode_u8()

func decode_s8() -> int:
	align_to_byte()
	return super.decode_s8()

func decode_u16() -> int:
	align_to_byte()
	return super.decode_u16()

func decode_s16() -> int:
	align_to_byte()
	return super.decode_s16()

func decode_u32() -> int:
	align_to_byte()
	return super.decode_u32()

func decode_s32() -> int:
	align_to_byte()
	return super.decode_s32()

func decode_u64() -> int:
	align_to_byte()
	return super.decode_u64()

func decode_s64() -> int:
	align_to_byte()
	return super.decode_s64()

func decode_float() -> float:
	align_to_byte()
	return super.decode_float()

func decode_double() -> float:
	align_to_byte()
	return super.decode_double()

func decode_half() -> float:
	align_to_byte()
	return super.decode_half()

func decode_vector2() -> Vector2:
	align_to_byte()
	return super.decode_vector2()

func decode_half_vector2() -> Vector2:
	align_to_byte()
	return super.decode_half_vector2()

func decode_bool() -> bool:
	align_to_byte()
	return super.decode_bool()

func decode_var() -> Variant:
	align_to_byte()
	return super.decode_var()


func duplicate() -> BitPackedByteStream:
	var stream: = BitPackedByteStream.new()
	stream.data = data.duplicate()
	stream.offset = 0
	stream.bit_offset = 0
	return stream
