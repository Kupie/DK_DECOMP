class_name Game extends Node

@export var build: CONST.BUILD_TYPE = CONST.BUILD_TYPE.DEMO
@export var devMode: = true
@export var resetBetweenRuns: = false
@export var qaOptions: = false
@export var unlockAllButton: = false
@export var useSteamPlatformInEditor: = false
@export var fixedWorld: = 0
@export var fixedPalette: = ""
@export var fixedMap: String
@export var fixedArchetype: Resource
@export var fixedIpJoin: String
@export var useRandomPort: = false
@export var prewarmShaders: = false

@export var fixedLocale: String

var screenshotIndex = 0

func _ready():
	_ensure_window_focus()
	randomize()
	_prewarmShaders()


	if not OS.has_feature("editor"):
		devMode = false
	if FileAccess.file_exists("user://dev-mode"):
		devMode = true

	loadDevState()

	Options.fixedLocale = fixedLocale
	GameWorld.worldEnv = $WorldEnvironment
	GameWorld.devMode = devMode
	GameWorld.fixedIpJoin = fixedIpJoin
	GameWorld.resetBetweenRuns = resetBetweenRuns
	GameWorld.buildType = build
	GameWorld.qaOptions = qaOptions
	GameWorld.unlockAllButton = unlockAllButton
	GameWorld.version = "v" + str(Version.VERSION)
	GameWorld.version_sha = Version.SHA
	GameWorld.worldEnv = $WorldEnvironment
	GameWorld.useRandomPort = useRandomPort
	match build:
		CONST.BUILD_TYPE.DEMO:
			GameWorld.version += "d"
		CONST.BUILD_TYPE.PLAYTEST:
			GameWorld.version += "p"
		CONST.BUILD_TYPE.EXHIBITION:
			GameWorld.version += "e"

	if Engine.has_singleton("_OS_Seaven"):
		if BuildCustomization.has_feature("disable_multi"):
			GameWorld.version += ".solo"
		else:
			GameWorld.version += ".multi"

	logDebuggingInfo()


	Platform.init(useSteamPlatformInEditor)
	GameWorld.init()
	GameWorld.handleVersionChange()
	Options.init()
	Backend.init()
	cacheScreenshotIndex()

	var in_custom_editor_play = false
	var editor_conf: DomeEditorConf = null
	if OS.has_feature("editor") and ResourceLoader.exists(Const.EDITOR_CONF_PATH):
		editor_conf = load(Const.EDITOR_CONF_PATH)
		if editor_conf and editor_conf.custom_play_pressed:
			in_custom_editor_play = true

	var is_server: bool = UtilsOS.has_startup_argument("--server")
	var is_client: bool = UtilsOS.has_startup_argument("--client")
	var is_dev_networked: bool = in_custom_editor_play and \
	(editor_conf.multiplayer_mode == Const.DEV_ENTER_MULTIPLAYER_MODE.NETWORK) or (is_server or is_client)
	if is_dev_networked:
		var is_starting_in_lvl: bool = editor_conf.play_mode == Const.ENTER_PLAY_MODE.Level
		if is_server and is_starting_in_lvl:
			Network.create_enet_host()
		if is_client and is_starting_in_lvl:
			OS.delay_msec(500)
			Network.create_enet_client("127.0.0.1", 8742)

	var runmode = Const.ENTER_PLAY_MODE.Title
	if in_custom_editor_play:
		runmode = editor_conf.play_mode
	elif devMode:
		runmode = Const.ENTER_PLAY_MODE.Level
	elif build == CONST.BUILD_TYPE.EXHIBITION:
		runmode = Const.ENTER_PLAY_MODE.Loadout

	startGameInMode(runmode, in_custom_editor_play, editor_conf)

func _ensure_window_focus() -> void :



	get_tree().root.grab_focus()

func cacheScreenshotIndex():
	if not DirAccess.dir_exists_absolute("../screenshots"):
		DirAccess.make_dir_recursive_absolute("../screenshots")
	var dir = DirAccess.open("../screenshots")
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if not file.begins_with("."):
			screenshotIndex += 1

func startGameInMode(mode: Const.ENTER_PLAY_MODE, in_custom_editor_play: bool, editor_conf: DomeEditorConf):
	if mode == Const.ENTER_PLAY_MODE.Loadout:
		StageManager.startStage("stages/loadout/multiplayerloadout")

	elif mode == Const.ENTER_PLAY_MODE.Title:
		StageManager.startStage("stages/intro/intro")
		if GameWorld.notifyAllMetaFileDamaged:
			StageManager.queueStage("stages/saveerror/SaveError")
			return
		else:
			StageManager.queueStage("stages/title/title")

	elif mode == Const.ENTER_PLAY_MODE.Level:
		var is_server: bool = UtilsOS.has_startup_argument("--server")
		var is_client: bool = UtilsOS.has_startup_argument("--client")
		var is_dev_networked: bool = in_custom_editor_play and \
		(editor_conf.multiplayer_mode == Const.DEV_ENTER_MULTIPLAYER_MODE.NETWORK) or (is_server or is_client)

		print("RUNNING IN DEV MODE")
		if GameWorld.devState.has("lockedSeed") and GameWorld.devState.lockedSeed != null:
			Level.setSeed(GameWorld.devState.lockedSeed)
		var loadout = Loadout.default()

		var ld1 = LoadoutDome.new()
		ld1.primaryGadgetId = "droneyard"
		ld1.domeId = "dome1"
		if in_custom_editor_play:
			ld1.primaryGadgetId = editor_conf.p1_primaryGadgetid
			ld1.domeId = Const.ENTER_DOME_TO_STRING_ID[editor_conf.p1_dome]
		ld1.teamId = "team1"
		ld1.petId = "pet6"
		ld1.additionalGadgets = []
		loadout.domes = [ld1]

		var is_versus: bool = not (in_custom_editor_play and editor_conf.game_mode == Const.ENTER_GAME_MODE.RELIC)
		if is_versus:
			var ld2 = LoadoutDome.new()
			ld2.primaryGadgetId = "shield"
			ld2.domeId = "dome2"
			if in_custom_editor_play:
				ld2.primaryGadgetId = editor_conf.p2_primaryGadgetid
				ld2.domeId = Const.ENTER_DOME_TO_STRING_ID[editor_conf.p2_dome]
			ld2.teamId = "team2"
			ld2.petId = "pet1"
			loadout.domes.append(ld2)

		loadout.modeId = CONST.MODE_VERSUS
		if in_custom_editor_play:
			if editor_conf.game_mode == Const.ENTER_GAME_MODE.RELIC:
				loadout.modeId = CONST.MODE_RELICHUNT
			if editor_conf.game_mode == Const.ENTER_GAME_MODE.VERSUS:
				loadout.modeId = CONST.MODE_VERSUS

		loadout.modeConfig = {CONST.MODE_CONFIG_MAP_ARCHETYPE: CONST.MAP_MEDIUM, CONST.MODE_CONFIG_PRESTIGE_VARIANT: CONST.MODE_PRESTIGE_PROVOCATION}

		loadout.worldId = "" if fixedWorld == 0 else "world" + str(fixedWorld)
		loadout.palette = ""
		var lk1 = LoadoutKeeper.new()
		lk1.playerId = "player1"
		lk1.teamId = "team1"
		lk1.keeperId = "keeper1"
		if in_custom_editor_play:
			lk1.keeperId = editor_conf.p1_keeper
		lk1.skinId = "skin0"
		lk1.deviceId = 0
		lk1.peerId = 1
		lk1.tutorialsActive = false
		var lk2 = LoadoutKeeper.new()
		lk2.playerId = "player2"
		lk2.teamId = "team1" if loadout.modeId == CONST.MODE_RELICHUNT else "team2"
		lk2.keeperId = "keeper1"
		if in_custom_editor_play:
			lk2.keeperId = editor_conf.p2_keeper
		lk2.skinId = "skin0"
		lk2.deviceId = 1 if not is_dev_networked else 0
		lk2.tutorialsActive = false
		var two_players: bool = editor_conf.nmb_of_players == Const.ENTER_PLAYERS_NMB.TWO_PLAYERS
		loadout.keepers = [lk1, lk2] if two_players or is_dev_networked else [lk1]
		lk2.peerId = 1

		var is_networked_server = is_dev_networked and is_server
		var is_networked_client = is_dev_networked and not is_server
		var is_one_machine: bool = not is_dev_networked
		var is_editor_forced_split_screen: bool = in_custom_editor_play and \
		editor_conf.multiplayer_mode == Const.DEV_ENTER_MULTIPLAYER_MODE.SPLIT
		if is_dev_networked and is_server:
			Lobby.simple_add(lk1.deviceId)
			while Lobby.members.size() <= 1:
				await (get_tree().process_frame)
			var client_peer_id: int = Network.clients[0].peer_id
			lk2.peerId = client_peer_id
		elif is_one_machine:
			Lobby.simple_add(lk1.deviceId)
			if is_editor_forced_split_screen:
				Lobby.simple_add(lk2.deviceId)
		elif is_networked_client:
			while Network.clients.size() == 0:

				await (get_tree().process_frame)
			Lobby.simple_add(lk2.deviceId)
		if is_networked_server or is_one_machine:
			for lk: LoadoutKeeper in loadout.keepers:
				var member: = Lobby.get_member_by_player_id(lk.playerId)
				member.keeper_id = Utils.encode_tech_id(lk.keeperId)
			Lobby.send_lobby_update()

		if is_editor_forced_split_screen:

			Options.enableSplitScreen = true
			Network.multiplayer_mode = Network.MultiplayerMode.ONLINE_ENET

		var startData = LevelStartData.new()
		startData.loadout = loadout
		if fixedMap != "":
			startData.tileDataPresetId = fixedMap





		var shouldStartStage: bool = is_networked_server or is_one_machine
		if shouldStartStage:
			StageManager.startStage("stages/landing/landing", [startData])
	else:
		Logger.error("Unknown enter play mode type set.")

func loadDevState() -> void :
	var save: = FileAccess.open(SaveGame.DEV_STATE_FILE, FileAccess.ModeFlags.READ)
	if save != null:
		var i = save.get_as_text()
		var test_json_conv = JSON.new()
		test_json_conv.parse(i)
		var parsed = test_json_conv.get_data()
		if parsed:
			GameWorld.devState = parsed
		save.close()

func _process(delta):
	if Input.is_action_just_pressed("screenshot"):
		var image = get_viewport().get_texture().get_image()
		image.save_png("../screenshots/s_" + str(screenshotIndex) + ".png")
		screenshotIndex += 1

	if Input.is_action_just_pressed("toggle_dev_mode") and GameWorld.qaOptions:
		Audio.sound("alarm")
		GameWorld.devMode = not GameWorld.devMode
		GameWorld.devModeActivated = true

	if GameWorld.qaOptions and Input.is_action_just_pressed("switch_resolution"):
		if get_viewport().size == Vector2i(1920, 1080):
			get_window().size = Vector2i(960, 540)
		elif get_viewport().size == Vector2i(960, 540):
			get_window().size = Vector2i(480, 270)
		elif get_viewport().size == Vector2i(480, 270):
			get_window().max_size = Vector2i(1920, 1200)
			get_window().size = Vector2i(1920, 1200)


		else:
			get_window().max_size = Vector2i(1920, 1080)
			get_window().size = Vector2i(1920, 1080)
		print("Set viewport size to " + str(get_window().size))

func logDebuggingInfo():
	print("")
	prints("Dome Keeper Version", GameWorld.version)
	prints(OS.get_name(), OS.get_distribution_name())
	prints(OS.get_processor_name(), "(" + str(OS.get_processor_count()) + ")", "Memory:", OS.get_memory_info()["physical"])
	prints(RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), \
	"(API:", RenderingServer.get_video_adapter_api_version(), ")")
	print("")

func _prewarmShaders():

	var resourcepacker = preload("res://content/gadgets/ressourcepacker/ResourcePackerEffect.tscn").instantiate()
	add_child(resourcepacker)
