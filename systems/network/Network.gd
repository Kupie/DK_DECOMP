extends Node

enum ConnectionState{
	HANDSHAKE = 7, 
	CONNECTING = 0, 
	STAGE_TRANSITION = 1, 
	LOADOUT_STAGE_SPAWN = 2, 
	LOADOUT_STAGE_SYNC = 3, 
	LEVEL_STAGE_MAP_DATA = 4, 
	LEVEL_STAGE_SPAWN = 5, 
	LEVEL_STAGE_SYNC = 6, 
	DEVICE_SELECTION_CLIENT_ONLY = 8, 
	DEVICE_SELECTION_STAGE_SPAWN = 9, 
	DEVICE_SELECTION_STAGE_SYNC = 10, 
}

enum MultiplayerMode{
	OFFLINE_SINGLEPLAYER, 
	ONLINE_ENET, 
	ONLINE_PLATFORM, 
	ONLINE_CROSSPLAY, 
	OFFLINE_SPLITSCREEN
}

const TIMEOUT: = 60.0
const TIMEOUT_DEV: = 60.0
const ENET_LISTEN_PORT: int = 8742
const NETWORK_POSITION_TICK_RATE: float = 1.0 / 60.0
const JOIN_CODE_UNAVAILABLE: = "multiplayer.host.joincodeunavailable"
const XUID_UNAVAILABLE = 0

signal network_tick(tick: int)
signal client_ready(client_peer_id: int)
signal lobby_ready
signal join_code_failed(reason: String)
signal stats_set
signal upgrades_set
signal ping_read(new_ping_ms: int)
signal peer_disconnected

var local_connection_state: ConnectionState = ConnectionState.HANDSHAKE

var tick_count: int = 0
var tick_process_frame: int = -1

var clients: Array[Client]
var chunker: Chunker
var _pinger: Pinger
var _tick_calibrator: TickCalibrator

var playfab_initialized: = false
var multiplayer_mode: = MultiplayerMode.OFFLINE_SINGLEPLAYER:
	get:
		return multiplayer_mode
	set(v):

		if GameWorld.devMode:
			print("multiplayer mode set to ", v)
		multiplayer_mode = v
var join_code: String = JOIN_CODE_UNAVAILABLE
var original_window_title: String

var connection_state_cache: Dictionary = {}
var viewport_sizes_by_player_id: = {}

var xuid_cb: Callable
var xuid_cache: = {}

func _ready() -> void :

	set_physics_process(false)
	process_physics_priority = 255

	PlayFabServices.logged.connect(_on_playfab_logged)
	PlayFabServices.lobby_created.connect(_on_playfab_lobby_created)
	PlayFabServices.logged_in.connect(_on_playfab_logged_in, CONNECT_ONE_SHOT)
	Platform.platform_lobby_created.connect(_on_platform_lobby_created)
	Platform.platform_lobby_joined.connect(_on_platform_lobby_joined)
	Platform.crossplay_lobby_joined.connect(_on_crossplay_lobby_joined)
	Platform.join_lobby_failed.connect(display_error.bind("multiplayer.error.lobby.join"))
	PlayFabServices.join_lobby_failed.connect(display_error.bind("multiplayer.error.lobby.join"))
	PlayFabServices.cloud_script_response.connect(_on_cloud_script_response)
	PlayFabServices.local_endpoint_disconnected.connect(_on_local_endpoint_disconnected)

	original_window_title = get_window().title

	chunker = Chunker.new()

	add_child(chunker)
	_pinger = Pinger.new()
	_pinger.new_read.connect(_on_pinger_new_read)
	add_child(_pinger)

	_tick_calibrator = TickCalibrator.new()
	_tick_calibrator.name = "TickCalibrator"
	add_child(_tick_calibrator)

func _on_pinger_new_read(new_ping_ms: int) -> void :
	ping_read.emit(new_ping_ms)

func get_current_ping_ms() -> int:
	return _pinger.get_current_ping_ms()

func is_server() -> bool:
	if not multiplayer.has_multiplayer_peer():

		return true
	return multiplayer.is_server()

func is_client() -> bool:
	if not multiplayer.has_multiplayer_peer():

		return false
	return not multiplayer.is_server()

func in_crossplay_game() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false

	return multiplayer.multiplayer_peer is PlayFabPartyMultiplayerPeer

func _physics_process(delta):
	var current_frame: = Engine.get_process_frames()
	tick_count += 1

	if tick_process_frame == current_frame:
		return

	network_tick.emit(tick_count)
	tick_process_frame = current_frame
	_tick_calibrator.update(tick_count)


func _on_playfab_logged_in():
	playfab_initialized = true

func _on_playfab_logged(message: String) -> void :
	Logger.info(message)

func create_platform_lobby() -> void :


	Network.multiplayer_mode = Network.MultiplayerMode.ONLINE_PLATFORM
	Platform.create_platform_lobby()

func _on_platform_lobby_created(peer: MultiplayerPeer, lobby_id: int) -> void :
	connection_state_cache.clear()
	Data.track_changes()
	tick_count = 0
	set_physics_process(true)

	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)

	if GameWorld.devMode and ClassDB.class_exists("SteamMultiplayerPeer"):
		peer.debug_level = ClassDB.class_get_integer_constant("SteamMultiplayerPeer", "DEBUG_LEVEL_PEER")
	peer.host_with_lobby(lobby_id)
	multiplayer.multiplayer_peer = peer

	push_warning("Created platform-only lobby")
	if GameWorld.devMode:
		get_window().title = original_window_title + " [HOST]"

	Discovery.stop_discovering()

func _on_platform_lobby_joined(peer: MultiplayerPeer, lobby_id: int) -> void :
	connection_state_cache.clear()
	Network.multiplayer_mode = Network.MultiplayerMode.ONLINE_PLATFORM

	set_physics_process(true)

	multiplayer.peer_connected.connect(on_client_peer_connected)
	multiplayer.peer_disconnected.connect(on_client_peer_disconnected)

	multiplayer.connected_to_server.connect(on_client_connected)
	multiplayer.server_disconnected.connect(on_client_disconnected_from_server)

	if GameWorld.devMode and ClassDB.class_exists("SteamMultiplayerPeer"):
		peer.debug_level = ClassDB.class_get_integer_constant("SteamMultiplayerPeer", "DEBUG_LEVEL_PEER")
	peer.connect_to_lobby(lobby_id)
	multiplayer.multiplayer_peer = peer

	push_warning("Joined platform lobby")
	if GameWorld.devMode:
		get_window().title = original_window_title + " [CLIENT]"

	Discovery.stop_discovering()

func create_crossplay_lobby():
	if not playfab_initialized:
		return

	Network.multiplayer_mode = Network.MultiplayerMode.ONLINE_CROSSPLAY
	Data.track_changes()
	tick_count = 0
	set_physics_process(true)

	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)

	create_playfab_lobby()
	set_lobby_crossplay_status(GameWorld.is_crossplay_enabled())

	Discovery.stop_discovering()

func create_playfab_lobby():
	connection_state_cache.clear()
	var peer: = PlayFabPartyMultiplayerPeer.new()
	peer.logged.connect(_on_playfab_logged)
	peer.create_with_lobby(Platform.get_username(), Version.VERSION, Platform.get_playfab_lobby_access_policy())
	peer.create_network_failed.connect(_on_create_network_failed)
	multiplayer.multiplayer_peer = peer
	push_warning("Created playfab lobby")
	if GameWorld.devMode:
		get_window().title = original_window_title + " [HOST]"

func _on_create_network_failed(error: String):
	var reason = "multiplayer.error.lobby.host" if Network.is_network_ready(true) else "network.error.offline"
	display_error(error, reason)

func _on_playfab_lobby_created(lobby: PlayFabLobby):
	lobby_ready.emit()
	var connection_string = lobby.get_connection_string()
	Platform.create_crossplay_lobby(connection_string)
	request_join_code(connection_string)

func _on_crossplay_lobby_joined(connection_string: String):
	connection_state_cache.clear()
	Network.multiplayer_mode = Network.MultiplayerMode.ONLINE_CROSSPLAY

	var peer: = PlayFabPartyMultiplayerPeer.new()
	peer.join_lobby(connection_string)
	peer.connect_to_network_failed.connect(display_error.bind("multiplayer.error.connection"))
	peer.create_endpoint_failed.connect(display_error.bind("multiplayer.error.lobby.join"))

	set_physics_process(true)
	peer.logged.connect(_on_playfab_logged)

	multiplayer.peer_connected.connect(on_client_peer_connected)
	multiplayer.peer_disconnected.connect(on_client_peer_disconnected)

	multiplayer.connected_to_server.connect(on_client_connected)
	multiplayer.server_disconnected.connect(on_client_disconnected_from_server)

	multiplayer.multiplayer_peer = peer
	push_warning("Joined playfab lobby")
	if GameWorld.devMode:
		get_window().title = original_window_title + " [CLIENT]"

	Discovery.stop_discovering()

func request_join_code(connection_string: String) -> void :
	PlayFabServices.execute_cloud_script("getJoinCodeFromConnectionString", {
		"connectionString": connection_string, 
	})

func join_from_code(join_code: String) -> void :
	if not is_network_ready(true):
		join_code_failed.emit("network.error.offline")
	self.join_code = join_code
	PlayFabServices.execute_cloud_script("getConnectionStringFromJoinCode", {
		"joinCode": join_code, 
	})

func release_join_code() -> void :
	PlayFabServices.execute_cloud_script("releaseJoinCode", {})

func get_xuid_from_entity_id(entity_id: String, cb: Callable) -> void :
	if xuid_cache.has(entity_id):
		cb.call(xuid_cache[entity_id])
	else:
		xuid_cb = cb
		PlayFabServices.execute_cloud_script("getXuidFromPlayFabId", {
			"playFabId": entity_id, 
		})

func _on_cloud_script_response(function_name: String, result: Dictionary) -> void :
	match function_name:
		"getConnectionStringFromJoinCode":
			if result.get("error", false) or result.get("connectionString", null) == null:
				join_code = JOIN_CODE_UNAVAILABLE
				var reason = "multiplayer.error.joincodefailed" if not result.get("network_error", false) else "network.error.offline"
				join_code_failed.emit(reason)
				return

			_on_crossplay_lobby_joined(result["connectionString"])
		"getJoinCodeFromConnectionString":
			join_code = result.get("joinCode", JOIN_CODE_UNAVAILABLE)
		"releaseJoinCode":
			join_code = JOIN_CODE_UNAVAILABLE
		"getXuidFromPlayFabId":
			if not result.get("error", false):
				var decimal_xuid = result.get("xuid", XUID_UNAVAILABLE)
				var hexa_xuid = "%x" % int(decimal_xuid)
				if (decimal_xuid != str(XUID_UNAVAILABLE)):
					xuid_cache[result.get("playFabId")] = hexa_xuid
				if xuid_cb.is_valid():
					xuid_cb.call(hexa_xuid)
		_:
			push_warning("Unknown cloud script response: ", function_name)

func display_error(error_message: String, public_message: String) -> void :
	push_error(error_message)
	close_session(public_message, false, "ERROR: " + error_message if GameWorld.devMode else "")

func _on_local_endpoint_disconnected():
	close_session("network.error.offline")



func create_enet_host() -> void :
	connection_state_cache.clear()
	Network.multiplayer_mode = Network.MultiplayerMode.ONLINE_ENET
	push_warning("Starting IP Server")
	if GameWorld.devMode:
		get_window().title = original_window_title + " [HOST]"
	var peer: = ENetMultiplayerPeer.new()

	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)

	var err: = peer.create_server(ENET_LISTEN_PORT)
	if err:
		push_error(err)
		return

	multiplayer.multiplayer_peer = peer
	Data.track_changes()
	tick_count = 0
	set_physics_process(true)

	Discovery.start_discovery_server()

func create_enet_client(host: String, port: int) -> void :
	connection_state_cache.clear()
	Network.multiplayer_mode = Network.MultiplayerMode.ONLINE_ENET
	StageManager.startStage("stages/client/loading")

	push_warning("Connecting to IP Server: ", host, ":", port)
	if GameWorld.devMode:
		get_window().title = original_window_title + " [CLIENT]"
	var peer: = ENetMultiplayerPeer.new()

	multiplayer.peer_connected.connect(on_client_peer_connected)
	multiplayer.peer_disconnected.connect(on_client_peer_disconnected)
	multiplayer.connected_to_server.connect(on_client_connected)
	multiplayer.server_disconnected.connect(on_client_disconnected_from_server)

	var err: = peer.create_client(host, port)
	if err:
		push_error(err)

	multiplayer.multiplayer_peer = peer
	set_physics_process(true)

	Discovery.stop_discovering()


func return_party_to_loadout() -> void :
	for client in Network.clients:
		client.start_stage("stages/client/loading")
	StageManager.startStage("stages/loadout/multiplayerloadout")

func restart_run() -> void :
	var startData = LevelStartData.new()
	startData.loadout = Level.loadout.asLoadoutWithTemplates()
	if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		startData.tileDataPresetId = "Exhibition"
	Level.randomizeSeed()
	for client in Network.clients:
		if client.isInDeviceSelectionScreen():
			client.session_ended()
			continue
		client.start_stage("stages/client/loading")

	StageManager.startStage("stages/landing/landing", [startData, true])

func reset_session_state(kicked: bool = false) -> void :

	if is_server() and in_crossplay_game():
		release_join_code()
	join_code = JOIN_CODE_UNAVAILABLE


	if not kicked:
		var local_members: Array[Lobby.Member] = []
		for member in Lobby.members:
			if member.peer_id == multiplayer.get_unique_id():
				local_members.append(member)
				Network.rpc_server(Lobby.remove.bind(member.device_id, Keepers.local.getCount()))



		for peer_id in multiplayer.get_peers():
			on_client_peer_disconnected(peer_id)

	Lobby.reset_state()
	connection_state_cache.clear()

	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	clients.clear()
	chunker.reset()
	Data.stop_tracking()
	GameWorld.unlocks.clear()
	Platform.leave_lobby()
	Discovery.stop_discovery_server()
	SaveGame.currentLoadingSavegame = false
	SaveGame.loadRollingMetaState()

	if multiplayer.peer_connected.is_connected(on_peer_connected):
		multiplayer.peer_connected.disconnect(on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(on_peer_disconnected)
	if multiplayer.peer_connected.is_connected(on_client_peer_connected):
		multiplayer.peer_connected.disconnect(on_client_peer_connected)
	if multiplayer.peer_disconnected.is_connected(on_client_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(on_client_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(on_client_connected):
		multiplayer.connected_to_server.disconnect(on_client_connected)
	if multiplayer.server_disconnected.is_connected(on_client_disconnected_from_server):
		multiplayer.server_disconnected.disconnect(on_client_disconnected_from_server)

func close_session(message: String = "", kicked: bool = false, additional_message: String = "") -> void :
	reset_session_state(kicked)

	if not StageManager.isInLoading():
		StageManager.startStage("stages/client/loading")
		await StageManager.stage_started

	var startMode = "" if message == "" else CONST.SHOW_MESSAGE
	StageManager.startStage.call_deferred("stages/title/title", [startMode, message, additional_message])


func update_local_connection_state(connection_state: ConnectionState) -> void :
	local_connection_state = connection_state
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		set_connection_state.rpc(connection_state)

@rpc("reliable", "any_peer")
func set_connection_state(connection_state: ConnectionState) -> void :
	connection_state_cache[multiplayer.get_remote_sender_id()] = connection_state
	for client in clients:
		if client.peer_id == multiplayer.get_remote_sender_id():
			client.connection_state = connection_state
			if multiplayer.is_server():
				do_work(client)
			break

@rpc("reliable")
func connect_state_update(buffer: PackedInt64Array) -> void :
	var updates: = buffer.size() / 2
	connection_state_cache.clear()
	for i in range(updates):
		var peer_id: int = buffer[i * 2]
		var state: ConnectionState = buffer[(i * 2) + 1] as ConnectionState
		connection_state_cache[peer_id] = state

	for client in clients:
		if connection_state_cache.has(client.peer_id):
			client.connection_state = connection_state_cache[client.peer_id]

func rpc_for_states(rpc_call: Callable, target_connection_states: Array[ConnectionState], call_local: bool = false) -> void :
	if call_local:
		rpc_call.call()

	for client in clients:
		if target_connection_states.has(client.connection_state):
			rpc_call.rpc_id(client.peer_id)

func rpc_if_state(rpc_call: Callable, connection_state: ConnectionState, call_local: bool = false) -> void :
	rpc_for_states(rpc_call, [connection_state, ], call_local)

@rpc("reliable")
func remote_start_stage(stage: String, data: Array):
	StageManager.startStage.call_deferred(stage, data)

@rpc("reliable")
func remote_set_map_data(size: int, compressed_buffer: PackedByteArray):
	var buffer: = compressed_buffer.decompress(size, FileAccess.CompressionMode.COMPRESSION_ZSTD)
	var map_data: Dictionary = bytes_to_var(buffer)
	if StageManager.isInClientLanding():
		StageManager.currentStage.remote_set_map_data(map_data)

@rpc("reliable")
func remote_set_upgrade_data(size: int, compressed_buffer: PackedByteArray):
	if StageManager.isInClientLanding() or StageManager.isInLevel():
		var buffer: = compressed_buffer.decompress(size, FileAccess.CompressionMode.COMPRESSION_ZSTD)
		var upgrade_data: Dictionary = bytes_to_var(buffer)
		StageManager.currentStage.remote_set_upgrade_data(upgrade_data)
		upgrades_set.emit()

@rpc("reliable")
func remote_set_landmark_data(biomes: PackedStringArray, chamber_placements: Dictionary, cave_placements: Dictionary):
	if StageManager.isInClientLanding():
		StageManager.currentStage.remote_set_landmark_data(biomes, chamber_placements, cave_placements)

@rpc("reliable")
func remote_set_chamber_ids(chamber_ids: Dictionary) -> void :
	GameWorld.setChamberIds(chamber_ids)

@rpc("reliable")
func remote_full_data_sync(size: int, compressed_buffer: PackedByteArray):
	var buffer: = compressed_buffer.decompress(size, FileAccess.CompressionMode.COMPRESSION_ZSTD)
	var values: Variant = bytes_to_var(buffer)
	if typeof(values) == TYPE_DICTIONARY:
		Data.values = values
		Data.full_sync_received.emit()
	else:
		push_error("Invalid data sync received.")

@rpc("reliable")
func remote_sync_ticks(server_ticks: int) -> void :
	tick_count = server_ticks

@rpc("reliable")
func remote_accept_handshake(server_ticks: int, crossplay: bool) -> void :
	tick_count = server_ticks
	set_lobby_crossplay_status(crossplay)
	GameWorld.send_unlocks_to_host()
	update_local_connection_state(ConnectionState.CONNECTING)

	Network.chunker.send(1, Chunker.ChunkRequestType.SET_CLIENT_BLOCK_LIST, Network.set_client_block_list.bind(BlockList.get_full_block_list()))

@rpc("reliable")
func remote_reject_handshake(reason: String) -> void :
	close_session(reason)

@rpc("reliable")
func remote_reject_due_game_end() -> void :
	assert (Network.is_client())
	close_session("multiplayer.error.gameresolved")

@rpc("reliable")
func remote_mods_mismatch(expected_mods: String) -> void :
	var parts: = expected_mods.split(",")
	var mods_formatted: String = "\n".join(parts)
	if mods_formatted == "":
		mods_formatted = "multiplayer.error.nomods"
	close_session("multiplayer.error.modsmismatched", false, mods_formatted)

@rpc("reliable")
func remote_set_recorder_data(buffer: PackedByteArray):
	Recorder.from_bytes(buffer)

@rpc("reliable")
func remote_set_run_stats(buffer: PackedByteArray) -> void :
	GameWorld.run_stats_from_bytes(buffer)
	stats_set.emit()

@rpc("reliable")
func remote_set_gadgets(gadgets: Dictionary) -> void :
	var additionalGadgets = Level.loadout.domes[0].additionalGadgets
	for team_id in gadgets.keys():
		for gadget_id: String in gadgets[team_id]:
			var generic_id: = gadget_id.split(".")[1]
			if additionalGadgets.has(generic_id):
				continue
			GameWorld.addUpgrade(gadget_id, team_id)

@rpc("reliable")
func remote_set_tile_state_data(tile_state_data: PackedByteArray) -> void :
	Level.map.setTileStateData(tile_state_data)

@rpc("reliable")
func remote_show_crossplay_system_popup() -> void :
	while not StageManager.isInLoading():

		await get_tree().process_frame
	var timer: = StageManager.currentStage.timeoutTimer as Timer
	timer.paused = true

	print("Openning crossplay resolution system popup")
	Platform.check_crossplay_privilege( func(result): call_deferred("network_finish_show_crossplay_system_popup", result))

@rpc("reliable")
func remote_disconnect_client() -> void :
	close_session("multiplayer.error.disconnected", true)

func network_finish_show_crossplay_system_popup(result) -> void :
	if not StageManager.isInLoading():

		return
	var timer: = StageManager.currentStage.timeoutTimer as Timer
	timer.paused = false

	print("Closed crossplay resolution system popup with " + str(result))
	Network.rpc_server(finish_show_crossplay_system_popup.bind(result))




func do_work(client: Client) -> void :
	print("Client Update")
	print_connection_state(client.connection_state)

	match client.connection_state:
		ConnectionState.HANDSHAKE:

			pass
		ConnectionState.CONNECTING:


			Lobby.send_lobby_update()
			client.sync_ticks(Network.tick_count)
			client.full_data_sync()
			if StageManager.isInLoadout():
				client.start_stage("stages/loadout/multiplayerloadout", [
					Level.loadout.to_bytes(), 
					StageManager.currentStage.serializePreGeneratedMaps(), 
					Level.levelSeed, 
					GameWorld.unlocks.serialize(), 
					StageManager.currentStage.getTeamSelections(), 
					GameWorld.devMode
				])
			if StageManager.isInLanding():
				client.start_stage("stages/landing/clientlanding", [
					Level.loadout.to_bytes(), 
					Level.levelSeed, 
					false, 
					GameWorld.runTime
				])
			if StageManager.isInLevel():
				var playerIdByPeerDeviceId: = {}
				for keeper in Keepers.getAll():
					var key: = Utils.get_peer_device_composite_key(keeper.peerId, keeper.deviceId)
					playerIdByPeerDeviceId[key] = keeper.playerId
				client.start_stage("stages/deviceselection/deviceselection", [
					playerIdByPeerDeviceId, 
					Level.loadout.to_bytes(), 
					Level.loadout.loadout_keepers_to_bytes(), 
					true, 
					GameWorld.unlocks.serialize(), 
					{}])
			if StageManager.isInDeviceSelection():
				client.start_stage("stages/deviceselection/deviceselection", [
					StageManager.currentStage.playerIdByPeerDeviceId, 
					Level.loadout.to_bytes(), 
					Level.loadout.loadout_keepers_to_bytes(), 
					false, 
					GameWorld.unlocks.serialize(), 
					StageManager.currentStage.serializeMapData()
				])

		ConnectionState.STAGE_TRANSITION:

			pass

		ConnectionState.DEVICE_SELECTION_CLIENT_ONLY:
			pass

		ConnectionState.DEVICE_SELECTION_STAGE_SPAWN:
			client.full_data_sync()
			if StageManager.isInDeviceSelection():
				StageManager.currentStage.sendStageSpawnPackets(client.peer_id)

		ConnectionState.DEVICE_SELECTION_STAGE_SYNC:
			client.sync_ticks(Network.tick_count)
			client.full_data_sync()
			Level.map.tiles_node.network_tiles_to_destroy(client.peer_id)


			StageManager.currentStage.ensureKeepersUpToDate(client.peer_id)

		ConnectionState.LOADOUT_STAGE_SPAWN:
			client.full_data_sync()

			if StageManager.isInLoadout():
				StageManager.currentStage.sendStageSpawnPackets(client.peer_id)

		ConnectionState.LOADOUT_STAGE_SYNC:

			client.sync_ticks(Network.tick_count)
			client.full_data_sync()
			Level.map.tiles_node.network_tiles_to_destroy(client.peer_id)

		ConnectionState.LEVEL_STAGE_MAP_DATA:
			client.full_data_sync()


			if StageManager.isInLanding():
				var landingStage: = StageManager.currentStage as LandingStage
				if landingStage.generationFinished:
					client.set_map_data(landingStage.getMapData())
					client.set_landmark_data(landingStage.levelStartData.biomes, landingStage.levelStartData.chamberPlacements, landingStage.levelStartData.cavePlacements)
			elif StageManager.isInLevel():
				client.set_map_data(Level.map.getMapData())
				client.set_landmark_data(Level.map.biomes, Level.map.chamberPlacements, Level.map.cavePlacements)

		ConnectionState.LEVEL_STAGE_SPAWN:
			if StageManager.isInLevel():

				StageManager.currentStage.checkForGroupPause()
				StageManager.currentStage.sendStageSpawnPackets(client.peer_id)
				client.set_gadgets(GameWorld.addedGadgetIds)
				client.set_tile_state_data(Level.map.getTileStateData())
			client_ready.emit(client.peer_id)
			return

		ConnectionState.LEVEL_STAGE_SYNC:
			client.sync_ticks(Network.tick_count)
			client.full_data_sync()
			Level.map.tiles_node.network_tiles_to_destroy(client.peer_id)
			client.set_upgrade_data(GameWorld.getUpgradeData())
			client.set_chamber_ids(GameWorld.getChamberIds())
			if StageManager.isInResolvedLevel():


				client.session_ended()

func send_handshake_request() -> void :
	var stream: = PackedByteStream.new()

	stream.encode_u16(Version.NETWORK_VERSION)
	stream.encode_var(Version.VERSION)
	stream.encode_var(Platform.get_platform_id())
	stream.encode_var(Platform.get_user_id())
	stream.encode_var(PlayFabServices.get_entity_id())
	stream.encode_bool(GameWorld.is_crossplay_enabled())
	stream.encode_var(ModLoaderUserProfile.get_active_mods_string())

	Network.rpc_server(client_handshake_request.bind(stream.data))

@rpc("reliable", "any_peer")
func client_handshake_request(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var sender_peer_id: = multiplayer.get_remote_sender_id()
	var client: = get_client(sender_peer_id)

	var client_network_version: = stream.decode_u16()
	if client_network_version != Version.NETWORK_VERSION:
		client.reject_handshake(tr("multiplayer.error.versionmismatch").format([Version.VERSION], "{}"))
		return

	client.handshake_data = {
		"network_version": client_network_version, 
		"version": stream.decode_var(), 
		"platform_id": stream.decode_var(), 
		"platform_user_id": stream.decode_var(), 
		"playfab_id": stream.decode_var(), 
		"crossplay": stream.decode_bool(), 
		"mods": stream.decode_var(), 
	}


	var host_mods: = ModLoaderUserProfile.get_active_mods_string()



	var client_count_without_member: = 0
	for c in clients:
		if c.peer_id == sender_peer_id:
			continue
		var keeper_count: = Keepers.get_peer(c.peer_id).getAll().size()
		if keeper_count == 0:
			client_count_without_member += 1

	if host_mods != client.handshake_data.mods:
		client.mods_mismatch(host_mods)
	elif not GameWorld.is_crossplay_enabled() and Platform.get_platform_id() != client.handshake_data.platform_id and multiplayer_mode != Network.MultiplayerMode.ONLINE_ENET:
		client.reject_handshake("multiplayer.error.hostcrossplaydisabled")
	elif clients.size() >= Const.MAX_NMB_OF_PLAYERS or Lobby.members.size() + client_count_without_member >= Const.MAX_NMB_OF_PLAYERS:
		client.reject_handshake("multiplayer.error.lobbyfull")
	elif (StageManager.isInLevel() or StageManager.isInDeviceSelection()) and (clients.size() + 1 > Level.loadout.keeperTemplates.size() or Keepers.getAll().size() >= Level.loadout.keeperTemplates.size()):
		client.reject_handshake("multiplayer.error.lobbyfull")
	elif StageManager.isSwitchingStage() or StageManager.isInLanding():


		client.reject_handshake("multiplayer.error.lobbyfull")
	elif StageManager.isInResolvedLevel():
		client.reject_handshake("multiplayer.error.gameresolved")
	elif GameWorld.is_crossplay_enabled() and not client.handshake_data.crossplay:
		if BuildCustomization.platform_has_feature(client.handshake_data.platform_id, "system_crossplay_option"):
			client.show_crossplay_system_popup()
		elif client.handshake_data.platform_id == CONST.PLATFORM_ID_STEAM or client.handshake_data.platform_id == CONST.PLATFORM_ID_DUMMY:

			client.accept_handshake(tick_count, GameWorld.is_crossplay_enabled())
		else:
			client.reject_handshake("multiplayer.error.clientcrossplaydisabled")
	else:
		client.accept_handshake(tick_count, GameWorld.is_crossplay_enabled())

@rpc("reliable", "any_peer")
func set_handshake_info(crossplay: bool, platform_user_id: String, platform_id: String, platform_username: String, playfab_id: String, mods: String, version: String) -> void :



	var client: = get_client(multiplayer.get_remote_sender_id())
	client.reject_handshake(tr("multiplayer.error.versionmismatch").format([Version.VERSION], "{}"))

@rpc("reliable", "any_peer")
func finish_device_selection(device_ids: PackedInt32Array, player_ids: PackedStringArray, playfab_id: String, platform_id: String, platform_user_ids: PackedStringArray, platform_user_names: PackedStringArray) -> void :
	var keeper_already_taken: = false
	for member in Lobby.members:
		var player_id_string: = Utils.decode_player_id(member.player_id)
		if player_ids.has(player_id_string):
			keeper_already_taken = true
			break

	var sender_peer_id: = multiplayer.get_remote_sender_id()
	var client = get_client(sender_peer_id)
	if keeper_already_taken:
		client.reject_handshake("multiplayer.error.keepertaken")
		return

	Lobby.add_bulk(sender_peer_id, device_ids, player_ids, playfab_id, platform_id, platform_user_ids, platform_user_names)
	client.start_stage("stages/landing/clientlanding", [
			Level.loadout.to_bytes(), 
			Level.levelSeed, 
			true, 
			GameWorld.runTime
		])

@rpc("reliable", "any_peer")
func finish_show_crossplay_system_popup(crossplay_activated: bool) -> void :
	var client: = get_client(multiplayer.get_remote_sender_id())
	client.handshake_data.crossplay = crossplay_activated

	if not crossplay_activated:
		client.reject_handshake("multiplayer.error.clientcrossplaydisabled")
		return

	client.accept_handshake(tick_count, GameWorld.is_crossplay_enabled())

@rpc("reliable", "any_peer")
func set_client_block_list(block_list: Dictionary) -> void :
	var client: = get_client(multiplayer.get_remote_sender_id())
	Logger.info("BlockList recieved for peer %s" % str(client.peer_id))
	client.block_list = block_list

	if is_client_blocked(client):
		client.reject_handshake("multiplayer.error.lobby.join")



func on_peer_connected(peer_id: int) -> void :
	var client: = Client.new()
	client.peer_id = peer_id
	client.connection_state = ConnectionState.HANDSHAKE
	clients.append(client)


	set_connection_state.rpc(local_connection_state)
	var buffer: = PackedInt64Array()
	var num_clients: = clients.size()
	buffer.resize(num_clients * 2)
	for i in range(num_clients):
		buffer[i * 2] = clients[i].peer_id
		buffer[(i * 2) + 1] = int(clients[i].connection_state)
	connect_state_update.rpc(buffer)


	do_work(client)

func on_peer_disconnected(peer_id: int) -> void :
	peer_disconnected.emit(peer_id)
	remove_client(peer_id)
	GameWorld.unlocks.remove_peer(peer_id)
	Keepers.unregisterRemoteKeepers(peer_id)
	Lobby.remove_from_peer(peer_id)



func on_client_peer_connected(peer_id: int) -> void :
	var client: = Client.new()
	client.peer_id = peer_id
	client.connection_state = connection_state_cache.get(peer_id, ConnectionState.CONNECTING)
	clients.append(client)

func on_client_peer_disconnected(peer_id: int) -> void :
	remove_client(peer_id)

func on_client_connected() -> void :

	if not StageManager.isInLoading():
		StageManager.startStage("stages/client/loading")

	Lobby.clear()

	if multiplayer.multiplayer_peer is PlayFabPartyMultiplayerPeer:
		Network.multiplayer_mode = Network.MultiplayerMode.ONLINE_CROSSPLAY
	elif multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		Network.multiplayer_mode = Network.MultiplayerMode.ONLINE_ENET
	else:
		Network.multiplayer_mode = Network.MultiplayerMode.ONLINE_PLATFORM

	send_handshake_request()

	Level.loadout.keepers.clear()

func on_client_disconnected_from_server() -> void :
	close_session("multiplayer.error.disconnected", true)



func rpc_server(rpc_call: Callable) -> void :
	if multiplayer.is_server():
		rpc_call.call()
	else:
		rpc_call.rpc_id(1)

func rpc_or_local(peer_id: int, rpc_call: Callable) -> void :
	if peer_id == 1:
		rpc_call.call()
	else:
		rpc_call.rpc_id(peer_id)

func remove_client(peer_id: int) -> void :
	print("Remove client ", peer_id)
	var existing_client: = get_client(peer_id)
	if existing_client:
		clients.erase(existing_client)

func get_client(peer_id: int) -> Client:
	var client: Client = null
	for c in Network.clients:
		if c.peer_id == peer_id:
			client = c
			break

	if client == null:
		push_error("Don't have client for peer_id ", peer_id)
		return

	return client

func print_connection_state(connection_state: ConnectionState) -> void :
	match connection_state:
		ConnectionState.HANDSHAKE:
			print("Handshake")
		ConnectionState.CONNECTING:
			print("Connecting")
		ConnectionState.STAGE_TRANSITION:
			print("Stage Transition")
		ConnectionState.LOADOUT_STAGE_SPAWN:
			print("Loadout Spawn")
		ConnectionState.LOADOUT_STAGE_SYNC:
			print("Loadout Sync")
		ConnectionState.LEVEL_STAGE_MAP_DATA:
			print("Level Map Data")
		ConnectionState.LEVEL_STAGE_SPAWN:
			print("Level Spawn")
		ConnectionState.LEVEL_STAGE_SYNC:
			print("Level Sync")

func set_lobby_crossplay_status(crossplay: bool):
	if multiplayer.multiplayer_peer is PlayFabPartyMultiplayerPeer and multiplayer.multiplayer_peer.has_method("set_lobby_crossplay_status"):
		multiplayer.multiplayer_peer.set_lobby_crossplay_status(crossplay)


func is_offline_mode() -> bool:
	return multiplayer_mode == MultiplayerMode.OFFLINE_SINGLEPLAYER or multiplayer_mode == MultiplayerMode.OFFLINE_SPLITSCREEN

func is_network_ready(require_playfab: bool):
	if require_playfab:
		return Platform.is_network_available() and PlayFabServices.is_initialized()

	return Platform.is_network_available()

func network_team_empty_close() -> void :
	team_empty_close.rpc()

@rpc("reliable", "call_local")
func team_empty_close() -> void :
	Network.close_session("multiplayer.error.otherteamquit")

func network_main_window_size_changed(sizes: Dictionary) -> void :
	set_viewport_sizes(sizes)
	rpc_server(set_viewport_sizes.bind(sizes))

@rpc("reliable", "any_peer")
func set_viewport_sizes(sizes: Dictionary) -> void :
	for playerId in sizes.keys():
		if min(sizes[playerId].x, sizes[playerId].y) < 10.0:
			continue
		viewport_sizes_by_player_id[playerId] = sizes[playerId]

func get_visible_rect_by_keeper(in_keeper: Keeper) -> Rect2:
	var uncertainly_factor: = 1.1
	var local: bool = Keepers.local.hasPlayerId(in_keeper.playerId)
	var failsafe_size: = Vector2(1000, 700)
	var size: Vector2
	if not Level.viewports is Viewports:

		size = failsafe_size
	else:
		size = Level.viewports.get_viewport_world_size(in_keeper.playerId) if local else\
		viewport_sizes_by_player_id.get(in_keeper.playerId, failsafe_size)
	size *= uncertainly_factor

	if not local and not viewport_sizes_by_player_id.has(in_keeper.playerId):

		return Rect2(in_keeper.global_position - size / 2.0, size)

	var visible_rect_center: Vector2 = in_keeper.get_remote_camera_target()
	var rect_start: Vector2 = visible_rect_center - size / 2.0
	return Rect2(rect_start, size)

func is_point_visible_by_keeper(in_point: Vector2, in_keeper: Keeper) -> bool:
	return get_visible_rect_by_keeper(in_keeper).has_point(in_point)

func is_point_visible_by_peer(in_point: Vector2, in_peer: int) -> bool:
	var keepers: Array = Keepers.get_peer(in_peer).getAll()
	for keeper in keepers:
		if is_point_visible_by_keeper(in_point, keeper):
			return true
	return false

func is_client_blocked(client: Client) -> bool:
	if not multiplayer.is_server():
		return false


	if check_block_data(\
	client.handshake_data.platform_id, client.handshake_data.platform_user_id, client.handshake_data.playfab_id, client.block_list, \
	Platform.get_platform_id(), Platform.get_user_id(), PlayFabServices.get_entity_id(), BlockList.get_full_block_list(), \
	):
		return true


	for c in clients:
		if client.peer_id == c.peer_id:
			continue
		if check_block_data(\
		client.handshake_data.platform_id, client.handshake_data.platform_user_id, client.handshake_data.playfab_id, client.block_list, \
		c.handshake_data.platform_id, c.handshake_data.platform_user_id, c.handshake_data.playfab_id, c.block_list, \
		):
			return true


	for m in Lobby.members:
		if m.platform_id != client.handshake_data.platform_id or m.platform_user_id == client.handshake_data.platform_user_id:
			continue
		if check_block_data(\
		client.handshake_data.platform_id, client.handshake_data.platform_user_id, client.handshake_data.playfab_id, client.block_list, \
		m.platform_id, m.platform_user_id, m.playfab_id, {m.platform_user_id: m.platform_block_list}, \
		):
			return true
	return false

func check_block_data(c1_platform_id, c1_platform_user_id, c1_playfab_id, c1_block_list: Dictionary, c2_platform_id, c2_platform_user_id, c2_playfab_id, c2_block_list: Dictionary) -> bool:
	if (c1_block_list.has("playfab") and c1_block_list.playfab.has(c2_playfab_id)) or \
	(c1_block_list.has(c2_platform_id) and c1_block_list[c2_platform_id].has(c2_platform_user_id)):
		return true
	if (c2_block_list.has("playfab") and c2_block_list.playfab.has(c1_playfab_id)) or \
	(c2_block_list.has(c1_platform_id) and c2_block_list[c1_platform_id].has(c1_platform_user_id)):
		return true

	return false

func is_platform_client_blocked(platform_id, platform_user_id, block_list: Array):
	if not multiplayer.is_server():
		return false


	if Platform.get_platform_id() == platform_id && (block_list.has(Platform.get_user_id()) or Platform.get_block_list_per_device_id(0).has(platform_user_id)):
		return true


	for c in clients:
		if platform_id != c.handshake_data.platform_id or platform_user_id == c.handshake_data.platform_user_id:
			continue
		if block_list.has(c.handshake_data.platform_user_id) or c.block_list.has(platform_user_id):
			return true


	for m in Lobby.members:
		if m.platform_id != platform_id or m.platform_user_id == platform_user_id:
			continue
		if block_list.has(m.platform_user_id) or m.platform_block_list.has(platform_user_id):
			return true
	return false
