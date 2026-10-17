class_name GoblinTaskManager
extends RefCounted

const HOLE_RADIUS_TILES: int = int(Keeper4GameplaySettings.HOLE_RADIUS / GoblinNavigator.TILE_SIZE)
const CAT_RADIUS_TILES: int = HOLE_RADIUS_TILES + 1
const CAT_RADIUS_TILES_SQ: int = CAT_RADIUS_TILES * CAT_RADIUS_TILES
const CAT_RADIUS_SQ: float = Keeper4GameplaySettings.HOLE_RADIUS * Keeper4GameplaySettings.HOLE_RADIUS
const RESOURCE_GRAB_RANGE_TILES: int = 9
const RESOURCE_GRAB_RANGE_SQ: float = (RESOURCE_GRAB_RANGE_TILES * GoblinNavigator.TILE_SIZE) * (RESOURCE_GRAB_RANGE_TILES * GoblinNavigator.TILE_SIZE)
const MATCH_BUDGET_PER_FRAME: int = 10
const HOLE_BUDGET_PER_FRAME: int = 3
const GOBLINS_GROUP: StringName = &"keeper4_goblins"
const EXCLUDED_DROP_TYPES = [CONST.RELIC, CONST.GADGET, CONST.POWERCORE]

var teamId: String
var _holes_group: StringName

var _navigator: GoblinNavigator = null
var _tree_provider: Node = null
var _resource_claims: Dictionary
var _mining_claims: Dictionary
var _surface_claims: Dictionary
var _hop_claims: Dictionary
var _occupied_owners_cache: Dictionary = {}
var _occupied_owners_cache_frame: int = -1
var _idle_cellar_goblins: Array[Goblin] = []
var _idle_match_cursor: int = 0
var _drops_hole_cursor: int = 0
var _mining_hole_cursor: int = 0
func _init(navigator: GoblinNavigator, tree_provider: Node, 
		resource_claims: Dictionary = {}, 
		mining_claims: Dictionary = {}, 
		surface_claims: Dictionary = {}, 
		hop_claims: Dictionary = {}):
	_navigator = navigator
	_tree_provider = tree_provider
	_resource_claims = resource_claims
	_mining_claims = mining_claims
	_surface_claims = surface_claims
	_hop_claims = hop_claims

func get_navigator() -> GoblinNavigator:
	return _navigator

func set_team_id(value: String) -> void :
	teamId = value
	_holes_group = StringName(value + "-goblin_holes")

func claim_resource(goblin: Node, resource: Node) -> bool:
	if _resource_claims.has(resource):
		return _resource_claims[resource] == goblin
	_resource_claims[resource] = goblin
	return true

func release_resource(goblin: Node, resource: Node) -> void :
	if _resource_claims.has(resource) and _resource_claims[resource] == goblin:
		_resource_claims.erase(resource)

func claim_mining_tile(goblin: Node, tile_coord: Vector2) -> bool:
	if _mining_claims.has(tile_coord):
		return _mining_claims[tile_coord] == goblin
	_mining_claims[tile_coord] = goblin
	return true

func release_mining_tile(goblin: Node, tile_coord: Vector2) -> void :
	if _mining_claims.has(tile_coord) and _mining_claims[tile_coord] == goblin:
		_mining_claims.erase(tile_coord)

func claim_surface(goblin: Node, coord: Vector2i) -> bool:
	if _surface_claims.has(coord):
		return _surface_claims[coord] == goblin
	_surface_claims[coord] = goblin
	return true

func release_surface(goblin: Node) -> void :
	var to_erase: Array = []
	for coord in _surface_claims:
		if _surface_claims[coord] == goblin:
			to_erase.append(coord)
	for coord in to_erase:
		_surface_claims.erase(coord)

func claim_hop_target(goblin: Node, coord: Vector2i) -> bool:
	if _hop_claims.has(coord):
		return _hop_claims[coord] == goblin
	_hop_claims[coord] = goblin
	return true

func release_hop_target(goblin: Node) -> void :
	var to_erase: Array = []
	for coord in _hop_claims:
		if _hop_claims[coord] == goblin:
			to_erase.append(coord)
	for coord in to_erase:
		_hop_claims.erase(coord)

func release_all_claims(goblin: Node) -> void :
	var res_to_erase: Array = []
	for resource in _resource_claims:
		if _resource_claims[resource] == goblin:
			res_to_erase.append(resource)
	for resource in res_to_erase:
		_resource_claims.erase(resource)
	var mine_to_erase: Array = []
	for coord in _mining_claims:
		if _mining_claims[coord] == goblin:
			mine_to_erase.append(coord)
	for coord in mine_to_erase:
		_mining_claims.erase(coord)
	release_surface(goblin)
	release_hop_target(goblin)

func cleanup_invalid_claims() -> void :
	var res_to_erase: Array = []
	for resource in _resource_claims:
		if not is_instance_valid(resource) or not is_instance_valid(_resource_claims[resource]):
			res_to_erase.append(resource)
	for resource in res_to_erase:
		_resource_claims.erase(resource)
	var mine_to_erase: Array = []
	for coord in _mining_claims:
		if not is_instance_valid(_mining_claims[coord]):
			mine_to_erase.append(coord)
		elif is_instance_valid(Level.map) and not Level.map.tiles.has(coord):
			mine_to_erase.append(coord)
	for coord in mine_to_erase:
		_mining_claims.erase(coord)
	var surf_to_erase: Array = []
	for coord in _surface_claims:
		if not is_instance_valid(_surface_claims[coord]):
			surf_to_erase.append(coord)
	for coord in surf_to_erase:
		_surface_claims.erase(coord)
	var hop_to_erase: Array = []
	for coord in _hop_claims:
		if not is_instance_valid(_hop_claims[coord]):
			hop_to_erase.append(coord)
	for coord in hop_to_erase:
		_hop_claims.erase(coord)

func request_task(goblin: Node) -> bool:
	return _request_underground_task(goblin)

func enqueue_idle_goblin(goblin: Goblin) -> void :
	if _idle_cellar_goblins.has(goblin):
		return
	_idle_cellar_goblins.append(goblin)

func dequeue_idle_goblin(goblin: Goblin) -> void :
	_idle_cellar_goblins.erase(goblin)

func match_pending_tasks() -> void :
	if _idle_cellar_goblins.is_empty():
		return
	var holes: = _get_nodes_in_group(_holes_group)
	if _drops_hole_cursor >= holes.size():
		_drops_hole_cursor = 0
	if _mining_hole_cursor >= holes.size():
		_mining_hole_cursor = 0
	var drops_window: Array = slice_holes(holes, _drops_hole_cursor, HOLE_BUDGET_PER_FRAME)
	_drops_hole_cursor = (_drops_hole_cursor + HOLE_BUDGET_PER_FRAME) % maxi(holes.size(), 1)
	var reachable_drops: Array = _build_reachable_drops_cache(drops_window)
	var cellar_drops: Array = _build_cellar_drops_cache()
	var mining_cache: Array = []
	var mining_cache_built: bool = false
	var count: int = _idle_cellar_goblins.size()
	var budget: int = min(MATCH_BUDGET_PER_FRAME, count)
	if _idle_match_cursor >= count:
		_idle_match_cursor = 0
	var processed: int = 0
	var i: int = _idle_match_cursor
	while processed < budget and not _idle_cellar_goblins.is_empty():
		if i >= _idle_cellar_goblins.size():
			i = 0
		var goblin: Goblin = _idle_cellar_goblins[i]
		processed += 1
		_release_goblin_resource_claims(goblin)
		var cellar_uid: = _pop_cellar_drop_for(goblin, cellar_drops)
		if cellar_uid != -1:
			_idle_cellar_goblins.remove_at(i)
			if not goblin.accept_cellar_resource_task(cellar_uid):
				if Level.drops.has_drop(cellar_uid):
					release_resource(goblin, Level.drops.get_drop(cellar_uid))
			continue
		var resource_hole: = _pop_reachable_drop_for(goblin, reachable_drops)
		if resource_hole:
			_idle_cellar_goblins.remove_at(i)
			goblin.assign_task(resource_hole)
			continue
		if goblin.get_mining_speed() > 0.0:
			if not mining_cache_built:
				var mining_window: Array = slice_holes(holes, _mining_hole_cursor, HOLE_BUDGET_PER_FRAME)
				_mining_hole_cursor = (_mining_hole_cursor + HOLE_BUDGET_PER_FRAME) % maxi(holes.size(), 1)
				mining_cache = _build_mining_cache(mining_window)
				mining_cache_built = true
			var mining_entry: = _pop_mining_for(goblin, mining_cache)
			if not mining_entry.is_empty():
				_idle_cellar_goblins.remove_at(i)
				goblin.assign_mining_task(mining_entry.hole, mining_entry.tile, mining_entry.tile_coord)
				continue
		i += 1
	_idle_match_cursor = i

func slice_holes(holes: Array, start: int, count: int) -> Array:
	var n: int = holes.size()
	if n == 0:
		return []
	var result: Array = []
	var taken: int = 0
	var i: int = start
	while taken < count and taken < n:
		result.append(holes[i % n])
		i += 1
		taken += 1
	return result

func _build_reachable_drops_cache(holes: Array) -> Array:
	var result: Array = []
	var seen_drops: Dictionary = {}
	var shuffled: = holes.duplicate()
	shuffled.shuffle()
	for hole in shuffled:
		if not is_instance_valid(hole) or hole.is_entrance_hole:
			continue
		if hole.hole_state != hole.HoleState.DUG_OUT:
			continue
		for entry in hole.get_reachable_drops(_navigator):
			var drop = entry.drop
			if seen_drops.has(drop):
				continue
			if not is_instance_valid(drop):
				continue
			var grabbable: bool = drop.carriedBy.is_empty()
			if not grabbable:
				grabbable = true
				for c in drop.carriedBy.duplicate():
					if not is_instance_valid(c):
						drop.carriedBy.erase(c)
						continue
					if not (c is KunaiCarrier) or not c.attached:
						grabbable = false
						break
			if not grabbable:
				continue
			if drop.independent or drop.isAutoTransported:
				continue
			if _resource_claims.has(drop):
				continue
			seen_drops[drop] = true
			result.append(entry)
	return result

func _build_mining_cache(holes: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	var shuffled: = holes.duplicate()
	shuffled.shuffle()
	for hole in shuffled:
		if not is_instance_valid(hole) or hole.is_entrance_hole:
			continue
		if hole.hole_state != hole.HoleState.DUG_OUT:
			continue
		var mineables: Array = hole.get_mineable_tiles(_navigator)
		for c in mineables:
			var tile_coord: Vector2 = c.tile_coord
			if seen.has(tile_coord):
				continue
			seen[tile_coord] = true
			if _mining_claims.has(tile_coord):
				continue
			var tile = c.tile
			if not is_instance_valid(tile):
				continue
			var path: = _navigator.get_surface_path(hole.global_position, c.surface_pos)
			if path.is_empty():
				continue
			result.append({"hole": hole, "tile": tile, "tile_coord": tile_coord})
	return result

func _pop_mining_for(goblin: Goblin, mining_cache: Array) -> Dictionary:
	if mining_cache.is_empty():
		return {}
	var entry: Dictionary = mining_cache[0]
	mining_cache.remove_at(0)
	_mining_claims[entry.tile_coord] = goblin
	return entry

func _pop_reachable_drop_for(goblin: Goblin, reachable_drops: Array) -> Node2D:
	while not reachable_drops.is_empty():
		var entry: Dictionary = reachable_drops[0]
		reachable_drops.remove_at(0)
		var drop = entry.drop
		var hole = entry.hole
		if not is_instance_valid(drop) or not is_instance_valid(hole):
			continue
		if _resource_claims.has(drop):
			continue
		_resource_claims[drop] = goblin
		return hole
	return null

func _build_cellar_drops_cache() -> Array:
	var result: Array = []
	for area in Level.getDome(teamId).get_node("GoblinCellarResourceDetector").get_overlapping_areas():
		var drop = area.get_parent()
		if drop is Drop and drop.gravity_scale == 0.0 and drop.linear_damp == 1.0\
		and drop.carriedBy.is_empty() and not _resource_claims.has(drop)\
		and not EXCLUDED_DROP_TYPES.has(drop.type):
			result.append(drop)
	return result

func _pop_cellar_drop_for(goblin: Goblin, cellar_drops: Array) -> int:
	if cellar_drops.is_empty():
		return -1
	var picked = cellar_drops.pop_front()
	_resource_claims[picked] = goblin
	return picked.UID

func _release_goblin_resource_claims(goblin: Goblin) -> void :
	var to_erase: Array = []
	for drop in _resource_claims:
		if _resource_claims[drop] == goblin:
			to_erase.append(drop)
	for drop in to_erase:
		_resource_claims.erase(drop)

func _request_underground_task(goblin: Node) -> bool:
	var from_pos: Vector2 = goblin.global_position
	if Level.drops.has_drop(goblin.carried_resource_uid):
		return _assign_return_hole(goblin, from_pos)
	_release_goblin_resource_claims(goblin)
	if _try_pinned_mining_task(goblin, from_pos):
		return true
	var resource_info: Dictionary = find_resource_task(goblin, from_pos)
	if not resource_info.is_empty():
		var resource = resource_info.get("resource")
		var path: Array = resource_info.get("path", [])
		if is_instance_valid(resource) and claim_resource(goblin, resource):
			if goblin.accept_resource_task(resource.UID, path):
				return true
			release_resource(goblin, resource)
	var mining_speed: float = goblin.get_mining_speed()
	if mining_speed > 0.0:
		var holes = _get_nodes_in_group(_holes_group)
		holes.sort_custom( func(a, b): return from_pos.distance_squared_to(a.global_position) < from_pos.distance_squared_to(b.global_position))
		for hole in holes:
			if not is_instance_valid(hole) or hole.is_entrance_hole:
				continue
			if hole.hole_state != hole.HoleState.DUG_OUT:
				continue
			var tile_info: Dictionary = find_mining_task(goblin, hole, from_pos)
			if not tile_info.is_empty():
				var tile_coord = tile_info.get("tile_coord")
				if claim_mining_tile(goblin, tile_coord):
					if goblin.accept_mining_task(hole, tile_info.get("tile"), tile_coord, tile_info.get("path", [])):
						return true
					release_mining_tile(goblin, tile_coord)
	return _assign_return_hole(goblin, from_pos)

func _try_pinned_mining_task(goblin: Node, from_pos: Vector2) -> bool:
	var pinned_coord: Vector2 = goblin._pinned_mining_tile_coord
	if pinned_coord == Vector2.ZERO:
		return false
	var pinned_tile = goblin._pinned_mining_tile
	var pinned_hole = goblin._assigned_hole_for_mining
	goblin._pinned_mining_tile = null
	goblin._pinned_mining_tile_coord = Vector2.ZERO
	if not is_instance_valid(pinned_tile) or not Level.map.tiles.has(pinned_coord):
		release_mining_tile(goblin, pinned_coord)
		return false
	if not (pinned_tile.type == CONST.IRON or pinned_tile.type == CONST.SAND or pinned_tile.type == CONST.WATER):
		release_mining_tile(goblin, pinned_coord)
		return false
	var adjacent_info: = _navigator.find_surface_adjacent_to_tile(pinned_coord)
	if adjacent_info.is_empty():
		release_mining_tile(goblin, pinned_coord)
		return false
	var path: = _navigator.get_surface_path(from_pos, adjacent_info.position)
	if path.is_empty():
		release_mining_tile(goblin, pinned_coord)
		return false
	if not goblin.accept_mining_task(pinned_hole, pinned_tile, pinned_coord, path):
		release_mining_tile(goblin, pinned_coord)
		return false
	return true

func _assign_return_hole(goblin: Node, from_pos: Vector2) -> bool:
	var hole_info: Dictionary = find_return_hole(from_pos)
	if not hole_info.is_empty():
		var hole = hole_info.get("hole")
		var path: Array = hole_info.get("path", [])
		if is_instance_valid(hole) and not goblin.is_target_blacklisted(hole.get_instance_id()):
			return goblin.accept_return_task(hole, path)
	return false

func find_resource_task(goblin: Goblin, from_pos: Vector2) -> Dictionary:
	if not _navigator:
		return {}
	var seen: Dictionary = {}
	var origin_hole = goblin._origin_hole if is_instance_valid(goblin._origin_hole) else null
	if origin_hole and not origin_hole.is_entrance_hole and origin_hole.hole_state == origin_hole.HoleState.DUG_OUT:
		var origin_result: = _pick_best_drop_from_hole(goblin, from_pos, origin_hole, seen)
		if not origin_result.is_empty():
			return origin_result
	var holes: = _get_nodes_in_group(_holes_group)
	var best: Dictionary = {}
	var best_score: float = INF
	for hole in holes:
		if not is_instance_valid(hole) or hole.is_entrance_hole:
			continue
		if hole.hole_state != hole.HoleState.DUG_OUT:
			continue
		if hole == origin_hole:
			continue
		var hole_best: = _pick_best_drop_from_hole(goblin, from_pos, hole, seen)
		if hole_best.is_empty():
			continue
		var score: float = hole_best.get("score", INF)
		if score < best_score:
			best_score = score
			best = hole_best
	return best

func _pick_best_drop_from_hole(goblin: Goblin, from_pos: Vector2, hole: GoblinHole, seen: Dictionary) -> Dictionary:
	var best_drop = null
	var best_score: float = INF
	var best_path: Array = []
	for drop in hole.get_nearby_resources():
		if seen.has(drop):
			continue
		seen[drop] = true
		if _resource_claims.has(drop) and _resource_claims[drop] != goblin:
			continue
		if goblin.is_target_blacklisted(drop.UID):
			continue
		var dist_sq: float = from_pos.distance_squared_to(drop.global_position)
		if dist_sq > RESOURCE_GRAB_RANGE_SQ:
			continue
		var path: = GoblinHole.find_path_within_length(_navigator, from_pos, drop.global_position)
		if path.is_empty():
			continue
		var path_end: Vector2 = path[path.size() - 1].get("position", Vector2.ZERO)
		if path_end.distance_squared_to(drop.global_position) > Goblin.MAX_GRAB_DISTANCE_SQ:
			continue
		if path.size() < best_score:
			best_score = path.size()
			best_drop = drop
			best_path = path
	if best_drop:
		return {"resource": best_drop, "score": best_score, "path": best_path}
	return {}

func find_mining_task(goblin: Goblin, hole: GoblinHole, from_pos: Vector2) -> Dictionary:
	if not _navigator or not is_instance_valid(Level.map) or not _navigator.has_surface_pathfinding():
		return {}
	if not is_instance_valid(hole):
		return {}
	var base_candidates: Array = hole.get_mineable_tiles(_navigator)
	if base_candidates.is_empty():
		return {}

	var candidates: Array = []
	for c in base_candidates:
		var tile = c.tile
		if not is_instance_valid(tile):
			continue
		if not (tile.type == CONST.IRON or tile.type == CONST.SAND or tile.type == CONST.WATER):
			continue
		if tile.hasTileOverlay():
			continue
		var tile_coord: Vector2 = c.tile_coord
		if _mining_claims.has(tile_coord) and _mining_claims[tile_coord] != goblin:
			continue
		var surface_pos: Vector2 = c.surface_pos
		candidates.append({
			"tile": tile, 
			"tile_coord": tile_coord, 
			"surface_pos": surface_pos, 
			"health": tile.health, 
			"dist_sq": surface_pos.distance_squared_to(from_pos)
		})

	if candidates.is_empty():
		return {}
	candidates.sort_custom( func(a, b): return a.dist_sq < b.dist_sq)
	for candidate in candidates:
		var path: = _navigator.get_surface_path(from_pos, candidate.surface_pos)
		if not path.is_empty():
			return {
				"tile": candidate.tile, 
				"tile_coord": candidate.tile_coord, 
				"path": path, 
				"health": candidate.health
			}
	return {}

func find_return_hole(from_pos: Vector2) -> Dictionary:
	if not _navigator:
		return {}
	return _navigator.find_closest_reachable_hole(from_pos)

func find_unclaimed_hop_target(goblin: Node, hole_pos: Vector2) -> Dictionary:
	if not _navigator:
		return {}
	var hop_targets: Array[Dictionary] = _navigator.get_hole_hop_targets(hole_pos)
	if hop_targets.is_empty():
		return {}
	var occupied: = _get_all_occupied_coords()
	for ht in hop_targets:
		var coord: Vector2i = ht.get("coord", Vector2i.ZERO)
		var owner = occupied.get(coord)
		if owner == null or owner == goblin:
			return ht
	return hop_targets[0]

func find_wander_point(goblin: Node, center: Vector2, radius: float, min_distance: float = 0.0) -> Dictionary:
	if not _navigator:
		return {}
	var occupied: = _get_all_occupied_coords()
	var goblin_pos: Vector2 = goblin.global_position
	return _navigator.find_random_reachable_point_in_range(center, radius, min_distance, occupied, goblin_pos, goblin)

func _get_nodes_in_group(group: StringName) -> Array[Node]:
	if not is_instance_valid(_tree_provider):
		return []
	return _tree_provider.get_tree().get_nodes_in_group(group)

func get_valid_holes() -> Array:
	var result: Array = []
	var holes = _get_nodes_in_group(_holes_group)
	for hole in holes:
		if not is_instance_valid(hole) or hole.is_entrance_hole:
			continue
		if hole.hole_state != hole.HoleState.DUG_OUT:
			continue
		result.append(hole)
	return result

func _get_all_occupied_coords() -> Dictionary:
	var current_frame: int = Engine.get_physics_frames()
	if _occupied_owners_cache_frame != current_frame:
		_occupied_owners_cache.clear()
		for coord in _surface_claims:
			_occupied_owners_cache[coord] = _surface_claims[coord]
		for coord in _hop_claims:
			_occupied_owners_cache[coord] = _hop_claims[coord]
		var goblins = _get_nodes_in_group(GOBLINS_GROUP)
		for goblin: Goblin in goblins:
			if not is_instance_valid(goblin):
				continue
			if goblin.teamId != teamId:
				continue
			if goblin.is_in_cellar:
				continue
			_occupied_owners_cache[goblin._current_surface_coord] = goblin
		_occupied_owners_cache_frame = current_frame
	return _occupied_owners_cache

func find_squad_mining_task(goblin: Node, hole_pos: Vector2, from_pos: Vector2, last_mined_coord: Vector2 = Vector2.ZERO, is_retry: bool = false) -> Dictionary:
	if not _navigator or not is_instance_valid(Level.map) or not _navigator.has_surface_pathfinding():
		return {}

	var hole_tile: Vector2 = Level.map.getTileCoord(hole_pos)

	var neighbor_candidates: Array = []
	var hole_candidates: Array = []
	var claimed_candidates: Array = []
	var checked: Dictionary = {}

	for dy in range( - HOLE_RADIUS_TILES, HOLE_RADIUS_TILES + 1):
		for dx in range( - HOLE_RADIUS_TILES, HOLE_RADIUS_TILES + 1):
			if abs(dy * dx) > CAT_RADIUS_TILES_SQ:
				continue
			var tile_coord: = Vector2(int(hole_tile.x) + dx, int(hole_tile.y) + dy)
			checked[tile_coord] = true

			var world_pos: Vector2 = tile_coord * GameWorld.TILE_SIZE + CONST.TILE_OFFSET
			if world_pos.distance_squared_to(hole_pos) > Keeper4GameplaySettings.HOLE_RADIUS_SQ:
				continue


			if not Level.map.tiles.has(tile_coord):
				continue
			var tile = Level.map.tiles[tile_coord]
			if tile.type == "border":
				continue
			if (tile.type == CONST.IRON or tile.type == CONST.SAND or tile.type == CONST.WATER):
				continue
			if tile.hasTileOverlay():
				continue
			if Data.ofOr(teamId + "seededTiles", []).has(tile.coord):
				continue
			if _mining_claims.has(tile_coord) and _mining_claims[tile_coord] != goblin:
				if not is_retry:
					continue
				claimed_candidates.append({"tile": tile, "tile_coord": tile_coord, "is_claimed": true})
				continue

			var candidate: Dictionary = {"tile": tile, "tile_coord": tile_coord, "is_claimed": false}
			if last_mined_coord != Vector2.ZERO:
				var diff_x: int = int(tile_coord.x - last_mined_coord.x)
				var diff_y: int = int(tile_coord.y - last_mined_coord.y)
				if (diff_x == 0 and (diff_y == 1 or diff_y == -1)) or (diff_y == 0 and (diff_x == 1 or diff_x == -1)):
					neighbor_candidates.append(candidate)
					continue
			hole_candidates.append(candidate)

	for candidates in [neighbor_candidates, hole_candidates]:
		var task: = _try_squad_candidates(goblin, candidates, from_pos)
		if not task.is_empty():
			return task

	if not claimed_candidates.is_empty():
		claimed_candidates.shuffle()
		for candidate in claimed_candidates:
			var result: = _find_path_to_claimed_tile(goblin, from_pos, candidate.tile_coord)
			if not result.is_empty():
				return {"tile": candidate.tile, "tile_coord": candidate.tile_coord, "path": result.path, "is_shared": true}

	return {}

func _try_squad_candidates(goblin: Node, candidates: Array, from_pos: Vector2) -> Dictionary:
	if candidates.is_empty():
		return {}

	for candidate in candidates:
		if not Level.map.tiles.has(candidate.tile_coord):
			continue
		if candidate.tile.type == CONST.GADGET or candidate.tile.type == CONST.RELIC or \
		candidate.tile.type == CONST.RELICSWITCH or candidate.tile.type == CONST.POWERCORE or \
		candidate.tile.type == CONST.NEST:
			var result: = _navigator.find_best_path_to_tile_surface(from_pos, candidate.tile_coord)
			if not result.is_empty():
				claim_mining_tile(goblin, candidate.tile_coord)
				return {"tile": candidate.tile, "tile_coord": candidate.tile_coord, "path": result.path}

	var gravity_down: Vector2 = Vector2.UP if Data.ofOr("world.inversegravity", false) else Vector2.DOWN
	for offsets in [[gravity_down], [Vector2.LEFT, Vector2.RIGHT], CONST.DIAGONALS]:
		for candidate in candidates:
			if not Level.map.tiles.has(candidate.tile_coord):
				continue
			for offset in offsets:
				var neighbor_coord: Vector2 = candidate.tile_coord + offset
				var type_index = Level.map.tileData.get_resource(neighbor_coord.x, neighbor_coord.y)
				if type_index >= 0 and type_index <= 9:
					var result: = _navigator.find_best_path_to_tile_surface(from_pos, candidate.tile_coord)
					if not result.is_empty():
						claim_mining_tile(goblin, candidate.tile_coord)
						return {"tile": candidate.tile, "tile_coord": candidate.tile_coord, "path": result.path}

	candidates.shuffle()
	for candidate in candidates:
		if not Level.map.tiles.has(candidate.tile_coord):
			continue
		var result: = _navigator.find_best_path_to_tile_surface(from_pos, candidate.tile_coord)
		if not result.is_empty():
			claim_mining_tile(goblin, candidate.tile_coord)
			return {"tile": candidate.tile, "tile_coord": candidate.tile_coord, "path": result.path}
	return {}

func _find_path_to_claimed_tile(goblin: Node, from_pos: Vector2, tile_coord: Vector2) -> Dictionary:
	var surfaces: = _navigator.find_all_surfaces_adjacent_to_tile(tile_coord)
	if surfaces.is_empty():
		return {}
	var claimer = _mining_claims.get(tile_coord)
	var claimer_surface_coord: Vector2i = claimer._current_surface_coord if is_instance_valid(claimer) else Vector2i.ZERO
	for surface in surfaces:
		if claimer_surface_coord != Vector2i.ZERO and surface.coord == claimer_surface_coord:
			continue
		var path: = _navigator.get_surface_path(from_pos, surface.position)
		if not path.is_empty():
			return {"path": path, "surface": surface}
	return {}
