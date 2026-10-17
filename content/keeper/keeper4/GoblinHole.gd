class_name GoblinHole
extends Node2D

signal state_updated
signal vines_updated
signal hole_punched

const GOBLIN_VINE_SCENE = preload("res://content/keeper/keeper4/GoblinVine.tscn")
const CREATE_FRAME_COUNT: int = 11
const DIG_DELAY: float = 2.0
const MINEABLE_REACHABLE_TARGET: int = 8
const MINEABLE_PATH_CHECK_LIMIT: int = 30
const MAX_PATH_LENGTH: float = 400.0

static func _compute_path_length(path: Array, from_pos: Vector2) -> float:
	var length: float = 0.0
	var prev: Vector2 = from_pos
	for step in path:
		var step_pos: Vector2 = step.get("position", prev)
		length += prev.distance_to(step_pos)
		prev = step_pos
	return length

static func find_path_within_length(navigator: GoblinNavigator, from: Vector2, to: Vector2) -> Array:
	var path: = navigator.get_surface_path(from, to)
	if path.is_empty():
		return []
	if _compute_path_length(path, from) > MAX_PATH_LENGTH:
		return []
	return path

enum HoleState{INCOMPLETE, DUG_OUT}

var UID: int
var teamId: String
var playerId: String
var colorId: String
var biome_color: Color

var spawned_vines: Array = []
var is_entrance_hole: = false
var is_revealed: = false
var assigned_goblin_count: = 0
var nearby_resources: Dictionary = {}
var _mineable_tiles_cache: Array = []
var _mineable_tiles_cache_generation: int = -1
var _reachable_drops_cache: Array = []
var _reachable_drops_cache_generation: int = -1
var _reachable_drops_dirty: bool = true
var _reachable_drops_carry_states: Dictionary = {}

var hole_state: int = HoleState.INCOMPLETE
var punch_count: int = 0
var vanish_timer: float = 0.0
var instability_timer: float = 0.0
var structural_check_timer: float = 0.0
var _last_vine_tile_count: int = 0
var _is_closing: = false
var _dig_animation_pending: = false
var _dig_delay_timer: = 0.0

@onready var sprite_goblin: AnimatedSprite2D = %SpriteGoblin


func setup():
	add_to_group("saveable")
	add_to_group(teamId + "-goblin_holes")
	add_to_group("goblin_holes")
	is_revealed = true
	hole_state = HoleState.DUG_OUT
	GoblinNavigator.force_rebuild_all()
	punch_count = Keeper4GameplaySettings.HOLE_TOTAL_PUNCHES
	$Sprite.visible = true
	$Sprite.animation = &"dug_out"
	$Sprite.frame = 0
	_spawn_vines_below()

func setup_growing():
	add_to_group("saveable")
	add_to_group(teamId + "-goblin_holes")
	add_to_group("goblin_holes")
	hole_state = HoleState.INCOMPLETE
	punch_count = 0
	is_revealed = true
	$Sprite.visible = true
	$Sprite.animation = &"create"
	$Sprite.frame = 0
	if multiplayer.is_server():
		structural_check_timer = randf_range(0.0, Keeper4GameplaySettings.HOLE_STABILITY_CHECK_INTERVAL)

func reveal():
	if is_revealed:
		return
	is_revealed = true
	$Sprite.visible = true
	$HoleCreatedSound.startSound()
	state_updated.emit()


func setup_as_entrance_hole():
	is_entrance_hole = true
	add_to_group("goblin_entrance_holes")
	var detector: Area2D = $ResourceDetector
	detector.monitoring = false
	nearby_resources.clear()
	$Sprite.visible = true
	$Sprite.animation = &"create"
	$Sprite.frame = CREATE_FRAME_COUNT - 1
	biome_color = Level.map.getBiomeColorByCoord(Level.map.getTileCoord(global_position))
	$Sprite.modulate = biome_color
	$Sprite.modulate += Style.colorData[Vector2(0, 10)] * 1.5

func set_color():
	if not is_instance_valid(Level.map):
		return
	biome_color = Level.map.getBiomeColorByCoord(Level.map.getTileCoord(global_position))
	if global_position.y < 450:
		$Sprite.modulate = biome_color + lerp(Color.BLACK, Style.colorData[Vector2(0, 10)] * 1.5, remap(global_position.y, 47, 447, 1.0, 0.0))
	else:
		$Sprite.modulate = biome_color
	var newColorId: String = ""
	var remapColorIdPerPalette: = false
	if Keepers.hasKeeper(playerId):
		newColorId = Keepers.getKeeper(playerId).colorId
		remapColorIdPerPalette = Keepers.getKeeper(playerId).remapColorIdPerPalette
	else:
		var keeperTemplate: LoadoutKeeper = null
		for lk in Level.loadout.keeperTemplates:
			if lk.playerId == playerId:
				keeperTemplate = lk
				break

		if is_instance_valid(keeperTemplate):
			newColorId = keeperTemplate.colorId
			remapColorIdPerPalette = keeperTemplate.remapColorIdPerPalette
		else:
			return

	self.colorId = newColorId

	if remapColorIdPerPalette:
		var mapping: Array = Data.palette_rgby.get(Style.paletteId)
		if mapping:
			colorId = "color" + str(mapping[int(colorId.substr(5))] - 1)
		else:
			Logger.error("Wanted to remap goblin hole color, but palette does not have mapping table", "GoblinHole.set_color", {"playerId": playerId, "colorId": colorId, "paletteId": Style.paletteId})

	var spritePath: String = "res://content/keeper/keeper4/goblins/spriteframes-goblinhole-" + colorId + ".tres"

	if %SpriteGoblin.is_playing():
		var frame = %SpriteGoblin.frame
		var animation = %SpriteGoblin.animation
		%SpriteGoblin.sprite_frames = load(spritePath)
		%SpriteGoblin.play(animation)
		%SpriteGoblin.frame = frame
	else:
		%SpriteGoblin.sprite_frames = load(spritePath)

	if not %SpriteGoblin.sprite_frames:
		Logger.error("Skin '%s' does not exist for catgoblins." % spritePath, "Goblin.setColor")

func receive_punch():
	for _i in 4:
		var t = Data.TILE_DIRT_PARTICLE.instantiate()
		t.modulate = biome_color
		t.position = global_position
		t.apply_central_impulse(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 130))
		Level.map.addDrop(t)
	punch_count = mini(punch_count + 1, Keeper4GameplaySettings.HOLE_TOTAL_PUNCHES)
	var progress: float = float(punch_count) / float(Keeper4GameplaySettings.HOLE_TOTAL_PUNCHES)
	var target_frame: int = clampi(int(progress * (CREATE_FRAME_COUNT - 1)), 0, CREATE_FRAME_COUNT - 1)
	$Sprite.animation = &"create"
	$Sprite.frame = target_frame
	vanish_timer = 0.0

	if punch_count >= Keeper4GameplaySettings.HOLE_TOTAL_PUNCHES and not _dig_animation_pending and hole_state == HoleState.INCOMPLETE:
		$HoleCreatedSound.startSound()
		_dig_animation_pending = true
		_dig_delay_timer = DIG_DELAY
		close_nearby_incomplete_holes()
		var particles = Data.TILE_BREAK_PARTICLES.instantiate()
		particles.biome_color = biome_color
		particles.dust_color = particles.biome_color * 1.3
		particles.impactDirection = Vector2.UP
		particles.position = global_position
		particles.spawn_dirt = false
		Level.map.addDrop(particles)
		for _i in 8:
			var t = Data.TILE_DIRT_PARTICLE.instantiate()
			t.modulate = biome_color
			t.position = global_position
			t.apply_central_impulse(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 130))
			Level.map.addDrop(t)

	state_updated.emit()
	hole_punched.emit()

func pauseChanged():
	if GameWorld.paused:
		$Sprite.pause()
		$SpriteGoblin.pause()
	elif _dig_animation_pending or _is_closing:
		$Sprite.play()
		$SpriteGoblin.play()

func on_punch_stopped():
	if _dig_animation_pending:
		return
	state_updated.emit()

func _ready():
	Style.init(self)
	var detector: Area2D = $ResourceDetector
	var shape: CircleShape2D = detector.get_node("CollisionShape2D").shape
	shape.radius = GoblinTaskManager.RESOURCE_GRAB_RANGE_TILES * GoblinNavigator.TILE_SIZE
	detector.area_entered.connect(_on_resource_detector_area_entered)
	detector.area_exited.connect(_on_resource_detector_area_exited)
	_scan_initial_resources.call_deferred()

func _scan_initial_resources() -> void :
	await get_tree().physics_frame
	if not is_instance_valid(self):
		return
	if is_entrance_hole:
		return
	var detector: Area2D = $ResourceDetector
	for area in detector.get_overlapping_areas():
		_on_resource_detector_area_entered(area)

func _on_resource_detector_area_entered(area: Area2D) -> void :
	var parent: Node = area.get_parent()
	if parent is Carryable and parent.carryableType == "resource":
		nearby_resources[parent] = true
		_reachable_drops_dirty = true

func _on_resource_detector_area_exited(area: Area2D) -> void :
	nearby_resources.erase(area.get_parent())
	_reachable_drops_dirty = true

func get_mineable_tiles(navigator: GoblinNavigator) -> Array:
	var gen: int = navigator.get_graph_generation()
	if _mineable_tiles_cache_generation == gen:
		return _mineable_tiles_cache
	_mineable_tiles_cache_generation = gen
	var hole_tile: Vector2 = Level.map.getTileCoord(global_position)
	var radius: int = GoblinTaskManager.CAT_RADIUS_TILES
	var radius_sq: int = GoblinTaskManager.CAT_RADIUS_TILES_SQ
	var seeded: Array = Data.ofOr(teamId + "seededTiles", [])
	var candidates: Array = []
	for dy in range( - radius, radius + 1):
		for dx in range( - radius, radius + 1):
			if abs(dy * dx) > radius_sq:
				continue
			var tile_coord: = Vector2(int(hole_tile.x) + dx, int(hole_tile.y) + dy)
			if not Level.map.tiles.has(tile_coord):
				continue
			var tile: Tile = Level.map.tiles[tile_coord]
			if not (tile.type == CONST.IRON or tile.type == CONST.SAND or tile.type == CONST.WATER):
				continue
			if tile.hasTileOverlay():
				continue
			if seeded.has(tile.coord):
				continue
			var adjacent_info: = navigator.find_surface_adjacent_to_tile(tile_coord)
			if adjacent_info.is_empty():
				continue
			var surface_pos: Vector2 = adjacent_info.position
			candidates.append({
				"tile": tile, 
				"tile_coord": tile_coord, 
				"surface_pos": surface_pos, 
				"health": tile.health, 
				"dist_sq": global_position.distance_squared_to(surface_pos)
			})
	candidates.sort_custom( func(a, b): return a.dist_sq < b.dist_sq)
	var result: Array = []
	var checks: int = min(candidates.size(), MINEABLE_PATH_CHECK_LIMIT)
	for i in range(checks):
		if result.size() >= MINEABLE_REACHABLE_TARGET:
			break
		var c: Dictionary = candidates[i]
		var path: = find_path_within_length(navigator, global_position, c.surface_pos)
		if path.is_empty():
			continue
		result.append({
			"tile": c.tile, 
			"tile_coord": c.tile_coord, 
			"surface_pos": c.surface_pos, 
			"health": c.health
		})
	_mineable_tiles_cache = result
	return result

func get_nearby_resources() -> Array[Carryable]:
	var result: Array[Carryable] = []
	var to_erase: Array = []
	for drop in nearby_resources:
		if not is_instance_valid(drop):
			to_erase.append(drop)
			continue
		if drop.carrierCount() > 0:
			var all_attached_kunai: = true
			for c in drop.carriedBy:
				if not (c is KunaiCarrier) or not c.attached:
					all_attached_kunai = false
					break
			if not all_attached_kunai:
				continue
		if drop.independent or drop.isAutoTransported:
			continue
		result.append(drop)
	for drop in to_erase:
		nearby_resources.erase(drop)
	return result

func get_reachable_drops(navigator: GoblinNavigator) -> Array:
	var gen: int = navigator.get_graph_generation()
	if not _reachable_drops_dirty and _reachable_drops_cache_generation == gen and not _carry_states_changed():
		return _reachable_drops_cache
	_reachable_drops_cache_generation = gen
	_reachable_drops_dirty = false
	_reachable_drops_carry_states.clear()
	var result: Array = []
	var to_erase: Array = []
	for drop in nearby_resources:
		if not is_instance_valid(drop):
			to_erase.append(drop)
			continue
		_reachable_drops_carry_states[drop] = drop.carrierCount()
		var path: = find_path_within_length(navigator, global_position, drop.global_position)
		if path.is_empty():
			continue
		var path_end: Vector2 = path[path.size() - 1].get("position", Vector2.ZERO)
		if path_end.distance_squared_to(drop.global_position) > Goblin.MAX_GRAB_DISTANCE_SQ:
			continue
		result.append({"hole": self, "drop": drop})
	for drop in to_erase:
		nearby_resources.erase(drop)
	_reachable_drops_cache = result
	return result

func _carry_states_changed() -> bool:
	for drop in nearby_resources:
		if not is_instance_valid(drop):
			return true
		if _reachable_drops_carry_states.get(drop, -1) != drop.carrierCount():
			return true
	return false

func _process(delta):
	if GameWorld.paused:
		return

	if is_entrance_hole:
		return

	if _is_closing:
		return

	if _dig_animation_pending:
		if _dig_delay_timer > 0:
			_dig_delay_timer -= delta
			if _dig_delay_timer <= 0:
				$GoblinDiggingOutHoleSound.startSound()
				$Sprite.animation = &"digging_out"
				$Sprite.frame = 0
				$Sprite.play()
				$Sprite.animation_finished.connect(_on_dig_animation_finished, CONNECT_ONE_SHOT)
				%SpriteGoblin.visible = true
				%SpriteGoblin.animation = &"digging_out"
				%SpriteGoblin.frame = 0
				%SpriteGoblin.play()
		return

	if not Network.is_server():
		return

	match hole_state:
		HoleState.DUG_OUT:
			if assigned_goblin_count <= 0:
				vanish_timer += delta
				if vanish_timer >= Keeper4GameplaySettings.HOLE_VANISH_TIMEOUT:
					close_hole()
					return

			structural_check_timer -= delta
			if structural_check_timer <= 0:
				structural_check_timer = Keeper4GameplaySettings.HOLE_STABILITY_CHECK_INTERVAL
				_update_vine_height()
				if assigned_goblin_count <= 0:
					var stable: = _check_structural_stability()
					if not stable:
						instability_timer += Keeper4GameplaySettings.HOLE_STABILITY_CHECK_INTERVAL
						if instability_timer >= Keeper4GameplaySettings.HOLE_UNSTABLE_TIMEOUT:
							close_hole()
					else:
						instability_timer = 0.0

func _on_dig_animation_finished():
	_dig_animation_pending = false
	hole_state = HoleState.DUG_OUT
	%SpriteGoblin.visible = false
	$Sprite.animation = &"dug_out"
	$Sprite.frame = 0
	structural_check_timer = randf_range(0.0, Keeper4GameplaySettings.HOLE_STABILITY_CHECK_INTERVAL)
	instability_timer = 0.0
	_spawn_vines_below()
	GoblinNavigator.force_rebuild_all()
	state_updated.emit()
	Level.getDome(teamId).goblins._on_hole_ready(self)

func _check_structural_stability() -> bool:
	var gravity_dir: int = -1 if Data.ofOr("world.inversegravity", false) else 1
	var coord: Vector2 = Level.map.getTileCoord(global_position)
	var cx: int = int(coord.x)
	var cy: int = int(coord.y)

	for y_offset in range(1, Keeper4GameplaySettings.HOLE_VINE_TILE_RANGE + 1):
		if Level.map.tiles.has(Vector2(cx, cy + y_offset * gravity_dir)):
			return true

	var vine_tiles: Array[Vector2i] = []
	for y_offset in range(1, Keeper4GameplaySettings.HOLE_VINE_TILE_RANGE + 1):
		var vy: int = cy + y_offset * gravity_dir
		if Level.map.is_tile_empty(Vector2i(cx, vy)):
			vine_tiles.append(Vector2i(cx, vy))
		else:
			break

	for i in range(vine_tiles.size()):
		var vx: int = vine_tiles[i].x
		var vy: int = vine_tiles[i].y
		var is_last: bool = i == vine_tiles.size() - 1
		var neighbors: Array[Vector2]
		neighbors = [Vector2(vx, vy - gravity_dir), Vector2(vx, vy + gravity_dir), Vector2(vx - 1, vy), Vector2(vx + 1, vy)]
		if is_last:
			neighbors.append(Vector2(vx - 1, vy + gravity_dir))
			neighbors.append(Vector2(vx + 1, vy + gravity_dir))
		for n in neighbors:
			if n == coord:
				continue
			if Level.map.tiles.has(n):
				return true

	return false

func _spawn_vines_below():
	var inverse_gravity: bool = Data.ofOr("world.inversegravity", false)
	var gravity_dir: int = -1 if inverse_gravity else 1
	var hole_coord: Vector2 = Level.map.getTileCoord(global_position)
	var below_x: int = int(hole_coord.x)
	var below_y: int = int(hole_coord.y) + gravity_dir

	var tile_count: int = 0
	while tile_count < Keeper4GameplaySettings.HOLE_VINE_TILE_RANGE and Level.map.is_tile_empty(Vector2(below_x, below_y)):
		tile_count += 1
		below_y += gravity_dir

	_last_vine_tile_count = tile_count

	if tile_count == 0:
		return

	var vine = GOBLIN_VINE_SCENE.instantiate()
	var hole_edge_y: float = Level.map.getTilePos(hole_coord).y + GameWorld.HALF_TILE_SIZE * gravity_dir
	vine.global_position = Vector2(global_position.x, hole_edge_y - 10 * gravity_dir)
	vine.set_meta("inverse_gravity", inverse_gravity)
	Level.map.add_child(vine)
	spawned_vines.append(vine)

	var total_height: float = tile_count * GameWorld.TILE_SIZE + 10
	vine.grow_to(total_height)

	vines_updated.emit()

func _update_vine_height():
	var inverse_gravity: bool = Data.ofOr("world.inversegravity", false)
	var gravity_dir: int = -1 if inverse_gravity else 1
	var hole_coord: Vector2 = Level.map.getTileCoord(global_position)
	var below_x: int = int(hole_coord.x)
	var below_y: int = int(hole_coord.y) + gravity_dir

	var tile_count: int = 0
	while tile_count < Keeper4GameplaySettings.HOLE_VINE_TILE_RANGE and Level.map.is_tile_empty(Vector2(below_x, below_y)):
		tile_count += 1
		below_y += gravity_dir

	if tile_count == _last_vine_tile_count:
		return
	_last_vine_tile_count = tile_count

	var total_height: float = tile_count * GameWorld.TILE_SIZE + 10
	if spawned_vines.size() > 0 and is_instance_valid(spawned_vines[0]):
		spawned_vines[0].extend_to(total_height)
	elif tile_count > 0:
		var vine = GOBLIN_VINE_SCENE.instantiate()
		var hole_edge_y: float = Level.map.getTilePos(hole_coord).y + GameWorld.HALF_TILE_SIZE * gravity_dir
		vine.global_position = Vector2(global_position.x, hole_edge_y - 10 * gravity_dir)
		vine.set_meta("inverse_gravity", inverse_gravity)
		Level.map.add_child(vine)
		spawned_vines.append(vine)
		vine.grow_to(total_height)

	vines_updated.emit()

func _cleanup_vines():
	for vine in spawned_vines:
		if is_instance_valid(vine):
			vine.queue_free()
	spawned_vines.clear()

func play_squad_exit_sound():
	if has_node("SquadExitSound"):
		$SquadExitSound.startSound()

func pulse():
	var t = create_tween()
	t.tween_property($Sprite, "position", Vector2(1, 0), 0.03)
	t.tween_property($Sprite, "position", Vector2(-1, 0), 0.03)
	t.tween_property($Sprite, "position", Vector2(0.5, 0), 0.03)
	t.tween_property($Sprite, "position", Vector2(-0.5, 0), 0.03)
	t.tween_property($Sprite, "position", Vector2.ZERO, 0.03)

func on_goblin_assigned():
	assigned_goblin_count += 1
	vanish_timer = 0.0

func on_goblin_unassigned():
	assigned_goblin_count = max(0, assigned_goblin_count - 1)
	if assigned_goblin_count <= 0:
		vanish_timer = 0.0
		instability_timer = 0.0

func close_hole():
	if _is_closing:
		return
	for _i in 8:
		var t = Data.TILE_DIRT_PARTICLE.instantiate()
		t.modulate = biome_color
		t.position = global_position
		t.apply_central_impulse(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 130))
		get_parent().call_deferred("add_child", t)
	_is_closing = true
	GoblinNavigator.force_rebuild_all()
	var has_vines: = false
	for vine in spawned_vines:
		if is_instance_valid(vine):
			has_vines = true
			vine.retracted.connect(_on_vine_retracted.bind(vine), CONNECT_ONE_SHOT)
			vine.retract()
	if not has_vines:
		_play_reverse_digging_out()
	state_updated.emit()

func close_nearby_incomplete_holes():
	var self_coord: = Vector2i(Level.map.getTileCoord(global_position))
	for hole in get_tree().get_nodes_in_group("goblin_holes"):
		if hole == self or not is_instance_valid(hole):
			continue
		if hole.is_entrance_hole:
			continue
		if hole.hole_state != HoleState.INCOMPLETE or hole._dig_animation_pending:
			continue
		var coord: = Vector2i(Level.map.getTileCoord(hole.global_position))
		if absi(coord.x - self_coord.x) <= 1 and absi(coord.y - self_coord.y) <= 1:
			hole.close_hole()

func _on_vine_retracted(vine: Node):
	if is_instance_valid(vine):
		vine.queue_free()
	spawned_vines.erase(vine)
	for v in spawned_vines:
		if is_instance_valid(v):
			return
	spawned_vines.clear()
	_play_reverse_digging_out()

func _play_reverse_digging_out():
	$HoleClosedSound.startSound()
	if hole_state == HoleState.DUG_OUT:
		%SpriteGoblin.visible = true
		%SpriteGoblin.play(&"digging_out_reverse")
		$Sprite.play(&"digging_out_reverse")
		$Sprite.animation_finished.connect(_play_close_animation, CONNECT_ONE_SHOT)
	else:
		_play_close_animation(true)

func _play_close_animation(play_partial: bool = false):
	var start_frame: = 0
	if play_partial:
		var current_open_frame = $Sprite.frame
		var frame_count = $Sprite.sprite_frames.get_frame_count(&"create")
		start_frame = (frame_count - 1) - current_open_frame
	%SpriteGoblin.visible = false
	$Sprite.animation = &"close"
	$Sprite.frame = start_frame
	$Sprite.play()
	$Sprite.animation_finished.connect(_on_close_finished, CONNECT_ONE_SHOT)

func to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_u8(hole_state)
	stream.encode_u8(punch_count)
	stream.encode_bool(is_revealed)
	stream.encode_bool(_dig_animation_pending)
	stream.encode_bool(_is_closing)
	stream.encode_bool(is_entrance_hole)

	return stream.data

func from_bytes(data: PackedByteArray, use_max_punch: bool = false) -> void :
	var stream: = PackedByteStream.from_bytes(data)

	var old_punch: int = punch_count
	var old_pending: bool = _dig_animation_pending

	hole_state = stream.decode_u8() as HoleState
	punch_count = maxi(old_punch, stream.decode_u8())
	is_revealed = stream.decode_bool()
	_dig_animation_pending = stream.decode_bool()
	var should_close = stream.decode_bool()

	if _dig_animation_pending and not old_pending:
		_dig_delay_timer = DIG_DELAY

	var is_entrance: bool = stream.decode_bool()
	if is_entrance and not is_entrance_hole:
		setup_as_entrance_hole()

	if should_close:
		close_hole()
		return

	if is_entrance_hole:
		$Sprite.visible = true
	else:
		$Sprite.visible = is_revealed
	if hole_state == HoleState.DUG_OUT:
		$Sprite.animation = &"dug_out"
		$Sprite.frame = 0
		_spawn_vines_below()
	else:
		var progress: float = float(punch_count) / float(Keeper4GameplaySettings.HOLE_TOTAL_PUNCHES)
		var target_frame: int = clampi(int(progress * (CREATE_FRAME_COUNT - 1)), 0, CREATE_FRAME_COUNT - 1)
		$Sprite.animation = &"create"
		$Sprite.frame = target_frame

func serialize() -> Dictionary:
	var data: Dictionary = {
		"meta.priority": 150, 
		"meta.kind": "generic", 
		"hole_state": hole_state, 
		"punch_count": punch_count, 
		"is_revealed": is_revealed, 
		"vanish_timer": vanish_timer, 
		"instability_timer": instability_timer, 
		"structural_check_timer": structural_check_timer, 
		"dig_animation_pending": _dig_animation_pending, 
		"dig_delay_timer": _dig_delay_timer, 
		"teamId": teamId, 
		"playerId": playerId, 
		"UID": UID
	}
	return data

func deserialize(data: Dictionary) -> void :
	UID = data.get("UID")
	playerId = data.get("playerId")
	teamId = data.get("teamId")
	hole_state = data.get("hole_state", HoleState.INCOMPLETE)
	punch_count = data.get("punch_count", 0)
	is_revealed = data.get("is_revealed", true)
	vanish_timer = data.get("vanish_timer", 0.0)
	instability_timer = data.get("instability_timer", 0.0)
	structural_check_timer = data.get("structural_check_timer", 0.0)
	_dig_animation_pending = data.get("dig_animation_pending", false)
	_dig_delay_timer = data.get("dig_delay_timer", 0.0)
	if _dig_animation_pending and _dig_delay_timer <= 0.0:
		_dig_delay_timer = 0.05

	add_to_group("saveable")
	add_to_group(data.get("teamId", "team1") + "-goblin_holes")
	add_to_group("goblin_holes")
	$Sprite.visible = is_revealed

	if hole_state == HoleState.DUG_OUT:
		$Sprite.animation = &"dug_out"
		$Sprite.frame = 0
		_spawn_vines_below()
	else:
		var progress: float = float(punch_count) / float(Keeper4GameplaySettings.HOLE_TOTAL_PUNCHES)
		var target_frame: int = clampi(int(progress * (CREATE_FRAME_COUNT - 1)), 0, CREATE_FRAME_COUNT - 1)
		$Sprite.animation = &"create"
		$Sprite.frame = target_frame

	GoblinNavigator.force_rebuild_all()
	Level.getDome(teamId).goblins.register_hole(self)
	set_color()

func _on_close_finished():
	queue_free()

func _on_sprite_goblin_frame_changed() -> void :
	if sprite_goblin.frame > 5 and sprite_goblin.frame < 60 and sprite_goblin.frame % 5 == 0:
		for _i in 4:
			var t = Data.TILE_DIRT_PARTICLE.instantiate()
			t.modulate = biome_color
			t.position = global_position
			t.apply_central_impulse(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 130))
			Level.map.addDrop(t)
