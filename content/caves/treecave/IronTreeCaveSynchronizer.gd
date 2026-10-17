extends Synchronizer

var iron_nodes: Array[Sprite2D] = []

func _ready() -> void :
	super._ready()

	iron_nodes = [
		owner.get_node("%Iron1"), 
		owner.get_node("%Iron2"), 
		owner.get_node("%Iron3"), 
		owner.get_node("%Iron4"), 
		owner.get_node("%Iron5"), 
	]

	for i in range(iron_nodes.size()):
		iron_nodes[i].hit.connect(on_iron_hit.bind(i))
		iron_nodes[i].regrown.connect(on_iron_regrown.bind(i))

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	for iron in iron_nodes:
		stream.encode_bool(iron.taken)
		stream.encode_float(iron.regrowCooldown)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	var i: = 0
	while stream.is_not_finished():
		iron_nodes[i].taken = stream.decode_bool()
		iron_nodes[i].regrowCooldown = stream.decode_float()
		iron_nodes[i].visible = not iron_nodes[i].taken
		i += 1

func on_iron_hit(keeper: Keeper, idx: int) -> void :
	network_rpc(remote_iron_hit.bind(idx, keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_iron_hit(idx: int, playerId: String) -> void :
	iron_nodes[idx].registerHit(playerId)

func on_iron_regrown(idx: int) -> void :
	network_rpc(remote_iron_regrown.bind(idx), true)

@rpc("reliable")
func remote_iron_regrown(idx: int) -> void :
	iron_nodes[idx].regrow()
