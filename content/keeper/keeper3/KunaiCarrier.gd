extends RigidBody2D
class_name KunaiCarrier

var playerId: String
var teamId: String
var UID: int
var carriedCarryables: Array = []
var chainManager: ResourceChainManager
var attached: = false
var anchorTile: Node
var chainHanging: bool = false
var ownerKeeperId: String = ""
var _ownerKeeper: Keeper
var ownerKeeper: Keeper:
	get:
		return _ownerKeeper
	set(value):
		_ownerKeeper = value
		if is_instance_valid(value):
			ownerKeeperId = value.playerId
		else:
			ownerKeeperId = ""
var launch_direction: Vector2 = Vector2.ZERO
var gravity_multiplier: float = 0.5
var lastVelocity: Vector2 = Vector2.ZERO
var lastPos: Vector2
var lastPosInitialized: = false
var lastImpactNormal: Vector2 = Vector2.ZERO
var _savedCarryableUids: Array = []
var _awaiting_carryable_restore: = false
var _savedAnchorCoord
var _savedAnchorNodePath: String = ""
var _savedLinearVelocity: Vector2 = Vector2.ZERO
var _savedAngularVelocity: float = 0.0
var _savedAttachedState: bool = false
var _savedAnchorType: String = ""
var _savedAnchorUid: int = -1
var _anchor_offset: Vector2 = Vector2.ZERO
var _sweep_exclusions: Array = []
var _collided: bool
var type: = "kunai_carrier"

const KUNAI_ATTACHABLE_GROUP: = &"kunai_attachable"

@onready var kunaiSprite: Node2D = $KunaiSprite
@onready var chainAnchor: Node2D = get_node_or_null("ChainAnchor")
@onready var _pickup_area: Area2D = $PickupArea
@onready var focus_sprite: Sprite2D = $FocusSprite

var carryableType: = "resource"
var inFocusArea: Array = []

var _initial_collision_layer: int
var _initial_collision_mask: int
var _collision_settings_initialized: = false

var _defaultZIndex: = 0
var _defaultSpriteZIndex: = 0

var _unfreeze_countdown: = 0
var _restore_gravity_frames: = 0
var _paused_linear_velocity: Vector2 = Vector2.ZERO
var _paused_angular_velocity: float = 0.0
var _paused_was_frozen: bool = false
var _paused_global_position: Vector2 = Vector2.ZERO
var _paused_rotation: float = 0.0
var _paused_position_valid: bool = false

enum LiftDockState{INACTIVE, DOCKING, RELEASING, COMPRESSING, FINISHED}
var _lift_dock_state: int = LiftDockState.INACTIVE
var _lift_dock_target_x: float = 0.0
var _paused_lift_dock_state: int = LiftDockState.INACTIVE
var _lift_check_last_x: float = 0.0
var _lift_check_last_x_initialized: bool = false
var _has_been_outside_lift_area: bool = false
var _cached_main_lift: Node2D

enum ShredderDockState{INACTIVE, CONSUMING, FINISHED}
var _shredder_dock_state: int = ShredderDockState.INACTIVE
var _shredder_dock_cooldown: float = 0.0
var _shredder_ref: Node = null

func _ready() -> void :
	assert (_pickup_area.get_parent() == self, "Dome._on_keeper_projectiles_detector_area_entered() needs update")
	assert (_pickup_area.get_collision_layer_value(1), "Dome.tscn.KeeperProjectilesDetector needs update")
	@warning_ignore("assert_always_true")
	assert (SHREDDER_PROXIMITY_RADIUS < 40.0, """Shredder proximity area must be well inside dome,
			otherwise we have problems with brinding gadgets/supplements into dome
			(related to Keeper.getIsInsideDome())""")
	_ensure_initial_collision_settings()
	contact_monitor = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	max_contacts_reported = 1
	_defaultZIndex = Keeper3SecondarySettings.CARRIER_STICK_Z_INDEX
	_defaultSpriteZIndex = Keeper3SecondarySettings.CARRIER_STICK_Z_INDEX
	_restore_default_depth()
	Style.init(self)

	chainManager = ResourceChainManager.new()
	chainManager.carrier = self
	chainManager.carriedCarryables = carriedCarryables
	chainManager.set_name("ResourceChainManager")
	add_child(chainManager)
	add_to_group("pauseL")

func _process(delta: float) -> void :
	if focus_sprite.visible:
		focus_sprite.global_rotation = 0.0
	if _lift_dock_state != LiftDockState.INACTIVE:
		return
	if _shredder_dock_state != ShredderDockState.INACTIVE:
		return
	if carriedCarryables.is_empty() and not _awaiting_carryable_restore:
		if multiplayer.is_server():
			Level.drops.network_free_carrier(UID)

func _physics_process(delta: float) -> void :
	if not Level.initialized:
		return

	if GameWorld.paused:
		_apply_pause_lock()
		return

	if _lift_dock_state != LiftDockState.INACTIVE:
		_process_lift_dock(delta)
		_updateCarryChains(delta)
		return

	if _shredder_dock_state != ShredderDockState.INACTIVE:
		_process_shredder_dock(delta)
		_updateCarryChains(delta)
		return

	if _unfreeze_countdown > 0:
		_unfreeze_countdown -= 1
		chainManager.lock_carried_bodies_for_pause()
		if _unfreeze_countdown == 0:
			_do_unfreeze_resources()


	if Data.of(playerId + ".keeper3.rocketcarrier") and not _collided:
		linear_velocity = launch_direction * Data.of(playerId + ".keeper3.carrierspeed")

	_update_rotation_from_velocity()

	if attached and is_instance_valid(anchorTile) and anchorTile is RigidBody2D:
		global_position = anchorTile.global_position + _anchor_offset

	_updateCarryChains(delta)

	if _restore_gravity_frames > 0:
		_restore_gravity_frames -= 1
		if _restore_gravity_frames == 0:
			for c in carriedCarryables:
				if c is RigidBody2D:
					c.gravity_scale = Keeper3SecondarySettings.CARRY_CARRIED_GRAVITY_SCALE

	if not attached:
		_perform_high_precision_collision_check()
	if not carriedCarryables.is_empty() and global_position.y < CONST.DOME_CELLAR_ENTRANCE_Y:
		_check_shredder_proximity()
		if _shredder_dock_state == ShredderDockState.INACTIVE and is_instance_valid(_shredder_ref):
			linear_velocity = (_shredder_ref.dropTarget() - global_position).normalized() * SHREDDER_APPROACH_SPEED
	_check_lift_area_overlap()

	if attached:
		return

func _apply_pause_lock() -> void :
	if not _paused_position_valid:
		_paused_global_position = global_position
		_paused_rotation = rotation
		_paused_position_valid = true
	if not attached:
		global_position = _paused_global_position
		rotation = _paused_rotation
		set_axis_velocity(Vector2.ZERO)
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
		PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
		sleeping = true
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true
	chainManager.lock_carried_bodies_for_pause()
	lastPos = global_position
	lastPosInitialized = true

func pauseChanged() -> void :
	if GameWorld.paused:
		_paused_linear_velocity = linear_velocity
		_paused_angular_velocity = angular_velocity
		_paused_was_frozen = freeze
		_paused_global_position = global_position
		_paused_rotation = rotation
		_paused_position_valid = true
		_paused_lift_dock_state = _lift_dock_state
		_apply_pause_lock()

		_unfreeze_countdown = 0
		_restore_gravity_frames = 0
		for c in carriedCarryables:
			if c is RigidBody2D:
				c.freeze = true
	else:
		_paused_position_valid = false
		_lift_dock_state = _paused_lift_dock_state
		if not attached:
			freeze = _paused_was_frozen
			sleeping = false
			linear_velocity = _paused_linear_velocity
			angular_velocity = _paused_angular_velocity
			PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, _paused_linear_velocity)
			PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, _paused_angular_velocity)

		if attached:
			for c in carriedCarryables:
				if c is RigidBody2D:
					c.freeze = true
			chainManager.skip_forces_for_frames(10)
			_unfreeze_countdown = 10
		else:
			chainManager.skip_forces_for_frames(0)
			_unfreeze_countdown = 0
			_do_unfreeze_resources()

func _do_unfreeze_resources() -> void :
	chainManager.release_pause_lock()
	if not multiplayer.is_server():
		return
	for c in carriedCarryables:
		if c is RigidBody2D:
			c.gravity_scale = 0.0
			if c.is_multiplayer_authority():
				c.freeze = false
	_restore_gravity_frames = 2

func _update_rotation_from_velocity() -> void :
	var velocity: Vector2 = linear_velocity
	var velocity_len_sq: = velocity.length_squared()
	if velocity_len_sq > Keeper3SecondarySettings.CARRIER_ROTATION_VELOCITY_EPS:
		lastVelocity = velocity
	var last_velocity_len_sq: = lastVelocity.length_squared()
	if last_velocity_len_sq > Keeper3SecondarySettings.CARRIER_ROTATION_VELOCITY_EPS:
		rotation = lastVelocity.angle() + PI * 0.5

func _apply_surface_stick_rotation() -> void :
	var forward: Vector2 = lastVelocity
	var forward_len_sq: = forward.length_squared()
	var launch_len_sq: = launch_direction.length_squared()
	if forward_len_sq <= Keeper3SecondarySettings.CARRIER_ROTATION_VELOCITY_EPS and launch_len_sq > 0.0:
		forward = launch_direction
	if forward.length_squared() > Keeper3SecondarySettings.CARRIER_ROTATION_VELOCITY_EPS:
		rotation = forward.normalized().angle() + PI * 0.5
	_apply_surface_stick_depth()

func _apply_surface_stick_depth() -> void :
	z_index = Keeper3SecondarySettings.CARRIER_STICK_Z_INDEX
	kunaiSprite.z_index = Keeper3SecondarySettings.CARRIER_STICK_Z_INDEX

func _spawn_tile_burst_vfx(normal: Vector2, spawn_dirt: bool = true) -> void :
	var parent: = get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var effect: Node2D = Keeper3SecondarySettings.CARRIER_TILE_BURST_VFX.instantiate()
	var offset_normal: Vector2 = normal.normalized() if normal.length_squared() > 0.0 else Vector2.ZERO
	parent.add_child(effect)
	effect.global_position = global_position + offset_normal * 2.0
	if effect.has_method("setup"):
		effect.setup(normal)
	_spawn_impact_particles(global_position, normal, parent, spawn_dirt)

func _spawn_impact_particles(hit_point: Vector2, normal: Vector2, parent: Node, spawn_dirt: bool = true) -> void :
	var impact_rotation: float = normal.angle() if normal.length_squared() > 0.0 else 0.0

	var spark_amount: = 4
	if Options.reducedParticles:
		spark_amount = 2
	for _i in range(spark_amount + randi() % 2):
		var s = Data.KEEPER_SPARK.instantiate()
		s.global_position = hit_point
		parent.add_child(s)
		s.apply_central_impulse(Vector2.RIGHT.rotated(impact_rotation + randf_range(-0.5, 0.5)) * randf_range(20, 100))

	if not spawn_dirt:
		return

	var inward_normal: = - normal if normal.length_squared() > 0.0 else Vector2.ZERO
	var sample_point: = hit_point + inward_normal * Keeper3SecondarySettings.CARRIER_COLLISION_RADIUS
	var tile_coord: Vector2 = Vector2(Level.map.getTileCoord(sample_point))
	var tile: Node = Level.map.getTile(tile_coord)

	var dirt_color: Color = Level.map.getBiomeColorByCoord(tile_coord)
	var tile_type = tile.type if tile != null and "type" in tile else ""

	var dirt_amount: = 2
	if Options.reducedParticles:
		dirt_amount = 1
	for _i in range(dirt_amount + randi() % 2):
		var t = Data.TILE_DIRT_PARTICLE.instantiate()
		t.modulate = dirt_color
		t.type = tile_type
		t.global_position = hit_point
		parent.add_child(t)
		t.apply_central_impulse(Vector2.RIGHT.rotated(impact_rotation + randf_range(-0.7, 0.7)) * randf_range(40, 100))

func _play_carrier_impact_sound() -> void :
	var parent_node: = get_parent()
	if parent_node == null or not is_instance_valid(parent_node):
		parent_node = self
	var sound = %KunaiCarrierImpactSound
	var s = sound.duplicate()
	s.simulatedPosition = global_position
	parent_node.add_child(s)
	s.startSound()

func _restore_default_depth() -> void :
	z_index = _defaultZIndex
	kunaiSprite.z_index = _defaultSpriteZIndex

func _ensure_initial_collision_settings() -> void :
	if not _collision_settings_initialized:
		_initial_collision_layer = collision_layer
		_initial_collision_mask = collision_mask
		_collision_settings_initialized = true

func _connect_anchor_tile(node: Node) -> void :
	var signal_callable: = Callable(self, "_on_anchorTile_destroyed")
	node.connect("tree_exited", signal_callable)
	if node.is_in_group(KUNAI_ATTACHABLE_GROUP):
		node.connect("deactivated", signal_callable)

func _disconnect_anchor_tile() -> void :
	var signal_callable: = Callable(self, "_on_anchorTile_destroyed")
	anchorTile.disconnect("tree_exited", signal_callable)
	if anchorTile.is_in_group(KUNAI_ATTACHABLE_GROUP):
		anchorTile.disconnect("deactivated", signal_callable)

func _apply_attachment_state(node, spawn_vfx: bool) -> void :
	if attached:
		_disconnect_anchor_tile()
	$ThrowResources.stop(true)
	attached = true
	chainHanging = true
	linear_velocity = Vector2.ZERO
	_collided = true
	angular_velocity = 0.0
	freeze = true
	sleeping = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	gravity_scale = 0.0
	collision_layer = 0
	collision_mask = 0
	anchorTile = node
	if node is Node2D:
		_anchor_offset = global_position - node.global_position
	lastPosInitialized = false
	_connect_anchor_tile(node)
	_apply_surface_stick_rotation()
	if spawn_vfx and lastImpactNormal.length_squared() > 0.0:
		var is_resource: bool = node is KunaiCarrier or node.has_meta("kunai_carrier") or node is Carryable
		_spawn_tile_burst_vfx(lastImpactNormal, not is_resource)
	if spawn_vfx:
		_play_carrier_impact_sound()
	lastImpactNormal = Vector2.ZERO

func _apply_free_state(linear_vel: Vector2, angular_vel: float) -> void :
	if attached:
		_disconnect_anchor_tile()
	anchorTile = null
	_anchor_offset = Vector2.ZERO
	attached = false
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = false
	sleeping = false
	gravity_scale = gravity_multiplier
	_ensure_initial_collision_settings()
	collision_layer = _initial_collision_layer
	collision_mask = _initial_collision_mask
	linear_velocity = linear_vel
	angular_velocity = angular_vel
	lastPosInitialized = false
	_restore_default_depth()

func _calculate_detach_velocity() -> Vector2:
	var side: float = 1.0 if UID % 2 == 0 else -1.0
	return Vector2(side * Keeper3SecondarySettings.CARRY_CARRIER_DETACH_FALL_HORIZONTAL, Keeper3SecondarySettings.CARRY_CARRIER_DETACH_FALL_VELOCITY)

func _build_sweep_exclusions() -> Array:
	_sweep_exclusions.clear()
	_sweep_exclusions.append(get_rid())
	for body in carriedCarryables:
		if body == null:
			continue
		if not is_instance_valid(body):
			continue
		if body is CollisionObject2D:
			_sweep_exclusions.append(body.get_rid())
	return _sweep_exclusions

func _should_ignore_collision(collider) -> bool:
	if collider == null:
		return false
	if collider is CollisionObject2D:
		if collider.name == "TrapDoor":
			return true
		if collider.get_collision_layer_value(CONST.LAYER_DROP_DOME_BORDER) or collider.get_collision_layer_value(CONST.LAYER_DOME_EXTERNAL):
			if global_position.y > collider.global_position.y:
				return true
			if not carriedCarryables.is_empty() and global_position.y < CONST.DOME_CELLAR_ENTRANCE_Y:
				return true
	if collider is Node:
		if collider.is_in_group("carryable"):
			return true
	return false

func _extend_sweep_exclusions(exclusions: Array, rid: RID, collider) -> void :
	if rid.is_valid() and not exclusions.has(rid):
		exclusions.append(rid)
	if collider is CollisionObject2D:
		var collider_rid: RID = collider.get_rid()
		if collider_rid.is_valid() and not exclusions.has(collider_rid):
			exclusions.append(collider_rid)

func _perform_high_precision_collision_check() -> void :
	if not lastPosInitialized:
		lastPos = global_position
		lastPosInitialized = true
		return

	var from: Vector2 = lastPos
	var to: Vector2 = global_position
	lastPos = global_position
	if from.distance_squared_to(to) <= 0.0025:
		return

	var exclusions: = _build_sweep_exclusions()
	while true:
		var res: = HighPrecisionCollision.sweep_and_snap(self, Keeper3SecondarySettings.CARRIER_COLLISION_RADIUS, from, to, exclusions)
		if not res.get("collided", false):
			lastImpactNormal = Vector2.ZERO
			return

		var collider = res.get("collider", null)
		if _should_ignore_collision(collider):
			var res_rid: RID = res.get("rid", RID())
			_extend_sweep_exclusions(exclusions, res_rid, collider)
			continue

		var impact_normal_value = res.get("normal", null)
		lastImpactNormal = impact_normal_value if impact_normal_value is Vector2 else Vector2.ZERO
		if lastImpactNormal.length_squared() > 0.0:
			lastImpactNormal = lastImpactNormal.normalized()

		if collider is Node2D and lastImpactNormal.length_squared() > 0.0:
			var hit_point: Vector2 = res.get("point", Vector2.ZERO)
			var tile_center: Vector2 = collider.global_position
			var face_axis: = Vector2(lastImpactNormal.y, lastImpactNormal.x)
			var edge_dist: = absf((hit_point - tile_center).dot(face_axis))
			if edge_dist > GameWorld.HALF_TILE_DIAGONAL - Keeper3SecondarySettings.CARRIER_CORNER_MARGIN:
				var res_rid: RID = res.get("rid", RID())
				_extend_sweep_exclusions(exclusions, res_rid, collider)
				continue

		if res.has("snap_position"):
			global_position = res.snap_position
			lastPos = global_position

		if collider is Node:
			if collider.has_meta("kunai_carrier") and collider.get_meta("kunai_carrier") == self:
				return
			if collider is Keeper:
				return
			_on_body_entered(collider)
		return

func _updateCarryChains(delta: float) -> void :
	chainManager.update_chains(delta)

func getChainSpawnNode() -> Node2D:
	return chainAnchor if is_instance_valid(chainAnchor) else self

func _carrierSetupCarryable(body) -> void :
	chainManager.setup_carryable(body)

func launch(aim_direction: Vector2):
	launch_direction = aim_direction.normalized()
	lastPosInitialized = false
	lastPos = global_position
	lastImpactNormal = Vector2.ZERO
	chainHanging = false

	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = false
	sleeping = false
	gravity_scale = Data.of(playerId + ".keeper3.carriergravity")
	collision_layer = _initial_collision_layer
	collision_mask = _initial_collision_mask
	if launch_direction.length_squared() > 0.0:
		lastVelocity = launch_direction
		rotation = launch_direction.normalized().angle() + PI * 0.5
	_restore_default_depth()
	var speed = Data.of(playerId + ".keeper3.carrierspeed")
	apply_central_impulse(launch_direction * speed)
	$ThrowResources.startSound()

	await get_tree().create_timer(1.0).timeout
	$FocusArea.monitoring = true
	$PickupArea.collision_mask |= (1 << 14)

func dropCarry(drop):
	_dropCarryInternal(drop)

func attachCarryable(body: Node2D) -> void :
	if body == null or not is_instance_valid(body):
		return
	if carriedCarryables.has(body):
		return

	carriedCarryables.append(body)
	body.set_meta("teleporter_droppable", true)
	body.setCarriedBy(self)
	body.dissolveCarryInfluence()
	var po = CarryablePhysicsOverride.new(self)
	po.angular_damp = 2
	po.gravity_scale = Keeper3SecondarySettings.CARRY_CARRIED_GRAVITY_SCALE
	body.addPhysicsOverride(po)
	_carrierSetupCarryable(body)

func _calculate_throw_velocity() -> Vector2:
	var throw_velocity: Vector2 = linear_velocity
	if throw_velocity.length_squared() <= 0.0 and lastVelocity.length_squared() > 0.0:
		throw_velocity = lastVelocity
	if throw_velocity.length_squared() > 0.0:
		throw_velocity = throw_velocity.normalized() * min(throw_velocity.length(), 200.0)
	return throw_velocity

func _dropCarryInternal(body) -> void :
	if not carriedCarryables.has(body):
		return
	_carrierDetachBody(body)
	carriedCarryables.erase(body)

func dropAllCarryables(throw_velocity: Vector2 = Vector2.ZERO) -> void :
	for body in carriedCarryables.duplicate():
		_carrierDetachBody(body, throw_velocity)
	carriedCarryables.clear()

func _on_body_entered(body: Node) -> void :
	if not multiplayer.is_server():
		return

	if body.is_in_group(KUNAI_ATTACHABLE_GROUP):
		Level.drops.network_attach_to_node(UID, body.get_path(), global_position)
		return

	var collider: = body as CollisionObject2D
	if collider and (collider.get_collision_layer_value(CONST.LAYER_DROP_DOME_BORDER) or collider.get_collision_layer_value(CONST.LAYER_DOME_EXTERNAL)):
		return

	Level.drops.network_attach_to_tile(UID, body.coord, global_position)

func releaseResourcesAndDestroy() -> void :
	release_resources_inside_dome()
	destroyKunaiCarrier()

func attachToSurface(node) -> void :
	_apply_attachment_state(node, true)

func destroyKunaiCarrier(preserve_velocity: bool = false, velocity_dampen: float = 1.0) -> void :
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	$ThrowResources.stop(true)

	if attached:
		_disconnect_anchor_tile()

	var throw_vel: = Vector2.ZERO
	if preserve_velocity:
		throw_vel = _calculate_throw_velocity() * velocity_dampen

	queue_free()

	dropAllCarryables(throw_vel)
	chainHanging = false
	for body in chainManager.carryChains.keys().duplicate():
		_carrierRemoveCarryChain(body)

func _on_pickup_area_body_entered(body):
	if not body is Keeper3:
		return
	if not attached:
		return
	if not body.is_multiplayer_authority():
		return
	if not body.input_settings.auto_kunai_carrier_pickup:
		return
	if not body.enterCarrierPickupArea(self):
		return

	Level.drops.network_request_transfer_kunai_carrier(body.playerId, UID)

func _on_pickup_area_body_exited(body):
	if not body is Keeper3:
		return

	body.exitCarrierPickupArea(self)

func _on_focus_area_body_entered(body):
	if not body is Keeper3:
		return

	body.carryables.append(self)

func _on_focus_area_body_exited(body):
	if not body is Keeper3:
		return

	body.carryables.erase(self)
	unfocusCarry(body)
	if body.focussedCarryable == self:
		body.focussedCarryable = null

func canFocusCarry(carrierTeamId: = "") -> bool:
	return not carriedCarryables.is_empty()

func isCarried() -> bool:
	return false

func focusCarry(p) -> void :
	inFocusArea.append(p)
	updateFocus()

func unfocusCarry(p) -> void :
	inFocusArea.erase(p)
	updateFocus()

func updateFocus() -> void :
	focus_sprite.visible = canFocusCarry() and not inFocusArea.is_empty()

func transferToKeeper(keeper: Keeper) -> void :
	var carry_limit: = int(Data.of(keeper.playerId + ".keeper3.carrylimit"))
	var available_space: = carry_limit - keeper.carriedCarryables.size()
	if available_space <= 0:
		return

	var transfer_queue: Array = []
	for c in carriedCarryables.duplicate():
		if available_space <= 0:
			break
		transfer_queue.append(c)
		available_space -= 1

	transfer_queue.reverse()

	if transfer_queue.is_empty():
		return

	call_deferred("_deferred_transfer_to_keeper", keeper, transfer_queue)

func _deferred_transfer_to_keeper(keeper: Keeper, transfer_queue: Array) -> void :
	Level.drops.network_transfer_kunai_carrier(keeper.playerId, attached, transfer_queue, UID)

func _on_anchorTile_destroyed():
	if not is_inside_tree():
		return
	chainHanging = false
	_apply_free_state(_calculate_detach_velocity(), 0.0)

func _deserialize_vector(value, default_value: Vector2 = Vector2.ZERO) -> Vector2:
	if value is String and value != "":
		var result = BackwardCompatibilityUtils.str_to_var(value)
		if result is Vector2:
			return result
	return default_value

func _restore_anchor_from_data() -> Node:
	match _savedAnchorType:
		"tile":
			if _savedAnchorCoord is Vector2 and Level and Level.map:
				return Level.map.getTile(_savedAnchorCoord)
		"node":
			return get_node(NodePath(_savedAnchorNodePath))
		_:
			if _savedAnchorCoord is Vector2 and Level and Level.map:
				var tile = Level.map.getTile(_savedAnchorCoord)
				if tile != null:
					return tile
			if _savedAnchorNodePath != "":
				return get_node_or_null(NodePath(_savedAnchorNodePath))
	return null

func _apply_loaded_state() -> void :
	_ensure_initial_collision_settings()
	$FocusArea.monitoring = true
	$PickupArea.collision_mask |= (1 << 14)
	var anchor_node: = _restore_anchor_from_data()
	if _savedAttachedState:
		if anchor_node != null:
			_apply_attachment_state(anchor_node, false)
		else:
			push_warning("KunaiCarrier could not restore anchor; switching to free state.")
			_apply_free_state(_savedLinearVelocity, _savedAngularVelocity)
	else:
		_apply_free_state(_savedLinearVelocity, _savedAngularVelocity)

func _queue_carryable_restore() -> void :
	if _savedCarryableUids.is_empty():
		return
	_awaiting_carryable_restore = true
	call_deferred("_reattach_carryables_from_save")

func _reattach_carryables_from_save() -> void :
	await GameWorld.savegame_loaded
	var carryable_map: = {}
	for node in get_tree().get_nodes_in_group("carryable"):
		if node is Carryable:
			carryable_map[(node as Carryable).UID] = node
	for uid in _savedCarryableUids.duplicate():
		var carryable = carryable_map.get(uid, null)
		if carryable == null:
			continue
		attachCarryable(carryable)
	_savedCarryableUids.clear()
	_awaiting_carryable_restore = false

func serialize() -> Dictionary:
	var data: = {}
	data["meta.priority"] = 150
	data["meta.kind"] = "generic"
	data["UID"] = UID
	data["playerId"] = playerId
	data["teamId"] = teamId
	data["ownerKeeperId"] = ownerKeeperId
	data["attached"] = attached
	data["chainHanging"] = chainHanging
	data["gravity_multiplier"] = gravity_multiplier
	data["launch_direction"] = var_to_str(launch_direction)
	data["last_velocity"] = var_to_str(lastVelocity)
	data["linear_velocity"] = var_to_str(linear_velocity)
	data["angular_velocity"] = angular_velocity
	var carryable_uids: Array = []
	for body in carriedCarryables:
		if body == null or not is_instance_valid(body):
			continue
		if not (body is Carryable):
			continue
		carryable_uids.append((body as Carryable).UID)
	data["carryable_uids"] = carryable_uids
	var anchor_coord: = ""
	if is_instance_valid(anchorTile) and anchorTile is Tile:
		anchor_coord = var_to_str((anchorTile as Tile).coord)
	data["anchor_tile_coord"] = anchor_coord
	var anchor_path: = ""
	if is_instance_valid(anchorTile):
		anchor_path = str(anchorTile.get_path())
	data["anchor_node_path"] = anchor_path
	var anchor_type: = ""
	var anchor_uid: = -1
	if is_instance_valid(anchorTile):
		if anchorTile is Tile:
			anchor_type = "tile"
		elif anchorTile is KunaiCarrier:
			anchor_type = "carrier"
			anchor_uid = (anchorTile as KunaiCarrier).UID
		elif anchorTile is Carryable:
			anchor_type = "carryable"
			anchor_uid = (anchorTile as Carryable).UID
		else:
			anchor_type = "node"
	data["anchor_type"] = anchor_type
	data["anchor_uid"] = anchor_uid
	data["lift_dock_state"] = _lift_dock_state
	data["lift_dock_target_x"] = _lift_dock_target_x
	return data

func deserialize(data: Dictionary) -> void :
	UID = data.get("UID", UID)
	playerId = data.get("playerId", playerId)
	teamId = data.get("teamId", teamId)
	gravity_multiplier = data.get("gravity_multiplier", gravity_multiplier)
	chainHanging = data.get("chainHanging", chainHanging)
	var owner_id: String = data.get("ownerKeeperId", "")
	ownerKeeperId = owner_id
	if owner_id != "":
		var keeper: = Keepers.getKeeper(owner_id)
		if keeper:
			ownerKeeper = keeper
	launch_direction = _deserialize_vector(data.get("launch_direction", ""), launch_direction)
	lastVelocity = _deserialize_vector(data.get("last_velocity", ""), lastVelocity)
	_savedLinearVelocity = _deserialize_vector(data.get("linear_velocity", ""), Vector2.ZERO)
	_savedAngularVelocity = float(data.get("angular_velocity", 0.0))
	_savedAttachedState = data.get("attached", false)
	_savedAnchorNodePath = data.get("anchor_node_path", "")
	_savedAnchorCoord = null
	var anchor_coord_str: String = data.get("anchor_tile_coord", "")
	if anchor_coord_str != "":
		var coord_value = BackwardCompatibilityUtils.str_to_var(anchor_coord_str)
		if coord_value is Vector2:
			_savedAnchorCoord = coord_value
	_savedAnchorType = data.get("anchor_type", "")
	_savedAnchorUid = int(data.get("anchor_uid", -1))
	_savedCarryableUids.clear()
	for uid in data.get("carryable_uids", []):
		_savedCarryableUids.append(int(uid))
	_lift_dock_state = data.get("lift_dock_state", LiftDockState.INACTIVE)
	_lift_dock_target_x = data.get("lift_dock_target_x", 0.0)
	_apply_loaded_state()
	Level.drops.track_carrier(self)
	_queue_carryable_restore()

func release_resources_inside_dome():
	var throw_velocity: Vector2 = _calculate_throw_velocity()

	for c in carriedCarryables.duplicate():
		if not c.get_collision_mask_value(CONST.LAYER_DOME_EXTERNAL):
			_carrierDetachBody(c, throw_velocity)

func canDroneDetachCarryable(body) -> bool:
	if not attached:
		return false
	if body == null or not is_instance_valid(body):
		return false
	if carriedCarryables.is_empty():
		return false
	return carriedCarryables.back() == body

func detachCarryableForDrone(body) -> bool:
	if not canDroneDetachCarryable(body):
		return false
	_carrierDetachBody(body)
	return true

func detachChainBodySync(body) -> void :
	chainManager.detach_body(body)

func _carrierDetachBody(body, throw_velocity: Vector2 = Vector2.ZERO) -> void :
	if is_instance_valid(body):
		body.set_meta("teleporter_droppable", null)
		body.set_meta("kunai_carrier", null)
	if is_queued_for_deletion():
		chainManager.detach_body(body)
	else:
		chainManager.detach_body.call_deferred(body)

	if multiplayer.is_server() and body is RigidBody2D:
		var rigid_body: = body as RigidBody2D
		if rigid_body.is_multiplayer_authority():
			rigid_body.set_deferred("freeze", false)
			rigid_body.set_deferred("sleeping", false)
			rigid_body.set_deferred("can_sleep", false)
			rigid_body.set_deferred("lock_rotation", false)
		if throw_velocity.length_squared() > 0.0:
			rigid_body.call_deferred("apply_central_impulse", throw_velocity)
		else:
			rigid_body.set_deferred("linear_velocity", Vector2.ZERO)
			rigid_body.set_deferred("angular_velocity", 0.0)
			PhysicsServer2D.call_deferred("body_set_state", rigid_body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
			PhysicsServer2D.call_deferred("body_set_state", rigid_body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
		rigid_body.call_deferred("apply_central_impulse", Vector2.UP)
		rigid_body.call_deferred("apply_torque_impulse", 5)
		if rigid_body.is_inside_tree():
			rigid_body.get_tree().create_timer(0.5).timeout.connect( func():
				if is_instance_valid(rigid_body):
					rigid_body.can_sleep = true
			)

func _carrierRemoveCarryChain(body) -> void :
	chainManager.remove_carry_chain(body)

func _check_lift_area_overlap() -> void :
	if not multiplayer.is_server():
		return

	if carriedCarryables.is_empty():
		_lift_check_last_x_initialized = false
		_has_been_outside_lift_area = false
		return
	if _lift_dock_state != LiftDockState.INACTIVE:
		return

	var lift: Node2D = _get_main_lift()
	if lift == null:
		_lift_check_last_x_initialized = false
		_has_been_outside_lift_area = false
		return

	var lift_center_x: float = lift.global_position.x
	var current_x: float = global_position.x

	if attached:
		if _any_carryable_in_lift_area(lift):
			Level.drops.network_begin_carrier_lift_docking(UID, lift_center_x)
		return

	if not _is_position_in_main_lift(global_position, lift):
		_has_been_outside_lift_area = true

	if not _lift_check_last_x_initialized:
		_lift_check_last_x = current_x
		_lift_check_last_x_initialized = true
		return

	var crossed_center: bool = (_lift_check_last_x - lift_center_x) * (current_x - lift_center_x) <= 0
	var within_threshold: bool = abs(current_x - lift_center_x) <= Keeper3SecondarySettings.LIFT_DOCK_X_THRESHOLD

	_lift_check_last_x = current_x

	if not _has_been_outside_lift_area:
		return

	if global_position.y < CONST.DOME_CELLAR_ENTRANCE_Y:
		return

	if crossed_center and _any_carryable_in_lift_area(lift):
		Level.drops.network_begin_carrier_lift_docking(UID, lift_center_x)
		return

	if within_threshold and _any_carryable_in_lift_area(lift):
		Level.drops.network_begin_carrier_lift_docking(UID, lift_center_x)

func _is_main_lift_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var lift_script_resource = node.get_script()
	if lift_script_resource == null:
		return false
	var script_path: String = lift_script_resource.resource_path
	return script_path.ends_with("Lift.gd")

func _get_main_lift() -> Node2D:
	if is_instance_valid(_cached_main_lift):
		if _cached_main_lift.is_inside_tree() and _cached_main_lift.is_in_group("shaft-gadget") and _is_main_lift_node(_cached_main_lift):
			return _cached_main_lift
	_cached_main_lift = _find_main_lift()
	return _cached_main_lift

func _find_main_lift() -> Node2D:
	var lifts: Array = get_tree().get_nodes_in_group("shaft-gadget")
	for lift in lifts:
		if _is_main_lift_node(lift) and lift.teamId == teamId:
			return lift
	return null

func _any_carryable_in_lift_area(lift: Node2D) -> bool:
	var lift_orbs: Array = get_tree().get_nodes_in_group("lift_orbs")
	for carryable in carriedCarryables:
		if carryable == null or not is_instance_valid(carryable):
			continue
		if _is_position_in_main_lift(carryable.global_position, lift) or _is_position_in_lift_orb(carryable.global_position, lift_orbs):
			return true
	return false

func _begin_lift_docking(lift_center_x: float) -> void :
	_lift_dock_state = LiftDockState.DOCKING
	_lift_dock_target_x = lift_center_x

	if not attached:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		freeze = true
		sleeping = true
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		global_position.x = lift_center_x

	chainManager.skip_forces_for_frames(5)

	_lift_dock_state = LiftDockState.RELEASING
	_release_next_resource()

func _release_next_resource() -> void :
	while not carriedCarryables.is_empty():
		var resource_to_release = carriedCarryables[0]
		if resource_to_release == null or not is_instance_valid(resource_to_release):
			carriedCarryables.erase(resource_to_release)
			continue

		_carrierDetachBody(resource_to_release, Vector2.ZERO)

		if resource_to_release is RigidBody2D:
			resource_to_release.linear_velocity = Vector2.ZERO
			resource_to_release.angular_velocity = 0.0
			PhysicsServer2D.body_set_state(resource_to_release.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
			PhysicsServer2D.body_set_state(resource_to_release.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
			resource_to_release.apply_central_impulse(Vector2.UP * Keeper3SecondarySettings.LIFT_RELEASE_UPWARD_IMPULSE)

		if carriedCarryables.is_empty():
			_lift_dock_state = LiftDockState.FINISHED
		else:
			_lift_dock_state = LiftDockState.COMPRESSING
		return

	_lift_dock_state = LiftDockState.FINISHED

func _apply_compression_impulse() -> void :
	var carrier_pos: Vector2 = global_position
	for i in range(carriedCarryables.size()):
		var body = carriedCarryables[i]
		if body == null or not is_instance_valid(body):
			continue
		if not (body is RigidBody2D):
			continue
		var direction: Vector2 = (carrier_pos - body.global_position).normalized()
		var impulse_strength: float = Keeper3SecondarySettings.LIFT_COMPRESSION_IMPULSE * (1.0 + float(i) * 0.5)
		body.apply_central_impulse(direction * impulse_strength)

func _process_lift_dock(delta: float) -> void :
	match _lift_dock_state:
		LiftDockState.INACTIVE:
			return
		LiftDockState.DOCKING:
			pass
		LiftDockState.RELEASING:
			pass
		LiftDockState.COMPRESSING:
			if _is_compression_complete():
				_lift_dock_state = LiftDockState.RELEASING
				Level.drops.network_release_next_resource_from_dock(UID)
			else:
				_apply_compression_impulse()
		LiftDockState.FINISHED:
			_lift_dock_state = LiftDockState.INACTIVE
			destroyKunaiCarrier()

func _is_compression_complete() -> bool:
	if carriedCarryables.is_empty():
		return true

	var first_resource = carriedCarryables[0]
	if first_resource == null or not is_instance_valid(first_resource):
		return true

	var distance_to_carrier: float = first_resource.global_position.distance_to(global_position)
	if distance_to_carrier > Keeper3SecondarySettings.LIFT_COMPRESSION_SETTLE_DISTANCE:
		return false

	if first_resource is RigidBody2D:
		var velocity: float = first_resource.linear_velocity.length()
		if velocity > Keeper3SecondarySettings.LIFT_COMPRESSION_SETTLE_VELOCITY:
			return false

	return true

const SHREDDER_PROXIMITY_RADIUS: = 0.0
const SHREDDER_APPROACH_SPEED: = 250.0

func _check_shredder_proximity() -> void :
	if not is_instance_valid(_shredder_ref):
		var resolved_team_id: String = teamId
		if resolved_team_id.is_empty():
			var keeper = Keepers.getKeeper(playerId)
			if is_instance_valid(keeper):
				resolved_team_id = keeper.teamId
		if Level.domesByTeamId.has(resolved_team_id):
			var dome = Level.domesByTeamId[resolved_team_id]
			_shredder_ref = dome.get_node_or_null("Shredder")
	if not is_instance_valid(_shredder_ref):
		return
	if not multiplayer.is_server():
		return
	var dist: float = global_position.distance_to(_shredder_ref.global_position)
	if dist <= SHREDDER_PROXIMITY_RADIUS:
		Level.drops.network_begin_carrier_shredder_docking(UID)

func _begin_shredder_docking() -> void :
	var resolved_team_id: String = teamId
	var keeper = Keepers.getKeeper(playerId)
	if is_instance_valid(keeper):
		resolved_team_id = keeper.teamId

	for c in carriedCarryables.duplicate():
		var dropCarryable: = false
		if c.get_collision_mask_value(CONST.LAYER_DOME_EXTERNAL):
			dropCarryable = true
			if c.type == CONST.RELIC:
				c.dropTargetRef = Level.domesByTeamId[resolved_team_id].RelicDropPoint
				if multiplayer.is_server():
					Level.drops.network_set_independent(c, true)
			elif c.type == CONST.POWERCORE or c.type == CONST.GADGET:
				c.dropTargetRef = Level.domesByTeamId[resolved_team_id].ArtifactDropPoint
				if multiplayer.is_server():
					Level.drops.network_set_independent(c, true)
		elif c.type == CONST.EGG:
			dropCarryable = true
			c.dropTargetRef = Level.domesByTeamId[resolved_team_id].EggDropPoint
			if multiplayer.is_server():
				Level.drops.network_set_independent(c, true)
		if dropCarryable:
			_carrierDetachBody(c, Vector2.ZERO)

	if carriedCarryables.is_empty():
		destroyKunaiCarrier()
		return

	if multiplayer.is_server():
		_freeze_kunai_for_shredding()

	if Level.domesByTeamId.has(resolved_team_id):
		var dome = Level.domesByTeamId[resolved_team_id]
		_shredder_ref = dome.get_node_or_null("Shredder")

	if multiplayer.is_server():
		chainManager.skip_forces_for_frames(5)
		_shredder_dock_cooldown = 0.0
	else:
		_shredder_dock_cooldown = 0.1
	_shredder_dock_state = ShredderDockState.CONSUMING

func _freeze_kunai_for_shredding() -> void :
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	sleeping = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	kunaiSprite.visible = false

func _consume_next_resource() -> void :
	while not carriedCarryables.is_empty():
		var resource = carriedCarryables[0]
		if resource == null or not is_instance_valid(resource):
			carriedCarryables.erase(resource)
			continue

		if resource is Drop and is_instance_valid(_shredder_ref):
			resource.dropTargetRef = _shredder_ref
			resource.setIndependent(true)
			_shredder_ref.arrived(resource)
			if not _shredder_ref.dropsInRange.has(resource):
				_shredder_ref.dropsInRange.append(resource)

		_carrierDetachBody(resource, Vector2.ZERO)

		if carriedCarryables.is_empty():
			_shredder_dock_state = ShredderDockState.FINISHED
		return

	_shredder_dock_state = ShredderDockState.FINISHED

func _process_shredder_dock(delta: float) -> void :
	match _shredder_dock_state:
		ShredderDockState.INACTIVE:
			return
		ShredderDockState.CONSUMING:
			_shredder_dock_cooldown -= delta
			if _shredder_dock_cooldown <= 0.0:
				if kunaiSprite.visible:
					_freeze_kunai_for_shredding()
				_consume_next_resource()
				_shredder_dock_cooldown = 0.3
		ShredderDockState.FINISHED:
			_shredder_dock_state = ShredderDockState.INACTIVE
			destroyKunaiCarrier()

func _is_position_in_main_lift(pos: Vector2, lift: Node2D = null) -> bool:
	if is_instance_valid(lift):
		return _is_position_in_lift_node(pos, lift)

	var lifts: Array = get_tree().get_nodes_in_group("pauseL")
	for candidate in lifts:
		if not _is_main_lift_node(candidate):
			continue
		if _is_position_in_lift_node(pos, candidate):
			return true

	return false

func _is_position_in_lift_node(pos: Vector2, lift: Node2D) -> bool:
	var collision_shape: CollisionShape2D = lift.get_node_or_null("CollisionShape2D")
	if collision_shape == null or collision_shape.disabled:
		return false

	var shape = collision_shape.shape
	if shape == null or not (shape is RectangleShape2D):
		return false

	var shape_global_transform: Transform2D = lift.global_transform * collision_shape.transform
	var local_point: Vector2 = shape_global_transform.affine_inverse() * pos
	var half_size: Vector2 = (shape as RectangleShape2D).size * 0.5

	return abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y

func _is_position_in_lift_orb(pos: Vector2, lift_orbs: Array = []) -> bool:
	var orbs: Array = lift_orbs
	if orbs.is_empty():
		orbs = get_tree().get_nodes_in_group("lift_orbs")
	for orb in orbs:
		if orb == null or not is_instance_valid(orb):
			continue

		var carry_area: Area2D = orb.get_node_or_null("CarryArea")
		if carry_area == null:
			continue

		var collision_shape: CollisionShape2D = carry_area.get_node_or_null("CollisionShape2D")
		if collision_shape == null or collision_shape.disabled:
			continue

		var shape = collision_shape.shape
		if shape == null or not (shape is CircleShape2D):
			continue

		var shape_global_pos: Vector2 = carry_area.global_transform * collision_shape.position
		var distance_sq: float = pos.distance_squared_to(shape_global_pos)
		var radius: float = shape.radius

		if distance_sq <= radius * radius:
			return true

	return false

func _on_tree_exited() -> void :
	chainManager.drop_all()

func force_move_towards_shredder(in_shredder: Shredder) -> void :
	var direction: Vector2 = (in_shredder.global_position - global_position).normalized()
	launch_direction = direction
	var minimal_speed: = 500.0
	var speed = max(lastVelocity.length(), minimal_speed)
	lastVelocity = direction
	rotation = direction.normalized().angle() + PI * 0.5
	linear_velocity = direction * speed
