class_name GadgetSynchronizer
extends Synchronizer

var gadget

func _ready() -> void :
	super._ready()

	if multiplayer.is_server():
		if not owner.has_signal(&"state_changed"):
			push_error("GadgetSynchronizer at ", get_path(), " is parented to a gadget without a state_changed signal and cannot function.")
			return

	gadget = owner
	if multiplayer.is_server():
		gadget.state_changed.connect(on_gadget_state_changed)

func on_gadget_state_changed() -> void :
	full_sync_next_tick = true

func get_initial_data(_peer_id: int) -> PackedByteArray:
	if is_instance_valid(gadget):
		return gadget.get_gadget_state()

	return PackedByteArray()

func set_initial_data(buffer: PackedByteArray) -> void :
	if is_instance_valid(gadget):
		gadget.set_gadget_state(buffer)

func get_full_sync_data(peer_id: int) -> PackedByteArray:
	return get_initial_data(peer_id)

func set_full_sync_data(buffer: PackedByteArray) -> void :
	set_initial_data(buffer)
