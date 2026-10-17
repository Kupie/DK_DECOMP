extends Synchronizer

func _ready() -> void :
	super._ready()

	owner.hit.connect(on_helmet_hit)

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_bool(owner.hasHelmet)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	owner.hasHelmet = stream.decode_bool()

	if not owner.hasHelmet:
		owner.get_node("%Sprite2D").play("empty")
	if owner.currentState == Cave.State.REVEALED:
		owner.get_node("%AmbSound").startSound()

func on_helmet_hit(keeper: Keeper) -> void :
	network_rpc(remote_helmet_hit.bind(keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_helmet_hit(playerId: String) -> void :
	owner.registerHit(playerId)
