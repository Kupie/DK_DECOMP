extends RefCounted


class_name TileDestroyedEvent

const BYTE_SIZE: int = 13

var time: float
var coord: Vector2
var type: int

func _init(time: float, coord: Vector2, newType: = -1) -> void :
	self.time = time
	self.coord = coord
	self.type = newType

func serialize() -> Dictionary:
	return {
		"time" = time, 
		"coord" = var_to_str(coord), 
		"type" = type
	}

static func deserialize_new(data: Dictionary) -> TileDestroyedEvent:
	var n = TileDestroyedEvent.new(data["time"], str_to_var(data["coord"]), data.get("type", -1))
	return n

func to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_float(time)
	stream.encode_vector2(coord)
	stream.encode_s8(type)
	return stream.data

static func from_bytes(buffer: PackedByteArray) -> TileDestroyedEvent:
	var stream: = PackedByteStream.from_bytes(buffer)

	return TileDestroyedEvent.new(stream.decode_float(), stream.decode_vector2(), stream.decode_s8())
