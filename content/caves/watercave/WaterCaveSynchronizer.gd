extends Synchronizer

var water_nodes: Array[Sprite2D] = []

func _ready() -> void :
	super._ready()

	water_nodes = [
		owner.get_node("%Water1"), 
		owner.get_node("%Water2"), 
		owner.get_node("%Water3"), 
	]

	for i in range(water_nodes.size()):
		water_nodes[i].hit.connect(on_water_hit.bind(i))
		water_nodes[i].regrown.connect(on_water_regrown.bind(i))

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	for water in water_nodes:
		stream.encode_bool(water.taken)
		stream.encode_float(water.regrowCooldown)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	var i: = 0
	while stream.is_not_finished():
		water_nodes[i].taken = stream.decode_bool()
		water_nodes[i].regrowCooldown = stream.decode_float()
		water_nodes[i].visible = not water_nodes[i].taken
		i += 1

func on_water_hit(keeper: Keeper, idx: int) -> void :
	network_rpc(remote_water_hit.bind(idx, keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_water_hit(idx: int, playerId: String) -> void :
	water_nodes[idx].registerHit(playerId)

func on_water_regrown(idx: int) -> void :
	network_rpc(remote_water_regrown.bind(idx), true)

@rpc("reliable")
func remote_water_regrown(idx: int) -> void :
	water_nodes[idx].regrow()
