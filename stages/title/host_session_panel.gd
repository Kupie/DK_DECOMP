extends PanelContainer

func _ready():
	%SplitscreenCheckBox.button_pressed = Options.enableSplitScreen
	%CrossplayCheckBox.button_pressed = Options.enableCrossplay
	if BuildCustomization.has_feature("system_crossplay_option"):
		%CrossplayCheckBox.visible = false
		%CrossplayButton.visible = true
		update_crossplay_button()
	elif not Network.is_network_ready(true):
		%CrossplayCheckBox.disabled = true
		update_crossplay_button()

	Style.init(self)
	InputSystem.grabFocus( %StartButton)

	if GameWorld.lastHostMode == "local" and not BuildCustomization.has_feature("disable_lan_multiplayer"):
		%LANButton.button_pressed = true
	else:
		%PlayfabButton.button_pressed = true
	%CrossplayPanelContainer.visible = %PlayfabButton.button_pressed and GameWorld.is_allowOnlineMultiplayer()

	if not GameWorld.is_allowOnlineMultiplayer():
		%LANButton.button_pressed = true
		%PlayfabButton.button_pressed = false

	if BuildCustomization.has_feature("disable_lan_multiplayer"):
		%LANButton.visible = false
		%LANLabel.visible = false
		%PlayfabButton.visible = false
		%LANButton.button_pressed = false
		%PlayfabButton.button_pressed = true

func _process(delta: float) -> void :
	if BuildCustomization.has_feature("system_crossplay_option"):
		update_crossplay_button()

func update_crossplay_button():
	if Network.is_network_ready(true) and (GameWorld.forcePlayfab or Platform.is_crossplay_enabled()):
		%CrossplayButton.text = "multiplayer.host.crossplay.enabled"
	else:
		%CrossplayButton.text = "multiplayer.host.crossplay.disabled"



func _on_lan_button_pressed() -> void :
	Audio.sound("gui_select")
	GameWorld.lastHostMode = "local"
	%CrossplayPanelContainer.visible = false

func _on_playfab_button_pressed() -> void :
	Audio.sound("gui_select")
	if not GameWorld.is_allowOnlineMultiplayer():
		var i = StageManager.currentStage.openTelemetryPopup()
		i.connect("stopping", onMultiplayerDecided)
	else:
		GameWorld.lastHostMode = "online"
	%CrossplayPanelContainer.visible = GameWorld.is_allowOnlineMultiplayer()

func onMultiplayerDecided():
	if GameWorld.is_allowOnlineMultiplayer():
		GameWorld.lastHostMode = "online"
		%PlayfabButton.button_pressed = true
	else:
		GameWorld.lastHostMode = "local"
		%LANButton.button_pressed = true
	InputSystem.grabFocus( %StartButton)

func _on_splitscreen_check_box_pressed() -> void :
	Audio.sound("gui_select")
	Options.enableSplitScreen = %SplitscreenCheckBox.button_pressed

func _on_crossplay_check_box_pressed() -> void :
	Audio.sound("gui_select")
	Options.enableCrossplay = %CrossplayCheckBox.button_pressed

func _on_start_button_pressed() -> void :
	if %LANButton.button_pressed and not BuildCustomization.has_feature("disable_lan_multiplayer"):
		Network.create_enet_host()
	else:
		if not GameWorld.is_crossplay_enabled() and Platform.can_create_platform_lobby():
			Network.create_platform_lobby()
		else:
			Network.create_crossplay_lobby()

	Options.saveOptions()
	Audio.sound("gui_title_newgame")
	StageManager.startStage("stages/loadout/multiplayerloadout")
	%LANButton.disabled = true
	%PlayfabButton.disabled = true

func _on_playfab_button_focus_entered() -> void :
	%SplitscreenCheckBox.focus_neighbor_top = %PlayfabButton.get_path()

func _on_lan_button_focus_entered() -> void :
	%SplitscreenCheckBox.focus_neighbor_top = %LANButton.get_path()

func _on_cancel_button_focus_entered() -> void :
	%SplitscreenCheckBox.focus_neighbor_bottom = %CancelButton.get_path()

func _on_start_button_focus_entered() -> void :
	%SplitscreenCheckBox.focus_neighbor_bottom = %StartButton.get_path()
