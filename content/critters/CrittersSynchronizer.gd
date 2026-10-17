class_name CrittersSynchronizer
extends Synchronizer


static var critter_scenes: Dictionary = {}

static func register_critter(critter_name: String, critter_scene: PackedScene) -> void :
	if critter_scenes.has(critter_name):
		return


	var test: Node2D = critter_scene.instantiate()
	if not test.has_method("init"):
		push_error("Attempted to register critter (%s) without required method: init" % critter_name)
		return

	if not test.has_method("set_spawn_data"):
		push_error("Attempted to register critter (%s) without required method: set_spawn_data" % critter_name)
		return

	critter_scenes[critter_name] = critter_scene



var critter_runtime_index: Dictionary = {}
var critter_reverse_lookup: Dictionary = {}
var critters: Dictionary = {}

func _ready() -> void :
	generate_runtime_index()
	super._ready()

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_var(critter_runtime_index)


	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	critter_runtime_index = stream.decode_var()

func generate_runtime_index() -> void :
	if not critter_runtime_index.is_empty():
		return

	var keys: = critter_scenes.keys()
	for i in range(keys.size()):
		critter_runtime_index[i] = keys[i]
		critter_reverse_lookup[keys[i]] = i

func on_critter_exiting(critter: Node2D) -> void :
	critters.erase(critter.UID)

@rpc("reliable")
func critter_state_update(state: int, direction: Vector2, UID: int) -> void :
	if critters.has(UID):
		var critter: Node2D = critters[UID]
		if critter.state != state:
			critter.change_state(state)
		critter.direction = direction



func network_spawn(critter_name: String, spawn_data: PackedByteArray) -> Node2D:
	var critter_index: int = critter_reverse_lookup[critter_name]
	network_rpc(spawn_critter.bind(critter_index, spawn_data), false)
	return spawn_critter(critter_index, spawn_data)

@rpc("reliable")
func spawn_critter(critter_index: int, spawn_data: PackedByteArray) -> Node2D:
	if Options.disableCritters:
		return

	var critter_scene: PackedScene = critter_scenes[critter_runtime_index[critter_index]]
	var critter: Node2D = critter_scene.instantiate()
	owner.add_child(critter)
	critter.set_spawn_data(spawn_data)
	critters[critter.UID] = critter
	critter.tree_exiting.connect(on_critter_exiting.bind(critter))
	critter.init()
	return critter
