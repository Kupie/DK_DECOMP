extends Node2D

class_name Keeper3CarryChain

var _links: Array[Node2D] = []
var _last_start: Vector2 = Vector2(INF, INF)
var _last_target: Vector2 = Vector2(INF, INF)

var _linkScene: PackedScene = Keeper3SecondarySettings.CHAIN_LINK_SCENE
var _linkSpacing: float = Keeper3SecondarySettings.CARRIER_CHAIN_LINK_SPACING
var _maxLinks: int = Keeper3SecondarySettings.CARRIER_CHAIN_MAX_LINKS
var _linkZIndex: int = Keeper3SecondarySettings.CARRIER_CHAIN_Z_INDEX

func set_link_z_index(z: int) -> void :
	_linkZIndex = z
	z_index = z
	z_as_relative = false
	for link in _links:
		if is_instance_valid(link):
			link.z_index = z
			link.z_as_relative = false

func update_chain(start: Vector2, target: Vector2) -> void :
	if start.distance_squared_to(_last_start) < 0.0025 and target.distance_squared_to(_last_target) < 0.0025:
		return
	_last_start = start
	_last_target = target
	global_position = start
	var delta: Vector2 = target - start
	var distance: float = delta.length()
	if distance <= 0.05:
		_sync_links(0)
		return

	var desired_count: int = int(ceil(distance / max(_linkSpacing, 0.001)))
	desired_count = clampi(desired_count, 1, _maxLinks)
	_sync_links(desired_count)

	var direction: Vector2 = delta / distance
	var angle: float = direction.angle()
	var segment: float = distance / float(desired_count)

	for i in range(desired_count):
		var link: Node2D = _links[i]
		var offset_distance: float = segment * (float(i) + 0.5)
		link.position = direction * offset_distance
		link.rotation = angle

func _sync_links(count: int) -> void :
	if count < 0:
		count = 0
	while _links.size() < count:
		var instance: Node2D = _linkScene.instantiate()
		instance.z_index = _linkZIndex
		instance.z_as_relative = false
		add_child(instance)
		_links.append(instance)
	while _links.size() > count:
		var link: Node2D = _links.pop_back()
		if is_instance_valid(link):
			link.queue_free()
	visible = count > 0

func clear_links() -> void :
	_sync_links(0)


func _ready() -> void :
	z_index = _linkZIndex
	z_as_relative = false
