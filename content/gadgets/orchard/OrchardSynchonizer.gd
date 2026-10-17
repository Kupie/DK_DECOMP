class_name OrchardSynchronizer extends Synchronizer

func get_initial_data(peer_id: int) -> PackedByteArray:
	return owner.get_initial_data(peer_id)

func set_initial_data(data: PackedByteArray) -> void :
	owner.set_initial_data(data)
