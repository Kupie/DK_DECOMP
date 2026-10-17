class_name DroneCaveSynchronizer
extends Synchronizer

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_bool(owner.hasDrone)
	stream.encode_bool(owner.opening)
	stream.encode_var(owner.teamId)
	stream.encode_bool(owner.get_node("ResourceGrabber").spent)

	for drone in owner.get_node("DroneDispatcher").drones.values():
		stream.encode_u32(drone.UID)
		stream.encode_vector2(drone.position)
		stream.encode_u8(drone.state)
		stream.encode_float(drone.cooldown)
		stream.encode_var(drone.carriedResource)
		stream.encode_var(drone.dispatcherId)
		stream.encode_u16(drone.deliveredResources)
		stream.encode_float(drone.baseSpeed)
		stream.encode_u8(drone.packedDropContent.size())
		for content: Array in drone.packedDropContent:
			stream.encode_var(content[0])
			stream.encode_float(content[1])
			stream.encode_float(content[2])

		var hasTargettedDrop: = is_instance_valid(drone.targettedDrop)
		stream.encode_bool(hasTargettedDrop)
		if hasTargettedDrop:
			stream.encode_u32(drone.targettedDrop.UID)
		stream.encode_vector2(drone.targetSpot)
		stream.encode_vector2(drone.linear_velocity)

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	owner.hasDrone = stream.decode_bool()
	owner.opening = stream.decode_bool()
	owner.teamId = stream.decode_var()
	owner.get_node("ResourceGrabber").spent = stream.decode_bool()
	if not owner.hasDrone:
		owner.get_node("Drone").visible = false
		owner.get_node("Door").visible = false
	if owner.opening:
		owner.get_node("Door").play("opening")

	if owner.currentState == Cave.State.REVEALED:
		owner.find_child("AmbSound").startSound()

	while stream.is_not_finished():
		var uid: = stream.decode_u32()
		owner.spawnDrone(uid, owner.teamId)
		var drone = owner.get_node("DroneDispatcher").drones[uid]
		drone.position = stream.decode_vector2()
		drone.state = stream.decode_u8()
		drone.cooldown = stream.decode_float()
		drone.carriedResource = stream.decode_var()
		drone.dispatcherId = stream.decode_var()
		drone.deliveredResources = stream.decode_u16()
		drone.baseSpeed = stream.decode_float()
		var packedDropSize: = stream.decode_u8()
		for i in range(packedDropSize):
			var content: = []
			content.append(stream.decode_var())
			content.append(stream.decode_float())
			content.append(stream.decode_float())
			drone.packedDropContent.append(content)
		drone.setCarriedResource(drone.carriedResource)
		var hasTargettedDrop: = stream.decode_bool()
		if hasTargettedDrop:
			drone.targettedDrop = Level.drops.get_drop(stream.decode_u32())
		drone.targetSpot = stream.decode_vector2()
		drone.linear_velocity = stream.decode_vector2()

		match drone.state:
			TransportDrone.State.PICKUP:
				owner.get_node("DroneDispatcher").targetDrop(drone.UID, drone.targettedDrop.UID, drone.position)
			TransportDrone.State.RETRIEVE:
				owner.get_node("DroneDispatcher").assignDronePathHome(drone)
