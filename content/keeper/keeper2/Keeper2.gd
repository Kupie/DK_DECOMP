class_name Keeper2
extends Keeper

signal tileHit
signal pinballSpawned(pinball: Pinball)
signal remainingSpheresChanged(count: int)


@export_group("Node Assignments")
@export var drill_particles: GPUParticles2D
@export var drill_sprite: Sprite2D

@export var charge_central: AnimatedSprite2D
@export var charge_pointer: AnimatedSprite2D

@export var stopped_particles: GPUParticles2D

@export var drill_hit_test_ray: RayCast2D

@export var reflect_cooldown_sprite: AnimatedSprite2D

@export var ammo_path: AmmoPath

@export var collect_modulation_curve: Curve
@export var collect_sprite: Sprite2D
@export var collect_sprite_particles: GPUParticles2D

@export var aim_indicator: Node2D

@export var reflection_cooldown_over: Node
@export var charge_collect_ambience: Node
@export var ammo_added: Node


@export var move_sound: Node
@export var move_fast_sound: Node
@export var move_start_sound: Node
@export var move_stop_sound: Node

@export var carry_drops_area: CollisionShape2D
@export var carry_not_drops_area: CollisionShape2D

@export var ballSplitArea: BallSplitArea
@export var ballExplodeArea: BallExplodeArea

var minBallCharge: = 0.5
var collectCharge: = 0.0
var ballActionCooldown: = 0.0
var reloadSpeedModifier: = 1.0
var chargingCollect: = false
var bundleShotRefPoint: = Vector2()
var tileHitCooldown: = 0.5
var remainingSpheres: = 0
var currentSphereReload: = 0.0

var pushTime: = 0.0
var pushing: = false
var pushDirection: = Vector2()

var insideLift: = false
var carryingResources: = false
var reloadOnNextConsoleExit: = false

var moveStopSoundPlayBuffer: = 0.0
var moveStartSoundPlayBuffer: = 0.0

var bundleEffect

var action_hint_cancel_disable: = -1
var action_hint_interact: = -1
var action_hint_shoot_bundle: = -1
var action_hint_drop: = -1
var action_hint_shoot_pinball: = -1
var last_frame_vel: Vector2

var ballReflectArea: BallReflectArea


@onready var collect_sprite_mat: ShaderMaterial = collect_sprite.material
@onready var collect_sprite_particles_mat = collect_sprite_particles.process_material

var last_collect_sprite_scale: = 0.0

func _ready() -> void :
	super._ready()
	collect_sprite.hide()
	drill_sprite.hide()

func init():
	super.init()
	charge_central.modulate.a = 0.0
	charge_central.play("charge")
	charge_pointer.modulate.a = 0.0
	charge_pointer.play("default")

	keeper_sprite.frame = 0
	focussedUsable = null
	focussedCarryable = null

	ballExplodeArea.start(playerId)
	ballExplodeArea.set_multiplayer_authority(get_multiplayer_authority())
	ballSplitArea.start(playerId)
	ballSplitArea.set_multiplayer_authority(get_multiplayer_authority())
	ammo_path.start(self, playerId)

	remainingSpheres = 0
	currentSphereReload = Data.of(playerId + ".keeper2.spherereload") - 4
	Data.listen(self, teamId + ".monsters.wavepresent")
	Data.listen(self, playerId + ".keeper2.reflectsphere", true)

	Style.init(self)

	Level.addTutorial(self, "assessor2_intro", playerId)
	Level.addTutorial(self, "assessor2_bundle", playerId)
	Level.addTutorial(self, "assessor2_guidance", playerId)

	Achievements.addIfOpen(self, "KEEPER2_AMMO", playerId)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".monsters.wavepresent":
		if newValue and newValue != oldValue:
			reloadOnNextConsoleExit = true
	elif property == playerId + ".keeper2.reflectsphere":
		if newValue and newValue != oldValue:
			visible = true
			Level.addTutorial(self, "assessor2_reflect", playerId)

func enterStation(station, dropResources: = true):
	super.enterStation(station, dropResources)
	aim_indicator.modulate.a = 0.0

func exitStation():
	if reloadOnNextConsoleExit:
		reloadOnNextConsoleExit = false
		var reloadTime = Data.of(playerId + ".keeper2.spherereload")
		var maxSpheres = Data.of(playerId + ".keeper2.totalspheres")
		var timeToAdd = maxSpheres * reloadTime * 0.55
		while timeToAdd > 0.0:
			if timeToAdd >= reloadTime and remainingSpheres < maxSpheres:
				setRemainingSpheres(remainingSpheres + 1)
				timeToAdd -= reloadTime
			else:
				if remainingSpheres == maxSpheres:
					currentSphereReload = 0.0
				else:
					currentSphereReload += timeToAdd
				timeToAdd = -1
		currentSphereReload = clamp(currentSphereReload, reloadTime, 0.0)
	super.exitStation()
	aim_indicator.modulate.a = 1.0

func _physics_process(delta):
	super._physics_process(delta)

	collect_sprite.show()
	drill_sprite.show()

	update_action_hints()

	if isInsideStation or GameWorld.paused or disabled:
		%BuffedSprite.visible = false
		move_sound.stop()
		drill_sprite.visible = false
		return

	var speedBuff = Data.of(playerId + ".keeper.speedBuff")
	var drillBuff = Data.of(playerId + ".keeper.drillBuff")
	%BuffedSprite.visible = speedBuff > 0 or drillBuff > 0

	drill_particles.emitting = false
	drill_sprite.visible = false

	if carriedCarryables.size() > 0 and (carriedCarryables[0].isLocal or multiplayer.is_server()):
		pullCarry()

	if ballActionCooldown > 0.0:
		ballActionCooldown -= delta
		reflect_cooldown_sprite.rotation = randf() * TAU
		if ballActionCooldown <= 0.0:
			if is_multiplayer_authority():
				reloadSpeedModifier = 1.0
			if Data.of(playerId + ".keeper2.reflectsphere"):
				reflection_cooldown_over.startSound()
				reflect_cooldown_sprite.visible = false

	if not is_multiplayer_authority():
		updateMoveAnimation(last_frame_vel * delta, delta)
		updateCollectCharge(delta)
		var collectScaling = min(1.0, collectCharge)
		updateCollectSphereFx(collectScaling)
		_updateMoveFastVolume(move)
		return

	if moveDirectionInput.length() == 0:
		pushTime = 0.0
		pushDirection *= 0
	else:
		drill_hit_test_ray.rotation = moveDirectionInput.angle()
		drill_hit_test_ray.force_raycast_update()
		var tile = drill_hit_test_ray.get_collider()
		if not (tile and tile.has_meta("destructable") and tile.get_meta("destructable")):
			pushTime = 0.0
			pushDirection *= 0
		else:
			if isMovementDummy:
				return
			var directMiningDamage = Data.of(playerId + ".keeper2.directminingdamage")
			var drillbuff = 1.0 + drillBuff
			pushTime += delta * (1.0 - min(last_frame_vel.length() / 35.0, 1.0))
			pushDirection = global_position - tile.global_position
			if pushTime * drillbuff > 0.4:
				if not pushing:
					synchronizer.network_rpc(play_ball_drill_anim.bind(tile.type), true)
			if pushTime * drillbuff > 0.8:
				var hardnessMod = 1.0
				if tile.hardness >= 3:
					hardnessMod -= ((tile.hardness - 2) * Data.of(playerId + ".keeper2.directmininghardness")) / 4.0
				if tile.hardness <= 1:
					hardnessMod += ((2 - tile.hardness) * Data.of(playerId + ".keeper2.directmininghardness")) / 2.0
				var mod = 1.0
				if tile.type == "iron":
					var v = max(15, Data.ofOr("map.ironAdditionalHealth", 0))
					mod = 15.0 / float(v)
				mod = mod * (Data.of("map.tileBaseHealth") / 3.0)
				tile.hit(pushDirection, tile.max_health * directMiningDamage * drillbuff * hardnessMod * delta * mod, teamId, techId)
				var pt = drill_hit_test_ray.get_collision_point()
				synchronizer.network_rpc(emit_ball_drill_particles.bind(pt, (pt - global_position).angle()), true)

				var s = randf_range(0.5, 1.0)
				synchronizer.network_rpc(set_drill_sprite.bind(pt, (pt - global_position).angle(), Vector2(s, s)), true)

	if pushTime <= 0 and pushing:
		synchronizer.network_rpc(stop_ball_drill_anim.bind(), true)


	bundleShotRefPoint = global_position + moveDirectionInput.normalized() * 40



	var moveDotInput = moveDirectionInput.dot(move.normalized())
	var turnSpeed = (1.0 - moveDotInput)
	var strength = 8.0
	var absX = abs(moveDirectionInput.x)
	var absY = abs(moveDirectionInput.y)
	if absX > absY * 1.0:
		if absY > 0.0:
			strength = min(strength, absX / absY)
		move.y *= 1.0 - delta * turnSpeed * strength
	elif absY > absX * 1.0:
		if absX > 0.0:
			strength = min(strength, absY / absX)
		move.x *= 1.0 - delta * turnSpeed * strength

	var theoreticalBaseSpeed = currentSpeed()
	var relativeSpeed = clamp(move.length() / theoreticalBaseSpeed, 0, 1.0)
	var acceleration = Data.of(playerId + ".keeper2.acceleration")



	acceleration *= min(1.0, (1.2 + 2.0 * max(0.0, turnSpeed)) - pow(relativeSpeed, 0.5))
	var deceleration = Data.of(playerId + ".keeper2.deceleration")
	var moveChange = moveDirectionInput * (acceleration + speedBuff) * delta * 3
	if moveDirectionInput.length() == 0:
		move = move * (1 - delta * deceleration)
	else:
		var intentionDiff = move.dot(moveDirectionInput)
		if intentionDiff < 0:
			moveChange *= 1.0 - intentionDiff / 25.0

	move = move + moveChange
	move *= clamp(1.0 - (pushTime - 0.1) * 2.0, 0.0, 1.0)

	_updateMoveFastVolume(move)

	var carrySize: = carriedCarryables.size()
	var slowdown: = 1.0
	for c in carriedCarryables:
		slowdown *= 1.0 - (c.additionalSlowdown / c.carrierCount())

	var minSpeed = Data.of(playerId + ".keeper2.minspeed")
	var collectChargeAffectingSpeed = max(minSpeed * 30.0, minSpeed * theoreticalBaseSpeed * (1.0 - collectCharge * 3.0))
	var loweredByCarryables = max(minSpeed * 24.0, theoreticalBaseSpeed * (1.0 - pow(carrySize, 3) * 0.0065))

	var baseSpeed = min(loweredByCarryables, collectChargeAffectingSpeed)
	var maxSpeed = baseSpeed * slowdown
	if externallyMoved:
		move *= 0
		moveDirectionInput *= 0
	move = move.limit_length(max(0, maxSpeed))

	var actualMove = position
	set_velocity(move)
	move_and_slide_custom()
	actualMove = position - actualMove
	move = velocity



	last_frame_vel = actualMove / delta

	updateMoveAnimation(actualMove, delta)

	if remainingSpheres < Data.of(playerId + ".keeper2.totalspheres"):
		var reloadCounter = max(1.0, currentSphereReload)
		reloadCounter += delta * reloadSpeedModifier
		if Data.of(playerId + ".keeper2.spherereload") <= reloadCounter:
			currentSphereReload = 0.0
			setRemainingSpheres(remainingSpheres + 1)
			ammo_added.startSound()
		else:
			currentSphereReload = reloadCounter

	if tileHitCooldown > 0.0:
		tileHitCooldown -= delta

	updateCollectCharge(delta)

	var collectScaling = min(1.0, collectCharge)
	var radius = 40 * collectScaling
	carry_drops_area.shape.radius = radius + 8
	updateCollectSphereFx(collectScaling)



	updateInteractables()

	var aimDirection = getAimDirection("aim1_snap")
	if carriedCarryables.size() > 0:
		aimDirection = getAimDirection("aim2_snap")

	if aimDirection.length() == 0:
		aim_indicator.modulate.a = 0
	else:
		if aim_indicator.modulate.a == 0:
			aim_indicator.rotation = aimDirection.angle()
		else:
			aim_indicator.rotation = lerp_angle(aim_indicator.rotation, aimDirection.angle(), delta * 30.0)
		aim_indicator.modulate.a = 1

func _updateMoveFastVolume(inMove: Vector2) -> void :
	var additionalVolume: float = -60
	if inMove.length() >= 80:
		additionalVolume = -12 + 12.0 * clamp((inMove.length() - 80) / 160.0, 0.0, 1.0)
	move_fast_sound.setAdditionalVolume(additionalVolume)

@rpc("reliable")
func play_ball_drill_anim(tileType: String):
	pushing = true
	match int(Data.of(playerId + ".keeper2.directminingstage")):
		1:
			$BallDrill.startSound()
			$BallDrillInit.startSound()
		2:
			$BallDrillUpgrade1.startSound()
			$BallDrillInitUpgrade1.startSound()
		3:
			$BallDrillUpgrade2.startSound()
			$BallDrillInitUpgrade2.startSound()
	match tileType:
		CONST.IRON:
			$BallDrillIron.startSound()
		CONST.WATER:
			$BallDrillWater.startSound()
		CONST.SAND:
			$BallDrillCobolt.startSound()
		CONST.GADGET:
			$BallDrillSpecial.startSound()
		CONST.POWERCORE:
			$BallDrillSpecial.startSound()
		CONST.RELIC:
			$BallDrillSpecial.startSound()

@rpc("reliable")
func stop_ball_drill_anim():
	pushing = false
	$BallDrill.stop()
	$BallDrillUpgrade1.stop()
	$BallDrillUpgrade2.stop()
	$BallDrillCobolt.stop()
	$BallDrillSpecial.stop()
	$BallDrillWater.stop()
	$BallDrillIron.stop()

@rpc("reliable")
func emit_ball_drill_particles(point: Vector2, drillRotation: float):
	drill_particles.global_position = point
	drill_particles.rotation = drillRotation
	drill_particles.emitting = true

@rpc("reliable")
func set_drill_sprite(point: Vector2, drillRotation: float, drillScale: Vector2):
	drill_sprite.global_position = point
	drill_sprite.rotation = drillRotation
	drill_sprite.scale = drillScale
	drill_sprite.visible = true

func setRemainingSpheres(newValue: int):
	if remainingSpheres != newValue:
		remainingSpheres = newValue
		remainingSpheresChanged.emit(newValue)

func update_action_hints():
	pass








func updateCollectSphereFx(_scaling: float):
	collect_sprite_particles.visible = not isInsideDome
	var shrinking: = last_collect_sprite_scale > _scaling
	last_collect_sprite_scale = _scaling
	collect_sprite_particles.emitting = not shrinking and last_collect_sprite_scale != _scaling
	collect_sprite_mat.set_shader_parameter("radius", 40 * _scaling * 0.9)
	collect_sprite_mat.set_shader_parameter("edge_width", remap(ease(_scaling, 0.4), 0, 1, 6, 0.7))
	collect_sprite.modulate.a = (ease(_scaling, 0.5) * 0.2) + 0.5
	var mainSpriteMod: Color = collect_sprite.modulate * 2.0
	mainSpriteMod.a = 1.0
	if not shrinking:
		keeper_sprite.modulate = lerp(Color.WHITE, mainSpriteMod, collect_modulation_curve.sample(_scaling))
		collect_sprite.self_modulate = lerp(Color(2, 2, 2, 1), Color.WHITE, ease(_scaling, 0.2))
	else:
		collect_sprite.self_modulate.a *= _scaling
		keeper_sprite.modulate = lerp(Color.WHITE, keeper_sprite.modulate, ease(_scaling, 0.5))
	collect_sprite_particles_mat.emission_ring_radius = 40 * _scaling
	collect_sprite_particles_mat.emission_ring_inner_radius = 40 * _scaling

func pullCarry():
	for c in carriedCarryables.duplicate():
		var d: Vector2 = global_position - c.global_position
		var l = d.length()
		if multiplayer.is_server() and l > 150:
			dropCarry(c)
			continue
		d = (d.normalized() * pow(d.length() * 0.1, 2)).limit_length(20)
		d += d.rotated(PI * 0.5) * 0.1
		c.apply_central_impulse(d)

func updateCollectCharge(delta):

	if chargingCollect:
		if position.y < CONST.DOME_CUPOLA_ENTRANCE_Y:
			collectRelease()
			return

		carry_drops_area.disabled = false
		carry_not_drops_area.disabled = true
		var untilFull = 2.0 * (1.0 - collectCharge)
		collectCharge = min(1.0, collectCharge + (1.0 + untilFull) * delta * 0.1)
		for c in carryables:
			if c.carryableType != "resource" or carriedCarryables.has(c):
				continue

			var influence = c.getOrCreateCarryInfluence(self)
			var newStrength = influence.strength + delta * 5.0
			influence.strength = min(1.0, newStrength)
			influence.beingPulled = true

			var d: Vector2 = global_position - c.global_position
			if d.length() < GameWorld.TILE_SIZE * 2 and newStrength >= 0.9:
				if influence.isBundled():
					var inBundle = influence.getBundle().getBundledInfluences()
					for i in inBundle:
						influence.exitBundle()
					for i in inBundle:
						attachCarry(i.getCarryable())
					return
				else:
					attachCarry(c)
					continue
			if is_multiplayer_authority():
				c.apply_central_impulse(d.limit_length(pow(newStrength * 4, 1.5)))
	else:
		if collectCharge > 0.0:
			collectCharge = max(0.0, collectCharge - 1 * delta)
		carry_drops_area.disabled = true
		carry_not_drops_area.disabled = false


	charge_collect_ambience.setAdditionalPitch(collectCharge * 0.6)
	var carrysize = carriedCarryables.size()
	if not chargingCollect:

		if carrysize == 0 and charge_collect_ambience.shouldPlay:
			charge_collect_ambience.stop()
		charge_collect_ambience.setAdditionalVolume(-6 + min(1.0, 8 * carrysize / 6.0))
	else:
		charge_collect_ambience.setAdditionalVolume(0)

func updateMoveAnimation(actualMove: Vector2, delta: float):
	var combinedMove = moveDirectionInput
	if not pushing and actualMove.length() > 0.15:
		combinedMove += actualMove
	elif actualMove.is_zero_approx():
		pass

	var moving = combinedMove.length() > 0.35
	trail_particles.emitting = moving
	stopped_particles.emitting = not moving

	if not pushing and chargingCollect:
		keeper_sprite.play("pull" + animationSuffix)
	else:
		if combinedMove.length() < 0.35:
			keeper_sprite.play("default" + animationSuffix)
		else:
			var prefix = "push_" if pushing else ""
			if abs(combinedMove.x) > abs(combinedMove.y) * 0.95:
				keeper_sprite.play(prefix + "left" + animationSuffix if combinedMove.x < 0 else prefix + "right" + animationSuffix)
			else:
				keeper_sprite.play(prefix + "up" + animationSuffix if combinedMove.y < 0 else prefix + "down" + animationSuffix)
		if moveDirectionInput.length() == 0 or move.length() < 3:
			moveStartSoundPlayBuffer = 0
			if move_sound.shouldPlay:
				moveStopSoundPlayBuffer += delta
				if moveStopSoundPlayBuffer >= 0.2:
					move_sound.stop()
					move_stop_sound.startSound()
					moveStopSoundPlayBuffer = 0
		else:
			moveStopSoundPlayBuffer = 0
			if not move_sound.shouldPlay:
				moveStartSoundPlayBuffer += delta
				if moveStartSoundPlayBuffer >= 0.1:
					move_sound.startSound()
					move_start_sound.startSound()
					moveStartSoundPlayBuffer = 0

func is_potential_carryable(carryable: Carryable) -> bool:
	if carriedCarryables.has(carryable):
		return false
	if carryable.carryableType != "gadget":
		return false
	if not carryable.canFocusCarry(teamId):
		return false
	if (pickupType != "" and pickupType != carryable.carryableType):
		return false
	if carryable.is_in_group("usables") and not usables.has(carryable.get_meta("usable")):
		return false

	return true

func updateCarryables():
	if not is_instance_valid(focussedCarryable):
		focussedCarryable = null

	if focussedCarryable:
		if not focussedCarryable.canFocusCarry(teamId)\
		or not carryables.has(focussedCarryable)\
		or carriedCarryables.has(focussedCarryable)\
		or (focussedCarryable.is_in_group("usables") and not usables.has(focussedCarryable.get_meta("usable"))):
			focussedCarryable.unfocusCarry(self)
			focussedCarryable = null


	var potentialCarryables: = []
	for carryable in carryables:
		if not is_instance_valid(carryable):
			continue

		if is_potential_carryable(carryable):
			potentialCarryables.append(carryable)

	potentialCarryables.sort_custom(sortByDistance)

	for carryable in potentialCarryables:
		if focussedCarryable == carryable:
			return
		else:
			if focussedCarryable:
				focussedCarryable.unfocusCarry(self)
			focussedCarryable = carryable
			focussedCarryable.focusCarry(self)
		return

func attachCarry(body):
	_ensureFreeFromKunaiCarrier(body)
	Level.drops.network_pickup(body, playerId)

func _attachCarryInternal(body):
	if carriedCarryables.has(body):
		Logger.error("Tried to attach carryable " + body.name + "although it's already carried ")
		return
	body.unfocusCarry(self)
	if body == focussedUsable:
		focussedUsable = null





	if not body.is_inside_tree():
		await body.tree_entered
		await get_tree().create_timer(0).timeout

	var influence = body.getOrCreateCarryInfluence(self)
	if influence.bundle:
		influence.exitBundle()
		influence = body.getOrCreateCarryInfluence(self)
	influence.strength = 1.0

	var po = CarryablePhysicsOverride.new(self)
	po.gravity_scale = 0.0
	po.linear_damp = 2
	po.angular_damp = 2
	body.addPhysicsOverride(po)
	carriedCarryables.append(body)
	body.setCarriedBy(self)

	$Pickup.startSound()

func shootPinball():
	var keeperCoord = Level.map.getTileCoord(global_position)
	var newPos = Level.map.getTilePos(keeperCoord)
	var db = Data.of(playerId + ".keeper.drillBuff")
	var spherePos = lerp(position, newPos, 0.45)
	var size = 1.0 + min(0.35, db * 0.5)
	var maxSpeed = db * 60
	var aimDirection: = getAimDirection("aim1_snap")
	if aimDirection.length() <= 0:
		aimDirection = moveDirectionInput.normalized()
	var startingForce: = aimDirection * 150
	synchronizer.network_rpc(networkShootPinball.bind(spherePos, size, maxSpeed, playerId, startingForce, 1, randi()), true)

	InputSystem.shakeTarget(self, 50, 0.2)

	emit_signal("mined", 3.0)

@rpc("reliable", "any_peer")
func networkShootPinball(pos: Vector2, size: float, maxSpeed: float, sendingPlayerId: String, startingForce: Vector2, generation: int, UID: int, useRemainingSpheres: bool = true) -> void :
	$Shoot.startSound()
	var sphere = preload("res://content/keeper/keeper2/Pinball.tscn").instantiate()
	sphere.UID = UID
	sphere.name = "Pinball-%d" % UID
	sphere.position = pos
	sphere.size = size
	sphere.maxSpeed += maxSpeed
	sphere.playerId = sendingPlayerId
	sphere.generation = generation
	sphere.set_multiplayer_authority(get_multiplayer_authority())
	get_parent().add_child(sphere)
	if sphere.generation > 1:
		sphere.lifeTime *= size
		sphere.modulate.b = 0.6

	pinballSpawned.emit(sphere)

	sphere.apply_central_impulse(startingForce)
	if useRemainingSpheres:
		setRemainingSpheres(remainingSpheres - 1)

func shootBundle(carryables):

	var bundleGroup: Array[Carryable] = []
	for carryable in carryables:
		if carryable.carryableType == "resource":
			bundleGroup.append(carryable)

	if bundleGroup.size() == 0:
		for carryable in carryables:
			bundleGroup.append(carryable)

	bundleGroup.sort_custom(Callable(self, "sortByDistanceToRefPo"))

	var aimDirection = getAimDirection("aim2_snap")
	if aimDirection.length() <= 0:
		aimDirection = moveDirectionInput.normalized()
	var bundleLeader = self if aimDirection.length() == 0.0 and Data.of(playerId + ".keeper2.bundleguide") else null

	Level.drops.network_bundle(
		bundleGroup, 
		position, 
		aimDirection, 
		Data.of(playerId + ".keeper2.bundlespeed"), 
		Data.of(playerId + ".keeper2.bundleduration"), 
		bundleLeader, 
		playerId
	)


	var groupSize = bundleGroup.size()
	InputSystem.shakeTarget(self, min(80, groupSize * 20), 0.2)
	move += aimDirection.rotated(PI) * 10 * groupSize
	carryingResources = false
	synchronizer.network_rpc(playBundleSound.bind(groupSize), true)

@rpc("reliable")
func playBundleSound(groupSize: int):
	if groupSize <= 4:
		$BundleShotSmall.startSound()
	elif groupSize <= 14:
		$BundleShotMedium.startSound()
	else:
		$BundleShotBig.startSound()



func ballHold():
	if disabled or isInsideDome:
		return

	collectRelease()

func ballRelease():
	collectRelease()

func getPotentialBallHitActionName():
	if disabled:
		return null

	var resources: = []
	var otherDrops: = []
	for c in carriedCarryables:
		if c.carryableType == "resource":
			resources.append(c)
		else:
			otherDrops.append(c)

	var shootBundleFirst: bool = input_settings.drop_ressources_before_gadets or otherDrops.is_empty()

	if resources.size() > 0 and shootBundleFirst:
		return "shoot_bundle"

	if otherDrops.size() > 0:
		return "drop_carry"

	if remainingSpheres > 0 and not isInsideDome:
		return "shoot"

	return null

var tmpAimDirection: = Vector2()
func ballHit():
	if disabled:
		return

	var resources: = []
	var otherDrops: = []
	for c in carriedCarryables:
		if c.carryableType == "resource":
			resources.append(c)
		else:
			otherDrops.append(c)

	var shootBundleFirst: bool = input_settings.drop_ressources_before_gadets or otherDrops.is_empty()

	if resources.size() > 0 and shootBundleFirst:
		shootBundle(resources)
	elif otherDrops.size() > 0:
		tmpAimDirection = getAimDirection("aim2_snap")
		if tmpAimDirection.length() == 0:
			tmpAimDirection = moveDirectionInput.normalized()
		otherDrops.sort_custom(sortByDistanceToGlobalPos)
		var farthestCarryable
		for carryable in otherDrops:
			if carryable.carryableType == "resource":
				farthestCarryable = carryable
				break
		if not farthestCarryable:
			farthestCarryable = otherDrops.front()
		dropCarry(farthestCarryable)
		$Drop.startSound()

		if tmpAimDirection.length() > 0:
			var impulse = tmpAimDirection * 150
			farthestCarryable.apply_central_impulse(impulse - farthestCarryable.linear_velocity)
	elif remainingSpheres > 0 and not isInsideDome:
		var aimDirection = getAimDirection("aim1_snap")
		if aimDirection.length() == 0:
			aimDirection = moveDirectionInput.normalized()
		var directionSufficientToShoot: bool
		if input_settings.use_mouse or Options.useGamepad(deviceId):
			directionSufficientToShoot = aimDirection.length() > 0
		else:
			directionSufficientToShoot = moveDirectionInput.length() >= moveDirectionThreshold
		if directionSufficientToShoot:
			shootPinball()

func sortByDistanceToGlobalPos(d1, d2) -> bool:
	var p = global_position + tmpAimDirection * 50.0
	return p.distance_to(d1.global_position) < p.distance_to(d2.global_position)

func collectHold():
	if disabled or position.y < CONST.DOME_CUPOLA_ENTRANCE_Y:
		return

	if collectCharge == 0.0 and focussedCarryable and focussedCarryable.carryableType != "resource":
		attachCarry(focussedCarryable)
		return

	if not chargingCollect:
		chargingCollect = true
		$ChargeCollectStart.startSound()
		charge_collect_ambience.startSound()
		$InitPull.startSound()

func collectRelease():
	if chargingCollect:
		chargingCollect = false
		$ChargeCollectStart.stop()

func collectHit():
	if disabled or position.y < CONST.DOME_CUPOLA_ENTRANCE_Y or not is_multiplayer_authority():
		return


	if focussedCarryable:
		attachCarry(focussedCarryable)
		return

	for u in usables:
		if u.canPickup(self):
			u.useHit(self)
			return

	if isInsideDome:
		return

	if Data.of(playerId + ".keeper2.reflectsphere"):
		if ballActionCooldown <= 0.0:
			synchronizer.network_rpc(createBallReflectArea, true)
	elif Data.of(playerId + ".keeper2.spheresplit"):
		if ballActionCooldown <= 0.0:
			move *= 0.0
			synchronizer.network_rpc(ballSplitAreaCatch, true)
		else:
			$AbilityOnCooldown.startSound()
	elif Data.of(playerId + ".keeper2.explodespheres"):
		if ballActionCooldown <= 0.0:
			synchronizer.network_rpc(ballExplodeAreaExplode, true)
			reloadSpeedModifier = 1.5
		else:
			$AbilityOnCooldown.startSound()

@rpc("reliable")
func createBallReflectArea() -> void :
	ballActionCooldown = Data.of(playerId + ".keeper2.actioncooldown")
	match Data.of(playerId + ".keeper2.actionstage"):
		1: $ReflectionOn.startSound()
		2: $ReflectionOnUpgrade.startSound()
	reflect_cooldown_sprite.visible = true
	reflect_cooldown_sprite.play("active")
	ballReflectArea = preload("res://content/keeper/keeper2/BallReflectArea.tscn").instantiate()
	var keeperCoord = Level.map.getTileCoord(global_position)
	var newPos = Level.map.getTilePos(keeperCoord)
	ballReflectArea.position = lerp(position, newPos, 0.6)
	ballReflectArea.lifetime = Data.of(playerId + ".keeper2.reflectlifetime")
	ballReflectArea.set_multiplayer_authority(get_multiplayer_authority())
	get_parent().add_child(ballReflectArea)
	ballReflectArea.ballReflected.connect(onBallReflected)

func onBallReflected() -> void :
	synchronizer.network_rpc(playBallReflectionAnimation, true)

@rpc("reliable", "any_peer")
func playBallReflectionAnimation() -> void :
	if is_instance_valid(ballReflectArea):
		ballReflectArea.playReflectionAnimation()

@rpc("reliable")
func ballSplitAreaCatch():
	ballSplitArea.catch()
	create_tween().tween_callback(ballSplitArea.stopCatching).set_delay(1.0)

@rpc("reliable")
func ballExplodeAreaExplode():
	ballExplodeArea.explode()

func sortByDistanceToRefPo(d1, d2) -> bool:
	return (d1.global_position - bundleShotRefPoint).length() < (d2.global_position - bundleShotRefPoint).length()

func _dropCarryInternal(carryable):
	carriedCarryables.erase(carryable)
	carryable.freeCarry(self)

func currentSpeed() -> float:
	var s = Data.of(playerId + ".keeper2.maxSpeed")
	s += Data.ofOr(playerId + ".keeper.speedBuff", 0)
	var yMove = move.normalized().y
	s += Data.ofOr(playerId + ".keeper.additionalupwardsspeed", 0) * abs(yMove)
	return s

func disableEffects():
	stopped_particles.emitting = false
	trail_particles.emitting = false
	ammo_path.visible = false

func enableEffects():
	ammo_path.visible = true

func getBallActionCooldown() -> float:
	return ballActionCooldown

func wasHolding() -> bool:
	return collectCharge > 0.0

func onShowKeeperAimIndicatorChanged():
	if not Keepers.local.hasPlayerId(playerId):
		$AimIndicator.visible = false
	elif Options.useGamepad(deviceId):
		$AimIndicator.visible = input_settings.show_aim_indicator
	else:
		$AimIndicator.visible = input_settings.show_aim_indicator\
		and input_settings.use_mouse

func canEnterRemoteStation() -> bool:


	return carriedCarryables.size() == 0
