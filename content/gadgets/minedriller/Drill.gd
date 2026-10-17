extends Node2D

signal state_changed

@export var synchronizer: GadgetSynchronizer

var teamId: String

var cooldown: = 0.0
var tileLength: = 0
var maxTileLength: = 0
var didDrill: = false
var centerDrill: = true
var sideMaxDepth: = 0

var sideDrills: = []

var sideDrillers: = {}

func _ready():
	if centerDrill:
		Data.listen(self, teamId + ".drill.sides", true)
		Data.listen(self, teamId + ".drill.widetunnel", true)

	Data.listen(self, teamId + ".drill.magnetic", true)
	$MagneticArea / CollisionShape2D.shape = $MagneticArea / CollisionShape2D.shape.duplicate()

	add_to_group(teamId + "-drill")

	$TileToucher.teamId = teamId

	$TentacleAttachBody / CollisionShapeLeft.shape = $TentacleAttachBody / CollisionShapeLeft.shape.duplicate()
	$TentacleAttachBody / CollisionShapeRight.shape = $TentacleAttachBody / CollisionShapeRight.shape.duplicate()

	Style.init(self)

func serialize() -> Dictionary:
	var data = {
		"meta.priority": 200, 
		"meta.kind": "station", 
		"tileLength": tileLength, 
		"cooldown": cooldown, 
		"didDrill": didDrill, 
		"centerDrill": centerDrill, 
	}
	var tileToucherData: = {}
	$TileToucher.serialize(tileToucherData)
	data["tileToucherData"] = tileToucherData

	if centerDrill:
		var sideDrillerData: = []
		for side in get_tree().get_nodes_in_group(teamId + "-minedriller_sidedriller"):
			sideDrillerData.append(side.serialize())
		data["sideDrillerData"] = sideDrillerData
	return data

func deserialize(data: Dictionary):
	tileLength = int(data["tileLength"])
	setRegion(tileLength)
	cooldown = data["cooldown"]
	centerDrill = data["centerDrill"]
	didDrill = data["didDrill"]
	if centerDrill:
		var sideDrillerData = data["sideDrillerData"]
		var i: = 0
		for side in get_tree().get_nodes_in_group(teamId + "-minedriller_sidedriller"):
			if sideDrillerData.size() > i:
				side.deserialize(sideDrillerData[i])
			i += 1
	$TileToucher.deserialize(data["tileToucherData"])

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".drill.magnetic":
		$MagneticArea.monitoring = newValue
		if newValue:
			$MagneticArea.gravity_space_override = Area2D.SPACE_OVERRIDE_REPLACE
			$MagneticArea.linear_damp_space_override = Area2D.SPACE_OVERRIDE_REPLACE
			$MagneticArea.angular_damp_space_override = Area2D.SPACE_OVERRIDE_REPLACE
		else:
			$MagneticArea.gravity_space_override = Area2D.SPACE_OVERRIDE_DISABLED
			$MagneticArea.linear_damp_space_override = Area2D.SPACE_OVERRIDE_DISABLED
			$MagneticArea.angular_damp_space_override = Area2D.SPACE_OVERRIDE_DISABLED
	elif property == teamId + ".drill.sides":
		var spawned_sidedrillers = get_tree().get_nodes_in_group(teamId + "-minedriller_sidedriller")
		var diff = newValue - spawned_sidedrillers.size()
		if diff < 0:
			for x in abs(diff):
				spawned_sidedrillers[spawned_sidedrillers.size() - 1].queue_free()
				spawned_sidedrillers.remove_at(spawned_sidedrillers.size() - 1)
		else:
			if multiplayer.is_server():
				for _i in diff:
					var randPosition: = maxf(72, tileLength * randf_range(0.1, 0.9) * GameWorld.TILE_SIZE)
					var drillerName: = "SideDriller-%d" % sideDrillers.size()
					networkSpawnSideDriller(drillerName, randPosition)
	elif property == teamId + ".drill.widetunnel":
		if not newValue:
			return
		var spawned_drills = get_tree().get_nodes_in_group(teamId + "-drill")
		if spawned_drills.size() >= 3:
			return

		for x in [-24, 24]:
			var drill = load("res://content/gadgets/minedriller/Drill.tscn").instantiate()
			drill.teamId = teamId
			drill.position = position
			drill.position.x += x
			drill.centerDrill = false
			drill.onSpawnSidedrill()




			if x < 0:
				drill.name = "DrillLeft"
			else:
				drill.name = "DrillRight"
			get_parent().add_child(drill)
			sideDrills.append(drill)

func networkSpawnSideDriller(drillerName: String, yStartPosition: float) -> void :
	synchronizer.network_rpc(spawnSideDriller.bind(drillerName, yStartPosition), true)

@rpc("reliable")
func spawnSideDriller(drillerName: String, yStartPosition: float) -> void :
	var sideDriller = preload("res://content/gadgets/minedriller/SideDriller.tscn").instantiate()
	sideDriller.teamId = teamId
	sideDriller.position.y = yStartPosition
	sideDriller.maxDepth = sideMaxDepth
	sideDriller.name = drillerName
	sideDrillers[sideDriller.name] = sideDriller
	sideDriller.holdStarted.connect(networkSideDrillerStartHold)
	sideDriller.holdStopped.connect(networkSideDrillerStopHold)
	add_child(sideDriller)

func networkSideDrillerStartHold(drillerName: String, playerId: String) -> void :
	synchronizer.rpc_server(sideDrillerStartHold.bind(drillerName, playerId))

@rpc("reliable", "any_peer")
func sideDrillerStartHold(drillerName: String, playerId: String) -> void :
	var sideDriller: = sideDrillers[drillerName] as SideDriller
	if sideDriller.grabbed:
		return

	synchronizer.network_rpc(remoteSideDrillerStartHold.bind(drillerName, playerId), true)

@rpc("reliable")
func remoteSideDrillerStartHold(drillerName: String, playerId: String) -> void :
	var sideDriller: = sideDrillers[drillerName] as SideDriller
	sideDriller.startHold(playerId)

func networkSideDrillerStopHold(drillerName: String, goalPos: float) -> void :
	synchronizer.network_rpc(sideDrillerStopHold.bind(drillerName, goalPos), true)

@rpc("reliable", "any_peer")
func sideDrillerStopHold(drillerName: String, goalPos: float) -> void :
	sideDrillers[drillerName].stopHold(goalPos)

func setLength(y):
	maxTileLength = y
	for x in sideDrills:
		x.setLength(y)

var t
func setLength2(y):
	tileLength = max(tileLength, y)

	if t:
		t.kill()
	t = create_tween()
	var oldY = $SpriteBase.region_rect.size.y
	var newY = max(0, y * 24)
	t.tween_method(setRegion, oldY, newY, abs(newY - oldY) * 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(1.0)

func onSpawnSidedrill():
	if not SaveGame.currentLoadingSavegame:
		$TileToucher.passThroughIndestructibleRock = true

func setRegion(v: float):
	$SpriteBase.region_rect.size.y = v
	$SpriteBase / shadow.region_rect.size.y = v
	$SpriteBase.region_rect.position.y = - v
	$SpriteBase / shadow.region_rect.position.y = - v
	$SpriteBase.position.y = v * 0.5 + 36


	$MagneticArea / CollisionShape2D.shape.size.y = v
	$MagneticArea / CollisionShape2D.position.y = v * 0.5
	$TentacleAttachBody / CollisionShapeLeft.shape.b = Vector2(0, v)
	$TentacleAttachBody / CollisionShapeRight.shape.b = Vector2(0, v)
	if centerDrill:
		sideMaxDepth = v + 36
		for side in get_tree().get_nodes_in_group(teamId + "-minedriller_sidedriller"):
			side.maxDepth = sideMaxDepth

func _process(delta: float) -> void :
	if $TileToucher.position.y - 72 > $SpriteBase.region_rect.size.y:
		setRegion($TileToucher.position.y - 72)

	tileLength = max(tileLength, floor(($TileToucher.position.y - 48) / 24))



func _on_tile_toucher_tile_destroyed() -> void :
	setLength2(floor($TileToucher.position.y / 24) - 2)

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_float(tileLength)
	stream.encode_float(cooldown)
	stream.encode_bool(didDrill)
	stream.encode_bool(centerDrill)
	if centerDrill:
		stream.encode_u8(get_tree().get_nodes_in_group(teamId + "-minedriller_sidedriller").size())
		for side in get_tree().get_nodes_in_group(teamId + "-minedriller_sidedriller"):
			var data: PackedByteArray = side.to_bytes()
			stream.encode_u32(data.size())
			stream.append_array(data)
	stream.append_array($TileToucher.to_bytes())
	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	tileLength = stream.decode_float()
	setRegion(tileLength)
	cooldown = stream.decode_float()
	didDrill = stream.decode_bool()
	centerDrill = stream.decode_bool()
	if centerDrill:
		var sideDrillerCount: = stream.decode_u8()
		for i in range(sideDrillerCount):
			var sideDriller = preload("res://content/gadgets/minedriller/SideDriller.tscn").instantiate()
			sideDriller.teamId = teamId
			sideDriller.maxDepth = sideMaxDepth
			sideDriller.holdStarted.connect(networkSideDrillerStartHold)
			sideDriller.holdStopped.connect(networkSideDrillerStopHold)
			var size: = stream.decode_u32()
			sideDriller.from_bytes(stream.slice(size).data)
			sideDrillers[sideDriller.name] = sideDriller
			add_child(sideDriller)
	$TileToucher.from_bytes(stream.remaining())
