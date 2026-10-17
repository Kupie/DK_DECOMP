class_name Goblins
extends Node2D

const GOBLIN_SCENE: = preload("res://content/keeper/keeper4/Goblin.tscn")
const HOLE_SCENE: = preload("res://content/keeper/keeper4/GoblinHole.tscn")

@onready var wander_path: Path2D = $WanderPathUpside if Data.ofOr("world.inversegravity", false) else $WanderPath
@onready var hole_jump_path: Path2D = $HoleJumpPath

@export var synchronizer: GoblinsSynchronizer

var teamId: String

var entrance_hole = null
var goblins_by_uid: Dictionary = {}
var goblins_by_player: Dictionary = {}
var all_goblins: Array[Goblin] = []
var _navigator: GoblinNavigator = null
var task_managers: Dictionary = {}
var _shared_resource_claims: Dictionary = {}
var _shared_mining_claims: Dictionary = {}
var _shared_surface_claims: Dictionary = {}
var _shared_hop_claims: Dictionary = {}
var _cleanup_timer: = 0.0
var _data_update_timer: = 0.0

var _squads: Dictionary = {}

const CLEANUP_INTERVAL: = 3.0
const DATA_UPDATE_INTERVAL: = 0.25
const SQUAD_CHECK_INTERVAL_FRAMES: = 5

class SquadContext:
	var hole: GoblinHole = null
	var remaining: int = 0
	var duration: float = 0.0
	var spawned: int = 0
	var frame_counter: int = 0
	var last_spawned: Node = null
	var active_goblin_count: int = 0

class SquadData:
	var contexts: Array = []


func init():
	if StageManager.isInLoadout():
		for keeper in Keepers.getAll():
			if keeper.techId == "keeper4":
				_spawn_entrance_hole()
				break
		_navigator = GoblinNavigator.new()
		_navigator.setup(teamId, self)
		Level.map.tile_destroyed.connect(_on_map_tile_destroyed, ConnectFlags.CONNECT_DEFERRED)
	elif Network.is_server():
		var spawnedHole: = false
		for lk: LoadoutKeeper in Level.loadout.keeperTemplates:
			if lk.teamId != teamId:
				continue
			if lk.keeperId == "keeper4":
				_spawn_entrance_hole()
				spawnedHole = true
				break
		if not spawnedHole:
			for member in Lobby.members:
				if member.team_id != Utils.encode_team_id(teamId):
					continue
				if member.keeper_id == 4:
					_spawn_entrance_hole()
					break
		add_to_group("saveable")
		_navigator = GoblinNavigator.new()
		_navigator.setup(teamId, self)
		Level.map.tile_destroyed.connect(_on_map_tile_destroyed, ConnectFlags.CONNECT_DEFERRED)

func _on_map_tile_destroyed(_world_tile_pos: Vector2) -> void :
	_navigator._dirty = true

func get_task_manager(playerId: String) -> GoblinTaskManager:
	if not task_managers.has(playerId):
		var tm: = GoblinTaskManager.new(
			_navigator, self, 
			_shared_resource_claims, _shared_mining_claims, 
			_shared_surface_claims, _shared_hop_claims)
		tm.set_team_id(teamId)
		task_managers[playerId] = tm
	return task_managers[playerId]

func register_keeper(keeper: Keeper) -> void :
	var already_spawned_goblins: bool = goblins_by_player.has(keeper.playerId) and goblins_by_player[keeper.playerId].size() > 0
	if not already_spawned_goblins:
		goblins_by_player[keeper.playerId] = []
	Data.listen(self, keeper.playerId + ".keeper4.catgoblincount", not already_spawned_goblins)
	keeper.tree_exiting.connect(on_keeper_tree_exiting.bind(keeper, goblins_by_player[keeper.playerId]))

func propertyChanged(property: String, oldValue, newValue):
	if property.ends_with(".keeper4.catgoblincount"):
		if SaveGame.currentLoadingSavegame:
			return
		var playerId: = property.split(".")[0]
		if not goblins_by_player.has(playerId):

			return
		if oldValue == null:
			oldValue = 0
		var new_goblins = newValue - oldValue
		for i in range(new_goblins):
			spawn_goblin(playerId)

func on_keeper_tree_exiting(keeper: Keeper, goblins: Array) -> void :

	var keeper_goblins: Array = goblins.duplicate()
	for goblin in keeper_goblins:
		if is_instance_valid(goblin):
			goblin.queue_free()

	goblins_by_player.erase(keeper.playerId)
	task_managers.erase(keeper.playerId)

func network_trigger_squad(keeper: Keeper, hole: GoblinHole) -> void :
	synchronizer.rpc_server(synchronizer.trigger_squad.bind(Utils.encode_player_id(keeper.playerId), hole.UID))

func spawn_hole(playerId: String, pos: Vector2, uid: int = -1) -> GoblinHole:


	var hole: GoblinHole = HOLE_SCENE.instantiate()
	if uid == -1:
		hole.UID = randi()
	else:
		hole.UID = uid
	Level.map.add_child(hole)
	hole.playerId = playerId
	hole.global_position = pos
	hole.teamId = teamId
	hole.setup_growing()
	hole.set_color()


	synchronizer.network_spawn_hole(hole)

	return hole

func server_spawn_hole(playerId: String, pos: Vector2, uid: int) -> GoblinHole:

	var hole: GoblinHole = HOLE_SCENE.instantiate()
	hole.playerId = playerId
	hole.UID = uid
	hole.teamId = teamId
	Level.map.add_child(hole)
	hole.global_position = pos
	hole.setup_growing()
	hole.set_color()
	return hole

func spawn_goblin(playerId: String) -> void :
	var goblin: Goblin = GOBLIN_SCENE.instantiate()
	goblin.UID = randi()
	goblin.playerId = playerId
	goblin.teamId = teamId
	goblin.set_color()

	Level.getDome(teamId).add_child(goblin)
	if wander_path and wander_path.curve:
		var start_pos: Vector2 = wander_path.curve.get_point_position(0)
		goblin.global_position = Level.getDome(teamId).global_position + start_pos
		goblin.setup_wander_path(wander_path.curve, Level.getDome(teamId), self)
	goblin.set_task_manager(get_task_manager(playerId))

	register_goblin(goblin)

	synchronizer.network_spawn_goblin(goblin)

func on_server_goblin_state_updated(goblin: Goblin) -> void :
	synchronizer.network_update_goblin(goblin)

func server_spawn_goblin(playerId: String, uid: int, is_squad_goblin: bool, initial_state: PackedByteArray) -> void :
	var goblin: Goblin = GOBLIN_SCENE.instantiate()
	goblin.UID = uid
	goblin.playerId = playerId
	goblin.teamId = teamId
	goblin.set_color()

	if is_squad_goblin:
		Level.map.add_child(goblin)
		goblin.setup_as_client_squad_goblin(self)
	elif wander_path and wander_path.curve:
		Level.getDome(teamId).add_child(goblin)
		var start_pos: Vector2 = wander_path.curve.get_point_position(0)
		goblin.global_position = Level.getDome(teamId).global_position + start_pos
		goblin.setup_wander_path(wander_path.curve, Level.getDome(teamId), self)
	else:
		push_error("Unable to create goblin.")
		return

	register_goblin(goblin)

	goblin.from_bytes(initial_state)

func on_client_goblin_state_updated(goblin: Goblin) -> void :
	push_error("Client goblin attempting to alter its state.")

func _exit_tree():
	Goblin.reset_normal_sound_pool()
	Goblin.reset_squad_sound_pool()

func notifyGameLost() -> void :
	for goblin in all_goblins:
		goblin.onGameLost()

func _physics_process(delta):
	if _navigator:
		_navigator.tick()
	if not Network.is_server():
		return
	if not task_managers.is_empty():
		_cleanup_timer -= delta
		if _cleanup_timer <= 0:
			_cleanup_timer = CLEANUP_INTERVAL
			task_managers.values()[0].cleanup_invalid_claims()
		for tm in task_managers.values():
			tm.match_pending_tasks()
	_process_squad_spawning(delta)
	_data_update_timer -= delta
	if _data_update_timer <= 0:
		_data_update_timer = DATA_UPDATE_INTERVAL
		_update_data_values()


func _spawn_entrance_hole():
	if is_instance_valid(entrance_hole):
		return


	while not is_instance_valid(Level.getDome("team1")):
		await get_tree().process_frame
	if not hole_jump_path or not hole_jump_path.curve:
		return
	entrance_hole = HOLE_SCENE.instantiate()
	Level.getDome(teamId).add_child(entrance_hole)
	var first_point: Vector2 = hole_jump_path.curve.get_point_position(0)
	entrance_hole.position = first_point
	entrance_hole.setup_as_entrance_hole()

func get_hole_jump_curve() -> Curve2D:
	if hole_jump_path:
		return hole_jump_path.curve
	return null

func get_entrance_hole():
	return entrance_hole

func register_goblin(goblin: Goblin) -> void :
	if goblin and not all_goblins.has(goblin):
		all_goblins.append(goblin)
		if not goblins_by_player.has(goblin.playerId):
			goblins_by_player[goblin.playerId] = []
		goblin.set_id_inside_keeper(goblins_by_player[goblin.playerId].size())
		goblins_by_player[goblin.playerId].append(goblin)
		goblins_by_uid[goblin.UID] = goblin
		if Network.is_server():
			goblin.state_updated.connect(on_server_goblin_state_updated.bind(goblin))

func unregister_goblin(goblin: Goblin) -> void :
	all_goblins.erase(goblin)
	if goblins_by_player.has(goblin.playerId):
		goblins_by_player[goblin.playerId].erase(goblin)
	goblins_by_uid.erase(goblin.UID)
	if goblin.is_squad_goblin:
		var sd: = get_squad_data(goblin.playerId)
		for ctx in sd.contexts:
			if ctx.hole == goblin._squad_origin_hole:
				ctx.active_goblin_count = maxi(0, ctx.active_goblin_count - 1)
				if ctx.active_goblin_count <= 0 and ctx.remaining <= 0:
					sd.contexts.erase(ctx)
				break

	if Network.multiplayer != null and Network.is_server():
		synchronizer.network_free_goblin(goblin)

func get_squad_data(playerId: String) -> SquadData:
	if not _squads.has(playerId):
		_squads[playerId] = SquadData.new()

	return _squads[playerId]

func has_idle_goblin() -> bool:
	for goblin in all_goblins:
		if not is_instance_valid(goblin):
			continue
		if goblin.is_in_cellar and goblin.state == goblin.State.CELLAR_WANDER:
			if not is_instance_valid(goblin.carried_resource):
				return true
	return false

func get_idle_goblin() -> Node2D:
	for goblin in all_goblins:
		if not is_instance_valid(goblin):
			continue
		if goblin.is_in_cellar and goblin.state == goblin.State.CELLAR_WANDER:
			if not is_instance_valid(goblin.carried_resource):
				return goblin
	return null

func _on_squad_triggered(playerId: String, hole: GoblinHole) -> void :
	var sd: = get_squad_data(playerId)
	var max_squads: int = Data.ofOr(playerId + ".keeper4.squadcount", 1)
	if sd.contexts.size() >= max_squads:
		return
	for ctx in sd.contexts:
		if ctx.hole == hole and ctx.remaining > 0:
			return
	var count: int = Data.ofOr(playerId + ".keeper4.holesquad", 0)
	var duration: float = Data.ofOr(playerId + ".keeper4.holesquadduration", 0.0)
	if count <= 0 or duration <= 0.0:
		return
	var ctx: = SquadContext.new()
	ctx.hole = hole
	ctx.remaining = count
	ctx.duration = duration
	sd.contexts.append(ctx)


func _on_hole_ready(hole: GoblinHole) -> void :
	for playerId: String in goblins_by_player.keys():
		if not Data.ofOr(hole.playerId + ".keeper4.autospawnminers", false):
			continue
		_on_squad_triggered(hole.playerId, hole)
		break

func _update_data_values() -> void :
	for playerId: String in goblins_by_player.keys():
		var squad_timers: = [0.0, 0.0]
		var holes_seen: Array = []
		var idle_count: int = 0
		for goblin in all_goblins:
			if not is_instance_valid(goblin):
				continue
			if goblin.playerId != playerId:
				continue
			if goblin.is_squad_goblin:
				var hole = goblin._squad_origin_hole
				var idx = holes_seen.find(hole)
				if idx == -1 and holes_seen.size() < 2:
					holes_seen.append(hole)
					idx = holes_seen.size() - 1
				if idx >= 0:
					squad_timers[idx] = maxf(squad_timers[idx], goblin._squad_timer)
			elif goblin.is_in_cellar and goblin.state == goblin.State.CELLAR_WANDER\
			and not Level.drops.has_drop(goblin.carried_resource_uid):
				idle_count += 1
		Data.apply(playerId + ".keeper4.squad1remainingduration", squad_timers[0])
		Data.apply(playerId + ".keeper4.squad2remainingduration", squad_timers[1])
		Data.apply(playerId + ".keeper4.idlegoblins", idle_count)

func _process_squad_spawning(_delta: float) -> void :
	for playerId: String in _squads.keys():
		var sd: = get_squad_data(playerId)
		for ctx in sd.contexts:
			if ctx.remaining <= 0:
				continue
			if not is_instance_valid(ctx.hole):
				ctx.remaining = 0
				continue
			ctx.frame_counter += 1
			if ctx.frame_counter < SQUAD_CHECK_INTERVAL_FRAMES:
				continue
			ctx.frame_counter = 0
			if ctx.spawned == 0:
				_spawn_single_squad_goblin(playerId, ctx)
				continue
			if not is_instance_valid(ctx.last_spawned):
				ctx.remaining = 0
				continue
			var s: int = ctx.last_spawned.state
			if s == ctx.last_spawned.State.CAVE_WANDER or s == ctx.last_spawned.State.MOVING_TO_MINE_SURFACE or s == ctx.last_spawned.State.MINING:
				_spawn_single_squad_goblin(playerId, ctx)

func _spawn_single_squad_goblin(playerId: String, ctx: SquadContext) -> void :
	var goblin: Goblin = GOBLIN_SCENE.instantiate()
	goblin.UID = randi()
	goblin.playerId = playerId
	goblin.teamId = teamId
	Level.map.add_child(goblin)
	goblin.global_position = ctx.hole.global_position
	goblin.setup_as_squad_goblin(ctx.hole, get_task_manager(playerId), _navigator, ctx.duration, self)
	ctx.active_goblin_count += 1
	ctx.spawned += 1
	ctx.remaining -= 1
	ctx.last_spawned = goblin
	register_goblin(goblin)
	goblin.set_color()

	synchronizer.network_spawn_goblin(goblin)

func serialize() -> Dictionary:
	var data: Dictionary = {
		"meta.priority": 160, 
		"meta.kind": "station", 
		"goblins": [], 
		"squad_goblins": [], 
		"squads": [], 
	}

	for playerId in _squads.keys():
		var sd: = get_squad_data(playerId)
		for ctx in sd.contexts:
			var squad_dict: Dictionary = {
				"playerId": playerId, 
				"squad_remaining": ctx.remaining, 
				"squad_duration": ctx.duration, 
				"squad_spawned": ctx.spawned, 
				"squad_hole_pos": var_to_str(ctx.hole.global_position) if is_instance_valid(ctx.hole) else "", 
			}
			data["squads"].append(squad_dict)

	for goblin in all_goblins:
		if not is_instance_valid(goblin):
			continue
		if goblin.is_squad_goblin:
			data["squad_goblins"].append(goblin.serialize_state())
		else:
			data["goblins"].append(goblin.serialize_state())
	return data

func deserialize(data: Dictionary) -> void :
	await GameWorld.savegame_loaded
	for goblin_data in data.get("goblins", []):
		if not Keepers.hasKeeper(goblin_data.get("playerId")):
			continue
		var goblin: Goblin = GOBLIN_SCENE.instantiate()
		goblin.playerId = goblin_data.get("playerId")
		goblin.teamId = goblin_data.get("teamId")
		goblin.UID = goblin_data.get("UID")
		Level.getDome(teamId).add_child(goblin)
		goblin.setup_wander_path(wander_path.curve, Level.getDome(teamId), self)
		goblin.set_task_manager(get_task_manager(goblin.playerId))
		goblin.deserialize_state(goblin_data)
		register_goblin(goblin)



	for keeper in Keepers.getAllOfTeam(teamId):
		if keeper.techId != "keeper4" or (goblins_by_player.has(keeper.playerId) and goblins_by_player[keeper.playerId].size() > 0):
			continue
		var count: int = Data.ofOr(keeper.playerId + ".keeper4.catgoblincount", 0)
		if count == 0:
			continue

		for i in range(count):
			spawn_goblin(keeper.playerId)

	for squad_dict in data.get("squads", []):
		var playerId: String = squad_dict.get("playerId", squad_dict.get("player_id", ""))
		if not Keepers.hasKeeper(playerId):
			continue
		var sd: = get_squad_data(playerId)
		var ctx: = SquadContext.new()
		ctx.remaining = squad_dict.get("squad_remaining", 0)
		ctx.duration = squad_dict.get("squad_duration", 0.0)
		ctx.spawned = squad_dict.get("squad_spawned", 0)
		var squad_hole_pos: String = squad_dict.get("squad_hole_pos", "")
		if ctx.remaining > 0 and squad_hole_pos != "":
			ctx.hole = _find_hole_by_position(squad_hole_pos)
			if not ctx.hole:
				ctx.remaining = 0
		if ctx.remaining > 0:
			sd.contexts.append(ctx)

	var max_squad_timer: Dictionary = {}
	for squad_data in data.get("squad_goblins", []):
		var hole: Node2D = _find_hole_by_position(squad_data.get("squad_origin_hole_pos", ""))
		if not hole:
			continue
		var goblin: Goblin = GOBLIN_SCENE.instantiate()
		goblin.playerId = squad_data.get("playerId")
		goblin.teamId = squad_data.get("teamId")
		goblin.UID = squad_data.get("UID")
		Level.map.add_child(goblin)
		goblin.deserialize_squad_state(squad_data, hole, get_task_manager(goblin.playerId), _navigator, self)
		var sd: = get_squad_data(goblin.playerId)
		var ctx: SquadContext = null
		for c in sd.contexts:
			if c.hole == hole:
				ctx = c
				break
		if not ctx:
			ctx = SquadContext.new()
			ctx.hole = hole
			sd.contexts.append(ctx)
		ctx.active_goblin_count += 1
		ctx.last_spawned = goblin
		register_goblin(goblin)
		if not max_squad_timer.has(goblin.playerId):
			max_squad_timer[goblin.playerId] = {}
		if not max_squad_timer[goblin.playerId].has(hole):
			max_squad_timer[goblin.playerId][hole] = 0.0
		var timer: float = squad_data.get("squad_timer", 0.0)
		if timer > max_squad_timer[goblin.playerId][hole]:
			max_squad_timer[goblin.playerId][hole] = timer


func _find_hole_by_position(pos_str: String) -> GoblinHole:
	if pos_str == "":
		return null
	var pos: Vector2 = BackwardCompatibilityUtils.str_to_var(pos_str)
	for hole in get_tree().get_nodes_in_group(teamId + "-goblin_holes"):
		if not is_instance_valid(hole):
			continue
		if hole.global_position.distance_squared_to(pos) < 4.0:
			return hole
	return null


func get_goblin_hole(uid: int) -> GoblinHole:
	return synchronizer.get_goblin_hole(uid)

func register_hole(hole: GoblinHole) -> void :
	synchronizer.register_hole(hole)

func set_entrance_hole_visible(hole_visible: bool) -> void :
	if is_instance_valid(entrance_hole):
		entrance_hole.visible = hole_visible
	elif hole_visible:
		_spawn_entrance_hole()
