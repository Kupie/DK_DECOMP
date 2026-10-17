class_name PetSynchronizer
extends Synchronizer


var pets: = {}
var eggs: = {}

func init() -> void :
	Level.drops.synchronizer.drop_spawned.connect(on_drop_spawned)

func get_initial_data(peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	for pet in pets.values():
		stream.encode_u32(pet.UID)
		stream.encode_var(pet.id)
		stream.encode_vector2(pet.position)
		stream.encode_var(pet.currentPos)
		stream.encode_bool(pet.get_node("Sprite2D").flip_h)
		stream.encode_u32(pet.random.seed)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	while stream.is_not_finished():
		var petUID: = stream.decode_u32()
		var petId: = stream.decode_var() as String

		var pet: = spawn(petId, petUID)
		var position: = stream.decode_vector2()
		var positionName: = stream.decode_var() as String
		var flip_h: = stream.decode_bool()
		var animation_seed: = stream.decode_u32()

		pet.setPlace(positionName, position, flip_h, animation_seed)

func on_drop_spawned(carryable: Carryable) -> void :
	if not carryable is Egg:
		return

	var egg: = carryable as Egg
	connect_egg_signals(egg)

func connect_egg_signals(egg: Egg) -> void :
	if eggs.has(egg.UID):
		return
	eggs[egg.UID] = true
	if not multiplayer.is_server():
		return
	egg.pet_added.connect(network_add_pet_from_egg.bind(egg.UID))
	egg.egg_broken.connect(network_break_egg.bind(egg.UID))

func network_add_pet_from_egg(petId: String, eggUID: int) -> void :
	assert (multiplayer.is_server())
	var petUID: = randi()
	network_rpc(add_pet_from_egg.bind(petId, petUID, eggUID))
	add_pet_from_egg(petId, petUID, eggUID)

@rpc("reliable")
func add_pet_from_egg(petId: String, petUID: int, eggUID: int) -> void :
	if not Level.drops.has_drop(eggUID):
		return

	var pet: = spawn(petId, petUID)
	pet.hatchedThisRun = true

	var egg: = Level.drops.get_drop(eggUID) as Egg
	egg.breakEgg()

func network_break_egg(eggUID: int) -> void :
	network_rpc(break_egg.bind(eggUID), true)

@rpc("reliable")
func break_egg(eggUID: int) -> void :
	var egg: = Level.drops.get_drop(eggUID) as Egg
	egg.breakEgg()

func network_spawn(petId: String) -> void :
	var uid: = randi()
	network_rpc(spawn.bind(petId, uid), false)
	spawn(petId, uid)

@rpc("reliable")
func spawn(petId: String, uid: int) -> Pet:
	var pet = load("res://content/pets/" + petId + "/" + Data.startCaptialized(petId) + ".tscn").instantiate()
	pet.teamId = owner.teamId
	pet.UID = uid
	pets[uid] = pet

	pet.tree_exiting.connect(on_pet_tree_exiting.bind(pet), CONNECT_ONE_SHOT)
	pet.found_new_place.connect(on_pet_found_new_place.bind(pet))

	owner.add_child(pet)
	return pet

func on_pet_tree_exiting(pet: Pet) -> void :
	pets.erase(pet.UID)

func on_pet_found_new_place(positionName: String, pos: Vector2, flip_h: bool, animation_seed: int, pet: Pet) -> void :
	if not multiplayer.is_server():
		return
	network_rpc(setPlace.bind(pet.UID, positionName, pos, flip_h, animation_seed))

@rpc("reliable")
func setPlace(petUID: int, positionName: String, position: Vector2, flip_h: bool, animation_seed: int) -> void :
	if not pets.has(petUID):
		return

	var pet: = pets[petUID] as Pet
	pet.setPlace(positionName, position, flip_h, animation_seed)
