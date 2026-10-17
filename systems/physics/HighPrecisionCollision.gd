extends Node




class_name HighPrecisionCollision

const SNAP_EPSILON: = 0.0



static func sweep_and_snap(
	body: Node2D, 
	radius: float, 
	from: Vector2, 
	to: Vector2, 
	exclude: Array = []
) -> Dictionary:
	var result: = {"collided": false}
	if not is_instance_valid(body):
		return result
	if radius <= 0.0:
		return result

	var motion: Vector2 = to - from
	var length: = motion.length()
	if length <= 0.0:
		return result

	var dir: = motion / length
	var perp: = Vector2( - dir.y, dir.x) * radius

	var state: = body.get_world_2d().direct_space_state
	var mask: = 2147483647
	if body is CollisionObject2D:
		mask = (body as CollisionObject2D).collision_mask

	var from_a: = from + perp
	var to_a: = from_a + dir * length
	var from_b: = from - perp
	var to_b: = from_b + dir * length

	var rq_a: = PhysicsRayQueryParameters2D.new()
	rq_a.from = from_a
	rq_a.to = to_a
	rq_a.exclude = exclude
	rq_a.collision_mask = mask
	rq_a.collide_with_bodies = true
	rq_a.collide_with_areas = false
	rq_a.hit_from_inside = true

	var rq_b: = PhysicsRayQueryParameters2D.new()
	rq_b.from = from_b
	rq_b.to = to_b
	rq_b.exclude = exclude
	rq_b.collision_mask = mask
	rq_b.collide_with_bodies = true
	rq_b.collide_with_areas = false
	rq_b.hit_from_inside = true

	var hit_a: = state.intersect_ray(rq_a)
	var hit_b: = state.intersect_ray(rq_b)

	var best_hit: Dictionary = {}
	var best_t: = INF

	for h in [hit_a, hit_b]:
		if h is Dictionary and h.size() > 0:
			var p: Vector2 = h.get("position", h.get("point", from))
			var t: = (p - from).dot(dir)
			if t >= 0.0 and t <= length and t < best_t:
				best_t = t
				best_hit = h

	if best_hit.is_empty():
		if _is_outside_reachable_tile_area(to):
			best_hit = _perform_failsafe_check(state, from, to, motion, perp, mask, exclude)
		if best_hit.is_empty():
			return result
		var p: Vector2 = best_hit.get("position", best_hit.get("point", from))
		best_t = (p - from).dot(dir)

	var snap_pos: = from + dir * best_t
	result.collided = true
	result.point = best_hit.get("position", best_hit.get("point", snap_pos))
	result.normal = best_hit.get("normal", Vector2.ZERO)
	result.collider = best_hit.get("collider", null)
	result.rid = best_hit.get("rid", RID())
	result.distance = best_t
	result.snap_position = snap_pos
	return result

static func _is_outside_reachable_tile_area(in_position: Vector2) -> bool:
	var map_data: MapData = Level.map.tileData
	var coord: Vector2i = Level.map.getTileCoord(in_position)
	var cell: int = map_data.get_cell_source_id(MapData.LAYER_RESOURCES, coord)
	var reachable_cell = cell == -1
	return not reachable_cell

static func _perform_failsafe_check(state: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, motion: Vector2, 
			perp: Vector2, _mask: int, exclude: Array) -> Dictionary:
	var direction: Vector2 = from.direction_to(to)
	var reverse_direction: Vector2 = to.direction_to(from)
	var failsafe_check_length: float = max(GameWorld.HALF_TILE_DIAGONAL, motion.length())
	var initial_check_point: Vector2 = to + reverse_direction * failsafe_check_length
	var test_radius: float = 2.0
	var future_check_factor: = 1.2
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = test_radius
	var motion_query = PhysicsShapeQueryParameters2D.new()
	motion_query.shape = circle_shape
	motion_query.transform = Transform2D(0, initial_check_point)
	motion_query.motion = direction * failsafe_check_length * future_check_factor
	motion_query.collision_mask = 1
	motion_query.collide_with_bodies = true
	motion_query.collide_with_areas = false
	motion_query.exclude = exclude

	var static_result = state.get_rest_info(motion_query)
	if not static_result.is_empty():
		static_result["collider"] = instance_from_id(static_result.collider_id)
		return static_result

	var motion_test = state.cast_motion(motion_query)
	var has_result: bool = ( not is_equal_approx(motion_test[0], 1.0)) and ( not is_equal_approx(motion_test[1], 1.0))
	if has_result:
		var unsafe_factor: float = motion_test[1]
		var unsafe_position: Vector2 = initial_check_point + direction * failsafe_check_length * unsafe_factor
		motion_query.transform = Transform2D(0, unsafe_position)
		var motion_result = state.get_rest_info(motion_query)
		if not motion_result.is_empty():
			motion_result["collider"] = instance_from_id(motion_result.collider_id)
			return motion_result

	return {}
