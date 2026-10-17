class_name Goblin
extends Node2D

signal state_updated

const SOUND: = preload("res://systems/audio/Sound.tscn")
const HOLE_DEBRIS_SCENE: = preload("res://content/keeper/keeper4/HoleDebrisParticle.tscn")
const HOLE_SQUAD_DEBRIS_SCENE: = preload("res://content/keeper/keeper4/HoleSquadDebrisParticle.tscn")
const HOLE_SQUAD_DUST_SCENE: = preload("res://content/keeper/keeper4/HoleSquadDust.tscn")
const SURFACE_MOVE_SPEED: = 60.0
const HOLE_EXIT_MOVE_SPEED: = 90.0
const TELEPORT_DURATION: = 1.5

const DEBUG_PATH: = false
const DEBUG_COLOR_WALK: = Color(0.2, 0.8, 0.2, 0.8)
const DEBUG_COLOR_JUMP: = Color(1.0, 0.5, 0.0, 0.8)
const DEBUG_COLOR_SURFACE_FLOOR: = Color(0.3, 0.3, 1.0, 0.5)
const DEBUG_COLOR_SURFACE_WALL: = Color(1.0, 0.3, 0.3, 0.5)
const GRAB_DURATION: = Vector2(0.2, 0.4)
const THROW_DURATION: = Vector2(0.2, 0.5)
const CELLAR_FLOOR_Y: = 53.0
const CELLAR_X_MIN: = -50.0
const CELLAR_X_MAX: = 50.0
const PATH_POINT_REACHED_SQ: = 64.0
const JUMP_PATH_SPEED: = 120.0
const JUMP_TWEEN_DURATION: = 0.4
const HOLE_HOP_DURATION: = 0.5
const HOLE_HOP_HEIGHT: = 12.0
const ENTRANCE_HOP_HEIGHT: = 40.0
const MAX_GRAB_DISTANCE: = 24.0
const MAX_GRAB_DISTANCE_SQ: = MAX_GRAB_DISTANCE * MAX_GRAB_DISTANCE
const MAX_PULL_START_DISTANCE: = 48.0
const MAX_PULL_START_DISTANCE_SQ: = MAX_PULL_START_DISTANCE * MAX_PULL_START_DISTANCE
const RESOURCE_PULL_SPEED: = 80.0
const WAIT_FOR_PATH_DURATION_MIN: = 0.3
const WAIT_FOR_PATH_DURATION_MAX: = 0.7
const PATH_RECHECK_INTERVAL_MIN: = 0.3
const PATH_RECHECK_INTERVAL_MAX: = 0.5
const FALL_LANDING_PAUSE_MIN: = 0.1
const FALL_LANDING_PAUSE_MAX: = 0.4
const DISAPPEAR_ANIMATION_DURATION: = 0.5
const FALL_SPEED: = 150.0
const MINE_DAMAGE: = 2.0
const DIGGING_INTERVAL: = 4.4
const MINING_INTERVAL: = 0.4

enum State{
	CELLAR_WANDER, 
	WALKING_TO_ENTRANCE_HOLE, 
	JUMPING_TO_ENTRANCE_HOLE, 
	TELEPORTING, 
	HOPPING_FROM_HOLE, 
	CAVE_WANDER, 
	MOVING_TO_RESOURCE, 
	GRABBING, 
	MOVING_TO_HOLE, 
	HOPPING_TO_HOLE, 
	JUMPING_FROM_ENTRANCE_HOLE, 
	THROW_DELAY, 
	THROWING, 
	WAITING_FOR_PATH, 
	DISAPPEARING, 
	FALLING, 
	MOVING_TO_MINE_SURFACE, 
	MINING, 
	NAPPING, 
	MOVING_TO_CELLAR_RESOURCE
}

var UID: int
var playerId: String
var teamId: String
var colorId: String

var state: int = State.CELLAR_WANDER
var state_timer: = 0.0
var move_direction: = 0.0
var facing_direction: = 1.0

var current_surface_path: Array = []
var surface_path_index: = 0
var _path_target_node: Node2D = null
var _path_required_tiles: Array[Vector2] = []
var _path_required_vine_tiles: Array[Vector2] = []
var _expected_resource_position: = Vector2.ZERO
const RESOURCE_MOVED_THRESHOLD_SQ: = 576.0

var target_resource_uid: int = -1
var target_hole = null
var carried_resource_uid: int = -1
var _blacklisted_targets: Dictionary = {}
var _hop_from_hole_phase: int = 0
var _hop_from_hole_target_pos: = Vector2.ZERO
var _hop_to_hole_phase: int = 0
var _entrance_landing_pos: = Vector2.ZERO

var teleport_timer: = 0.0
var is_in_cellar: = false:
	set(value):
		is_in_cellar = value
		z_as_relative = true
		z_index = -1 if value else 25
var _grabbed_in_cellar: = false
var _is_pulling_resource: = false
var _path_recheck_timer: = 0.0
var _stale_check_at_ms: int = 0
var _stale_cached_result: bool = false
const STALE_CHECK_INTERVAL_MS: int = 250
var _mine_target_tile = null
var _mine_target_tile_coord: = Vector2.ZERO
var _pinned_mining_tile = null
var _pinned_mining_tile_coord: = Vector2.ZERO
var _mine_timer: = 0.0
var _nap_timer: = 0.0
var _nap_wander_timer: = 0.0
var _assigned_hole_for_mining: Node2D = null
var _has_greeted: = false

const GREET_DISTANCE_SQ: = 2500.0

var _wander_curve: Curve2D = null
var _wander_base_node: Node2D = null
var _wander_progress: = 0.0
var _wander_target_progress: = 0.0
var _wander_pause_timer: = 0.0

var _goblins_node = null
var _jump_path_curve: Curve2D = null
var _target_exit_hole = null
var _is_teleporting_outbound: = false
@onready var _sprite: AnimatedSprite2D = $GoblinSprite
@onready var _squad_sprite: AnimatedSprite2D = $SquadSprite
@onready var step_dust: GPUParticles2D = $StepDust

var _navigator: GoblinNavigator = null
var _task_manager: GoblinTaskManager = null

var _current_surface_type: int = SurfacePathfinding.SurfaceType.FLOOR_TOP
var _visual_surface_type: int = SurfacePathfinding.SurfaceType.FLOOR_TOP
var _current_surface_coord: = Vector2i.ZERO
var _fall_surface_preference: int = -1
var _is_jumping: = false
var _wall_moving_up: = false
var _last_anim_sig: int = -1
var _movement_tween: Tween = null
var _rotation_tween: Tween = null
var _origin_hole: Node2D = null
var _hole_hop_target: Dictionary = {}
var _hole_hop_tween: Tween = null

var is_squad_goblin: = false
var squad_id: int = -1
var _squad_origin_hole: Node2D = null
var _squad_timer: float = 0.0
var _last_squad_mined_coord: Vector2 = Vector2.ZERO

var _rng: RandomNumberGenerator
var _gravity_dir: int = 1

var _id_inside_keeper: int = 0

static var _squad_pool_initialized: = false
static var _squad_sound_pool: Dictionary = {}
static var _normal_pool_initialized: = false
static var _normal_sound_pool: Dictionary = {}

static func _init_squad_sound_pool(source_goblin: Node) -> void :
	if _squad_pool_initialized:
		return
	_squad_pool_initialized = true
	var parent: Node = Level.map if is_instance_valid(Level.map) else source_goblin.get_parent()
	var pool_sizes: = {"jump": 3, "into_hole": 2, "out_from_hole": 2, "drop": 2, "extractresource": 2, "greet": 2, "startdig": 2}
	var source_map: = {
		"jump": "SquadSound/JumpSound", "into_hole": "SquadSound/IntoHoleSound", 
		"out_from_hole": "SquadSound/OutFromHoleSound", "drop": "Drop", 
		"extractresource": "ExtractResource", "greet": "SquadSound/GreetKeeper", 
		"startdig": "SquadSound/StartDig"
	}
	for pool_name in pool_sizes:
		_squad_sound_pool[pool_name] = []
		var source_node: Node = source_goblin.get_node_or_null(source_map[pool_name])
		if not source_node or not source_node is AudioStreamPlayer:
			continue
		var src: AudioStreamPlayer = source_node as AudioStreamPlayer
		for i in range(pool_sizes[pool_name]):
			var player: = SOUND.instantiate()
			player.stream = src.stream
			player.volume_db = src.volume_db
			player.pitch_scale = src.pitch_scale
			player.bus = src.bus
			player.maxAudibleDistance = src.maxAudibleDistance
			player.processOnlyOnce = src.processOnlyOnce
			parent.call_deferred("add_child", player)
			_squad_sound_pool[pool_name].append(player)

static func _play_squad_sound(pool_name: String) -> void :
	if not _squad_sound_pool.has(pool_name):
		return
	for player in _squad_sound_pool[pool_name]:
		if is_instance_valid(player) and not player.playing:
			player.startSound()
			return

static func reset_squad_sound_pool() -> void :
	for pool_name in _squad_sound_pool:
		for player in _squad_sound_pool[pool_name]:
			if is_instance_valid(player):
				player.queue_free()
	_squad_sound_pool.clear()
	_squad_pool_initialized = false

const NORMAL_POOL_SOURCE_PATHS: = [
	"NormalSound/JumpSound", 
	"NormalSound/IntoHoleSound", 
	"NormalSound/OutFromHoleSound", 
	"NormalSound/WakeUpSound", 
	"NormalSound/GreetKeeper", 
	"NormalSound/StartDig", 
	"NormalSound/GetResource", 
	"Drop", 
]

static func _init_normal_sound_pool(source_goblin: Node) -> void :
	if _normal_pool_initialized:
		return
	_normal_pool_initialized = true
	var parent: Node = Level.map
	var pool_sizes: = {
		"jump": 6, "into_hole": 6, "out_from_hole": 6, 
		"wake_up": 4, "greet": 4, "start_dig": 4, "get_resource": 4, "drop": 4, 
	}
	var source_map: = {
		"jump": "NormalSound/JumpSound", 
		"into_hole": "NormalSound/IntoHoleSound", 
		"out_from_hole": "NormalSound/OutFromHoleSound", 
		"wake_up": "NormalSound/WakeUpSound", 
		"greet": "NormalSound/GreetKeeper", 
		"start_dig": "NormalSound/StartDig", 
		"get_resource": "NormalSound/GetResource", 
		"drop": "Drop", 
	}
	for pool_name in pool_sizes:
		_normal_sound_pool[pool_name] = []
		var src: AudioStreamPlayer = source_goblin.get_node(source_map[pool_name])
		for i in range(pool_sizes[pool_name]):
			var player: = SOUND.instantiate()
			player.stream = src.stream
			player.volume_db = src.volume_db
			player.pitch_scale = src.pitch_scale
			player.bus = src.bus
			player.maxAudibleDistance = src.maxAudibleDistance
			player.processOnlyOnce = src.processOnlyOnce
			parent.call_deferred("add_child", player)
			_normal_sound_pool[pool_name].append(player)

func _play_normal_sound(pool_name: String) -> void :
	if not _normal_sound_pool.has(pool_name):
		return
	for player in _normal_sound_pool[pool_name]:
		if not player.playing:
			player.setSimulatedPosition(global_position)
			player.startSound()
			return

static func reset_normal_sound_pool() -> void :
	for pool_name in _normal_sound_pool:
		for player in _normal_sound_pool[pool_name]:
			if is_instance_valid(player):
				player.queue_free()
	_normal_sound_pool.clear()
	_normal_pool_initialized = false

const ROTATION_TWEEN_DURATION: = 0.15

const _surface_offset_floor: = Vector2(0, -6.5)
const _surface_offset_wall_left: = Vector2(4.0, 0)
const _surface_offset_wall_right: = Vector2(0.0, 0)

func _get_surface_offset(surface_type: int) -> Vector2:
	match surface_type:
		SurfacePathfinding.SurfaceType.WALL_LEFT:
			return _surface_offset_wall_left
		SurfacePathfinding.SurfaceType.WALL_RIGHT:
			return _surface_offset_wall_right
		_:
			return Vector2(0, -6.5 * _gravity_dir)

func _get_combined_surface_offset(type_a: int, type_b: int) -> Vector2:
	var a: = _get_surface_offset(type_a)
	var b: = _get_surface_offset(type_b)
	return Vector2(
		a.x if a.x != 0.0 else b.x, 
		a.y if a.y != 0.0 else b.y
	)

func _precompute_path_offsets():
	for i in range(current_surface_path.size()):
		var node: Dictionary = current_surface_path[i]
		var st: int = node.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
		if i + 1 < current_surface_path.size():
			var next_st: int = current_surface_path[i + 1].get("surface_type", st)
			if next_st != st:
				node["_offset"] = _get_combined_surface_offset(st, next_st)
				continue
		node["_offset"] = _get_surface_offset(st)

func _ready():
	_rng = RandomNumberGenerator.new()
	_rng.seed = UID
	_gravity_dir = -1 if Data.ofOr("world.inversegravity", false) else 1
	add_to_group("keeper4_goblins")
	Style.init(self)
	is_in_cellar = true
	state = State.CELLAR_WANDER
	state_timer = _rng.randf_range(0.5, 2.0)
	move_direction = [-1.0, 1.0][_rng.randi() % 2]
	set_physics_process(false)
	_init_normal_sound_pool(self)
	for path in NORMAL_POOL_SOURCE_PATHS:
		var node: = get_node_or_null(path)
		if node:
			node.queue_free()

func _set_carried_resource_uid(uid: int) -> void :
	carried_resource_uid = uid
	set_physics_process(uid != -1)

func set_color():
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
			Logger.error("Wanted to remap goblin color, but palette does not have mapping table", "Goblin.set_color", {"playerId": playerId, "colorId": colorId, "paletteId": Style.paletteId})

	var catgoblinSkinSpritePath: String = "res://content/keeper/keeper4/goblins/spriteframes-catgoblin-" + colorId + ".tres"
	var squadgoblinSkinSpritePath: String = "res://content/keeper/keeper4/goblins/spriteframes-squadgoblin-" + colorId + ".tres"
	%GoblinSprite.sprite_frames = load(catgoblinSkinSpritePath)
	%SquadSprite.sprite_frames = load(squadgoblinSkinSpritePath)

	if not %GoblinSprite.sprite_frames:
		Logger.error("Skin '%s' does not exist for catgoblins." % catgoblinSkinSpritePath, "Goblin.setColor")
	if not %SquadSprite.sprite_frames:
		Logger.error("Skin '%s' does not exist for squadgoblins." % squadgoblinSkinSpritePath, "Goblin.setColor")


func set_seed(value: int) -> void :
	_rng.seed = value

func set_task_manager(manager) -> void :
	_task_manager = manager
	_navigator = manager.get_navigator() if manager else null
	if _task_manager and Network.is_server() and not is_squad_goblin:
		state_updated.connect(_sync_idle_queue_membership)
		tree_exiting.connect(_on_tree_exiting_for_queue)
		_sync_idle_queue_membership()

func _sync_idle_queue_membership() -> void :
	if is_in_cellar and state == State.CELLAR_WANDER and not Level.drops.has_drop(carried_resource_uid):
		_task_manager.enqueue_idle_goblin(self)
	else:
		_task_manager.dequeue_idle_goblin(self)

func _on_tree_exiting_for_queue() -> void :
	_task_manager.dequeue_idle_goblin(self)

func _enter_cellar_wander() -> void :
	_grabbed_in_cellar = false
	state = State.CELLAR_WANDER
	state_updated.emit()

func _enter_throw_delay_facing_shredder() -> void :
	var shredder_pos: Vector2 = Level.getDome(teamId).getDropTarget(CONST.IRON).dropTarget()
	facing_direction = sign(shredder_pos.x - global_position.x)
	if facing_direction == 0:
		facing_direction = 1.0
	state = State.THROW_DELAY
	state_timer = _rng.randf_range(0.4, 0.6)
	state_updated.emit()

func set_id_inside_keeper(nmb_inside_keeper: int) -> void :
	_id_inside_keeper = nmb_inside_keeper

func setup_as_squad_goblin(hole: Node2D, task_mgr: GoblinTaskManager, nav: GoblinNavigator, duration: float, goblins: Node = null) -> void :
	is_squad_goblin = true
	_goblins_node = goblins
	_squad_origin_hole = hole
	_origin_hole = hole
	_squad_timer = duration
	_task_manager = task_mgr
	_navigator = nav
	is_in_cellar = false
	visible = true

	_sprite.visible = false
	_squad_sprite.visible = true
	_sprite = _squad_sprite
	_init_squad_sound_pool(self)
	for child in get_children():
		if child is AudioStreamPlayer:
			child.queue_free()
	hole.on_goblin_assigned()
	_navigator.flush_pending_rebuild()
	_start_hop_from_hole()

func setup_as_client_squad_goblin(goblins: Node) -> void :
	is_squad_goblin = true
	_goblins_node = goblins
	is_in_cellar = false
	visible = true

	_sprite.visible = false
	_squad_sprite.visible = true
	_sprite = _squad_sprite
	_init_squad_sound_pool(self)
	for child in get_children():
		if child is AudioStreamPlayer:
			child.queue_free()

func _start_hop_from_hole():
	var hop_targets = _navigator.get_hole_hop_targets(global_position) if _navigator else []
	if hop_targets.is_empty():
		if is_squad_goblin:
			queue_free()
		else:
			_unassign_from_hole()
			_clear_path()
			_return_to_cellar()
		return
	var best_target: Dictionary = {}
	if _task_manager:
		best_target = _task_manager.find_unclaimed_hop_target(self, global_position)
	if best_target.is_empty():
		best_target = hop_targets[0]
	var hop_coord: Vector2i = best_target.get("coord", Vector2i.ZERO)
	if _task_manager:
		_task_manager.claim_hop_target(self, hop_coord)
	_hole_hop_target = best_target
	_current_surface_coord = hop_coord
	var target_type: int = best_target.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
	var target_pos: Vector2 = best_target.get("position", global_position) + _get_surface_offset(target_type)
	if target_pos.x < global_position.x:
		facing_direction = -1.0
	elif target_pos.x > global_position.x:
		facing_direction = 1.0
	_spawn_hole_debris(global_position)
	_hop_from_hole_phase = 0
	state = State.HOPPING_FROM_HOLE
	_sprite.play("hole_exit_start")
	state_updated.emit()

func _spawn_hole_debris(hole_pos: Vector2) -> void :
	var impulse_min: float = Keeper4GameplaySettings.ATTACH_IMPULSE_MIN
	var impulse_max: float = Keeper4GameplaySettings.ATTACH_IMPULSE_MAX
	var tileCoord = Level.map.getTileCoord(hole_pos)
	var dirt_color: Color = Level.map.getBiomeColorByCoord(tileCoord)
	for _i in range((Keeper4GameplaySettings.ATTACH_DIRT_COUNT + randi() % 2) * 2):
		var t = HOLE_DEBRIS_SCENE.instantiate()
		t.modulate = dirt_color
		t.type = "dirt"
		t.global_position = hole_pos
		var horizontal: float = randf_range(-15, 15)
		var vertical: float = randf_range( - impulse_max * 1.5, - impulse_min * 1.5) * _gravity_dir
		t.apply_central_impulse(Vector2(horizontal, vertical))
		t.z_index = 20
		Level.map.call_deferred("add_child", t)
	if is_squad_goblin:
		_spawn_squad_hole_debris(hole_pos, dirt_color, impulse_min, impulse_max)
		if is_instance_valid(_squad_origin_hole):
			_squad_origin_hole.play_squad_exit_sound()

func _spawn_squad_hole_debris(hole_pos: Vector2, dirt_color: Color, impulse_min: float, impulse_max: float) -> void :
	for _i in range(3 + randi() % 2):
		var t = HOLE_SQUAD_DEBRIS_SCENE.instantiate()
		t.modulate = dirt_color
		t.type = "dirt"
		t.global_position = hole_pos
		var horizontal: float = randf_range(-15, 15)
		var vertical: float = randf_range( - impulse_max * 1.5, - impulse_min * 1.5) * _gravity_dir
		t.apply_central_impulse(Vector2(horizontal, vertical))
		t.z_index = 20
		Level.map.call_deferred("add_child", t)
	var dust = HOLE_SQUAD_DUST_SCENE.instantiate()
	dust.dust_color = dirt_color
	dust.global_position = hole_pos
	Level.map.call_deferred("add_child", dust)

func accept_resource_task(resource_uid: int, path: Array) -> bool:
	if not _set_surface_path_to_target(Level.drops.get_drop(resource_uid), path):
		return false
	target_resource_uid = resource_uid
	_expected_resource_position = Level.drops.get_drop(resource_uid).global_position
	state = State.MOVING_TO_RESOURCE
	_assigned_hole_for_mining = null
	state_updated.emit()
	return true

func accept_cellar_resource_task(resource_uid: int) -> bool:
	if not Level.drops.has_drop(resource_uid):
		return false
	target_resource_uid = resource_uid
	_expected_resource_position = Level.drops.get_drop(resource_uid).global_position
	_assigned_hole_for_mining = null
	_is_pulling_resource = false
	_grabbed_in_cellar = true
	state = State.MOVING_TO_CELLAR_RESOURCE
	state_updated.emit()
	return true

func accept_mining_task(hole: Node2D, tile, tile_coord: Vector2, path: Array) -> bool:
	if is_squad_goblin and is_instance_valid(_squad_origin_hole):
		var world_pos: Vector2 = tile_coord * GameWorld.TILE_SIZE + CONST.TILE_OFFSET
		if world_pos.distance_squared_to(_squad_origin_hole.global_position) > Keeper4GameplaySettings.HOLE_RADIUS_SQ:
			return false
	if not _set_surface_path_to_target(null, path):
		return false
	_assigned_hole_for_mining = hole
	_mine_target_tile = tile
	_mine_target_tile_coord = tile_coord
	state = State.MOVING_TO_MINE_SURFACE
	state_updated.emit()
	return true

func accept_return_task(hole: Node2D, path: Array) -> bool:
	if is_squad_goblin and _squad_timer > 0:
		return false
	if not _set_surface_path_to_target(hole, path):
		return false
	target_hole = hole
	state = State.MOVING_TO_HOLE
	_assigned_hole_for_mining = null
	state_updated.emit()
	return true

func _request_task() -> void :
	if not Network.is_server():
		return
	if is_squad_goblin:
		_request_squad_task()
		return
	if not _task_manager or not _task_manager.request_task(self):
		if is_in_cellar:
			return
		_enter_waiting_for_path_state()

func setup_wander_path(curve: Curve2D, base_node: Node2D, goblins_node = null) -> void :
	_wander_curve = curve
	_wander_base_node = base_node
	_wander_progress = 0.0
	_wander_target_progress = _rng.randf() * curve.get_baked_length()
	_wander_pause_timer = 0.0
	_goblins_node = goblins_node
	if _goblins_node:
		_jump_path_curve = _goblins_node.get_hole_jump_curve()

func _physics_process(_delta: float) -> void :
	if is_instance_valid(Level.drops) and Level.drops.has_drop(carried_resource_uid):
		var drop: Carryable = Level.drops.get_drop(carried_resource_uid)
		drop.global_position = global_position + Vector2(0, 3 * _gravity_dir)
		if not is_in_cellar and _is_in_shaft():
			drop.z_index = -3
		elif drop.has_meta("goblin_prev_z"):
			drop.z_index = drop.get_meta("goblin_prev_z")

func _is_in_shaft() -> bool:
	return absf(global_position.x - Level.getDome(teamId).global_position.x) < GameWorld.TILE_SIZE

func _process(delta: float) -> void :
	if GameWorld.paused or GameWorld.gameover:
		return
	step_dust.emitting = false
	if not is_in_cellar:
		var in_shaft: = _is_in_shaft()
		z_as_relative = not in_shaft
		z_index = -3 if in_shaft else 25
	if not _has_greeted and not is_in_cellar and state != State.NAPPING:
		var keeper: Keeper = Keepers.getClosestKeeper(global_position, teamId)
		if is_instance_valid(keeper) and global_position.distance_squared_to(keeper.global_position) <= GREET_DISTANCE_SQ:
			_has_greeted = true
			if is_squad_goblin:
				_play_squad_sound("greet")
			else:
				_play_normal_sound("greet")
	if Network.is_server():
		if is_squad_goblin and _squad_timer > 0:
			_squad_timer -= delta
			if _squad_timer <= 0 and state != State.MOVING_TO_HOLE and state != State.HOPPING_TO_HOLE:
				_trigger_squad_return()
		if is_squad_goblin and not is_instance_valid(_squad_origin_hole) and state != State.FALLING and state != State.DISAPPEARING:
			_enter_falling_state()
			return
		var _hopping_from_hole_safe: = (state == State.HOPPING_FROM_HOLE and _hop_from_hole_phase < 2) or state == State.HOPPING_TO_HOLE
		if not is_in_cellar and not _hopping_from_hole_safe and \
		(state in [State.MOVING_TO_RESOURCE, State.MOVING_TO_HOLE, State.MOVING_TO_MINE_SURFACE, 
				State.MINING, State.HOPPING_FROM_HOLE, State.WAITING_FOR_PATH, 
				State.CAVE_WANDER, State.GRABBING]) and _is_current_surface_destroyed():
			_enter_falling_state()
			return
	match state:
		State.CELLAR_WANDER:
			_process_cellar_wander(delta)
		State.WALKING_TO_ENTRANCE_HOLE:
			_process_walking_to_entrance_hole(delta)
		State.JUMPING_TO_ENTRANCE_HOLE:
			_process_jumping_to_entrance_hole(delta)
		State.TELEPORTING:
			_process_teleporting(delta)
		State.HOPPING_FROM_HOLE:
			_process_hopping_from_hole(delta)
		State.CAVE_WANDER:
			_process_cave_wander(delta)
		State.MOVING_TO_RESOURCE:
			_process_moving_to_resource(delta)
		State.MOVING_TO_CELLAR_RESOURCE:
			_process_moving_to_cellar_resource(delta)
		State.GRABBING:
			_process_grabbing(delta)
		State.MOVING_TO_HOLE:
			_process_moving_to_hole(delta)
		State.HOPPING_TO_HOLE:
			_process_hopping_to_hole(delta)
		State.JUMPING_FROM_ENTRANCE_HOLE:
			_process_jumping_from_entrance_hole(delta)
		State.THROW_DELAY:
			_process_throw_delay(delta)
		State.THROWING:
			_process_throwing(delta)
		State.WAITING_FOR_PATH:
			_process_waiting_for_path(delta)
		State.DISAPPEARING:
			_process_disappearing(delta)
		State.FALLING:
			_process_falling(delta)
		State.MOVING_TO_MINE_SURFACE:
			_process_moving_to_mine_surface(delta)
		State.MINING:
			_process_mining(delta)
		State.NAPPING:
			_process_napping(delta)
	_update_animation()
	if DEBUG_PATH:
		queue_redraw()

func _get_cellar_floor_y() -> float:
	if is_instance_valid(Level.getDome(teamId)):
		return Level.getDome(teamId).global_position.y + CELLAR_FLOOR_Y
	return CELLAR_FLOOR_Y

func _get_cellar_x_min() -> float:
	if is_instance_valid(Level.getDome(teamId)):
		return Level.getDome(teamId).global_position.x + CELLAR_X_MIN
	return CELLAR_X_MIN

func _get_cellar_x_max() -> float:
	if is_instance_valid(Level.getDome(teamId)):
		return Level.getDome(teamId).global_position.x + CELLAR_X_MAX
	return CELLAR_X_MAX

func _clear_path():
	current_surface_path = []
	surface_path_index = 0
	_path_target_node = null
	_path_required_tiles.clear()
	_stale_check_at_ms = 0
	_stale_cached_result = false
	if _movement_tween and _movement_tween.is_valid():
		_movement_tween.kill()
	_is_jumping = false
	_stop_climbing_sounds()
	if DEBUG_PATH:
		queue_redraw()

func _is_path_stale() -> bool:
	if current_surface_path.is_empty():
		return false
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _stale_check_at_ms < STALE_CHECK_INTERVAL_MS:
		return _stale_cached_result
	_stale_check_at_ms = now_ms
	if not is_instance_valid(Level.map):
		_stale_cached_result = true
		return true
	for tile_coord in _path_required_tiles:
		if not Level.map.tiles.has(tile_coord):
			_stale_cached_result = true
			return true
	for vine_coord in _path_required_vine_tiles:
		if Level.map.tiles.has(vine_coord):
			_stale_cached_result = true
			return true
	_stale_cached_result = false
	return false

func _has_resource_moved_significantly() -> bool:
	if not Level.drops.has_drop(target_resource_uid):
		return false
	var resource_pos: Vector2 = Level.drops.get_drop(target_resource_uid).global_position
	var delta_sq: float = resource_pos.distance_squared_to(_expected_resource_position)
	return delta_sq > RESOURCE_MOVED_THRESHOLD_SQ

func _set_surface_path_to_target(target: Node2D, path: Array) -> bool:
	if not _is_path_valid(path):
		return false
	current_surface_path = path
	surface_path_index = 0
	_path_target_node = target
	_is_jumping = false
	_precompute_path_offsets()
	_rebuild_required_tiles()
	_stale_check_at_ms = 0
	_stale_cached_result = false
	if DEBUG_PATH:
		queue_redraw()
	return true

func _refresh_surface_path_to_target() -> bool:
	if not is_instance_valid(_path_target_node):
		return false
	if not _navigator:
		return false
	var new_path: Array
	var is_hole: = _path_target_node.is_in_group(teamId + "-goblin_holes")
	if is_hole:
		new_path = _navigator.get_path_to_hole_adjacent_surface(global_position, _path_target_node.global_position)
	else:
		new_path = _navigator.get_surface_path(global_position, _path_target_node.global_position)
	if _is_path_valid(new_path):
		if _movement_tween and _movement_tween.is_valid():
			_movement_tween.kill()
		_is_jumping = false
		current_surface_path = new_path
		surface_path_index = 0
		_precompute_path_offsets()
		_rebuild_required_tiles()
		_stale_check_at_ms = 0
		_stale_cached_result = false
		return true
	_clear_path()
	return false

func _rebuild_required_tiles() -> void :
	_path_required_tiles.clear()
	_path_required_vine_tiles.clear()
	for node in current_surface_path:
		var coord: Vector2i = node.get("coord", Vector2i.ZERO)
		var surface_type: int = node.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
		var tile_coord: = Vector2.ZERO
		match surface_type:
			SurfacePathfinding.SurfaceType.FLOOR_TOP:
				tile_coord = Vector2(coord.x, coord.y + _gravity_dir)
			SurfacePathfinding.SurfaceType.WALL_LEFT:
				tile_coord = Vector2(coord.x - 1, coord.y)
			SurfacePathfinding.SurfaceType.WALL_RIGHT:
				tile_coord = Vector2(coord.x + 1, coord.y)
			SurfacePathfinding.SurfaceType.VINE_CENTER:
				var vine_coord: = Vector2(coord.x, coord.y)
				if not _path_required_vine_tiles.has(vine_coord):
					_path_required_vine_tiles.append(vine_coord)
		if tile_coord != Vector2.ZERO and not _path_required_tiles.has(tile_coord):
			_path_required_tiles.append(tile_coord)

func _calculate_required_tiles_for_path(path: Array) -> Array[Vector2]:
	var tiles: Array[Vector2] = []
	for node in path:
		var coord: Vector2i = node.get("coord", Vector2i.ZERO)
		var surface_type: int = node.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
		var tile_coord: = Vector2.ZERO
		match surface_type:
			SurfacePathfinding.SurfaceType.FLOOR_TOP:
				tile_coord = Vector2(coord.x, coord.y + _gravity_dir)
			SurfacePathfinding.SurfaceType.WALL_LEFT:
				tile_coord = Vector2(coord.x - 1, coord.y)
			SurfacePathfinding.SurfaceType.WALL_RIGHT:
				tile_coord = Vector2(coord.x + 1, coord.y)
			SurfacePathfinding.SurfaceType.VINE_CENTER:
				pass
		if tile_coord != Vector2.ZERO and not tiles.has(tile_coord):
			tiles.append(tile_coord)
	return tiles

func _is_path_valid(path: Array) -> bool:
	if path.is_empty():
		return false
	if not is_instance_valid(Level.map):
		return false
	var tiles: = _calculate_required_tiles_for_path(path)
	for tile_coord in tiles:
		if not Level.map.tiles.has(tile_coord):
			return false
	return true

func _grab_resource(resource_uid: int) -> bool:
	if not Level.drops.has_drop(resource_uid):
		return false

	var resource: Carryable = Level.drops.get_drop(resource_uid)

	Level.drops.network_goblin_carry(resource, self)
	_set_carried_resource_uid(resource_uid)

	var carry_position: = global_position + Vector2(0, -6 * _gravity_dir)
	var tween = create_tween()
	tween.tween_property(resource, "global_position", carry_position, 0.15)

	if not is_squad_goblin:
		_play_normal_sound("get_resource")
	return true

func _throw_resource_at_shredder():
	if is_squad_goblin:
		_play_squad_sound("drop")
	else:
		_play_normal_sound("drop")

	if not Network.is_server():
		return

	if not Level.drops.has_drop(carried_resource_uid):
		_set_carried_resource_uid(-1)
		return

	var carried_resource: Drop = Level.drops.get_drop(carried_resource_uid)
	Level.drops.network_goblin_release(carried_resource, self)

	var shredder = Level.getDome(teamId).getDropTarget(CONST.IRON)
	if shredder:
		carried_resource.floatToDropTarget(shredder)

	_set_carried_resource_uid(-1)



func _dropCarryInternal(carryable: Carryable) -> void :
	if carried_resource_uid != carryable.UID:
		return

	_set_carried_resource_uid(-1)
	carryable.freeCarry(self)

func _clear_target_resource():
	_is_pulling_resource = false
	if is_instance_valid(Level.drops) and Level.drops.has_drop(target_resource_uid) and _task_manager:
		_task_manager.release_resource(self, Level.drops.get_drop(target_resource_uid))
	target_resource_uid = -1

func blacklist_target(target_id: int) -> void :
	_blacklisted_targets[target_id] = Time.get_ticks_msec() + 5000

func is_target_blacklisted(target_id: int) -> bool:
	if not _blacklisted_targets.has(target_id):
		return false
	if Time.get_ticks_msec() > _blacklisted_targets[target_id]:
		_blacklisted_targets.erase(target_id)
		return false
	return true

func _handle_path_failure_to_resource() -> void :
	if target_resource_uid > 0:
		blacklist_target(target_resource_uid)
	_clear_target_resource()
	_clear_path()
	_enter_waiting_for_path_state()

func _handle_path_failure_to_hole() -> void :
	if is_instance_valid(target_hole):
		blacklist_target(target_hole.get_instance_id())
	_clear_path()
	_enter_waiting_for_path_state()

func _enter_waiting_for_path_state() -> void :
	_clear_target_resource()
	state = State.WAITING_FOR_PATH
	state_timer = _rng.randf_range(WAIT_FOR_PATH_DURATION_MIN, WAIT_FOR_PATH_DURATION_MAX)
	_path_recheck_timer = _rng.randf_range(PATH_RECHECK_INTERVAL_MIN, PATH_RECHECK_INTERVAL_MAX)
	_clear_path()
	state_updated.emit()

func _drop_resource_in_place() -> void :
	if not Level.drops.has_drop(carried_resource_uid):
		return

	var carried_resource: Carryable = Level.drops.get_drop(carried_resource_uid)
	Level.drops.network_goblin_release(carried_resource, self)

	if is_squad_goblin:
		_play_squad_sound("drop")
	else:
		_play_normal_sound("drop")

	_set_carried_resource_uid(-1)

func _emergency_return_to_cellar() -> void :
	if is_squad_goblin:
		_squad_cleanup_and_free()
		return
	_clear_target_resource()
	_clear_mining_target()
	if _task_manager:
		_task_manager.release_all_claims(self)
	_is_teleporting_outbound = false
	_set_as_teleporting()

func _process_waiting_for_path(delta):
	state_timer -= delta
	_path_recheck_timer -= delta

	if is_squad_goblin:
		if not current_surface_path.is_empty():
			if _is_path_stale():
				_clear_path()
				state_updated.emit()
			elif _move_along_surface_path(delta):
				_clear_path()
				_try_squad_idle_wander()
				state_updated.emit()
			elif _is_current_surface_destroyed():
				_clear_path()
				_enter_falling_state()
				return
		if Network.is_server():
			if _path_recheck_timer <= 0:
				_path_recheck_timer = _rng.randf_range(PATH_RECHECK_INTERVAL_MIN, PATH_RECHECK_INTERVAL_MAX)
				_request_squad_task()
				if state != State.WAITING_FOR_PATH:
					return
				if current_surface_path.is_empty():
					_try_squad_idle_wander()
				if current_surface_path.is_empty():
					_try_path_back_to_hole()
			if state_timer <= 0:
				state_timer = _rng.randf_range(WAIT_FOR_PATH_DURATION_MIN, WAIT_FOR_PATH_DURATION_MAX)
		return

	if not Network.is_server():
		return

	if _path_recheck_timer <= 0:
		_path_recheck_timer = _rng.randf_range(PATH_RECHECK_INTERVAL_MIN, PATH_RECHECK_INTERVAL_MAX)
		if _task_manager and _task_manager.request_task(self):
			return

	if state_timer <= 0:
		_return_or_disappear()

func _process_disappearing(delta):
	if Network.is_server():
		state_timer -= delta
		if state_timer <= 0:
			_emergency_return_to_cellar()

func _get_supporting_tile_coord() -> Vector2:
	match _current_surface_type:
		SurfacePathfinding.SurfaceType.FLOOR_TOP:
			return Vector2(_current_surface_coord.x, _current_surface_coord.y + _gravity_dir)
		SurfacePathfinding.SurfaceType.WALL_LEFT:
			return Vector2(_current_surface_coord.x - 1, _current_surface_coord.y)
		SurfacePathfinding.SurfaceType.WALL_RIGHT:
			return Vector2(_current_surface_coord.x + 1, _current_surface_coord.y)
		SurfacePathfinding.SurfaceType.VINE_CENTER:
			return Vector2.ZERO
	return Vector2.ZERO

func _is_current_surface_destroyed() -> bool:
	if is_in_cellar:
		return false
	if _current_surface_coord == Vector2i.ZERO:
		return false
	if not is_instance_valid(Level.map):
		return false
	if _current_surface_type == SurfacePathfinding.SurfaceType.VINE_CENTER:
		if not Level.map.is_tile_empty(Vector2(_current_surface_coord.x, _current_surface_coord.y)):
			return true
		if _navigator:
			var has_vine: = _navigator.has_vine_at(_current_surface_coord)
			return not has_vine
		return true
	var supporting_tile: = _get_supporting_tile_coord()
	return not Level.map.tiles.has(supporting_tile)

func _find_landing_surface_below() -> Dictionary:
	if not is_instance_valid(Level.map):
		return {}

	var tile_coord: Vector2
	if _current_surface_coord != Vector2i.ZERO:
		tile_coord = Vector2(_current_surface_coord)
	else:
		tile_coord = Level.map.getTileCoord(global_position)
	var start_y: int = int(tile_coord.y)
	var x: int = int(tile_coord.x)

	for step in range(50):
		var y: int = start_y + step * _gravity_dir
		var coord: = Vector2i(x, y)
		var below_solid: bool = Level.map.tiles.has(Vector2(x, y + _gravity_dir))
		var left_solid: bool = Level.map.tiles.has(Vector2(x - 1, y))
		var right_solid: bool = Level.map.tiles.has(Vector2(x + 1, y))
		var current_solid: bool = Level.map.tiles.has(Vector2(x, y))

		if current_solid:
			continue

		if below_solid:
			var world_pos: Vector2 = Vector2(x, y) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET + Vector2(0, GameWorld.TILE_SIZE / 2.0 * _gravity_dir)
			return {"position": world_pos, "surface_type": SurfacePathfinding.SurfaceType.FLOOR_TOP, "coord": coord}

		if _fall_surface_preference == SurfacePathfinding.SurfaceType.WALL_RIGHT and right_solid:
			var world_pos: Vector2 = Vector2(x, y) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET + Vector2(GameWorld.TILE_SIZE / 2.0, 0)
			return {"position": world_pos, "surface_type": SurfacePathfinding.SurfaceType.WALL_RIGHT, "coord": coord}

		if _fall_surface_preference == SurfacePathfinding.SurfaceType.WALL_LEFT and left_solid:
			var world_pos: Vector2 = Vector2(x, y) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET + Vector2( - GameWorld.TILE_SIZE / 2.0, 0)
			return {"position": world_pos, "surface_type": SurfacePathfinding.SurfaceType.WALL_LEFT, "coord": coord}

	return {}

func _enter_falling_state() -> void :
	_clear_target_resource()
	_clear_path()
	_clear_mining_target()
	if _movement_tween and _movement_tween.is_valid():
		_movement_tween.kill()
	_is_jumping = false

	if _current_surface_type == SurfacePathfinding.SurfaceType.WALL_RIGHT:
		_fall_surface_preference = SurfacePathfinding.SurfaceType.WALL_RIGHT
	elif _current_surface_type == SurfacePathfinding.SurfaceType.WALL_LEFT:
		_fall_surface_preference = SurfacePathfinding.SurfaceType.WALL_LEFT
	else:
		_fall_surface_preference = -1

	state = State.FALLING
	state_updated.emit()

func _process_falling(delta):
	global_position.y += FALL_SPEED * delta * _gravity_dir

	if Network.is_server() and is_squad_goblin and abs(global_position.y) > 5000:
		_squad_cleanup_and_free()
		return

	var landing: = _find_landing_surface_below()
	if not landing.is_empty():
		var landing_pos: Vector2 = landing.position + _get_surface_offset(landing.surface_type)
		if (global_position.y >= landing_pos.y) if _gravity_dir == 1 else (global_position.y <= landing_pos.y):
			global_position = landing_pos
			_current_surface_type = landing.surface_type
			_visual_surface_type = landing.surface_type
			_current_surface_coord = landing.coord
			_tween_to_surface_rotation(_current_surface_type)
			_fall_surface_preference = -1

			if not Network.is_server():
				return

			if is_squad_goblin and not is_instance_valid(_squad_origin_hole):
				state = State.DISAPPEARING
				state_timer = DISAPPEAR_ANIMATION_DURATION
				_sprite.play("idle")
				state_updated.emit()
				return
			state = State.WAITING_FOR_PATH
			state_timer = _rng.randf_range(WAIT_FOR_PATH_DURATION_MIN, WAIT_FOR_PATH_DURATION_MAX)
			_path_recheck_timer = _rng.randf_range(FALL_LANDING_PAUSE_MIN, FALL_LANDING_PAUSE_MAX)
			state_updated.emit()

func _move_along_surface_path(delta) -> bool:
	if _is_jumping:
		return false

	if current_surface_path.is_empty() or surface_path_index >= current_surface_path.size():
		return true
	step_dust.emitting = true
	var remaining: float = SURFACE_MOVE_SPEED * delta

	while remaining > 0.0 and surface_path_index < current_surface_path.size():
		var target_node: Dictionary = current_surface_path[surface_path_index]
		var target_pos: Vector2 = target_node.position + target_node.get("_offset", Vector2.ZERO)

		var target_surface: int = target_node.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
		_visual_surface_type = target_surface

		if target_node.get("is_jump", false):
			_start_jump_to(target_node)
			return false

		var to_target: Vector2 = target_pos - global_position
		var dist: = to_target.length()

		if dist <= remaining:
			global_position = target_pos
			remaining -= dist
			_arrive_at_surface_node(target_node)
			surface_path_index += 1
		else:
			global_position += (to_target / dist) * remaining
			_update_facing_for_movement(to_target)
			remaining = 0.0

	return surface_path_index >= current_surface_path.size()

func _start_jump_to(target: Dictionary) -> void :
	_is_jumping = true
	if is_squad_goblin:
		_play_squad_sound("jump")
	else:
		_play_normal_sound("jump")
	var start_pos: = global_position
	var end_pos: Vector2 = target.position + target.get("_offset", Vector2.ZERO)
	_update_facing_for_movement(end_pos - start_pos)
	var mid_pos: = (start_pos + end_pos) / 2 + Vector2(0, -16 * _gravity_dir)

	if _movement_tween and _movement_tween.is_valid():
		_movement_tween.kill()

	_movement_tween = create_tween()
	_movement_tween.tween_method(_jump_arc_position.bind(start_pos, mid_pos, end_pos), 0.0, 1.0, JUMP_TWEEN_DURATION)
	_movement_tween.tween_callback(_on_jump_complete.bind(target))

func _jump_arc_position(t: float, start: Vector2, mid: Vector2, end: Vector2) -> void :
	var p0: = start.lerp(mid, t)
	var p1: = mid.lerp(end, t)
	global_position = p0.lerp(p1, t)

func _on_jump_complete(target: Dictionary) -> void :
	_is_jumping = false
	if is_instance_valid(Level.map):
		var target_coord: Vector2i = target.get("coord", Vector2i.ZERO)
		var target_type: int = target.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
		var supporting: = Vector2.ZERO
		match target_type:
			SurfacePathfinding.SurfaceType.FLOOR_TOP:
				supporting = Vector2(target_coord.x, target_coord.y + _gravity_dir)
			SurfacePathfinding.SurfaceType.WALL_LEFT:
				supporting = Vector2(target_coord.x - 1, target_coord.y)
			SurfacePathfinding.SurfaceType.WALL_RIGHT:
				supporting = Vector2(target_coord.x + 1, target_coord.y)
		if supporting != Vector2.ZERO and not Level.map.tiles.has(supporting):
			_clear_path()
			_enter_falling_state()
			return
	global_position = target.position + target.get("_offset", Vector2.ZERO)
	_arrive_at_surface_node(target)
	surface_path_index += 1

func _arrive_at_surface_node(node: Dictionary) -> void :
	var new_surface_type: int = node.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
	var new_coord: Vector2i = node.get("coord", Vector2i.ZERO)

	var rotation_target_type: = new_surface_type
	if surface_path_index + 1 < current_surface_path.size():
		var next_node: Dictionary = current_surface_path[surface_path_index + 1]
		if not next_node.get("is_jump", false):
			rotation_target_type = next_node.get("surface_type", new_surface_type)

	if rotation_target_type != _visual_surface_type:
		_tween_to_surface_rotation(rotation_target_type)
		_visual_surface_type = rotation_target_type
		_update_climbing_sounds(rotation_target_type)

	_current_surface_type = new_surface_type
	_current_surface_coord = new_coord

func _update_climbing_sounds(surface_type: int) -> void :
	if is_squad_goblin:
		return
	var on_vine: bool = surface_type == SurfacePathfinding.SurfaceType.VINE_CENTER
	var on_wall: bool = surface_type == SurfacePathfinding.SurfaceType.WALL_LEFT or surface_type == SurfacePathfinding.SurfaceType.WALL_RIGHT
	if on_vine and not $VineClimbSound.playing:
		$WallClimbSound.stop()
		$VineClimbSound.startSound()
	elif on_wall and not $WallClimbSound.playing:
		$VineClimbSound.stop()
		$WallClimbSound.startSound()
	elif not on_vine and not on_wall:
		$VineClimbSound.stop()
		$WallClimbSound.stop()

func _stop_climbing_sounds() -> void :
	if not is_squad_goblin:
		$VineClimbSound.stop()
		$WallClimbSound.stop()

func _tween_to_surface_rotation(surface_type: int) -> void :
	if _rotation_tween and _rotation_tween.is_valid():
		_rotation_tween.kill()

	_rotation_tween = create_tween()
	_rotation_tween.tween_property(_sprite, "rotation", 0.0, ROTATION_TWEEN_DURATION)

func _update_facing_for_movement(move_dir: Vector2) -> void :
	if abs(move_dir.x) > 0.1:
		facing_direction = sign(move_dir.x)
	if abs(move_dir.y) > 0.1:
		_wall_moving_up = move_dir.y < 0

func assign_task(exit_hole: Node2D) -> void :
	_unassign_from_hole()
	_target_exit_hole = exit_hole
	_notify_hole_assigned(exit_hole)
	_jump_to_entrance_hole()

func _return_to_cellar() -> void :
	_is_pulling_resource = false
	_visual_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
	_current_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
	_unassign_from_hole()
	_target_exit_hole = null
	_pinned_mining_tile = null
	_pinned_mining_tile_coord = Vector2.ZERO
	if _task_manager:
		_task_manager.release_all_claims(self)
	if is_in_cellar:
		_enter_cellar_wander()
		return
	_is_teleporting_outbound = false
	_set_as_teleporting()

func get_mining_speed() -> float:
	return float(Data.ofOr(playerId + ".keeper4.catgoblinminingspeed", 0.0))

func _enter_nap_or_wander() -> void :
	var nap_duration: float = Data.ofOr(playerId + ".keeper4.goblinnapduration", 0.0) * randf_range(0.8, 1.3)
	if nap_duration > 0.0:
		var wander_fraction: float = _rng.randf_range(0.05, 0.1)
		_nap_wander_timer = nap_duration * wander_fraction
		_nap_timer = nap_duration - _nap_wander_timer
		_wander_target_progress = _rng.randf() * _wander_curve.get_baked_length() if _wander_curve else 0.0
		state = State.NAPPING
		state_updated.emit()
	else:
		_enter_cellar_wander()

func _process_napping(delta):
	if _nap_wander_timer > 0:
		_nap_wander_timer -= delta
		_process_cellar_wander(delta)
		return
	_nap_timer -= delta
	if _nap_timer <= 0:
		_play_normal_sound("wake_up")
		_enter_cellar_wander()

func _process_cellar_wander(delta):
	if not _wander_curve or not is_instance_valid(_wander_base_node):
		return

	var path_length: = _wander_curve.get_baked_length()
	if path_length <= 0:
		return

	var local_pos: Vector2 = _wander_curve.sample_baked(_wander_progress)
	var current_pos: Vector2 = _wander_base_node.global_position + local_pos
	global_position.y = current_pos.y

	if _wander_pause_timer > 0:
		_wander_pause_timer -= delta
		if _wander_pause_timer <= 0 and Network.is_server():
			_wander_target_progress = _rng.randf() * path_length
			state_updated.emit()
		return

	var dist_to_target: = _wander_target_progress - _wander_progress
	if abs(dist_to_target) < 2.0 and Network.is_server():
		_wander_pause_timer = _rng.randf_range(0.5, 2.5)
		state_updated.emit()
		return

	var move_dir: float = sign(dist_to_target)
	_wander_progress += move_dir * SURFACE_MOVE_SPEED * 0.5 * delta
	_wander_progress = clamp(_wander_progress, 0.0, path_length)

	local_pos = _wander_curve.sample_baked(_wander_progress)
	var target_pos: Vector2 = _wander_base_node.global_position + local_pos
	var dir_to_pos: = target_pos - global_position

	if abs(dir_to_pos.x) > 1.0:
		global_position.x += sign(dir_to_pos.x) * SURFACE_MOVE_SPEED * 0.5 * delta
		move_direction = sign(dir_to_pos.x)
		facing_direction = move_direction

	global_position.y = target_pos.y

func _process_walking_to_entrance_hole(_delta):
	pass

func _process_teleporting(delta):
	teleport_timer -= delta
	if teleport_timer <= 0:
		if _is_teleporting_outbound:
			_teleport_outbound()
		else:
			_teleport_inbound()

func _set_as_teleporting(should_clear_path: bool = true) -> void :
	visible = false
	state = State.TELEPORTING
	teleport_timer = _rng.randf_range(TELEPORT_DURATION - 0.3, TELEPORT_DURATION + 0.3)
	if should_clear_path:
		_clear_path()
	if Level.drops.has_drop(carried_resource_uid):
		Level.drops.network_hide_drop(Level.drops.get_drop(carried_resource_uid))
	state_updated.emit()

func _teleport_outbound():
	if is_instance_valid(_target_exit_hole):
		_origin_hole = _target_exit_hole
		global_position = _target_exit_hole.global_position
		if _target_exit_hole.has_method("reveal"):
			_target_exit_hole.reveal()
	if is_squad_goblin:
		_play_squad_sound("out_from_hole")
	else:
		_play_normal_sound("out_from_hole")
	is_in_cellar = false
	_has_greeted = false
	target_hole = null
	_current_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
	_visual_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
	if Network.is_server():
		visible = true
		_start_hop_from_hole()
		if Level.drops.has_drop(carried_resource_uid):
			Level.drops.network_show_drop(Level.drops.get_drop(carried_resource_uid))

func _teleport_inbound():
	var entrance_hole = _goblins_node.get_entrance_hole() if _goblins_node else null
	if is_instance_valid(entrance_hole) and is_instance_valid(_wander_base_node) and _wander_curve:
		global_position = entrance_hole.global_position
		is_in_cellar = true
		target_hole = null
		_clear_path()
		_current_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
		_visual_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
		if Network.is_server():
			visible = true
			if Level.drops.has_drop(carried_resource_uid):
				Level.drops.network_show_drop(Level.drops.get_drop(carried_resource_uid))
			var landing_progress: float = _rng.randf() * _wander_curve.get_baked_length()
			var landing_local: Vector2 = _wander_curve.sample_baked(landing_progress)
			var landing_pos: Vector2 = _wander_base_node.global_position + landing_local
			_wander_progress = landing_progress
			_entrance_landing_pos = landing_pos
			_update_facing_for_movement(landing_pos - global_position)
			_is_jumping = true
			_start_hole_hop(global_position, landing_pos, _on_entrance_exit_hop_complete, ENTRANCE_HOP_HEIGHT)
			state = State.JUMPING_FROM_ENTRANCE_HOLE
			state_updated.emit()
	else:
		is_in_cellar = true
		visible = true
		target_hole = null
		_clear_path()
		_current_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
		_visual_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
		if Level.drops.has_drop(carried_resource_uid):
			Level.drops.network_show_drop(Level.drops.get_drop(carried_resource_uid))
			state = State.THROW_DELAY
			state_timer = _rng.randf_range(0.4, 0.6)
			state_updated.emit()
		else:
			_enter_nap_or_wander()

func _on_entrance_exit_hop_complete() -> void :
	_is_jumping = false
	is_in_cellar = true
	_visual_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
	_current_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
	if Level.drops.has_drop(carried_resource_uid):
		_enter_throw_delay_facing_shredder()
	else:
		_enter_nap_or_wander()
		state_timer = _rng.randf_range(1.0, 3.0)

func _start_hole_hop(from_pos: Vector2, to_pos: Vector2, on_complete: Callable, height: float = HOLE_HOP_HEIGHT) -> void :
	if _hole_hop_tween and _hole_hop_tween.is_valid():
		_hole_hop_tween.kill()

	var mid_pos: = (from_pos + to_pos) / 2.0 + Vector2(0, - height * _gravity_dir)

	_hole_hop_tween = create_tween()
	_hole_hop_tween.tween_method(_hole_hop_arc.bind(from_pos, mid_pos, to_pos), 0.0, 1.0, HOLE_HOP_DURATION)
	_hole_hop_tween.tween_callback(on_complete)

func _hole_hop_arc(t: float, start: Vector2, mid: Vector2, end: Vector2) -> void :
	var p0: = start.lerp(mid, t)
	var p1: = mid.lerp(end, t)
	global_position = p0.lerp(p1, t)

func _process_hopping_from_hole(delta):
	if _hop_from_hole_phase == 0:
		if _sprite.animation != "hole_exit_start":
			_sprite.play("hole_exit_start")
		elif not _sprite.is_playing():
			_hop_from_hole_phase = 1
			if Network.is_server():
				var target_surface_type: int = _hole_hop_target.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
				var target_pos: Vector2 = _hole_hop_target.get("position", global_position) + _get_surface_offset(target_surface_type)
				_hop_from_hole_target_pos = target_pos
			_sprite.play("hole_exit_start")
			_sprite.frame = _sprite.sprite_frames.get_frame_count("hole_exit_start") - 1
			_sprite.pause()
	elif _hop_from_hole_phase == 1:
		var dir: Vector2 = _hop_from_hole_target_pos - global_position
		var dist: float = dir.length()
		var move_amount: float = HOLE_EXIT_MOVE_SPEED * delta
		if dist <= move_amount:
			if Network.is_server():
				global_position = _hop_from_hole_target_pos
				_on_hop_from_hole_complete()
		else:
			global_position += (dir / dist) * move_amount
			_update_facing_for_movement(dir)

func _process_cave_wander(delta):
	if not Network.is_server():
		_move_along_surface_path(delta)
		return
	if not current_surface_path.is_empty():
		if _is_path_stale():
			_clear_path()
			state_timer = Keeper4GameplaySettings.SQUAD_HOP_PAUSE + _rng.randf_range( - Keeper4GameplaySettings.SQUAD_HOP_PAUSE_VARIANCE, Keeper4GameplaySettings.SQUAD_HOP_PAUSE_VARIANCE)
			return

		if _move_along_surface_path(delta):
			_clear_path()
			state_timer = Keeper4GameplaySettings.SQUAD_HOP_PAUSE + _rng.randf_range( - Keeper4GameplaySettings.SQUAD_HOP_PAUSE_VARIANCE, Keeper4GameplaySettings.SQUAD_HOP_PAUSE_VARIANCE)
		return

	if state_timer > 0:
		state_timer -= delta
		if state_timer <= 0:
			_request_task()

func _on_hop_from_hole_complete() -> void :
	var target_surface_type: int = _hole_hop_target.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
	var target_coord: Vector2i = _hole_hop_target.get("coord", Vector2i.ZERO)
	var target_pos: Vector2 = _hole_hop_target.get("position", global_position) + _get_surface_offset(target_surface_type)
	global_position = target_pos
	_current_surface_type = target_surface_type
	_visual_surface_type = target_surface_type
	_current_surface_coord = target_coord
	_tween_to_surface_rotation(target_surface_type)
	_hole_hop_target = {}
	if _task_manager:
		_task_manager.release_hop_target(self)

	_clear_path()
	state_timer = Keeper4GameplaySettings.SQUAD_HOP_PAUSE + _rng.randf_range( - Keeper4GameplaySettings.SQUAD_HOP_PAUSE_VARIANCE, Keeper4GameplaySettings.SQUAD_HOP_PAUSE_VARIANCE)
	state = State.CAVE_WANDER
	state_updated.emit()

func _process_hopping_to_hole(delta):
	if _hop_to_hole_phase == 0:
		var target_pos: Vector2 = _hole_hop_target.get("position", global_position) + Vector2(0, 3 * _gravity_dir)
		var dir: Vector2 = target_pos - global_position
		var dist: float = dir.length()
		var move_amount: float = HOLE_EXIT_MOVE_SPEED * delta
		if dist <= move_amount:
			global_position = target_pos
			_hop_to_hole_phase = 1
			_sprite.play("hole_enter")
		else:
			global_position += (dir / dist) * move_amount
	elif _hop_to_hole_phase == 1:
		if _sprite.animation != "hole_enter":
			_sprite.play("hole_enter")
		elif not _sprite.is_playing():
			if Network.is_server():
				_on_hop_to_hole_complete()
			else:
				visible = false

func _on_hop_to_hole_complete() -> void :
	_hole_hop_target = {}
	if is_squad_goblin:
		_play_squad_sound("into_hole")
		_unassign_from_hole()
		_squad_cleanup_and_free()
		return
	_unassign_from_hole()
	_target_exit_hole = null
	_is_teleporting_outbound = false
	_play_normal_sound("into_hole")
	_set_as_teleporting()

func _process_moving_to_cellar_resource(delta):
	if not Network.is_server():
		return

	if not Level.drops.has_drop(target_resource_uid):
		_enter_cellar_wander()
		return
	var target_resource: Carryable = Level.drops.get_drop(target_resource_uid)
	var dx: float = target_resource.global_position.x - global_position.x
	if global_position.distance_squared_to(target_resource.global_position) < MAX_PULL_START_DISTANCE_SQ:
		state_timer = _rng.randf_range(GRAB_DURATION.x, GRAB_DURATION.y)
		state = State.GRABBING
		state_updated.emit()
		return
	global_position.x += sign(dx) * SURFACE_MOVE_SPEED * delta
	facing_direction = sign(dx)
	move_direction = facing_direction

func _process_moving_to_resource(delta):
	if not Network.is_server():
		_move_along_surface_path(delta)
		return

	var abort: bool = not Level.drops.has_drop(target_resource_uid)
	if not abort:
		var drop: Carryable = Level.drops.get_drop(target_resource_uid)
		abort = not drop.carriedBy.is_empty()
		if abort:
			abort = false
			for c in drop.carriedBy:
				if not (c is KunaiCarrier) or not c.attached:
					abort = true
					break

	if abort:
		_is_pulling_resource = false
		_clear_target_resource()
		_clear_path()
		_request_task()
		return

	var target_resource: Carryable = Level.drops.get_drop(target_resource_uid)

	var dist_sq = global_position.distance_squared_to(target_resource.global_position)
	if _is_pulling_resource:
		for c in target_resource.carriedBy:
			if c is KunaiCarrier:
				Level.drops.network_drop_from_all(target_resource)
				break
		var dir_to_self: Vector2 = global_position - target_resource.global_position
		var dist = dir_to_self.length()
		if dist > 2.0:
			target_resource.global_position += dir_to_self * (RESOURCE_PULL_SPEED * delta / dist)
		if dist_sq < 64.0:
			state_timer = _rng.randf_range(GRAB_DURATION.x, GRAB_DURATION.y)
			state = State.GRABBING
			state_updated.emit()
		return

	if dist_sq < 64.0:
		for c in target_resource.carriedBy:
			if c is KunaiCarrier and c.attached:
				Level.drops.network_drop_from_all(target_resource)
				break
		state_timer = _rng.randf_range(GRAB_DURATION.x, GRAB_DURATION.y)
		state = State.GRABBING
		state_updated.emit()
		return

	if _has_resource_moved_significantly():
		_expected_resource_position = target_resource.global_position
		var holes: Array = _task_manager.get_valid_holes()
		var in_range: = false
		for hole in holes:
			if target_resource.global_position.distance_squared_to(hole.global_position) <= GoblinTaskManager.RESOURCE_GRAB_RANGE_SQ:
				in_range = true
				break
		if not in_range:
			_handle_path_failure_to_resource()
			return
		if not _refresh_surface_path_to_target():
			_handle_path_failure_to_resource()
			return

	if _is_path_stale():
		if not _refresh_surface_path_to_target():
			_handle_path_failure_to_resource()
			return

	if _move_along_surface_path(delta):
		if dist_sq <= MAX_PULL_START_DISTANCE_SQ:
			for c in target_resource.carriedBy:
				if c is KunaiCarrier and c.attached:
					Level.drops.network_drop_from_all(target_resource)
					break
			_is_pulling_resource = true
		else:
			if target_resource_uid > 0:
				blacklist_target(target_resource_uid)
			_clear_target_resource()
			_clear_path()
			_enter_waiting_for_path_state()

func _process_grabbing(delta):
	if not Network.is_server():
		return

	state_timer -= delta
	if state_timer <= 0:
		if Level.drops.has_drop(carried_resource_uid):
			_clear_path()
			if is_in_cellar:
				_enter_throw_delay_facing_shredder()
			else:
				_request_task()
			return
		if _grab_resource(target_resource_uid):
			if _task_manager:
				_task_manager.release_resource(self, Level.drops.get_drop(target_resource_uid))
			target_resource_uid = -1
			_is_pulling_resource = false
			state_timer = _rng.randf_range(Keeper4GameplaySettings.GOBLIN_PAUSE_AFTER_GRAB.x, Keeper4GameplaySettings.GOBLIN_PAUSE_AFTER_GRAB.y)
		else:
			_clear_target_resource()
			_clear_path()
			_request_task()

func _process_moving_to_hole(delta):
	if not Network.is_server():
		_move_along_surface_path(delta)
		return
	if is_squad_goblin and _squad_timer > 0:
		_clear_path()
		_request_squad_task()
		return
	if not is_instance_valid(target_hole):
		_clear_path()
		_handle_path_failure_to_hole()
		return

	if _is_path_stale():
		if not _refresh_surface_path_to_target():
			_handle_path_failure_to_hole()
			return

	if _move_along_surface_path(delta):
		if not current_surface_path.is_empty():
			var last_waypoint: Dictionary = current_surface_path[current_surface_path.size() - 1]
			var last_waypoint_pos: Vector2 = last_waypoint.get("position", global_position)
			var dist_to_hole_sq: float = last_waypoint_pos.distance_squared_to(target_hole.global_position)
			var is_waypoint_adjacent: bool = dist_to_hole_sq <= SurfacePathfinding.ADJACENT_DISTANCE_SQ
			if is_waypoint_adjacent:
				_hole_hop_target = {"position": target_hole.global_position}
				if target_hole.global_position.x < global_position.x:
					facing_direction = -1.0
				elif target_hole.global_position.x > global_position.x:
					facing_direction = 1.0
				_hop_to_hole_phase = 0
				state = State.HOPPING_TO_HOLE
				state_updated.emit()
				return
			else:
				if is_instance_valid(target_hole):
					blacklist_target(target_hole.get_instance_id())
				_clear_path()
				_enter_waiting_for_path_state()
				return

func _process_jumping_from_entrance_hole(_delta):
	pass

func _process_throw_delay(delta):
	if not Network.is_server():
		return

	state_timer -= delta
	if state_timer <= 0:
		state = State.THROWING
		state_timer = _rng.randf_range(THROW_DURATION.x, THROW_DURATION.y)
		state_updated.emit()

func _process_throwing(delta):
	state_timer -= delta
	if state_timer <= 0:
		_throw_resource_at_shredder()
		if _grabbed_in_cellar:
			_enter_cellar_wander()
		else:
			_enter_nap_or_wander()

func _draw():
	if not DEBUG_PATH:
		return

	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
	draw_circle(Vector2.ZERO, 3.0, Color.MAGENTA)

	var font: Font = preload("res://gui/fonts/small_pixel.ttf")
	var font_size: int = 8
	var y_offset: float = -20.0
	var line_height: float = 8.0

	var state_name: String = State.keys()[state] if state < State.keys().size() else str(state)
	draw_string(font, Vector2(-15, y_offset), state_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	y_offset += line_height

	var objective: String = ""
	if state == State.MINING or state == State.MOVING_TO_MINE_SURFACE:
		objective = "tile=%s" % _mine_target_tile_coord
	elif state == State.MOVING_TO_HOLE or state == State.HOPPING_TO_HOLE:
		objective = "hole"
	elif state == State.WAITING_FOR_PATH:
		objective = "waiting"
	draw_string(font, Vector2(-15, y_offset), objective, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
	y_offset += line_height

	draw_string(font, Vector2(-15, y_offset), "state=%.1f" % state_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.CYAN)
	y_offset += line_height

	if is_squad_goblin:
		draw_string(font, Vector2(-15, y_offset), "squad=%.1f" % _squad_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.GREEN)

	if not current_surface_path.is_empty():
		var inv_transform: Transform2D = get_global_transform().affine_inverse()

		for i in range(current_surface_path.size() - 1):
			var from_node: Dictionary = current_surface_path[i]
			var to_node: Dictionary = current_surface_path[i + 1]
			var from_pos: Vector2 = inv_transform * from_node.position
			var to_pos: Vector2 = inv_transform * to_node.position

			var is_jump: bool = to_node.get("is_jump", false)
			var color: = DEBUG_COLOR_JUMP if is_jump else DEBUG_COLOR_WALK
			draw_line(from_pos, to_pos, color, 2.0)

		for i in range(current_surface_path.size()):
			var node: Dictionary = current_surface_path[i]
			var pos: Vector2 = inv_transform * node.position
			var surface_type: int = node.get("surface_type", 0)
			var is_jump: bool = node.get("is_jump", false)

			var color: = DEBUG_COLOR_SURFACE_FLOOR
			if surface_type == SurfacePathfinding.SurfaceType.WALL_LEFT or surface_type == SurfacePathfinding.SurfaceType.WALL_RIGHT:
				color = DEBUG_COLOR_SURFACE_WALL

			draw_circle(pos, 4.0, color)

			if is_jump:
				draw_circle(pos, 6.0, DEBUG_COLOR_JUMP)

func _update_animation():
	if state != State.MINING and state != State.GRABBING:
		var path_active: bool = not current_surface_path.is_empty() and surface_path_index < current_surface_path.size()
		var wander_moving: bool = _wander_pause_timer <= 0 and absf(_wander_target_progress - _wander_progress) > 1.0
		var nap_moving: bool = _nap_wander_timer > 0
		var sig: int = state
		sig = (sig << 4) | (_visual_surface_type & 15)
		sig = (sig << 4) | (_current_surface_type & 15)
		sig = (sig << 3) | ((_hop_from_hole_phase + 1) & 7)
		sig = (sig << 3) | ((_hop_to_hole_phase + 1) & 7)
		sig = (sig << 1) | int(_is_jumping)
		sig = (sig << 1) | int(facing_direction < 0)
		sig = (sig << 1) | int(_wall_moving_up)
		sig = (sig << 1) | int(_gravity_dir == -1)
		sig = (sig << 1) | int(path_active)
		sig = (sig << 1) | int(wander_moving)
		sig = (sig << 1) | int(nap_moving)
		sig = (sig << 1) | int(visible)
		if sig == _last_anim_sig:
			return
		_last_anim_sig = sig
	else:
		_last_anim_sig = -1

	var _is_on_wall: = _visual_surface_type == SurfacePathfinding.SurfaceType.WALL_LEFT or _visual_surface_type == SurfacePathfinding.SurfaceType.WALL_RIGHT or _visual_surface_type == SurfacePathfinding.SurfaceType.VINE_CENTER
	var _is_on_vine: = _visual_surface_type == SurfacePathfinding.SurfaceType.VINE_CENTER
	var _run_anim: String = "vine_climb_loop" if _is_on_vine else ("run_wall" if _is_on_wall else "run")
	var _idle_anim: String = "run_wall" if _is_on_wall else "idle"
	var _wall_idle: = false
	var _handled: = false

	match state:
		State.DISAPPEARING:
			_handled = true
		State.FALLING:
			_sprite.play("fall")
			_handled = true
		State.MINING:
			if _current_surface_type == SurfacePathfinding.SurfaceType.FLOOR_TOP:
				_sprite.play("dig_down")
				_sprite.flip_h = facing_direction < 0
				_sprite.flip_v = _gravity_dir == -1
			else:
				var below_coord: = Vector2(_current_surface_coord.x, _current_surface_coord.y + _gravity_dir)
				if is_instance_valid(Level.map) and Level.map.tiles.has(below_coord):
					_sprite.play("dig_side")
				else:
					_sprite.play("dig_side_wall")
			_handled = true
		State.GRABBING:
			if Level.drops.has_drop(carried_resource_uid):
				_wall_idle = _is_on_wall
				_sprite.play(_idle_anim)
			else:
				_sprite.play("dig_side")
			_handled = true
		State.THROWING:
			_sprite.play("dig_side")
			_handled = true
		State.HOPPING_FROM_HOLE:
			if _hop_from_hole_phase == 0:
				_sprite.play("hole_exit_start")
				_handled = true
			elif _hop_from_hole_phase == 1:
				_sprite.frame = _sprite.sprite_frames.get_frame_count("hole_exit_start") - 1
				_handled = true
		State.HOPPING_TO_HOLE:
			if _hop_to_hole_phase == 0:
				_sprite.play(_run_anim)
			elif _hop_to_hole_phase == 1:
				_sprite.play("hole_enter")
			_handled = true
		State.TELEPORTING:
			if visible:
				_wall_idle = _is_on_wall
				_sprite.play(_idle_anim)
			_handled = true

	if not _handled:
		if _is_jumping:
			_sprite.play("jump")
		elif not current_surface_path.is_empty() and surface_path_index < current_surface_path.size():
			_sprite.play(_run_anim)
		elif state == State.CELLAR_WANDER and _wander_pause_timer <= 0 and abs(_wander_target_progress - _wander_progress) > 1.0:
			_sprite.play(_run_anim)
		elif state == State.MOVING_TO_CELLAR_RESOURCE:
			_sprite.play(_run_anim)
		elif state == State.NAPPING and _nap_wander_timer > 0:
			_sprite.play(_run_anim)
		elif state == State.NAPPING:
			_sprite.play("sleep")
		else:
			_wall_idle = _is_on_wall
			_sprite.play(_idle_anim)

	if _wall_idle:
		_sprite.stop()
		_sprite.frame = 0

	if not _is_on_vine:
		_sprite.speed_scale = abs(_sprite.speed_scale)

	var is_tweening_rotation: = _rotation_tween and _rotation_tween.is_running()
	if not is_tweening_rotation:
		_sprite.rotation = 0.0

	var _inverted: bool = _gravity_dir == -1
	var _on_horizontal: bool = _visual_surface_type == SurfacePathfinding.SurfaceType.FLOOR_TOP
	_sprite.position.y = 1 if (_inverted and _on_horizontal) else -1

	if _is_jumping or state == State.GRABBING:
		_sprite.flip_h = facing_direction < 0
		_sprite.flip_v = _inverted
		return

	var _is_mining_wall: = state == State.MINING and _visual_surface_type != SurfacePathfinding.SurfaceType.FLOOR_TOP
	match _visual_surface_type:
		SurfacePathfinding.SurfaceType.WALL_LEFT:
			_sprite.flip_h = true
			_sprite.flip_v = false if _is_mining_wall else not _wall_moving_up
		SurfacePathfinding.SurfaceType.WALL_RIGHT:
			_sprite.flip_h = false
			_sprite.flip_v = false if _is_mining_wall else not _wall_moving_up
		SurfacePathfinding.SurfaceType.VINE_CENTER:
			_sprite.flip_h = false
			_sprite.flip_v = false
			if _sprite.animation == "vine_climb_loop":
				var climbing_up: bool = _wall_moving_up != _inverted
				if climbing_up:
					_sprite.speed_scale = abs(_sprite.speed_scale)
				else:
					_sprite.speed_scale = - abs(_sprite.speed_scale)
		_:
			_sprite.flip_h = facing_direction < 0
			_sprite.flip_v = _inverted

func _notify_hole_assigned(hole: Node2D) -> void :
	hole.on_goblin_assigned()

func _unassign_from_hole() -> void :
	if is_instance_valid(_target_exit_hole):
		_target_exit_hole.on_goblin_unassigned()

func assign_mining_task(exit_hole: Node2D, tile, tile_coord: Vector2) -> void :
	_unassign_from_hole()
	_target_exit_hole = exit_hole
	_notify_hole_assigned(exit_hole)
	_assigned_hole_for_mining = exit_hole
	_pinned_mining_tile = tile
	_pinned_mining_tile_coord = tile_coord
	_jump_to_entrance_hole()

func onGameLost() -> void :
	if not Network.is_server():
		return
	if state == State.JUMPING_TO_ENTRANCE_HOLE or state == State.TELEPORTING or state == State.DISAPPEARING or state == State.FALLING:
		return
	if is_in_cellar:
		_sprite.play("idle")
	await get_tree().create_timer(_rng.randf_range(0.1, 0.5)).timeout
	if not is_instance_valid(self):
		return
	if is_in_cellar:
		var entrance_pos: Vector2 = _goblins_node.get_entrance_hole().global_position
		_update_facing_for_movement(entrance_pos - global_position)
		state = State.JUMPING_TO_ENTRANCE_HOLE
		state_timer = 0.0
		state_updated.emit()
		_is_jumping = true
		_sprite.play("jump")
		_start_hole_hop(global_position, entrance_pos, _on_entrance_hop_complete, ENTRANCE_HOP_HEIGHT)
	else:
		_start_disappearing()

func _jump_to_entrance_hole() -> void :
	var entrance_hole = _goblins_node.get_entrance_hole() if _goblins_node else null
	if not is_instance_valid(entrance_hole):
		_enter_cellar_wander()
		return
	var entrance_pos: Vector2 = entrance_hole.global_position
	_update_facing_for_movement(entrance_pos - global_position)
	var delay: float = _rng.randf_range(0.0, 0.8)
	state = State.JUMPING_TO_ENTRANCE_HOLE
	state_timer = delay
	state_updated.emit()

func _process_jumping_to_entrance_hole(delta):
	if _is_jumping:
		return
	if state_timer > 0:
		state_timer -= delta
		if state_timer <= 0:
			var entrance_hole = _goblins_node.get_entrance_hole() if _goblins_node else null
			if is_instance_valid(entrance_hole):
				_is_jumping = true
				_start_hole_hop(global_position, entrance_hole.global_position, _on_entrance_hop_complete, ENTRANCE_HOP_HEIGHT)

func _on_entrance_hop_complete() -> void :
	_is_jumping = false
	_play_normal_sound("into_hole")
	if not Network.is_server():
		visible = false
		return
	var entrance_hole = _goblins_node.get_entrance_hole() if _goblins_node else null
	if is_instance_valid(entrance_hole):
		target_hole = entrance_hole
		_is_teleporting_outbound = true
		_set_as_teleporting(false)
	else:
		_enter_cellar_wander()

func _process_moving_to_mine_surface(delta):
	if not Network.is_server():
		_move_along_surface_path(delta)
		return

	if not is_instance_valid(_mine_target_tile):
		_clear_mining_target()
		_request_task()
		return

	if _is_path_stale():
		if not _refresh_path_to_mine_surface():
			_clear_mining_target()
			_request_task()
			return

	if _move_along_surface_path(delta):
		var mining_offset: float = _rng.randf_range(-5.0, 5.0)
		match _current_surface_type:
			SurfacePathfinding.SurfaceType.FLOOR_TOP:
				global_position.x += mining_offset
			SurfacePathfinding.SurfaceType.WALL_LEFT, SurfacePathfinding.SurfaceType.WALL_RIGHT:
				global_position.y += mining_offset
		_face_tile(_mine_target_tile_coord)
		state = State.MINING
		_mine_timer = 0.0
		state_updated.emit()
		if is_squad_goblin:
			_play_squad_sound("startdig")
			$SquadSound / DigSound.startSound()
		else:
			_play_normal_sound("start_dig")
			$NormalSound / ExtractSound.startSound()

func _process_mining(delta):
	if not Network.is_server():
		return

	if not is_instance_valid(_mine_target_tile):
		if is_squad_goblin:
			_last_squad_mined_coord = _mine_target_tile_coord
		_clear_mining_target()
		_on_tile_mined()
		return

	if _mine_target_tile.isTileOverlayType(Data.TILE_OVERLAY_WORMS):
		_clear_mining_target()
		_request_task()
		return

	if is_squad_goblin:
		_mine_timer += delta
		if _mine_timer >= MINING_INTERVAL:
			_mine_timer = 0.0
			if is_instance_valid(_mine_target_tile):
				var dir: Vector2 = global_position - _mine_target_tile.global_position
				var damage = Keeper4GameplaySettings.SQUAD_MINE_DAMAGE_PERCENT / sqrt(_mine_target_tile.hardnessMultiplier)
				_mine_target_tile.hit(dir, _mine_target_tile.max_health * damage)

				for _i in 3:
					var t = Data.TILE_DIRT_PARTICLE.instantiate()
					t.modulate = Level.map.getBiomeColorByCoord(_mine_target_tile.coord)
					t.position = global_position
					Level.map.addDrop(t)
					t.apply_central_impulse(dir.normalized().rotated(randfn(0.0, 0.7)) * randf_range(40, 80))

				_play_squad_sound("extractresource")

			if not is_instance_valid(_mine_target_tile):
				_last_squad_mined_coord = _mine_target_tile_coord
				_clear_mining_target()
				_on_tile_mined()
		return

	var mining_speed: float = get_mining_speed()
	if mining_speed <= 0.0:
		_clear_mining_target()
		_request_task()
		return
	_mine_timer += delta
	if _mine_timer >= DIGGING_INTERVAL / mining_speed:
		_mine_timer = 0.0
		var tile_type: String = _mine_target_tile.type
		_mine_target_tile.richness -= 1
		_spawn_extraction_drop(tile_type)
		$NormalSound / ExtractResource.startSound()
		var extra_chance: float = Data.ofOr(playerId + ".keeper4.goblinextraresourcechance", 0.0)
		if extra_chance > 0.0 and Data.stabilizedRandomFloat(0, 1.0, playerId + ".keeper4.goblinextraresourcechance", 2.0) < extra_chance:
			_spawn_extraction_drop(tile_type)

		if _mine_target_tile.richness <= 0:
			if Data.ofOr(playerId + ".keeper4.goblindestroytileondig", false):
				var dir: Vector2 = global_position - _mine_target_tile.global_position
				_mine_target_tile.hit(dir, _mine_target_tile.max_health, teamId)
			else:
				Level.map.changeTileType(_mine_target_tile, Data.TILE_DIRT_START)
			_clear_mining_target()
			_on_tile_mined()

func _on_tile_mined() -> void :
	if _is_current_surface_destroyed():
		_enter_falling_state()
	else:
		_request_task()

func _clear_mining_target() -> void :
	if _task_manager and _mine_target_tile_coord != Vector2.ZERO:
		_task_manager.release_mining_tile(self, _mine_target_tile_coord)
	_mine_target_tile = null
	_mine_target_tile_coord = Vector2.ZERO
	if is_squad_goblin:
		$SquadSound / DigSound.stop()
	else:
		$NormalSound / ExtractSound.stop()
	_clear_path()

func _spawn_extraction_drop(type: String) -> void :
	var dir_away_from_tile: Vector2 = (global_position - _mine_target_tile.global_position).normalized()

	Level.drops.network_spawn({
		"type": type, 
		"position": global_position + dir_away_from_tile * 10, 
		"impulse": dir_away_from_tile.rotated(randf_range(-0.4, 0.4)) * randf_range(30, 60), 
		"team": teamId
	})

	GameWorld.incrementRunStat("resources_mined", teamId)

func _face_tile(tile_coord: Vector2) -> void :
	var tile_world_pos: Vector2 = tile_coord * GameWorld.TILE_SIZE + CONST.TILE_OFFSET
	if tile_world_pos.x < global_position.x:
		facing_direction = -1.0
	elif tile_world_pos.x > global_position.x:
		facing_direction = 1.0

func _refresh_path_to_mine_surface() -> bool:
	if not is_instance_valid(_mine_target_tile):
		return false
	if not _navigator:
		return false
	var adjacent_info: = _navigator.find_surface_adjacent_to_tile(_mine_target_tile_coord)
	if adjacent_info.is_empty():
		return false
	var surface_pos: Vector2 = adjacent_info.position
	var new_path: = _navigator.get_surface_path(global_position, surface_pos)
	if new_path.is_empty():
		return false
	if _movement_tween and _movement_tween.is_valid():
		_movement_tween.kill()
	_is_jumping = false
	current_surface_path = new_path
	surface_path_index = 0
	_precompute_path_offsets()
	_rebuild_required_tiles()
	state_updated.emit()
	return true

func _try_hop_to_neighbor_tile() -> bool:
	if not _navigator or not is_instance_valid(_squad_origin_hole):
		return false
	_clear_mining_target()
	var hole_pos: Vector2 = _squad_origin_hole.global_position
	CONST.DIRECTIONS.shuffle()
	for offset in CONST.DIRECTIONS:
		var coord: = Vector2(int(_last_squad_mined_coord.x) + int(offset.x), int(_last_squad_mined_coord.y) + int(offset.y))
		var world_pos: Vector2 = coord * GameWorld.TILE_SIZE + CONST.TILE_OFFSET
		if world_pos.distance_squared_to(hole_pos) > Keeper4GameplaySettings.HOLE_RADIUS_SQ:
			continue
		if not Level.map.tiles.has(coord):
			continue
		var tile = Level.map.tiles[coord]
		if not tile.has_meta("destructable") or not tile.get_meta("destructable"):
			continue
		if tile.type == CONST.IRON or tile.type == CONST.SAND or tile.type == CONST.WATER:
			continue
		var result: = _navigator.find_best_path_to_tile_surface(global_position, coord)
		if result.is_empty():
			continue
		_current_surface_type = result.surface.surface_type
		_current_surface_coord = result.surface.coord
		if _task_manager:
			_task_manager.claim_mining_tile(self, coord)
		if accept_mining_task(_squad_origin_hole, tile, coord, result.path):
			return true
		if _task_manager:
			_task_manager.release_mining_tile(self, coord)
	return false

func _request_squad_task() -> void :
	if _squad_timer <= 0:
		_trigger_squad_return()
		return
	if not _task_manager or not is_instance_valid(_squad_origin_hole):
		_enter_falling_state()
		return
	var is_retry: bool = state == State.WAITING_FOR_PATH
	var task: Dictionary = _task_manager.find_squad_mining_task(self, _squad_origin_hole.global_position, global_position, _last_squad_mined_coord, is_retry)
	if task.is_empty():
		if state != State.WAITING_FOR_PATH:
			_enter_waiting_for_path_state()
		return
	var tile = task.get("tile")
	var tile_coord: Vector2 = task.get("tile_coord")
	var path: Array = task.get("path", [])
	var is_shared: bool = task.get("is_shared", false)
	if is_shared or _task_manager.claim_mining_tile(self, tile_coord):
		if accept_mining_task(_squad_origin_hole, tile, tile_coord, path):
			return
		if not is_shared:
			_task_manager.release_mining_tile(self, tile_coord)
	if state != State.WAITING_FOR_PATH:
		_enter_waiting_for_path_state()

func _try_squad_idle_wander() -> void :
	if not _task_manager or not _navigator or not is_instance_valid(_squad_origin_hole):
		return
	var hole_pos: Vector2 = _squad_origin_hole.global_position
	var wander_info: Dictionary = _task_manager.find_wander_point(self, global_position, 2.0 * GameWorld.TILE_SIZE, 1.0 * GameWorld.TILE_SIZE)
	if wander_info.is_empty():
		return
	var path: Array = wander_info.get("path", [])
	if path.is_empty():
		return
	var last_pos: Vector2 = path[path.size() - 1].position
	if last_pos.distance_squared_to(hole_pos) > Keeper4GameplaySettings.HOLE_RADIUS_SQ:
		return
	current_surface_path = path
	surface_path_index = 0
	_precompute_path_offsets()
	_rebuild_required_tiles()
	state_updated.emit()

func _try_path_back_to_hole() -> void :
	if not _navigator or not is_instance_valid(_squad_origin_hole):
		return
	var path: Array = _navigator.get_surface_path(global_position, _squad_origin_hole.global_position)
	if path.is_empty():
		return
	current_surface_path = path
	surface_path_index = 0
	_precompute_path_offsets()
	_rebuild_required_tiles()
	state_updated.emit()

func _return_or_disappear() -> void :
	_unassign_from_hole()
	_clear_mining_target()
	_clear_path()
	if Level.drops.has_drop(carried_resource_uid):
		var carried_resource: Carryable = Level.drops.get_drop(carried_resource_uid)
		Level.drops.network_goblin_release(carried_resource, self)
		carried_resource.apply_central_impulse(Vector2(0, -80 * _gravity_dir))
	_clear_target_resource()
	var hole_pos: = Vector2.ZERO
	if is_squad_goblin and is_instance_valid(_squad_origin_hole):
		hole_pos = _squad_origin_hole.global_position
	elif _task_manager:
		var hole_info: Dictionary = _task_manager.find_return_hole(global_position)
		var hole = hole_info.get("hole")
		if is_instance_valid(hole):
			hole_pos = hole.global_position
	if hole_pos != Vector2.ZERO and _navigator:
		var path: Array = _navigator.get_path_to_hole_adjacent_surface(global_position, hole_pos)
		if not path.is_empty():
			var hole_node = _squad_origin_hole if is_squad_goblin else null
			if not is_squad_goblin and _task_manager:
				var info: Dictionary = _task_manager.find_return_hole(global_position)
				hole_node = info.get("hole")
			if is_instance_valid(hole_node) and _set_surface_path_to_target(hole_node, path):
				target_hole = hole_node
				state = State.MOVING_TO_HOLE
				state_updated.emit()
				return
	_start_disappearing()

func _start_disappearing() -> void :
	state = State.DISAPPEARING
	state_timer = 999.0
	var biome_color = Level.map.getBiomeColorByCoord(Level.map.getTileCoord(global_position))
	if global_position.y < 450:
		$DisappearHole.modulate = biome_color + lerp(Color.BLACK, Style.colorData[Vector2(0, 10)] * 1.5, remap(global_position.y, 47, 447, 1.0, 0.0))
	else:
		$DisappearHole.modulate = biome_color
	$DisappearHole.visible = true
	$DisappearHole.play("open")
	$DisappearHole.animation_finished.connect(_on_disappear_hole_opened, CONNECT_ONE_SHOT)
	state_updated.emit()

func _on_disappear_hole_opened() -> void :
	_sprite.play("hole_enter")
	_sprite.animation_finished.connect(_on_disappear_goblin_entered, CONNECT_ONE_SHOT)

func _on_disappear_goblin_entered() -> void :
	_sprite.visible = false
	$DisappearHole.play("close")
	$DisappearHole.animation_finished.connect(_on_disappear_hole_closed, CONNECT_ONE_SHOT)

func _on_disappear_hole_closed() -> void :
	$DisappearHole.visible = false
	_sprite.visible = true
	_emergency_return_to_cellar()

func _trigger_squad_return() -> void :
	_squad_timer = 0
	_return_or_disappear()

func _squad_cleanup_and_free() -> void :
	if _task_manager:
		_task_manager.release_all_claims(self)
	if is_instance_valid(_squad_origin_hole):
		_squad_origin_hole.on_goblin_unassigned()
	queue_free()

func _restore_carried_resource() -> void :

	pass

func to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_u8(state)

	var new_seed: int = _rng.randi()
	set_seed(new_seed)
	stream.encode_u32(new_seed)

	stream.encode_vector2(global_position)
	stream.encode_u8(_visual_surface_type)
	stream.encode_bool(_wall_moving_up)

	match state:
		State.CELLAR_WANDER:
			stream.encode_float(_wander_progress)
			stream.encode_float(_wander_target_progress)
			stream.encode_float(_wander_pause_timer)
		State.WALKING_TO_ENTRANCE_HOLE:
			pass
		State.JUMPING_TO_ENTRANCE_HOLE:
			var _entrance_ref = _goblins_node.get_entrance_hole() if _goblins_node else null
			stream.encode_vector2(_entrance_ref.global_position if is_instance_valid(_entrance_ref) else global_position)
			stream.encode_float(state_timer)
		State.TELEPORTING:
			stream.encode_u32(target_hole.UID if is_instance_valid(target_hole) else 0)
			stream.encode_bool(_is_teleporting_outbound)
			stream.encode_bool(visible)
			stream.encode_float(teleport_timer)
		State.HOPPING_FROM_HOLE:
			stream.encode_u8(_hop_from_hole_phase)
			stream.encode_bool(facing_direction < 0)
			if not _hole_hop_target.is_empty():
				stream.append_array(encode_surface(_hole_hop_target))
		State.CAVE_WANDER:
			stream.encode_u8(surface_path_index)
			stream.encode_bool(facing_direction)
			for path in current_surface_path:
				stream.append_array(encode_surface(path))
		State.MOVING_TO_RESOURCE:
			stream.encode_u8(surface_path_index)
			stream.encode_bool(_is_jumping)
			for surface in current_surface_path:
				stream.append_array(encode_surface(surface))
		State.MOVING_TO_CELLAR_RESOURCE:
			stream.encode_float(_wander_progress)
			stream.encode_float(_wander_target_progress)
		State.GRABBING:
			stream.encode_float(state_timer)
		State.MOVING_TO_HOLE:
			stream.encode_u32(target_hole.UID)
			stream.encode_u8(surface_path_index)
			stream.encode_bool(_is_jumping)
			for surface in current_surface_path:
				stream.append_array(encode_surface(surface))
		State.HOPPING_TO_HOLE:
			stream.encode_u8(_hop_to_hole_phase)
			stream.encode_vector2(_hole_hop_target.get("position", Vector2.ZERO))
			stream.encode_bool(facing_direction < 0)
		State.JUMPING_FROM_ENTRANCE_HOLE:
			stream.encode_vector2(_entrance_landing_pos)
		State.THROW_DELAY:
			pass
		State.THROWING:
			stream.encode_float(state_timer)
		State.WAITING_FOR_PATH:
			stream.encode_u8(surface_path_index)
			stream.encode_bool(facing_direction)
			for path in current_surface_path:
				stream.append_array(encode_surface(path))
		State.DISAPPEARING:
			pass
		State.FALLING:
			stream.encode_u8(_fall_surface_preference)
		State.MOVING_TO_MINE_SURFACE:
			stream.encode_u8(surface_path_index)
			stream.encode_bool(_is_jumping)
			stream.encode_u8(_current_surface_type)
			for surface in current_surface_path:
				stream.append_array(encode_surface(surface))
		State.MINING:
			stream.encode_u8(_current_surface_type)
			stream.encode_vector2(_mine_target_tile_coord)
		State.NAPPING:
			stream.encode_float(_nap_wander_timer)
			stream.encode_float(_nap_timer)
			stream.encode_float(_wander_target_progress)

	return stream.data

func from_bytes(buffer: PackedByteArray) -> void :
	if not Network.is_server() and _is_jumping and state == State.JUMPING_TO_ENTRANCE_HOLE:
		return
	var stream: = PackedByteStream.from_bytes(buffer)

	var new_state: int = stream.decode_u8()
	var state_changed: bool = new_state != state
	state = new_state as State
	set_seed(stream.decode_u32())
	global_position = stream.decode_vector2()
	_visual_surface_type = stream.decode_u8()
	_wall_moving_up = stream.decode_bool()

	if state_changed:
		if _movement_tween and _movement_tween.is_valid():
			_movement_tween.kill()
		_is_jumping = false
	visible = true

	match state:
		State.CELLAR_WANDER:
			_wander_progress = stream.decode_float()
			_wander_target_progress = stream.decode_float()
			_wander_pause_timer = stream.decode_float()
			if not Network.is_server() and _wander_curve and is_instance_valid(_wander_base_node):
				var local_pos: Vector2 = _wander_curve.sample_baked(_wander_progress)
				global_position = _wander_base_node.global_position + local_pos
		State.WALKING_TO_ENTRANCE_HOLE:
			pass
		State.JUMPING_TO_ENTRANCE_HOLE:
			var entrance_pos: Vector2 = stream.decode_vector2()
			state_timer = stream.decode_float()
			if (state_changed or not _is_jumping) and ( not Network.is_server() or state_timer <= 0):
				_is_jumping = true
				_start_hole_hop(global_position, entrance_pos, _on_entrance_hop_complete, ENTRANCE_HOP_HEIGHT)
		State.TELEPORTING:
			target_hole = _goblins_node.get_goblin_hole(stream.decode_u32())
			_is_teleporting_outbound = stream.decode_bool()
			visible = stream.decode_bool()
			teleport_timer = stream.decode_float()
		State.HOPPING_FROM_HOLE:
			var incoming_phase: int = stream.decode_u8()
			if state_changed or incoming_phase >= _hop_from_hole_phase:
				_hop_from_hole_phase = incoming_phase
			facing_direction = -1.0 if stream.decode_bool() else 1.0
			if stream.is_not_finished():
				_hole_hop_target = decode_surface(stream.slice(SURFACE_PACKET_SIZE).data)
				var target_type: int = _hole_hop_target.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
				_hop_from_hole_target_pos = _hole_hop_target.get("position", global_position) + _get_surface_offset(target_type)
		State.CAVE_WANDER:
			surface_path_index = stream.decode_u8()
			facing_direction = stream.decode_bool()
			current_surface_path = []
			while stream.is_not_finished():
				current_surface_path.append(decode_surface(stream.slice(SURFACE_PACKET_SIZE).data))
			_precompute_path_offsets()
		State.MOVING_TO_RESOURCE:
			_assigned_hole_for_mining = null
			surface_path_index = stream.decode_u8()
			stream.decode_bool()
			current_surface_path = []
			while stream.is_not_finished():
				current_surface_path.append(decode_surface(stream.slice(SURFACE_PACKET_SIZE).data))
			_precompute_path_offsets()
		State.MOVING_TO_CELLAR_RESOURCE:
			_wander_progress = stream.decode_float()
			_wander_target_progress = stream.decode_float()
			if not Network.is_server() and _wander_curve and is_instance_valid(_wander_base_node):
				var local_pos: Vector2 = _wander_curve.sample_baked(_wander_progress)
				global_position = _wander_base_node.global_position + local_pos
		State.GRABBING:
			state_timer = stream.decode_float()
		State.MOVING_TO_HOLE:
			target_hole = _goblins_node.get_goblin_hole(stream.decode_u32())
			surface_path_index = stream.decode_u8()
			stream.decode_bool()
			current_surface_path = []
			while stream.is_not_finished():
				current_surface_path.append(decode_surface(stream.slice(SURFACE_PACKET_SIZE).data))
			_precompute_path_offsets()
		State.HOPPING_TO_HOLE:
			var incoming_to_phase: int = stream.decode_u8()
			if state_changed or incoming_to_phase >= _hop_to_hole_phase:
				_hop_to_hole_phase = incoming_to_phase
			_hole_hop_target = {"position": stream.decode_vector2()}
			facing_direction = -1.0 if stream.decode_bool() else 1.0
		State.JUMPING_FROM_ENTRANCE_HOLE:
			is_in_cellar = true
			target_hole = null
			_clear_path()
			_current_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
			_visual_surface_type = SurfacePathfinding.SurfaceType.FLOOR_TOP
			_entrance_landing_pos = stream.decode_vector2()
			if state_changed or not _is_jumping:
				_is_jumping = true
				_start_hole_hop(global_position, _entrance_landing_pos, _on_entrance_exit_hop_complete, ENTRANCE_HOP_HEIGHT)
		State.THROW_DELAY:
			pass
		State.THROWING:
			state_timer = stream.decode_float()
		State.WAITING_FOR_PATH:
			surface_path_index = stream.decode_u8()
			facing_direction = stream.decode_bool()
			current_surface_path = []
			while stream.is_not_finished():
				current_surface_path.append(decode_surface(stream.slice(SURFACE_PACKET_SIZE).data))
			_precompute_path_offsets()
		State.DISAPPEARING:
			_sprite.play("idle")
		State.FALLING:
			_fall_surface_preference = stream.decode_u8()
		State.MOVING_TO_MINE_SURFACE:
			surface_path_index = stream.decode_u8()
			stream.decode_bool()
			_current_surface_type = stream.decode_u8()
			current_surface_path = []
			while stream.is_not_finished():
				current_surface_path.append(decode_surface(stream.slice(SURFACE_PACKET_SIZE).data))
			_precompute_path_offsets()
		State.MINING:
			_current_surface_type = stream.decode_u8()
			_mine_target_tile_coord = stream.decode_vector2()
			_face_tile(_mine_target_tile_coord)
		State.NAPPING:
			_nap_wander_timer = stream.decode_float()
			_nap_timer = stream.decode_float()
			_wander_target_progress = stream.decode_float()

func serialize_state() -> Dictionary:
	return {
		"position": var_to_str(global_position), 
		"playerId": playerId, 
		"teamId": teamId, 
		"UID": UID, 
		"is_in_cellar": is_in_cellar, 
		"facing_direction": facing_direction, 
		"wander_progress": _wander_progress, 
		"wander_target_progress": _wander_target_progress, 
		"wander_pause_timer": _wander_pause_timer, 
		"surface_type": _current_surface_type, 
		"surface_coord": var_to_str(_current_surface_coord), 
		"carried_resource_uid": carried_resource_uid, 
		"is_squad_goblin": is_squad_goblin, 
		"squad_id": squad_id, 
		"squad_timer": _squad_timer, 
		"squad_origin_hole_pos": var_to_str(_squad_origin_hole.global_position) if is_squad_goblin and is_instance_valid(_squad_origin_hole) else "", 
		"last_squad_mined_coord": var_to_str(_last_squad_mined_coord), 
	}

func deserialize_state(data: Dictionary) -> void :
	global_position = BackwardCompatibilityUtils.str_to_var(data.get("position", var_to_str(Vector2.ZERO)))
	facing_direction = data.get("facing_direction", 1.0)
	_current_surface_type = data.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
	_current_surface_coord = BackwardCompatibilityUtils.str_to_var(data.get("surface_coord", var_to_str(Vector2i.ZERO)))
	if data.get("is_in_cellar", true):
		is_in_cellar = true
		_wander_progress = data.get("wander_progress", 0.0)
		_wander_target_progress = data.get("wander_target_progress", 0.0)
		_wander_pause_timer = data.get("wander_pause_timer", 0.0)
		state = State.CELLAR_WANDER
	else:
		is_in_cellar = false
		state = State.WAITING_FOR_PATH
		state_timer = _rng.randf_range(WAIT_FOR_PATH_DURATION_MIN, WAIT_FOR_PATH_DURATION_MAX)

	_restore_carried_resource()

	set_color()

func deserialize_squad_state(data: Dictionary, hole: Node2D, task_mgr: GoblinTaskManager, nav: GoblinNavigator, goblins: Node) -> void :
	is_squad_goblin = true
	_goblins_node = goblins
	_squad_origin_hole = hole
	_origin_hole = hole
	_task_manager = task_mgr
	_navigator = nav
	is_in_cellar = false
	visible = true

	_sprite.visible = false
	_squad_sprite.visible = true
	_sprite = _squad_sprite
	_init_squad_sound_pool(self)
	for child in get_children():
		if child is AudioStreamPlayer:
			child.queue_free()
	hole.on_goblin_assigned()

	global_position = BackwardCompatibilityUtils.str_to_var(data.get("position", var_to_str(Vector2.ZERO)))
	facing_direction = data.get("facing_direction", 1.0)
	squad_id = data.get("squad_id", -1)
	_squad_timer = data.get("squad_timer", 0.0)
	_last_squad_mined_coord = BackwardCompatibilityUtils.str_to_var(data.get("last_squad_mined_coord", var_to_str(Vector2.ZERO)))
	_current_surface_type = data.get("surface_type", SurfacePathfinding.SurfaceType.FLOOR_TOP)
	_current_surface_coord = BackwardCompatibilityUtils.str_to_var(data.get("surface_coord", var_to_str(Vector2i.ZERO)))

	if _squad_timer <= 0:
		state = State.DISAPPEARING
		state_timer = DISAPPEAR_ANIMATION_DURATION
	else:
		state = State.WAITING_FOR_PATH
		state_timer = _rng.randf_range(WAIT_FOR_PATH_DURATION_MIN, WAIT_FOR_PATH_DURATION_MAX)

	_restore_carried_resource()
	GoblinNavigator.force_rebuild_all()

func _exit_tree():
	if _task_manager:
		_task_manager.release_all_claims(self)
	_clear_target_resource()
	_clear_mining_target()
	_goblins_node.unregister_goblin(self)

	if is_instance_valid(Level.drops) and Level.drops.has_drop(carried_resource_uid):
		Level.drops.network_goblin_release(Level.drops.get_drop(carried_resource_uid), self)

	var tree: = get_tree()
	if tree:
		for carryable in tree.get_nodes_in_group("carryable"):
			if is_instance_valid(carryable) and carryable.carriedBy.has(self):
				carryable.carriedBy.erase(self)

const SURFACE_PACKET_SIZE: int = 10
const COORD_BIT_SIZE: int = 10
const COORD_FACTOR: float = 1.0

const POSITION_BIT_SIZE: int = 26
const POSITION_FACTOR: float = 1000.0
const Y_POSITION_SHIFT: int = 100

const SURFACE_TYPE_BIT_SIZE: int = 2
const ROTATION_BIT_SIZE: int = 3


func encode_surface(surface_data: Dictionary) -> PackedByteArray:

	var stream: = BitPackedByteStream.new()
	stream.resize(SURFACE_PACKET_SIZE)

	stream.pack_signed_float(surface_data["position"].x, POSITION_BIT_SIZE, POSITION_FACTOR)
	stream.pack_unsigned_float(surface_data["position"].y, POSITION_BIT_SIZE, POSITION_FACTOR, Y_POSITION_SHIFT)

	stream.pack_bits(surface_data["surface_type"], SURFACE_TYPE_BIT_SIZE)

	stream.pack_signed_float(surface_data["coord"].x, COORD_BIT_SIZE, COORD_FACTOR)
	stream.pack_unsigned_float(surface_data["coord"].y, COORD_BIT_SIZE, COORD_FACTOR)

	stream.pack_bit(surface_data["is_jump"])
	stream.pack_rotation(surface_data["rotation"], ROTATION_BIT_SIZE)

	return stream.data

func decode_surface(buffer: PackedByteArray) -> Dictionary:
	var stream: = BitPackedByteStream.from_bytes(buffer)

	return {
		"position": Vector2(
			stream.unpack_signed_float(POSITION_BIT_SIZE, POSITION_FACTOR), 
			stream.unpack_unsigned_float(POSITION_BIT_SIZE, POSITION_FACTOR, Y_POSITION_SHIFT)
		), 
		"surface_type": stream.unpack_bits(SURFACE_TYPE_BIT_SIZE) as SurfacePathfinding.SurfaceType, 
		"coord": Vector2(
			stream.unpack_signed_float(COORD_BIT_SIZE, COORD_FACTOR), 
			stream.unpack_unsigned_float(COORD_BIT_SIZE, COORD_FACTOR)
		), 
		"is_jump": stream.unpack_bit(), 
		"rotation": stream.unpack_rotation(ROTATION_BIT_SIZE), 
	}
