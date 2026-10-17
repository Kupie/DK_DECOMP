extends Node2D

const Keeper4Script = preload("res://content/keeper/keeper4/Keeper4.gd")
const Tentacle = preload("res://content/keeper/keeper4/Tentacle.tscn")
const TENTACLE_COUNT: = 4
const REACH: = 65.0
const MIN_DIST: = 10
const PULL_FORCE: = 400.0
const PUSH_FORCE: = 400.0
const MIN_ATTACH_DIST_MULTIPLIER: = 2
const IDLE_DISTANCE: = 15.0
const FORCE_SMOOTH_SPEED: = 16.0
const FORCE_SMOOTH_SPEED_FAST: = 30.0
const INPUT_CHANGE_THRESHOLD: = 0.7

signal tentacle_attached(position: Vector2, collider: Node)
signal tentacle_detached(position: Vector2, collider: Node)

@export var speed_curve: Curve

var tentacles = []
var velocity: = Vector2.ZERO
var last_input_dir: = Vector2.ZERO
var keeper_move_speed: = 50.0

var grid_attach_enabled: = false
var is_spread_mode: = false
var is_actively_hitting: = false
var was_spread_mode: = false
var spread_redistributions: = 0
const MAX_SPREAD_REDISTRIBUTIONS: = 2

var mining_tentacles: Array = []
const MINING_TENTACLE_COUNT: = 2

const ATTACHMENT_STABILITY_DISTANCE: = 15.0
var stability_anchor_position: = Vector2.ZERO

func _ready():
	for i in range(TENTACLE_COUNT):
		var t = Tentacle.instantiate()
		tentacles.append(t)
		t.parent_tentacles = self
		$Center.add_child(t)
		t.attached.connect(_on_tentacle_attached)
		t.detached.connect(_on_tentacle_detached)

	$RayCast2D.target_position = Vector2(REACH, 0)

func set_speed_buildup(v: float):
	for t in tentacles:
		t.set_speed_buildup(v)

func _on_tentacle_attached(pos: Vector2, collider: Node):
	emit_signal("tentacle_attached", pos, collider)

func _on_tentacle_detached(pos: Vector2, collider: Node):
	emit_signal("tentacle_detached", pos, collider)

func apply_impulse(impulse: Vector2):
	velocity += impulse

func constrain_movement(desired_velocity: Vector2, delta: float) -> Vector2:
	if desired_velocity.length() < 0.1:
		return desired_velocity

	var constrained: Vector2 = desired_velocity
	var max_reach: float = REACH - Keeper4GameplaySettings.TENTACLE_LENGTH_CONSTRAINT_BUFFER

	for t in tentacles:
		if not t.is_grounded():
			continue
		var to_attachment: Vector2 = t.attachmentPoint - global_position
		var current_dist: float = to_attachment.length()
		if current_dist < max_reach * 0.8:
			continue
		var away_dir: Vector2 = - to_attachment.normalized()
		var movement_away: float = constrained.dot(away_dir)
		if movement_away > 0:
			var future_pos: Vector2 = global_position + constrained * delta
			var future_dist: float = future_pos.distance_to(t.attachmentPoint)
			if future_dist > max_reach:
				var allowed_dist: float = max_reach - current_dist
				var allowed_movement: float = max(0.0, allowed_dist / delta)
				if movement_away > allowed_movement:
					var excess: float = movement_away - allowed_movement
					constrained -= away_dir * excess
	return constrained

func check_and_detach_overstretched() -> void :
	for t in tentacles:
		if t.is_grounded():
			var dist: float = (t.attachmentPoint - global_position).length()
			if dist > REACH:
				t.detach()

func update_follow(input: Vector2, keeper_velocity: Vector2, delta: float, mining_tile = null, is_actively_mining: bool = false) -> void :
	keeper_move_speed = keeper_velocity.length() if keeper_velocity.length() > 10.0 else 50.0

	var is_stationary: bool = keeper_velocity.length() < 5.0 and input.length() < 0.1
	is_spread_mode = is_stationary or is_actively_mining
	$Center.position.y = move_toward($Center.position.y, 0.0, 0.1)
	is_actively_hitting = is_actively_mining

	if is_spread_mode and not was_spread_mode:
		spread_redistributions = 0
		stability_anchor_position = global_position
	was_spread_mode = is_spread_mode

	if input.length() > 0.1:
		last_input_dir = input.normalized()

	for t in tentacles:
		t.speed_curve = speed_curve
		t.move_speed_scale = Keeper4GameplaySettings.TENTACLE_MOVE_SPEED_SCALE

		if t.is_grounded():
			_process_attached_tentacle(t, input, keeper_velocity, delta, mining_tile)
		elif not t.is_attached():
			_process_detached_tentacle(t, input, mining_tile)

		if not t.is_attached():
			var idle_pos: Vector2 = _get_idle_quadrant_position(t)
			if idle_pos != Vector2.ZERO:
				t.set_idle_pos(idle_pos)

		t.current_force = Vector2.ZERO

func _process_attached_tentacle(t, input: Vector2, keeper_velocity: Vector2, delta: float, mining_tile) -> void :
	var dist_vec: Vector2 = t.attachmentPoint - global_position
	var dist: float = dist_vec.length()

	if dist > REACH and get_planted_count() > 1:
		t.detach()
		return

	if mining_tile != null and t.attachedTile == mining_tile and not is_actively_hitting:
		var has_other_grounded: bool = false
		for other in tentacles:
			if other != t and other.is_grounded() and other.attachedTile != mining_tile:
				has_other_grounded = true
				break
		if has_other_grounded:
			t.detach()
			return

	var within_stability_distance: bool = global_position.distance_to(stability_anchor_position) < ATTACHMENT_STABILITY_DISTANCE

	if is_spread_mode and t.can_detach() and not is_actively_hitting and spread_redistributions < MAX_SPREAD_REDISTRIBUTIONS and not within_stability_distance:
		var counts: Array[int] = _get_attached_quadrant_counts()
		var my_quadrant: int = _get_quadrant_index(dist_vec.angle())
		if counts[my_quadrant] > 1:
			var has_empty: bool = false
			for c in counts:
				if c == 0:
					has_empty = true
					break
			if has_empty and get_planted_count() > 1:
				spread_redistributions += 1
				t.detach()
				return
		return

	if is_actively_hitting:
		return

	if input.length() > 0.1 and t.can_detach():
		var input_dir: Vector2 = input.normalized()
		var dir_to_anchor: Vector2 = dist_vec.normalized()
		var dot: float = input_dir.dot(dir_to_anchor)
		var stretch_ratio: float = dist / REACH
		var is_stretched: bool = stretch_ratio > 0.75

		if within_stability_distance and not is_stretched:
			return

		if dot < -0.3:
			var should_detach: bool = false
			if dot < -0.85:
				should_detach = true
			elif dot < -0.7 and stretch_ratio > 0.3:
				should_detach = true
			elif stretch_ratio > 0.7 or (dot < -0.5 and stretch_ratio > 0.4):
				should_detach = true
			if should_detach and get_planted_count() > 1:
				t.detach()

func _process_detached_tentacle(t, input: Vector2, mining_tile) -> void :
	if is_actively_hitting:
		reattach_during_mining(t, mining_tile)
		return
	_try_attach_follow(t, input, mining_tile)

func _try_attach_follow(t, input: Vector2, mining_tile) -> bool:
	var all_detached: bool = get_planted_count() == 0
	var effective_dir: Vector2 = input if input.length() > 0.1 else last_input_dir

	if is_spread_mode:
		var empty_angles: Array[float] = _get_empty_quadrant_angles()
		if not empty_angles.is_empty():
			for angle in empty_angles:
				if _do_raycast_attach_follow(t, angle, mining_tile):
					return true
				for offset in [0.2, -0.2, 0.4, -0.4]:
					if _do_raycast_attach_follow(t, angle + offset, mining_tile):
						return true

	if effective_dir.length() > 0.1:
		if _do_raycast_attach_follow(t, effective_dir.angle(), mining_tile):
			return true

		for offset in [0.3, -0.3, 0.6, -0.6]:
			if _do_raycast_attach_follow(t, effective_dir.angle() + offset, mining_tile):
				return true

		for _i in range(3):
			var wide_angle: float = effective_dir.angle() + randf_range(-1.5, 1.5)
			if _do_raycast_attach_follow(t, wide_angle, mining_tile):
				return true

	if all_detached or is_spread_mode:
		if _do_raycast_attach_follow(t, randf() * PI * 2, mining_tile):
			return true

	if not grid_attach_enabled:
		return false
	return _do_grid_attach(t, effective_dir.angle() if effective_dir.length() > 0.1 else randf() * PI * 2)

func _do_grid_attach(t, angle: float) -> bool:
	var tile_size: float = GameWorld.TILE_SIZE
	var target_pos: Vector2 = global_position + Vector2.from_angle(angle) * REACH
	var snapped: Vector2 = target_pos.snapped(Vector2(tile_size * 0.5, tile_size * 0.5))
	var perp: Vector2 = Vector2(absf(last_input_dir.y), absf(last_input_dir.x))
	var rand_scale: Vector2 = Vector2(8.0, 8.0) + perp * 20.0
	snapped += Vector2(randf() * rand_scale.x, randf() * rand_scale.y)

	var dist_to_body: float = snapped.distance_to(global_position)
	if dist_to_body < MIN_DIST * MIN_ATTACH_DIST_MULTIPLIER or dist_to_body > REACH:
		return false

	$RayCast2D.rotation = (snapped - global_position).angle()
	$RayCast2D.force_raycast_update()
	if $RayCast2D.is_colliding() and $RayCast2D.get_collision_point().distance_to(global_position) < dist_to_body - tile_size * 0.5:
		return false

	for other in tentacles:
		if other != t and (other.is_grounded() or other.is_attached()):
			if other.attachmentPoint.distance_to(snapped) < MIN_DIST:
				return false

	var dummy: = Node2D.new()
	dummy.set_meta("grid_dummy", true)
	add_child(dummy)
	dummy.global_position = snapped
	t.detached.connect( func(_pos, _col): dummy.queue_free(), CONNECT_ONE_SHOT)
	t.attach_to(dummy, snapped, t.get_claw_pos())
	return true

func _do_raycast_attach_follow(t, angle: float, mining_tile) -> bool:
	$RayCast2D.rotation = angle
	$RayCast2D.force_raycast_update()

	if $RayCast2D.is_colliding():
		var point: Vector2 = $RayCast2D.get_collision_point()
		var tile = $RayCast2D.get_collider()

		if mining_tile != null and tile == mining_tile:
			return false

		var too_close: bool = false
		for other in tentacles:
			if other != t and (other.is_grounded() or other.is_attached()):
				if other.attachmentPoint.distance_to(point) < MIN_DIST:
					too_close = true
					break

		var dist_to_body: float = point.distance_to(global_position)
		if dist_to_body < MIN_DIST * MIN_ATTACH_DIST_MULTIPLIER:
			return false

		var all_detached: bool = get_planted_count() == 0
		if not all_detached and not is_spread_mode and velocity.length() > 5.0:
			var to_point: Vector2 = (point - global_position).normalized()
			var vel_dir: Vector2 = velocity.normalized()
			if to_point.dot(vel_dir) < 0.3:
				return false

		if not too_close:
			var start_pos: Vector2 = t.get_claw_pos()
			var normal: Vector2 = $RayCast2D.get_collision_normal()
			t.attach_to(tile, point, start_pos, normal)
			return true

	return false

func force_attach_all(mining_tile, mining_direction: Vector2 = Vector2.ZERO) -> void :
	var has_mining_dir: bool = mining_direction.length() > 0.1
	var mining_angle: float = mining_direction.angle() if has_mining_dir else 0.0

	var side_multiplier: int = 1
	for t in tentacles:
		if t.is_attached():
			continue

		var attached: = false

		if has_mining_dir:
			var perp_angle: float = mining_angle + (PI / 2.0) * side_multiplier
			attached = _try_attach_around_angle(t, perp_angle, mining_tile)

			if not attached:
				attached = _try_attach_around_angle(t, perp_angle + 0.5 * side_multiplier, mining_tile)
			if not attached:
				attached = _try_attach_around_angle(t, perp_angle - 0.5 * side_multiplier, mining_tile)

			if not attached:
				var back_angle: float = mining_angle + PI
				attached = _try_attach_around_angle(t, back_angle, mining_tile)

			if not attached:
				for i in range(16):
					var angle: float = i * TAU / 16.0
					if _do_raycast_attach_force(t, angle, mining_tile):
						attached = true
						break

			side_multiplier *= -1

		if not attached:
			for i in range(16):
				var angle: float = i * TAU / 16.0
				if _do_raycast_attach_force(t, angle, null):
					break

func _do_raycast_attach_force(t, angle: float, mining_tile) -> bool:
	$RayCast2D.rotation = angle
	$RayCast2D.force_raycast_update()

	if $RayCast2D.is_colliding():
		var point: Vector2 = $RayCast2D.get_collision_point()
		var tile = $RayCast2D.get_collider()

		if mining_tile != null and tile == mining_tile:
			return false

		var too_close: bool = false
		for other in tentacles:
			if other != t and (other.is_grounded() or other.is_attached()):
				if other.attachmentPoint.distance_to(point) < MIN_DIST:
					too_close = true
					break

		var dist_to_body: float = point.distance_to(global_position)
		if dist_to_body < MIN_DIST * MIN_ATTACH_DIST_MULTIPLIER:
			return false

		if not too_close:
			var start_pos: Vector2 = t.get_claw_pos()
			var normal: Vector2 = $RayCast2D.get_collision_normal()
			t.attach_to(tile, point, start_pos, normal)
			return true

	return false

func _try_attach_around_angle(t, center_angle: float, mining_tile) -> bool:
	for offset in [0.0, 0.15, -0.15, 0.3, -0.3, 0.45, -0.45]:
		if _do_raycast_attach_force(t, center_angle + offset, mining_tile):
			return true
	return false

func force_attach_all_to_tile(tile) -> void :
	for t in tentacles:
		if t.is_attached():
			continue
		for i in range(16):
			var angle: float = i * TAU / 16.0
			if _do_raycast_attach_to_tile(t, angle, tile):
				break

func _do_raycast_attach_to_tile(t, angle: float, target_tile) -> bool:
	$RayCast2D.rotation = angle
	$RayCast2D.force_raycast_update()

	if $RayCast2D.is_colliding():
		var point: Vector2 = $RayCast2D.get_collision_point()
		var tile = $RayCast2D.get_collider()

		if tile != target_tile:
			return false

		var too_close: bool = false
		for other in tentacles:
			if other != t and (other.is_grounded() or other.is_attached()):
				if other.attachmentPoint.distance_to(point) < MIN_DIST:
					too_close = true
					break

		if not too_close:
			var start_pos: Vector2 = t.get_claw_pos()
			var normal: Vector2 = $RayCast2D.get_collision_normal()
			t.attach_to(tile, point, start_pos, normal)
			return true

	return false

func reattach_during_mining(t, mining_tile) -> bool:

	var mining_dir: Vector2 = mining_tile.global_position - global_position
	if mining_dir.length() < 0.1:
		return false

	var mining_angle: float = mining_dir.angle()

	var side_multiplier: int = _get_preferred_side_for_reattach(t, mining_angle)

	var perp_angle: float = mining_angle + (PI / 2.0) * side_multiplier
	if _try_attach_around_angle(t, perp_angle, mining_tile):
		return true

	if _try_attach_around_angle(t, perp_angle + 0.5 * side_multiplier, mining_tile):
		return true
	if _try_attach_around_angle(t, perp_angle - 0.5 * side_multiplier, mining_tile):
		return true

	var back_angle: float = mining_angle + PI
	if _try_attach_around_angle(t, back_angle, mining_tile):
		return true

	for i in range(16):
		var angle: float = i * TAU / 16.0
		if _do_raycast_attach_force(t, angle, mining_tile):
			return true

	for i in range(16):
		var angle: float = i * TAU / 16.0
		if _do_raycast_attach_force(t, angle, null):
			return true

	return false

func _get_preferred_side_for_reattach(t, mining_angle: float) -> int:
	var left_count: int = 0
	var right_count: int = 0
	var left_angle: float = mining_angle + PI / 2.0
	var right_angle: float = mining_angle - PI / 2.0

	for other in tentacles:
		if other == t or not other.is_grounded():
			continue
		var to_attach: Vector2 = other.attachmentPoint - global_position
		var attach_angle: float = to_attach.angle()
		var diff_left: float = abs(wrapf(attach_angle - left_angle, - PI, PI))
		var diff_right: float = abs(wrapf(attach_angle - right_angle, - PI, PI))
		if diff_left < diff_right:
			left_count += 1
		else:
			right_count += 1

	if left_count < right_count:
		return 1
	elif right_count < left_count:
		return -1
	return 1

func _get_idle_quadrant_position(tentacle) -> Vector2:
	var quadrants: Array[float] = [-3.0 * PI / 4.0, - PI / 4.0, 3.0 * PI / 4.0, PI / 4.0]

	var time: float = Time.get_ticks_msec() * 0.002
	var breathe: float = cos(time * 0.5 + tentacles.find(tentacle)) * 3.0
	var best_pos: Vector2 = Vector2.ZERO
	var best_score: float = - INF
	var current_pos: Vector2 = tentacle.get_claw_pos()
	var all_detached: bool = is_all_detached()
	var vel_dir: Vector2 = velocity.normalized() if velocity.length() > 10.0 else Vector2.ZERO

	for q_angle in quadrants:
		var occupied: bool = false
		for other in tentacles:
			if other != tentacle and not other.is_attached():
				var other_dir: Vector2 = (other.get_claw_pos() - global_position)
				if other_dir.length() > 0.001 and other_dir.length() < IDLE_DISTANCE * 2.0:
					if abs(angle_difference(other_dir.angle(), q_angle)) < PI / 4.0:
						occupied = true
						break

		var is_top: bool = q_angle < 0.0
		var dist: float = current_pos.distance_to(global_position + Vector2(IDLE_DISTANCE, 0).rotated(q_angle))
		var score: float = (1000.0 if is_top else 0.0) - dist
		if all_detached and vel_dir.length() > 0.1:
			var quadrant_dir: Vector2 = Vector2.RIGHT.rotated(q_angle)
			score += quadrant_dir.dot(vel_dir) * velocity.length() * 80.0

		if occupied:
			score -= 5000.0

		if score > best_score:
			best_score = score
			best_pos = global_position + Vector2(IDLE_DISTANCE + breathe, 0).rotated(q_angle)

	return best_pos

func angle_difference(a1: float, a2: float) -> float:
	return wrapf(a1 - a2, - PI, PI)

func _get_quadrant_index(angle: float) -> int:
	var normalized_angle: float = wrapf(angle, - PI, PI)
	if normalized_angle < - PI / 2.0:
		return 0
	elif normalized_angle < 0.0:
		return 1
	elif normalized_angle < PI / 2.0:
		return 3
	else:
		return 2

func _get_attached_quadrant_counts() -> Array[int]:
	var counts: Array[int] = [0, 0, 0, 0]
	for t in tentacles:
		if t.is_grounded():
			var dir: Vector2 = t.attachmentPoint - global_position
			if dir.length() > 0.001:
				var q: int = _get_quadrant_index(dir.angle())
				counts[q] += 1
	return counts

func _get_empty_quadrant_angles() -> Array[float]:
	var quadrant_angles: Array[float] = [-3.0 * PI / 4.0, - PI / 4.0, 3.0 * PI / 4.0, PI / 4.0]
	var counts: Array[int] = _get_attached_quadrant_counts()
	var empty_angles: Array[float] = []
	for i in range(4):
		if counts[i] == 0:
			empty_angles.append(quadrant_angles[i])
	return empty_angles

func is_attached():
	for t in tentacles:
		if t.is_grounded():
			return true
	return false


func get_planted_count():
	var c = 0
	for t in tentacles:
		if t.is_grounded():
			c += 1
	return c

func is_all_detached() -> bool:
	for t in tentacles:
		if t.is_attached():
			return false
	return true

func get_front_tentacle_pull(input_dir: Vector2) -> Vector2:
	var pull_direction: = Vector2.ZERO
	var front_count: = 0

	for t in tentacles:
		if t.is_grounded():
			var to_attachment = t.attachmentPoint - global_position
			var proj = to_attachment.dot(input_dir)
			if proj > 0.0:
				pull_direction += to_attachment.normalized()
				front_count += 1

	if front_count > 0:
		pull_direction /= front_count

	return pull_direction

func clear_mining_tentacles() -> void :
	for t in mining_tentacles:
		t.set_mining_mode(false)
	mining_tentacles.clear()

func assign_initial_mining_tentacles(mining_tile) -> void :
	var is_carrying: = false
	var scored: Array = []
	for t in tentacles:
		if t.is_carrying():
			is_carrying = true
			continue
		var score: float = t.get_claw_pos().distance_to(mining_tile.global_position)
		if t.is_grounded() and t.attachedTile != mining_tile:
			score += 1000.0
		scored.append({"tentacle": t, "score": score})

	scored.sort_custom( func(a, b): return a.score < b.score)

	var tentacle_count: int = 1 if is_carrying else MINING_TENTACLE_COUNT
	mining_tentacles.clear()
	for i in range(min(tentacle_count, scored.size())):
		var t = scored[i].tentacle
		t.side = -1 if i == 0 else 1
		t.set_mining_mode(true, mining_tile)
		mining_tentacles.append(t)

func get_mining_tentacles() -> Array:
	return mining_tentacles

func has_mining_tentacles() -> bool:
	return not mining_tentacles.is_empty()

func update_mining_target(mining_tile) -> void :
	for t in mining_tentacles:
		t.update_mining_target(mining_tile)

func get_available_carrying_tentacle():
	for t in tentacles:
		if t.can_carry():
			return t
	return null

func get_carrying_tentacle():
	for t in tentacles:
		if t.is_carrying():
			return t
	return null

func get_farthest_available_tentacle(target_pos: Vector2):
	var farthest = null
	var max_dist: = -1.0
	for t in tentacles:
		if t.can_carry():
			var dist: float = t.get_claw_pos().distance_squared_to(target_pos)
			if dist > max_dist:
				max_dist = dist
				farthest = t
	return farthest

func set_color(color_id: String, remap_color_palette: bool):
	for tentacle in tentacles:
		tentacle.set_color(color_id, remap_color_palette)
