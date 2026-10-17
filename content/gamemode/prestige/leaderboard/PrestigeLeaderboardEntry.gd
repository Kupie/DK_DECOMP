class_name PrestigeLeaderboardEntry
extends RefCounted

enum PlayerPlatform{
	STEAM = 0, 
	XBL = 1, 
	PSN = 2, 
	NX = 3
}

var legacy: bool = false
var score: int
var run_id: int
var with: String



var entity_id: String
var display_name: String
var rank: int




var dome_id: int
var keeper_id: int
var gadget_id: int
var world_id: int
var time: int
var base_per_wave: int
var multiplier: int
var wave: int
var won: int
var cheat_hash: int
var version_hash: int
var mode_variant: int
var blocks_mined: int
var travelled_distance: int
var monsters_killed: int
var resources_mined: int
var total_time_waves_were_present: int
var times_saved: int
var total_damage_taken: int
var gadgets_returned: int
var gadgets_shredded: int
var total_iron: int
var total_water: int
var total_cobalt: int
var times_stalled: int
var total_stall_time: int
var spawn_escalation: int
var game_time_without_delay: int
var platform_id: PlayerPlatform = PlayerPlatform.STEAM

func get_scores() -> PackedStringArray:
	if with.is_empty():
		return PackedStringArray([score, run_id])
	else:
		return PackedStringArray([score, run_id, with.hex_to_int()])

func get_metadata() -> String:
	var stream: = BitPackedByteStream.new()
	stream.pack_bits(dome_id, 3)
	stream.pack_bits(keeper_id, 2)
	stream.pack_bits(gadget_id, 3)
	stream.pack_bits(world_id, 4)
	stream.pack_bits(floori(time / 60.0), 11)
	stream.pack_bits(base_per_wave, 16)
	stream.pack_bits(multiplier, 16)
	stream.pack_bits(wave, 9)
	stream.pack_bits(won, 1)
	stream.pack_bits(cheat_hash, 16)
	stream.pack_bits(version_hash, 16)
	stream.pack_bits(mode_variant, 4)
	stream.pack_bits(blocks_mined, 16)
	stream.pack_bits(travelled_distance, 10)
	stream.pack_bits(monsters_killed, 20)
	stream.pack_bits(resources_mined, 14)
	stream.pack_bits(floori(total_time_waves_were_present / 60.0), 11)
	stream.pack_bits(times_saved, 10)
	stream.pack_bits(total_damage_taken, 20)
	stream.pack_bits(gadgets_returned, 8)
	stream.pack_bits(gadgets_shredded, 8)
	stream.pack_bits(total_iron, 14)
	stream.pack_bits(total_water, 14)
	stream.pack_bits(total_cobalt, 14)
	stream.pack_bits(times_stalled, 8)
	stream.pack_bits(floori(total_stall_time / 60.0), 11)
	stream.pack_bits(spawn_escalation, 8)
	stream.pack_bits(floori(game_time_without_delay / 60.0), 11)
	stream.pack_bits(platform_id, 3)

	return Base85.encode(stream.data.slice(0, 40))

func time_per_wave() -> float:
	return float(time) / float(wave)

func is_self() -> bool:
	if legacy:
		return entity_id == Platform.get_user_id()
	else:
		return entity_id == PlayFabServices.get_entity_id()

func set_platform(platform_id_string: String) -> void :
	match platform_id_string:
		CONST.PLATFORM_ID_STEAM:
			platform_id = PlayerPlatform.STEAM
		CONST.PLATFORM_ID_XBOX:
			platform_id = PlayerPlatform.XBL
		CONST.PLATFORM_ID_PSN:
			platform_id = PlayerPlatform.PSN
		CONST.PLATFORM_ID_SWITCH:
			platform_id = PlayerPlatform.NX

func get_platform_id_string() -> String:
	match platform_id:
		PlayerPlatform.STEAM:
			return CONST.PLATFORM_ID_STEAM
		PlayerPlatform.XBL:
			return CONST.PLATFORM_ID_XBOX
		PlayerPlatform.PSN:
			return CONST.PLATFORM_ID_PSN
		PlayerPlatform.NX:
			return CONST.PLATFORM_ID_SWITCH
		_:
			return "N/A"

static func from_legacy_leaderboard(result: Dictionary) -> PrestigeLeaderboardEntry:
	var steam_id: int = result.get("steam_id", 0)
	var player_name: String = Platform.getFriendPersonaName(result.get("steam_id", 0))
	var details: PackedInt32Array = result.get("details", [])
	var legacy_rank: int = result.get("global_rank", 0)
	var legacy_score: int = result.get("score", 0)




























	var entry: = PrestigeLeaderboardEntry.new()
	entry.legacy = true

	entry.score = legacy_score
	entry.rank = legacy_rank
	entry.entity_id = str(steam_id)
	entry.display_name = player_name

	entry.dome_id = details[0]
	entry.keeper_id = details[1]
	entry.gadget_id = details[2]
	entry.world_id = details[3]
	entry.time = details[4]
	entry.base_per_wave = details[5]
	entry.multiplier = details[6]
	entry.wave = details[7]
	entry.won = details[8]
	entry.cheat_hash = details[9]
	entry.version_hash = details[10]
	entry.mode_variant = details[11]
	entry.blocks_mined = details[12]
	entry.travelled_distance = details[13]
	entry.monsters_killed = details[14]
	entry.resources_mined = details[15]
	entry.total_time_waves_were_present = details[16]
	entry.times_saved = details[17]
	entry.total_damage_taken = details[18]
	entry.gadgets_returned = floori(details[19] / 100)
	entry.gadgets_shredded = details[19] %100
	entry.total_iron = details[20]
	entry.total_water = details[21]
	entry.total_cobalt = details[22]
	entry.times_stalled = details[23]
	entry.total_stall_time = details[24]
	entry.spawn_escalation = details[25]
	entry.game_time_without_delay = details[26]

	return entry

static func from_playfab_leaderboard(result: Dictionary) -> PrestigeLeaderboardEntry:
	var entry: = PrestigeLeaderboardEntry.new()

	entry.score = result["Score"].to_int()
	entry.rank = result["rank"]
	entry.run_id = result["RunID"].to_int()
	entry.display_name = result["display_name"]
	entry.entity_id = result["entity_id"]
	if result.get("With", "") != "":
		var with_bytes: = PackedByteArray()
		with_bytes.resize(8)
		with_bytes.encode_u64(0, int(result["With"]))
		with_bytes.reverse()
		entry.with = with_bytes.hex_encode().to_upper()

	if result["metadata"] != "":
		var metadata_bytes = Base85.decode(result["metadata"])
		var stream: = BitPackedByteStream.from_bytes(metadata_bytes)

		entry.dome_id = stream.unpack_bits(3)
		entry.keeper_id = stream.unpack_bits(2)
		entry.gadget_id = stream.unpack_bits(3)
		entry.world_id = stream.unpack_bits(4)
		entry.time = stream.unpack_bits(11) * 60.0
		entry.base_per_wave = stream.unpack_bits(16)
		entry.multiplier = stream.unpack_bits(16)
		entry.wave = stream.unpack_bits(9)
		entry.won = stream.unpack_bits(1)
		entry.cheat_hash = stream.unpack_bits(16)
		entry.version_hash = stream.unpack_bits(16)
		entry.mode_variant = stream.unpack_bits(4)
		entry.blocks_mined = stream.unpack_bits(16)
		entry.travelled_distance = stream.unpack_bits(10)
		entry.monsters_killed = stream.unpack_bits(20)
		entry.resources_mined = stream.unpack_bits(14)
		entry.total_time_waves_were_present = stream.unpack_bits(11) * 60.0
		entry.times_saved = stream.unpack_bits(10)
		entry.total_damage_taken = stream.unpack_bits(20)
		entry.gadgets_returned = stream.unpack_bits(8)
		entry.gadgets_shredded = stream.unpack_bits(8)
		entry.total_iron = stream.unpack_bits(14)
		entry.total_water = stream.unpack_bits(14)
		entry.total_cobalt = stream.unpack_bits(14)
		entry.times_stalled = stream.unpack_bits(8)
		entry.total_stall_time = stream.unpack_bits(11) * 60.0
		entry.spawn_escalation = stream.unpack_bits(8)
		entry.game_time_without_delay = stream.unpack_bits(11) * 60.0
		entry.platform_id = stream.unpack_bits(3) as PlayerPlatform

	return entry
