extends Container

@export var keepGadgetPopup: PanelContainer
@export var titleLabel: Label
@export var mainMenuButton: Button
@export var mineViewButton: Button
@export var anotherRunButton: Button
@export var unlockElementButton: Button
@export var clientDisconnectButton: Button
@export var runStats: Container

var isIn: = false
var animationDone: = false
var is_server: = true
var _previousInput: InputEvent = null

func init(is_server: bool = true):
	self.is_server = is_server

	if GameWorld.won:
		titleLabel.text = "level.gameover.win.title"
	else:
		titleLabel.text = "level.gameover.lose.title"

	if Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER or GameWorld.won or GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		keepGadgetPopup.visible = false
	else:
		keepGadgetPopup.init(is_server)

	if is_server:
		clientDisconnectButton.visible = false

		if GameWorld.won and GameWorld.unlockableElements.size() > 0 and GameWorld.buildType != CONST.BUILD_TYPE.EXHIBITION:
			mainMenuButton.visible = false
			anotherRunButton.visible = false
			unlockElementButton.visible = true
		else:
			mainMenuButton.visible = true
			anotherRunButton.visible = true
			unlockElementButton.visible = false
	else:
		clientDisconnectButton.visible = true
		mainMenuButton.visible = false
		anotherRunButton.visible = false
		unlockElementButton.visible = false

	runStats.init(self, "team1", is_server)
	if is_server:

		Network.rpc_if_state(Network.remote_set_recorder_data.bind(Recorder.to_bytes()), Network.ConnectionState.LEVEL_STAGE_SYNC)
		Network.rpc_if_state(Network.remote_set_run_stats.bind(GameWorld.run_stats_to_bytes()), Network.ConnectionState.LEVEL_STAGE_SYNC)
	else:
		Network.stats_set.connect(on_stats_set)

	if not Data.ofOr("postrun.showmine", false):
		mineViewButton.visible = false

	Style.init(self)

func on_stats_set() -> void :
	runStats.init(self, "team1", is_server)

func updateFocus():
	if not is_server:
		InputSystem.grabFocus(clientDisconnectButton)
		return

	var fo = keepGadgetPopup.getFirstOption()
	if keepGadgetPopup.visible and fo:
		InputSystem.grabFocus(fo)
	elif unlockElementButton and unlockElementButton.visible:
		InputSystem.grabFocus(unlockElementButton)
	elif anotherRunButton.visible:
		InputSystem.grabFocus(anotherRunButton)
	else:
		InputSystem.grabFocus(mainMenuButton)

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

func _on_AnotherRunButton_pressed():
	if isIn:
		continuePressed()
		if multiplayer.is_server() and Network.clients.size() > 0:
			Network.return_party_to_loadout()
		elif GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
			StageManager.startStage("stages/loadout/multiplayerloadout")
		else:
			StageManager.startStage("stages/loadout/multiplayerloadout")

func _input(event: InputEvent) -> void :
	_previousInput = event

func _on_MineViewButton_pressed():
	if isIn:
		Level.stage.startMineView(_previousInput)

func continuePressed():
	Audio.stopMusic()
	Audio.sound("gui_select")
	mainMenuButton.disabled = true
	anotherRunButton.disabled = true
	mineViewButton.disabled = true
	clientDisconnectButton.disabled = true
	SaveGame.saveRollingMetaState()

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

func focusMineViewButton():
	InputSystem.grabFocus(mineViewButton)

func _on_ClientDisconnectButton_pressed() -> void :
	continuePressed()
	Network.close_session()

func _exit_tree() -> void :
	InputSystem.singleFocus = false
