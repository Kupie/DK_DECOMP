extends Node2D

class_name Worldd

var teamId: String

var walk_mediumPaths: = {CONST.LEFT: [], CONST.RIGHT: []}
var walk_largePaths: = {CONST.LEFT: [], CONST.RIGHT: []}
var walk_mediumPathOccupations: = {}
var walk_largePathOccupations: = {}

var tween: DeprecatedTween
var showSimpson: = true

@onready var _parallax_bg_prototype: ParallaxBG = get_node("ParallaxBackground")

func _ready():
	if StageManager.isInDeviceSelection() or StageManager.isInLoadout():

		teamId = "team1"

	_parallax_bg_prototype.useOnlyAsContructionPrototype()
	for moveType in ["walk_medium", "walk_large"]:
		var nodeName = moveType.capitalize().replace(" ", "")
		var node = find_child(nodeName + "Paths")
		if not node:
			continue
		for c in node.get_children():
			if c.name.begins_with("LeftPath"):
				get(moveType + "Paths")[CONST.LEFT].append(c)
				get(moveType + "PathOccupations")[c] = []
			elif c.name.begins_with("RightPath"):
				get(moveType + "Paths")[CONST.RIGHT].append(c)
				get(moveType + "PathOccupations")[c] = []

	var black_border = preload("res://content/worlds/BlackBorder.tscn").instantiate()
	add_child(black_border)

	Style.init(self)

	var cg = find_child("Couchgag")
	if cg:
		if showSimpson and GameWorld.isUpgradeLimitAvailable("team1.hostile"):
			var animations = cg.sprite_frames.get_animation_names()
			cg.play(animations[randi() % animations.size()])
			cg.frame = 0
		else:
			cg.queue_free()

	$WeatherSystem.teamId = teamId
	for group in ["weather-fognear", "weather-fogfar", "weather-lightning", "weather-lightningstrike", "weather-meteor", "weather-rain", "weather-snowfar", "weather-spores", "weather-windstorm", "weather-windstormfar", "weather"]:
		for o in get_tree().get_nodes_in_group(group):
			if is_ancestor_of(o):
				o.add_to_group(teamId + "-" + group)
				if "teamId" in o:
					o.teamId = teamId

	updateBackgroundVisibility()

func createNewParallaxBG() -> ParallaxBG:
	return _parallax_bg_prototype.clone()

func assignRandomPath(moveType: String, variant: String, monster):
	var occupations = get(moveType + "PathOccupations")
	var path: Path2D = getPath(moveType, variant)
	occupations[path].append(monster)
	monster.connect("died", Callable(self, "freePathOccupation").bind(moveType, path, monster))

	return path

func getPath(moveType: String, variant: String) -> Path2D:
	var paths: Array = getPaths(moveType, variant)
	return paths[getPathIndex(moveType, variant)]

func getPathIndex(moveType: String, variant: String) -> int:
	var paths: Array = getPaths(moveType, variant)
	var occupations = get(moveType + "PathOccupations")
	var monsterCount: = 9999
	var pathIndex: int = -1

	for i: int in range(paths.size()):
		var p: Path2D = paths[i]
		var m = occupations[p].size()
		if m < monsterCount:
			pathIndex = i
			monsterCount = m
	return pathIndex


func getPaths(moveType: String, variant: String) -> Array:
	return get(moveType + "Paths").get(variant, [])

var sortOccupations
func getDefensivePaths(moveType: String, variant: String):
	var paths: Array = getPaths(moveType, variant)
	sortOccupations = get(moveType + "PathOccupations")
	var r = paths.duplicate()
	r.sort_custom(Callable(self, "sortByOccupations"))
	sortOccupations = null
	return r

func sortByOccupations(p1, p2):
	return sortOccupations[p1].size() > sortOccupations[p2].size()

func assignPathOccupation(moveType, path, monster):
	get(moveType + "PathOccupations")[path].append(monster)

func freePathOccupation(moveType, path, monster):
	get(moveType + "PathOccupations")[path].erase(monster)
	if monster.died.is_connected(freePathOccupation):
		monster.died.disconnect(freePathOccupation)

func ambience() -> AudioStreamPlayer:
	return $Ambience as AudioStreamPlayer

func getFlyerPathProvider():
	return $FlyerPaths

func addBackgroundHub(hub):
	var bgh = find_child("BackgroundHub")
	if bgh:
		find_child("BackgroundHub").add_child(hub)
	else:
		Logger.error(name + " has no Background Hub Spot", "world.addBackgroundHub")

func domeImpact():
	var cg = find_child("Couchgag")
	if cg:
		cg.visible = false
		cg.queue_free()

func updateBackgroundVisibility():
	var bg = find_child("SimpleBackground")
	if bg:
		bg.visible = Options.disableWorldBackgrounds

func getDomePosition() -> Vector2:
	if has_node("DomePosition"):
		return get_node("DomePosition").global_position
	else:
		return to_global(Vector2(0, -14))
