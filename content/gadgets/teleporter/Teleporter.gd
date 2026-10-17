class_name Teleporter
extends Carryable

var type: = CONST.TELEPORTER
var gravity: Vector2
var off: = Vector2()
var station: TeleporterStation
var resourcesInSucker: = []
var currentlySuckedResource
var originalAccel
var originalSpeedClamp
var suckCooldown: = 0.0
var shake: = 0.0
var pullCountdown: = 0.0
var teleporting: = false
var warpCommitted: = false
var currentKeeper: Keeper

func _ready():
	super._ready()
	$Sprite2D.play("ready")
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * ProjectSettings.get_setting("physics/2d/default_gravity_vector")
	Data.listen(self, teamId + ".teleporter.teleportResources")
	Data.listen(self, teamId + ".teleporter.teleportResourcesArea", true)
	Data.listen(self, teamId + ".teleporter.slowdown", true)
	$ResourceSucker / CollisionShape2D.disabled = not Data.of(teamId + ".teleporter.teleportResources")
	%SuckLine.visible = false
	Style.init(self)

	Level.addTutorial(self, "teleporter_teleport", teamId)
	Level.addTutorial(self, "teleporter_carry", teamId)

	Keepers.keeper_unregistered.connect(on_keeper_removed)

func setTeam(newTeamId: String) -> void :
	super.setTeam(newTeamId)
	set_collision_mask_value(CONST.LAYER_BLOCKER_TEAM_1, newTeamId == "team1")
	set_collision_mask_value(CONST.LAYER_BLOCKER_TEAM_2, newTeamId == "team2")

func serialize() -> Dictionary:
	var data = super.serialize()
	data["pullCountdown"] = pullCountdown
	data["suckCooldown"] = suckCooldown
	data["teamId"] = teamId
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	pullCountdown = data["pullCountdown"]
	suckCooldown = data["suckCooldown"]
	teamId = data.get("teamId", "team1")

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".teleporter.slowdown":
		additionalSlowdown = newValue
	elif property == teamId + ".teleporter.teleportresources":
		$ResourceSucker / CollisionShape2D.disabled = not newValue
	elif property == teamId + ".teleporter.teleportresourcesarea":
		$ResourceSucker / CollisionShape2D.shape.radius = newValue * GameWorld.TILE_SIZE

func onCarried(p):
	if currentlySuckedResource:
		arrived(currentlySuckedResource)

func onDropped(keeper_or_kunaicarrier):



	pass

func _physics_process(delta):
	if not multiplayer.is_server():
		super._physics_process(delta)

		if isCarried() or GameWorld.paused:
			return

		processCooldownAndSetReady(delta)
		if suckCooldown > 0.0:
			return
		if is_instance_valid(currentlySuckedResource) and not currentlySuckedResource.absorbed:
			%SuckLine.set_point_position(1, currentlySuckedResource.global_position - global_position)
		return

	if isCarried():
		return

	apply_central_impulse( - linear_velocity.limit_length(max(1.0, linear_velocity.length() * 0.025)))
	off.y = sin(0.01 * Time.get_ticks_msec()) * 1.3
	apply_central_impulse(off)



	var drot = 0.0 - rotation
	apply_torque_impulse(drot * 3.0)

	if GameWorld.paused:
		return

	processCooldownAndSetReady(delta)
	if suckCooldown > 0.0:
		return

	if $ResourceSucker / CollisionShape2D.disabled:
		return

	if not currentlySuckedResource:
		var closestDistance: = 9999.0
		var closestResource: Node = null
		for resource in resourcesInSucker:
			if resource.isCarried() and not resource.has_meta("teleporter_droppable"):
				continue
			if not resource.canFocusCarry():
				continue
			var distance = resource.global_position.distance_to(global_position)
			if distance < closestDistance:
				closestDistance = distance
				closestResource = resource
		if closestResource:
			if closestResource.isCarried():
				Level.drops.network_drop_from_all(closestResource)
			station.synchronizer.network_rpc(station.networkSuckAnimation.bind(closestResource.UID))
			currentlySuckedResource = closestResource
			currentlySuckedResource.floatToDropTarget(self)
			currentlySuckedResource.dissolveCarryInfluence()
			currentlySuckedResource.dropTargetRef = self
			originalAccel = currentlySuckedResource.independentAcceleration
			originalSpeedClamp = currentlySuckedResource.independentSpeedClamp
			startSuckAnimation()
			shake = 20.0
			pullCountdown = 0.0
			return

	if currentlySuckedResource:
		var suckProgress = clamp(pullCountdown / 12.0, 0.01, 1.0)
		currentlySuckedResource.independentAcceleration = originalAccel * suckProgress * 80
		currentlySuckedResource.independentSpeedClamp = originalSpeedClamp * suckProgress * 80
		%SuckLine.set_point_position(1, currentlySuckedResource.global_position - global_position)
		pullCountdown += delta
		if pullCountdown > 16.0:
			arrived(currentlySuckedResource)

func processCooldownAndSetReady(delta: float) -> void :
	if suckCooldown > 0.0:
		suckCooldown -= delta * GameWorld.cycleSpeed
	elif $Sprite2D.animation != "active":
		$Sprite2D.play("ready")

func dropTarget() -> Vector2:
	return global_position

func onTeleported(duration: float, delay: = 0.0):
	%LightBig.light_size = 0.1
	%TeleporterActiveParticle.emitting = true
	$Sprite2D.play("active")
	%LightTween.remove_all()

	%LightTween.interpolate_callback(self, delay, "startParticleEffects")
	%LightTween.interpolate_property( %LightBig, "light_size", 0.1, 64, duration, Tween.TRANS_SINE, Tween.EASE_OUT, delay)
	%LightTween.interpolate_property( %LightBig, "light_flicker_strength", 1, 6, duration, Tween.TRANS_SINE, Tween.EASE_OUT, delay)
	%LightTween.interpolate_property( %TeleporterActiveBg, "self_modulate:a", 0, 1, delay, Tween.TRANS_SINE, Tween.EASE_OUT)


	%LightTween.interpolate_property( %LightBig, "light_size", 64, 0.1, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT, delay + duration)
	%LightTween.interpolate_property( %LightBig, "light_active", true, false, 0.01, Tween.TRANS_SINE, Tween.EASE_OUT, 0.3 + delay + duration)
	%LightTween.interpolate_property( %TeleporterActiveBg, "self_modulate:a", 1, 0, delay, Tween.TRANS_SINE, Tween.EASE_OUT, delay + duration)
	%LightTween.interpolate_callback(self, delay + duration, "stopParticleEffects")
	%LightTween.start()

	create_tween().tween_callback(stopTeleporting).set_delay(delay + duration)

func stopParticleEffects():
	$Sprite2D.play("cooldown")
	$Effects / AppearParticles2.emitting = false
	$Effects / AppearParticles.emitting = false
	$Effects / StartupParticles.emitting = false
	$Effects / StartupParticles2.emitting = false
	%TeleporterActiveParticle.emitting = false

func startParticleEffects():
	%LightBig.light_active = true
	$Effects / AppearParticles2.emitting = true
	$Effects / AppearParticles.emitting = true
	$Effects / StartupParticles.emitting = true
	$Effects / StartupParticles2.emitting = true

func stopTeleporting() -> void :
	teleporting = false

func stopSuckAnimation():
	if not %SuckLine.visible:
		return
	$Sprite2D.play("cooldown")
	%LightTween.interpolate_property( %TeleporterActiveBg, "self_modulate:a", 1, 0, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT, 0.3)
	%LightTween.interpolate_callback( %TeleporterActiveParticle, 0.3, "set_emitting", false)
	%LightTween.start()
	%SuckLine.visible = false
	$Effects / StartupParticles.emitting = false
	$Effects / StartupParticles2.emitting = false
	%LightBig.light_active = false
	$ResourcePull.stop()
	$ResourcePullStop.startSound()

func startSuckAnimation():
	$ResourcePull.startSound()
	%SuckLine.visible = true
	$Effects / StartupParticles.emitting = true
	$Effects / StartupParticles2.emitting = true
	$Sprite2D.play("active")
	%TeleporterActiveParticle.emitting = true
	%LightTween.remove_all()
	%LightTween.interpolate_property( %LightBig, "light_size", 5, 28, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT)
	%LightTween.interpolate_property( %LightBig, "light_flicker_strength", 1, 2, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT)
	%LightTween.interpolate_property( %TeleporterActiveBg, "self_modulate:a", 0, 1, 0.15, Tween.TRANS_SINE, Tween.EASE_OUT)
	%LightTween.start()
	%LightBig.light_active = true

func animateTeleportation(lenght: = 1.0, use_timer: = true):
	$Sprite2D.play("active")
	%TeleporterActiveParticle.emitting = true
	$Effects / StartupParticles.emitting = true
	$Effects / StartupParticles2.emitting = true
	$Effects / AppearParticles.emitting = false
	$Effects / AppearParticles2.emitting = false
	%LightTween.remove_all()
	%LightTween.interpolate_property( %LightBig, "light_size", 5, 64, lenght, Tween.TRANS_SINE, Tween.EASE_OUT)
	%LightTween.interpolate_property( %LightBig, "light_flicker_strength", 1, 6, lenght, Tween.TRANS_SINE, Tween.EASE_OUT)
	%LightTween.interpolate_callback($Sprite2D, lenght, "set_animation", "ready")
	%LightTween.interpolate_callback( %TeleporterActiveParticle, lenght, "set_emitting", false)
	%LightTween.interpolate_property( %TeleporterActiveBg, "self_modulate:a", 0, 1, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT)
	%LightTween.interpolate_property( %TeleporterActiveBg, "self_modulate:a", 1, 0, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT, lenght)
	%LightTween.start()
	%LightBig.light_active = true
	if use_timer:
		$AnimationTimer.start(Data.of(teamId + ".teleporter.teleportDuration"))

func canFocusCarry(carrierTeamId: = "") -> bool:
	return super.canFocusCarry() and not teleporting and (carrierTeamId == teamId or carrierTeamId == "")

func canFocusUse(keeper: Keeper) -> bool:
	return not teleporting and Data.of(teamId + ".teleporter.teleportBack") and carriedBy.size() == 0 and keeper.teamId == teamId

func useHit(keeper: Keeper) -> bool:
	if teleporting or not (position.y > 50 and Data.of(teamId + ".teleporter.teleportBack")) and keeper.teamId == teamId:
		return false

	station.synchronizer.rpc_server(station.teleporterRegisterHit.bind(keeper.playerId))
	return true

func startTeleportation(playerId: String) -> void :
	currentKeeper = Keepers.getKeeper(playerId)
	teleporting = true
	warpCommitted = false
	unfocusCarry(currentKeeper)
	var shrinkTime: float = min(2.0, Data.of(teamId + ".teleporter.teleportDuration") * 0.33)
	var transitionTime: float = Data.of(teamId + ".teleporter.teleportDuration") - (2 * shrinkTime)
	var cameras = get_tree().get_nodes_in_group("cameras")
	var goalPos: = Vector2()
	for c in cameras:
		if c.target == currentKeeper:
			goalPos = Utils.get_global_from_local_dome_position(c.getDomeRestPos(), currentKeeper.teamId)
			break
	currentKeeper.startTeleportation(self, shrinkTime, $CollisionShape2D.global_position, goalPos, Data.ofOr(teamId + ".teleporter.teleportitems", false))
	animateTeleportation(shrinkTime, false)

	$TeleportationTimer.interpolate_callback(self, shrinkTime * 0.7, "set", "warpCommitted", true)
	$TeleportationTimer.interpolate_callback(self, shrinkTime, "complete_teleport", false, shrinkTime, transitionTime, currentKeeper)
	$TeleportationTimer.start()

func on_keeper_removed(keeper: Keeper) -> void :
	if currentKeeper != keeper:
		return
	keeperWantsToAbort(keeper)

func keeperWantsToAbort(keeper: Keeper):
	if not teleporting or warpCommitted:
		return

	station.synchronizer.network_rpc(station.networkTeleporterAbort.bind(keeper.playerId), true)

func teleportAbort(playerId: String) -> void :
	$TeleportationTimer.stop_all()
	$TeleportationTimer.remove_all()
	%LightTween.stop_all()

	complete_teleport(true, 0, 0.2, currentKeeper)

func getTeleportPosition() -> Vector2:
	return global_position + Vector2(0, 4)

func useHold(keeper: Keeper) -> bool:
	return false

func canTeleportDrop(body):
	return body.type == CONST.IRON\
	or body.type == CONST.WATER\
	or body.type == CONST.SAND\
	or body.type == "pack"

func _on_ResourceSucker_body_entered(body):
	if canTeleportDrop(body):
		resourcesInSucker.append(body)

func _on_ResourceSucker_body_exited(body):
	if canTeleportDrop(body):
		resourcesInSucker.erase(body)

func arrived(res):
	if res == currentlySuckedResource:
		station.synchronizer.network_rpc(station.networkResourceArrived)
		Level.drops.network_shrink(res, teamId)
		$ResourceTeleport.startSound()
		currentlySuckedResource = null
		suckCooldown = Data.of(teamId + ".teleporter.teleportResourcesCooldown")
		$AnimationTimer.start(0.5)

func remoteArrived() -> void :
	$ResourceTeleport.startSound()
	currentlySuckedResource = null
	suckCooldown = Data.of(teamId + ".teleporter.teleportResourcesCooldown")
	$AnimationTimer.start(0.5)

func pauseChanged():
	super.pauseChanged()
	$AnimationTimer.paused = GameWorld.paused
	if GameWorld.paused and not independent:
		$TeleportationTimer.stop_all()
	else:
		$TeleportationTimer.resume_all()

func isTeleporting() -> bool:
	return teleporting

func _on_AnimationTimer_timeout():
	shake = 0.0
	stopSuckAnimation()
	$Effects / TeleportEffect.frame = 11
	$Sprite2D.offset = Vector2.ZERO
	$Sprite2D.play("cooldown")


func complete_teleport(aborted: bool, shrinkTime: float, transitionTime: float, keeper: Keeper):
	if not aborted:
		warpCommitted = true
	$Effects / StartupParticles.emitting = false
	$Effects / StartupParticles2.emitting = false
	$Effects / TeleportEffect.frame = 0
	$Effects / TeleportEffect.play()
	$Effects / UseParticles.restart()
	$Effects / UseParticles.emitting = true
	%LightBig.light_active = false
	%TeleporterActiveParticle.emitting = false
	%TeleporterActiveBg.self_modulate.a = 0
	keeper.teleportComplete()
	if not aborted:
		keeper.teleport(station.teleportPosition())
		station.onTeleported(shrinkTime, transitionTime - 0.2)
	else:
		teleporting = false
		Level.viewports.abortTeleportAnimation(keeper)
	keeper.grow(shrinkTime, transitionTime - 0.2)
	$Sprite2D.play("cooldown")
