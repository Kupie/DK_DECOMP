class_name Bundle
extends Node2D

var UID: int
var direction: Vector2
var carryInfluences: Array
var goalSpeed: float
var lastCenterPos: Vector2
var leaderNode
var velocity: Vector2 = Vector2.ZERO
var curve: Curve2D

var bundleStopCenter: bool
var playerId: String
var teamId: String
var center: Vector2

func _ready():
	curve = Curve2D.new()

	Style.init($Shoot)
	$Shoot.hide()

func clientStart(direction: Vector2, speed: float, leaderNode, playerId: String) -> void :
	self.playerId = playerId
	self.direction = direction
	self.goalSpeed = speed
	self.leaderNode = leaderNode

	bundleStopCenter = false
	if Data.ofOr(playerId + ".keeper2.bundlestopcenter", false):
		bundleStopCenter = true

	if leaderNode:
		Style.init($LeaderLine)
		leaderNode.before_killed.connect(on_before_killed, CONNECT_ONE_SHOT)
	else:
		$LeaderLine.queue_free()

	$BundleCenter / Amb.startSound.call_deferred()

	teamId = Keepers.getKeeper(playerId).teamId
	Achievements.addIfOpen(self, "KEEPER2_BIGBUNDLE", playerId)

func start(direction: Vector2, bundledCarryables: Array[Carryable], speed: float, duration: float, leaderNode, playerId: String):
	self.playerId = playerId
	self.direction = direction
	self.goalSpeed = speed
	self.leaderNode = leaderNode
	self.carryInfluences = []
	if leaderNode:
		goalSpeed *= 2.0

	bundleStopCenter = false
	if Data.ofOr(playerId + ".keeper2.bundlestopcenter", false):
		bundleStopCenter = true








	if leaderNode:
		Style.init($LeaderLine)
		leaderNode.before_killed.connect(on_before_killed, CONNECT_ONE_SHOT)
	else:
		$LeaderLine.queue_free()

	$BundleCenter / Amb.startSound()

	for carryable in bundledCarryables:
		addCarryable(carryable, duration)

	teamId = Keepers.getKeeper(playerId).teamId
	Achievements.addIfOpen(self, "KEEPER2_BIGBUNDLE", playerId)

func on_before_killed() -> void :
	$LeaderLine.queue_free()

func addCarryable(c, duration):
	var influence = c.getOrCreateCarryInfluence(self)
	carryInfluences.append(influence)
	influence.strength = duration
	influence.applyBundle(self)

func _physics_process(delta):
	if StageManager.isSwitchingStage():
		return
	if not is_multiplayer_authority():
		return

	run_process(delta)

func run_process(delta):
	var size = carryInfluences.size()
	if size == 0:
		if is_multiplayer_authority():
			Level.drops.network_free_bundle(UID)
		queue_free()
		return

	if is_multiplayer_authority():
		center = Vector2()

		for influence in carryInfluences:
			if not is_instance_valid(influence):
				Logger.error("carry influence instance is not valid anymore")
				continue
			center += influence.getCarryable().sync_transform.origin
		center /= float(size)
	$BundleCenter.position = center - global_position

	velocity = (center - lastCenterPos) / delta
	lastCenterPos = center

	var strength = 1.0
	if is_instance_valid(leaderNode):
		var maxDist = 80 + size * 1.5
		var minDist = 14 + size * 0.5
		var fade = 18 + size * 0.5
		var dist = leaderNode.position - center
		var l = dist.length()
		var strengthMax = clamp(1.0 - (l - (maxDist - fade)) / fade, 0.0, 1.0)
		strengthMax = pow(strengthMax, 2)
		var strengthMin = clamp((l - fade) / fade, 0.0, 1.0)
		strength = min(strengthMin, strengthMax)
		if l < maxDist:
			if l <= minDist:
				direction = Vector2.ZERO
			else:
				direction = dist.normalized()

		var inVec = velocity.normalized() * clamp((l - minDist) * 2.0, 0.0, 60.0)
		inVec *= min(1.0, velocity.length() * 0.02)

		curve.clear_points()
		curve.add_point(leaderNode.position - global_position)
		curve.add_point($BundleCenter.position, inVec)
		$LeaderLine.points = curve.get_baked_points()

		$LeaderLine.default_color.a = min(strength, 0.7)
		$LeaderLine.width = 0.0 + strength * 2
		$LeaderLine.z_index = 0

	var goalMovement = direction * (goalSpeed + size * 0.35) * strength

	if goalMovement.length() == 0:
		for influence in carryInfluences:

			if not is_instance_valid(influence):

				carryInfluences.erase(influence)
				continue

			var carryable = influence.getCarryable()
			var impulse = center - carryable.global_position
			if impulse.length() > 130.0:
				influence.dissolve()
				continue
			carryable.apply_central_impulse(impulse.limit_length(3))





	else:
		var centerLocked: = false
		var centerRelativeToDome = Utils.get_position_relative_to_dome(center, teamId)
		if bundleStopCenter and abs(centerRelativeToDome.x) <= GameWorld.TILE_SIZE * 0.5 and not startedInCenter():
			if leaderNode:
				goalMovement.x = - centerRelativeToDome.x
			else:
				goalMovement = Vector2( - centerRelativeToDome.x, 0)
			centerLocked = true


		if goalMovement.length() > 0:
			for influence in carryInfluences:

				if not is_instance_valid(influence):

					carryInfluences.erase(influence)
					continue

				var carryable = influence.getCarryable()
				var move = center - carryable.global_position
				if move.length() > 120.0:
					influence.dissolve()
					continue
				var localCarryablePosition = carryable.global_position - global_position

				if not centerLocked and not leaderNode:
					var bundleProgress = localCarryablePosition.project(goalMovement)
					move += bundleProgress - localCarryablePosition
				var impulse = (move + goalMovement).limit_length(3)
				carryable.apply_central_impulse(Vector2(impulse.x, 0))
				carryable.apply_central_impulse(Vector2(0, impulse.y))

func removeCarryInfluence(carryInfluence):
	carryInfluences.erase(carryInfluence)

func getBundledInfluences() -> Array:
	return carryInfluences.duplicate()

func startedInCenter() -> bool:
	var posRelativeToDome = Utils.get_position_relative_to_dome(global_position, teamId)
	return abs(posRelativeToDome.x) <= GameWorld.TILE_SIZE * 0.5

func serialize() -> Dictionary:
	var data = {}

	data["meta.priority"] = 200
	data["meta.kind"] = "generic"

	data["UID"] = UID
	data["playerId"] = playerId
	data["velocity"] = var_to_str(velocity)
	data["direction"] = var_to_str(direction)
	data["goal_speed"] = var_to_str(goalSpeed)
	data["last_center_pos"] = var_to_str(lastCenterPos)
	data["bundle_stop_center"] = var_to_str(bundleStopCenter)

	var id = -1
	if is_instance_valid(leaderNode):
		if leaderNode is Carryable:
			id = leaderNode.UID
		elif leaderNode is Keeper:
			id = leaderNode.playerId
	data["leader_id"] = var_to_str(id)

	var targets: = []
	for x in carryInfluences:
		targets.append([x.carryable.UID, x.strength])
	data["target_ids"] = var_to_str(targets)
	return data

func deserialize(data: Dictionary):

	await (tree_entered)

	UID = data.get("UID", randi())
	playerId = data.get("playerId", "player1")
	Level.drops.track_bundle(self)
	velocity = BackwardCompatibilityUtils.str_to_var(data["velocity"])
	direction = BackwardCompatibilityUtils.str_to_var(data["direction"])
	goalSpeed = BackwardCompatibilityUtils.str_to_var(data["goal_speed"])
	lastCenterPos = BackwardCompatibilityUtils.str_to_var(data["last_center_pos"])
	bundleStopCenter = BackwardCompatibilityUtils.str_to_var(data["bundle_stop_center"])

	var all_carryable = get_tree().get_nodes_in_group("carryable")
	var map = {}
	for x in all_carryable:
		map[x.UID] = x

	var leaderid = BackwardCompatibilityUtils.str_to_var(data["leader_id"])
	if leaderid is String:
		leaderNode = Keepers.getKeeper(leaderid)
	else:
		leaderNode = map.get([leaderid])
	var targets = BackwardCompatibilityUtils.str_to_var(data["target_ids"])
	for x in targets:
		var carryable = map.get(x[0])
		var influence = carryable.getOrCreateCarryInfluence(self)
		influence.strength = x[1]
		carryInfluences.append(influence)
		influence.applyBundle(self)
