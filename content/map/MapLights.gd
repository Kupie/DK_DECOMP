extends SubViewport

var ray_light_polygon: PackedScene = load("res://content/map/lighteffect/LightEffect.tscn")

var lights: Dictionary = {}
var simple_lights: Dictionary = {}
var pos_offset: Vector2 = Vector2(size.x / 2, 50)
var map_to_world_offset: Vector2
var sprite: Sprite2D

var previous_frame_active_lights: int = 0

const BASE_RAY_LIGHT_PRECISSION: = 96
const MAX_RAY_PRECISSION_POOL: = roundi(BASE_RAY_LIGHT_PRECISSION * 2.5)
const MIN_RAY_PRECISSION = 24

var _tiles_destroyed_since_last_frame: PackedVector2Array = PackedVector2Array()
var _frames_to_skip_before_refresh: int = 0
var _frames_since_refresh: int = 0
var _force_update_frames_left: int = 0

func _ready() -> void :
	StageManager.stage_started.connect(on_stage_manager_stage_started)

func propertyChanged(property: String, oldValue, newValue):
	match property:
		"options.changed":
			_frames_to_skip_before_refresh = 1 if Options.renderHalfRes else 0

func on_stage_manager_stage_started() -> void :
	_frames_to_skip_before_refresh = 1 if Options.renderHalfRes else 0
	if not Data.isListening(self, "options.changed"):
		Data.listen(self, "options.changed")
	if not is_instance_valid(Level.map):
		return
	if Level.map.tile_destroyed.is_connected(_on_map_tile_destroyed):
		return
	Level.map.tile_destroyed.connect(_on_map_tile_destroyed, ConnectFlags.CONNECT_DEFERRED)

func _on_map_tile_destroyed(in_tile_coords: Vector2):
	_tiles_destroyed_since_last_frame.append(in_tile_coords)

func set_size(new_size: Vector2i):
	size = new_size
	pos_offset.x = size.x / 2

func _physics_process(delta: float) -> void :
	if _frames_since_refresh < _frames_to_skip_before_refresh:
		_frames_since_refresh += 1
		return
	_frames_since_refresh = 0

	var precission_target: int = previous_frame_active_lights * BASE_RAY_LIGHT_PRECISSION
	var current_frame_precission: int = BASE_RAY_LIGHT_PRECISSION
	if precission_target > MAX_RAY_PRECISSION_POOL:
		current_frame_precission = roundi(MAX_RAY_PRECISSION_POOL / previous_frame_active_lights)
		if current_frame_precission < MIN_RAY_PRECISSION:
			current_frame_precission = MIN_RAY_PRECISSION

	var active_lights: int = 0
	var lights: Array = get_tree().get_nodes_in_group("LightLineOfSight")
	for light in lights:
		var fully_processed: bool = _process_light(light, current_frame_precission)
		if fully_processed:
			active_lights += 1

	previous_frame_active_lights = active_lights
	_tiles_destroyed_since_last_frame.clear()

func _process(_delta: float) -> void :
	var marked_for_deletion: = []
	var offset: = pos_offset + map_to_world_offset + Vector2.UP * 2.0
	for s in simple_lights:
		if not is_instance_valid(s):
			simple_lights[s].queue_free()
			marked_for_deletion.append(s)
			continue
		simple_lights[s].position = s.global_position + offset
	for del in marked_for_deletion:
		simple_lights.erase(del)

func _process_light(light: LightLineOfSight, in_current_frame_precission: int) -> bool:
	if not light.isOnScreen():
		return false
	if not light.light_active:
		return false

	var force_update: bool = _force_update_frames_left > 0
	var movement_since_last_frame: float = light.previous_position.distance_squared_to(light.global_position)
	if is_zero_approx(movement_since_last_frame) and not force_update:
		light.previous_position = light.global_position
		force_update = _need_to_force_update_tile(light)
		if force_update:
			_force_update_frames_left = 3
		else:
			return false
	_force_update_frames_left = max(0, _force_update_frames_left - 1)

	light.previous_position = light.global_position
	var polygon: PackedVector2Array = _calculate_light_polygon(light, in_current_frame_precission, force_update)
	if polygon.is_empty():
		_update_only_transform(light)
		return false
	else:
		_update_light_poly(light, polygon)
		return true

func _need_to_force_update_tile(inLight: LightLineOfSight) -> bool:
	const INFLUENCE_FACTOR: = 1.5
	for tile_coord: Vector2 in _tiles_destroyed_since_last_frame:
		var sqr_dst_to_tile = inLight.global_position.distance_squared_to(tile_coord)
		var influence_radius: float = (inLight.light_size + inLight.light_expansion) * INFLUENCE_FACTOR
		var influence_sqr_radius: float = influence_radius * influence_radius
		if sqr_dst_to_tile < influence_sqr_radius:
			return true
	return false

func _calculate_light_polygon(out_light: LightLineOfSight, in_light_precission: int, in_force_update: bool) -> PackedVector2Array:
	const LIGHT_EXPAND_4_BRIGHT_TILE_EDGE: = 6.0
	var angle_slice: = TAU / in_light_precission
	var out_polygon: = PackedVector2Array()
	var space_state: = out_light.get_world_2d().direct_space_state

	var simple_check: bool = not out_light.collision_previous_frame and ( not in_force_update)
	if simple_check:
		if not _is_circle_collision(out_light, space_state):
			return PackedVector2Array()

	var any_collision: bool = false
	for i in in_light_precission:
		var radius: float = out_light.light_size
		var from: Vector2 = out_light.global_position
		var direction: Vector2 = Vector2.UP.rotated(angle_slice * i)
		var to: Vector2 = out_light.global_position + direction * radius
		if not out_light.rayQuery:
			out_light.rayQuery = PhysicsRayQueryParameters2D.create(from, to, 1)
			out_light.rayQuery.collide_with_areas = false
			out_light.rayQuery.collide_with_bodies = true
			out_light.rayQuery.collision_mask = 1
		var query: = out_light.rayQuery
		query.from = from
		query.to = to
		var result: = space_state.intersect_ray(query)
		var is_colliding: bool = not result.is_empty()
		var light_polygon_point: Vector2 = result["position"] if is_colliding else to
		var local_light_polygon_point: Vector2 = out_light.to_local(light_polygon_point)
		var expansion: float = (out_light.light_expansion + LIGHT_EXPAND_4_BRIGHT_TILE_EDGE)
		var distance: float = local_light_polygon_point.length() + expansion
		var new_point: = direction * distance
		any_collision = any_collision or is_colliding
		out_polygon.append(new_point)
	out_light.collision_previous_frame = any_collision
	return out_polygon

static func _is_circle_collision(out_light: LightLineOfSight, in_space_state: PhysicsDirectSpaceState2D) -> bool:
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = out_light.circleShape
	query.transform = Transform2D(0.0, out_light.global_position)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var results = in_space_state.intersect_shape(query, 1)
	var is_colliding: bool = not results.is_empty()
	return is_colliding

func _update_only_transform(in_light: LightLineOfSight) -> void :
	var light_name: String = in_light.light_name
	var light_position: Vector2 = in_light.global_position
	if not light_name in lights:
		var polygon: PackedVector2Array = _calculate_light_polygon(in_light, BASE_RAY_LIGHT_PRECISSION, true)
		_update_light_poly(in_light, polygon)
		return

	var effect: LightEffect = lights[light_name]
	effect.position = light_position + pos_offset + map_to_world_offset
	var radius: float = in_light.light_size + in_light.light_expansion
	effect.set_flicker_strength(in_light.light_flicker_strength, radius, in_light.light_flicker_speed)

func _update_light_poly(in_light: LightLineOfSight, in_points: PackedVector2Array):
	var light_name: String = in_light.light_name
	var light_color: Color = in_light.light_color
	var light_position: Vector2 = in_light.global_position

	if not light_name in lights:
		var new_light: LightEffect = ray_light_polygon.instantiate()
		add_child(new_light)
		lights[light_name] = new_light

	var light_effect: LightEffect = lights[light_name]
	light_effect.set_main_color(light_color)
	if in_light.light_inner_enabled:
		light_effect.set_inner_color(in_light.light_inner_color)

	light_effect.update_polygon(in_points, in_light.light_inner_enabled)
	var radius: float = in_light.light_size + in_light.light_expansion
	light_effect.set_flicker_strength(in_light.light_flicker_strength, radius, in_light.light_flicker_speed)
	light_effect.position = light_position + pos_offset + map_to_world_offset

func remove_light(light_name):
	if light_name in lights:
		lights[light_name].queue_free()
		lights.erase(light_name)

func add_simple_light(track_node: Node2D, light_node: Node2D):
	simple_lights[track_node] = light_node
	light_node.top_level = true
	light_node.reparent(self, true)
