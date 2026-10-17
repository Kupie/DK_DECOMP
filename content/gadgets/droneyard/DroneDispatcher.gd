extends Node2D
class_name DroneDispatcher

@export var synchronizer: Synchronizer

var cooldown: float

var domeId: String
var teamId: String

@export
var dispatcherId: String

var baseSpeed: = 50.0
var goalAmount: int


var drones: = {}

func init(teamId: String):
	self.teamId = teamId
	add_to_group(teamId + "-dronedispatcher")

func setAmount(amount: int):
	var drones = getOwnDrones()
	var diff = amount - drones.size()
	if diff > 0:
		for _i in diff:
			networkSpawnDrone.call_deferred()
	elif diff < 0:
		for i in abs(diff):
			drones[drones.size() - 1 - i].kill()

func setBaseSpeed(speed: float):
	self.baseSpeed = speed
	for drone in getOwnDrones():
		drone.baseSpeed = speed

func getOwnDrones() -> Array:
	var ownDrones: = []
	for drone in get_tree().get_nodes_in_group(teamId + "-transport_drones"):
		if drone.dispatcherId == dispatcherId:
			ownDrones.append(drone)
	return ownDrones

func networkSpawnDrone() -> void :
	if not multiplayer.is_server():
		return
	synchronizer.network_rpc(spawnDrone.bind(randi()), true)

@rpc("reliable")
func spawnDrone(uid: int):
	if drones.has(uid):
		return

	var drone = preload("res://content/gadgets/droneyard/TransportDrone.tscn").instantiate()
	drone.position = $DroneSpawnPoint.global_position
	var random: = RandomNumberGenerator.new()
	random.seed = uid
	drone.speedMod = random.randf_range(0.9, 1.1)
	drone.baseSpeed = baseSpeed
	drone.teamId = teamId
	drone.UID = uid
	Level.map.addDrop(drone)
	assignDrone(drone)

func assignDrone(drone):
	drones[drone.UID] = drone
	drone.dispatcherId = dispatcherId
	drone.connect("request_path_home", assignDronePathHome.bind(drone))
	if multiplayer.is_server():
		drone.drop_picked_up.connect(networkDronePickupDrop.bind(drone.UID))
		drone.drop_retrieved.connect(networkDroneRetrieveDrop.bind(drone.UID))
		drone.stopped_targeting_drop.connect(networkDroneStopTargetingDrop.bind(drone.UID))

func _process(delta):
	if GameWorld.paused or not multiplayer.is_server():
		return

	if cooldown > 0.0:
		cooldown -= delta
		return

	cooldown = randf_range(0.4, 0.8)

	var waitingDrones: = []
	var targettedDrops: = []
	for drone in getOwnDrones():
		if drone.state == 0:
			waitingDrones.append(drone)

		if drone.targettedDrop:
			targettedDrops.append(drone.targettedDrop)

	if waitingDrones.size() == 0:
		return

	var drops = []
	for drop in get_tree().get_nodes_in_group("drops"):
		if drop.carryableType != "resource":
			continue

		if not TransportDrone.canTransport(drop):
			continue

		if targettedDrops.has(drop):
			continue

		if drop.linear_velocity.length() > 5:
			continue

		if drop.is_in_group("ignore-for-auto-transport"):
			continue

		drops.append(drop)

	drops.sort_custom(sortByDistance)

	while (waitingDrones.size() > 0 and drops.size() > 0):
		var idx = drops.size() - 1
		var drop = drops[idx]
		drops.remove_at(idx)
		var drone = getClosestTo(waitingDrones, drop.position)
		if not drone:

			if drop.position.length() > 100000:

				drop.shrink(teamId)
			else:

				var droneUIDs: = []
				for d in waitingDrones:
					droneUIDs.append(d.UID)
				networkResetDrones(droneUIDs)
			return
		waitingDrones.erase(drone)
		networkTargetDrop(drone.UID, drop.UID, drone.global_position, drop.position, drone.baseSpeed)

func networkResetDrones(droneUIDs: Array[int]) -> void :
	synchronizer.network_rpc(resetDrones.bind(droneUIDs), true)

@rpc("reliable")
func resetDrones(droneUIDs: Array[int]) -> void :
	for uid in droneUIDs:
		if not drones.has(uid):
			continue
		var drone = drones[uid]
		drone.position = $DroneSpawnPoint.global_position

func networkTargetDrop(droneUID: int, dropUID: int, dronePosition: Vector2, dropPosition: Vector2, baseSpeed: float) -> void :
	synchronizer.network_rpc(targetDrop.bind(droneUID, dropUID, dronePosition, dropPosition, baseSpeed), true)

@rpc("reliable")
func targetDrop(droneUID: int, dropUID: int, dronePosition: Vector2, dropPosition: Vector2, baseSpeed: float) -> void :
	if not drones.has(droneUID) or not Level.drops.has_drop(dropUID):
		return
	var drone = drones[droneUID]
	var drop: = Level.drops.get_drop(dropUID)
	drone.global_position = dronePosition

	drone.baseSpeed = baseSpeed
	drone.setCarriedResource("")

	var dronePos = drone.position
	var friendlyDomePosition: Vector2 = Utils.get_dome_position(teamId)
	const friendlyDomeRadiusSqrt: float = 100.0 * 100.0
	var isDropInFriendlyDome: bool = dropPosition.y <= CONST.DOME_CELLAR_ENTRANCE_Y and \
	friendlyDomePosition.distance_squared_to(dropPosition) < friendlyDomeRadiusSqrt
	var isDroneNearDome: bool = friendlyDomePosition.distance_squared_to(dronePos) < friendlyDomeRadiusSqrt
	if isDropInFriendlyDome and isDroneNearDome:
		var middleDomeAtDroneHeight = Vector2(friendlyDomePosition.x, dronePos.y)
		var middleDomeAtDropHeight = Vector2(friendlyDomePosition.x, dropPosition.y)
		var path = [dronePos, middleDomeAtDroneHeight, middleDomeAtDropHeight, dropPosition]
		drone.targetDrop(drop, path)
	else:
		var path = tryFindPath(dronePos, dropPosition, drone.teamId)
		if path and not path.is_empty():
			if path[0] == (Vector2(0, -1) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET):
				path.insert(0, Vector2(0, -3) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET)
			drone.targetDrop(drop, path)
		else:
			drop.add_to_group("ignore-for-auto-transport")
			drop.create_tween().tween_callback(drop.remove_from_group.bind("ignore-for-auto-transport")).set_delay(10)


func getClosestTo(arr: Array, pos: Vector2):
	var closest = null
	var closestDist: = 100000
	for x in arr:
		var dist = (pos - x.position).length()
		if dist < closestDist:
			closestDist = dist
			closest = x
	return closest

func assignDronePathHome(drone):
	var dome: Dome = Level.domesByTeamId[teamId]
	var yPos = (Vector2(0, -1) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET).y
	var xPos = dome.global_position.x
	var path = tryFindPath(drone.position, Vector2(xPos, yPos), drone.teamId)
	if path and not path.is_empty():
		path.append(Vector2(xPos, (Vector2(0, -5) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET).y))
		drone.setPathHome(path)

func networkDronePickupDrop(droneUID: int):
	var drone = drones[droneUID]
	var dronePosition = drone.position
	var dropUID: = drone.targettedDrop.UID as int
	synchronizer.network_rpc(dronePickupDrop.bind(droneUID, dronePosition, dropUID), true)

@rpc("reliable")
func dronePickupDrop(droneUID: int, dronePosition: Vector2, dropUID: int) -> void :
	if not drones.has(droneUID) or not Level.drops.has_drop(dropUID):
		return
	var drone = drones[droneUID]
	drone.position = dronePosition
	var drop: = Level.drops.get_drop(dropUID)
	drone.pickup(drop)

func networkDroneRetrieveDrop(droneUID: int):
	var drone = drones[droneUID]
	var dronePosition = drone.position
	synchronizer.network_rpc(droneRetrieveDrop.bind(droneUID, dronePosition), true)

@rpc("reliable")
func droneRetrieveDrop(droneUID: int, dronePosition: Vector2) -> void :
	if not drones.has(droneUID):
		return
	var drone = drones[droneUID]
	drone.position = dronePosition
	drone.retrieve()

func networkDroneStopTargetingDrop(droneUID: int):
	var drone = drones[droneUID]
	var dronePosition = drone.position
	synchronizer.network_rpc(droneStopTargetingDrop.bind(droneUID, dronePosition), true)

@rpc("reliable")
func droneStopTargetingDrop(droneUID: int, dronePosition: Vector2) -> void :
	if not drones.has(droneUID):
		return
	var drone = drones[droneUID]
	drone.position = dronePosition
	drone.stopTargettingDrop()

func tryFindPath(startPos, endPos, teamId):
	for offset in CONST.PATHFINDING_OFFSETS:
		var path = Level.map.findPath(startPos + offset, endPos, teamId)
		if path:
			return path
	return null

func sortByDistance(a, b):
	return a.position.length() > b.position.length()
