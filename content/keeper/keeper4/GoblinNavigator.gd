class_name GoblinNavigator
extends RefCounted

const TILE_SIZE: = 24
const MAX_DETECTION_RANGE_TILES: = 5
const MAX_DETECTION_RANGE_SQ: = (MAX_DETECTION_RANGE_TILES * TILE_SIZE) * (MAX_DETECTION_RANGE_TILES * TILE_SIZE)
const WANDER_POSITION_OFFSET: = 12.0
const REBUILD_THROTTLE_MS: int = 100
const REBUILD_BUDGET_US: int = 5000

static var _navigators: Dictionary = {}

var _pathfinder: SurfacePathfinding = null
var _pathfinder_scratch: SurfacePathfinding = null
var _tile_count: = -1
var _dirty: = false
var _last_rebuild_ms: int = 0
var _graph_generation: int = 0
var _frame_chunk_budget_us: int = REBUILD_BUDGET_US
var _tree_provider: Node = null
var teamId: String

func tick() -> void :
	_frame_chunk_budget_us = REBUILD_BUDGET_US

func setup(teamId: String, tree_provider: Node) -> void :
	self.teamId = teamId
	_tree_provider = tree_provider
	_pathfinder = SurfacePathfinding.new()
	_navigators[teamId] = self

func _get_nodes_in_group(group: String) -> Array[Node]:
	if not is_instance_valid(_tree_provider):
		return []
	return _tree_provider.get_tree().get_nodes_in_group(group)

func _ensure_pathfinder_updated() -> void :
	if _tile_count == -1:
		var inverse_gravity: bool = Data.ofOr("world.inversegravity", false)
		_pathfinder.rebuild_from_map(Level.map, gather_vine_coords(inverse_gravity), inverse_gravity)
		_tile_count = Level.map.tiles.size()
		_dirty = false
		_last_rebuild_ms = Time.get_ticks_msec()
		_graph_generation += 1
		return

	if _pathfinder_scratch == null:
		if Level.map.tiles.size() == _tile_count and not _dirty:
			return
		if Time.get_ticks_msec() - _last_rebuild_ms < REBUILD_THROTTLE_MS:
			return
		if _frame_chunk_budget_us <= 0:
			return
		_pathfinder_scratch = SurfacePathfinding.new()
		var inverse_gravity: bool = Data.ofOr("world.inversegravity", false)
		_pathfinder_scratch.begin_rebuild(Level.map, gather_vine_coords(inverse_gravity), inverse_gravity)

	if _frame_chunk_budget_us <= 0:
		return
	var t0: int = Time.get_ticks_usec()
	var done: bool = _pathfinder_scratch.step_rebuild(_frame_chunk_budget_us)
	_frame_chunk_budget_us -= Time.get_ticks_usec() - t0
	if done:
		_pathfinder = _pathfinder_scratch
		_pathfinder_scratch = null
		_tile_count = Level.map.tiles.size()
		_dirty = false
		_last_rebuild_ms = Time.get_ticks_msec()
		_graph_generation += 1

func get_graph_generation() -> int:
	_ensure_pathfinder_updated()
	return _graph_generation

func flush_pending_rebuild() -> void :
	if _tile_count == -1:
		_ensure_pathfinder_updated()
		return
	if _pathfinder_scratch == null:
		if Level.map.tiles.size() == _tile_count and not _dirty:
			return
		_pathfinder_scratch = SurfacePathfinding.new()
		var inverse_gravity: bool = Data.ofOr("world.inversegravity", false)
		_pathfinder_scratch.begin_rebuild(Level.map, gather_vine_coords(inverse_gravity), inverse_gravity)
	while not _pathfinder_scratch.step_rebuild(1000000):
		pass
	_pathfinder = _pathfinder_scratch
	_pathfinder_scratch = null
	_tile_count = Level.map.tiles.size()
	_dirty = false
	_last_rebuild_ms = Time.get_ticks_msec()
	_graph_generation += 1

func gather_vine_coords(inverse_gravity: bool) -> Array[Vector2i]:
	var gravity_dir: int = -1 if inverse_gravity else 1
	var vine_coords: Array[Vector2i] = []
	var holes: = _get_nodes_in_group(teamId + "-goblin_holes")
	for hole in holes:
		if not is_instance_valid(hole) or hole.is_entrance_hole:
			continue
		if hole.hole_state != hole.HoleState.DUG_OUT:
			continue
		var pc: Vector2 = Level.map.getTileCoord(hole.global_position)
		var by: = int(pc.y) + gravity_dir
		var vine_count: = 0
		while vine_count < Keeper4GameplaySettings.HOLE_VINE_TILE_RANGE and Level.map.is_tile_empty(Vector2(pc.x, by)):
			vine_coords.append(Vector2i(int(pc.x), by))
			vine_count += 1
			by += gravity_dir
	return vine_coords

static func force_rebuild_for(team_id: String) -> void :
	if _navigators.has(team_id):
		_navigators[team_id]._dirty = true

static func force_rebuild_all() -> void :
	for nav in _navigators.values():
		nav._dirty = true

static func reset_all() -> void :
	_navigators.clear()

func has_vine_at(coord: Vector2i) -> bool:
	_ensure_pathfinder_updated()
	var vine_id: int = _pathfinder._get_surface_id(coord, SurfacePathfinding.SurfaceType.VINE_CENTER)
	return _pathfinder.surface_nodes.has(vine_id)

func has_surface_pathfinding() -> bool:
	return _pathfinder != null and is_instance_valid(Level.map)

func get_current_tile_count() -> int:
	if not is_instance_valid(Level.map):
		return -1
	return Level.map.tiles.size()

func get_surface_path(from_pos: Vector2, to_pos: Vector2) -> Array:
	if not has_surface_pathfinding():
		return []
	_ensure_pathfinder_updated()
	return _pathfinder.find_path(from_pos, to_pos)

func can_reach(from_pos: Vector2, to_pos: Vector2) -> bool:
	return get_surface_path(from_pos, to_pos).size() > 0

func find_closest_reachable_hole(from_pos: Vector2) -> Dictionary:
	var holes = _get_nodes_in_group(teamId + "-goblin_holes")
	var candidates: Array = []
	for hole in holes:
		if not is_instance_valid(hole):
			continue
		if hole.is_entrance_hole:
			continue
		if hole.hole_state != hole.HoleState.DUG_OUT:
			continue
		candidates.append({"hole": hole, "dist_sq": from_pos.distance_squared_to(hole.global_position)})
	if candidates.is_empty():
		return {}
	candidates.sort_custom( func(a, b): return a.dist_sq < b.dist_sq)
	for candidate in candidates:
		var path: = get_path_to_hole_adjacent_surface(from_pos, candidate.hole.global_position)
		if path.size() == 0:
			continue
		return {"hole": candidate.hole, "distance_sq": candidate.dist_sq, "path": path}
	return {}

func find_hole_adjacent_surface(hole_pos: Vector2) -> Dictionary:
	if not has_surface_pathfinding():
		return {}
	_ensure_pathfinder_updated()
	return _pathfinder.get_adjacent_surface(hole_pos)

func get_hole_hop_targets(hole_pos: Vector2) -> Array[Dictionary]:
	if not has_surface_pathfinding():
		return []
	_ensure_pathfinder_updated()
	return _pathfinder.get_hole_hop_targets(hole_pos)

func get_path_to_hole_adjacent_surface(from_pos: Vector2, hole_pos: Vector2) -> Array:
	if not has_surface_pathfinding():
		return []
	_ensure_pathfinder_updated()
	return _pathfinder.find_path_to_adjacent_surface(from_pos, hole_pos)

func is_position_adjacent_to_hole(position: Vector2, hole_pos: Vector2) -> bool:
	if not has_surface_pathfinding():
		return false
	_ensure_pathfinder_updated()
	var surface: Dictionary = _pathfinder.get_closest_surface(position)
	if surface.is_empty():
		return false
	var surface_to_goblin_dist_sq: float = surface.world_pos.distance_squared_to(position)
	var half_tile_sq: float = SurfacePathfinding.HALF_TILE_SIZE * SurfacePathfinding.HALF_TILE_SIZE
	if surface_to_goblin_dist_sq > half_tile_sq:
		return false
	return _pathfinder.is_surface_adjacent(surface.world_pos, hole_pos)

func find_random_reachable_point_in_range(center: Vector2, radius: float, min_distance: float = 0.0, excluded_coords: Dictionary = {}, from_pos = null, exclude_owner = null) -> Dictionary:
	if not has_surface_pathfinding():
		return {}
	_ensure_pathfinder_updated()

	var radius_sq: float = radius * radius
	var min_dist_sq: float = min_distance * min_distance
	var all_surfaces: Array = _pathfinder.get_all_surfaces_in_range(center, radius)

	if all_surfaces.is_empty():
		return {}

	all_surfaces.shuffle()

	var goblin_pos: Vector2 = center
	if from_pos != null:
		goblin_pos = from_pos
	elif is_instance_valid(_tree_provider):
		goblin_pos = _tree_provider.global_position

	for surface in all_surfaces:
		var surface_pos: Vector2 = surface.get("world_pos", Vector2.ZERO)
		var dist_sq: float = surface_pos.distance_squared_to(center)
		if dist_sq > radius_sq or dist_sq < min_dist_sq:
			continue

		var coord: Vector2i = surface.get("coord", Vector2i.ZERO)
		var owner = excluded_coords.get(coord)
		if owner != null and owner != exclude_owner:
			continue

		var path: = get_surface_path(goblin_pos, surface_pos)
		if not path.is_empty():
			var surface_type: int = surface.get("type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
			var offset: float = randf_range( - WANDER_POSITION_OFFSET, WANDER_POSITION_OFFSET)
			if surface_type == SurfacePathfinding.SurfaceType.FLOOR_TOP:
				surface_pos.x += offset
			else:
				surface_pos.y += offset
			path[path.size() - 1]["position"] = surface_pos
			return {"position": surface_pos, "path": path, "surface": surface}

	return {}

func find_surface_adjacent_to_tile(tile_coord: Vector2, skip_update: bool = false) -> Dictionary:
	if not has_surface_pathfinding():
		return {}
	if not skip_update:
		_ensure_pathfinder_updated()
	var gravity_dir: int = -1 if Data.ofOr("world.inversegravity", false) else 1
	var tile_world_pos: Vector2 = tile_coord * GameWorld.TILE_SIZE + CONST.TILE_OFFSET
	var tx: int = int(tile_coord.x)
	var ty: int = int(tile_coord.y)
	var adjacent_surfaces: Array[Dictionary] = _pathfinder.get_surfaces_adjacent_to(tile_world_pos)
	for surface in adjacent_surfaces:
		var sx: int = surface.coord.x
		var sy: int = surface.coord.y
		var on_surface: = false
		match surface.type:
			SurfacePathfinding.SurfaceType.FLOOR_TOP:
				on_surface = sx == tx and sy + gravity_dir == ty
			SurfacePathfinding.SurfaceType.WALL_LEFT:
				on_surface = sx - 1 == tx and sy == ty
			SurfacePathfinding.SurfaceType.WALL_RIGHT:
				on_surface = sx + 1 == tx and sy == ty
		if not on_surface:
			continue
		return {
			"position": surface.world_pos, 
			"surface_type": surface.type, 
			"coord": surface.coord
		}
	return {}

func find_all_surfaces_adjacent_to_tile(tile_coord: Vector2, skip_update: bool = false) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not has_surface_pathfinding():
		return results
	if not skip_update:
		_ensure_pathfinder_updated()
	var gravity_dir: int = -1 if Data.ofOr("world.inversegravity", false) else 1
	var tile_world_pos: Vector2 = tile_coord * GameWorld.TILE_SIZE + CONST.TILE_OFFSET
	var tx: int = int(tile_coord.x)
	var ty: int = int(tile_coord.y)
	var adjacent_surfaces: Array[Dictionary] = _pathfinder.get_surfaces_adjacent_to(tile_world_pos)
	for surface in adjacent_surfaces:
		var sx: int = surface.coord.x
		var sy: int = surface.coord.y
		var on_surface: = false
		match surface.type:
			SurfacePathfinding.SurfaceType.FLOOR_TOP:
				on_surface = sx == tx and sy + gravity_dir == ty
			SurfacePathfinding.SurfaceType.WALL_LEFT:
				on_surface = sx - 1 == tx and sy == ty
			SurfacePathfinding.SurfaceType.WALL_RIGHT:
				on_surface = sx + 1 == tx and sy == ty
		if on_surface:
			results.append({"position": surface.world_pos, "surface_type": surface.type, "coord": surface.coord})
	return results

func find_best_path_to_tile_surface(from_pos: Vector2, tile_coord: Vector2) -> Dictionary:
	var surfaces: = find_all_surfaces_adjacent_to_tile(tile_coord)
	var best_path: Array = []
	var best_length: float = INF
	var best_surface: Dictionary = {}
	for surface in surfaces:
		var path: = get_surface_path(from_pos, surface.position)
		if path.is_empty():
			continue
		var length: float = 0.0
		var prev: Vector2 = from_pos
		for node in path:
			length += prev.distance_to(node.position)
			prev = node.position
		if length < best_length:
			best_length = length
			best_path = path
			best_surface = surface
	if best_path.is_empty():
		return {}
	return {"path": best_path, "surface": best_surface}
