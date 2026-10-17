class_name FruitGrowth
extends Sprite2D

signal hit

const dropPositions: = {
	0: Vector2(1, 0), 
	1: Vector2(-2, 4), 
	2: Vector2(-1, 1), 
	3: Vector2(0, 0), 
	4: Vector2(-2, 3), 
	5: Vector2(-2, 1), 
	6: Vector2(1, 0), 
	7: Vector2(0, 4), 
	8: Vector2(-1, 1)
}

var totalCycles: int
var cyclesToGrow: int
var remainingCycles: int = -1
var type: String = ""
var wasAutoDropped: = false

func _notification(what: int) -> void :
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		visible = false
	if what == NOTIFICATION_READY:
		Style.init($Sprite2D)

func canFocusUse(keeper: Keeper) -> bool:
	return visible and type != ""

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if canFocusUse(keeper):
		hit.emit(keeper)
		return true
	else:
		return true

func registerHit(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	spawnResource(keeper)
	clear()

func spawnResource(keeper: Keeper = null, impulse: Vector2 = Vector2.ZERO):
	if not multiplayer.is_server():
		return

	var data: = {
		"type": type, 
		"position": $Sprite2D.global_position, 
		"team": owner.teamId, 
	}

	if keeper != null:
		data["carriers"] = [keeper.playerId]

	if impulse != Vector2.ZERO:
		data["impulse"] = impulse

	Level.drops.network_spawn(data)

func setType(type: String):
	match type:
		CONST.IRON:
			frame = -1 + int(name.substr(name.find("_") + 1))
			$Sprite2D.texture = preload("res://content/drop/iron/iron_smol.png")
			cyclesToGrow = 1
		CONST.WATER:
			frame = 2 + int(name.substr(name.find("_") + 1))
			$Sprite2D.texture = preload("res://content/drop/water/water_smol.png")
			cyclesToGrow = 2
		CONST.SAND:
			frame = 5 + int(name.substr(name.find("_") + 1))
			$Sprite2D.texture = preload("res://content/drop/sand/sand_smol.png")
			cyclesToGrow = 3
	$Sprite2D.position = dropPositions[frame]
	if wasAutoDropped:
		cyclesToGrow -= 1
		wasAutoDropped = false
	remainingCycles = cyclesToGrow
	self.type = type
	visible = remainingCycles <= 0 and type != ""

func progressCycle():
	if type == "":
		return
	totalCycles += 1

	if remainingCycles == 0:
		if multiplayer.is_server():
			spawnResource(null, Vector2(0, 10).rotated(randf() * TAU))
		clear()
		wasAutoDropped = true

	if remainingCycles > 0:
		remainingCycles -= 1
	if remainingCycles <= 0 and type != "":
		visible = true

func clear():
	remainingCycles = -1
	visible = false
	type = ""
