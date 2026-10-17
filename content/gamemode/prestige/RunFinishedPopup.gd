extends CenterContainer

var isIn: = false
var inScoreCount: = false

@onready var ScoreLabel = find_child("ScoreLabel")
@onready var ScoreUploadResult = find_child("ScoreUploadResult")
@onready var Leaderboard = find_child("PrestigeLeaderboard")

@export var runStats: Container

var currentScore: int
var totalScore: int
var currentTime: float
var totalTime: float

var scoreUploadMessage: String
var shoulShowUploadMessage: = false
var is_server: = true
var leaderboardName: = ""

func init(is_server: bool) -> void :
	self.is_server = is_server

func _ready() -> void :
	if get_parent() == get_tree().root:
		Platform.init(false)
		Data.apply("team1.prestige.baseperwave", 10)
		Data.apply("team1.prestige.multiplier", 1)
		Data.apply("team1.monsters.cycle", 1)
		Data.apply("team1.prestige.score", 10010)
		Data.apply("team1.prestige.sentcobalt", 1)
		Data.apply("inventory.totalsand", 1)
		GameWorld.version = "v1.1"
		$Tween.interpolate_callback(self, 0.3, "startScoreCount")
		$Tween.start()

	runStats.init(self, "team1", is_server)
	if is_server:

		Network.rpc_if_state(Network.remote_set_recorder_data.bind(Recorder.to_bytes()), Network.ConnectionState.LEVEL_STAGE_SYNC)
		Network.rpc_if_state(Network.remote_set_run_stats.bind(GameWorld.run_stats_to_bytes()), Network.ConnectionState.LEVEL_STAGE_SYNC)
	else:
		Network.stats_set.connect(on_stats_set)
	ScoreLabel.text = "0"

	%AnotherRunButton.visible = is_server
	find_child("VariationLabel").visible = true
	find_child("TitleLabel").text = "level.gameover.prestige.title"
	match Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT):
		CONST.MODE_PRESTIGE_COUNTDOWN:
			find_child("VariationLabel").text = tr("loadout.prestige.countdown")
		CONST.MODE_PRESTIGE_PROVOCATION:
			find_child("VariationLabel").text = tr("loadout.prestige.provocation")
		CONST.MODE_PRESTIGE_MINER:
			find_child("VariationLabel").text = tr("loadout.prestige.miner")
		CONST.MODE_PRESTIGE_ENDLESS:
			find_child("VariationLabel").text = tr("loadout.prestige.endless")

	if Level.loadout.modeConfig.get("friendly-mode", false):
		find_child("VariationLabel").text += " (" + tr("loadout.prestige.friend.mode") + ")"

	Style.init(self)

	ScoreUploadResult.text = ""
	scoreUploadMessage = tr("level.gameover.prestige.uploading.inprocess")
	totalScore = Data.of("team1.prestige.score")

	Leaderboard.connect("leaderboard_score_upload_success", leaderboard_Score_Upload_Success)
	Leaderboard.connect("leaderboard_score_upload_failed", leaderboard_Score_Upload_Failed)

	if Level.loadout.keepers.size() > 1:
		Leaderboard.twoPlayer = true
	var display_seasons = true
	match BuildCustomization.features["playfab_leaderboard_setup"]:
		BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_SOLO, BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_MULTI:
			display_seasons = false

	if Level.loadout.getLoadoutKeepers().size() <= 2:
		Leaderboard.start(Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT, ""), display_seasons)
		leaderboardName = Leaderboard.leaderboardName
		Leaderboard.uploadScore(totalScore)
	else:
		ScoreUploadResult.visible = false
		Leaderboard.visible = false

	if is_server:
		%ClientDisconnectButton.visible = false
		if GameWorld.won and GameWorld.unlockableElements.size() > 0:
			%MainMenuButton.visible = false
			%AnotherRunButton.visible = false
			%UnlockElementButton.visible = true
		else:
			%MainMenuButton.visible = true
			%AnotherRunButton.visible = true
			%UnlockElementButton.visible = false
	else:
		%MainMenuButton.visible = false
		%ClientDisconnectButton.visible = true
		%AnotherRunButton.visible = false
		%UnlockElementButton.visible = false

	if not Data.ofOr("postrun.showmine", false):
		find_child("MineViewButton").visible = false

func on_stats_set() -> void :
	runStats.init(self, "team1", is_server)

func _process(delta):
	if not inScoreCount:
		return

	if currentTime > totalTime or ScoreLabel.text == str(totalScore):
		currentTime = totalTime
		inScoreCount = false
		$FinalRaised.play()
		ScoreLabel.pivot_offset = ScoreLabel.size * 0.5
		$Tween.interpolate_property(ScoreLabel, "scale", Vector2.ONE * 3, Vector2.ONE, 0.5, Tween.TRANS_EXPO, 0, 0.1)
		$Tween.interpolate_callback($FinalDropped, 0.5, "play")
		$Tween.interpolate_callback(self, 1.0, "set", "shoulShowUploadMessage", true)
		$Tween.interpolate_callback(self, 1.1, "updateScoreUploadLabel")
		$Tween.start()

	var fraction = currentTime / totalTime
	var newText = str("%.0f" % (fraction * totalScore))

	if newText != ScoreLabel.text:
		ScoreLabel.text = newText
		$Ping.play()

	var deltaMod = 1.0 - 1.99 * abs(0.5 - fraction)
	currentTime += delta * 10000 * pow(min(deltaMod, 0.05), 3)

func updateScoreUploadLabel():

	if shoulShowUploadMessage:
		ScoreUploadResult.text = scoreUploadMessage
	else:
		ScoreUploadResult.text = ""

func startScoreCount():
	totalTime = 1.0 + pow(abs(totalScore), 0.4) * 0.02
	inScoreCount = true

func leaderboard_Score_Upload_Failed() -> void :
	shoulShowUploadMessage = true
	scoreUploadMessage = tr("level.gameover.prestige.uploading.failed")
	updateScoreUploadLabel()
	shoulShowUploadMessage = false

func leaderboard_Score_Upload_Success(score_changed: int, new_rank: int, prev_rank: int, ln: String) -> void :
	if leaderboardName != ln:
		return

	scoreUploadMessage = ""
	if totalScore == 0:
		scoreUploadMessage = tr("level.gameover.prestige.score.rankunchanged")
		updateScoreUploadLabel()
		return

	if score_changed == 1:
		scoreUploadMessage = tr("level.gameover.prestige.score.personalbest") + " "
	if new_rank == prev_rank:
		scoreUploadMessage += tr("level.gameover.prestige.score.rankunchanged")
	else:
		scoreUploadMessage += tr("level.gameover.prestige.score.rankimproved").format({"rank": new_rank})
	updateScoreUploadLabel()

func moveIn():
	if isIn:
		return

	InputSystem.singleFocus = true

	GameWorld.setShowMouse(Options.useMouseMenus)
	isIn = true
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property(self, "position:y", position.y, (get_viewport_rect().size.y - size.y) * 0.5, 1.2, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$Tween.interpolate_callback(self, 1.3, "startScoreCount")
	$Tween.interpolate_callback(self, 3.0, "updateFocus")
	$Tween.start()

func moveOut():
	if not isIn:
		return

	InputSystem.singleFocus = false

	isIn = false
	$Tween.interpolate_property(self, "position:y", position.y, get_viewport_rect().size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	$Tween.interpolate_callback(self, 0.5, "queue_free")
	$Tween.start()

func _on_MainMenuButton_pressed():
	if isIn:
		continuePressed()
		if multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
			Network.close_session()
		else:
			StageManager.startStage("stages/title/title")

func _on_AnotherRunButton_pressed():
	if isIn:
		continuePressed()
		if multiplayer.is_server() and Network.clients.size() > 0:
			Network.return_party_to_loadout()
		else:
			StageManager.startStage("stages/loadout/multiplayerloadout")

func continuePressed():
	Audio.stopMusic()
	Audio.sound("gui_select")
	%MainMenuButton.disabled = true
	%AnotherRunButton.disabled = true
	%MineViewButton.disabled = true

func _on_UnlockElementButton_pressed():
	visible = false
	Audio.sound("gui_select")
	var i = preload("res://gui/PopupInput.gd").new()
	var unlockablesPopup = preload("res://content/gamemode/unlockables/UnlockablesPopup.tscn").instantiate()
	unlockablesPopup.connect("proceed", i.desintegrate)
	unlockablesPopup.connect("back", i.desintegrate)
	unlockablesPopup.connect("back", unlockablesPopupBack)
	unlockablesPopup.connect("back", unlockablesPopup.queue_free)
	get_parent().add_child(unlockablesPopup)
	i.popup = unlockablesPopup
	i.integrate(Level.stage)

func unlockablesPopupBack() -> void :
	updateFocus()
	visible = true

func updateFocus():
	if not is_server:
		InputSystem.grabFocus( %ClientDisconnectButton)
		return

	if %AnotherRunButton.visible:
		InputSystem.grabFocus( %AnotherRunButton)
	elif %UnlockElementButton.visible:
		InputSystem.grabFocus( %UnlockElementButton)
	else:
		InputSystem.grabFocus( %MainMenuButton)

func _on_MineViewButton_pressed():
	if isIn:
		Level.stage.startMineView()

func focusMineViewButton():
	InputSystem.grabFocus(find_child("MineViewButton"))

func _exit_tree() -> void :
	InputSystem.singleFocus = false

func _on_client_disconnect_button_pressed() -> void :
	continuePressed()
	Network.close_session()
