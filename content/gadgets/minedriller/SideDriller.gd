class_name SideDriller
extends Node2D

signal holdStarted(drillerName: String, playerId: String)
signal holdStopped(drillerName: String, goalPos: float)

var teamId: String

var goalPos: float
var newGoalPos: float
var timeSinceTouch: float
var retracting: bool
var maxDepth: float
var releasePlayed: = true
var grabber: Keeper
var grabbed: = false
var _holding_tentacle = null

func _ready():
	goalPos = global_position.y
	newGoalPos = get_clamped_tile_position(goalPos)

	Data.listen(self, teamId + ".drill.sidetimepertile", true)
	Data.listen(self, teamId + ".drill.resourcepull", true)

	Style.init(self)

	%PullerCollisionLeft.disabled = true
	%PullerCollisionRight.disabled = true
	%PullerCollisionRight.shape = %PullerCollisionRight.shape.duplicate()
	%PullerCollisionLeft.shape = %PullerCollisionLeft.shape.duplicate()
	$TentacleAttachBody / CollisionShapeTop.shape = $TentacleAttachBody / CollisionShapeTop.shape.duplicate()
	$TentacleAttachBody / CollisionShapeTop.position.y = 0
	$TentacleAttachBody / CollisionShapeBottom.queue_free()

	$TileToucherLeft.is_blocked_changed.connect(on_left_blocked_changed)
	$TileToucherRight.is_blocked_changed.connect(on_right_blocked_changed)

	add_to_group(teamId + "-minedriller_sidedriller")
	$TileToucherLeft.teamId = teamId
	$TileToucherRight.teamId = teamId

	Keepers.keeper_unregistered.connect(_on_keeper_unregistered)

	Level.addTutorial(self, "drillingrigsidedriller", teamId)

func _on_keeper_unregistered(unregistered_keeper: Keeper) -> void :
	if grabber == unregistered_keeper:
		stopHold(get_clamped_tile_position(goalPos))

func serialize() -> Dictionary:
	var data = {
		"meta.priority": 200, 
		"meta.kind": "station", 
		"goalPos": goalPos, 
		"timeSinceTouch": timeSinceTouch, 
		"retracting": retracting, 
		"maxDepth": maxDepth, 
		"position": var_to_str(position)
		}
	var tileToucherData: = {}
	$TileToucherLeft.serialize(tileToucherData)
	data["tileToucherLeftData"] = tileToucherData
	tileToucherData = {}
	$TileToucherRight.serialize(tileToucherData)
	data["tileToucherRightData"] = tileToucherData
	return data

func deserialize(data: Dictionary):
	goalPos = data["goalPos"]
	newGoalPos = get_clamped_tile_position(goalPos)
	timeSinceTouch = data["timeSinceTouch"]
	retracting = data["retracting"]
	maxDepth = data["maxDepth"]
	position = str_to_var(data["position"])
	$TileToucherLeft.deserialize(data["tileToucherLeftData"])
	$TileToucherRight.deserialize(data["tileToucherRightData"])

	var resourcepull = Data.ofOr(teamId + ".drill.resourcepull", false)
	%PullerCollisionLeft.disabled = not resourcepull
	%PullerCollisionRight.disabled = not resourcepull

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".drill.resourcepull":
		$TileToucherLeft / ResourcePuller.monitoring = newValue
		$TileToucherRight / ResourcePuller.monitoring = newValue
		%PullerCollisionLeft.disabled = not newValue and timeSinceTouch > 1.0 and not retracting
		%PullerCollisionRight.disabled = not newValue and timeSinceTouch > 1.0 and not retracting
	elif property == teamId + ".drill.sidetimepertile":
		$TileToucherLeft.timePerTile = newValue
		$TileToucherRight.timePerTile = newValue

func canFocusUse(keeper: Keeper) -> bool:
	if grabbed and grabber != keeper:
		return false
	return true

func useHold(keeper: Keeper) -> bool:
	if keeper.pickupType != "":
		return false

	if not grabbed:
		holdStarted.emit(name, keeper.playerId)
		$GrabSound.startSound()
		if keeper.has_node("Tentacles"):
			var tentacle = keeper.get_node("Tentacles").get_available_carrying_tentacle()
			if tentacle:
				tentacle.attach_to($TentacleAttachBody, global_position, tentacle.get_claw_pos())
				_holding_tentacle = tentacle

	timeSinceTouch = 0.0

	return true

func startHold(playerId: String) -> void :
	grabber = Keepers.getKeeper(playerId)
	grabbed = true

func stopHold(_newGoalPos: float) -> void :
	grabber = null
	grabbed = false
	newGoalPos = _newGoalPos
	timeSinceTouch = 0.0

func useHit(keeper: Keeper) -> bool:
	return false

func areSidesRetracted() -> bool:
	return $TileToucherRight.position.x <= 8 and $TileToucherLeft.position.x >= -8

func _physics_process(delta):
	if GameWorld.gameover:
		$MoveParticles.emitting = false
		return
	if GameWorld.paused:
		return

	if grabbed:
		if areSidesRetracted():
			goalPos = clamp(grabber.global_position.y, 60, maxDepth)
		else:
			retracting = true
			grabber.move = global_position - grabber.global_position
			%PullerCollisionLeft.disabled = true
			%PullerCollisionRight.disabled = true
			%PullerCollisionLeft.shape.extents.x = 0
			%PullerCollisionRight.shape.extents.x = 0

		$TileToucherLeft.cooldown = 1.0
		$TileToucherRight.cooldown = 1.0
		releasePlayed = false

	if timeSinceTouch >= 0.0 and not (grabbed and not grabber.is_multiplayer_authority()):
		timeSinceTouch += delta

	if is_instance_valid(_holding_tentacle):
		if timeSinceTouch >= 0.0:
			_holding_tentacle.attachmentPoint = global_position
			_holding_tentacle.cooldown_timer = 1.0
		else:
			_holding_tentacle.cooldown_timer = 0.0
			_holding_tentacle = null

	var p = abs($TileToucherLeft.position.x)
	$TileToucherLeft / Arm.region_rect.size.x = p
	$TileToucherLeft / Arm.position.x = p * 0.5
	$TileToucherLeft / Arm / shadow.region_rect.size.x = $TileToucherLeft / Arm.region_rect.size.x

	p = abs($TileToucherRight.position.x)
	$TileToucherRight / Arm.region_rect.size.x = p
	$TileToucherRight / Arm.position.x = - p * 0.5
	$TileToucherRight / Arm / shadow.region_rect.size.x = $TileToucherRight / Arm.region_rect.size.x

	if timeSinceTouch > 0.3 and not releasePlayed:
		newGoalPos = get_clamped_tile_position(goalPos)
		holdStopped.emit(name, newGoalPos)
		$ReleaseSound.startSound()
		releasePlayed = true

	if retracting:
		if timeSinceTouch > 0.3:
			retracting = false
			return
		$TileToucherLeft.cooldown = 1.0
		$TileToucherRight.cooldown = 1.0
		var speed = Data.of(teamId + ".drill.extensionspeed") * 50
		$TileToucherLeft.position.x = min(-8, $TileToucherLeft.position.x + speed * delta)
		$TileToucherRight.position.x = max(8, $TileToucherRight.position.x - speed * delta)
		if areSidesRetracted():
			retracting = false
	else:
		var diff = goalPos - global_position.y
		$MoveParticles.rotation = 0 if diff <= 0 else PI
		$MoveParticles.amount_ratio = abs(diff) * 0.1

		var resourcepull = Data.ofOr(teamId + ".drill.resourcepull", false)

		global_position.y = lerp(global_position.y, goalPos, delta * 10)
		if timeSinceTouch >= 0.0:
			$TileToucherLeft.cooldown = 1.0
			$TileToucherRight.cooldown = 1.0
			if timeSinceTouch > 1.0:
				goalPos = newGoalPos
				timeSinceTouch = -1.0
				%PullerCollisionLeft.disabled = not resourcepull
				%PullerCollisionRight.disabled = not resourcepull
		else:
			if resourcepull:
				%PullerCollisionLeft.shape.extents.x = max(0, abs(0.5 * $TileToucherLeft.position.x))
				%PullerCollisionLeft.position.x = %PullerCollisionLeft.shape.extents.x - GameWorld.TILE_SIZE * 0.5

				%PullerCollisionRight.shape.extents.x = max(0, abs(0.5 * $TileToucherRight.position.x))
				%PullerCollisionRight.position.x = - %PullerCollisionRight.shape.extents.x + GameWorld.TILE_SIZE * 0.5
			$TentacleAttachBody / CollisionShapeTop.shape.a = Vector2($TileToucherLeft.position.x, 0)
			$TentacleAttachBody / CollisionShapeTop.shape.b = Vector2($TileToucherRight.position.x, 0)

const LIGHT_ON = preload("res://content/gadgets/minedriller/light_on.png")
const LIGHT_OFF = preload("res://content/gadgets/minedriller/light_off.png")
func on_left_blocked_changed(val):
	$Sprite2D / light_left.texture = LIGHT_OFF if val else LIGHT_ON

func on_right_blocked_changed(val):
	$Sprite2D / light_right.texture = LIGHT_OFF if val else LIGHT_ON

func _on_resource_puller_body_entered(body: Node2D) -> void :
	if not multiplayer.is_server():
		return
	Utils.wakeUpDrop(body)

func get_clamped_tile_position(pos: float) -> float:
	return GameWorld.TILE_SIZE * (-0.5 + round((pos + 12) / GameWorld.TILE_SIZE))

func to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_var(name)
	stream.encode_float(goalPos)
	stream.encode_float(timeSinceTouch)
	stream.encode_bool(retracting)
	stream.encode_float(maxDepth)
	stream.encode_vector2(position)
	var tileToucherLeftData: PackedByteArray = $TileToucherLeft.to_bytes()
	stream.encode_u32(tileToucherLeftData.size())
	stream.append_array(tileToucherLeftData)
	stream.append_array($TileToucherRight.to_bytes())
	return stream.data

func from_bytes(data: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(data)
	name = stream.decode_var()
	goalPos = stream.decode_float()
	newGoalPos = get_clamped_tile_position(goalPos)
	timeSinceTouch = stream.decode_float()
	retracting = stream.decode_bool()
	maxDepth = stream.decode_float()
	position = stream.decode_vector2()
	var tileToucherLeftSize = stream.decode_u32()
	$TileToucherLeft.from_bytes(stream.slice(tileToucherLeftSize).data)
	$TileToucherRight.from_bytes(stream.remaining())

	var resourcepull = Data.ofOr(teamId + ".drill.resourcepull", false)
	%PullerCollisionLeft.disabled = not resourcepull
	%PullerCollisionRight.disabled = not resourcepull
