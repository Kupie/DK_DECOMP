extends Node

signal server_found(server: LocalServer)
signal lobby_found(lobby: PlatformLobby)
signal clear_lobbies
signal clear_servers

enum DiscoveryState{NONE, SEARCHING, BROADCASTING}
enum LobbySearchState{SEARCHING, WAITING, ERROR}

const DISCOVERY_PORT: int = Network.ENET_LISTEN_PORT + 1
const ENET_DISCOVERY_TIME: float = 1.0
const LOBBY_DISCOVERY_TIME: float = 10.0

var _allow_local_search: bool = true

var discovery_server: UDPServer
var discovery_client: PacketPeerUDP
var discovery_state: DiscoveryState = DiscoveryState.NONE
var lobby_search_state: LobbySearchState = LobbySearchState.WAITING
var enet_discovery_time: float = 0.0
var lobby_discovery_time: float = 0.0
var discovered_servers: Array[LocalServer] = []

class LocalServer:
	var ip_address: String
	var port: int
	var version: String
	var username: String

class PlatformLobby:
	var lobby_name: String
	var lobby_id: String
	var host_platform_user_id: String
	var host_platform_id: String
	var version: String

func _ready() -> void :
	if BuildCustomization.has_feature("disable_lan_multiplayer"):
		_allow_local_search = false

func _process(delta: float) -> void :
	var time_agnostic_delta: = delta / Engine.time_scale

	match discovery_state:
		DiscoveryState.SEARCHING:
			if _allow_local_search:
				process_discovery_client(time_agnostic_delta)
			if GameWorld.is_allowOnlineMultiplayer():
				prcoess_lobby_search(time_agnostic_delta)
		DiscoveryState.BROADCASTING:
			if _allow_local_search:
				process_discovery_server()

func start_discovering() -> void :
	if is_instance_valid(discovery_server):
		discovery_server.stop()
		discovery_server = null

	discovered_servers = []

	if _allow_local_search:
		start_discovering_servers()
	start_discovering_lobbies()

	discovery_state = DiscoveryState.SEARCHING

func stop_discovering() -> void :
	match discovery_state:
		DiscoveryState.SEARCHING:
			if _allow_local_search:
				stop_discovering_servers()
			else:
				discovery_state = DiscoveryState.NONE
			stop_discovering_lobbies()
		DiscoveryState.BROADCASTING:
			pass


func start_discovery_server() -> void :
	if not _allow_local_search:
		return

	stop_discovering_servers()

	discovery_server = UDPServer.new()
	discovery_server.listen(DISCOVERY_PORT)
	discovery_state = DiscoveryState.BROADCASTING

func stop_discovery_server() -> void :
	if is_instance_valid(discovery_server):
		discovery_server.stop()
		discovery_server = null
	discovery_state = DiscoveryState.NONE

func start_discovering_servers() -> void :
	discovery_client = PacketPeerUDP.new()
	discovery_client.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	discovery_client.set_broadcast_enabled(true)

func stop_discovering_servers() -> void :
	if is_instance_valid(discovery_client):
		discovery_client.close()
		discovery_client = null

	if discovery_state != DiscoveryState.BROADCASTING:
		discovery_state = DiscoveryState.NONE

func send_discovery_packet() -> void :
	if not is_instance_valid(discovery_client):
		push_error("Asking for a discovery packet without a valid PacketPeerUDP.")

	var buffer: = PackedByteStream.new()
	buffer.resize(2)
	buffer.encode_u8(0)
	buffer.encode_u8(0)
	discovery_client.put_packet(buffer.data)

func process_discovery_server() -> void :
	discovery_server.poll()

	if discovery_server.is_connection_available():
		var packet_peer: = discovery_server.take_connection()
		if _is_valid_discovery_packet(packet_peer.get_packet()):
			var buffer: = PackedByteStream.new()
			buffer.encode_u8(0)
			buffer.encode_u8(1)
			buffer.encode_u16(Network.ENET_LISTEN_PORT)
			buffer.encode_var(Version.VERSION)
			buffer.encode_var(Platform.get_username())
			packet_peer.put_packet(buffer.data)

		else:
			push_warning("Invalid discovery packet: ", packet_peer.get_packet())

func _is_valid_discovery_packet(buffer: PackedByteArray) -> bool:
	return buffer.size() == 2 and buffer.decode_u8(0) == 0 and buffer.decode_u8(1) == 0

func process_discovery_client(delta: float) -> void :
	if discovery_client.get_available_packet_count() > 0:
		var buffer: = PackedByteStream.from_bytes(discovery_client.get_packet())
		if _is_valid_response_packet(buffer):
			var server: = LocalServer.new()
			server.ip_address = discovery_client.get_packet_ip()
			server.port = buffer.decode_u16()
			server.version = buffer.decode_var()
			server.username = buffer.decode_var()

			var found_existing: bool = false
			for existing in discovered_servers:
				if existing.ip_address == server.ip_address and existing.port == server.port:

					existing.version = server.version
					found_existing = true
					break

			if not found_existing:
				discovered_servers.append(server)
			server_found.emit(server)

		else:
			push_warning("Invalid response packet: ", buffer)

	enet_discovery_time -= delta
	if enet_discovery_time <= 0.0:
		clear_servers.emit()
		send_discovery_packet()
		enet_discovery_time = ENET_DISCOVERY_TIME

func _is_valid_response_packet(buffer: PackedByteStream) -> bool:
	return buffer.decode_u8() == 0 and buffer.decode_u8() == 1



func start_discovering_lobbies() -> void :
	Platform.lobby_search_complete.connect(_on_platform_lobby_search_complete)
	Platform.lobby_search_error.connect(_on_platform_lobby_search_error)
	Platform.lobby_found.connect(_on_platform_lobby_found)

func stop_discovering_lobbies() -> void :
	if lobby_search_state == LobbySearchState.SEARCHING:
		return

	if Platform.lobby_found.is_connected(_on_platform_lobby_found):
		Platform.lobby_found.disconnect(_on_platform_lobby_found)
		Platform.lobby_search_complete.disconnect(_on_platform_lobby_search_complete)
		Platform.lobby_search_error.disconnect(_on_platform_lobby_search_error)

func prcoess_lobby_search(delta: float) -> void :
	if lobby_search_state == LobbySearchState.WAITING:
		lobby_discovery_time -= delta
		if lobby_discovery_time <= 0.0:
			lobby_search_state = LobbySearchState.SEARCHING
			Platform.find_lobbies()

func _on_platform_lobby_search_complete() -> void :
	lobby_discovery_time = LOBBY_DISCOVERY_TIME
	lobby_search_state = LobbySearchState.WAITING
	clear_lobbies.emit()

	if discovery_state == DiscoveryState.NONE:
		stop_discovering_lobbies()

func _on_platform_lobby_search_error() -> void :
	lobby_search_state = LobbySearchState.ERROR

	if discovery_state == DiscoveryState.NONE:
		stop_discovering_lobbies()

func _on_platform_lobby_found(lobby_data: Dictionary) -> void :
	var platform_lobby: = PlatformLobby.new()
	platform_lobby.lobby_name = lobby_data["name"]
	platform_lobby.lobby_id = str(lobby_data["id"])
	platform_lobby.host_platform_user_id = str(lobby_data.get("host_platform_user_id", ""))
	platform_lobby.host_platform_id = str(lobby_data.get("host_platform_id", ""))
	platform_lobby.version = lobby_data.get("version", "Unknown Version")

	if platform_lobby.lobby_name == "" or platform_lobby.lobby_name.strip_edges() == "":
		push_error("Lobby found with empty name, data: ", lobby_data)

		if not GameWorld.devMode:
			return

	lobby_found.emit(platform_lobby)
