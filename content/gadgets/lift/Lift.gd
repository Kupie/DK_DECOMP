extends Area2D


signal state_changed

@export var synchronizer: GadgetSynchronizer

@onready var particles: = $CollisionShape2D / GPUParticles2D

var teamId: String

var liftedRigids: = []
var tileLength: int = -1
var orbCooldown: float
var keeperInsideLift: = false
var addedSpeedPerPlayerId: = {}
var orbState = []
var queuedOrbs = 0
var building: = false

func _ready():
	$build.play("default")
	$build.hide()

	Data.listen(self, teamId + ".lift.useorbs", true)
	Data.listen(self, teamId + ".lift.orbs", true)

	Style.init(self)

	$TentacleAttachBody / CollisionShapeLeft.shape = $TentacleAttachBody / CollisionShapeLeft.shape.duplicate()
	$TentacleAttachBody / CollisionShapeRight.shape = $TentacleAttachBody / CollisionShapeRight.shape.duplicate()

	Achievements.addIfOpen(self, "LIFT_JAM", teamId)
	Achievements.addIfOpen(self, "LIFT_TRANSPORT", teamId)

func serialize() -> Dictionary:
	var state = []
	for lo in get_tree().get_nodes_in_group(teamId + "-lift_orbs"):
		state.append(lo.serialize())

	var data = {
		"tileLength": tileLength, 
		"state": state, 
		"keeperInsideLift": keeperInsideLift, 
		"addedSpeedPerPlayerId": addedSpeedPerPlayerId, 
		"teamId": teamId, 
	}

	data["meta.priority"] = 200
	data["meta.kind"] = "station"

	return data

func deserialize(data: Dictionary):
	teamId = data.get("teamId", "team1")
	setLength(int(data["tileLength"]), true)

	orbState = data.get("state", [])
	keeperInsideLift = data["keeperInsideLift"]
	addedSpeedPerPlayerId = data["addedSpeedPerPlayerId"]

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(building)
	if not building:
		stream.encode_u16(tileLength)

	stream.encode_bool(keeperInsideLift)
	stream.encode_u8(addedSpeedPerPlayerId.size())

	for key in addedSpeedPerPlayerId.keys():
		var value: float = addedSpeedPerPlayerId[key]
		stream.encode_var(key)
		stream.encode_float(value)

	sync_lift_orb_state()
	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	var host_building: = stream.decode_bool()
	if not host_building:
		setLength(stream.decode_u16(), true)

	keeperInsideLift = stream.decode_bool()
	var addedSpeedCount: = stream.decode_u8()
	for i in range(addedSpeedCount):
		var playerId: String = stream.decode_var()
		addedSpeedPerPlayerId[playerId] = stream.decode_float()

func sync_lift_orb_state() -> void :


	await get_tree().create_timer(0.5).timeout
	var stream: = PackedByteStream.new()

	var orbs: = get_lift_orbs()
	stream.encode_u8(orbs.size())
	for lo: LiftOrb in orbs:
		stream.encode_float(lo.position.y)
		stream.encode_u8(lo.state)
		stream.encode_u32(lo.uid)
		var carrySize: = lo.carry.size()
		stream.encode_u8(carrySize)
		for i in range(carrySize):
			stream.encode_u32(lo.carry[i].UID)
	var compressed: = stream.data.compress(FileAccess.CompressionMode.COMPRESSION_ZSTD)
	synchronizer.network_rpc(set_lift_orb_positions.bind(stream.data.size(), compressed))

@rpc("reliable")
func set_lift_orb_positions(size: int, compressed_buffer: PackedByteArray) -> void :
	var buffer: = compressed_buffer.decompress(size, FileAccess.CompressionMode.COMPRESSION_ZSTD)
	var stream: = PackedByteStream.from_bytes(buffer)
	var orbCount: = stream.decode_u8()
	for i in range(orbCount):
		var lo: LiftOrb = get_node("LiftOrb-" + str(i))
		if not is_instance_valid(lo):
			lo = preload("res://content/gadgets/lift/LiftOrb.tscn").instantiate()
		lo.teamId = teamId
		lo.position.y = stream.decode_float()
		lo.setState(stream.decode_u8())
		lo.uid = stream.decode_u32()

		if lo.get_parent() == null:
			add_child(lo)

		var carrySize: = stream.decode_u8()
		for j in range(carrySize):
			var uid: = stream.decode_u32()
			var drop: = Level.drops.get_drop(uid)
			if not lo.carry.has(drop):
				lo.attachCarry(drop)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".lift.useorbs":
		if not newValue:
			var orbs = get_tree().get_nodes_in_group(teamId + "-lift_orbs")
			var res = floor(orbs.size() / 2.0)
			if multiplayer.is_server():
				Data.changeByInt(teamId + ".inventory.iron", res)
				Data.changeByInt(teamId + ".inventory.water", res)
				Data.apply(teamId + ".lift.orbs", 0)
			for orb in orbs:
				orb.dropAllCarries(true)
				orb.queue_free()
			queuedOrbs = 0
			gravity_direction.y = -1
			gravity = 80
			setLength(tileLength, true)
		elif newValue:
			gravity = 0
	elif property == teamId + ".lift.orbs":
		if not Data.of(teamId + ".lift.useorbs"):
			return

		var count = get_tree().get_nodes_in_group(teamId + "-lift_orbs").size()
		var diff = newValue - count - queuedOrbs
		for _i in diff:
			queuedOrbs += 1
			if multiplayer.is_server():
				var yPos: = getBottomOfLift() + GameWorld.TILE_SIZE / 2

				networkSpawnQueuedOrb.call_deferred(yPos)

func getTopOfLift() -> float:
	return -40.0

func getBottomOfLift() -> float:
	return position.y + $Sprite2D.region_rect.size.y + 24

func getLength() -> float:
	return getBottomOfLift() - getTopOfLift()

func setLength(tileLength: int, restore: bool = false):
	if not restore and tileLength == self.tileLength:
		return
	building = false

	var goal = GameWorld.TILE_SIZE * tileLength + 14 + GameWorld.TILE_SIZE
	var growth = goal - $Sprite2D.region_rect.size.y
	if growth <= 0 and !restore:
		return

	var duration = ((growth / float(GameWorld.TILE_SIZE)) if not restore else 0)
	self.tileLength = tileLength
	if not restore:
		building = true

	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property($Sprite2D, "region_rect:size:y", $Sprite2D.region_rect.size.y, goal, duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.interpolate_property($OverlaySprite, "region_rect:size:y", $OverlaySprite.region_rect.size.y, goal, duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)

	var pos_bonus = -20 if not Data.of(teamId + ".lift.useorbs") else 0
	$Tween.interpolate_property($CollisionShape2D, "position:y", $CollisionShape2D.position.y, $Sprite2D.position.y + goal * 0.5 + pos_bonus, duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.interpolate_property($CollisionShape2D, "shape:extents:y", $CollisionShape2D.shape.extents.y, goal * 0.5 - pos_bonus, duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)

	particles.amount = max(1, 5 * tileLength)
	$Tween.interpolate_property(particles, "process_material:emission_box_extents:y", particles.process_material.emission_box_extents.y, goal * 0.5, duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.start()
	$build.show()
	$build / buildSfx.startSound()

	if not restore:
		await get_tree().create_timer(duration).timeout
		building = false

func _physics_process(delta):
	if StageManager.currentStage.stage_ending:
		return

	if multiplayer.is_server():
		var useOrbs = Data.of(teamId + ".lift.useorbs")
		for b: RigidBody2D in liftedRigids:
			if b.independent:

				continue
			var dome: Dome = Level.domesByTeamId[teamId]
			var positionRelativeToDome = Vector2(b.position.x - dome.global_position.x, b.position.y)
			var impulseX = clamp( - b.linear_velocity.x * 0.15, -20.0, 20.0) + clamp( - positionRelativeToDome.x, -1.0, 1.0)
			var limit = 12.0 if useOrbs else 3.0
			if abs(b.position.x - global_position.x) > limit:
				b.apply_central_impulse(Vector2(impulseX, 0))



			elif not useOrbs and b.linear_velocity.y > -1.0:
				var center_direction = sign( - positionRelativeToDome.x)
				b.apply_central_impulse(Vector2(center_direction * 25, -25.0))

	var lift_height: float = $Sprite2D.region_rect.size.y
	$TentacleAttachBody / CollisionShapeLeft.shape.b = Vector2(0, lift_height)
	$TentacleAttachBody / CollisionShapeRight.shape.b = Vector2(0, lift_height)

	if GameWorld.softPaused(teamId):
		return
	$build.position.y = $Sprite2D.position.y + $Sprite2D.region_rect.size.y

func _on_Lift_body_entered(body):
	if body is RigidBody2D:
		liftedRigids.append(body)
		body.isAutoTransported = true
	elif body is Keeper and body.teamId == teamId:
		var keeper: = body as Keeper
		var ups = Data.of(teamId + ".lift.keeperupwardsspeed")
		if ( not addedSpeedPerPlayerId.has(keeper.playerId) or addedSpeedPerPlayerId[keeper.playerId] == 0) and ups > 0:
			addedSpeedPerPlayerId[keeper.playerId] = ups
			if multiplayer.is_server():
				Data.changeByInt(keeper.playerId + ".keeper.additionalupwardsspeed", ups)
	particles.emitting = liftedRigids.size()

func _on_Lift_body_exited(body):
	if body is RigidBody2D:

		if body.position.y < 0 and not Data.ofOr(teamId + ".lift.useorbs", false):
			GameWorld.incrementRunStat("lift_carried_drops", teamId)
		liftedRigids.erase(body)
		body.isAutoTransported = false
	elif body is Keeper and body.teamId == teamId:
		var keeper: = body as Keeper
		if addedSpeedPerPlayerId.has(keeper.playerId):
			if multiplayer.is_server():
				Data.changeByInt(keeper.playerId + ".keeper.additionalupwardsspeed", - addedSpeedPerPlayerId[keeper.playerId])
			addedSpeedPerPlayerId.erase(keeper.playerId)

	particles.emitting = liftedRigids.size()

func liftUpgraded():
	particles.process_material.initial_velocity_min = max(1, Data.of(teamId + ".lift.speed") - 2.0)

func _on_Tween_tween_all_completed():
	$build.hide()
	$build / buildSfx.stop()

func networkSpawnQueuedOrb(yPos: float) -> void :
	synchronizer.network_rpc(spawnQueuedOrb.bind(randi(), yPos), true)

@rpc("reliable")
func spawnQueuedOrb(uid: int, yPos: float):
	if queuedOrbs <= 0:
		return

	if $Sprite2D.region_rect.size.y < GameWorld.TILE_SIZE:
		$SpawnTween.interpolate_callback(self, 1.0, "spawnQueuedOrb", uid, yPos)
		$SpawnTween.start()
		return

	var l = preload("res://content/gadgets/lift/LiftOrb.tscn").instantiate()
	l.teamId = teamId
	l.uid = uid
	add_child(l)
	l.position.y = yPos
	if orbState.size():
		var state = orbState.pop_front()
		l.deserialize(state)

	if queuedOrbs > 0:
		queuedOrbs -= 1

func get_lift_orbs() -> Array[Node]:
	return get_tree().get_nodes_in_group(teamId + "-lift_orbs")

func network_attach_drop_to_lift_orb(lift_orb_uid: int, drop_uid: int) -> void :
	synchronizer.network_rpc(attach_drop_to_lift_orb.bind(lift_orb_uid, drop_uid), true)

@rpc("reliable")
func attach_drop_to_lift_orb(lift_orb_uid: int, drop_uid: int) -> void :
	if not Level.drops.has_drop(drop_uid):
		return
	for lo: LiftOrb in get_lift_orbs():
		if lo.uid == lift_orb_uid:
			lo.attachCarry(Level.drops.get_drop(drop_uid))
			break

func network_drop_carry_from_lift_orb(lift_orb_uid: int, drop_uid: int) -> void :
	synchronizer.network_rpc(drop_carry_from_lift_orb.bind(lift_orb_uid, drop_uid), true)

@rpc("reliable")
func drop_carry_from_lift_orb(lift_orb_uid: int, drop_uid: int) -> void :
	if not Level.drops.has_drop(drop_uid):
		return
	for lo: LiftOrb in get_lift_orbs():
		if lo.uid == lift_orb_uid:
			lo.dropCarry(Level.drops.get_drop(drop_uid))
			break
