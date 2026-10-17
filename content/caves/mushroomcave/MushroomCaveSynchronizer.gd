extends Synchronizer

func _ready() -> void :
	super._ready()

	owner.hit.connect(on_mushroom_hit)

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_bool(owner.hasMushroom)
	stream.encode_float(owner.timeUntilNewMushroom)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	owner.hasMushroom = stream.decode_bool()
	owner.timeUntilNewMushroom = stream.decode_float()

	if not owner.hasMushroom:
		owner.get_node("%Mushroom").visible = false
	if owner.currentState == Cave.State.REVEALED:
		owner.get_node("%AmbSound").startSound()

func on_mushroom_hit(keeper: Keeper) -> void :
	network_rpc(remote_mushroom_hit.bind(keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_mushroom_hit(playerId: String) -> void :
	owner.registerHit(playerId)
