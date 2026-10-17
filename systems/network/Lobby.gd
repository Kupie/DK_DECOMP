extends Node

signal member_added(member: Member)
signal member_removed(member: Member)
signal member_color_updated(member: Member)
signal member_device_updated(peer_id: int, old_device_id: int, new_device_id: int)

var members: Array[Member]


var time_since_last_recent_player_update: = 0.0
var time_between_recent_player_update: = 10

class Member:
	var peer_id: int = 1
	var team_id: int = 1
	var player_id: int = -1
	var device_id: int = -2
	var skin_id: int
	var color_id: int
	var keeper_id: int = 1
	var playfab_id: String
	var platform_id: String
	var platform_user_id: String
	var platform_user_name: String
	var platform_block_list: Array

func _process(delta: float) -> void :
	if BuildCustomization.has_feature("recent_player_update"):
		time_since_last_recent_player_update += delta
		if time_since_last_recent_player_update > time_between_recent_player_update:
			var local_peer_id = multiplayer.get_unique_id()
			var local_platform_id = Platform.get_platform_id()
			for member in members:
				if local_peer_id == member.peer_id or local_platform_id != member.platform_id:
					continue
				PlayFabServices.update_recent_player(member.platform_user_id)
			time_since_last_recent_player_update = 0

@rpc("any_peer", "reliable")
func add_bulk(peer_id: int, device_ids: PackedInt32Array, player_ids: PackedStringArray, playfab_id: String, platform_id: String, platform_user_ids: PackedStringArray, platform_user_names: PackedStringArray) -> void :
	for i in range(device_ids.size()):
		var player_id: = -1
		if i < player_ids.size():
			player_id = Utils.encode_player_id(player_ids[i])

		add(peer_id, device_ids[i], playfab_id, platform_id, platform_user_ids[i], platform_user_names[i], player_id)
	send_lobby_update()

func can_add_new_member() -> bool:
	return Lobby.members.size() < Const.MAX_NMB_OF_PLAYERS

func local_member_count() -> int:
	var count: = 0
	for member in members:
		if member.peer_id == multiplayer.get_unique_id():
			count += 1

	return count

func simple_add(device_id: int, player_id: int = -1) -> void :
	var platform_user_id: String
	var platform_user_name: String
	if BuildCustomization.has_feature("enable_multiple_local_account"):

		platform_user_id = Platform.get_user_id_per_device_id(device_id)
		platform_user_name = Platform.get_username_per_device_id(device_id)
	else:

		platform_user_id = Platform.get_user_id()
		platform_user_name = Platform.get_username()

	Network.rpc_server(add.bind(
		multiplayer.get_unique_id(), 
		device_id, 
		PlayFabServices.get_entity_id(), 
		Platform.get_platform_id(), 
		platform_user_id, 
		platform_user_name, 
		player_id, 
	))

@rpc("any_peer", "reliable")
func add(peer_id: int, device_id: int, playfab_id: String, platform_id: String, platform_user_id: String, platform_user_name: String, player_id: int = -1, send_network_update: bool = true) -> void :
	_add(peer_id, device_id, player_id, playfab_id, platform_id, platform_user_id, platform_user_name, send_network_update)

func _add(peer_id: int, device_id: int, player_id: int, playfab_id: String, platform_id: String, platform_user_id: String, platform_user_name: String, send_network_update: bool) -> void :
	var member: = Member.new()
	if peer_id == 0:
		peer_id = 1

	member.peer_id = peer_id
	member.playfab_id = playfab_id
	member.platform_id = platform_id
	member.platform_user_id = platform_user_id
	member.platform_user_name = platform_user_name

	if player_id == -1:
		member.player_id = get_next_player_id(member.platform_user_id, device_id)
	else:
		member.player_id = player_id

	member.device_id = device_id

	if Level.loadout.modeId == CONST.MODE_VERSUS:
		if Keepers.get_team("team1").getCount() > Keepers.get_team("team2").getCount():
			member.team_id = 2
		else:
			member.team_id = 1
	else:
		member.team_id = 1

	members.append(member)
	if send_network_update and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:


		send_lobby_update()
	member_added.emit(member)



@rpc("any_peer", "reliable")
func remove(device_id: int, caller_peer_nmb_of_local_keepers: int) -> void :
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = multiplayer.get_unique_id()

	var existing: Member
	for member in members:
		if member.device_id == device_id and member.peer_id == peer_id:
			existing = member

	if is_instance_valid(existing):
		Network.rpc_for_states(emit_member_removed.bind(existing.peer_id, existing.device_id), [Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC, Network.ConnectionState.LOADOUT_STAGE_SYNC, Network.ConnectionState.LEVEL_STAGE_SYNC], true)
		members.erase(existing)
		send_lobby_update()

@rpc("reliable")
func emit_member_removed(peer_id: int, device_id: int) -> void :
	var existing: Member
	for member in members:
		if member.device_id == device_id and member.peer_id == peer_id:
			existing = member
	if is_instance_valid(existing):
		member_removed.emit(existing)

@rpc("reliable", "any_peer", "call_local")
func update_device_id(old_device_id: int, new_device_id: int) -> void :
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = 1

	for member in members:
		if member.device_id == old_device_id and member.peer_id == peer_id:
			member.device_id = new_device_id
			member_device_updated.emit(peer_id, old_device_id, new_device_id)

@rpc("reliable", "any_peer", "call_local")
func update_color(player_id: int, color_id: int) -> void :
	for member in members:
		if member.player_id == player_id:
			member.color_id = color_id
			member_color_updated.emit(member)
			break

@rpc("reliable", "any_peer", "call_local")
func update_team_id(player_id: int, team_id: int) -> void :
	for member in members:
		if member.player_id == player_id:
			member.team_id = team_id
			break

@rpc("reliable", "any_peer", "call_local")
func update_member(peer_id: int, device_id: int, new_player_id: int, new_team_id: int, new_keeper_id: int, new_color_id: int, new_skin_id: int) -> void :
	for member in members:
		if member.peer_id == peer_id and member.device_id == device_id:
			member.player_id = new_player_id
			member.team_id = new_team_id
			member.keeper_id = new_keeper_id
			member.color_id = new_color_id
			member.skin_id = new_skin_id
			break

func get_next_player_id(platform_user_id: String, device_id: int) -> int:
	for i in range(members.size()):
		var new_player_id = i + 1
		var already_exists: = false
		for member in members:
			if member.player_id == new_player_id:
				already_exists = true
				break
		if not already_exists:
			return new_player_id
	return members.size() + 1

func remove_from_peer(peer_id: int) -> void :
	var i: int = members.size()
	while i > 0 and members.size() > 0:
		i -= 1
		if members[i].peer_id == peer_id:
			member_removed.emit(members[i])
			if members.size() > i:
				members.erase(members[i])

	send_lobby_update()

@rpc("reliable")
func lobby_update(data: PackedByteArray):
	members.clear()
	var stream: = PackedByteStream.from_bytes(data)
	while stream.is_not_finished():
		var member: = Member.new()
		member.peer_id = stream.decode_u32()
		member.player_id = stream.decode_u8()
		member.team_id = stream.decode_u8()
		member.device_id = stream.decode_s8()
		member.skin_id = stream.decode_u8()
		member.color_id = stream.decode_u8()
		member.keeper_id = stream.decode_u8()
		member.playfab_id = stream.decode_var()
		member.platform_id = Utils.decode_platform_id(stream.decode_u8())
		member.platform_user_id = stream.decode_var()
		member.platform_user_name = stream.decode_var()
		members.append(member)
		if not multiplayer.is_server():
			_ensure_loadout_in_sync(member)


func _ensure_loadout_in_sync(in_member: Member) -> void :
	for lk: LoadoutKeeper in Level.loadout.keepers:
		var same_player: bool = lk.peerId == in_member.peer_id and lk.playerId.to_int() == in_member.player_id
		if same_player:
			lk.deviceId = in_member.device_id

func send_lobby_update():
	if members.size() == 0:
		clear.rpc()
		return

	var stream: = PackedByteStream.new()
	for m in members:
		stream.encode_u32(m.peer_id)
		stream.encode_u8(m.player_id)
		stream.encode_u8(m.team_id)
		stream.encode_s8(m.device_id)
		stream.encode_u8(m.skin_id)
		stream.encode_u8(m.color_id)
		stream.encode_u8(m.keeper_id)
		stream.encode_var(m.playfab_id)
		stream.encode_u8(Utils.encode_platform_id(m.platform_id))
		stream.encode_var(m.platform_user_id)
		stream.encode_var(m.platform_user_name)
	lobby_update.rpc(stream.data)

@rpc("reliable")
func clear() -> void :
	members.clear()

func get_member_by_player_id(player_id: String) -> Member:
	for member in members:
		if member.player_id == Utils.encode_player_id(player_id):
			return member
	return null

func get_member(peer_id: int, device_id: int) -> Member:
	for member in members:
		if member.peer_id == peer_id and member.device_id == device_id:
			return member
	return null

func reset_state() -> void :
	members.clear()
