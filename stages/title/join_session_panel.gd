extends PanelContainer

signal join_with_code_failed

var found_lobbies: Dictionary = {}
var found_servers: Dictionary = {}

func _ready():
	$NumPadPanel.callback_on_accept = _on_join_with_code_pressed
	%SplitscreenCheckBox.button_pressed = Options.enableSplitScreen
	%CrossplayCheckBox.button_pressed = Options.enableCrossplay
	if BuildCustomization.has_feature("system_crossplay_option"):
		%CrossplayCheckBox.visible = false
		%CrossplayButton.visible = true
		update_crossplay_button()

	Style.init(self)

	InputSystem.grabFocus( %CancelButton)

	Discovery.server_found.connect(_on_server_found)
	Discovery.lobby_found.connect(_on_platform_lobby_found)
	Discovery.start_discovering()

	Network.join_code_failed.connect(_on_join_code_failed)

	%JoinCodeContainer.visible = GameWorld.is_allowOnlineMultiplayer()
	%LocalOnly.visible = not GameWorld.is_allowOnlineMultiplayer() and not BuildCustomization.has_feature("disable_lan_multiplayer")
	%CrossplayPanelContainer.visible = GameWorld.is_allowOnlineMultiplayer() and BuildCustomization.has_feature("show_crossplay_on_join")

func _process(delta: float) -> void :
	%DiscoverLabel.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.002)

	if BuildCustomization.has_feature("system_crossplay_option"):
		update_crossplay_button()

func update_crossplay_button():
	if GameWorld.forcePlayfab or Platform.is_crossplay_enabled():
		%CrossplayButton.text = "multiplayer.host.crossplay.enabled"
	else:
		%CrossplayButton.text = "multiplayer.host.crossplay.disabled"

func _on_splitscreen_check_box_pressed() -> void :
	Options.enableSplitScreen = %SplitscreenCheckBox.button_pressed

func _on_server_found(server: Discovery.LocalServer):
	if found_servers.has(server.ip_address):
		found_servers[server.ip_address].touch()
		return

	var e = preload("res://stages/title/lobby_entry.tscn").instantiate()
	e.freed.connect(on_entry_freed.bind(server.ip_address, found_servers))
	e.setServer(server)
	%Lobbies.add_child(e)

	found_servers[server.ip_address] = e

func _on_platform_lobby_found(lobby: Discovery.PlatformLobby) -> void :
	if found_lobbies.has(lobby.lobby_id):
		found_lobbies[lobby.lobby_id].touch()
		return

	var e = preload("res://stages/title/lobby_entry.tscn").instantiate()
	e.freed.connect(on_entry_freed.bind(lobby.lobby_id, found_lobbies))
	e.setLobby(lobby)
	%Lobbies.add_child(e)

	found_lobbies[lobby.lobby_id] = e

func on_entry_freed(key: String, found_list: Dictionary) -> void :
	found_list.erase(key)

func stop_discovery():
	Discovery.stop_discovering()
	if Discovery.server_found.is_connected(_on_server_found):
		Discovery.server_found.disconnect(_on_server_found)
	if Discovery.server_found.is_connected(_on_platform_lobby_found):
		Discovery.server_found.disconnect(_on_platform_lobby_found)

func _on_tree_exiting() -> void :
	stop_discovery()

func onMultiplayerDecided():
	if GameWorld.is_allowOnlineMultiplayer():
		%JoinCodeContainer.visible = true
		%LocalOnly.visible = false
		GameWorld.lastHostMode = "online"
	else:
		%JoinCodeContainer.visible = false
		%LocalOnly.visible = true
		GameWorld.lastHostMode = "local"

func _on_local_only_pressed() -> void :
	var i = StageManager.currentStage.openTelemetryPopup()
	i.connect("stopping", onMultiplayerDecided)


func _on_join_with_code_pressed() -> void :

	%JoinWithCode.focus_mode = FOCUS_NONE
	%JoinWithCode.disabled = true
	if GameWorld.fixedIpJoin != "":
		Network.create_enet_client(GameWorld.fixedIpJoin, Network.ENET_LISTEN_PORT)
	else:
		Network.join_from_code( %JoinCode.text)

func _on_join_code_text_changed(new_text: String) -> void :
	pass

func _on_join_code_failed(reason: String) -> void :
	%JoinWithCode.focus_mode = FOCUS_ALL
	%JoinWithCode.disabled = false
	$NumPadPanel.hide()
	join_with_code_failed.emit( %JoinWithCode, reason)

func _on_join_code_gui_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_select"):
		DisplayServer.virtual_keyboard_show( %JoinCode.text, %JoinCode.get_global_rect(), %JoinCode.virtual_keyboard_type, %JoinCode.max_length)

func _on_crossplay_check_box_pressed() -> void :
	Audio.sound("gui_select")
	Options.enableCrossplay = %CrossplayCheckBox.button_pressed
