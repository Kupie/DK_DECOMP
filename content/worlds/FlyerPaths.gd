extends Node2D

var flyerMovePoints: = {CONST.LEFT: [], CONST.RIGHT: [], CONST.CENTER: [], CONST.LEFT_LOW: [], CONST.RIGHT_LOW: [], CONST.LEFT_HIGH: [], CONST.RIGHT_HIGH: []}
var flyerSpawnPoints: = {
	CONST.MONSTER_SPAWN_FLY_TOP: [], 
	CONST.MONSTER_SPAWN_FLY_TOP_CORNER_LEFT: [], 
	CONST.MONSTER_SPAWN_FLY_TOP_CORNER_RIGHT: [], 
	CONST.MONSTER_SPAWN_FLY_LOW_LEFT: [], 
	CONST.MONSTER_SPAWN_FLY_LOW_RIGHT: [], 
	CONST.MONSTER_SPAWN_FLY_LOW_LEFT_LOW: [], 
	CONST.MONSTER_SPAWN_FLY_LOW_RIGHT_LOW: [], 
	CONST.MONSTER_SPAWN_FLY_HIGH_LEFT: [], 
	CONST.MONSTER_SPAWN_FLY_HIGH_RIGHT: [], 
	CONST.MONSTER_SPAWN_FLY_LEFT: [], 
	CONST.MONSTER_SPAWN_FLY_RIGHT: [], 
	CONST.MONSTER_SPAWN_FLY_CENTER: [], 
	}
var pointOccupations: = {}


func _ready():
	for c in get_children():
		if c.name.begins_with("LeftPoint"):
			flyerMovePoints[CONST.LEFT].append(c)
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_LEFT].append(c)
			pointOccupations[c] = []
		elif c.name.begins_with("RightPoint"):
			flyerMovePoints[CONST.RIGHT].append(c)
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_RIGHT].append(c)
			pointOccupations[c] = []
		elif c.name.begins_with("CenterPoint"):
			flyerMovePoints[CONST.CENTER].append(c)
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_CENTER].append(c)
			pointOccupations[c] = []
		elif c.name.begins_with("LeftLowPoint"):
			flyerMovePoints[CONST.LEFT_LOW].append(c)
			pointOccupations[c] = []
		elif c.name.begins_with("RightLowPoint"):
			flyerMovePoints[CONST.RIGHT_LOW].append(c)
			pointOccupations[c] = []
		elif c.name.begins_with("LeftHighPoint"):
			flyerMovePoints[CONST.LEFT_HIGH].append(c)
			pointOccupations[c] = []
		elif c.name.begins_with("RightHighPoint"):
			flyerMovePoints[CONST.RIGHT_HIGH].append(c)
			pointOccupations[c] = []
		elif c.name.begins_with("LeftTopCorner"):
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_TOP_CORNER_LEFT].append(c)
		elif c.name.begins_with("RightTopCorner"):
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_TOP_CORNER_RIGHT].append(c)
		elif c.name.begins_with("LeftHighSpawn"):
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_HIGH_LEFT].append(c)
		elif c.name.begins_with("RightHighSpawn"):
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_HIGH_RIGHT].append(c)
		elif c.name.begins_with("LeftLowSpawn"):
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_LOW_LEFT].append(c)
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_LOW_LEFT_LOW].append(c)
		elif c.name.begins_with("RightLowSpawn"):
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_LOW_RIGHT].append(c)
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_LOW_RIGHT_LOW].append(c)
		elif c.name.begins_with("TopSpawn"):
			flyerSpawnPoints[CONST.MONSTER_SPAWN_FLY_TOP].append(c)

func assignRandomPoint(variant: String, monster: Monster):
	var point = getRandomPoint(variant)

	assignPointOccupation(point, monster)

	return point

func getRandomPoint(side: String) -> Marker2D:
	var points: Array = flyerMovePoints.get(side, [])
	points.shuffle()
	var point: Marker2D = null
	var monsterCount: = 9999
	for p in points:
		var m = pointOccupations[p].size()
		if m < monsterCount:
			point = p
			monsterCount = m
	return point

func getPointIndex(point: Marker2D, side: String) -> int:
	var points: Array = flyerMovePoints.get(side, [])
	for i: int in range(points.size()):
		if point == points[i]:
			return i
	return -1

func getPoint(pointIndex: int, side: String) -> Marker2D:
	var points: Array = flyerMovePoints.get(side, [])
	return points[pointIndex]

func assignPointOccupation(point: Marker2D, monster: Monster) -> void :
	pointOccupations[point].append(monster)
	if not monster.move_finished.is_connected(freePointOccupation):
		monster.move_finished.connect(freePointOccupation.bind(point, monster))

func getMarkerFromPoint(point: Vector2, side: String) -> Marker2D:
	var points: Array = flyerMovePoints.get(side, [])
	for p in points:
		if point == p.global_position:
			return p

	return null

func freePointOccupation(point, monster):
	pointOccupations[point].erase(monster)
	monster.disconnect("move_finished", Callable(self, "freePointOccupation"))

func getSpawn(type: String) -> Marker2D:
	var spawns = flyerSpawnPoints.get(type)
	for i in 10:
		var p = spawns[randi() % spawns.size()]
		if pointOccupations.has(p):
			if pointOccupations[p].size() == 0:
				return p
		else:
			return p
	return spawns[randi() % spawns.size()]
