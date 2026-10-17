

extends Node



const SEGMENT_SIZE: float = 100.0

var _outside_map_segment: = Segment.new()
var _groups: Dictionary = {

}
var known_proxies: Dictionary = {

}

var _proxies_counter: int = -1


func reset(in_tilemap: TileMap) -> void :
	for proxy in known_proxies.values():
		if is_instance_valid(proxy):
			proxy.predelete.disconnect(_on_proxy_predelete)
			proxy.tree_exited.disconnect(_on_proxy_tree_exited)
			proxy.tree_reenter.disconnect(_on_proxy_tree_reenter)
			proxy.moved.disconnect(_on_proxy_moved)
	known_proxies.clear()
	initialize(in_tilemap)

func initialize(in_tilemap: TileMap) -> void :
	_proxies_counter = -1
	_outside_map_segment = Segment.new()
	_groups.clear()
	for group_name in ProximityProxy.Group:
		_groups[ProximityProxy.Group[group_name]] = Group.new()
	_fill_segments(in_tilemap)
	_register_proxies()

func _register_proxies() -> void :
	var proximity_proxies = Network.get_tree().get_nodes_in_group("ProximityProxy")
	for proximity_proxy: ProximityProxy in proximity_proxies:
		if not __is_proxy_registered(proximity_proxy):
			__register_new_proxy(proximity_proxy)

func _fill_segments(in_tilemap: TileMap) -> void :
	var used_rect = in_tilemap.get_used_rect()
	var tile_size = in_tilemap.tile_set.tile_size
	var world_size = used_rect.size * tile_size
	var top_left_local = in_tilemap.map_to_local(used_rect.position) - (Vector2(tile_size) / 2.0)
	var world_position = top_left_local + in_tilemap.global_position
	var world_rect = Rect2(world_position, Vector2(world_size))
	var top_left_safery_margin: = Vector2(SEGMENT_SIZE * 2, SEGMENT_SIZE * 2)
	var bottom_right_safery_margin: = Vector2(SEGMENT_SIZE * 2, SEGMENT_SIZE * 2)
	var start_pos = world_rect.position - top_left_safery_margin
	var end_pos = world_rect.position + world_rect.size + bottom_right_safery_margin * 2.0
	var start_id = Vector2i((start_pos / SEGMENT_SIZE).floor())
	var end_id = Vector2i((end_pos / SEGMENT_SIZE).ceil())
	for y in range(start_id.y, end_id.y):
		for x in range(start_id.x, end_id.x):
			var new_segment_id = Vector2i(x, y)
			for group in _groups.values():
				if not group.id_to_segment_map.has(new_segment_id):
					group.id_to_segment_map[new_segment_id] = Segment.new()

func __register_new_proxy(in_proxy: ProximityProxy) -> void :
	if known_proxies.has(in_proxy._id):
		return
	in_proxy._segment_id = Vector2i(-10000, -10000)
	_proxies_counter += 1
	in_proxy.set_id(_proxies_counter)
	in_proxy.predelete.connect(_on_proxy_predelete.bind(in_proxy))
	in_proxy.tree_exited.connect(_on_proxy_tree_exited.bind(in_proxy))
	in_proxy.tree_reenter.connect(_on_proxy_tree_reenter.bind(in_proxy))
	in_proxy.moved.connect(_on_proxy_moved.bind(in_proxy))
	_ensure_proxy_in_right_segment(in_proxy)
	known_proxies[in_proxy._id] = in_proxy

func __is_proxy_registered(in_proxy: ProximityProxy) -> bool:
	return known_proxies.has(in_proxy._id)

func _on_proxy_predelete(in_proxy: ProximityProxy) -> void :
	var group: Group = _groups[in_proxy.group]
	var segment: Segment = group.id_to_segment_map.get(in_proxy._segment_id, _outside_map_segment)
	segment.proxies.erase(in_proxy._id)
	known_proxies.erase(in_proxy._id)

func _on_proxy_tree_exited(in_proxy: ProximityProxy) -> void :
	var group: Group = _groups[in_proxy.group]
	var segment: Segment = group.id_to_segment_map.get(in_proxy._segment_id, _outside_map_segment)
	segment.proxies.erase(in_proxy._id)

func _on_proxy_tree_reenter(in_proxy: ProximityProxy) -> void :
	in_proxy._segment_id = Vector2i(-10000, -10000)
	_ensure_proxy_in_right_segment(in_proxy)

func _on_proxy_moved(in_proxy: ProximityProxy) -> void :
	_ensure_proxy_in_right_segment(in_proxy)

func _ensure_proxy_in_right_segment(in_proxy: ProximityProxy) -> void :
	var group: Group = _groups[in_proxy.group]
	var new_segment_id: Vector2i = Vector2i((in_proxy.global_position / SEGMENT_SIZE).round())
	var old_segment_id: Vector2i = in_proxy._segment_id
	if new_segment_id != old_segment_id:
		var old_segment: Segment = group.id_to_segment_map.get(old_segment_id, _outside_map_segment)
		var new_segment: Segment = group.id_to_segment_map.get(new_segment_id, _outside_map_segment)
		old_segment.proxies.erase(in_proxy._id)
		new_segment.proxies[in_proxy._id] = in_proxy.get_parent()
		in_proxy._segment_id = new_segment_id













func estimate_objects_in_area(in_rect: Rect2, in_group: ProximityProxy.Group) -> Array[Node2D]:
	var output: Array[Node2D] = []
	var segments: Array[Vector2i] = _get_segments_in_rect(in_rect)
	for segment_id in segments:
		var objects: Array = _get_objects_from_segment_id(segment_id, in_group)
		output.append_array(objects)
	return output

func _get_segments_in_rect(rect: Rect2) -> Array[Vector2i]:
	var out_segments: Array[Vector2i] = []
	var rect_min = rect.position
	var rect_max = rect.position + rect.size
	var min_seg_x = round((rect_min.x - SEGMENT_SIZE / 2.0) / SEGMENT_SIZE)
	var max_seg_x = round((rect_max.x + SEGMENT_SIZE / 2.0) / SEGMENT_SIZE)
	var min_seg_y = round((rect_min.y - SEGMENT_SIZE / 2.0) / SEGMENT_SIZE)
	var max_seg_y = round((rect_max.y + SEGMENT_SIZE / 2.0) / SEGMENT_SIZE)

	for x in range(min_seg_x, max_seg_x + 1):
		for y in range(min_seg_y, max_seg_y + 1):
			var segment_id = Vector2i(x, y)
			var seg_center = Vector2(segment_id.x * SEGMENT_SIZE, segment_id.y * SEGMENT_SIZE)
			var seg_rect = Rect2(
				seg_center - Vector2(SEGMENT_SIZE / 2.0, SEGMENT_SIZE / 2.0), 
				Vector2(SEGMENT_SIZE, SEGMENT_SIZE)
			)
			if rect.intersects(seg_rect, true):
				out_segments.append(segment_id)
	return out_segments

func _get_objects_from_segment_id(in_id: Vector2i, in_group: ProximityProxy.Group) -> Array:
	var group = _groups[in_group]
	var segment: Segment = group.id_to_segment_map.get(in_id, _outside_map_segment)
	return segment.proxies.values().duplicate()


func _get_segments_in_rect_from_middle_to_outside(rect: Rect2) -> Array[Vector2i]:
	var segments: Array[Vector2i] = []
	var rect_min = rect.position
	var rect_max = rect.position + rect.size
	var rect_center = rect.get_center()
	var min_seg_x = round((rect_min.x - SEGMENT_SIZE / 2.0) / SEGMENT_SIZE)
	var max_seg_x = round((rect_max.x + SEGMENT_SIZE / 2.0) / SEGMENT_SIZE)
	var min_seg_y = round((rect_min.y - SEGMENT_SIZE / 2.0) / SEGMENT_SIZE)
	var max_seg_y = round((rect_max.y + SEGMENT_SIZE / 2.0) / SEGMENT_SIZE)
	var center_x = round(rect_center.x / SEGMENT_SIZE)
	var center_y = round(rect_center.y / SEGMENT_SIZE)
	var max_radius_x = max(abs(max_seg_x - center_x), abs(center_x - min_seg_x))
	var max_radius_y = max(abs(max_seg_y - center_y), abs(center_y - min_seg_y))
	var max_radius = max(max_radius_x, max_radius_y)

	_check_and_add_segment(Vector2i(center_x, center_y), rect, segments)

	for current_ring in range(1, max_radius + 1):
		var left_edge = center_x - current_ring
		var right_edge = center_x + current_ring
		var top_edge = center_y - current_ring
		var bottom_edge = center_y + current_ring
		for x in range(left_edge, right_edge + 1):
			_check_and_add_segment(Vector2i(x, top_edge), rect, segments)
			_check_and_add_segment(Vector2i(x, bottom_edge), rect, segments)

		for y in range(top_edge + 1, bottom_edge):
			_check_and_add_segment(Vector2i(left_edge, y), rect, segments)
			_check_and_add_segment(Vector2i(right_edge, y), rect, segments)
	return segments

func _check_and_add_segment(segment_id: Vector2i, rect: Rect2, segments: Array[Vector2i]) -> void :
	var seg_center = Vector2(segment_id.x * SEGMENT_SIZE, segment_id.y * SEGMENT_SIZE)
	var seg_rect = Rect2(
		seg_center - Vector2(SEGMENT_SIZE / 2.0, SEGMENT_SIZE / 2.0), 
		Vector2(SEGMENT_SIZE, SEGMENT_SIZE)
	)

	if rect.intersects(seg_rect, true):
		segments.append(segment_id)

class Group:
	var id_to_segment_map: Dictionary = {

	}

class Segment:
	var proxies: Dictionary = {

	}
