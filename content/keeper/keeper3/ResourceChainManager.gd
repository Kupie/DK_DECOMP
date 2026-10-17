extends Node
class_name ResourceChainManager

var carrier: Node2D
var carriedCarryables: Array = []

var carryChains: = {}
var carryableConnections: = {}
var _original_collision_layers: = {}
var _original_collision_masks: = {}
var _original_bounce: = {}
var _prev_predecessor_positions: = {}
var _tile_query_cache: = {}
var _skip_force_frames: = 0
var _pause_locked_states: = {}

func calculate_spring_force(body: RigidBody2D, target_position: Vector2, desired_distance: float) -> Vector2:
	var to_body: Vector2 = body.global_position - target_position
	var distance: float = to_body.length()
	var direction: Vector2

	if distance <= 0.0001:
		return Vector2.ZERO

	direction = to_body / distance
	var distance_error: float = distance - desired_distance

	if abs(distance_error) < 0.1:
		return Vector2.ZERO

	var correction_force: Vector2 = - direction * distance_error * Keeper3SecondarySettings.CARRY_SPRING_STIFFNESS
	var radial_velocity: float = body.linear_velocity.dot(direction)
	var damping_force: Vector2 = - direction * radial_velocity * Keeper3SecondarySettings.CARRY_SPRING_DAMPING

	return correction_force + damping_force

func update_chains(delta: float) -> void :
	ensure_setup()
	cleanup_carry_chains()
	apply_follow_forces(delta)
	update_chain_visuals()

func update_chain_visuals() -> void :
	for body_index in range(carriedCarryables.size()):
		var body = carriedCarryables[body_index]
		if body == null or not is_instance_valid(body):
			continue
		if not (carrier is KunaiCarrier) and body.has_meta("kunai_carrier"):
			var body_carrier = body.get_meta("kunai_carrier")
			if body_carrier != null and is_instance_valid(body_carrier) and body_carrier != carrier:
				continue
		if not carryChains.has(body):
			continue
		var chain = carryChains[body]
		if not is_instance_valid(chain):
			continue
		var anchor: Node2D = get_chain_anchor_node(body_index)
		var start_pos: Vector2 = anchor.global_position if is_instance_valid(anchor) else carrier.global_position
		if body_index == 0 and carrier is Keeper and carrier.isInsideStation and carrier._station is Station4:
			start_pos = carrier._station.getVisualGlobalPosition() + Vector2(-6, 9)
		var body_pos: Vector2 = body.global_position
		if int(body.get_meta("pickup_settle_frames", 0)) > 0 and not body.get_meta("pickup_chain_arrived", false):
			if start_pos.distance_to(body_pos) > Keeper3SecondarySettings.CARRY_CHAIN_VISUAL_MAX_STRETCH:
				chain.update_chain(start_pos, start_pos)
				continue
			body.set_meta("pickup_chain_arrived", true)
		chain.update_chain(start_pos, body_pos)

func ensure_setup() -> void :
	for body in carriedCarryables.duplicate():
		setup_carryable(body)

func setup_carryable(body) -> void :
	if body == null:
		return
	if not is_instance_valid(body):
		detach_body(body)
		return
	if carryChains.has(body):
		return
	if not (carrier is KunaiCarrier) and body.has_meta("kunai_carrier"):
		var body_carrier = body.get_meta("kunai_carrier")
		if body_carrier != null and is_instance_valid(body_carrier) and body_carrier != carrier:
			return
	body.set_meta("kunai_carrier", carrier)
	if body is RigidBody2D:
		body.add_collision_exception_with(carrier)
		carrier.add_collision_exception_with(body)
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
		body.lock_rotation = true
		for child in body.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.disabled = false
		_original_collision_layers[body] = body.collision_layer
		_original_collision_masks[body] = body.collision_mask
		if carrier is KunaiCarrier and body is Carryable:
			_original_bounce[body] = body.physics_material_override.bounce
			body.physics_material_override.bounce = Keeper3SecondarySettings.CARRY_KUNAI_CARRIED_BOUNCE
		body.set_collision_layer_value(CONST.LAYER_DROP_COLLISION, false)
		body.set_collision_mask_value(CONST.LAYER_DROP_COLLISION, false)
		body.set_collision_layer_value(CONST.LAYER_CARRIED_DROP_COLLISION, true)
		body.set_collision_mask_value(CONST.LAYER_CARRIED_DROP_COLLISION, true)
		body.set_collision_mask_value(CONST.LAYER_TILE_COLLISION, true)
		var body_is_resource: bool = body is Carryable and body.carryableType == "resource"
		if body_is_resource:
			if carrier is KunaiCarrier:
				body.set_collision_layer_value(CONST.LAYER_CARRIED_DROP_COLLISION, false)
				body.set_collision_mask_value(CONST.LAYER_CARRIED_DROP_COLLISION, false)
				body.set_collision_layer_value(CONST.LAYER_KUNAI_CARRIED_DROP_COLLISION, true)
				body.set_collision_mask_value(CONST.LAYER_KUNAI_CARRIED_DROP_COLLISION, true)
		else:
			body.set_collision_layer_value(CONST.LAYER_CARRIED_DROP_COLLISION, false)
			body.set_collision_mask_value(CONST.LAYER_CARRIED_DROP_COLLISION, false)
		for other in carriedCarryables:
			if other == body:
				continue
			if not (other is RigidBody2D):
				continue
			var other_is_resource: bool = other is Carryable and other.carryableType == "resource"
			if body_is_resource and other_is_resource:
				continue
			body.add_collision_exception_with(other)
			other.add_collision_exception_with(body)
		if body_is_resource and carrier is KunaiCarrier:
			for other_carrier in Level.drops.synchronizer.carriers.values():
				if other_carrier == carrier:
					continue
				for other_res in other_carrier.carriedCarryables:
					if other_res is Carryable and other_res.carryableType == "resource":
						body.add_collision_exception_with(other_res)
						other_res.add_collision_exception_with(body)
	var chain: Keeper3CarryChain = Keeper3SecondarySettings.CARRIER_CHAIN_SCENE.instantiate()
	var parent: = carrier.get_parent()
	if parent:
		parent.add_child(chain)
	else:
		carrier.add_child(chain)
	chain.set_link_z_index(Keeper3SecondarySettings.CARRY_CHAIN_LINK_Z_INDEX)
	carryChains[body] = chain
	Style.init(chain)
	var removal_callable: = Callable(self, "on_carryable_removed").bind(body)
	body.connect("tree_exited", removal_callable, CONNECT_ONE_SHOT)
	carryableConnections[body] = removal_callable

func get_chain_anchor_node(body_index: int) -> Node2D:
	if body_index <= 0:
		if carrier.has_method("getChainSpawnNode"):
			var keeper_anchor: Node2D = carrier.getChainSpawnNode()
			return keeper_anchor if is_instance_valid(keeper_anchor) else carrier
		return carrier
	var previous_body = carriedCarryables[body_index - 1]
	if previous_body != null and is_instance_valid(previous_body) and previous_body is Node2D:
		return previous_body as Node2D
	if carrier.has_method("getChainSpawnNode"):
		var fallback_anchor: Node2D = carrier.getChainSpawnNode()
		return fallback_anchor if is_instance_valid(fallback_anchor) else carrier
	return carrier

func cleanup_carry_chains() -> void :
	var toRemove: Array = []
	for body in carryChains.keys():
		if body == null:
			toRemove.append(body)
			continue
		if not is_instance_valid(body):
			toRemove.append(body)
			continue
		if not carriedCarryables.has(body):
			toRemove.append(body)
			continue
		var chain = carryChains[body]
		if not is_instance_valid(chain):
			toRemove.append(body)
	for b in toRemove:
		if b == null:
			continue
		_prev_predecessor_positions.erase(b)
		_tile_query_cache.erase(b)
		remove_carry_chain(b)

func skip_forces_for_frames(frames: int) -> void :
	_skip_force_frames = frames

func lock_carried_bodies_for_pause() -> void :
	for body in carriedCarryables:
		if not (body is RigidBody2D):
			continue
		if not _pause_locked_states.has(body):
			_pause_locked_states[body] = [body.global_position, body.linear_velocity]
		body.global_position = _pause_locked_states[body][0]
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0

func release_pause_lock() -> void :
	for body in carriedCarryables:
		if body is RigidBody2D and _pause_locked_states.has(body):
			body.global_position = _pause_locked_states[body][0]
			body.linear_velocity = _pause_locked_states[body][1]
	_pause_locked_states.clear()

func _build_dome_external_shape_query(body: RigidBody2D) -> PhysicsShapeQueryParameters2D:
	var shape: Shape2D
	var shape_transform: Transform2D
	for child in body.get_children():
		if child is CollisionShape2D:
			shape = child.shape
			shape_transform = child.global_transform
			break
		if child is CollisionPolygon2D:
			var poly_shape: = ConvexPolygonShape2D.new()
			poly_shape.points = child.polygon
			shape = poly_shape
			shape_transform = child.global_transform
			break
	var query: = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = shape_transform
	query.collision_mask = 1 << (CONST.LAYER_DOME_EXTERNAL - 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [body.get_rid()]
	return query

func _is_penetrating_dome_external(body: RigidBody2D) -> bool:
	var query: = _build_dome_external_shape_query(body)
	var space: = body.get_world_2d().direct_space_state
	return space.intersect_shape(query, 1).size() > 0

func _sweep_hits_dome_external(body: RigidBody2D, displacement: Vector2) -> bool:
	var query: = _build_dome_external_shape_query(body)
	query.motion = displacement
	var space: = body.get_world_2d().direct_space_state
	return space.cast_motion(query)[0] < 1.0

func build_tile_shape_query(body: RigidBody2D) -> PhysicsShapeQueryParameters2D:
	var cached: Array = _tile_query_cache.get(body, [])
	if cached.is_empty():
		var shape: Shape2D
		var shape_owner: Node2D
		for child in body.get_children():
			if child is CollisionShape2D:
				shape = child.shape
				shape_owner = child
				break
			if child is CollisionPolygon2D:
				var poly_shape: = ConvexPolygonShape2D.new()
				poly_shape.points = child.polygon
				shape = poly_shape
				shape_owner = child
				break
		var new_query: = PhysicsShapeQueryParameters2D.new()
		new_query.shape = shape
		new_query.collide_with_areas = false
		new_query.collide_with_bodies = true
		new_query.exclude = [body.get_rid()]
		cached = [new_query, shape_owner]
		_tile_query_cache[body] = cached
	var query: PhysicsShapeQueryParameters2D = cached[0]
	var shape_owner_node: Node2D = cached[1]
	query.transform = shape_owner_node.global_transform
	query.collision_mask = 1 << (CONST.LAYER_TILE_COLLISION - 1)
	query.margin = 0.0
	query.motion = Vector2.ZERO
	return query

func get_tile_contact_normal(body: RigidBody2D) -> Vector2:
	var space: = body.get_world_2d().direct_space_state
	var query: = build_tile_shape_query(body)
	query.margin = 1.0
	var rest: = space.get_rest_info(query)
	if rest.is_empty():
		return Vector2.ZERO
	var normal: Vector2 = rest.get("normal", Vector2.ZERO)
	return normal

func slide_displacement_against_tiles(body: RigidBody2D, displacement: Vector2) -> Vector2:
	if displacement.length_squared() <= 0.0001:
		return displacement
	var space: = body.get_world_2d().direct_space_state
	var query: = build_tile_shape_query(body)
	var initial_motion = query.motion
	query.motion = displacement
	var result: Array = space.cast_motion(query)
	if result[0] >= 1.0:
		return displacement
	query.motion = initial_motion
	query.transform = query.transform.translated(displacement * result[0])
	query.margin = 1.0
	var rest: = space.get_rest_info(query)
	if rest.is_empty():
		return displacement
	var normal: Vector2 = rest.get("normal", Vector2.ZERO)
	if normal == Vector2.ZERO:
		return displacement
	var into: float = displacement.dot(normal)
	if into >= 0.0:
		return displacement
	return redirect_along_tile_face(displacement, normal, displacement.normalized())

func redirect_along_tile_face(displacement: Vector2, contact_normal: Vector2, pull_direction: Vector2) -> Vector2:
	var tangent: Vector2 = Vector2( - contact_normal.y, contact_normal.x)
	if pull_direction.dot(tangent) < 0.0:
		tangent = - tangent
	return tangent * displacement.length()

func correction_blocked(body: RigidBody2D, displacement: Vector2) -> bool:
	if displacement.length_squared() <= 0.0001:
		return false
	var space: = body.get_world_2d().direct_space_state
	var query: = build_tile_shape_query(body)
	query.collision_mask = body.collision_mask
	query.motion = displacement
	var result: Array = space.cast_motion(query)
	return result[0] < 0.5

func apply_follow_forces(delta: float) -> void :
	if delta <= 0.0:
		return

	if _skip_force_frames > 0:
		_skip_force_frames -= 1
		for body in carriedCarryables:
			if body is RigidBody2D:
				body.linear_velocity = Vector2.ZERO
				body.angular_velocity = 0.0
		return

	var total_bodies: int = carriedCarryables.size()
	if total_bodies <= 0:
		return

	var is_server: bool = multiplayer.is_server()
	var carrier_is_kunai: bool = carrier is KunaiCarrier
	var carrier_position: Vector2 = carrier.global_position
	var carrier_velocity: Vector2 = carrier.linear_velocity if carrier_is_kunai else carrier.velocity
	var keeper_in_dome: bool = carrier is Keeper and carrier.isInsideDome
	var index: = 0

	for body in carriedCarryables:
		if body == null or not is_instance_valid(body):
			continue

		if body.has_meta("kunai_carrier"):
			var body_carrier = body.get_meta("kunai_carrier")
			if body_carrier != null and is_instance_valid(body_carrier) and body_carrier != carrier:
				index += 1
				continue

		if not (body is RigidBody2D):
			index += 1
			continue

		var rigid_body: = body as RigidBody2D

		var prev_position: Vector2 = carrier_position
		if index > 0:
			var prev_body = carriedCarryables[index - 1]
			if prev_body != null and is_instance_valid(prev_body) and prev_body is Node2D:
				prev_position = (prev_body as Node2D).global_position

		var constraint_dist: float = Keeper3SecondarySettings.CARRY_FOLLOW_REST_DISTANCE * 1.05

		if is_server:
			var prev_b_pos: Vector2 = _prev_predecessor_positions.get(body, prev_position)
			var predecessor_delta: Vector2 = prev_position - prev_b_pos
			_prev_predecessor_positions[body] = prev_position
			var predecessor_moved: bool = predecessor_delta.length_squared() > 0.01

			var desired_distance: float = Keeper3SecondarySettings.CARRY_FOLLOW_REST_DISTANCE * (index + 1)
			var attached_multiplier: float = 1.0
			if carrier is KunaiCarrier and (carrier as KunaiCarrier).attached:
				attached_multiplier = Keeper3SecondarySettings.CARRY_CHAIN_ATTACHED_STRAIGHTENING_MULTIPLIER
			var straightening: float = Keeper3SecondarySettings.CARRY_CHAIN_STRAIGHTENING_FORCE * attached_multiplier
			var force: Vector2 = Vector2.ZERO
			if index == 0:
				force = calculate_spring_force(rigid_body, carrier_position, desired_distance) * attached_multiplier
			elif straightening > 0.0:
				force = calculate_spring_force(rigid_body, carrier_position, desired_distance) * straightening

			if force != Vector2.ZERO:
				rigid_body.apply_central_force(force)
				rigid_body.sleeping = false

			var to_resource: Vector2 = rigid_body.global_position - carrier_position
			if to_resource.length_squared() > 0.01 and rigid_body.linear_velocity.length_squared() > 0.01:
				var radial_dir: Vector2 = to_resource.normalized()
				var tangent_dir: Vector2 = Vector2( - radial_dir.y, radial_dir.x)
				var tangential_velocity: float = rigid_body.linear_velocity.dot(tangent_dir)
				var damping_factor: float = 1.0 if index == 0 else 0.1
				rigid_body.apply_central_force( - tangent_dir * tangential_velocity * Keeper3SecondarySettings.CARRY_ORBITAL_DAMPING * damping_factor)

			var to_prev: Vector2 = rigid_body.global_position - prev_position
			var current_dist: float = to_prev.length()

			if current_dist > constraint_dist:
				rigid_body.sleeping = false
				var correction_dir: Vector2 = - to_prev.normalized()
				var correction_dist: float = current_dist - constraint_dist

				var displacement: Vector2 = correction_dir * correction_dist * 0.5

				var redirect_fired: bool = false
				if predecessor_moved:
					var contact_normal: Vector2 = get_tile_contact_normal(rigid_body)
					if contact_normal != Vector2.ZERO and displacement.dot(contact_normal) < 0.0:
						displacement = redirect_along_tile_face(displacement, contact_normal, correction_dir)
						redirect_fired = true

				if keeper_in_dome and (_is_penetrating_dome_external(rigid_body) or _sweep_hits_dome_external(rigid_body, displacement)):
					index += 1
					continue

				if not redirect_fired:
					displacement = slide_displacement_against_tiles(rigid_body, displacement)
				if carrier_is_kunai and (carrier as KunaiCarrier).attached and correction_blocked(rigid_body, displacement):
					var follow_force: Vector2 = calculate_spring_force(rigid_body, prev_position, constraint_dist)
					if follow_force != Vector2.ZERO:
						rigid_body.apply_central_force(follow_force * Keeper3SecondarySettings.CARRY_CHAIN_BLOCKED_FOLLOW_FORCE)
						rigid_body.sleeping = false
					displacement = Vector2.ZERO
				rigid_body.global_position += displacement

				var radial_vel: float = rigid_body.linear_velocity.dot(correction_dir)
				if radial_vel < 0:
					rigid_body.linear_velocity -= correction_dir * radial_vel

			if carrier_velocity.length_squared() < 100.0 and rigid_body.linear_velocity.length_squared() > 0.01:
				rigid_body.linear_velocity *= 0.92
		else:
			var to_prev: Vector2 = rigid_body.global_position - prev_position
			var current_dist: float = to_prev.length()
			if current_dist > constraint_dist and current_dist > 0.01:
				rigid_body.global_position = prev_position + to_prev / current_dist * constraint_dist
			rigid_body.linear_velocity = carrier_velocity

		index += 1

func detach_body(body) -> void :
	if carriedCarryables.has(body):
		carriedCarryables.erase(body)
	_prev_predecessor_positions.erase(body)
	_tile_query_cache.erase(body)
	if carryableConnections.has(body):
		var removal_callable: Callable = carryableConnections[body]
		if body != null and is_instance_valid(body) and body.is_connected("tree_exited", removal_callable):
			body.disconnect("tree_exited", removal_callable)
		carryableConnections.erase(body)
	if body == null:
		return
	if not is_instance_valid(body):
		remove_carry_chain(body)
		return
	if body is RigidBody2D:
		body.remove_collision_exception_with(carrier)
		carrier.remove_collision_exception_with(body)
		var body_is_resource: bool = body is Carryable and body.carryableType == "resource"
		for other in carriedCarryables:
			if other == body:
				continue
			if not (other is RigidBody2D):
				continue
			var other_is_resource: bool = other is Carryable and other.carryableType == "resource"
			if body_is_resource and other_is_resource:
				continue
			body.remove_collision_exception_with(other)
			other.remove_collision_exception_with(body)
		if body_is_resource and carrier is KunaiCarrier:
			for other_carrier in Level.drops.synchronizer.carriers.values():
				if other_carrier == carrier:
					continue
				for other_res in other_carrier.carriedCarryables:
					if other_res is Carryable and other_res.carryableType == "resource":
						body.remove_collision_exception_with(other_res)
						other_res.remove_collision_exception_with(body)
		body.lock_rotation = false
		if _original_collision_layers.has(body):
			body.collision_layer = _original_collision_layers[body]
			_original_collision_layers.erase(body)
		if _original_collision_masks.has(body):
			body.collision_mask = _original_collision_masks[body]
			_original_collision_masks.erase(body)
		if _original_bounce.has(body):
			body.physics_material_override.bounce = _original_bounce[body]
			_original_bounce.erase(body)
	if body.has_method("freeCarry"):
		body.freeCarry(carrier)
	body.set_meta("kunai_carrier", null)
	remove_carry_chain(body)

func remove_carry_chain(body) -> void :
	if body == null:
		return
	if carryChains.has(body):
		var chain = carryChains[body]
		if is_instance_valid(chain):
			chain.clear_links()
			chain.queue_free()
		carryChains.erase(body)

func on_carryable_removed(body) -> void :
	var isAboutToBeDeleted: bool = not is_inside_tree()
	if isAboutToBeDeleted:
		return
	carryableConnections.erase(body)
	detach_body(body)

func drop_all() -> void :
	for body in carryChains.keys():
		if body is Carryable:
			if _original_collision_layers.has(body):
				body.collision_layer = _original_collision_layers[body]
			if _original_collision_masks.has(body):
				body.collision_mask = _original_collision_masks[body]
			if _original_bounce.has(body):
				body.physics_material_override.bounce = _original_bounce[body]
			body.freeCarry(carrier)
			body.ensurePhysicsProcessed()
	_original_collision_layers.clear()
	_original_collision_masks.clear()
	_original_bounce.clear()
	for chain_body in carryChains.keys().duplicate():
		remove_carry_chain(chain_body)
