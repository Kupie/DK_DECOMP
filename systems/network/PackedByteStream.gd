class_name PackedByteStream
extends RefCounted

var data: PackedByteArray = PackedByteArray()
var offset: int = 0

static func from_bytes(data: PackedByteArray) -> PackedByteStream:
	var stream: = PackedByteStream.new()
	stream.data = data
	return stream

func resize(new_size: int) -> void :
	data.resize(new_size)

func ensure_space(required: int) -> void :
	if data.size() >= (offset + required):
		return

	data.resize(offset + required)

func size() -> int:
	return data.size()

func is_empty() -> bool:
	return data.is_empty()

func is_not_finished() -> bool:
	return offset < data.size()

func clear() -> void :
	data.clear()
	offset = 0

func append_array(new_data: PackedByteArray) -> void :
	data.append_array(new_data)
	offset = data.size()

func append_stream(new_stream: PackedByteStream) -> void :
	data.append_array(new_stream.data)
	offset = data.size()

func slice(size: int) -> PackedByteStream:
	var new_data: = data.slice(offset, offset + size)
	offset += size
	return PackedByteStream.from_bytes(new_data)

func remaining() -> PackedByteArray:
	var new_data: = data.slice(offset)
	offset = data.size()
	return new_data

func get_string_from_utf8() -> String:

	offset = data.size()
	return data.get_string_from_utf8()

func duplicate() -> PackedByteStream:
	var stream: = PackedByteStream.new()
	stream.data = data.duplicate()
	stream.offset = 0
	return stream


func decode_bool() -> bool:
	var ret: = data.decode_u8(offset)
	offset += 1
	return bool(ret)

func decode_vector2() -> Vector2:
	var ret: = Vector2(data.decode_float(offset), data.decode_float(offset + 4))
	offset += 8
	return ret

func decode_half_vector2() -> Vector2:
	var ret: = Vector2(data.decode_half(offset), data.decode_half(offset + 2))
	offset += 4
	return ret

func decode_u8() -> int:
	var ret: = data.decode_u8(offset)
	offset += 1
	return ret

func decode_s8() -> int:
	var ret: = data.decode_s8(offset)
	offset += 1
	return ret

func decode_u16() -> int:
	var ret: = data.decode_u16(offset)
	offset += 2
	return ret

func decode_s16() -> int:
	var ret: = data.decode_s16(offset)
	offset += 2
	return ret

func decode_u32() -> int:
	var ret: = data.decode_u32(offset)
	offset += 4
	return ret

func decode_s32() -> int:
	var ret: = data.decode_s32(offset)
	offset += 4
	return ret

func decode_u64() -> int:
	var ret: = data.decode_u64(offset)
	offset += 8
	return ret

func decode_s64() -> int:
	var ret: = data.decode_s64(offset)
	offset += 8
	return ret

func decode_half() -> float:
	var ret: = data.decode_half(offset)
	offset += 2
	return ret

func decode_float() -> float:
	var ret: = data.decode_float(offset)
	offset += 4
	return ret

func decode_double() -> float:
	var ret: = data.decode_double(offset)
	offset += 8
	return ret

func has_encoded_var() -> bool:
	return data.has_encoded_var(offset)

func decode_var() -> Variant:
	var var_size: = data.decode_var_size(offset)
	var ret: Variant = data.decode_var(offset)
	offset += var_size
	return ret



func encode_bool(value: bool) -> void :
	ensure_space(1)
	data.encode_u8(offset, int(value))
	offset += 1

func encode_vector2(value: Vector2) -> void :
	ensure_space(8)
	data.encode_float(offset, value.x)
	data.encode_float(offset + 4, value.y)
	offset += 8

func encode_half_vector2(value: Vector2) -> void :
	ensure_space(4)
	data.encode_half(offset, value.x)
	data.encode_half(offset + 2, value.y)
	offset += 4

func encode_u8(value: int) -> void :
	ensure_space(1)
	data.encode_u8(offset, value)
	offset += 1

func encode_s8(value: int) -> void :
	ensure_space(1)
	data.encode_s8(offset, value)
	offset += 1

func encode_u16(value: int) -> void :
	ensure_space(2)
	data.encode_u16(offset, value)
	offset += 2

func encode_s16(value: int) -> void :
	ensure_space(2)
	data.encode_s16(offset, value)
	offset += 2

func encode_u32(value: int) -> void :
	ensure_space(4)
	data.encode_u32(offset, value)
	offset += 4

func encode_s32(value: int) -> void :
	ensure_space(4)
	data.encode_s32(offset, value)
	offset += 4

func encode_u64(value: int) -> void :
	ensure_space(8)
	data.encode_u64(offset, value)
	offset += 8

func encode_s64(value: int) -> void :
	ensure_space(8)
	data.encode_s64(offset, value)
	offset += 8

func encode_half(value: float) -> void :
	ensure_space(2)
	data.encode_half(offset, value)
	offset += 2

func encode_float(value: float) -> void :
	ensure_space(4)
	data.encode_float(offset, value)
	offset += 4

func encode_double(value: float) -> void :
	ensure_space(8)
	data.encode_double(offset, value)
	offset += 8

func encode_var(value: Variant) -> void :

	var buffer: = var_to_bytes(value)
	var var_size: = buffer.size()
	ensure_space(var_size)
	data.encode_var(offset, value)
	offset += var_size
