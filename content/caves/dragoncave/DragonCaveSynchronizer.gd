class_name DragonCaveSynchronizer
extends Synchronizer

func _ready() -> void :
	super._ready()

	owner.get_node("%Egg").hit.connect(on_egg_hit)

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_bool(owner.hasEgg)
	stream.encode_bool(owner.needsCobalt)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	owner.hasEgg = stream.decode_bool()
	owner.needsCobalt = stream.decode_bool()

	if owner.needsCobalt:
		owner.get_node("%Egg").visible = false
	else:
		owner.get_node("%CobaltMarker").queue_free()
		if owner.hasEgg:
			owner.get_node("%Egg").visible = true
		else:
			owner.get_node("%Egg").queue_free()

	if owner.currentState == Cave.State.REVEALED:
		owner.get_node("%AmbSound").startSound()

func on_egg_hit(keeper: Keeper) -> void :
	network_rpc(remote_egg_hit.bind(keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_egg_hit(playerId: String) -> void :
	owner.get_node("%Egg").registerHit(playerId)
