extends Node2D

signal request_path_home
signal drop_picked_up
signal drop_retrieved
signal stopped_targeting_drop
enum State{WAIT, PICKUP, WAIT_FOR_PATH_HOME, RETRIEVE}


var state: int = State.WAIT

var teamId: String
var UID: int

var cooldown: float
var carriedResource: String
var targettedDrop
var targetSpot: Vector2
var linear_velocity: Vector2
var speedMod: float = 1.0
var baseSpeed: float = 80
var deliveredResources: int = 0
var retrieveSpeedMod: float = 0.8
var dispatcherId: String

var currentPath: Array
var currentPathIndex: int
var animationBiasVertical: = -0.1
var animationBiasHorizontal: = 0.0

var packedDropContent: Array

func _ready():
	Style.init(self)
	setCarriedResource("")

	if teamId != "":
		add_to_group(teamId + "-transport_drones")

func _physics_process(delta):
	if GameWorld.paused:
		return

	if cooldown > 0.0:
		cooldown -= delta
		return

	match int(state):
		State.WAIT:

			$MoveAmb.stop()
			$Sprite2D.play("idle")
			$Sprite2D.speed_scale = speedMod
		State.PICKUP:
			if not TransportDrone.canTransport(targettedDrop):
				targettedDrop = null
				state = State.WAIT
				return

			if not $MoveAmb.playing:

				$MoveAmb.startSound()

			if followPath(delta):
				$Sprite2D.play("idle")
				var move: Vector2 = targettedDrop.global_position - $PickupSpot.global_position
				if move.length() >= 2 * GameWorld.TILE_SIZE or not is_instance_valid(targettedDrop):
					stopped_targeting_drop.emit()
					return


				if not targettedDrop.get_parent():
					stopped_targeting_drop.emit()
					return

				if move.length() < 1.0:
					if targettedDrop.isCarried():
						if not TransportDrone.detachFromKunaiCarrier(targettedDrop):
							stopped_targeting_drop.emit()
							return
					drop_picked_up.emit()
				else:
					move(move.normalized(), baseSpeed * 0.5 * speedMod, delta)
		State.RETRIEVE:
			if not $MoveAmb.playing:
				$MoveAmb.startSound()

			if followPath(delta):
				$Sprite2D.play("idle")
				var d = targetSpot - global_position
				if d.length() < 1.0:
					drop_retrieved.emit()
				else:
					move(d.normalized(), baseSpeed * speedMod, delta)
		State.WAIT_FOR_PATH_HOME:

			$Sprite2D.play("idle")
			$Sprite2D.speed_scale = speedMod
			emit_signal("request_path_home")
			cooldown = 0.5
			$MoveAmb.stop()

func pickup(drop: Carryable) -> void :
	packedDropContent.clear()
	if drop.type == "pack":
		for d in drop.get_children():
			if CONST.RESOURCE_PACKER_SPRITE_NAME in d.name:
				var dropContent = []
				dropContent.append(d.get_meta("dropType"))
				dropContent.append(d.position.x)
				dropContent.append(d.position.y)
				packedDropContent.append(dropContent)
		drop.get_parent().remove_child(drop)
	else:
		drop.remove()

	var dome = Level.domesByTeamId[teamId]
	targetSpot = dome.getDropTarget(drop.type).dropTarget()
	setCarriedResource(drop.type)
	state = State.WAIT_FOR_PATH_HOME

	var wakeup_call: = preload("res://content/map/tile/RigidBodyWakeupCall.tscn").instantiate()
	wakeup_call.position = position
	get_parent().add_child(wakeup_call)

func retrieve() -> void :
	if carriedResource == CONST.PACK:
		if multiplayer.is_server():
			for drop in packedDropContent:
				Data.changeByInt(teamId + ".inventory." + drop[0], 1)

		packedDropContent.clear()
		for child in $CarriedResource.get_children():
			child.queue_free()
	elif multiplayer.is_server():
		Data.changeByInt(teamId + ".inventory." + carriedResource, 1)

	setCarriedResource("")
	state = State.WAIT
	deliveredResources += 1
	baseSpeed = min(45 + deliveredResources * 2, 240)
	$Sprite2D.speed_scale = speedMod

func stopTargettingDrop() -> void :
	targettedDrop = null
	state = State.WAIT

func followPath(delta: float) -> bool:
	if currentPathIndex >= currentPath.size() - 1:
		return true

	var nextPoint = currentPath[currentPathIndex]
	var afterNextPoint = currentPath[min(currentPathIndex + 1, currentPath.size() - 1)]
	var d = 0.5 * (nextPoint + afterNextPoint) - position
	if d.length() < 6:
		currentPathIndex += 1
		return followPath(delta)
	move(d.normalized(), baseSpeed, delta)
	return false

func move(direction: Vector2, speed: float, delta: float):
	if carriedResource != "":
		speed *= retrieveSpeedMod
	$Sprite2D.speed_scale = 0.5 + speedMod * speed / 100.0
	linear_velocity = lerp(linear_velocity, direction * speed, delta * 10)
	position += linear_velocity * delta
	if direction.length() <= 0.1:
		$Sprite2D.play("idle")
		animationBiasVertical = -0.1
		animationBiasHorizontal = 0.0
	else:
		var prefix = "carry_" if carriedResource != "" else "move_"
		if abs(direction.y) + animationBiasVertical > abs(direction.x) + animationBiasHorizontal:
			animationBiasVertical = 0.2
			animationBiasHorizontal = 0.0
			if direction.y < 0.0:
				$Sprite2D.play(prefix + "up")
			else:
				$Sprite2D.play(prefix + "down")
		else:
			animationBiasHorizontal = 0.2
			animationBiasVertical = -0.1
			if direction.x < 0.0:
				$Sprite2D.play(prefix + "left")
			else:
				$Sprite2D.play(prefix + "right")


func sortByDistance(a, b):
	return (a.position - position).length() < (b.position - position).length()

func targetDrop(drop, path):
	targettedDrop = drop
	targetSpot = targettedDrop.global_position - $PickupSpot.position
	state = State.PICKUP
	currentPath = path
	currentPathIndex = 0


func setPathHome(path):
	state = State.RETRIEVE
	currentPath = path
	currentPathIndex = 0










func setCarriedResource(res: String):
	carriedResource = res
	match res:
		"":
			$CarriedResource.texture = null
			$Sprite2D.play("idle")
		CONST.IRON:
			$CarriedResource.texture = preload("res://content/drop/iron/iron_smol.png")
			$Sprite2D.play("idle")
			$PickupSound.startSound()
		CONST.WATER:
			$CarriedResource.texture = preload("res://content/drop/water/water_smol.png")
			$Sprite2D.play("idle")
			$PickupSound.startSound()
		CONST.SAND:
			$CarriedResource.texture = preload("res://content/drop/sand/sand_smol.png")
			$Sprite2D.play("idle")
			$PickupSound.startSound()
		CONST.PACK:
			for drop in packedDropContent:
				var newChild = Sprite2D.new()
				match drop[0]:
					"iron":
						newChild.texture = preload("res://content/drop/iron/iron_smol.png")
					"water":
						newChild.texture = preload("res://content/drop/water/water_smol.png")
					"sand":
						newChild.texture = preload("res://content/drop/sand/sand_smol.png")
				newChild.position.x = drop[1]
				newChild.position.y = drop[2]
				newChild.rotation = 0
				newChild.scale = Vector2(0.5, 0.5)
				newChild.material = preload("res://content/drop/ShredMaterial.tres")
				Style.init(newChild)
				$CarriedResource.add_child(newChild)
			$Sprite2D.play("carry_idle")


			$PickupSound.startSound()

func serialize() -> Dictionary:
	var data = {}
	data["meta.priority"] = 100
	data["meta.kind"] = "generic"
	data["state"] = state
	data["cooldown"] = cooldown
	data["carriedResource"] = carriedResource
	data["dispatcherId"] = dispatcherId
	data["packedDropContent"] = packedDropContent
	data["deliveredResources"] = deliveredResources
	data["teamId"] = teamId
	data["UID"] = UID
	return data

func deserialize(data: Dictionary):
	UID = data.get("UID", randi())
	teamId = data.get("teamId", "team1")
	add_to_group(teamId + "-transport_drones")
	state = data["state"]
	if state == State.RETRIEVE:
		state = State.WAIT_FOR_PATH_HOME
	elif state == State.PICKUP:
		state = State.WAIT

	deliveredResources = data["deliveredResources"]
	cooldown = data["cooldown"]
	carriedResource = data["carriedResource"]
	dispatcherId = data["dispatcherId"]

	packedDropContent = data["packedDropContent"]

	setCarriedResource(carriedResource)

	await GameWorld.savegame_loaded
	for hub in get_tree().get_nodes_in_group(teamId + "-dronedispatcher"):
		if hub.dispatcherId == dispatcherId:
			hub.assignDrone(self)
			return
	Logger.error("Drone failed to find dispatcher with id %s" % dispatcherId)

func _on_Sprite_frame_changed():
	match $Sprite2D.animation:
		"carry_up":
			match $Sprite2D.frame:
				0: $CarriedResource.position.y = 8
				1: $CarriedResource.position.y = 10
				2: $CarriedResource.position.y = 11
				3: $CarriedResource.position.y = 10
				4: $CarriedResource.position.y = 7
				5: $CarriedResource.position.y = 7
		"carry_down":
			if $Sprite2D.frame >= 2 and $Sprite2D.frame <= 4:
				$CarriedResource.position.y = 7
			else:
				$CarriedResource.position.y = 8
		_:
			$CarriedResource.position.y = 8

func kill():
	queue_free()
	if carriedResource != "":
		Data.changeByInt("inventory.total" + carriedResource, -1)
		var drop = Data.DROP_SCENES.get(carriedResource).instantiate()
		drop.position = $CarriedResource.global_position
		Level.map.call_deferred("addDrop", drop)
