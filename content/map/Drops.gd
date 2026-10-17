class_name Drops
extends Node2D

@export var synchronizer: DropSynchronizer

func _ready() -> void :
	synchronizer.drop_spawned.connect(on_drop_spawned, CONNECT_DEFERRED)
	synchronizer.bundle_spawned.connect(on_bundle_spawned)
	synchronizer.carrier_spawned.connect(on_carrier_spawned)

func on_drop_spawned(drop: Carryable) -> void :
	add_child(drop)

func on_bundle_spawned(bundle: Bundle) -> void :
	add_child(bundle)

func on_carrier_spawned(carrier: KunaiCarrier) -> void :
	Level.map.addDrop(carrier)

func _physics_process(delta: float) -> void :
	if GameWorld.paused:
		return


	for influence in get_tree().get_nodes_in_group("carry_influence"):
		var carryable = influence.getCarryable()

		if not is_instance_valid(influence.carrier):
			influence.dissolve()

		elif influence.carrier is Keeper2:

			var change: = delta
			if carryable is Drop:
				change *= 0.2
			influence.strength -= change

		elif influence.isBundled():
			influence.beingPulled = false
			influence.strength -= delta

func network_spawn(data: Dictionary) -> Carryable:
	return synchronizer.network_spawn(data)


func local_spawn(data: Dictionary) -> Carryable:
	return synchronizer.local_spawn(data)

func network_pickup(carryable: Carryable, playerId: String) -> void :
	if carryable.isLocal:
		synchronizer.pickup(carryable.UID, Utils.encode_player_id(playerId))
		return

	synchronizer.rpc_server(synchronizer.request_pickup.bind(
		carryable.UID, 
		Utils.encode_player_id(playerId)
	))

func network_drop(carryable: Carryable, playerId: String) -> void :
	if carryable.isLocal:
		synchronizer.drop(carryable.UID, Utils.encode_player_id(playerId))
		return

	synchronizer.network_rpc(synchronizer.drop.bind(
		carryable.UID, 
		Utils.encode_player_id(playerId)
	), true)

func network_drop_from_all(carryable) -> void :
	synchronizer.network_rpc(synchronizer.drop_from_all.bind(
		carryable.UID
	), true)

func network_shred(carryable: Carryable, teamId: String) -> void :
	synchronizer.network_rpc(synchronizer.shred.bind(
		carryable.UID, teamId
	), true)

func network_set_independent(carryable: Carryable, value: bool) -> void :
	synchronizer.network_rpc(synchronizer.set_independent.bind(carryable.UID, value), true)

func network_set_drop_target(carryable: Carryable, drop_target_node: Node) -> void :
	if carryable == drop_target_node:
		synchronizer.network_rpc(synchronizer.float_drop_target_as_self.bind(
			carryable.UID
		), true)
		return

	var drop_target_path: String = drop_target_node.get_path()
	synchronizer.network_rpc(synchronizer.set_drop_target.bind(
		carryable.UID, drop_target_path
	), true)

func network_set_other_peers_team_id(carryable: Carryable, new_team_id: String) -> void :
	synchronizer.network_rpc(synchronizer.set_drop_team.bind(
		carryable.UID, new_team_id
	), false)

func network_shrink(carryable: Carryable, teamId: String) -> void :
	synchronizer.network_rpc(synchronizer.shrink.bind(carryable.UID, teamId), true)

func network_free_drop(carryableUID: int) -> void :
	synchronizer.network_rpc(synchronizer.free_drop.bind(carryableUID), true)

func network_hide_drop(carryable: Carryable) -> void :
	synchronizer.network_rpc(synchronizer.hide_drop.bind(carryable.UID), true)

func network_show_drop(carryable: Carryable) -> void :

	synchronizer.network_rpc(synchronizer.show_drop.bind(carryable.UID), true)
	await get_tree().physics_frame
	carryable.show()

func network_goblin_carry(carryable: Carryable, goblin) -> void :
	if not carryable.has_meta("goblin_prev_layer"):
		carryable.set_meta("goblin_prev_layer", carryable.collision_layer)
		carryable.set_meta("goblin_prev_mask", carryable.collision_mask)
		carryable.set_meta("goblin_prev_freeze", carryable.freeze)
		carryable.set_meta("goblin_prev_freeze_mode", carryable.freeze_mode)
	synchronizer.network_rpc(synchronizer.goblin_carry.bind(carryable.UID, goblin.teamId, goblin.UID), true)

func network_goblin_release(carryable: Carryable, goblin) -> void :
	if carryable.has_meta("goblin_prev_layer"):
		carryable.collision_layer = carryable.get_meta("goblin_prev_layer")
		carryable.remove_meta("goblin_prev_layer")
	if carryable.has_meta("goblin_prev_mask"):
		carryable.collision_mask = carryable.get_meta("goblin_prev_mask")
		carryable.remove_meta("goblin_prev_mask")
	if carryable.has_meta("goblin_prev_freeze_mode"):
		carryable.freeze_mode = carryable.get_meta("goblin_prev_freeze_mode")
		carryable.remove_meta("goblin_prev_freeze_mode")
	if carryable.has_meta("goblin_prev_freeze"):
		carryable.freeze = carryable.get_meta("goblin_prev_freeze")
		carryable.remove_meta("goblin_prev_freeze")
	synchronizer.network_rpc(synchronizer.goblin_release.bind(carryable.UID, carryable.collision_layer, carryable.collision_mask, carryable.freeze_mode, carryable.freeze, goblin.teamId, goblin.UID), true)

func network_bundle(resources: Array[Carryable], bundle_position: Vector2, aim_direction: Vector2, speed: float, duration: float, leader: Node, playerId: String) -> void :
	var uids: = PackedInt64Array()
	for resource in resources:
		uids.append(resource.UID)
	var carryable_id: int = -1
	var keeper_id: int = -1
	if is_instance_valid(leader):
		if leader is Carryable:
			carryable_id = leader.UID
		elif leader is Keeper:
			keeper_id = int(leader.playerId.lstrip("player"))
	var bundle_id: = randi()
	if resources[0].isLocal:
		var bundle: = synchronizer.bundle(bundle_id, uids, bundle_position, aim_direction, speed, duration, carryable_id, keeper_id, playerId)
		bundle.set_multiplayer_authority(multiplayer.get_unique_id())
		return

	synchronizer.network_rpc(
		synchronizer.bundle.bind(bundle_id, uids, bundle_position, aim_direction, speed, duration, carryable_id, keeper_id, playerId), 
		true
	)

func network_kunai_carrier(carrier_group: Array[Carryable], aim_direction: Vector2, start_position: Vector2, player_id: String) -> void :
	var uids: = PackedInt64Array()
	for carryable in carrier_group:
		uids.append(carryable.UID)

	var carrier_id: = randi()
	synchronizer.network_rpc(
		synchronizer.kunai_carrier.bind(carrier_id, uids, aim_direction, start_position, player_id), 
		true
	)

func network_transfer_kunai_carrier(player_id: String, attached: bool, transfer_queue: Array, kunai_carrier_uid: int) -> void :
	var uids: = PackedInt64Array()
	for carryable in transfer_queue:
		uids.append(carryable.UID)

	synchronizer.network_rpc(
		synchronizer.transfer_kunai_carrier.bind(player_id, attached, uids, kunai_carrier_uid), 
		true
	)

func network_request_transfer_kunai_carrier(player_id: String, kunai_carrier_uid: int) -> void :
	synchronizer.rpc_server(
		synchronizer.request_transfer_kunai_carrier.bind(player_id, kunai_carrier_uid)
	)

func network_attach_to_tile(sending_kunai_carrier_uid: int, coord: Vector2, current_position: Vector2) -> void :
	synchronizer.network_rpc(
		synchronizer.attach_to_tile.bind(sending_kunai_carrier_uid, coord, current_position), 
		true
	)

func network_attach_to_node(sending_kunai_carrier_uid: int, node_path: NodePath, current_position: Vector2) -> void :
	synchronizer.network_rpc(
		synchronizer.attach_to_node.bind(sending_kunai_carrier_uid, node_path, current_position), 
		true
	)

func network_release_resources_from_kunai_carrier(uid: int) -> void :
	synchronizer.network_rpc(
		synchronizer.release_resources_from_kunai_carrier.bind(uid), 
		true
	)

func network_begin_carrier_lift_docking(uid: int, lift_center_x: float) -> void :
	synchronizer.network_rpc(
		synchronizer.begin_carrier_lift_docking.bind(uid, lift_center_x), 
		true
	)

func network_release_next_resource_from_dock(uid: int) -> void :
	synchronizer.network_rpc(
		synchronizer.release_next_resource_from_dock.bind(uid), 
		true
	)

func network_begin_carrier_shredder_docking(uid: int) -> void :
	synchronizer.network_rpc(
		synchronizer.begin_carrier_shredder_docking.bind(uid), 
		true
	)

func network_throw_drop(uid: int, force: Vector2) -> void :
	synchronizer.rpc_server(
		synchronizer.throw_drop.bind(uid, force)
	)




func get_all_bundles() -> Dictionary:
	return synchronizer.bundles.duplicate()

func bulk_bundle(_bundles: Dictionary) -> void :
	synchronizer.bundles = _bundles
	for bundle in synchronizer.bundles.values():
		add_child(bundle)

func get_all_drops() -> Dictionary:
	return synchronizer.drops.duplicate()

func get_drop(UID: int) -> Carryable:
	return synchronizer.drops[UID]

func has_drop(UID: int) -> bool:
	if UID == -1:
		return false
	return synchronizer.drops.has(UID)


func load_drop(drop):
	add_child.call_deferred(drop)
	if drop is MineralTree:

		return
	connect_tree_signals(drop)

func connect_tree_signals(drop):
	if not drop.tree_entered.is_connected(synchronizer.on_drop_tree_entering):
		drop.tree_entered.connect(synchronizer.on_drop_tree_entering.bind(drop))
		drop.tree_exiting.connect(synchronizer.on_drop_tree_exiting.bind(drop))

func bulk_add(_drops: Dictionary) -> void :
	for drop in _drops.values():
		load_drop(drop)

func track_drop(drop):
	synchronizer.track_drop(drop)

func track_bundle(bundle):
	synchronizer.track_bundle(bundle)

func track_carrier(carrier):
	synchronizer.track_carrier(carrier)

func network_free_bundle(bundleUID: int) -> void :
	synchronizer.network_rpc(synchronizer.free_bundle.bind(bundleUID), true)

func network_free_carrier(carrier_uid: int) -> void :
	synchronizer.network_rpc(synchronizer.free_carrier.bind(carrier_uid), true)
