class_name BombCaveSynchronizer
extends Synchronizer

func _ready() -> void :
	super._ready()
	owner.hit.connect(on_bomb_cave_hit)

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(owner.hasBomb)
	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	owner.hasBomb = stream.decode_bool()
	owner.setInitialState()

func on_bomb_cave_hit(keeper: Keeper) -> void :
	network_rpc(remote_bomb_cave_hit.bind(keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_bomb_cave_hit(playerId: String) -> void :
	owner.registerHit(playerId)

func on_bomb_state_updated(bomb: CaveBomb) -> void :
	network_rpc(remote_bomb_state_update.bind(bomb.UID, bomb.get_bomb_state()), false)

@rpc("reliable")
func remote_bomb_state_update(UID: int, buffer: PackedByteArray) -> void :
	if Level.drops.has_drop(UID):
		var bomb: CaveBomb = Level.drops.get_drop(UID) as CaveBomb
		if is_instance_valid(bomb):
			bomb.set_bomb_state(buffer)
