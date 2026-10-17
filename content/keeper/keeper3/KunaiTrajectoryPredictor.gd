extends Node2D

const LINE_COLOR: = Color(1.0, 1.0, 1.0, 0.4)
const LINE_WIDTH: = 1.3
const HIT_SIZE: = 1.0
const HIT_WIDTH: = 2.0
const V_SIZE: = 4.0

@onready var hit_marker: Line2D = $HitMarker
@onready var bounces_container: Node2D = $BouncesContainer

var _bounce_markers: Array[Line2D] = []


func update_prediction(start_pos: Vector2, direction: Vector2, speed: float, collision_mask: int) -> void :
	var result: Dictionary = _simulate_trajectory(start_pos, direction * speed, collision_mask)

	var hit_point = result.get("hit_point", null)
	if hit_point != null:
		_update_hit_marker(hit_point)
		hit_marker.visible = true
	else:
		hit_marker.visible = false

	var bounces: Array = result.get("bounces", [])
	_update_bounce_markers(bounces)


func _simulate_trajectory(start_pos: Vector2, velocity: Vector2, collision_mask: int) -> Dictionary:
	var current_pos: Vector2 = start_pos
	var current_velocity: Vector2 = velocity
	var remaining_distance: float = Keeper3GameplaySettings.KUNAI_MAX_DISTANCE
	var bounce_count: int = 0
	var bounces: Array = []
	var final_hit_point = null

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return {"hit_point": null, "bounces": []}

	for _iteration in range(4):
		if remaining_distance <= 0.0:
			break

		var sweep_result: Dictionary = _sweep_cast(space, current_pos, current_velocity.normalized(), remaining_distance, collision_mask)

		if not sweep_result.collided:
			break

		var hit_pos: Vector2 = sweep_result.point
		var hit_normal: Vector2 = sweep_result.normal
		var snap_pos: Vector2 = sweep_result.snap_position
		var distance_traveled: float = sweep_result.distance
		remaining_distance -= distance_traveled

		var can_bounce: bool = _can_bounce(current_velocity, hit_normal, bounce_count)

		if can_bounce:
			var incoming_velocity: Vector2 = current_velocity
			var reflected_velocity: Vector2 = current_velocity.bounce(hit_normal) * Keeper3GameplaySettings.KUNAI_BOUNCE_DAMPING

			if reflected_velocity.length() < Keeper3GameplaySettings.KUNAI_MIN_BOUNCE_SPEED:
				if reflected_velocity.length_squared() > 0.0:
					reflected_velocity = reflected_velocity.normalized() * Keeper3GameplaySettings.KUNAI_MIN_BOUNCE_SPEED
				else:
					reflected_velocity = current_velocity.normalized() * Keeper3GameplaySettings.KUNAI_MIN_BOUNCE_SPEED

			var separation: float = Keeper3GameplaySettings.KUNAI_COLLISION_RADIUS + Keeper3GameplaySettings.KUNAI_BOUNCE_SEPARATION
			current_pos = hit_pos + hit_normal * separation
			if Keeper3GameplaySettings.KUNAI_BOUNCE_FORWARD_OFFSET > 0.0:
				current_pos += reflected_velocity.normalized() * Keeper3GameplaySettings.KUNAI_BOUNCE_FORWARD_OFFSET

			bounces.append({
				"point": current_pos, 
				"incoming": incoming_velocity.normalized(), 
				"outgoing": reflected_velocity.normalized()
			})

			current_velocity = reflected_velocity
			bounce_count += 1
		else:
			final_hit_point = snap_pos
			break

	return {"hit_point": final_hit_point, "bounces": bounces}


func _sweep_cast(space: PhysicsDirectSpaceState2D, from: Vector2, dir: Vector2, length: float, mask: int) -> Dictionary:
	var radius: float = Keeper3GameplaySettings.KUNAI_COLLISION_RADIUS
	var perp: Vector2 = Vector2( - dir.y, dir.x) * radius

	var from_a: Vector2 = from + perp
	var to_a: Vector2 = from_a + dir * length
	var from_b: Vector2 = from - perp
	var to_b: Vector2 = from_b + dir * length

	var rq_a: = PhysicsRayQueryParameters2D.new()
	rq_a.from = from_a
	rq_a.to = to_a
	rq_a.collision_mask = mask
	rq_a.collide_with_bodies = true
	rq_a.collide_with_areas = false
	rq_a.hit_from_inside = true

	var rq_b: = PhysicsRayQueryParameters2D.new()
	rq_b.from = from_b
	rq_b.to = to_b
	rq_b.collision_mask = mask
	rq_b.collide_with_bodies = true
	rq_b.collide_with_areas = false
	rq_b.hit_from_inside = true

	var hit_a: Dictionary = space.intersect_ray(rq_a)
	var hit_b: Dictionary = space.intersect_ray(rq_b)

	var best_hit: Dictionary = {}
	var best_t: float = INF

	for h in [hit_a, hit_b]:
		if h is Dictionary and h.size() > 0:
			var p: Vector2 = h.get("position", from)
			var t: float = (p - from).dot(dir)
			if t >= 0.0 and t <= length and t < best_t:
				best_t = t
				best_hit = h

	if best_hit.is_empty():
		return {"collided": false}

	var snap_pos: Vector2 = from + dir * best_t
	return {
		"collided": true, 
		"point": best_hit.get("position", snap_pos), 
		"normal": best_hit.get("normal", Vector2.ZERO), 
		"snap_position": snap_pos, 
		"distance": best_t
	}


func _can_bounce(velocity: Vector2, normal: Vector2, bounce_count: int) -> bool:
	if bounce_count >= Keeper3GameplaySettings.KUNAI_BOUNCE_MAX_COUNT:
		return false

	if normal.length_squared() < 0.0001:
		return false

	if velocity.length() < Keeper3GameplaySettings.KUNAI_MIN_BOUNCE_SPEED:
		return false

	var motion_dir: Vector2 = velocity.normalized()
	var normal_dir: Vector2 = normal.normalized()
	var dot: float = clampf( - motion_dir.dot(normal_dir), -1.0, 1.0)
	var incidence_angle: float = rad_to_deg(acos(dot))

	return incidence_angle >= Keeper3GameplaySettings.KUNAI_BOUNCE_MIN_ANGLE_DEGREES


func _update_hit_marker(world_pos: Vector2) -> void :
	hit_marker.global_position = world_pos
	hit_marker.width = HIT_WIDTH
	hit_marker.default_color = LINE_COLOR
	hit_marker.clear_points()
	hit_marker.add_point(Vector2( - HIT_SIZE, 0))
	hit_marker.add_point(Vector2(HIT_SIZE, 0))


func _update_bounce_markers(bounces: Array) -> void :
	while _bounce_markers.size() < bounces.size():
		var marker: Line2D = Line2D.new()
		marker.width = LINE_WIDTH
		marker.default_color = LINE_COLOR
		marker.antialiased = true
		bounces_container.add_child(marker)
		_bounce_markers.append(marker)

	for i in range(_bounce_markers.size()):
		var marker: Line2D = _bounce_markers[i]
		if i < bounces.size():
			var bounce: Dictionary = bounces[i]
			var point: Vector2 = bounce.point
			var incoming: Vector2 = bounce.incoming
			var outgoing: Vector2 = bounce.outgoing

			marker.global_position = point
			marker.clear_points()
			marker.add_point( - incoming * V_SIZE)
			marker.add_point(Vector2.ZERO)
			marker.add_point(outgoing * V_SIZE)
			marker.visible = true
		else:
			marker.visible = false
