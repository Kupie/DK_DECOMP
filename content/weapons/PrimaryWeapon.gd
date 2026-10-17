extends Node2D

class_name PrimaryWeapon

var UID: int
var teamId: String
var showcaseMode: = false
var hitMonsterUIDs: Array[Dictionary]
var started: = false
var deviceId: int

func _ready():
	add_to_group(teamId + "-primaryweapon")

func start():
	pass

func stop():
	pass

func inputs(moveValue: Vector2, fireValue: float, specialValue: float, mouseGlobal: Vector2 = Vector2()):
	pass

func get_hit_data() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_u16(hitMonsterUIDs.size())
	for hitData in hitMonsterUIDs:
		stream.encode_u32(hitData["uid"])
		stream.encode_var(hitData["source"])
		stream.encode_float(hitData["damage"])
		stream.encode_float(hitData["stun"])

	hitMonsterUIDs.clear()
	return stream.data

func set_hit_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var size: = stream.decode_u16()
	for _i in range(size):
		var monsterUID: = stream.decode_u32()
		if Level.monstersByTeamId[teamId].hasMonster(monsterUID):
			Level.monstersByTeamId[teamId].getMonster(monsterUID).hit(stream.decode_var(), stream.decode_float(), stream.decode_float())

func hitMonster(monster: Monster, source: String, damage: float, stun: float) -> void :
	if not is_multiplayer_authority():
		return

	monster.hit(source, damage, stun)
	if monster.hittable:
		var hitData: = {
			"uid": monster.UID, 
			"source": source, 
			"damage": damage, 
			"stun": stun
		}
		hitMonsterUIDs.append(hitData)

func remove():
	queue_free()
