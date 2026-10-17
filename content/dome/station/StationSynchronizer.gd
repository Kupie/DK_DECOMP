class_name StationSynchronizer
extends Synchronizer

var station: DomeStation

func _ready() -> void :
	super._ready()

	station = owner as DomeStation

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	var id_to_encode = -1
	if is_instance_valid(station.keeperInStation):
		var playerId = station.keeperInStation.playerId
		id_to_encode = Utils.encode_player_id(playerId)
	stream.encode_s8(id_to_encode)

	var weapons: = station.getControlledWeapons()
	stream.encode_u8(weapons.size())
	for weapon in weapons:
		stream.encode_u32(weapon.UID)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var playerIdInStation = stream.decode_s8()
	if playerIdInStation != -1:
		stationAuthorityApproved(Utils.decode_player_id(playerIdInStation))

	var known_UIDS: Array[int] = []
	for weapon in station.getControlledWeapons():
		known_UIDS.append(weapon.UID)

	var weapons_to_decode: = stream.decode_u8()
	while weapons_to_decode > 0:
		var UID: = stream.decode_u32()
		if not known_UIDS.has(UID):
			var dome = Level.domesByTeamId[station.teamId]
			dome.remoteAddWeapon(UID, station)
		weapons_to_decode -= 1

@rpc("reliable", "any_peer")
func requestStationAuthority(playerId: String) -> void :
	if is_instance_valid(station.keeperInStation) or (station.remoteStation and station.remoteStation.keeperInStation):

		return


	network_rpc(stationAuthorityApproved.bind(playerId), true)

@rpc("reliable", "call_local")
func stationAuthorityApproved(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	station.keeperId = keeper.techId
	keeper.enterStation(station)
	station.keeperInStation = keeper
	station.keeperEnteredStation()

	for w in station.getControlledWeapons():
		w.deviceId = keeper.deviceId


	station.setWeaponAuthority(keeper.peerId)


	if keeper.peerId == multiplayer.get_unique_id():
		Level.stage.startStationInput(keeper, station)

	if multiplayer.is_server():
		if not keeper.tree_exiting.is_connected(_on_keeper_tree_exiting):
			keeper.tree_exiting.connect(_on_keeper_tree_exiting, CONNECT_ONE_SHOT)

func _on_keeper_tree_exiting() -> void :
	network_rpc(releaseStationAuthority, true)

@rpc("reliable", "any_peer")
func releaseStationAuthority() -> void :
	if is_instance_valid(station.keeperInStation):
		station.keeperInStation.exitStation()
	station.keeperInStation = null
	station.keeperExitedStation()
	station.setWeaponAuthority(1)
