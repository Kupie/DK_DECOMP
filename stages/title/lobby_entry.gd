class_name LobbyEntry
extends PanelContainer

signal freed

var server: Discovery.LocalServer
var lobby: Discovery.PlatformLobby

var timeElapsed: float
var dereferenced: bool = false
var timeUntilExpired: float

var host_platform_user_id: String

func _ready():
	Style.init(self)
	timeElapsed = 0.0

	if BuildCustomization.has_feature("enable_see_profile_buttons"):
		%ProfileButton.visible = true

func setLobby(lobby: Discovery.PlatformLobby):
	self.lobby = lobby
	%NameLabel.set_gamer_tag(lobby.lobby_name, lobby.host_platform_id)
	%NameLabel.icon_size = 60
	%OriginLabel.text = "Version " + lobby.version
	host_platform_user_id = lobby.host_platform_user_id
	timeUntilExpired = Discovery.LOBBY_DISCOVERY_TIME + 1
	Discovery.clear_lobbies.connect(dereference)

func setServer(server: Discovery.LocalServer):
	self.server = server
	%NameLabel.set_gamer_tag(server.username, "")
	%OriginLabel.text = "Version " + server.version
	timeUntilExpired = Discovery.ENET_DISCOVERY_TIME + 1
	Discovery.clear_servers.connect(dereference)

func _on_join_button_pressed() -> void :
	Audio.sound("gui_title_newgame")
	if GameWorld.fixedIpJoin != "":
		Network.create_enet_client(GameWorld.fixedIpJoin, Network.ENET_LISTEN_PORT)
	elif lobby:
		StageManager.startStage("stages/client/loading")
		Platform.join_lobby(lobby.lobby_id)
	elif server:
		Network.create_enet_client(server.ip_address, server.port)
	else:
		pass


func _process(delta: float) -> void :
	if dereferenced:
		timeElapsed += delta
		if timeElapsed > timeUntilExpired:
			remove()

func touch() -> void :
	dereferenced = false
	timeElapsed = 0.0

func dereference() -> void :
	dereferenced = true

func remove() -> void :
	freed.emit()
	queue_free()

func _on_profile_button_pressed() -> void :
	Platform.show_player_profile_card(host_platform_user_id)
