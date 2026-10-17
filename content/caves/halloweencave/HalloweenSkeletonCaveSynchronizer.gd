extends Synchronizer

func _ready() -> void :
	super._ready()
	owner.hit.connect(on_halloween_cave_hit)

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(owner.hasSkeleton)
	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	owner.hasSkeleton = stream.decode_bool()
	owner.setInitialState()

func on_halloween_cave_hit(keeper: Keeper) -> void :
	network_rpc(remote_halloween_cave_hit.bind(keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_halloween_cave_hit(playerId: String) -> void :
	owner.registerHit(playerId)
