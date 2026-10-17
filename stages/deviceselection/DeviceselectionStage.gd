class_name DeviceSelectionStage
extends Stage

var loadoutInputProcessor: MultiplayerLoadoutInputProcessor
var inputProcessorsByKeeper: = {}

var initialized: = false
var MAP: Map

var pausedDeviceId: = -1
var pause_menu_scene: = load("res://content/pause/PauseMenu.tscn")

var containerByPlayerId: = {}
var playerIdByPeerDeviceId: = {}

var startedRun: = false
var clientOnlyMode: = false

var nextMoveableDevicePlayerId: = 100

@export var spawner: DeviceSelectionKeeperSpawner

func beforeStart():
	$Tween.interpolate_callback(Audio, 0.1, "unmuteSoundAndUI")
	$Tween.start()
	if clientOnlyMode:
		Network.update_local_connection_state(Network.ConnectionState.DEVICE_SELECTION_CLIENT_ONLY)
	else:
		Network.update_local_connection_state(Network.ConnectionState.DEVICE_SELECTION_STAGE_SPAWN)
	if multiplayer.is_server():
		Network.update_local_connection_state(Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC)
	else:
		spawner.initial_spawned.connect(onInitialKeepersSpawned)
	Keepers.has_initial_keepers_spawned = false

func onInitialKeepersSpawned():
	Network.update_local_connection_state(Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC)

func beforeReady():
	spawner.spawned.connect(on_loadout_keeper_spawned)
	Lobby.member_added.connect(on_lobby_member_added)
	Lobby.member_removed.connect(onLobbyMemberRemoved)
	Lobby.member_color_updated.connect(onLobbyMemberColorUpdated)
	Lobby.member_device_updated.connect(onLobbyMemberDevicedUpdated)
	spawner.keeper_removed.connect(onRemoveKeeper)
	spawner.keeper_replaced.connect(onKeeperReplaced)
	Keepers.keeper_unregistered.connect(onKeeperUnregistered)
	%CancelKeeperLoadoutChoice.select.connect(on_cancel_keeper_select)

	Audio.muteSoundAndUI()
	MAP = %Map
	GameWorld.prepareCleanData()

	Level.stage = self
	Level.viewports = self

	Style.additionalPalettes.clear()
	Style.setPalette("palette_1_1")

	GameWorld.setShowMouse(false)

	Data.apply("map.tileHealthMultiplierPerLayer", 1)

func addElement(e) -> void :
	add_child(e)

func on_cancel_keeper_select(keeper: Keeper) -> void :
	if not is_instance_valid(keeper):

		return

	if not playerIdByPeerDeviceId.has(Utils.get_peer_device_composite_key(keeper.peerId, keeper.deviceId)):
		return

	networkCancelKeeperSelection(keeper)

func build(data: Array):
	var clientMapData: Dictionary
	if not multiplayer.is_server():
		assert (data.size() == 6, "Client sent to device selection stage without appropriate data.")

		playerIdByPeerDeviceId = data[0]
		Level.loadout = Loadout.from_bytes(data[1])
		Level.loadout.loadout_keepers_from_bytes(data[2])
		clientOnlyMode = data[3]
		GameWorld.unlocks.deserialize(data[4])
		clientMapData = data[5]

	%StartRunChoiceGroup.clientOnlyMode = clientOnlyMode
	updateStartRunButton()

	Level.map = MAP
	MAP.biomes = Map.generateBiomes()
	MAP.setTileData(preload("res://stages/deviceselection/TileDataDeviceSelection.tscn").instantiate())
	if clientMapData.size() > 0:
		MAP.tileData.clear()
		for layer in clientMapData.keys():
			Level.map.tileData.set_layer_data(layer, clientMapData[layer])

	MAP.init(false, false)

	Audio.startIntro()

	GameWorld.levelInitialized()
	initialized = true

	MAP.revealInitialState(Vector2(0, 3))

	%Camera.zoom = GameWorld.goalCameraZoomLoadout * Vector2.ONE
	%StartRunChoiceGroup.setChoice("", "", null)

	var teams: = {}
	for lk: LoadoutKeeper in Level.loadout.keeperTemplates:
		teams[lk.teamId] = ""

	if teams.size() == 1:
		%OneTeamContainer.visible = true
		%TwoTeamsContainer.visible = false
	else:
		%OneTeamContainer.visible = false
		%TwoTeamsContainer.visible = true

	%LabelTeam1.text = tr("loadout.team") % "1"
	%LabelTeam2.text = tr("loadout.team") % "2"

	for i in range(Level.loadout.keeperTemplates.size()):
		var lk: LoadoutKeeper = Level.loadout.keeperTemplates[i]
		var container
		if teams.size() == 2:
			container = find_child("GridContainer" + Data.startCaptialized(lk.teamId))
		else:
			container = %GridContainerAllTeams

		addLoadoutKeeper(lk.duplicate(), container)

	Level.loadout.keepers.clear()
	updateKeeperChoices(playerIdByPeerDeviceId)
	_initInputProcessors()

	Style.init($UI)
	runDecoration()

func _initInputProcessors() -> void :
	loadoutInputProcessor = MultiplayerLoadoutInputProcessor.new()
	if multiplayer.is_server():


		Options.enableSplitScreen = true

	if GameWorld.isSplitScreen():
		loadoutInputProcessor.new_device_detected.connect(addNewDevice)
		loadoutInputProcessor.joystick_disconnected.connect(onDeviceDisconnected)
	else:
		addNewDevice(-1)
	loadoutInputProcessor.integrate(self)

func runDecoration():
	await get_tree().create_timer(0.05).timeout

	var rng: = RandomNumberGenerator.new()
	rng.seed = Level.levelSeed

	MAP.border_deco.runDecoration()
	for d in get_tree().get_nodes_in_group("decoration"):
		d.visible = rng.randf() < 0.7

func _process(delta: float) -> void :
	for keeper: Keeper in Keepers.local.getAll():
		var ua = keeper.find_child("UseArea")
		ua.get_child(0).shape.radius = 1.0




		Data.values[keeper.playerId + ".keeper.speedbuff"] = 0.0;
		Data.values[keeper.playerId + ".keeper.drillbuff"] = 0.0;
		Data.values[keeper.playerId + ".keeper.zoominmine"] = 0.0;
		Data.values[keeper.playerId + ".keeper.additionalupwardsspeed"] = 0.0;
		match keeper.techId:
			"keeper1":
				Data.values[keeper.playerId + ".keeper1.drillstrength"] = 2
				Data.values[keeper.playerId + ".keeper1.maxspeed"] = 180
				Data.values[keeper.playerId + ".keeper1.slowdownrecovery"] = 4
				Data.values[keeper.playerId + ".keeper1.acceleration"] = 5
				Data.values[keeper.playerId + ".keeper1.deceleration"] = 4
				Data.values[keeper.playerId + ".keeper1.speedlosspercarry"] = 4
				Data.values[keeper.playerId + ".keeper1.jetpackstage"] = 0
				Data.values[keeper.playerId + ".keeper1.tileknockback"] = 7
				Data.values[keeper.playerId + ".keeper1.tilehitcooldown"] = 0.35
				Data.values[keeper.playerId + ".keeper1.hardtilesmodifier"] = 1.0
				Data.values[keeper.playerId + ".keeper1.destroyindestructibletiles"] = false
			"keeper2":
				Data.values[keeper.playerId + ".keeper2.maxspeed"] = 200
				Data.values[keeper.playerId + ".keeper2.acceleration"] = 110
				Data.values[keeper.playerId + ".keeper2.deceleration"] = 5
				Data.values[keeper.playerId + ".keeper2.minspeed"] = 1.0;
				Data.values[keeper.playerId + ".keeper2.totalspheres"] = 1;
				Data.values[keeper.playerId + ".keeper2.spherereload"] = 10.0;
				Data.values[keeper.playerId + ".keeper2.directminingdamage"] = 0.4;
				Data.values[keeper.playerId + ".keeper2.directmininghardness"] = 1.0;
				Data.values[keeper.playerId + ".keeper2.directminingstage"] = 1;
				Data.values[keeper.playerId + ".keeper2.spherebasedamage"] = 1.2;
				Data.values[keeper.playerId + ".keeper2.spherefractiondamage"] = 0.03;
				Data.values[keeper.playerId + ".keeper2.spherebaselifetime"] = 9.0;
				Data.values[keeper.playerId + ".keeper2.sphereadditionalfirsthitdamage"] = 2.0;
				Data.values[keeper.playerId + ".keeper2.spherespeed"] = 200.0;
				Data.values[keeper.playerId + ".keeper2.actioncooldown"] = 0.0;
				Data.values[keeper.playerId + ".keeper2.actionstage"] = 0;
				Data.values[keeper.playerId + ".keeper2.spheresplit"] = false;
				Data.values[keeper.playerId + ".keeper2.splitlifetime"] = 0.0;
				Data.values[keeper.playerId + ".keeper2.explodespheres"] = false;
				Data.values[keeper.playerId + ".keeper2.explodespheresradius"] = 0.0;
				Data.values[keeper.playerId + ".keeper2.reflectsphere"] = false;
				Data.values[keeper.playerId + ".keeper2.reflectspeed"] = 0.0;
				Data.values[keeper.playerId + ".keeper2.reflectnexthitdamage"] = 0.0;
				Data.values[keeper.playerId + ".keeper2.reflectlifetime"] = 0.0;
				Data.values[keeper.playerId + ".keeper2.bundleduration"] = 15.0;
				Data.values[keeper.playerId + ".keeper2.bundlespeed"] = 30.0;
				Data.values[keeper.playerId + ".keeper2.bundlestopcenter"] = false;
				Data.values[keeper.playerId + ".keeper2.bundleguide"] = false;
				Data.values[keeper.playerId + ".keeper2.pinballdestroyadjacenttiles"] = false;
				Data.values[keeper.playerId + ".keeper2.bundlecentralmarker"] = false;
			"keeper3":
				pass
			"keeper4":
				Data.values[keeper.playerId + ".keeper4.movespeed"] = 300

func addLoadoutKeeper(lk: LoadoutKeeper, container):
	var skin_sprite_path: String = "res://content/keeper/" + lk.keeperId + "/spriteframes-" + lk.skinId + "-" + lk.colorId + ".tres"
	if not ResourceLoader.exists(skin_sprite_path):
		Logger.error("skin does not exist, cannot offer to play keeper", "DeviceSelectionPopup.add_keeper", skin_sprite_path)
		return
	var e = preload("res://stages/loadout/KeeperChoice.tscn").instantiate()
	containerByPlayerId[lk.playerId] = e
	e.connect("select", changeKeeper.bind(lk))
	var keeperIcon: Texture2D = load("res://content/icons/loadout_" + lk.keeperId + "-" + lk.skinId + "-" + lk.colorId + ".png")
	container.add_child(e)
	e.setChoice(lk.playerId, keeperIcon, true)
	e.setName(lk.playerName)
	e.custom_minimum_size.x = 200
	e.clear_material()
	e.set_enabled(true)
	Style.init(e)


func changeKeeper(currentKeeper: Keeper, newLoadoutKeeper: LoadoutKeeper):
	if clientOnlyMode:
		serverChangeKeeper(currentKeeper.playerId, newLoadoutKeeper.playerId)
	else:
		Network.rpc_server(serverChangeKeeper.bind(currentKeeper.playerId, newLoadoutKeeper.playerId))

func ensureKeepersUpToDate(peer_id: int) -> void :
	Network.rpc_for_states(updateKeeperChoices.bind(playerIdByPeerDeviceId), [Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC, 
		Network.ConnectionState.DEVICE_SELECTION_STAGE_SPAWN], false)

	var keepersToEnsure: Array = []
	for keeper: Keeper in Keepers.all.getAll():
		if keeper.isMovementDummy:
			continue
		keepersToEnsure.append(keeper)

		var newLoadoutKeeper: LoadoutKeeper
		for lk in Level.loadout.keeperTemplates:
			if lk.playerId == keeper.playerId:
				newLoadoutKeeper = lk.duplicate()
				break

		Network.rpc_for_states(Lobby.update_member.bind(keeper.peerId, keeper.deviceId, \
		Utils.encode_player_id(newLoadoutKeeper.playerId), Utils.encode_team_id(newLoadoutKeeper.teamId), \
		Utils.encode_tech_id(newLoadoutKeeper.keeperId), Utils.encode_color_id(newLoadoutKeeper.colorId), \
		Utils.encode_skin_id(newLoadoutKeeper.skinId)), [Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC, Network.ConnectionState.DEVICE_SELECTION_STAGE_SPAWN], false)
		Network.rpc_for_states(ensurePeerKeeperCorrect.bind(keeper.peerId, keeper.playerId, newLoadoutKeeper.to_bytes()), 
			[Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC, Network.ConnectionState.DEVICE_SELECTION_STAGE_SPAWN], false)

@rpc("reliable")
func ensurePeerKeeperCorrect(inPeerId: int, inPlayerId: String, buffer: PackedByteArray) -> void :
	var dummyFound: bool = false
	var found: bool = false
	for keeper: Keeper in Keepers.getAll():
		if keeper.peerId == inPeerId:
			if keeper.playerId == inPlayerId:
				found = true
				if keeper.isMovementDummy:
					dummyFound = true
	if dummyFound:
		var lk = LoadoutKeeper.from_bytes(buffer)
		lk.peerId = inPeerId
		Level.loadout.updateTemplatePlayerPeer(lk.playerId, inPeerId)
		spawner.spawn_from_bytes(lk.to_bytes(), true, inPlayerId)
	elif not found:
		var lk = LoadoutKeeper.from_bytes(buffer)
		lk.peerId = inPeerId
		Level.loadout.updatePlayerIdForKeeper(lk.playerId, lk.keeperId)
		spawner.spawn_from_bytes(lk.to_bytes(), true, inPlayerId)

@rpc("reliable")
func updateKeeperChoices(playerIdByPeerDeviceId: Dictionary) -> void :
	self.playerIdByPeerDeviceId = playerIdByPeerDeviceId
	for keeperChoice in containerByPlayerId.values():
		keeperChoice.set_enabled(true)

	for playerId in playerIdByPeerDeviceId.values():
		containerByPlayerId[playerId].set_enabled(false)

@rpc("reliable", "any_peer")
func serverChangeKeeper(currentPlayerId: String, newPlayerId: String) -> void :
	var currentKeeper: = Keepers.getKeeper(currentPlayerId)

	if playerIdByPeerDeviceId.values().has(newPlayerId):
		Network.rpc_if_state(updateKeeperChoices.bind(playerIdByPeerDeviceId), Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC, true)
		return

	var newLoadoutKeeper: LoadoutKeeper
	for lk in Level.loadout.keeperTemplates:
		if lk.playerId == newPlayerId:
			newLoadoutKeeper = lk.duplicate()
			break

	var composite: = Utils.get_peer_device_composite_key(currentKeeper.peerId, currentKeeper.deviceId)
	playerIdByPeerDeviceId[composite] = newLoadoutKeeper.playerId
	if clientOnlyMode:
		updateKeeperChoices(playerIdByPeerDeviceId)
	else:
		Network.rpc_if_state(updateKeeperChoices.bind(playerIdByPeerDeviceId), Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC, true)

	newLoadoutKeeper.position = currentKeeper.position
	newLoadoutKeeper.deviceId = currentKeeper.deviceId
	newLoadoutKeeper.peerId = currentKeeper.peerId
	newLoadoutKeeper.playerName = Utils.get_player_name(newPlayerId, currentKeeper.peerId, currentKeeper.deviceId)
	var oldLoadoutKeeper: LoadoutKeeper
	for l: LoadoutKeeper in Level.loadout.keepers:
		if l.playerId == currentKeeper.playerId:
			oldLoadoutKeeper = l
			break
	oldLoadoutKeeper.keeper = currentKeeper

	if clientOnlyMode:
		spawner.spawn_from_bytes(newLoadoutKeeper.to_bytes(), true, currentPlayerId)
		Lobby.update_member(currentKeeper.peerId, currentKeeper.deviceId, \
		Utils.encode_player_id(newLoadoutKeeper.playerId), Utils.encode_team_id(newLoadoutKeeper.teamId), \
		Utils.encode_tech_id(newLoadoutKeeper.keeperId), Utils.encode_color_id(newLoadoutKeeper.colorId), \
		Utils.encode_skin_id(newLoadoutKeeper.skinId))
	else:
		spawner.network_replace_player_id(newLoadoutKeeper.to_bytes(), currentPlayerId)
		Network.rpc_if_state(Lobby.update_member.bind(currentKeeper.peerId, currentKeeper.deviceId, \
		Utils.encode_player_id(newLoadoutKeeper.playerId), Utils.encode_team_id(newLoadoutKeeper.teamId), \
		Utils.encode_tech_id(newLoadoutKeeper.keeperId), Utils.encode_color_id(newLoadoutKeeper.colorId), \
		Utils.encode_skin_id(newLoadoutKeeper.skinId)), Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC, true)

func networkCancelKeeperSelection(keeper: Keeper) -> void :
	if clientOnlyMode:
		cancelKeeperSelection(keeper.peerId, keeper.deviceId)
	else:
		keeper.synchronizer.paused = true
		Network.rpc_server(cancelKeeperSelection.bind(keeper.peerId, keeper.deviceId))

@rpc("reliable", "any_peer")
func cancelKeeperSelection(peerId: int, deviceId: int) -> void :
	var keeper: Keeper
	for k in Keepers.getAll():
		if k.peerId == peerId and k.deviceId == deviceId:
			keeper = k
			break

	for drops in keeper.carriedCarryables:
		keeper.dropCarry(drops)

	playerIdByPeerDeviceId.erase(Utils.get_peer_device_composite_key(peerId, deviceId))
	updateKeeperChoices(playerIdByPeerDeviceId)

	changeKeeperToMoveableDevice(keeper.playerId)

func changeKeeperToMoveableDevice(currentPlayerId: String) -> void :
	var currentKeeper: = Keepers.getKeeper(currentPlayerId)
	var composite: = Utils.get_peer_device_composite_key(currentKeeper.peerId, currentKeeper.deviceId)
	playerIdByPeerDeviceId.erase(composite)

	if clientOnlyMode:
		updateKeeperChoices(playerIdByPeerDeviceId)
	else:
		Network.rpc_if_state(updateKeeperChoices.bind(playerIdByPeerDeviceId), Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC, true)

	var newLoadoutKeeper: = Loadout.createDefaultKeeper()
	newLoadoutKeeper.position = currentKeeper.position
	newLoadoutKeeper.deviceId = currentKeeper.deviceId
	newLoadoutKeeper.peerId = currentKeeper.peerId
	newLoadoutKeeper.playerName = currentKeeper.playerName
	newLoadoutKeeper.playerId = Utils.decode_player_id(getNextMoveablePlayerId())

	var oldLoadoutKeeper: LoadoutKeeper
	for l: LoadoutKeeper in Level.loadout.keepers:
		if l.playerId == currentKeeper.playerId:
			oldLoadoutKeeper = l
			break
	oldLoadoutKeeper.keeper = currentKeeper

	if clientOnlyMode:
		spawner.spawn_from_bytes(newLoadoutKeeper.to_bytes(), true, currentPlayerId)
		Lobby.update_member(currentKeeper.peerId, currentKeeper.deviceId, \
		Utils.encode_player_id(newLoadoutKeeper.playerId), Utils.encode_team_id(newLoadoutKeeper.teamId), \
		Utils.encode_tech_id(newLoadoutKeeper.keeperId), Utils.encode_color_id(newLoadoutKeeper.colorId), \
		Utils.encode_skin_id(newLoadoutKeeper.skinId))
	else:
		spawner.network_replace_player_id(newLoadoutKeeper.to_bytes(), currentPlayerId)
		Network.rpc_if_state(Lobby.update_member.bind(currentKeeper.peerId, currentKeeper.deviceId, \
		Utils.encode_player_id(newLoadoutKeeper.playerId), Utils.encode_team_id(newLoadoutKeeper.teamId), \
		Utils.encode_tech_id(newLoadoutKeeper.keeperId), Utils.encode_color_id(newLoadoutKeeper.colorId), \
		Utils.encode_skin_id(newLoadoutKeeper.skinId)), Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC, true)


func addKeeper(keeper: Keeper):
	add_child(keeper)
	keeper.registerCamera( %Camera)

func addNewDevice(id: int):
	for existing in Lobby.members:
		if existing.peer_id == multiplayer.get_unique_id() and existing.device_id == id:
			return

	if multiplayer.is_server():
		if not canAddNewDevice(1):

			rejectNewDevice(id)
		else:
			Lobby.simple_add(id, getNextMoveablePlayerId())
	else:
		var platform_user_id: String
		var platform_user_name: String
		if BuildCustomization.has_feature("enable_multiple_local_account"):

			platform_user_id = Platform.get_user_id_per_device_id(id)
			platform_user_name = Platform.get_username_per_device_id(id)
		else:

			platform_user_id = Platform.get_user_id()
			platform_user_name = Platform.get_username()

		if clientOnlyMode:
			Lobby.add(
				multiplayer.get_unique_id(), 
				id, 
				PlayFabServices.get_entity_id(), 
				Platform.get_platform_id(), 
				platform_user_id, 
				platform_user_name, 
				getNextMoveablePlayerId(), 
				false
			)
		else:
			var platform_block_list = []
			if BuildCustomization.has_feature("enable_block"):
				platform_block_list = Platform.get_block_list_per_device_id(id)

			var add_keeper_cb: Callable = addMoveableMember.bind(
				multiplayer.get_unique_id(), 
				id, 
				PlayFabServices.get_entity_id(), 
				Platform.get_platform_id(), 
				platform_user_id, 
				platform_user_name, 
				platform_block_list, 
			)

			if multiplayer.is_server():
				add_keeper_cb.call()
			else:
				Network.chunker.send(1, Chunker.ChunkRequestType.ADD_MOVEABLE_MEMBER, add_keeper_cb)

@rpc("reliable")
func rejectNewDevice(id: int) -> void :
	loadoutInputProcessor.unregisterDevice(id)

@rpc("reliable", "any_peer")
func addMoveableMember(peerId: int, deviceId: int, playfab_id: String, platform_id: String, platform_user_id: String, platform_user_name: String, platform_block_list: Array) -> void :
	if not canAddNewDevice(peerId) or Network.is_platform_client_blocked(platform_id, platform_user_id, platform_block_list):
		rejectNewDevice.rpc_id(peerId, deviceId)
		return

	Lobby.add(
		peerId, 
		deviceId, 
		playfab_id, 
		platform_id, 
		platform_user_id, 
		platform_user_name, 
		getNextMoveablePlayerId()
	)
	Lobby.get_member(peerId, deviceId).platform_block_list = platform_block_list

func canAddNewDevice(peerId: int) -> bool:
	return Keepers.local.getCount() < 4 and Keepers.get_peer(peerId).getCount() + Network.clients.size() < Level.loadout.keeperTemplates.size() and Network.clients.size() + 1 <= Level.loadout.keeperTemplates.size() and Keepers.all.getCount() < Level.loadout.keeperTemplates.size()

func onDeviceDisconnected(deviceId: int) -> void :
	Network.rpc_server(Lobby.remove.bind(deviceId, Keepers.local.getCount()))

	var keepers = Keepers.local.getAll()
	for keeper: Keeper in keepers:
		if keeper.deviceId != deviceId:
			continue
		var isLastLocalKeeper: bool = keepers.size() < 2
		if isLastLocalKeeper and not GameWorld.isSplitScreen():
			_local_switch_device(deviceId, InputProcessor.KEYBOARD_AND_MOUSE_DEVICE_ID)
		else:
			Keepers.unregisterKeeper(keeper)

func _local_switch_device(old_device_id: int, new_device_id: int) -> void :
	assert (Network.is_client())
	var localKeeperToUpdate: Keeper = Keepers.getLocalKeeperByDeviceId(old_device_id)
	if is_instance_valid(localKeeperToUpdate):
		var lk: LoadoutKeeper = Level.loadout.getLoadoutKeeperByDeviceId(new_device_id)
		localKeeperToUpdate.deviceId = new_device_id
		lk.deviceId = new_device_id
		if StageManager.currentStage is MultiplayerLoadoutStage:
			StageManager.currentStage.updateKeeperDeviceId(localKeeperToUpdate)

	for keeper: LoadoutKeeper in Level.loadout.keepers:
		if keeper.deviceId == old_device_id:
			keeper.deviceId = new_device_id

func on_lobby_member_added(member: Lobby.Member) -> void :
	var lk = Level.loadout.getLoadoutKeeperByDeviceId(member.device_id)
	lk.playerId = "player%d" % member.player_id
	lk.playerName = Utils.get_player_name(lk.playerId, member.peer_id, member.device_id)
	lk.deviceId = member.device_id
	lk.peerId = member.peer_id
	lk.teamId = "team%d" % member.team_id
	lk.platformId = member.platform_user_id
	lk.platformName = member.platform_id

	var nextColor: = Utils.get_next_player_color()
	lk.colorId = "color%d" % nextColor

	member.skin_id = int(lk.skinId.lstrip("skin"))
	member.color_id = nextColor
	member.keeper_id = 1
	lk.keeperId = "keeper1"

	if Level.loadout.keepers.size() > 0:
		Audio.sound("loadout_keeper_join")

	spawn_keeper(lk)

func spawn_existing_member(member: Lobby.Member) -> void :
	var lk = Level.loadout.getLoadoutKeeperByDeviceId(member.device_id)
	lk.playerId = "player%d" % member.player_id
	lk.playerName = Utils.get_player_name(lk.playerId, lk.peerId, lk.deviceId)
	lk.teamId = "team%d" % member.team_id
	lk.deviceId = member.device_id
	lk.peerId = member.peer_id
	lk.skinId = "skin%d" % member.skin_id
	lk.colorId = "color%d" % member.color_id
	lk.keeperId = "keeper0"
	lk.platformId = member.platform_user_id
	lk.platformName = member.platform_id

	spawn_keeper(lk)

func spawn_keeper(lk: LoadoutKeeper) -> void :
	var spawnPosition: Vector2
	spawnPosition = %KeeperSpawnPosition.position
	spawnPosition += Vector2.ONE.rotated(randf_range( - PI, PI)) * 10
	lk.position = spawnPosition

	spawner.network_spawn(lk.to_bytes())

func onLobbyMemberRemoved(member: Lobby.Member) -> void :
	if member.peer_id == multiplayer.get_unique_id():
		loadoutInputProcessor.unregisterDevice(member.device_id)

	var isInClientControlledDeviceSelection: bool = StageManager.isInDeviceSelection() and \
	StageManager.currentStage.clientOnlyMode
	if multiplayer.is_server() or isInClientControlledDeviceSelection:
		spawner.network_despawn(member.peer_id, member.device_id)

	Audio.sound("loadout_keeper_leave")

func on_loadout_keeper_spawned(lk: LoadoutKeeper):
	if multiplayer.is_server():
		updatePlayerIds()
	else:
		lk.keeper.init()

	var tentacles = lk.keeper.get_node_or_null("Tentacles")
	if tentacles:
		tentacles.grid_attach_enabled = true

	lk.keeper.set_multiplayer_authority(lk.keeper.peerId)
	lk.keeper.synchronizer.paused = clientOnlyMode

	if not playerIdByPeerDeviceId.has(Utils.get_peer_device_composite_key(lk.keeper.peerId, lk.keeper.deviceId)):
		lk.keeper.as_movement_dummy()
		var md: = preload("res://stages/deviceselection/MoveableDevice.tscn").instantiate()
		lk.keeper.add_child(md)
		lk.keeper.updateShowPlayerName()

	updateStartRunButton()

	if lk.keeper.peerId != multiplayer.get_unique_id():
		return

	var id = lk.keeper.techId.capitalize().replace(" ", "")
	var keeperInputProcessor: KeeperInputProcessor = load("res://content/keeper/" + id + "InputProcessor.gd").new()
	keeperInputProcessor.keeper = lk.keeper
	keeperInputProcessor.playerId = lk.keeper.playerId
	keeperInputProcessor.deviceId = lk.deviceId
	keeperInputProcessor.runningInLoadout = true
	keeperInputProcessor.integrate(self)
	inputProcessorsByKeeper[lk.keeper] = keeperInputProcessor

func updatePlayerIds():
	var keepers: = Keepers.getAll()
	for keeper in keepers:
		if keeper.visible:
			keeper.init()
			match keeper.techId:
				"keeper1":
					Data.apply(keeper.playerId + ".keeper1.maxSpeed", 180)
				"keeper2":
					Data.apply(keeper.playerId + ".keeper2.maxSpeed", 200)
					Data.apply(keeper.playerId + ".keeper2.acceleration", 110)
					Data.apply(keeper.playerId + ".keeper2.deceleration", 5)

func onLobbyMemberColorUpdated(member: Lobby.Member) -> void :
	for lk: LoadoutKeeper in Level.loadout.keepers:
		if lk.playerId == "player%d" % member.player_id:
			lk.colorId = "color%d" % member.color_id
			lk.keeper.setSkin("skin%d" % member.skin_id, "color%d" % member.color_id)

func onLobbyMemberDevicedUpdated(peer_id: int, old_device_id: int, new_device_id: int) -> void :
	for lk: LoadoutKeeper in Level.loadout.keepers:
		if lk.peerId == peer_id and lk.deviceId == old_device_id:
			lk.deviceId = new_device_id
			lk.keeper.deviceId = new_device_id
			updateKeeperDeviceId(lk.keeper)
			return

func updateKeeperDeviceId(keeper: Keeper) -> void :
	if not keeper.is_multiplayer_authority():
		return

	if inputProcessorsByKeeper.has(keeper):
		inputProcessorsByKeeper[keeper].desintegrate()
		inputProcessorsByKeeper[keeper].keeper = null
		inputProcessorsByKeeper.erase(keeper)

	var id = keeper.techId.capitalize().replace(" ", "")
	var keeperInputProcessor = load("res://content/keeper/" + id + "InputProcessor.gd").new()
	keeperInputProcessor.keeper = keeper
	keeperInputProcessor.playerId = keeper.playerId
	keeperInputProcessor.deviceId = keeper.deviceId
	keeperInputProcessor.runningInLoadout = true
	keeperInputProcessor.integrate(self)
	inputProcessorsByKeeper[keeper] = keeperInputProcessor

func onRemoveKeeper(keeper: Keeper):
	Keepers.unregisterKeeper(keeper)
	updateStartRunButton()

func onKeeperReplaced(newKeeper: Keeper, oldKeeper: Keeper) -> void :
	newKeeper.set_multiplayer_authority(oldKeeper.peerId)
	updatePlayerIds()
	killKeeper(oldKeeper)

	if newKeeper.peerId == multiplayer.get_unique_id():
		GameWorld.ostKeeperId = newKeeper.techId
		Audio.fadeIntro()

func killKeeper(keeper: Keeper) -> void :
	keeper.kill()
	if inputProcessorsByKeeper.has(keeper):
		inputProcessorsByKeeper[keeper].desintegrate()
		inputProcessorsByKeeper[keeper].keeper = null
		inputProcessorsByKeeper.erase(keeper)

func onKeeperUnregistered(keeper: Keeper) -> void :
	playerIdByPeerDeviceId.erase(Utils.get_peer_device_composite_key(keeper.peerId, keeper.deviceId))
	updateKeeperChoices(playerIdByPeerDeviceId)
	killKeeper(keeper)

func openPauseMenu(keeper: Keeper):
	if pauseMenuOpen:
		return

	pausedDeviceId = keeper.deviceId
	pauseMenuOpen = true
	if not Options.useGamepad(keeper.deviceId):
		GameWorld.setShowMouse(true)
	var i = preload("res://content/pause/PauseInputProcessor.gd").new()
	i.deviceId = keeper.deviceId
	i.popup = pause_menu_scene.instantiate()
	i.popup.deviceId = keeper.deviceId
	i.popup.saveOnQuit = false
	i.globalInput = true
	i.blockAllKeys = true
	add_child(i.popup)
	i.integrate(self)
	i.connect("stopping", i.popup.fadeOut.bind(0.3))
	i.connect("onStop", pauseClosed.bind(keeper.deviceId))
	i.popup.connect("close", i.desintegrate)
	pause()
	pauseMenuOpenChanged.emit()

func pauseClosed(deviceId: int):
	pauseMenuOpen = false
	unpause(false)
	pauseMenuOpenChanged.emit()

func toggleCheats():
	pass

func pause(byPlayer: = true):
	if Keepers.isMultiplayer():
		return
	GameWorld.pause()

func unpause(byPlayer: = true):
	GameWorld.unpause()

func _on_start_run_choice_group_select() -> void :
	if clientOnlyMode:
		clientStartRunSelected()
	else:
		Network.rpc_server(serverStartRunSelected)

func clientStartRunSelected() -> void :
	var device_ids: PackedInt32Array = []
	var player_ids: PackedStringArray = []
	var platform_user_ids: PackedStringArray = []
	var platform_user_names: PackedStringArray = []
	for keeper: Keeper in Keepers.local.getAll():
		device_ids.append(keeper.deviceId)
		player_ids.append(keeper.playerId)
		if BuildCustomization.has_feature("enable_multiple_local_account"):

			platform_user_ids.append(Platform.get_user_id_per_device_id(keeper.deviceId))
			platform_user_names.append(Platform.get_username_per_device_id(keeper.deviceId))
		else:

			platform_user_ids.append(Platform.get_user_id())
			platform_user_names.append(Platform.get_username())

	Network.rpc_server(Network.finish_device_selection.bind(
		device_ids, 
		player_ids, 
		PlayFabServices.get_entity_id(), 
		Platform.get_platform_id(), 
		platform_user_ids, 
		platform_user_names, 
	))
	StageManager.startStage("stages/client/loading")

@rpc("reliable", "any_peer")
func serverStartRunSelected() -> void :
	if %StartRunChoiceGroup.visible and %StartRunChoiceGroup.isAnyPeerOutsideStartButton():
		return
	startRun()

func startRun():
	if startedRun or ( %StartRunChoiceGroup.visible and %StartRunChoiceGroup.disabled):
		return

	startedRun = true
	%StartRunChoiceGroup.set_enabled(false)

	Audio.sound("gui_loadout_startrun")

	for ki: InputProcessor in inputProcessorsByKeeper.values():
		ki.desintegrate()

	Level.loadout.keepers.clear()
	Keepers.clear()

	for client in Network.clients:

		if client.connection_state != Network.ConnectionState.DEVICE_SELECTION_STAGE_SYNC:
			client.server_disconnect()

	SaveGame.continue_loading_save.emit(false)

func updateStartRunButton(area = null):
	if area == null:
		updateStartRunButton( %StartRunChoiceGroup)
	else:
		if clientOnlyMode:
			area.set_enabled(true)
			return

		area.set_enabled(false)
		match Level.loadout.modeId:
			CONST.MODE_PRESTIGE:
				if Level.loadout.keepers.size() < 2:
					area.setChoice("loadout.hint.multiplayer.playerminimum", "", null)
					return
			CONST.MODE_VERSUS:
				var hasTeam1: = false
				var hasTeam2: = false
				for keeper: Keeper in Keepers.getAll():
					if keeper.techId == "keeper1" and keeper.isMovementDummy:
						continue
					if keeper.teamId == "team1":
						hasTeam1 = true
					elif keeper.teamId == "team2":
						hasTeam2 = true
				if not (hasTeam1 and hasTeam2):
					area.setChoice("loadout.hint.teams", "", null)
					return

		area.set_enabled(true)
		area.setChoice("loadout.secondstage.start", "", null)

func beforeEnd():
	super.beforeEnd()
	if spawner.initial_spawned.is_connected(onInitialKeepersSpawned):
		spawner.initial_spawned.disconnect(onInitialKeepersSpawned)

	for k in Keepers.getAll():
		k.kill()

	Data.clearListeners()
	Keepers.clear()

	if not startedRun:
		SaveGame.continue_loading_save.emit(true)

func sendStageSpawnPackets(peer_id: int) -> void :
	var spawnBytes: = PackedByteStream.new()
	spawnBytes.encode_u8(Level.loadout.keepers.size())
	for lk: LoadoutKeeper in Level.loadout.keepers:
		var lkBytes: = lk.to_bytes()
		spawnBytes.encode_u8(lkBytes.size())
		spawnBytes.append_array(lkBytes)
	spawner.spawn_initial.rpc_id(peer_id, spawnBytes.data)

func getNextMoveablePlayerId() -> int:
	nextMoveableDevicePlayerId += 1
	return nextMoveableDevicePlayerId

func serializeMapData() -> Dictionary:
	return Level.map.getMapData()
