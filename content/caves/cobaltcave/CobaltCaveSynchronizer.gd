extends Synchronizer

var cobalt_nodes: Array[Sprite2D] = []

func _ready() -> void :
	super._ready()

	cobalt_nodes = [
		owner.get_node("%Cobalt1"), 
		owner.get_node("%Cobalt2"), 
	]

	for i in range(cobalt_nodes.size()):
		cobalt_nodes[i].hit.connect(on_cobalt_hit.bind(i))

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	for cobalt in cobalt_nodes:
		stream.encode_bool(cobalt.taken)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	var i: = 0
	while stream.is_not_finished():
		cobalt_nodes[i].taken = stream.decode_bool()
		cobalt_nodes[i].visible = not cobalt_nodes[i].taken
		i += 1

func on_cobalt_hit(keeper: Keeper, idx: int) -> void :
	network_rpc(remote_cobalt_hit.bind(idx, keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_cobalt_hit(idx: int, playerId: String) -> void :
	cobalt_nodes[idx].registerHit(playerId)
