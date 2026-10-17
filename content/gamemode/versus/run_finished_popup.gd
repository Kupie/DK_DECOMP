extends Container

@export var titleLabel: Label
@export var mainMenuButton: Button
@export var mineViewButton: Button
@export var clientDisconnectButton: Button
@export var startAnotherRunButton: Button

var isIn: = false
var animationDone: = false
var is_server: = true
var profile_buttons: Dictionary
var timelapse_button: Button

func init(is_server: bool, dead_team: String):
	self.is_server = is_server
	var loser_team_number = int(dead_team.lstrip("team"))
	var winner_team_number = 3 - loser_team_number
	titleLabel.text = tr("level.gameover.win.team") % str(winner_team_number)
	%LabelTeam1Title.text = tr("loadout.team") % "1"
	%LabelTeam2Title.text = tr("loadout.team") % "2"
	var local_platform_id = Platform.get_platform_id()
	var local_platform_user_id = Platform.get_user_id()
	for team in ["team1", "team2"]:
		profile_buttons[team] = []
		var i: = 0
		for keeper in Keepers.getAllOfTeam(team):
			var container = find_child("KeeperNameContainer" + Data.startCaptialized(team))
			if i % 2 == 1:
				var spacer = Control.new()
				spacer.custom_minimum_size.x = 40
				container.add_child(spacer)
			var keeper_sprite = preload("res://content/shared/keeper_in_ui.tscn").instantiate()
			keeper_sprite.set_keeper(keeper)
			container.add_child(keeper_sprite)
			var name_label = preload("res://gui/platform/gamertag/GamerTagLabel.tscn").instantiate()
			var keeper_platform_id = Lobby.get_member_by_player_id(keeper.playerId).platform_id
			var keeper_platform_user_id = Lobby.get_member_by_player_id(keeper.playerId).platform_user_id
			name_label.icon_size = 60
			name_label.set_gamer_tag(keeper.playerName, keeper_platform_id)
			container.add_child(name_label)
			if BuildCustomization.has_feature("enable_see_profile_buttons") and local_platform_id == keeper_platform_id and not local_platform_user_id == keeper_platform_user_id:
				var profile_button = Button.new()
				profile_button.grow_vertical
				profile_button.text = "level.gameover.win.team.profile"
				profile_button.connect("pressed", _on_profile_button_pressed.bind(keeper_platform_user_id))
				container.add_child(profile_button)
				profile_buttons[team].append(profile_button)
			i += 1

	if is_server:
		clientDisconnectButton.visible = false
		mainMenuButton.visible = true
		startAnotherRunButton.visible = true
	else:
		clientDisconnectButton.visible = true
		mainMenuButton.visible = false
		startAnotherRunButton.visible = false

	on_stats_set()
	if is_server:

		Network.rpc_if_state(Network.remote_set_recorder_data.bind(Recorder.to_bytes()), Network.ConnectionState.LEVEL_STAGE_SYNC)
		Network.rpc_if_state(Network.remote_set_run_stats.bind(GameWorld.run_stats_to_bytes()), Network.ConnectionState.LEVEL_STAGE_SYNC)
	else:
		Network.stats_set.connect(on_stats_set)

	mineViewButton.visible = Data.ofOr("postrun.showmine", false)

	Style.init(self)

func _ready() -> void :
	setup_profile_buttons()

func on_stats_set() -> void :
	%RunStatsTeam1.init(self, "team1", is_server, true)
	%RunStatsTeam2.init(self, "team2", is_server, true)
	timelapse_button = %RunStatsTeam1.pop_timelapse_button()
	if timelapse_button:
		timelapse_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%NavigationButtons.add_child(timelapse_button)
		%NavigationButtons.move_child(startAnotherRunButton, %NavigationButtons.get_child_count() - 1)
		%RunStatsTeam2.pop_timelapse_button()

func updateFocus():
	if not is_server:
		InputSystem.grabFocus(clientDisconnectButton)
		return

	InputSystem.grabFocus(startAnotherRunButton)

func moveIn():
	if isIn:
		return

	InputSystem.singleFocus = true

	GameWorld.setShowMouse(Options.useMouseMenus)
	isIn = true
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property(self, "position:y", position.y, (get_viewport_rect().size.y - size.y) * 0.5, 1.2, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$Tween.interpolate_callback(self, 1.3, "set", "animationDone", true)
	$Tween.interpolate_callback(self, 2.5, "updateFocus")
	$Tween.start()

func _on_MainMenuButton_pressed():
	if isIn:
		continuePressed()
		if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
			StageManager.startStage("stages/loadout/multiplayerloadout")
		elif multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
			Network.close_session()
		else:
			StageManager.startStage("stages/title/title")

func _on_MineViewButton_pressed():
	if isIn:
		Level.stage.startMineView()

func continuePressed():
	Audio.stopMusic()
	Audio.sound("gui_select")
	mainMenuButton.disabled = true
	mineViewButton.disabled = true
	clientDisconnectButton.disabled = true
	timelapse_button.disabled = true
	SaveGame.saveRollingMetaState()

func focusMineViewButton():
	InputSystem.grabFocus(mineViewButton)

func _on_ClientDisconnectButton_pressed() -> void :
	continuePressed()
	Network.close_session()

func _exit_tree() -> void :
	InputSystem.singleFocus = false

func _on_profile_button_pressed(platform_user_id: String):
	Platform.show_player_profile_card(platform_user_id)

func setup_profile_buttons():
	if !profile_buttons["team1"].is_empty() and !profile_buttons["team1"].is_empty():
		var i: = 0
		var team1_size = profile_buttons["team1"].size()
		var team2_size = profile_buttons["team2"].size()
		while i < team1_size or i < team2_size:
			if i > 50:
				assert (false, "Initializing profile buttons gone wrong")
				break

			var team1_i = i if i < team1_size else team1_size - 1
			var team2_i = i if i < team2_size else team2_size - 1

			if team1_i >= team2_i:
				profile_buttons["team1"][team1_i].focus_neighbor_right = profile_buttons["team2"][team2_i].get_path()

			if team2_i >= team1_i:
				profile_buttons["team2"][team2_i].focus_neighbor_left = profile_buttons["team1"][team1_i].get_path()
			i += 1

func _on_another_run_button_pressed() -> void :
	if isIn:
		continuePressed()
		if multiplayer.is_server() and Network.clients.size() > 0:
			Network.return_party_to_loadout()
		elif GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
			StageManager.startStage("stages/loadout/multiplayerloadout")
		else:
			StageManager.startStage("stages/loadout/multiplayerloadout")
