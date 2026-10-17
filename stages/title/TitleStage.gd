class_name TitleStage
extends Stage

const SHOW_MESSAGE: = "show-message"

var isMenuIn: = false
var startMode: = ""
var messageToShow: = ""
var additionalMessageToShow: = ""

func build(data: Array):
	var current_ModLoaderUserProfile = ModLoaderUserProfile.get_current()
	if is_instance_valid(current_ModLoaderUserProfile):
		print(current_ModLoaderUserProfile.get_active_string())

	if data.size() > 0:
		startMode = data[0]
		match startMode:
			CONST.SHOW_MESSAGE:
				messageToShow = data[1]
				additionalMessageToShow = data[2]

	Style.setPalette("palette_1_1")

	Lobby.clear()
	Keepers.clear()
	Level.loadout.keepers.clear()

	Style.init($Canvas / MainMenu)
	Style.init($Canvas / AdditionalMenu)
	Style.init($Canvas / VersionContainer)
	Style.init($Canvas / PatchNotesPanel)
	Style.init($Canvas / CreditsPanel)
	Style.init($Canvas / NoStreamContainer)
	Style.init($Canvas / PrestigePanel)
	Style.init($Canvas / GamerTagContainer)

	match GameWorld.buildType:
		CONST.BUILD_TYPE.DEMO:
			find_child("BuildLabel").text = "Demo Build"
		CONST.BUILD_TYPE.PLAYTEST:
			find_child("BuildLabel").text = "Playtest Build"
		CONST.BUILD_TYPE.FULL:
			find_child("BuildLabel").text = ""
		CONST.BUILD_TYPE.EXHIBITION:
			find_child("BuildLabel").text = "Exhibition Build"

	find_child("NoStreamContainer").visible = GameWorld.buildType == CONST.BUILD_TYPE.PLAYTEST

	if GameWorld.devMode:
		find_child("BuildLabel").text += "Dev mode "
	if GameWorld.qaOptions:
		find_child("BuildLabel").text += "QA Build "
	if GameWorld.unlockAllButton:
		find_child("BuildLabel").text += "Preview Build "

	find_child("UnlockEverythingButton").visible = GameWorld.unlockAllButton
	%SendLogButton.visible = GameWorld.devMode
	%NewGameMenu.visible = false
	%ContinueGameMenu.visible = false


	var i = preload("res://stages/title/TitleInputProcessor.gd").new()
	i.connect("close_panel", try_close_panel)
	i.integrate(self)

	if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		%OptionsButton.visible = false
		find_child("WhatsNewButton").visible = false
		find_child("QuitButton").visible = false
		Options.onlineMultiplayerDecided = true
		Options.allowOnlineMultiplayer = false

		var vid = $Canvas / VideoStreamPlayer
		var ei = preload("res://content/keeper/StationAbandonedInputProcessor.gd").new()
		ei.baseCountdown = 45
		ei.connect("no_inputs", Callable(vid, "start"))
		ei.connect("got_input", Callable(vid, "stop"))
		vid.connect("finished", Callable(ei, "resetTimer"))
		ei.integrate(self)

	if BuildCustomization.has_feature("disable_pc_options"):
		find_child("QuitButton").visible = false

	if BuildCustomization.has_feature("disable_modding"):
		%ModdingButton.visible = false

	if BuildCustomization.has_feature("disable_update_menu"):
		find_child("WhatsNewButton").visible = false

	if BuildCustomization.has_feature("enable_gamer_tag"):
		find_child("GamerTagContainer").visible = true
		%GamerTagLabel.set_gamer_tag(Platform.get_username(), Platform.get_platform_id())

	if BuildCustomization.has_feature("porting_credits_splashscreen"):
		%ModingHSeparator.visible = false
		%ModingTitleLabel.visible = false
		%ModingDescLabel.visible = false
		%PortingHSeparator.visible = true
		%PortingTitleLabel.visible = true
		%PortingHBoxContainer.visible = true

	for button in find_child("AdditionalButtons").get_children():
		button.connect("focus_entered", on_additional_menu_button_entered.bind(button))
	for button in find_child("MainMenuButtons").get_children():
		button.connect("focus_entered", on_main_menu_button_entered.bind(button))

	%PrestigeLeaderboardButton.visible = GameWorld.isUnlocked(CONST.MODE_PRESTIGE)

	if GameWorld.notifyDamagedMetaFile:
		var popup = preload("res://gui/savefallback/SaveFallbackPopup.tscn").instantiate()
		$Canvas.add_child(popup)

	if GameWorld.devMode:
		%SendLogButton.pressed.connect(_on_send_log_button_pressed)

func _on_send_log_button_pressed() -> void :
	var log_id = randi()
	print("Log uploaded to Sentry with ID %d." % log_id)
	var event_id = Engine.get_singleton("SentrySDK").capture_message("Remote Upload: Log %d" % log_id)
	openMessagePopup("Log successfully uploaded with ID %d. Please give this ID to the developer when reporting the issue." % log_id, "Sentry event id: %s" % event_id, %NewGameButton, true)

func on_main_menu_button_entered(button):
	%JoinMultiplayerButton.focus_neighbor_bottom = button.get_path()

func on_additional_menu_button_entered(button):
	var b
	if find_child("ContinueButton").visible:
		b = find_child("ContinueButton")
	else:
		b = find_child("NewGameButton")
	b.focus_neighbor_left = button.get_path()
	button.focus_neighbor_right = b.get_path()

func copy_version_to_clipboard(ev):
	if ev is InputEventMouseButton:
		DisplayServer.clipboard_set(GameWorld.getVersionPrint())

var moveDuration: = 0.6
var defaultDelay: = 1.6
var mainMenuPos
var additionalMenuPos
var versionContainerPos
var gamerTagContainerPos
func beforeStart():

	Options.updateWindowMode(true)

	GameWorld.setShowMouse(Options.useMouseMenus)

	mainMenuPos = $Canvas / MainMenu.position.y
	additionalMenuPos = $Canvas / AdditionalMenu.position.y
	versionContainerPos = $Canvas / VersionContainer.position.y
	gamerTagContainerPos = $Canvas / GamerTagContainer.position.y
	$Canvas / MainMenu.position.y = $Canvas / MainMenu.get_viewport_rect().size.y + 5
	$Canvas / AdditionalMenu.position.y = $Canvas / AdditionalMenu.get_viewport_rect().size.y + 5
	$Canvas / VersionContainer.position.y = - $Canvas / VersionContainer.size.y - 5
	$Canvas / GamerTagContainer.position.y = - $Canvas / GamerTagContainer.size.y - 5
	find_child("VersionLabel").text = GameWorld.getVersionPrint()
	if GameWorld.qaOptions or GameWorld.devMode:
		find_child("VersionLabel").gui_input.connect(copy_version_to_clipboard)
	%PatchNotesPanel.visible = false
	%PrestigePanel.visible = false
	find_child("CreditsPanel").visible = false

	match startMode:
		CONST.SHOW_MESSAGE:
			Network.multiplayer_mode = Network.MultiplayerMode.OFFLINE_SINGLEPLAYER
			var buttonToFocus = %NewGameButton
			if %ContinueButton.visible:
				buttonToFocus = %ContinueButton
			openMessagePopup(messageToShow, additionalMessageToShow, buttonToFocus)
		_:
			Network.multiplayer_mode = Network.MultiplayerMode.OFFLINE_SINGLEPLAYER
			if Options.onlineMultiplayerDecided or BuildCustomization.has_feature("disable_allow_online_option"):
				if GameWorld.notifyKeybindingsReset:
					GameWorld.notifyKeybindingsReset = false
					var popup = preload("res://stages/title/KeybindingResetPopup.tscn").instantiate()
					$Canvas.add_child(popup)
					popup.grabFocus()
					find_child("Overlay").showOverlay()

					var i = preload("res://gui/PopupInput.gd").new()
					popup.confirmed.connect( func():
						i.desintegrate()
						Audio.sound("gui_select")
						Options.resetKeyBindingsToDefault()
						moveMenuIn(0.3)
						find_child("Overlay").hideOverlay()
					)
					i.popup = popup
					i.integrate(self)
				else:
					moveMenuIn()
			else:
				openTelemetryPopup()

	Audio.startIntro()

func openTelemetryPopup():
	var popup = preload("res://systems/telemetry/TelemetryPopup.tscn").instantiate()
	$Canvas.add_child(popup)
	find_child("Overlay").showOverlay()

	var i = preload("res://gui/PopupInput.gd").new()
	i.canClose = false
	popup.connect("disable_online", disableOnlineServices.bind(i))
	popup.connect("enable_online", enableOnlineServices.bind(i))
	i.connect("stopping", popup.queue_free)
	i.popup = popup
	i.integrate(self)
	return i

func openMessagePopup(message: String, additionalMessage: String, buttonToFocusAfterclosed: Button, hideOverlay: = true):
	var popup = preload("res://stages/title/TitleMessagePopup.tscn").instantiate()
	$Canvas.add_child(popup)
	find_child("Overlay").showOverlay()

	popup.set_message(message, additionalMessage)

	var i = preload("res://gui/PopupInput.gd").new()
	i.popup = popup
	i.connect("onStop", close_popup.bind(i.popup, buttonToFocusAfterclosed, true, hideOverlay))
	i.integrate(self)

func enableOnlineServices(ip):
	Audio.sound("gui_select")
	ip.desintegrate()
	Options.onlineMultiplayerDecided = true
	Options.allowOnlineMultiplayer = true
	Options.saveOptions()
	Backend.updateEnableTracking()
	var overlayStillNeeded = $Canvas.has_node("HostSessionPanel") or $Canvas.has_node("JoinSessionPanel")
	if not overlayStillNeeded:
		find_child("Overlay").hideOverlay()
	moveMenuIn(0.3)

func disableOnlineServices(ip):
	Audio.sound("gui_select")
	ip.desintegrate()
	GameWorld.lastViewedOptionsCategory = "Game"
	Options.onlineMultiplayerDecided = true
	Options.allowOnlineMultiplayer = false
	Options.saveOptions()
	Backend.updateEnableTracking()
	var overlayStillNeeded = $Canvas.has_node("HostSessionPanel") or $Canvas.has_node("JoinSessionPanel")
	if not overlayStillNeeded:
		find_child("Overlay").hideOverlay()
	moveMenuIn(0.3)

func moveMenuIn(delay: = defaultDelay):
	if isMenuIn:
		return

	isMenuIn = true
	$Tween.interpolate_property($Canvas / MainMenu, "position:y", $Canvas / MainMenu.position.y, mainMenuPos, moveDuration, Tween.TRANS_CUBIC, Tween.EASE_OUT, delay)
	$Tween.interpolate_property($Canvas / AdditionalMenu, "position:y", $Canvas / AdditionalMenu.position.y, additionalMenuPos, moveDuration, Tween.TRANS_CUBIC, Tween.EASE_OUT, delay + 0.2)
	$Tween.interpolate_property($Canvas / VersionContainer, "position:y", $Canvas / VersionContainer.position.y, versionContainerPos, moveDuration, Tween.TRANS_CUBIC, Tween.EASE_OUT, delay + moveDuration)
	$Tween.interpolate_property($Canvas / GamerTagContainer, "position:y", $Canvas / GamerTagContainer.position.y, gamerTagContainerPos, moveDuration, Tween.TRANS_CUBIC, Tween.EASE_OUT, delay + moveDuration)

	var has_sp_save: = SaveGame.has_autosave(true)
	var has_mp_save: bool = (SaveGame.has_autosave(false) and not BuildCustomization.has_feature("disable_multi"))
	if has_sp_save or has_mp_save:
		var cb = find_child("ContinueButton")
		cb.show()
		$Tween.interpolate_callback(InputSystem, delay + 0.5 * moveDuration, "grabFocus", find_child("ContinueButton"))
		cb.focus_neighbor_left = %PrestigeLeaderboardButton.get_path() if %PrestigeLeaderboardButton.visible else %CreditsButton.get_path()
	else:
		find_child("ContinueButton").hide()
		$Tween.interpolate_callback(InputSystem, delay + 0.5 * moveDuration, "grabFocus", %NewGameButton)
		%NewGameButton.focus_neighbor_left = %PrestigeLeaderboardButton.get_path() if %PrestigeLeaderboardButton.visible else %CreditsButton.get_path()
	$Tween.start()

func setMenuMovedIn():
	isMenuIn = true
	$Canvas / MainMenu.position.y = mainMenuPos
	$Canvas / AdditionalMenu.position.y = additionalMenuPos
	$Canvas / VersionContainer.position.y = versionContainerPos
	$Canvas / GamerTagContainer.position.y = gamerTagContainerPos

	var has_sp_save: = SaveGame.has_autosave(true)
	var has_mp_save: = SaveGame.has_autosave(false)
	if has_sp_save or has_mp_save:
		var cb = find_child("ContinueButton")
		cb.show()
		cb.focus_neighbor_left = %PrestigeLeaderboardButton.get_path() if %PrestigeLeaderboardButton.visible else %CreditsButton.get_path()
	else:
		find_child("ContinueButton").hide()
		%NewGameButton.focus_neighbor_left = %PrestigeLeaderboardButton.get_path()

func try_close_panel():
	if %NewGameMenu.visible:
		%NewGameMenu.visible = false
		InputSystem.grabFocus( %NewGameButton)
	elif %ContinueGameMenu.visible:
		%ContinueGameMenu.visible = false
		InputSystem.grabFocus( %ContinueButton)

func _on_ContinueButton_pressed() -> void :
	var has_sp_save: = SaveGame.has_autosave(true)
	var has_mp_save: bool = (SaveGame.has_autosave(false) and not BuildCustomization.has_feature("disable_multi"))
	%ContinueSingleplayerButton.disabled = not has_sp_save
	%ContinueMultiplayerButton.disabled = not has_mp_save

	if has_sp_save and not has_mp_save:
		continue_game("singleplayer")
	elif has_mp_save:
		Audio.sound("gui_select")
		%NewGameMenu.visible = false
		%ContinueGameMenu.visible = true
		if not %ContinueSingleplayerButton.disabled:
			InputSystem.grabFocus( %ContinueSingleplayerButton)
		elif not %ContinueMultiplayerButton.disabled:
			InputSystem.grabFocus( %ContinueMultiplayerButton)

func continue_game(save_folder: String):
	Audio.sound("gui_title_continue")
	SaveGame.loadRollingSavegame(save_folder)
	find_child("ContinueButton").disabled = true
	%ContinueSingleplayerButton.disabled = true
	%ContinueMultiplayerButton.disabled = true

func _on_ModdingButton_pressed():
	Audio.sound("gui_title_options")
	var i = preload("res://systems/modding/ModdingPopupInput.gd").new()
	i.blockAllKeys = true
	i.popup = preload("res://systems/modding/ModdingPopup.tscn").instantiate()
	$Canvas.add_child(i.popup)
	i.integrate(self)
	i.connect("onStop", close_popup.bind(i.popup, %ModdingButton, true))
	find_child("Overlay").showOverlay()

func _on_OptionsButton_pressed() -> void :
	Audio.sound("gui_title_options")
	var i = preload("res://systems/options/OptionsInputProcessor.gd").new()
	i.blockAllKeys = true
	i.globalInput = true
	i.popup = preload("res://systems/options/OptionsPanel.tscn").instantiate()
	i.stickReceiver = i.popup
	$Canvas.add_child(i.popup)
	i.popup.setFromOptions()
	i.integrate(self)
	i.connect("onStop", close_popup.bind(i.popup, %OptionsButton, true))
	i.popup.connect("close", i.desintegrate)
	find_child("Overlay").showOverlay()

func _on_QuitButton_pressed() -> void :
	Audio.sound("gui_quit_confirm")
	Backend.event("game_quit")
	Backend.sendBufferedEvents()
	$Tween.interpolate_callback(get_tree(), 0.4, "quit")
	$Tween.start()

func _on_WhatsNewButton_pressed() -> void :
	Audio.sound("gui_select")
	%PatchNotesPanel.visible = true
	InputSystem.grabFocus( %PatchNotesPanel.find_child("CancelButton"))

	var i = preload("res://content/shared/ControllerScrollInputProcessor.gd").new()
	i.popup = %PatchNotesPanel
	i.scrollTarget = i.popup.find_child("ScrollContainer").get_v_scroll_bar()
	i.integrate(self)
	i.connect("onStop", close_popup.bind( %PatchNotesPanel, %WhatsNewButton))
	find_child("Overlay").showOverlay()

func _on_CreditsButton_pressed():
	Audio.sound("gui_title_credits")
	find_child("CreditsPanel").visible = true
	InputSystem.grabFocus(find_child("CreditsPanel").find_child("CancelButton"))

	var i = preload("res://content/shared/ControllerScrollInputProcessor.gd").new()
	i.popup = find_child("CreditsPanel")
	i.scrollTarget = i.popup.find_child("ScrollContainer").get_v_scroll_bar()
	i.integrate(self)
	i.connect("onStop", close_popup.bind( %CreditsPanel, %CreditsButton))
	find_child("Overlay").showOverlay()

func _on_UnlockEverythingButton_pressed():
	Audio.sound("gui_select")
	GameWorld.unlockEverything()
	find_child("UnlockEverythingButton").disabled = true

func _on_singleplayer_button_pressed() -> void :
	Audio.sound("gui_title_newgame")
	StageManager.startStage("stages/loadout/multiplayerloadout")
	disable_new_game_options()

func _on_splitscreen_button_pressed() -> void :
	Audio.sound("gui_title_newgame_splitscreen")
	StageManager.startStage("stages/loadout/multiplayerloadout")
	Network.multiplayer_mode = Network.MultiplayerMode.OFFLINE_SPLITSCREEN
	disable_new_game_options()

func disable_new_game_options() -> void :
	%SingleplayerButton.disabled = true
	%SplitscreenButton.disabled = true
	%HostMultiplayerButton.disabled = true
	%JoinMultiplayerButton.disabled = true

func _on_new_game_button_pressed() -> void :
	if BuildCustomization.has_feature("disable_multi"):
		_on_singleplayer_button_pressed()
		return

	Audio.sound("gui_select")
	%NewGameMenu.visible = true
	%ContinueGameMenu.visible = false
	InputSystem.grabFocus( %SingleplayerButton)

func _on_prestige_leaderboard_button_pressed() -> void :
	Audio.sound("gui_select")
	%PrestigePanel.visible = true
	InputSystem.grabFocus( %PrestigePanel.find_child("CancelButton"))

	var i = preload("res://gui/PopupInput.gd").new()
	i.popup = %PrestigePanel
	%PrestigePanel.loadData()
	i.integrate(self)
	i.connect("onStop", close_popup.bind( %PrestigePanel, %PrestigeLeaderboardButton))
	find_child("Overlay").showOverlay()

func close_popup(popup, button_to_focus, free_popup: = false, hide_overlay: = true):
	Audio.sound("gui_select")
	if free_popup:
		$Canvas.remove_child(popup)
		popup.queue_free()
	else:
		popup.visible = false
	InputSystem.grabFocus(button_to_focus)
	if hide_overlay:
		find_child("Overlay").hideOverlay()

	if not isMenuIn:
		moveMenuIn(0.4)

func on_multiplayer_host_privilege_checked(result):
	InputSystem.grabFocus( %HostMultiplayerButton)
	if (result == true):
		if BuildCustomization.has_feature("disable_lan_multiplayer") and not GameWorld.is_allowOnlineMultiplayer():
			var i = StageManager.currentStage.openTelemetryPopup()
			i.canClose = true
			i.connect("stopping", open_host_panel)
			i.connect("onStop", close_popup.bind(i.popup, %HostMultiplayerButton, true))
		else:
			open_host_panel()

func on_multiplayer_host_privilege_checked_deferred(result):
	on_multiplayer_host_privilege_checked.call_deferred(result)

func open_host_panel():
	if BuildCustomization.has_feature("disable_lan_multiplayer") and not GameWorld.is_allowOnlineMultiplayer():
		return

	var i = preload("res://gui/PopupInput.gd").new()
	i.popup = preload("res://stages/title/host_session_panel.tscn").instantiate()
	$Canvas.add_child(i.popup)
	i.integrate(self)
	i.connect("onStop", close_popup.bind(i.popup, %HostMultiplayerButton, true))
	if BuildCustomization.has_feature("disable_lan_multiplayer"):
		find_child("Overlay").tween.stop_all()
	find_child("Overlay").showOverlay()

func _on_host_multiplayer_button_pressed() -> void :
	Audio.sound("gui_select")
	%HostMultiplayerButton.release_focus()


	if Network.is_network_ready(BuildCustomization.has_feature("disable_lan_multiplayer")) or not GameWorld.is_allowOnlineMultiplayer():
		Platform.check_online_privilege(on_multiplayer_host_privilege_checked_deferred)
	else:
		openMessagePopup("network.error.offline", "", %HostMultiplayerButton, true)

func on_multiplayer_join_privilege_checked(result):
	InputSystem.grabFocus( %JoinMultiplayerButton)
	if (result == true):
		if BuildCustomization.has_feature("disable_lan_multiplayer") and not GameWorld.is_allowOnlineMultiplayer():
			var i = StageManager.currentStage.openTelemetryPopup()
			i.canClose = true
			i.connect("stopping", open_join_panel)
			i.connect("onStop", close_popup.bind(i.popup, %JoinMultiplayerButton, true))
		else:
			open_join_panel()

func on_multiplayer_join_privilege_checked_deferred(result):
	call_deferred("on_multiplayer_join_privilege_checked", result)

func open_join_panel():
	if BuildCustomization.has_feature("disable_lan_multiplayer") and not GameWorld.is_allowOnlineMultiplayer():
		return

	var i = preload("res://gui/PopupInput.gd").new()
	i.popup = preload("res://stages/title/join_session_panel.tscn").instantiate()
	i.popup.join_with_code_failed.connect(_on_join_code_failed)
	$Canvas.add_child(i.popup)
	i.integrate(self)
	i.connect("onStop", close_popup.bind(i.popup, %JoinMultiplayerButton, true))
	if BuildCustomization.has_feature("disable_lan_multiplayer"):
		find_child("Overlay").tween.stop_all()
	find_child("Overlay").showOverlay()

func _on_join_code_failed(button_to_focus_after_closed: Button, reason: String) -> void :
	openMessagePopup(reason, "", button_to_focus_after_closed, false)

func _on_join_multiplayer_button_pressed() -> void :
	Audio.sound("gui_select")
	%JoinMultiplayerButton.release_focus()


	if Network.is_network_ready(BuildCustomization.has_feature("disable_lan_multiplayer")) or not GameWorld.is_allowOnlineMultiplayer():
		Platform.check_online_privilege(on_multiplayer_join_privilege_checked_deferred)
	else:
		openMessagePopup("network.error.offline", "", %JoinMultiplayerButton, true)

func _on_continue_singleplayer_button_pressed() -> void :
	continue_game("singleplayer")

func _on_continue_multiplayer_button_pressed() -> void :
	if true:
		Platform.check_online_privilege(on_continue_multiplayer_privilege_checked_deferred)
	else:
		continue_multiplayer()

func continue_multiplayer() -> void :
	SaveGame.keeper_data_loaded.connect(go_to_device_selection_stage, CONNECT_ONE_SHOT)
	continue_game("multiplayer")

func on_continue_multiplayer_privilege_checked_deferred(result):
	call_deferred("on_continue_multiplayer_privilege_checked", result)

func on_continue_multiplayer_privilege_checked(result):
	if result:
		continue_multiplayer()

func go_to_device_selection_stage() -> void :
	StageManager.startStage("stages/deviceselection/deviceselection")
