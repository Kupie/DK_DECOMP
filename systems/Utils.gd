extends Object
class_name Utils

static func shuffle(arr: Array, rand: RandomNumberGenerator) -> void :
	if arr.size() < 2:
		return

	for i in range(arr.size() - 1, 0, -1):
		var j = rand.randi() % (i + 1)
		var tmp = arr[j]
		arr[j] = arr[i]
		arr[i] = tmp

static func wakeUpDrop(r, force: bool = false):
	if r is Drop and (r.sleeping or force):
		r.sleeping = false
		r.apply_central_impulse(Vector2.UP)
		r.apply_torque_impulse(5)

static func get_side_string_from_bool(onRightSide: bool) -> String:
	return "right" if onRightSide else "left"

static func get_side_bool_from_string(side: String) -> bool:
	return side == "right"

static func get_other_side(side: String) -> String:
	return CONST.LEFT if side == CONST.RIGHT else CONST.RIGHT

static func encode_player_id(player_id: String) -> int:
	return int(player_id.lstrip("player"))

static func decode_player_id(player_id: int) -> String:
	return "player%d" % player_id

static func encode_team_id(team_id: String) -> int:
	return int(team_id.lstrip("team"))

static func decode_team_id(team_id: int) -> String:
	return "team%d" % team_id

static func encode_tech_id(tech_id: String) -> int:
	return int(tech_id.lstrip("keeper"))

static func decode_tech_id(tech_id: int) -> String:
	return "keeper%d" % tech_id

static func encode_color_id(color_id: String) -> int:
	return int(color_id.lstrip("color"))

static func decode_color_id(color_id: int) -> String:
	return "color%d" % color_id

static func encode_skin_id(skin_id: String) -> int:
	return int(skin_id.lstrip("skin"))

static func encode_platform_id(platform_id: String) -> int:
	return [CONST.PLATFORM_ID_DUMMY, CONST.PLATFORM_ID_STEAM, CONST.PLATFORM_ID_XBOX, CONST.PLATFORM_ID_PSN, CONST.PLATFORM_ID_SWITCH].find(platform_id)

static func decode_platform_id(platform_int: int) -> String:
	return [CONST.PLATFORM_ID_DUMMY, CONST.PLATFORM_ID_STEAM, CONST.PLATFORM_ID_XBOX, CONST.PLATFORM_ID_PSN, CONST.PLATFORM_ID_SWITCH][platform_int]

static func encode_monster_type(monster_string: String) -> Monster.Type:
	match monster_string:
		"walker":
			return Monster.Type.WALKER
		"flyer":
			return Monster.Type.FLYER
		"stingray":
			return Monster.Type.STINGRAY
		"mucker":
			return Monster.Type.MUCKER
		"bolter":
			return Monster.Type.BOLTER
		"driller":
			return Monster.Type.DRILLER
		"shifter":
			return Monster.Type.SHIFTER
		"rockman":
			return Monster.Type.ROCKMAN
		"tormentor":
			return Monster.Type.TORMENTOR
		"butterfly":
			return Monster.Type.BUTTERFLY
		"beast":
			return Monster.Type.BEAST
		"worm":
			return Monster.Type.WORM
		"hornet":
			return Monster.Type.HORNET
		"diver":
			return Monster.Type.DIVER
		"tick":
			return Monster.Type.TICK
		"bigtick":
			return Monster.Type.BIGTICK
		"scarab":
			return Monster.Type.SCARAB
		"stag":
			return Monster.Type.STAG
		"breeder":
			return Monster.Type.BREEDER
		"phaser":
			return Monster.Type.PHASER
		"bloater":
			return Monster.Type.BLOATER
		"burrower":
			return Monster.Type.BURROWER
		"scarabarm":
			return Monster.Type.SCARABARM

	push_error("Unknown Monster Type: ", monster_string)
	return Monster.Type.WALKER

static func decode_monster_type(monster_type: Monster.Type) -> String:
	match monster_type:
		Monster.Type.WALKER:
			return "walker"
		Monster.Type.FLYER:
			return "flyer"
		Monster.Type.STINGRAY:
			return "stingray"
		Monster.Type.MUCKER:
			return "mucker"
		Monster.Type.BOLTER:
			return "bolter"
		Monster.Type.DRILLER:
			return "driller"
		Monster.Type.SHIFTER:
			return "shifter"
		Monster.Type.ROCKMAN:
			return "rockman"
		Monster.Type.TORMENTOR:
			return "tormentor"
		Monster.Type.BUTTERFLY:
			return "butterfly"
		Monster.Type.BEAST:
			return "beast"
		Monster.Type.WORM:
			return "worm"
		Monster.Type.HORNET:
			return "hornet"
		Monster.Type.DIVER:
			return "diver"
		Monster.Type.TICK:
			return "tick"
		Monster.Type.BIGTICK:
			return "bigtick"
		Monster.Type.SCARAB:
			return "scarab"
		Monster.Type.STAG:
			return "stag"
		Monster.Type.BREEDER:
			return "breeder"
		Monster.Type.PHASER:
			return "phaser"
		Monster.Type.BLOATER:
			return "bloater"
		Monster.Type.BURROWER:
			return "burrower"
		Monster.Type.SCARABARM:
			return "scarabarm"

	push_error("Unknown Monster Type: ", monster_type)
	return "walker"

static func get_player_name(player_id: String, peer_id: int, device_id: int) -> String:
	if Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SPLITSCREEN or Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SINGLEPLAYER:
		return player_id.capitalize()


	var member: = Lobby.get_member(peer_id, device_id)
	if not is_instance_valid(member):
		return player_id.capitalize()

	var platform_user_id: String = member.platform_user_id

	var count_local_to_platform_user_id: = 0
	var local_index: = 0
	for m in Lobby.members:
		if m.peer_id == peer_id and m.device_id == device_id:
			local_index = count_local_to_platform_user_id
		if platform_user_id == m.platform_user_id:
			count_local_to_platform_user_id += 1

	var persona_name: String = member.platform_user_name

	var local_index_string: String = "" if local_index == 0 else " " + str(local_index)

	return persona_name + local_index_string

static func get_next_player_color() -> int:
	var nextColor: = 0
	for i in range(4):
		var hasColor: = false
		for k: Keeper in Keepers.getAll():
			if Utils.encode_color_id(k.colorId) == i:
				hasColor = true
				break
		if not hasColor:
			nextColor = i
			break
	return nextColor

static func get_position_relative_to_dome(pos: Vector2, teamId: String) -> Vector2:
	if not Level.domesByTeamId.has(teamId):
		assert ( not StageManager.isInLevel(), "Should be possible only in loadout versus")
		return pos
	pos.x -= Level.domesByTeamId[teamId].global_position.x
	return pos

static func get_global_from_local_dome_position(pos: Vector2, teamId: String) -> Vector2:
	pos.x += Level.domesByTeamId[teamId].global_position.x
	return pos

static func get_dome_position(teamId: String) -> Vector2:
	if Level.domesByTeamId.is_empty():

		return Vector2.ZERO
	return Level.domesByTeamId[teamId].global_position

static func get_nearest_parent_of_buildin_type(in_base_node: Node, in_type: String) -> Node:
	if not in_base_node.is_inside_tree():
		return null
	if in_base_node.get_parent() == null:
		return null
	if in_base_node.get_parent().is_class(in_type):
		return in_base_node.get_parent()
	return Utils.get_nearest_parent_of_buildin_type(in_base_node.get_parent(), in_type)


static func is_audio_stream_looping(stream: AudioStream) -> bool:
	if "loop" in stream:
		return stream.loop
	elif "loop_mode" in stream:
		return stream.loop_mode != 0
	return false

static func parse_vector2(value) -> Vector2:
	if value is Vector2 or value is Vector2i:
		return value
	var replaced: String = value.replace("(", "").replace(")", "")
	var split: = replaced.split(", ")
	return Vector2(float(split[0]), float(split[1]))

static func convertGamepadAxisInput(axis_value) -> float:
	if abs(axis_value) <= Options.gamepadStickDeadZone:
		return 0.0
	else:
		return (axis_value - (sign(axis_value) * Options.gamepadStickDeadZone)) * (1.0 / (1.0 - Options.gamepadStickDeadZone))

static func get_peer_device_composite_key(peer_id: int, device_id: int) -> String:
	return "%d-%d" % [peer_id, device_id]

static func clip_text(text: String, max_length: int, add_ellipsis: = false) -> String:
	if text.length() > max_length:
		text = text.substr(0, max_length)
		if add_ellipsis:
			text += "..."
		return text
	return text

static func is_position_in_secondary_station(position: Vector2, team_id: String) -> bool:
	if Level.domesByTeamId.size() == 0 or not Level.domesByTeamId.has(team_id):
		return false
	var pos_rel_to_dome: = get_position_relative_to_dome(position, team_id)
	return pos_rel_to_dome.y < CONST.DOME_SECONDARY_STATION_ENTRANCE_Y and pos_rel_to_dome.y > CONST.DOME_CELLAR_ENTRANCE_Y and pos_rel_to_dome.x < CONST.DOME_SECONDARY_STATION_ENTRANCE_X


static func get_local_team_id(peer_id: int) -> String:
	var local_team_id: String = ""
	for member in Lobby.members:
		if member.peer_id != peer_id:
			continue
		var team_id: = Utils.decode_team_id(member.team_id)
		if local_team_id == "":
			local_team_id = team_id
		elif local_team_id != team_id:
			local_team_id = "mixed"
			break

	return local_team_id

static func get_local_teams(peer_id: int) -> PackedStringArray:
	var localTeams: PackedStringArray = PackedStringArray()
	for member: Lobby.Member in Lobby.members:
		if member.peer_id != peer_id:
			continue
		localTeams.append(Utils.decode_team_id(member.team_id))
	return localTeams

static func get_full_upgrade_id(base_id: String, team_id: String, player_id: String) -> String:
	if base_id.contains("team") or base_id.contains("player"):
		return base_id

	if (base_id.contains(".") and base_id.split(".")[0].contains("keeper")):
		return player_id + "." + base_id
	if Data.gadgets.has(base_id):
		if Data.gadgets[base_id].get("takeslots", []).has("keepersuit"):
			return player_id + "." + base_id
	return team_id + "." + base_id


static func encode_animated_sprite2d_state(out_stream: PackedByteStream, in_sprite: AnimatedSprite2D) -> void :
	out_stream.encode_var(in_sprite.animation)
	out_stream.encode_bool(in_sprite.is_playing())
	out_stream.encode_bool(in_sprite.visible)
	out_stream.encode_float(in_sprite.speed_scale)
	out_stream.encode_u32(in_sprite.frame)
	out_stream.encode_float(in_sprite.frame_progress)

static func decode_animated_sprite2d_state(in_stream: PackedByteStream, out_sprite: AnimatedSprite2D) -> void :
	var anim: StringName = in_stream.decode_var()
	var is_playing: bool = in_stream.decode_bool()
	if is_playing:
		out_sprite.play(anim)
	out_sprite.visible = in_stream.decode_bool()
	var speed: float = in_stream.decode_float()
	out_sprite.speed_scale = speed
	out_sprite.frame = in_stream.decode_u32()
	out_sprite.frame_progress = in_stream.decode_float()

static func combined_set(current: Array, added: Array) -> Array:
	var combined: Dictionary = {}
	for element in current:
		combined[element] = 1
	for element in added:
		combined[element] = 1
	return combined.keys()

static func combined_skin_dict(current: Dictionary, added: Dictionary) -> Dictionary:
	var result: = current.duplicate()
	for key in added:
		result[key] = combined_set(result.get(key, []), added[key])
	return result
