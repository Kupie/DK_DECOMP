extends Container

@export var runStats: Container

var isIn: = false
var animationDone: = false
var is_server: = true

func init(is_server: bool, assignment: Assignment, earned_medals: int):
	self.is_server = is_server
	if GameWorld.won:
		find_child("TitleLabel").text = "level.gameover.assignment.win.title"
	else:
		find_child("TitleLabel").text = "level.gameover.assignment.lose.title"

	var isChallengeMode = Data.of("assignment.challengemode")
	if isChallengeMode:
		%AssignmentTypeLabel.text = tr("assignment." + assignment.id + ".title") + " - " + tr("assignment.mode.challenge")
	else:
		%AssignmentTypeLabel.text = tr("assignment." + assignment.id + ".title") + " - " + tr("assignment.mode.regular")

	if GameWorld.won:
		%RestartRunButton.visible = false
		if is_server:
			%ClientDisconnectButton.visible = false
			if GameWorld.unlockableElements.size() > 0:
				%MainMenuButton.visible = false
				%UnlockElementButton.visible = true
				%AnotherRunButton.visible = false
			else:
				%UnlockElementButton.visible = false
				%AnotherRunButton.visible = true
		else:
			%MainMenuButton.visible = false
			%ClientDisconnectButton.visible = true
			%UnlockElementButton.visible = false
			%AnotherRunButton.visible = false

		var progress = GameWorld.assignmentProgress.get(assignment.id, 0)
		if earned_medals == 0 and progress == 2:
			%NewBadgesLabel.visible = false
		else:
			%NewBadgesLabel.text = ""
			if earned_medals > 0:
				%NewBadgesLabel.text = tr("level.gameover.assignment.badges")
			if not isChallengeMode:
				%NewBadgesLabel.text += "\n" + tr("level.gameover.assignment.badges.more")
		%ExplanationLabel.text = tr("level.gameover.assignment.completed")
	else:
		if is_server:
			%MainMenuButton.visible = true
			%ClientDisconnectButton.visible = false
			%RestartRunButton.visible = true
			%AnotherRunButton.visible = Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER
			%UnlockElementButton.visible = false
		else:
			%MainMenuButton.visible = false
			%ClientDisconnectButton.visible = true
			%RestartRunButton.visible = false
			%AnotherRunButton.visible = false
			%UnlockElementButton.visible = false

		%ExplanationLabel.text = tr("level.gameover.assignment.failed")
		if assignment.goalvalue is PropertyCheck and assignment.goalvalue.property_key.ends_with("contribution"):
			var resource = assignment.goalvalue.property_key.replace("assignments.", "").replace("contribution", "")
			var goal: String = tr("assignment.condition.deliver" + resource) % assignment.goalvalue.expected_value
			%NewBadgesLabel.text = tr("assignment.goaltype.delivery.failed").format({"goal": goal, "amount": str(Data.of("team1.assignments." + resource + "contribution"))})
		else:
			%NewBadgesLabel.visible = false

	SaveGame.saveRollingMetaState()

	runStats.init(self, "team1", is_server)
	if is_server:

		Network.rpc_if_state(Network.remote_set_recorder_data.bind(Recorder.to_bytes()), Network.ConnectionState.LEVEL_STAGE_SYNC)
		Network.rpc_if_state(Network.remote_set_run_stats.bind(GameWorld.run_stats_to_bytes()), Network.ConnectionState.LEVEL_STAGE_SYNC)
	else:
		Network.stats_set.connect(on_stats_set)

	if not Data.ofOr("postrun.showmine", false):
		find_child("MineViewButton").visible = false

	Style.init(self)

func on_stats_set() -> void :
	runStats.init(self, "team1", is_server)

func updateFocus():
	if not is_server:
		InputSystem.grabFocus( %ClientDisconnectButton)
		return

	if %AnotherRunButton.visible:
		InputSystem.grabFocus( %AnotherRunButton)
	elif %UnlockElementButton.visible:
		InputSystem.grabFocus( %UnlockElementButton)
	elif %RestartRunButton.visible:
		InputSystem.grabFocus( %RestartRunButton)
	else:
		InputSystem.grabFocus( %MainMenuButton)

func moveIn():
	if isIn:
		return

	InputSystem.singleFocus = true

	Level.stage.pause(false)
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
		StageManager.startStage("stages/loadout/multiplayerloadout")

func _on_restart_run_button_pressed() -> void :
	if isIn:
		continuePressed()
		Network.restart_run()

func _on_MineViewButton_pressed():
	if isIn:
		Level.stage.startMineView()

func continuePressed():
	Audio.stopMusic()
	Audio.sound("gui_select")
	find_child("MainMenuButton").disabled = true
	%AnotherRunButton.disabled = true
	find_child("MineViewButton").disabled = true
	%RestartRunButton.disabled = true
	%UnlockElementButton.disabled = true

func focusMineViewButton():
	InputSystem.grabFocus(find_child("MineViewButton"))


func _on_unlock_element_button_pressed() -> void :
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

func _exit_tree() -> void :
	InputSystem.singleFocus = false

func _on_ClientDisconnectButton_pressed() -> void :
	continuePressed()
	Network.close_session()
