class_name WeaponSynchronizer
extends Synchronizer

var station: DomeStation
var weapons: Dictionary = {}

func _ready() -> void :
	super._ready()
	station = owner as DomeStation

	station.weaponsChanged.connect(on_weapons_changed)


func get_delta_data(send_to_peer_id: int) -> PackedByteArray:
	var weaponsToSync: Array[PrimaryWeapon]

	for weapon in weapons.values():
		if weapon.started:
			weaponsToSync.append(weapon)

	return get_weapon_data(weaponsToSync, send_to_peer_id)

func get_initial_data(send_to_peer_id: int) -> PackedByteArray:
	var weaponsToSync: Array[PrimaryWeapon]

	for weapon in weapons.values():
		weaponsToSync.append(weapon)

	return get_weapon_data(weaponsToSync, send_to_peer_id)

func get_weapon_data(weapons: Array[PrimaryWeapon], send_to_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_u8(weapons.size())

	for weapon in weapons:
		var buffer: PackedByteArray = weapon.get_delta_data()
		stream.encode_u32(weapon.UID)
		stream.encode_u32(buffer.size())
		stream.append_array(buffer)

		if send_to_peer_id == 1:
			buffer = weapon.get_hit_data()
			stream.encode_u32(buffer.size())
			stream.append_array(buffer)

	return stream.data

func set_delta_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	var weapons_to_decode: = stream.decode_u8()
	while weapons_to_decode > 0:
		var UID: = stream.decode_u32()
		var delta_buffer_size: = stream.decode_u32()
		var delta_data: = stream.slice(delta_buffer_size).data

		var hit_data: PackedByteArray
		if multiplayer.is_server():
			var hit_buffer_size: = stream.decode_u32()
			hit_data = stream.slice(hit_buffer_size).data

		if weapons.has(UID):
			weapons[UID].set_delta_data(delta_data)
			if multiplayer.is_server():
				weapons[UID].set_hit_data(hit_data)
		else:
			push_warning("Tried to set a weapon's delta data but it didn't exist. UID: ", UID)
		weapons_to_decode -= 1

func on_weapons_changed() -> void :

	weapons.clear()
	for weapon in station.getControlledWeapons():
		weapons[weapon.UID] = weapon



		if multiplayer.is_server():
			network_rpc(network_spawn.bind(weapon.UID))

	if multiplayer.is_server():
		network_rpc(_remote_set_initial_data.bind(Network.tick_count, get_initial_data(0)))


@rpc("reliable", "any_peer")
func network_spawn(UID: int) -> void :

	if not weapons.has(UID):
		var dome = Level.domesByTeamId[station.teamId]
		dome.remoteAddWeapon(UID, station)
