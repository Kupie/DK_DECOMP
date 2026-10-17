extends RefCounted

class_name MonsterKillEvent

const BYTE_SIZE: int = 5

var time: float
var monsterId: String

func _init(time: float, monsterId: String) -> void :
	self.time = time
	self.monsterId = monsterId

func serialize() -> Dictionary:
	return {
		"time" = time, 
		"monsterId" = monsterId
	}

static func deserialize_new(data: Dictionary) -> MonsterKillEvent:
	var n = MonsterKillEvent.new(data["time"], data["monsterId"])
	return n

func to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_float(time)
	stream.encode_u8(Utils.encode_monster_type(monsterId))
	return stream.data

static func from_bytes(buffer: PackedByteArray) -> MonsterKillEvent:
	var stream: = PackedByteStream.from_bytes(buffer)
	return MonsterKillEvent.new(stream.decode_float(), Utils.decode_monster_type(stream.decode_u8() as Monster.Type))
