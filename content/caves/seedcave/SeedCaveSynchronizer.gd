class_name SeedCaveSynchronizer
extends Synchronizer
const MINERAL_TREE = preload("res://content/gadgets/mineraltree/MineralTree.tscn")

func _ready() -> void :
	super._ready()

	owner.hit.connect(on_seed_hit)

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_bool(owner.hasSeed)

	var nmb_of_trees: int = owner.trees.size()
	stream.encode_u8(nmb_of_trees)
	for tree_id: int in owner.trees:
		var tree: MineralTree = owner.trees[tree_id]
		var serialized_tree: PackedByteArray = var_to_bytes(tree.serialize())
		var serialized_compressed_tree: = serialized_tree.compress(FileAccess.CompressionMode.COMPRESSION_DEFLATE)
		stream.encode_vector2(tree.position)
		stream.encode_u32(serialized_tree.size())
		stream.encode_var(serialized_compressed_tree)

	var nmb_of_seeds: int = owner.seeds.size()
	stream.encode_u8(nmb_of_seeds)
	for seed_id: int in owner.seeds:
		var seed_drop: Seed = owner.seeds[seed_id]
		var serialized_seed: PackedByteArray = var_to_bytes(seed_drop.serialize())
		var serialized_compressed_seed: PackedByteArray = serialized_seed.compress(FileAccess.CompressionMode.COMPRESSION_DEFLATE)
		stream.encode_u32(serialized_seed.size())
		stream.encode_var(serialized_compressed_seed)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	owner.hasSeed = stream.decode_bool()

	if not owner.hasSeed:
		owner.get_node("%ActiveSprite").queue_free()
		owner.get_node("%AmbSound").queue_free()
	if owner.currentState == Cave.State.REVEALED:
		owner.get_node("%AmbSound").startSound()

	var nmb_of_trees: int = stream.decode_u8()
	for tree_idx: int in nmb_of_trees:
		var position: Vector2 = stream.decode_vector2()
		var serialized_size: int = stream.decode_u32()
		var serialized_compressed_tree: PackedByteArray = stream.decode_var()
		var serialized_decompressed_tree: PackedByteArray = serialized_compressed_tree.decompress(serialized_size, 
			FileAccess.CompressionMode.COMPRESSION_DEFLATE)
		var serialized_tree: Dictionary = bytes_to_var(serialized_decompressed_tree)
		var tree: MineralTree = MINERAL_TREE.instantiate()
		Level.drops.add_child(tree)
		owner.trees[serialized_tree.UID] = tree
		tree.deserialize(serialized_tree)
		tree.position = position

	var nmb_of_seeds: int = stream.decode_u8()
	for seed_idx: int in nmb_of_seeds:
		var serialized_size: int = stream.decode_u32()
		var serialized_compressed_seed: PackedByteArray = stream.decode_var()
		var serialized_decompressed_seed: PackedByteArray = serialized_compressed_seed.decompress(serialized_size, 
			FileAccess.CompressionMode.COMPRESSION_DEFLATE)
		var serialized_seed: Dictionary = bytes_to_var(serialized_decompressed_seed)
		var seed_drop: Seed = Level.drops.get_drop(serialized_seed["UID"])
		seed_drop.deserialize(serialized_seed)

func on_seed_hit(keeper: Keeper) -> void :
	network_rpc(remote_seed_hit.bind(keeper.playerId), true)

@rpc("reliable", "any_peer")
func remote_seed_hit(playerId: String) -> void :
	owner.registerHit(playerId)
