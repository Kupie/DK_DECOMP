class_name NestCaveSynchronizer
extends Synchronizer

func _ready() -> void :
	super._ready()

	owner.hit.connect(on_egg_hit)

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_bool(owner.hasEgg)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	owner.hasEgg = stream.decode_bool()
	if not owner.hasEgg:
		owner.get_node("GizmoSpawn").queue_free()
		owner.get_node("Usable").queue_free()
		owner.get_node("Sprite2D").play("empty")

func on_egg_hit(keeper: Keeper) -> void :
	network_rpc(remote_egg_hit.bind(keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_egg_hit(playerId: String) -> void :
	owner.registerHit(playerId)
