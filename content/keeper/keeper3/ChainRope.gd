extends Node2D

class_name ChainRope

signal rope_ready(ball)
signal rope_finished
signal rope_detached

class VerletPoint:
	var position: Vector2
	var previous_position: Vector2
	var inv_mass: float
	var pinned_node: Node2D

	func _init(pos: Vector2, inv_mass_value: float, pinned: Node2D = null) -> void :
		position = pos
		previous_position = pos
		inv_mass = inv_mass_value
		pinned_node = pinned

	func is_pinned() -> bool:
		return pinned_node != null

	func set_position(pos: Vector2) -> void :
		position = pos
		previous_position = pos

var keeper: Keeper
var carry_owner: Node2D
var hook: HookKunai
var hook_anchor: Node2D
var spawn_pivot: Node2D
var rope_ball
var retraction_speed: float = Keeper3SecondarySettings.CHAIN_RETRACTION_SPEED_DEFAULT
var visual_return_speed: float = Keeper3SecondarySettings.CHAIN_VISUAL_RETURN_SPEED
var carried_body: Node2D
var _usage: int = Keeper3SecondarySettings.CHAIN_USAGE_HOOK
var _carry_link_count: int = Keeper3SecondarySettings.CARRY_CHAIN_LINK_COUNT
var _carry_rest_length: float = Keeper3SecondarySettings.CARRY_FOLLOW_REST_DISTANCE
var _carry_anchor: Node2D
var _base_pin_override: Node2D
var _tip_pin_override: Node2D
var _base_inv_mass_override: float = -1.0
var _tip_inv_mass_override: float = -1.0

var _points: Array[VerletPoint] = []
var _visual_links: Array[Node2D] = []
var _curve: = Curve2D.new()
var _unique_positions: Array[Vector2] = []
var _target_length: float = 0.0
var _last_base_position: Vector2 = Vector2.ZERO
var _active: bool = false
var _retracting: bool = false
var _cleaning_up: bool = false
var _mode: int = Keeper3SecondarySettings.CHAIN_MODE_TRAVEL
var _gravity_vector: Vector2 = Vector2.ZERO
var _gravity_enabled: bool = false
var _retraction_timer: SceneTreeTimer
var _retraction_timer_callable: Callable
var _retraction_completed: bool = false
var _base_override_pending: bool = false
var _base_override_position: Vector2 = Vector2.ZERO
var _base_override_velocity: Vector2 = Vector2.ZERO
var _base_override_delta: float = 0.0
var _base_released: bool = false
var _segment_rest_length: float = Keeper3SecondarySettings.CHAIN_LINK_LENGTH
var _visual_return_active: bool = false
var _detached_emitted: bool = false
var _visual_tip: Node2D
var _max_distance_triggered: bool = false
var _hang_length_locked: bool = false
var _stiff_mode: bool = false

func _ready() -> void :
	material = Style.spriteShader

func set_stiff_mode(enabled: bool) -> void :
	_stiff_mode = enabled

func setup_for_travel(new_keeper: Keeper, new_hook: HookKunai, pivot: Node2D) -> void :
	_usage = Keeper3SecondarySettings.CHAIN_USAGE_HOOK
	keeper = new_keeper
	hook = new_hook
	hook_anchor = null
	spawn_pivot = pivot
	if not is_instance_valid(keeper) or not is_instance_valid(hook):
		queue_free()
		return
	if hook.has_method("get_chain_anchor_node"):
		var anchor_node: = hook.get_chain_anchor_node()
		if anchor_node is Node2D:
			hook_anchor = anchor_node
	_cleanup_chain()
	rope_ball = Keeper3SecondarySettings.CHAIN_ATTACHMENT_SCRIPT.new()
	rope_ball.rope = self
	rope_ball.global_position = _get_spawn_position()
	rope_ball.linear_velocity = Vector2.ZERO
	rope_ball.angular_velocity = 0.0
	add_child(rope_ball)
	var start_pos: Vector2 = _get_spawn_position()
	var end_pos: Vector2 = _get_hook_anchor_position()
	var desired_links: int = _calculate_desired_link_count(start_pos, end_pos)
	_target_length = Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(desired_links)
	_build_points(start_pos, end_pos, desired_links)
	_last_base_position = start_pos
	_active = true
	_retracting = false
	_hang_length_locked = false
	_mode = Keeper3SecondarySettings.CHAIN_MODE_TRAVEL
	_cleaning_up = false
	_gravity_enabled = false
	_gravity_vector = _resolve_gravity_vector()
	_retraction_completed = false
	_visual_return_active = false
	_detached_emitted = false
	_max_distance_triggered = false
	_base_override_pending = false
	_base_override_position = Vector2.ZERO
	_base_override_velocity = Vector2.ZERO
	_base_override_delta = 0.0
	_base_released = false
	_clear_retraction_timer()
	set_physics_process(true)

func setup_for_carry(newcarry_owner: Node2D, new_carried_body: Node2D, anchor_override: Node2D = null, rest_distance: float = Keeper3SecondarySettings.CARRY_FOLLOW_REST_DISTANCE) -> void :
	_usage = Keeper3SecondarySettings.CHAIN_USAGE_CARRY
	carry_owner = newcarry_owner
	var carry_node: Node2D = new_carried_body if new_carried_body is Node2D else null
	hook = null
	hook_anchor = null
	spawn_pivot = null
	var requested_anchor: Node2D = anchor_override
	if not is_instance_valid(carry_owner) or not is_instance_valid(carry_node):
		queue_free()
		return
	_cleanup_chain()
	carried_body = carry_node
	_carry_anchor = requested_anchor
	var anchor_node: = _resolve_carry_anchor_node()
	_configure_carry_rest_length(rest_distance)
	_base_pin_override = anchor_node
	_tip_pin_override = carry_node
	_base_inv_mass_override = Keeper3SecondarySettings.CARRY_CHAIN_BASE_INV_MASS
	_tip_inv_mass_override = 0.0
	var base_pos: Vector2 = _resolve_carry_anchor_position()
	var tip_pos: Vector2 = carry_node.global_position
	rope_ball = Keeper3SecondarySettings.CHAIN_ATTACHMENT_SCRIPT.new()
	rope_ball.rope = self
	rope_ball.global_position = base_pos
	rope_ball.linear_velocity = Vector2.ZERO
	rope_ball.angular_velocity = 0.0
	add_child(rope_ball)
	_target_length = _carry_rest_length
	_build_points(base_pos, tip_pos, _carry_link_count)
	_last_base_position = base_pos
	_refresh_carry_anchor_pin()
	_active = true
	_retracting = false
	_cleaning_up = false
	_mode = Keeper3SecondarySettings.CHAIN_MODE_TRAVEL
	_gravity_vector = _resolve_gravity_vector()
	_gravity_enabled = true
	_base_override_pending = false
	_base_override_position = Vector2.ZERO
	_base_override_velocity = Vector2.ZERO
	_base_override_delta = 0.0
	_base_released = false
	_retraction_completed = false
	_visual_return_active = false
	_detached_emitted = false
	_max_distance_triggered = false
	_clear_retraction_timer()
	set_physics_process(true)

func _configure_carry_rest_length(rest_length: float, adjust_existing: bool = false) -> void :
	var desired_length: float = maxf(rest_length, Keeper3SecondarySettings.CARRY_CHAIN_LINK_LENGTH)
	var desired_links: int = int(ceil(desired_length / Keeper3SecondarySettings.CARRY_CHAIN_LINK_LENGTH))
	desired_links = clampi(desired_links, Keeper3SecondarySettings.CHAIN_MIN_LINKS, Keeper3SecondarySettings.CHAIN_MAX_LINKS)
	_carry_rest_length = desired_length
	_carry_link_count = desired_links
	_target_length = desired_length
	if adjust_existing and not _points.is_empty():
		_ensure_link_count(_carry_link_count, true)
		_update_segment_rest_length()

func update_carry_anchor(anchor_override: Node2D, rest_distance: float = -1.0) -> void :
	if _usage != Keeper3SecondarySettings.CHAIN_USAGE_CARRY:
		return
	_carry_anchor = anchor_override
	_refresh_carry_anchor_pin()
	if rest_distance > 0.0:
		_configure_carry_rest_length(rest_distance, true)

func start_retraction(delay: float = Keeper3SecondarySettings.CHAIN_RETRACTION_DELAY_DEFAULT) -> void :
	if not _active:
		return
	if delay > 0.0:
		_schedule_retraction(delay)
	else:
		_begin_retraction()

func begin_detach() -> void :
	if _usage == Keeper3SecondarySettings.CHAIN_USAGE_CARRY:
		_emit_detach()
		_cleanup_chain()
		if not is_queued_for_deletion():
			queue_free()
		return
	if _visual_return_active or _cleaning_up:
		return
	_cleaning_up = true
	_start_visual_return()

func _start_visual_return() -> void :
	_clear_retraction_timer()
	_mode = Keeper3SecondarySettings.CHAIN_MODE_RETRACT
	_active = false
	_retracting = false
	_gravity_enabled = false
	_base_override_pending = false
	_visual_return_active = true
	_create_visual_tip_from_hook()
	_re_pin_base_for_return()
	if not _points.is_empty():
		_last_base_position = _points[0].position
	_release_hook_point_for_return()
	_emit_detach()
	if is_instance_valid(rope_ball):
		rope_ball.queue_free()
		rope_ball = null
	hook = null
	hook_anchor = null
	set_physics_process(true)
	if _points.size() <= 1:
		_finish_visual_return()

func _release_hook_point_for_return() -> void :
	if _points.size() < 2:
		return
	for i in range(1, _points.size()):
		var point: VerletPoint = _points[i]
		point.pinned_node = null
		if point.inv_mass <= 0.0:
			point.inv_mass = 1.0
		point.previous_position = point.position

func _re_pin_base_for_return() -> void :
	if _points.is_empty():
		return
	var base_point: VerletPoint = _points[0]
	var base_pin: Node2D = _get_base_pin_node()
	if is_instance_valid(base_pin):
		base_point.pinned_node = base_pin
		base_point.inv_mass = 0.0
		base_point.set_position(base_pin.global_position)
	elif is_instance_valid(keeper):
		base_point.pinned_node = keeper
		base_point.inv_mass = 0.0
		base_point.set_position(keeper.global_position)
	else:
		base_point.pinned_node = null
		if base_point.inv_mass == 0.0:
			base_point.inv_mass = 1.0
		base_point.previous_position = base_point.position

func _create_visual_tip_from_hook() -> void :
	if _visual_tip != null and is_instance_valid(_visual_tip):
		return
	if not is_instance_valid(hook):
		return
	var sprite_node: = hook.get_node_or_null("KunaiSprite")
	if sprite_node == null or not (sprite_node is Node2D):
		return
	var sprite_ref: Node2D = sprite_node
	var duplicated: = sprite_ref.duplicate()
	if duplicated == null or not (duplicated is Node2D):
		return
	_visual_tip = duplicated
	add_child(_visual_tip)
	var tip_node: Node2D = _visual_tip
	tip_node.global_position = sprite_ref.global_position
	tip_node.global_rotation = sprite_ref.global_rotation
	tip_node.visible = sprite_ref.visible
	tip_node.scale = sprite_ref.scale
	tip_node.skew = sprite_ref.skew
	tip_node.z_index = sprite_ref.z_index

func get_base_position() -> Vector2:
	if _points.is_empty():
		return _get_spawn_position()
	return _points[0].position

func get_anchor_position() -> Vector2:
	if _points.is_empty():
		return _get_spawn_position()
	return _points[_points.size() - 1].position

func adjust_hang_length(direction: int) -> bool:
	var length_changed: = false
	if direction < 0:
		_retracting = true
		_hang_length_locked = true
		var min_length: float = Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(Keeper3SecondarySettings.CHAIN_MIN_LINKS)
		var old_length: float = _target_length
		var new_length: float = maxf(old_length - Keeper3GameplaySettings.CHAIN_HANG_CLIMB_SPEED * get_physics_process_delta_time(), min_length)
		length_changed = not is_equal_approx(new_length, old_length)
		_target_length = new_length
	elif direction > 0:
		_retracting = false
		_hang_length_locked = true
		var max_length: float = Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(Keeper3SecondarySettings.CHAIN_MAX_LINKS)
		var old_length: float = _target_length
		var new_length: float = minf(old_length + Keeper3GameplaySettings.CHAIN_HANG_EXTEND_SPEED * get_physics_process_delta_time(), max_length)
		length_changed = not is_equal_approx(new_length, old_length)
		_target_length = new_length
	else:
		_retracting = false
	return length_changed

func lock_hang_length(target_length: float) -> bool:
	var min_length: float = Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(Keeper3SecondarySettings.CHAIN_MIN_LINKS)
	var max_length: float = Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(Keeper3SecondarySettings.CHAIN_MAX_LINKS)
	var clamped_length: float = clampf(target_length, min_length, max_length)
	var length_changed: = not is_equal_approx(clamped_length, _target_length)
	_target_length = clamped_length
	_hang_length_locked = true
	_retracting = false
	return length_changed

func get_target_length() -> float:
	return _target_length

func set_base_override(pos: Vector2, velocity: Vector2, delta: float) -> void :
	_base_override_position = pos
	_base_override_velocity = velocity
	_base_override_delta = delta
	_base_override_pending = true
	_apply_base_override_immediate()

func _apply_base_override_immediate() -> void :
	if _points.is_empty():
		return
	var base_point: VerletPoint = _points[0]
	base_point.position = _base_override_position
	var backstep: Vector2 = _velocity_to_backstep(_base_override_velocity, _base_override_delta)
	base_point.previous_position = base_point.position - backstep
	if is_instance_valid(rope_ball):
		rope_ball.global_position = base_point.position
		if _base_override_delta > 0.0:
			rope_ball.linear_velocity = _base_override_velocity
		else:
			rope_ball.linear_velocity = Vector2.ZERO
		rope_ball.angular_velocity = 0.0
	_stabilize_after_base_override(base_point)

func _stabilize_after_base_override(base_point: VerletPoint) -> void :
	var point_count: int = _points.size()
	if point_count < 2:
		return
	var original_inv_mass: float = base_point.inv_mass
	base_point.inv_mass = 0.0
	base_point.position = _base_override_position
	_apply_pin_positions()
	var relax_iterations: int = Keeper3SecondarySettings.CHAIN_SOLVER_ITERATIONS
	for _i in range(relax_iterations):
		for j in range(point_count - 1):
			_constrain_segment(j, j + 1)
	base_point.position = _base_override_position
	base_point.inv_mass = original_inv_mass
	_update_visual_links()

func _apply_base_override() -> void :
	if not _base_override_pending or _points.is_empty():
		return
	var base_point: VerletPoint = _points[0]
	base_point.position = _base_override_position
	var backstep: Vector2 = _velocity_to_backstep(_base_override_velocity, _base_override_delta)
	base_point.previous_position = base_point.position - backstep
	_last_base_position = base_point.position
	_base_override_pending = false
	_base_override_position = Vector2.ZERO
	_base_override_velocity = Vector2.ZERO
	_base_override_delta = 0.0

func _velocity_to_backstep(velocity: Vector2, delta: float) -> Vector2:
	if delta <= 0.0:
		return Vector2.ZERO
	return velocity * delta

func _schedule_retraction(delay: float) -> void :
	_clear_retraction_timer()
	_retraction_timer = get_tree().create_timer(delay)
	if _retraction_timer:
		_retraction_timer_callable = Callable(self, "_on_retraction_timer_timeout")
		_retraction_timer.timeout.connect(_retraction_timer_callable)

func _on_retraction_timer_timeout() -> void :
	if GameWorld.paused:
		return
	_retraction_timer = null
	_retraction_timer_callable = Callable()
	_begin_retraction()

func _begin_retraction() -> void :
	if not _active or _mode == Keeper3SecondarySettings.CHAIN_MODE_RETRACT and _retracting:
		return
	_clear_retraction_timer()
	_mode = Keeper3SecondarySettings.CHAIN_MODE_RETRACT
	_retracting = true
	_hang_length_locked = false
	_retraction_completed = false
	_release_base_point()
	_target_length = Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(max(Keeper3SecondarySettings.CHAIN_MIN_LINKS, _current_link_count()))
	if is_instance_valid(rope_ball):
		rope_ball.sleeping = false
		emit_signal("rope_ready", rope_ball)
	_gravity_enabled = true

func _release_base_point() -> void :
	if _points.is_empty():
		return
	var base_point: VerletPoint = _points[0]
	if base_point.pinned_node != null:
		base_point.pinned_node = null
		base_point.inv_mass = Keeper3SecondarySettings.CHAIN_KEEPER_INV_MASS
		base_point.previous_position = base_point.position
		_base_released = true
	_last_base_position = base_point.position

func _physics_process(delta: float) -> void :
	if GameWorld.paused:
		return
	if _visual_return_active:
		_process_visual_return(delta)
		return
	if not _active:
		return
	match _usage:
		Keeper3SecondarySettings.CHAIN_USAGE_CARRY:
			_process_carry_usage(delta)
		_:
			_process_hook_usage(delta)

func _process_hook_usage(delta: float) -> void :
	if not is_instance_valid(hook):
		begin_detach()
		return
	if _points.size() < 2:
		return
	_apply_base_override()
	_apply_pin_positions()
	var base_position: Vector2 = _points[0].position
	var hook_position: Vector2 = _get_hook_anchor_position()
	var desired_links: int
	var distance: float = base_position.distance_to(hook_position)
	if _mode == Keeper3SecondarySettings.CHAIN_MODE_TRAVEL and not _max_distance_triggered and distance >= Keeper3SecondarySettings.CHAIN_MAX_TRAVEL_DISTANCE:
		_handle_max_distance_reached()
		return
	if _mode == Keeper3SecondarySettings.CHAIN_MODE_TRAVEL:
		desired_links = _calculate_desired_link_count(base_position, hook_position)
		_target_length = Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(desired_links)
		_ensure_link_count(desired_links)
	else:
		if _hang_length_locked:
			var desired_links_hang: int = clampi(ceili(_target_length / Keeper3SecondarySettings.CHAIN_LINK_LENGTH), Keeper3SecondarySettings.CHAIN_MIN_LINKS, Keeper3SecondarySettings.CHAIN_MAX_LINKS)
			_ensure_link_count(desired_links_hang, true)
		elif _retracting:
			var min_length: float = maxf(Keeper3SecondarySettings.CHAIN_RETRACTION_STOP_DISTANCE, Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(Keeper3SecondarySettings.CHAIN_MIN_LINKS))
			_target_length = maxf(min_length, _target_length - retraction_speed * delta)
			var max_links: int = max(Keeper3SecondarySettings.CHAIN_MIN_LINKS, _current_link_count())
			desired_links = clampi(ceili(_target_length / Keeper3SecondarySettings.CHAIN_LINK_LENGTH), Keeper3SecondarySettings.CHAIN_MIN_LINKS, max_links)
			_ensure_link_count(desired_links, false)
		else:
			_target_length = maxf(max(distance, Keeper3SecondarySettings.CHAIN_RETRACTION_STOP_DISTANCE), Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(Keeper3SecondarySettings.CHAIN_MIN_LINKS))
			var max_links: int = max(Keeper3SecondarySettings.CHAIN_MIN_LINKS, _current_link_count())
			desired_links = clampi(ceili(_target_length / Keeper3SecondarySettings.CHAIN_LINK_LENGTH), Keeper3SecondarySettings.CHAIN_MIN_LINKS, max_links)
			_ensure_link_count(desired_links, false)
	_update_segment_rest_length()
	_simulate_points(delta)
	_satisfy_constraints()
	if _stiff_mode:
		_straighten_chain()
	_update_rope_ball(delta)
	_update_visual_links()
	if _mode == Keeper3SecondarySettings.CHAIN_MODE_RETRACT:
		_handle_retraction_completion()

func _process_carry_usage(delta: float) -> void :
	if not is_instance_valid(carry_owner) or not is_instance_valid(carried_body):
		_emit_detach()
		_cleanup_chain()
		if not is_queued_for_deletion():
			queue_free()
		return
	if _points.size() < 2:
		return
	_apply_pin_positions()
	_ensure_link_count(_carry_link_count, false)
	_update_segment_rest_length()
	_simulate_points(delta)
	_satisfy_constraints()
	_update_rope_ball(delta)
	_update_visual_links()


func _resolve_carry_anchor_node() -> Node2D:
	if is_instance_valid(_carry_anchor):
		return _carry_anchor
	if is_instance_valid(carry_owner):
		if carry_owner.has_method("getChainSpawnNode"):
			var anchor_candidate: Node2D = carry_owner.getChainSpawnNode()
			if anchor_candidate is Node2D:
				_carry_anchor = anchor_candidate
				return _carry_anchor
		_carry_anchor = carry_owner
		return _carry_anchor
	return null

func _resolve_carry_anchor_position() -> Vector2:
	var anchor_node: = _resolve_carry_anchor_node()
	if is_instance_valid(anchor_node):
		return anchor_node.global_position
	if is_instance_valid(carry_owner):
		return carry_owner.global_position
	return global_position

func _current_link_count() -> int:
	return max(_points.size() - 1, 0)

func _build_points(start_pos: Vector2, end_pos: Vector2, link_count: int) -> void :
	_points.clear()
	var base_pin: Node2D = _base_pin_override if _base_pin_override else _get_base_pin_node()
	var base_inv_mass: float
	if _base_inv_mass_override >= 0.0:
		base_inv_mass = _base_inv_mass_override
	else:
		base_inv_mass = 0.0 if base_pin else 1.0
	var base_point: = VerletPoint.new(start_pos, base_inv_mass, base_pin)
	_points.append(base_point)
	if link_count <= 1:
		link_count = 1
	for i in range(1, link_count):
		var t: float = float(i) / float(link_count)
		var point_pos: Vector2 = start_pos.lerp(end_pos, t)
		var point: = VerletPoint.new(point_pos, 1.0)
		_points.append(point)
	var hook_node: = _tip_pin_override if _tip_pin_override else _get_hook_anchor_node()
	var hook_inv_mass: float
	if _tip_inv_mass_override >= 0.0:
		hook_inv_mass = _tip_inv_mass_override
	else:
		hook_inv_mass = 0.0 if hook_node else 1.0
	var hook_point: = VerletPoint.new(end_pos, hook_inv_mass, hook_node)
	_points.append(hook_point)
	_update_visual_links()

func _sync_visual_links(desired_count: int) -> void :
	if desired_count < 0:
		desired_count = 0
	if _visual_links.size() == desired_count:
		return
	var link_z_index: int = Keeper3SecondarySettings.CARRY_CHAIN_LINK_Z_INDEX if _usage == Keeper3SecondarySettings.CHAIN_USAGE_CARRY else 24
	while _visual_links.size() < desired_count:
		var link_node: Node2D = Keeper3SecondarySettings.CHAIN_LINK_SCENE.instantiate()
		link_node.z_index = link_z_index
		add_child(link_node)
		_visual_links.append(link_node)
	while _visual_links.size() > desired_count:
		var node: Node2D = _visual_links.pop_back()
		if is_instance_valid(node):
			node.queue_free()
	var visual_links_size: = float(_visual_links.size())
	for i in _visual_links.size():
		_visual_links[i].modulate = lerp(Color.DARK_GRAY, Color.WHITE, sin(remap(float(i), 0.0, visual_links_size, 0.0, PI * 0.5)))

func _ensure_link_count(desired_links: int, allow_growth: bool = true) -> void :
	desired_links = clampi(desired_links, Keeper3SecondarySettings.CHAIN_MIN_LINKS, Keeper3SecondarySettings.CHAIN_MAX_LINKS)
	if allow_growth:
		while _current_link_count() < desired_links:
			_add_link_at_base()
	while _current_link_count() > desired_links:
		if _mode == Keeper3SecondarySettings.CHAIN_MODE_RETRACT:
			_remove_link_at_end()
		else:
			_remove_link_at_base()

func _update_segment_rest_length() -> void :
	var link_count: int = _current_link_count()
	if link_count <= 0:
		if _usage == Keeper3SecondarySettings.CHAIN_USAGE_CARRY:
			_segment_rest_length = Keeper3SecondarySettings.CARRY_CHAIN_LINK_LENGTH
		else:
			_segment_rest_length = Keeper3SecondarySettings.CHAIN_LINK_LENGTH
		return
	if _usage == Keeper3SecondarySettings.CHAIN_USAGE_CARRY:
		var desired_length: float = maxf(_target_length, Keeper3SecondarySettings.CARRY_CHAIN_LINK_LENGTH)
		_segment_rest_length = desired_length / float(link_count)
		return
	if _mode == Keeper3SecondarySettings.CHAIN_MODE_RETRACT:
		var desired_rest: float = _target_length / float(link_count)
		var min_rest: float = Keeper3SecondarySettings.CHAIN_LINK_LENGTH * 0.95
		var max_rest: float = Keeper3SecondarySettings.CHAIN_LINK_LENGTH
		var clamped: float = clampf(desired_rest, min_rest, max_rest)
		var relax_speed: float = 80.0
		var delta_time: float = get_physics_process_delta_time()
		_segment_rest_length = move_toward(_segment_rest_length, clamped, relax_speed * delta_time)
	else:
		_segment_rest_length = Keeper3SecondarySettings.CHAIN_LINK_LENGTH

func _add_link_at_base() -> void :
	if _current_link_count() >= Keeper3SecondarySettings.CHAIN_MAX_LINKS:
		return
	var base_point: VerletPoint = _points[0]
	var direction: Vector2 = Vector2.DOWN
	if _points.size() > 1:
		direction = _points[1].position - base_point.position
	elif is_instance_valid(hook):
		direction = _get_hook_anchor_position() - base_point.position
	if direction.length_squared() <= 0.0001:
		if is_instance_valid(hook):
			var hook_delta: Vector2 = _get_hook_anchor_position() - base_point.position
			direction = Vector2.DOWN if hook_delta.y > 0 else Vector2.UP
		else:
			direction = Vector2.DOWN
	direction = direction.normalized()
	var insert_pos: Vector2 = base_point.position + direction * Keeper3SecondarySettings.CHAIN_LINK_LENGTH
	var link_point: = VerletPoint.new(insert_pos, 1.0)
	_points.insert(1, link_point)

func _remove_link_at_base() -> void :
	if _current_link_count() <= Keeper3SecondarySettings.CHAIN_MIN_LINKS:
		return
	if _points.size() > 2:
		_points.remove_at(1)

func _remove_link_at_end() -> void :
	if _current_link_count() <= Keeper3SecondarySettings.CHAIN_MIN_LINKS:
		return
	if _points.size() > 2:
		_points.remove_at(_points.size() - 2)

func _simulate_points(delta: float) -> void :
	if delta <= 0.0:
		return
	var point_count: int = _points.size()
	var damping: float = Keeper3SecondarySettings.CHAIN_DAMPING
	var gravity_step: Vector2 = Vector2.ZERO
	if _gravity_enabled:
		gravity_step = _gravity_vector * delta * delta
	for i in range(point_count):
		var point: VerletPoint = _points[i]
		if point.is_pinned():
			continue
		var current_position: Vector2 = point.position
		var velocity: Vector2 = (current_position - point.previous_position) * damping
		point.previous_position = current_position
		point.position = current_position + velocity + gravity_step

func _satisfy_constraints() -> void :
	_apply_pin_positions()
	var point_count: int = _points.size()
	for _i in range(Keeper3SecondarySettings.CHAIN_SOLVER_ITERATIONS):
		for j in range(point_count - 1):
			_constrain_segment(j, j + 1)

func _straighten_chain() -> void :
	if _points.size() < 3:
		return
	var base_pos: Vector2 = _points[0].position
	var anchor_pos: Vector2 = _points[_points.size() - 1].position
	for i in range(1, _points.size() - 1):
		var t: float = float(i) / float(_points.size() - 1)
		var target_pos: Vector2 = base_pos.lerp(anchor_pos, t)
		_points[i].position = target_pos
		_points[i].previous_position = target_pos

func _constrain_segment(a_index: int, b_index: int) -> void :
	var point_a: VerletPoint = _points[a_index]
	var point_b: VerletPoint = _points[b_index]
	var delta: Vector2 = point_b.position - point_a.position
	var distance_sq: float = delta.length_squared()
	if distance_sq <= 0.0001:
		var angle: float = float(a_index) * 0.7
		delta = Vector2(cos(angle), sin(angle)) * 0.5
		distance_sq = delta.length_squared()
	var distance: float = sqrt(distance_sq)
	var rest_length: float = _segment_rest_length
	var difference: float = (distance - rest_length) / distance
	var inv_mass_sum: float = point_a.inv_mass + point_b.inv_mass
	if inv_mass_sum <= 0.0:
		return
	if not point_a.is_pinned():
		var ratio_a: float = point_a.inv_mass / inv_mass_sum
		point_a.position += delta * difference * ratio_a
	if not point_b.is_pinned():
		var ratio_b: float = point_b.inv_mass / inv_mass_sum
		point_b.position -= delta * difference * ratio_b

func _apply_pin_positions() -> void :
	for i in range(_points.size()):
		var point: VerletPoint = _points[i]
		if point.pinned_node != null:
			if is_instance_valid(point.pinned_node):
				point.set_position(point.pinned_node.global_position)
			else:
				point.pinned_node = null
				if point.inv_mass == 0.0:
					point.inv_mass = 1.0

func _update_rope_ball(delta: float) -> void :
	if not is_instance_valid(rope_ball):
		return
	var base_point: VerletPoint = _points[0]
	rope_ball.global_position = base_point.position
	if delta > 0.0:
		var velocity: Vector2 = (base_point.position - _last_base_position) / delta
		rope_ball.linear_velocity = velocity
		_last_base_position = base_point.position
	rope_ball.angular_velocity = 0.0

func _rebuild_visual_curve() -> float:
	_curve.clear_points()
	if _points.size() < 2:
		return 0.0
	_unique_positions.clear()
	for point in _points:
		var point_position: Vector2 = point.position
		if _unique_positions.is_empty() or _unique_positions[_unique_positions.size() - 1].distance_squared_to(point_position) > 0.0001:
			_unique_positions.append(point_position)
	var unique_count: int = _unique_positions.size()
	if unique_count < 2:
		return 0.0
	var last_index: int = unique_count - 1
	for i in range(unique_count):
		var point_position: Vector2 = _unique_positions[i]
		_curve.add_point(point_position)
		var prev_position: Vector2 = _unique_positions[max(i - 1, 0)]
		var next_position: Vector2 = _unique_positions[min(i + 1, last_index)]
		var tangent: Vector2 = Vector2.ZERO
		if i == 0:
			tangent = (next_position - point_position) * Keeper3SecondarySettings.CHAIN_VISUAL_CURVE_ENDPOINT_FACTOR
		elif i == last_index:
			tangent = (point_position - prev_position) * Keeper3SecondarySettings.CHAIN_VISUAL_CURVE_ENDPOINT_FACTOR
		else:
			tangent = (next_position - prev_position) * Keeper3SecondarySettings.CHAIN_VISUAL_CURVE_TENSION
		_curve.set_point_in(i, - tangent)
		_curve.set_point_out(i, tangent)
	_curve.set_bake_interval(Keeper3SecondarySettings.CHAIN_CURVE_BAKE_INTERVAL)
	return _curve.get_baked_length()

func _update_visual_links() -> void :
	var total_length: float = _rebuild_visual_curve()
	if total_length <= 0.001:
		_sync_visual_links(0)
		return
	var spacing: float = Keeper3SecondarySettings.CHAIN_VISUAL_LINK_SPACING
	if spacing <= 0.0:
		spacing = Keeper3SecondarySettings.CHAIN_LINK_LENGTH
	var desired_count: int = ceili(total_length / spacing)
	desired_count = clampi(desired_count, 1, Keeper3SecondarySettings.CHAIN_MAX_VISUAL_LINKS)
	_sync_visual_links(desired_count)
	var step: float = total_length / float(desired_count)
	if step <= 0.0001:
		return
	var tangent_offset: float = maxf(step * 0.5, Keeper3SecondarySettings.CHAIN_TANGENT_SAMPLE_OFFSET)
	var fallback_direction: Vector2 = Vector2.DOWN
	if _points.size() >= 2:
		fallback_direction = _points[_points.size() - 1].position - _points[0].position
		if fallback_direction.length_squared() <= 0.0001:
			fallback_direction = Vector2.DOWN
	for i in range(desired_count):
		var link_node: Node2D = _visual_links[i]
		if not is_instance_valid(link_node):
			continue
		var center_distance: float = min(step * float(i) + step * 0.5, total_length)
		var curve_position: Vector2 = _curve.sample_baked(center_distance)
		var ahead_distance: float = min(center_distance + tangent_offset, total_length)
		var forward: Vector2 = _curve.sample_baked(ahead_distance)
		var direction: Vector2 = forward - curve_position
		if direction.length_squared() <= 0.0001 and center_distance > 0.0:
			var back_distance: float = maxf(center_distance - tangent_offset, 0.0)
			var back: Vector2 = _curve.sample_baked(back_distance)
			direction = curve_position - back
		if direction.length_squared() <= 0.0001:
			direction = fallback_direction
		link_node.global_position = curve_position
		link_node.rotation = direction.angle()

func _process_visual_return(delta: float) -> void :
	if not _visual_return_active:
		return
	_apply_pin_positions()
	if _points.is_empty():
		_finish_visual_return()
		return
	var base_position: Vector2 = _points[0].position
	if delta <= 0.0:
		delta = get_physics_process_delta_time()
	var step: float = maxf(visual_return_speed * delta, 0.0)
	for i in range(1, _points.size()):
		var point: VerletPoint = _points[i]
		var to_base: Vector2 = base_position - point.position
		var distance: float = to_base.length()
		if distance <= 0.001 or step <= 0.0:
			point.position = base_position
			point.previous_position = base_position
			continue
		var move_amount: float = min(step, distance)
		var direction: Vector2 = to_base / distance
		point.position += direction * move_amount
		point.previous_position = point.position
	_remove_collapsed_segments(base_position)
	_update_visual_links()
	_update_visual_tip(base_position)
	if _points.size() <= 1:
		_finish_visual_return()

func _remove_collapsed_segments(base_position: Vector2) -> void :
	if _points.size() <= 1:
		return
	var _removed: bool = false
	var remove_distance: float = Keeper3SecondarySettings.CHAIN_VISUAL_RETURN_REMOVE_DISTANCE
	var remove_distance_sq: float = remove_distance * remove_distance
	for i in range(_points.size() - 1, 0, -1):
		var point: VerletPoint = _points[i]
		if point.position.distance_squared_to(base_position) <= remove_distance_sq:
			_points.remove_at(i)
			_removed = true
		else:
			break

func _update_visual_tip(base_position: Vector2) -> void :
	if not is_instance_valid(_visual_tip):
		return
	var tip_position: Vector2 = base_position
	if _points.size() > 1:
		tip_position = _points[_points.size() - 1].position
	_visual_tip.global_position = tip_position
	var outward: Vector2 = tip_position - base_position
	if outward.length_squared() <= 0.0001:
		outward = Vector2.UP
	_visual_tip.rotation = outward.angle() + PI * 0.5

func _dispose_visual_tip() -> void :
	if is_instance_valid(_visual_tip):
		_visual_tip.queue_free()
	_visual_tip = null

func _finish_visual_return() -> void :
	if is_queued_for_deletion():
		return
	_visual_return_active = false
	_dispose_visual_tip()
	_cleanup_chain()
	if not is_queued_for_deletion():
		queue_free()

func _handle_retraction_completion() -> void :
	if _points.is_empty() or not is_instance_valid(hook):
		return
	if _hang_length_locked:
		return
	var base_point: Vector2 = _points[0].position
	var distance: float = base_point.distance_to(_get_hook_anchor_position())
	if _retracting and distance <= Keeper3SecondarySettings.CHAIN_RETRACTION_STOP_DISTANCE:
		_retracting = false
		_target_length = maxf(Keeper3SecondarySettings.CHAIN_RETRACTION_STOP_DISTANCE, distance)
		if not _retraction_completed:
			_retraction_completed = true
			emit_signal("rope_finished")
	if not _retracting:
		_target_length = maxf(max(distance, Keeper3SecondarySettings.CHAIN_RETRACTION_STOP_DISTANCE), Keeper3SecondarySettings.CHAIN_LINK_LENGTH * float(Keeper3SecondarySettings.CHAIN_MIN_LINKS))

func _handle_max_distance_reached() -> void :
	if _max_distance_triggered:
		return
	_max_distance_triggered = true
	if is_instance_valid(keeper) and keeper.has_method("releaseHookInput"):
		keeper.releaseHookInput()
	elif is_instance_valid(hook):
		hook.request_detach()
	else:
		begin_detach()

func _calculate_desired_link_count(start_pos: Vector2, end_pos: Vector2) -> int:
	var distance: float = start_pos.distance_to(end_pos)
	var total_segments: int = ceili((distance + Keeper3SecondarySettings.CHAIN_TOTAL_SLACK) / Keeper3SecondarySettings.CHAIN_LINK_LENGTH)
	var desired_links: int = max(total_segments, Keeper3SecondarySettings.CHAIN_MIN_LINKS)
	return clampi(desired_links, Keeper3SecondarySettings.CHAIN_MIN_LINKS, Keeper3SecondarySettings.CHAIN_MAX_LINKS)


func _get_hook_anchor_node() -> Node2D:
	if _usage == Keeper3SecondarySettings.CHAIN_USAGE_CARRY:
		return null
	if is_instance_valid(hook_anchor):
		return hook_anchor
	if is_instance_valid(hook):
		if hook.has_method("get_chain_anchor_node"):
			var anchor_node = hook.get_chain_anchor_node()
			if anchor_node is Node2D and is_instance_valid(anchor_node):
				hook_anchor = anchor_node
				return hook_anchor
		return hook
	return null


func _get_hook_anchor_position() -> Vector2:
	if _usage == Keeper3SecondarySettings.CHAIN_USAGE_CARRY:
		if is_instance_valid(carried_body):
			return carried_body.global_position
		return _resolve_carry_anchor_position()
	var anchor_node: = _get_hook_anchor_node()
	if is_instance_valid(anchor_node):
		return anchor_node.global_position
	if is_instance_valid(hook):
		return hook.global_position
	return Vector2.ZERO


func _get_base_pin_node() -> Node2D:
	if _usage == Keeper3SecondarySettings.CHAIN_USAGE_CARRY:
		return null
	if is_instance_valid(spawn_pivot):
		return spawn_pivot
	if is_instance_valid(keeper):
		return keeper.getChainSpawnNode()
	return null

func _get_spawn_position() -> Vector2:
	if _usage == Keeper3SecondarySettings.CHAIN_USAGE_CARRY:
		return _resolve_carry_anchor_position()
	var node: Node2D = _get_base_pin_node()
	if is_instance_valid(node):
		return node.global_position
	if is_instance_valid(keeper):
		return keeper.global_position
	return global_position

func _cleanup_chain() -> void :
	_clear_retraction_timer()
	_active = false
	_retracting = false
	_hang_length_locked = false
	_gravity_enabled = false
	_visual_return_active = false
	_base_override_pending = false
	_base_override_position = Vector2.ZERO
	_base_override_velocity = Vector2.ZERO
	_base_override_delta = 0.0
	_sync_visual_links(0)
	_curve.clear_points()
	_points.clear()
	if is_instance_valid(rope_ball):
		rope_ball.queue_free()
	rope_ball = null
	_dispose_visual_tip()
	_max_distance_triggered = false
	carried_body = null
	carry_owner = null
	_carry_anchor = null
	_base_pin_override = null
	_tip_pin_override = null
	_base_inv_mass_override = -1.0
	_tip_inv_mass_override = -1.0
	_carry_link_count = Keeper3SecondarySettings.CARRY_CHAIN_LINK_COUNT
	_carry_rest_length = Keeper3SecondarySettings.CARRY_FOLLOW_REST_DISTANCE

func _refresh_carry_anchor_pin() -> void :
	var anchor_node: = _resolve_carry_anchor_node()
	_base_pin_override = anchor_node
	_base_inv_mass_override = Keeper3SecondarySettings.CARRY_CHAIN_BASE_INV_MASS
	if _points.is_empty():
		return
	var base_point: VerletPoint = _points[0]
	if is_instance_valid(anchor_node):
		base_point.pinned_node = anchor_node
		base_point.inv_mass = 0.0
		base_point.set_position(anchor_node.global_position)
		_last_base_position = base_point.position
		if is_instance_valid(rope_ball):
			rope_ball.global_position = base_point.position
			rope_ball.linear_velocity = Vector2.ZERO
			rope_ball.angular_velocity = 0.0
	else:
		base_point.pinned_node = null
		if _base_inv_mass_override >= 0.0:
			base_point.inv_mass = _base_inv_mass_override
		elif base_point.inv_mass == 0.0:
			base_point.inv_mass = 1.0

func _emit_detach() -> void :
	if _detached_emitted:
		return
	_detached_emitted = true
	emit_signal("rope_detached")

func _resolve_gravity_vector() -> Vector2:
	var gravity_setting: Variant = ProjectSettings.get_setting("physics/2d/default_gravity", 0.0)
	var gravity_value: float
	if gravity_setting is float or gravity_setting is int:
		gravity_value = float(gravity_setting)
	else:
		gravity_value = 0.0
	return Vector2(0.0, gravity_value * Keeper3GameplaySettings.CHAIN_GRAVITY_MULTIPLIER)

func _clear_retraction_timer() -> void :
	if _retraction_timer:
		if _retraction_timer_callable and _retraction_timer.timeout.is_connected(_retraction_timer_callable):
			_retraction_timer.timeout.disconnect(_retraction_timer_callable)
		_retraction_timer = null
		_retraction_timer_callable = Callable()
