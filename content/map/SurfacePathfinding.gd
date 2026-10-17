extends RefCounted
class_name SurfacePathfinding

enum SurfaceType{FLOOR_TOP, WALL_LEFT, WALL_RIGHT, VINE_CENTER}

const WALK_COST: = 24.0
const CORNER_COST: = 17.0
const JUMP_COST: = 72.0
const MAX_MAP_WIDTH: = 1000
const HALF_TILE_SIZE: = 12.0
const COORD_OFFSET_X: = 500
const COORD_OFFSET_Y: = 100
const ADJACENT_DISTANCE_SQ: = 900.0
const CORNER_ID_OFFSET: = 10000000

class WeightedAStar extends AStar2D:
	var jump_connections: Dictionary = {}
	var _edge_costs: Dictionary = {}

	func _compute_cost(from_id: int, to_id: int) -> float:
		return _edge_costs.get(mini(from_id, to_id) * 1000000 + maxi(from_id, to_id), 0.0)

	func _make_connection_key(a: int, b: int) -> int:
		return mini(a, b) * 1000000 + maxi(a, b)

	func mark_as_jump(from_id: int, to_id: int) -> void :
		var key: = _make_connection_key(from_id, to_id)
		jump_connections[key] = true

	func precompute_costs() -> void :
		_edge_costs.clear()
		for point_id in get_point_ids():
			for connected_id in get_point_connections(point_id):
				var key: int = mini(point_id, connected_id) * 1000000 + maxi(point_id, connected_id)
				if _edge_costs.has(key):
					continue
				var dist: float = get_point_position(point_id).distance_to(get_point_position(connected_id))
				if jump_connections.has(key):
					dist += JUMP_COST
				_edge_costs[key] = dist

	func clear_jumps() -> void :
		jump_connections.clear()
		_edge_costs.clear()

var pathfinder: WeightedAStar
var surface_nodes: = {}
var coord_to_surfaces: = {}
var corner_nodes: = {}
var _map_data: MapData = null
var _gravity_dir: int = 1
var _uf_parent: = {}

enum RebuildPhase{IDLE, SCAN, VINES, CONNECT, PRECOMPUTE, UNION_FIND, DONE}
var _rebuild_phase: int = RebuildPhase.IDLE
var _rebuild_cells_keys: Array = []
var _rebuild_cells_cursor: int = 0
var _rebuild_vine_coords: Array[Vector2i] = []
var _rebuild_vines_cursor: int = 0
var _rebuild_surface_keys: Array = []
var _rebuild_surface_cursor: int = 0
var _rebuild_uf_init_done: bool = false
var _rebuild_uf_cursor: int = 0

func _uf_find(x: int) -> int:
	while _uf_parent[x] != x:
		_uf_parent[x] = _uf_parent.get(_uf_parent[x], x)
		x = _uf_parent[x]
	return x

func _uf_union(a: int, b: int) -> void :
	var ra: int = _uf_find(a)
	var rb: int = _uf_find(b)
	if ra != rb:
		_uf_parent[ra] = rb

func are_connected(a: int, b: int) -> bool:
	if not _uf_parent.has(a) or not _uf_parent.has(b):
		return false
	return _uf_find(a) == _uf_find(b)

func _init():
	pathfinder = WeightedAStar.new()

func rebuild_from_map(map: Node, vine_coords: Array[Vector2i] = [], inverse_gravity: bool = false) -> void :
	begin_rebuild(map, vine_coords, inverse_gravity)
	while not step_rebuild(1000000):
		pass

func is_rebuilding() -> bool:
	return _rebuild_phase != RebuildPhase.IDLE and _rebuild_phase != RebuildPhase.DONE

func begin_rebuild(map: Node, vine_coords: Array[Vector2i] = [], inverse_gravity: bool = false) -> void :
	pathfinder.clear()
	pathfinder.clear_jumps()
	surface_nodes.clear()
	coord_to_surfaces.clear()
	corner_nodes.clear()
	_uf_parent.clear()

	_map_data = map.tileData
	_gravity_dir = -1 if inverse_gravity else 1

	var cells_to_check: = {}
	for tile_coord in map.tiles:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var neighbor: = Vector2(tile_coord.x + dx, tile_coord.y + dy)
				cells_to_check[neighbor] = true

	_rebuild_cells_keys = cells_to_check.keys()
	_rebuild_cells_cursor = 0
	_rebuild_vine_coords = vine_coords
	_rebuild_vines_cursor = 0
	_rebuild_surface_keys.clear()
	_rebuild_surface_cursor = 0
	_rebuild_uf_init_done = false
	_rebuild_uf_cursor = 0
	_rebuild_phase = RebuildPhase.SCAN

func step_rebuild(budget_us: int) -> bool:
	if _rebuild_phase == RebuildPhase.IDLE or _rebuild_phase == RebuildPhase.DONE:
		return true
	var deadline: int = Time.get_ticks_usec() + budget_us
	while _rebuild_phase != RebuildPhase.DONE:
		match _rebuild_phase:
			RebuildPhase.SCAN:
				if not step_scan(deadline):
					return false
				_rebuild_phase = RebuildPhase.VINES
			RebuildPhase.VINES:
				if not step_vines(deadline):
					return false
				_rebuild_phase = RebuildPhase.CONNECT
				_rebuild_surface_keys = surface_nodes.keys()
				_rebuild_surface_cursor = 0
			RebuildPhase.CONNECT:
				if not step_connect(deadline):
					return false
				_rebuild_phase = RebuildPhase.PRECOMPUTE
			RebuildPhase.PRECOMPUTE:
				pathfinder.precompute_costs()
				_rebuild_phase = RebuildPhase.UNION_FIND
				if Time.get_ticks_usec() >= deadline:
					return false
			RebuildPhase.UNION_FIND:
				if not step_union_find(deadline):
					return false
				_rebuild_phase = RebuildPhase.DONE
	return true

func step_scan(deadline: int) -> bool:
	var tile_size: float = GameWorld.TILE_SIZE
	var tile_offset: Vector2 = CONST.TILE_OFFSET
	var keys: Array = _rebuild_cells_keys
	var n: int = keys.size()
	while _rebuild_cells_cursor < n:
		var coord_v2 = keys[_rebuild_cells_cursor]
		_rebuild_cells_cursor += 1
		var x: int = int(coord_v2.x)
		var y: int = int(coord_v2.y)
		var coord: = Vector2i(x, y)

		if _map_data.get_resourcev(coord_v2) >= 0:
			if (_rebuild_cells_cursor & 63) == 0 and Time.get_ticks_usec() >= deadline:
				return false
			continue

		var below_solid: bool = _map_data.get_resourcev(Vector2(x, y + _gravity_dir)) >= 0
		var left_solid: bool = _map_data.get_resourcev(Vector2(x - 1, y)) >= 0
		var right_solid: bool = _map_data.get_resourcev(Vector2(x + 1, y)) >= 0

		var base_pos: Vector2 = coord_v2 * tile_size + tile_offset

		if below_solid:
			var surface_id: int = _get_surface_id(coord, SurfaceType.FLOOR_TOP)
			var world_pos: Vector2 = base_pos + Vector2(0, HALF_TILE_SIZE * _gravity_dir)
			pathfinder.add_point(surface_id, world_pos)
			surface_nodes[surface_id] = {"coord": coord, "type": SurfaceType.FLOOR_TOP, "world_pos": world_pos, "id": surface_id}
			if not coord_to_surfaces.has(coord):
				coord_to_surfaces[coord] = []
			coord_to_surfaces[coord].append(surface_id)
			_add_corners_for_surface(surface_id, coord, SurfaceType.FLOOR_TOP, base_pos)

		if left_solid:
			var surface_id: int = _get_surface_id(coord, SurfaceType.WALL_LEFT)
			var world_pos: Vector2 = base_pos + Vector2( - HALF_TILE_SIZE, 0)
			pathfinder.add_point(surface_id, world_pos)
			surface_nodes[surface_id] = {"coord": coord, "type": SurfaceType.WALL_LEFT, "world_pos": world_pos, "id": surface_id}
			if not coord_to_surfaces.has(coord):
				coord_to_surfaces[coord] = []
			coord_to_surfaces[coord].append(surface_id)
			_add_corners_for_surface(surface_id, coord, SurfaceType.WALL_LEFT, base_pos)

		if right_solid:
			var surface_id: int = _get_surface_id(coord, SurfaceType.WALL_RIGHT)
			var world_pos: Vector2 = base_pos + Vector2(HALF_TILE_SIZE, 0)
			pathfinder.add_point(surface_id, world_pos)
			surface_nodes[surface_id] = {"coord": coord, "type": SurfaceType.WALL_RIGHT, "world_pos": world_pos, "id": surface_id}
			if not coord_to_surfaces.has(coord):
				coord_to_surfaces[coord] = []
			coord_to_surfaces[coord].append(surface_id)
			_add_corners_for_surface(surface_id, coord, SurfaceType.WALL_RIGHT, base_pos)

		if (_rebuild_cells_cursor & 63) == 0 and Time.get_ticks_usec() >= deadline:
			return false
	return true

func step_vines(deadline: int) -> bool:
	var tile_size: float = GameWorld.TILE_SIZE
	var tile_offset: Vector2 = CONST.TILE_OFFSET
	var vines: Array[Vector2i] = _rebuild_vine_coords
	var n: int = vines.size()
	while _rebuild_vines_cursor < n:
		var vine_coord: Vector2i = vines[_rebuild_vines_cursor]
		_rebuild_vines_cursor += 1
		var vc: = Vector2(vine_coord.x, vine_coord.y)
		if _map_data.get_resourcev(vc) >= 0:
			continue
		var sid: int = _get_surface_id(vine_coord, SurfaceType.VINE_CENTER)
		var wpos: Vector2 = vc * tile_size + tile_offset
		pathfinder.add_point(sid, wpos)
		pathfinder.set_point_weight_scale(sid, 0.1)
		surface_nodes[sid] = {"coord": vine_coord, "type": SurfaceType.VINE_CENTER, "world_pos": wpos, "id": sid}
		if not coord_to_surfaces.has(vine_coord):
			coord_to_surfaces[vine_coord] = []
		coord_to_surfaces[vine_coord].append(sid)
		if (_rebuild_vines_cursor & 63) == 0 and Time.get_ticks_usec() >= deadline:
			return false
	return true

func step_connect(deadline: int) -> bool:
	var keys: Array = _rebuild_surface_keys
	var n: int = keys.size()
	while _rebuild_surface_cursor < n:
		var surface_id: int = keys[_rebuild_surface_cursor]
		_rebuild_surface_cursor += 1
		var surface: Dictionary = surface_nodes[surface_id]
		if surface.type == SurfaceType.VINE_CENTER:
			var coord: Vector2i = surface.coord
			var above_id: = _get_surface_id(Vector2i(coord.x, coord.y - 1), SurfaceType.VINE_CENTER)
			var below_id: = _get_surface_id(Vector2i(coord.x, coord.y + 1), SurfaceType.VINE_CENTER)
			if surface_nodes.has(above_id) and not pathfinder.are_points_connected(surface_id, above_id):
				pathfinder.connect_points(surface_id, above_id, true)
			if surface_nodes.has(below_id) and not pathfinder.are_points_connected(surface_id, below_id):
				pathfinder.connect_points(surface_id, below_id, true)
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if ox != 0 and oy != 0:
						if _map_data.get_resourcev(Vector2(coord.x + ox, coord.y)) >= 0:
							continue
						if _map_data.get_resourcev(Vector2(coord.x, coord.y + oy)) >= 0:
							continue
					var adj: = Vector2i(coord.x + ox, coord.y + oy)
					for st in [SurfaceType.FLOOR_TOP, SurfaceType.WALL_LEFT, SurfaceType.WALL_RIGHT]:
						var adj_id: = _get_surface_id(adj, st)
						if surface_nodes.has(adj_id) and not pathfinder.are_points_connected(surface_id, adj_id):
							pathfinder.connect_points(surface_id, adj_id, true)
							pathfinder.mark_as_jump(surface_id, adj_id)
		else:
			_connect_walks(surface_id, surface)
			_connect_jumps_by_rules(surface_id, surface)
		if (_rebuild_surface_cursor & 31) == 0 and Time.get_ticks_usec() >= deadline:
			return false
	return true

func step_union_find(deadline: int) -> bool:
	if not _rebuild_uf_init_done:
		for point_id in surface_nodes:
			_uf_parent[point_id] = point_id
		for corner_id in corner_nodes:
			_uf_parent[corner_id] = corner_id
		_rebuild_uf_init_done = true
		_rebuild_surface_keys = surface_nodes.keys()
		_rebuild_uf_cursor = 0
		if Time.get_ticks_usec() >= deadline:
			return false
	var keys: Array = _rebuild_surface_keys
	var n: int = keys.size()
	while _rebuild_uf_cursor < n:
		var point_id: int = keys[_rebuild_uf_cursor]
		_rebuild_uf_cursor += 1
		for connected_id in pathfinder.get_point_connections(point_id):
			_uf_union(point_id, connected_id)
		if (_rebuild_uf_cursor & 31) == 0 and Time.get_ticks_usec() >= deadline:
			return false
	return true

func _get_corner_id(world_pos: Vector2) -> int:
	var px: int = int(world_pos.x * 100)
	var py: int = int(world_pos.y * 100)
	return CORNER_ID_OFFSET + (py + 100000) * 200000 + (px + 100000)

func _is_corner_passable(x: int, y: int) -> bool:
	return _map_data.get_hardnessv(Vector2(x, y)) >= 0 and _map_data.get_resourcev(Vector2(x, y)) < 0

func _add_corners_for_surface(surface_id: int, coord: Vector2i, surface_type: int, base_pos: Vector2) -> void :
	var corners: Array[Vector2] = []
	match surface_type:
		SurfaceType.FLOOR_TOP:
			if _is_corner_passable(coord.x - 1, coord.y):
				corners.append(base_pos + Vector2( - HALF_TILE_SIZE, HALF_TILE_SIZE * _gravity_dir))
			if _is_corner_passable(coord.x + 1, coord.y):
				corners.append(base_pos + Vector2(HALF_TILE_SIZE, HALF_TILE_SIZE * _gravity_dir))
		SurfaceType.WALL_LEFT:
			if _is_corner_passable(coord.x, coord.y - _gravity_dir):
				corners.append(base_pos + Vector2( - HALF_TILE_SIZE, - HALF_TILE_SIZE * _gravity_dir))
			corners.append(base_pos + Vector2( - HALF_TILE_SIZE, HALF_TILE_SIZE * _gravity_dir))
		SurfaceType.WALL_RIGHT:
			if _is_corner_passable(coord.x, coord.y - _gravity_dir):
				corners.append(base_pos + Vector2(HALF_TILE_SIZE, - HALF_TILE_SIZE * _gravity_dir))
			corners.append(base_pos + Vector2(HALF_TILE_SIZE, HALF_TILE_SIZE * _gravity_dir))

	for corner_pos in corners:
		var corner_id: int = _get_corner_id(corner_pos)
		if not corner_nodes.has(corner_id):
			corner_nodes[corner_id] = {"world_pos": corner_pos}
			pathfinder.add_point(corner_id, corner_pos)
		pathfinder.connect_points(surface_id, corner_id, true)

func _connect_walks(surface_id: int, surface: Dictionary) -> void :
	var coord: Vector2i = surface.coord
	var surface_type: int = surface.type

	match surface_type:
		SurfaceType.FLOOR_TOP:
			_try_connect(surface_id, coord + Vector2i(-1, 0), SurfaceType.FLOOR_TOP)
			_try_connect(surface_id, coord + Vector2i(1, 0), SurfaceType.FLOOR_TOP)
			_try_connect(surface_id, coord, SurfaceType.WALL_LEFT)
			_try_connect(surface_id, coord, SurfaceType.WALL_RIGHT)
			if _is_corner_passable(coord.x - 1, coord.y):
				_try_connect(surface_id, coord + Vector2i(-1, _gravity_dir), SurfaceType.WALL_RIGHT)
			if _is_corner_passable(coord.x + 1, coord.y):
				_try_connect(surface_id, coord + Vector2i(1, _gravity_dir), SurfaceType.WALL_LEFT)
		SurfaceType.WALL_LEFT:
			_try_connect(surface_id, coord + Vector2i(0, -1), SurfaceType.WALL_LEFT)
			_try_connect(surface_id, coord + Vector2i(0, 1), SurfaceType.WALL_LEFT)
			_try_connect(surface_id, coord + Vector2i(0, - _gravity_dir), SurfaceType.FLOOR_TOP)
			if _is_corner_passable(coord.x, coord.y - _gravity_dir):
				_try_connect(surface_id, coord + Vector2i(-1, - _gravity_dir), SurfaceType.FLOOR_TOP)
		SurfaceType.WALL_RIGHT:
			_try_connect(surface_id, coord + Vector2i(0, -1), SurfaceType.WALL_RIGHT)
			_try_connect(surface_id, coord + Vector2i(0, 1), SurfaceType.WALL_RIGHT)
			_try_connect(surface_id, coord + Vector2i(0, - _gravity_dir), SurfaceType.FLOOR_TOP)
			if _is_corner_passable(coord.x, coord.y - _gravity_dir):
				_try_connect(surface_id, coord + Vector2i(1, - _gravity_dir), SurfaceType.FLOOR_TOP)

func _connect_jumps_by_rules(surface_id: int, surface: Dictionary) -> void :
	var coord: Vector2i = surface.coord
	var surface_type: int = surface.type
	var x: int = coord.x
	var y: int = coord.y

	match surface_type:
		SurfaceType.FLOOR_TOP:
			_connect_floor_jumps(surface_id, x, y)
		SurfaceType.WALL_LEFT:
			_connect_wall_left_jumps(surface_id, x, y)
		SurfaceType.WALL_RIGHT:
			_connect_wall_right_jumps(surface_id, x, y)

func _connect_floor_jumps(surface_id: int, x: int, y: int) -> void :
	_try_jump_if_gap_empty(surface_id, x, y, x + 2, y, SurfaceType.FLOOR_TOP, x + 1, y)
	_try_jump_if_gap_empty(surface_id, x, y, x - 2, y, SurfaceType.FLOOR_TOP, x - 1, y)
	_connect_floor_cross_jumps(surface_id, x, y)

func _connect_wall_left_jumps(surface_id: int, x: int, y: int) -> void :
	_try_jump_if_gap_empty(surface_id, x, y, x, y + 2, SurfaceType.WALL_LEFT, x, y + 1)
	_try_jump_if_gap_empty(surface_id, x, y, x, y - 2, SurfaceType.WALL_LEFT, x, y - 1)
	_connect_wall_cross_jumps(surface_id, x, y)

func _connect_wall_right_jumps(surface_id: int, x: int, y: int) -> void :
	_try_jump_if_gap_empty(surface_id, x, y, x, y + 2, SurfaceType.WALL_RIGHT, x, y + 1)
	_try_jump_if_gap_empty(surface_id, x, y, x, y - 2, SurfaceType.WALL_RIGHT, x, y - 1)
	_connect_wall_cross_jumps(surface_id, x, y)

func _try_jump_if_gap_empty(from_id: int, from_x: int, from_y: int, to_x: int, to_y: int, to_type: int, gap_x: int, gap_y: int) -> void :
	var target_id: int = _get_surface_id(Vector2i(to_x, to_y), to_type)
	if not surface_nodes.has(target_id):
		return
	if _map_data.get_resourcev(Vector2(gap_x, gap_y)) >= 0:
		return
	if not pathfinder.are_points_connected(from_id, target_id):
		pathfinder.connect_points(from_id, target_id, true)
		pathfinder.mark_as_jump(from_id, target_id)

func _try_jump_floor_to_wall_c(from_id: int, from_x: int, from_y: int, to_x: int, to_y: int, to_type: int) -> void :
	var target_id: int = _get_surface_id(Vector2i(to_x, to_y), to_type)
	if surface_nodes.has(target_id):
		if not pathfinder.are_points_connected(from_id, target_id):
			pathfinder.connect_points(from_id, target_id, false)
			pathfinder.mark_as_jump(from_id, target_id)

func _try_jump_wall_to_floor_c(from_id: int, from_x: int, from_y: int, to_x: int, to_y: int, to_type: int) -> void :
	var target_id: int = _get_surface_id(Vector2i(to_x, to_y), to_type)
	if surface_nodes.has(target_id):
		if not pathfinder.are_points_connected(from_id, target_id):
			pathfinder.connect_points(from_id, target_id, false)
			pathfinder.mark_as_jump(from_id, target_id)

func _try_connect(from_id: int, target_coord: Vector2i, target_type: int) -> void :
	var target_id: = _get_surface_id(target_coord, target_type)
	if surface_nodes.has(target_id):
		pathfinder.connect_points(from_id, target_id, true)

func _get_surface_id(coord: Vector2i, surface_type: int) -> int:
	return ((coord.y + COORD_OFFSET_Y) * MAX_MAP_WIDTH + (coord.x + COORD_OFFSET_X)) * 4 + surface_type

func get_hole_hop_targets(hole_world_pos: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(Level.map):
		return result
	if not _map_data:
		return result

	var adjacent: = get_hole_adjacent_surfaces(hole_world_pos)
	for surface in adjacent:
		result.append({
			"position": surface.world_pos, 
			"surface_type": surface.type, 
			"coord": surface.coord, 
			"is_jump": true, 
			"rotation": _get_rotation_for_type(surface.type)
		})

	return result

func get_hole_adjacent_surfaces(hole_world_pos: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(Level.map):
		return result

	var hole_tile: Vector2 = Level.map.getTileCoord(hole_world_pos)
	var px: int = int(hole_tile.x)
	var py: int = int(hole_tile.y)
	var hole_coord: = Vector2i(px, py)

	var floor_id: int = _get_surface_id(hole_coord, SurfaceType.FLOOR_TOP)
	if surface_nodes.has(floor_id):
		result.append(surface_nodes[floor_id])

	var wall_left_id: int = _get_surface_id(hole_coord, SurfaceType.WALL_LEFT)
	if surface_nodes.has(wall_left_id) and _is_corner_passable(px, py - _gravity_dir):
		result.append(surface_nodes[wall_left_id])

	var wall_right_id: int = _get_surface_id(hole_coord, SurfaceType.WALL_RIGHT)
	if surface_nodes.has(wall_right_id) and _is_corner_passable(px, py - _gravity_dir):
		result.append(surface_nodes[wall_right_id])

	var vine_id: int = _get_surface_id(Vector2i(px, py + _gravity_dir), SurfaceType.VINE_CENTER)
	if surface_nodes.has(vine_id):
		result.append(surface_nodes[vine_id])

	return result

func _get_rotation_for_type(surface_type: int) -> float:
	match surface_type:
		SurfaceType.WALL_LEFT:
			return - PI / 2.0
		SurfaceType.WALL_RIGHT:
			return PI / 2.0
		_:
			return 0.0

func get_closest_surface(world_pos: Vector2) -> Dictionary:
	if not is_instance_valid(Level.map):
		return {}

	var tile_coord: Vector2 = Level.map.getTileCoord(world_pos)
	var cx: int = int(tile_coord.x)
	var cy: int = int(tile_coord.y)
	var best_surface: = {}
	var best_dist_sq: = INF

	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var coord: = Vector2i(cx + ox, cy + oy)
			if not coord_to_surfaces.has(coord):
				continue
			for surface_id in coord_to_surfaces[coord]:
				var surface: Dictionary = surface_nodes[surface_id]
				var dist_sq: float = surface.world_pos.distance_squared_to(world_pos)
				if dist_sq < best_dist_sq:
					best_dist_sq = dist_sq
					best_surface = surface

	return best_surface

func find_path(from_pos: Vector2, to_pos: Vector2) -> Array:
	var from_surface: = get_closest_surface(from_pos)
	var to_surface: = get_closest_surface(to_pos)

	if from_surface.is_empty() or to_surface.is_empty():
		return []

	var from_id: int = from_surface.id
	var to_id: int = to_surface.id

	if not pathfinder.has_point(from_id) or not pathfinder.has_point(to_id):
		return []

	if not are_connected(from_id, to_id):
		return []

	var id_path: PackedInt64Array = pathfinder.get_id_path(from_id, to_id)
	if id_path.is_empty():
		return []

	return _build_path_from_ids(id_path)

func _build_path_from_ids(id_path: PackedInt64Array) -> Array:
	var surface_result: = []
	var prev_surface_id: int = -1

	for i in range(id_path.size()):
		var point_id: int = id_path[i]
		if point_id >= CORNER_ID_OFFSET:
			continue
		if not surface_nodes.has(point_id):
			continue

		var surface: Dictionary = surface_nodes[point_id]
		var curr_type: int = surface.type

		var is_jump: = false
		if prev_surface_id >= 0:
			var key: int = pathfinder._make_connection_key(prev_surface_id, point_id)
			is_jump = pathfinder.jump_connections.has(key)

		surface_result.append({
			"position": surface.world_pos, 
			"surface_type": curr_type, 
			"coord": surface.coord, 
			"is_jump": is_jump, 
			"rotation": _get_rotation_for_type(curr_type), 
			"surface_id": point_id
		})

		prev_surface_id = point_id

	var final_result: = []
	for i in range(surface_result.size()):
		var current_node: Dictionary = surface_result[i]
		final_result.append(current_node)

		if i < surface_result.size() - 1:
			var next_node: Dictionary = surface_result[i + 1]
			if not next_node.is_jump:
				var corner: = _get_corner_waypoint(current_node, next_node)
				if not corner.is_empty():
					final_result.append(corner)

	return final_result

func _get_corner_waypoint(from_node: Dictionary, to_node: Dictionary) -> Dictionary:
	var from_coord: Vector2i = from_node.coord
	var to_coord: Vector2i = to_node.coord
	var from_type: int = from_node.surface_type
	var to_type: int = to_node.surface_type

	var tile_size: float = GameWorld.TILE_SIZE
	var tile_offset: Vector2 = CONST.TILE_OFFSET
	var from_base: Vector2 = Vector2(from_coord) * tile_size + tile_offset

	if from_coord == to_coord:
		if from_type == SurfaceType.FLOOR_TOP and to_type == SurfaceType.WALL_LEFT:
			return _make_corner(from_base + Vector2( - HALF_TILE_SIZE, HALF_TILE_SIZE * _gravity_dir), from_node)
		if from_type == SurfaceType.FLOOR_TOP and to_type == SurfaceType.WALL_RIGHT:
			return _make_corner(from_base + Vector2(HALF_TILE_SIZE, HALF_TILE_SIZE * _gravity_dir), from_node)
		if from_type == SurfaceType.WALL_LEFT and to_type == SurfaceType.FLOOR_TOP:
			return _make_corner(from_base + Vector2( - HALF_TILE_SIZE, HALF_TILE_SIZE * _gravity_dir), from_node)
		if from_type == SurfaceType.WALL_RIGHT and to_type == SurfaceType.FLOOR_TOP:
			return _make_corner(from_base + Vector2(HALF_TILE_SIZE, HALF_TILE_SIZE * _gravity_dir), from_node)

	var dx: int = to_coord.x - from_coord.x
	var dy: int = to_coord.y - from_coord.y

	if from_type == SurfaceType.FLOOR_TOP and to_type == SurfaceType.WALL_RIGHT:
		if dx == -1 and dy == _gravity_dir:
			return _make_corner(from_base + Vector2( - HALF_TILE_SIZE, HALF_TILE_SIZE * _gravity_dir), from_node)

	if from_type == SurfaceType.FLOOR_TOP and to_type == SurfaceType.WALL_LEFT:
		if dx == 1 and dy == _gravity_dir:
			return _make_corner(from_base + Vector2(HALF_TILE_SIZE, HALF_TILE_SIZE * _gravity_dir), from_node)

	if from_type == SurfaceType.WALL_LEFT and to_type == SurfaceType.FLOOR_TOP:
		if (dx == -1 and dy == - _gravity_dir) or (dx == 0 and dy == - _gravity_dir):
			return _make_corner(from_base + Vector2( - HALF_TILE_SIZE, - HALF_TILE_SIZE * _gravity_dir), from_node)

	if from_type == SurfaceType.WALL_RIGHT and to_type == SurfaceType.FLOOR_TOP:
		if (dx == 1 and dy == - _gravity_dir) or (dx == 0 and dy == - _gravity_dir):
			return _make_corner(from_base + Vector2(HALF_TILE_SIZE, - HALF_TILE_SIZE * _gravity_dir), from_node)

	return {}

func _make_corner(pos: Vector2, from_node: Dictionary) -> Dictionary:
	return {
		"position": pos, 
		"surface_type": from_node.surface_type, 
		"coord": from_node.coord, 
		"is_jump": false, 
		"rotation": from_node.rotation
	}

func get_adjacent_surface(world_pos: Vector2) -> Dictionary:
	if not is_instance_valid(Level.map):
		return {}

	var tile_coord: Vector2 = Level.map.getTileCoord(world_pos)
	var cx: int = int(tile_coord.x)
	var cy: int = int(tile_coord.y)

	var floor_surface: = {}
	var floor_dist_sq: = INF
	var wall_surface: = {}
	var wall_dist_sq: = INF
	var vine_surface: = {}
	var vine_dist_sq: = INF

	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var coord: = Vector2i(cx + ox, cy + oy)
			if not coord_to_surfaces.has(coord):
				continue
			for surface_id in coord_to_surfaces[coord]:
				var surface: Dictionary = surface_nodes[surface_id]
				var surface_type: int = surface.type
				var dist_sq: float = surface.world_pos.distance_squared_to(world_pos)

				if dist_sq > ADJACENT_DISTANCE_SQ:
					continue

				if surface_type == SurfaceType.FLOOR_TOP:
					if dist_sq < floor_dist_sq:
						floor_dist_sq = dist_sq
						floor_surface = surface
				elif surface_type == SurfaceType.WALL_LEFT or surface_type == SurfaceType.WALL_RIGHT:
					if dist_sq < wall_dist_sq:
						wall_dist_sq = dist_sq
						wall_surface = surface
				elif surface_type == SurfaceType.VINE_CENTER:
					if dist_sq < vine_dist_sq:
						vine_dist_sq = dist_sq
						vine_surface = surface

	if not floor_surface.is_empty():
		return {"position": floor_surface.world_pos, "surface_type": floor_surface.type}
	if not wall_surface.is_empty():
		return {"position": wall_surface.world_pos, "surface_type": wall_surface.type}
	if not vine_surface.is_empty():
		return {"position": vine_surface.world_pos, "surface_type": vine_surface.type}
	return {}

func is_surface_adjacent(surface_world_pos: Vector2, reference_pos: Vector2) -> bool:
	return surface_world_pos.distance_squared_to(reference_pos) <= ADJACENT_DISTANCE_SQ

func get_surfaces_adjacent_to(world_pos: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(Level.map):
		return result

	var tile_coord: Vector2 = Level.map.getTileCoord(world_pos)
	var cx: int = int(tile_coord.x)
	var cy: int = int(tile_coord.y)

	var sort_pos: Vector2 = world_pos
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var coord: = Vector2i(cx + ox, cy + oy)
			if not coord_to_surfaces.has(coord):
				continue
			for surface_id in coord_to_surfaces[coord]:
				var surface: Dictionary = surface_nodes[surface_id]
				var dist_sq: float = surface.world_pos.distance_squared_to(world_pos)
				if dist_sq <= ADJACENT_DISTANCE_SQ:
					result.append(surface)

	result.sort_custom( func(a, b): return a.world_pos.distance_squared_to(sort_pos) < b.world_pos.distance_squared_to(sort_pos))
	return result

func find_path_to_adjacent_surface(from_pos: Vector2, reference_pos: Vector2) -> Array:
	var from_surface: = get_closest_surface(from_pos)
	if from_surface.is_empty():
		return []

	var hole_tile: Vector2 = Level.map.getTileCoord(reference_pos)
	var hx: int = int(hole_tile.x)
	var hy: int = int(hole_tile.y)
	var hole_coord: = Vector2i(hx, hy)
	var adjacent_surfaces: Array[Dictionary] = []
	for st in [SurfaceType.FLOOR_TOP, SurfaceType.WALL_LEFT, SurfaceType.WALL_RIGHT]:
		var sid: int = _get_surface_id(hole_coord, st)
		if surface_nodes.has(sid):
			adjacent_surfaces.append(surface_nodes[sid])
	var vine_id: int = _get_surface_id(Vector2i(hx, hy + _gravity_dir), SurfaceType.VINE_CENTER)
	if surface_nodes.has(vine_id):
		adjacent_surfaces.append(surface_nodes[vine_id])

	if adjacent_surfaces.is_empty():
		return []

	var from_id: int = from_surface.id
	if not pathfinder.has_point(from_id):
		return []

	var best_path: Array = []
	var best_cost: = INF

	for adj_surface in adjacent_surfaces:
		var to_id: int = adj_surface.id
		if not pathfinder.has_point(to_id):
			continue
		if not are_connected(from_id, to_id):
			continue

		var id_path: PackedInt64Array = pathfinder.get_id_path(from_id, to_id)
		if id_path.is_empty():
			continue

		var cost: float = id_path.size()
		if cost < best_cost:
			best_cost = cost
			best_path = _build_path_from_ids(id_path)

	return best_path

func _try_cross_orientation_jump(from_id: int, to_coord: Vector2i, to_type: int) -> void :
	var target_id: int = _get_surface_id(to_coord, to_type)
	if not surface_nodes.has(target_id):
		return
	if pathfinder.are_points_connected(from_id, target_id):
		return
	pathfinder.connect_points(from_id, target_id, true)
	pathfinder.mark_as_jump(from_id, target_id)

func _connect_floor_cross_jumps(surface_id: int, x: int, y: int) -> void :
	var adjacent: = [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]
	for coord in adjacent:
		_try_cross_orientation_jump(surface_id, coord, SurfaceType.WALL_LEFT)
		_try_cross_orientation_jump(surface_id, coord, SurfaceType.WALL_RIGHT)

func _connect_wall_cross_jumps(surface_id: int, x: int, y: int) -> void :
	var adjacent: = [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]
	for coord in adjacent:
		_try_cross_orientation_jump(surface_id, coord, SurfaceType.FLOOR_TOP)
		_try_cross_orientation_jump(surface_id, coord, SurfaceType.WALL_LEFT)
		_try_cross_orientation_jump(surface_id, coord, SurfaceType.WALL_RIGHT)

func cleanup() -> void :
	pathfinder.clear()
	pathfinder.clear_jumps()
	surface_nodes.clear()
	coord_to_surfaces.clear()
	corner_nodes.clear()
	_uf_parent.clear()
	_map_data = null

func get_all_surfaces_in_range(center: Vector2, radius: float) -> Array:
	var result: Array = []
	var radius_sq: float = radius * radius

	for surface_id in surface_nodes:
		var surface: Dictionary = surface_nodes[surface_id]
		var dist_sq: float = surface.world_pos.distance_squared_to(center)
		if dist_sq <= radius_sq:
			result.append(surface)

	return result
