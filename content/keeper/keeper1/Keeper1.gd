extends Keeper

signal tileHit

const THRUSTER_IDLE_DIR_L: Vector3 = Vector3(-0.5, 1, 0)
const THRUSTER_IDLE_DIR_R: Vector3 = Vector3(0.5, 1, 0)
const THRUSTER_IDLE_VEL: float = 40.0

@export var simulatedCarrySlowdown: = false
@export_group("Node Assignments")
@export var drill_sprite: AnimatedSprite2D
@export var drill_hit_test_ray: RayCast2D
@export var drill_hit: AnimatedSprite2D
@export var drill_hit_particles: GPUParticles2D
@export var thruster_left: GPUParticles2D
@export var thruster_left_boost: AnimatedSprite2D
@export var thruster_right: GPUParticles2D
@export var thruster_right_boost: AnimatedSprite2D

@onready var thruster_left_material: ParticleProcessMaterial = thruster_left.process_material
@onready var thruster_right_material: ParticleProcessMaterial = thruster_right.process_material

var knockbackDirection: = Vector2()
var moveSlowdown: = 0.0
var carrySlowdown: = 0.0
var hitCooldown: = 0.0
var spriteLockDuration: = 0.0
var moveStopSoundPlayBuffer: = 0.0
var moveStartSoundPlayBuffer: = 0.0
const maxCarryLineLength: = 150.0

var carryLines: = {}

var action_hint_drop: = -1
var action_hint_pickup: = -1
var action_hint_cancel_disable: = -1
var action_hint_interact: = -1

func _ready() -> void :
	super._ready()
	drill_sprite.hide()

func init():
	super.init()
	Data.listen(self, playerId + ".keeper1.jetpackStage")

	keeper_sprite.frame = 0
	focussedUsable = null
	focussedCarryable = null
	hitCooldown = 0.0

	thruster_left.emitting = true
	thruster_right.emitting = true

	thruster_left_boost.play()
	thruster_right_boost.play()

	drill_hit.frame = 4

	Style.init(self)
	Level.addTutorial(self, "keeper1_pickup", playerId)
	Level.addTutorial(self, "keeper1_drop", playerId)
	Achievements.addIfOpen(self, "KEEPER1_SHOPPINGBAG", playerId)
	Achievements.addIfOpen(self, "KEEPER1_SPEED", playerId)

	await StageManager.stage_started






func propertyChanged(property: String, oldValue, newValue):
	match property:
		"keeper1.jetpackstage":
			setJetpackStage(newValue)

func _physics_process(delta):
	super._physics_process(delta)



	var keys_to_remove = []
	for key in carryLines.keys():
		if not is_instance_valid(key):
			keys_to_remove.append(key)

	for key in keys_to_remove:
		carryLines[key].queue_free()
		carryLines.erase(key)

		if carryLines.size() == 0:
			$CarryLine.stop()

	for drop: Carryable in carryLines.keys():
		if drop.is_visible_in_tree() == carryLines[drop].visible:
			continue
		carryLines[drop].visible = drop.is_visible_in_tree()

	for t in carryLines:
		var line = carryLines[t]
		var sourcePosition: Vector2 = global_position
		if isInsideStation:
			sourcePosition = _station.getVisualGlobalPosition() + Vector2(-6, 9) if _station is Station4 else sourcePosition
		line.set_point_position(0, sourcePosition)
		line.set_point_position(1, t.global_position)

	update_action_hints()

	if isInsideStation or GameWorld.paused or disabled:
		%BuffedSprite.visible = false
		$MoveSound.stop()
		$CarryLoadSound.stop()
		pullCarry()
		return

	updateJetpackThrusterVisuals(move, moveDirectionInput.length() > 0.0, delta)

	var carrySize: = 0.0
	for i in range(1, carriedCarryables.size() + 1):
		if not is_instance_valid(carriedCarryables[i - 1]):
			continue
		carrySize += i / float(carriedCarryables[i - 1].carrierCount())

	moveSlowdown *= 1.0 - delta * Data.of(playerId + ".keeper1.slowdownRecovery") * 1.0

	var baseSpeed = currentSpeed()
	var desiredMove: Vector2 = moveDirectionInput * baseSpeed

	if abs(moveDirectionInput.x) < 0.1 and abs(moveDirectionInput.y) > 0.9:
		move.x *= 1 - delta * Data.of(playerId + ".keeper1.deceleration")
	if abs(moveDirectionInput.y) < 0.1 and abs(moveDirectionInput.x) > 0.9:
		move.y *= 1 - delta * Data.of(playerId + ".keeper1.deceleration")

	var moveChange = desiredMove * Data.of(playerId + ".keeper1.acceleration") * delta * max(0.1, 1.0 - moveSlowdown)
	moveChange = moveChange.limit_length(max(0, desiredMove.length() - move.length()))
	move = (move * (1 - delta * Data.of(playerId + ".keeper1.deceleration"))) + moveChange


	updateCarry()
	pullCarry()
	carrySlowdown = 0.01 * Data.of(playerId + ".keeper1.speedLossPerCarry") * carrySize

	var slowdown: = 1.0
	for c in carriedCarryables:
		slowdown *= 1.0 - (c.additionalSlowdown / c.carrierCount())

	var maxSpeed = baseSpeed * slowdown
	maxSpeed -= carrySlowdown * maxSpeed
	if externallyMoved:
		move *= 0
		moveDirectionInput *= 0
	move = move.limit_length(max(0, maxSpeed))

	var actualMove = position
	set_velocity(move)

	if is_multiplayer_authority():
		move_and_slide_custom()
	actualMove = position - actualMove


	if hitCooldown > 0:
		hitCooldown = max(hitCooldown - delta, 0)


	if is_multiplayer_authority() and moveDirectionInput.length() > 0.0 and hitCooldown <= 0 and not isMovementDummy:
		drill_check()

	if $CarryLoadSound.playing:
		$CarryLoadSound.baseVolume = min(-2, -30 + carrySlowdown * 50)

	var speedBuff = Data.of(playerId + ".keeper.speedBuff")
	var drillBuff = Data.of(playerId + ".keeper.drillBuff")
	%BuffedSprite.visible = speedBuff > 0 or drillBuff > 0

	trail_particles.emitting = moveDirectionInput.length() > 0 and hitCooldown <= 0.0 and spriteLockDuration <= 0.0
	trail_particles.process_material.direction = Vector3( - moveDirectionInput.x, - moveDirectionInput.y, 0)

	if spriteLockDuration > 0.0:
		spriteLockDuration -= delta
	else:
		var combinedMove = moveDirectionInput
		if actualMove.length() > 0.15:
			combinedMove += actualMove
		drill_sprite.hide()
		drill_sprite.stop()
		if combinedMove.length() < 0.35:
			keeper_sprite.play("default" + animationSuffix)
		else:
			if abs(combinedMove.x) > abs(combinedMove.y) * 0.95:
				keeper_sprite.play("left" + animationSuffix if combinedMove.x < 0 else "right" + animationSuffix)
			else:
				keeper_sprite.play("up" + animationSuffix if combinedMove.y < 0 else "down" + animationSuffix)
		if moveDirectionInput.length() == 0:
			moveStartSoundPlayBuffer = 0
			if $MoveSound.shouldPlay:
				moveStopSoundPlayBuffer += delta
				if moveStopSoundPlayBuffer >= 0.2:
					$MoveSound.stop()
					$CarryLoadSound.stop()
					$MoveStopSound.startSound()
					$StillSound.startSound()
					moveStopSoundPlayBuffer = 0
		else:
			moveStopSoundPlayBuffer = 0
			if not $MoveSound.shouldPlay:
				moveStartSoundPlayBuffer += delta
				if moveStartSoundPlayBuffer >= 0.1:
					$MoveSound.startSound()
					$CarryLoadSound.startSound()
					$MoveStartSound.startSound()
					$StillSound.stop()
					moveStartSoundPlayBuffer = 0



	updateInteractables()

func update_action_hints():
	pass





func updateCarry():
	var longest = 0
	for c in carriedCarryables.duplicate():
		if is_multiplayer_authority() and c.independent:
			dropCarry(c)
		elif multiplayer.is_server():
			var d = (position - c.position).length()
			if d > longest:
				longest = d
			if d > maxCarryLineLength:
				dropCarry(c)
				$CarryLineBreak.startSound()

	var breakThreshold = 0.7
	if longest > breakThreshold * maxCarryLineLength:
		if not $CarryLineStretch.playing:
			$CarryLineStretch.startSound()
		var pitch = (longest - breakThreshold * maxCarryLineLength) / ((1.0 - breakThreshold) * maxCarryLineLength)
		$CarryLineStretch.pitch_scale = 1 + ease(pitch, 0.6)
	else:
		$CarryLineStretch.stop()

func pullCarry():
	var strength: = 0.27
	for c in carriedCarryables:
		var dist = position - c.position

		if dist.length() < 12.0:
			dist *= 0.0
		else:
			dist -= dist.normalized() * 12
		if dist.y < 0:
			dist.y -= 2.0 * pow(1.0 + dist.length() / maxCarryLineLength, 4)

		var factor: = 1.0
		var off = dist.length() - 0.15 * maxCarryLineLength
		if off > 0:
			var fill = abs(off / (0.8 * maxCarryLineLength))
			if randf() < fill:
				factor = 10.0 * fill
		var impulse = (dist * strength * factor).limit_length(100)
		if c.is_multiplayer_authority():
			c.apply_central_impulse(impulse)
		strength = max(strength * 0.9, 0.005)

func attachCarry(body):
	_ensureFreeFromKunaiCarrier(body)
	Level.drops.network_pickup(body, playerId)

func _attachCarryInternal(body):
	if carriedCarryables.has(body):
		Logger.error("Tried to attach carryable " + body.name + " although it's already carried ")
		return
	body.unfocusCarry(self)
	body.dissolveCarryInfluence()
	var po = CarryablePhysicsOverride.new(self)
	po.linear_damp = 2
	po.angular_damp = 2
	body.addPhysicsOverride(po)
	carriedCarryables.append(body)
	body.setCarriedBy(self)
	$Pickup.startSound()

	var carryLine = preload("res://content/keeper/Carryline.tscn").instantiate()
	carryLine.add_point(position)
	carryLine.add_point(body.position)
	get_parent().add_child(carryLine)
	carryLines[body] = carryLine
	Style.init(carryLine)

	if not $CarryLine.playing:
		$CarryLine.startSound()

func _dropCarryInternal(body):
	if not carriedCarryables.has(body):
		Logger.error("keeper wants to drop carryable that isn't carried", "Keeper.dropCarry", {"carryable": body.name, "carry": str(carriedCarryables)})
		return
	carriedCarryables.erase(body)
	body.freeCarry(self)
	$Drop.startSound()


	var brk = Data.CARRYLINE_BREAK.instantiate()
	brk.global_position = global_position
	brk.target = body.global_position
	get_parent().add_child(brk)


	if carryLines.has(body):
		carryLines[body].queue_free()
	carryLines.erase(body)

	if carryLines.size() == 0:
		$CarryLine.stop()

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

		if not carriedCarryables.has(carryable)\
		and carryable.canFocusCarry(teamId)\
		and (pickupType == "" or pickupType == carryable.carryableType)\
		and ( not carryable.is_in_group("usables") or usables.has(carryable.get_meta("usable"))):

			potentialCarryables.append(carryable)

	potentialCarryables.sort_custom(Callable(self, "sortByDistance"))


	for carryable in potentialCarryables:
		if focussedCarryable == carryable:
			return
		else:
			if focussedCarryable:
				focussedCarryable.unfocusCarry(self)
			focussedCarryable = carryable
			focussedCarryable.focusCarry(self)
		return

func pickupHit():
	if isInsideStation or disabled:
		return false

	updateCarryables()
	if focussedCarryable:
		pickup(focussedCarryable)

func pickupHold():
	if isInsideStation or disabled:
		return false

	updateCarryables()
	if focussedCarryable:
		pickup(focussedCarryable)
		pickupType = focussedCarryable.carryableType

func pickupHoldStopped():
	pickupType = ""

func dropHit():
	if isInsideStation or disabled:
		return

	var farthestDrop
	var distance: = 0.0
	for c in carriedCarryables:
		var dist = (c.global_position - global_position).length()
		if dist > distance:
			distance = dist
			farthestDrop = c
	if farthestDrop:
		dropCarry(farthestDrop)
		return true

func dropHold():
	if isInsideStation or disabled:
		return

	if carriedCarryables.size() > 0:
		var drop = carriedCarryables.front()
		dropCarry(drop)

func pickup(drop):
	attachCarry(drop)

func currentSpeed() -> float:
	var s = Data.of(playerId + ".keeper1.maxSpeed")
	s += Data.ofOr(playerId + ".keeper.speedBuff", 0)
	var yMove = move.normalized().y
	s += Data.ofOr(playerId + ".keeper.additionalupwardsspeed", 0) * abs(yMove)
	return s

func drill_check() -> void :
	drill_hit_test_ray.rotation = moveDirectionInput.angle()

	drill_hit_test_ray.force_raycast_update()
	var tile = drill_hit_test_ray.get_collider()

	if not tile or not tile.has_meta("destructable"):
		return
	if not tile.get_meta("destructable"):
		if Data.of(playerId + ".keeper1.destroyindestructibletiles"):
			if not Level.map.isWithinBounds(tile.coord):
				return
		else:
			return


	synchronizer.network_rpc(play_drill_anim.bind(drill_hit_test_ray.rotation + PI, tile.coord), true)

	var hits_needed_to_destroy: float = float(tile.max_health) / float(Data.of(playerId + ".keeper1.drillStrength"))
	synchronizer.network_rpc(emit_sparks.bind(drill_hit_test_ray.get_collision_point(), tile.coord, hits_needed_to_destroy, drill_hit_test_ray.rotation + PI), true)

	var dir = global_position - tile.global_position
	var drillStrength = Data.of(playerId + ".keeper1.drillStrength")
	if tile.hardness >= 3:
		var tilehardnessmodifier = Data.ofOr(playerId + ".keeper1.hardtilesmodifier", 1.0)
		drillStrength *= tilehardnessmodifier
	tile.hit(dir, drillStrength, teamId, techId)
	emit_signal("mined", 0.1)

	if Options.shakeDrill:
		InputSystem.shakeTarget(self, 20, 0.2, 8)

	var knockback = Data.of(playerId + ".keeper1.acceleration") * Data.of(playerId + ".keeper1.tileKnockback")
	hitCooldown = Data.of(playerId + ".keeper1.tileHitCooldown")
	var drillbuff = 1.0 - float(Data.of(playerId + ".keeper.drillBuff"))

	moveSlowdown = 0.25 + currentSpeed() * 0.01
	if drillbuff < 1.0:
		hitCooldown = max(hitCooldown * drillbuff, 0.017)
		knockback *= drillbuff
	if abs(dir.x) > abs(dir.y):
		move.x = sign(dir.x) * knockback
		move.y *= 0.1
	else:
		move.y = sign(dir.y) * knockback
		move.x *= 0.1

	tileHit.emit()

@rpc("reliable")
func play_drill_anim(_rotation: float, tileCoord: Vector2):
	if not Level.map.tiles.has(tileCoord):
		return
	var tile = Level.map.tiles[tileCoord]

	var drillbuff: = 1.0 - float(Data.of(playerId + ".keeper.drillBuff"))
	spriteLockDuration = Data.of(playerId + ".keeper1.tileHitCooldown")
	if drillbuff < 1.0:
		spriteLockDuration *= drillbuff

	$TileHitSounds.hit(tile, drillbuff < 1.0, true)

	drill_sprite.show()
	drill_sprite.frame = 0
	var infix: String = "_big" if Data.of(playerId + ".keeper1.destroyindestructibletiles") else ""
	drill_sprite.play("drill" + infix + animationSuffix)
	drill_sprite.rotation = _rotation

	var anim_name: = ""
	if abs(moveDirectionInput.x) > abs(moveDirectionInput.y):
		anim_name = "drill_right" if moveDirectionInput.x > 0 else "drill_left"
	else:
		anim_name = "down" if moveDirectionInput.y > 0 else "up"

	keeper_sprite.play(anim_name + animationSuffix)


@rpc("reliable")
func emit_sparks(hit_position: Vector2, tileCoord: Vector2, hits_needed_to_destroy: float, _rotation: float):
	if not Level.map.tiles.has(tileCoord):
		return
	var tile = Level.map.tiles[tileCoord]
	var tile_type = tile.type
	drill_hit.position = to_local(hit_position) * 1.5
	drill_hit.rotation = _rotation
	drill_hit.frame = 0
	drill_hit.play("hit")
	var particle_amount = int(round(remap(clamp(hits_needed_to_destroy, 1.0, 8.0), 1, 8, 60, 10)))
	drill_hit_particles.amount = particle_amount
	drill_hit_particles.restart()


	var spark_amount = int(round(remap(clamp(hits_needed_to_destroy, 1.0, 8.0), 1, 8, 20, 3)))
	var random_amount: = 3
	if Options.reducedParticles:
		spark_amount = clamp(spark_amount - 1, 2, 5)
		random_amount = 1
	for _i in range(spark_amount + randi() % random_amount):
		var s = Data.KEEPER_SPARK.instantiate()
		s.global_position = hit_position
		s.apply_central_impulse(Vector2.RIGHT.rotated(drill_hit.rotation + randf_range(-0.4, 0.4)) * randf_range(30, 150))
		get_parent().call_deferred("add_child", s)

	var dirt_color = Level.map.getBiomeColorByCoord(tile.coord)

	var dirt_amount = int(round(remap(clamp(hits_needed_to_destroy, 1.0, 8.0), 1, 8, 5, 0)))
	for _i in range(dirt_amount + randi() % 2):
		var t = Data.TILE_DIRT_PARTICLE.instantiate()
		t.modulate = dirt_color
		t.type = tile_type
		t.global_position = hit_position
		t.apply_central_impulse(Vector2.RIGHT.rotated(drill_hit.rotation + randf_range(-0.7, 0.7)) * randf_range(60, 130))
		get_parent().call_deferred("add_child", t)

func setJetpackStage(stage: int):
	trail_particles.amount = 20 + stage * 8
	trail_particles.process_material.initial_velocity_min = 12 + stage * 1
	trail_particles.process_material.initial_velocity_max = 12 + stage * 1

func updateJetpackThrusterVisuals(_dir: Vector2, _is_moving: bool, delta: float) -> void :
	var target_angle_l: Vector3
	var target_angle_r: Vector3
	var target_vel: float
	var lerp_speed: float

	if not _is_moving:
		thruster_left_boost.animation = "idle"
		thruster_right_boost.animation = "idle"
		lerp_speed = 7.0
		target_vel = THRUSTER_IDLE_VEL
		target_angle_l = THRUSTER_IDLE_DIR_L
		target_angle_r = THRUSTER_IDLE_DIR_R
	else:
		thruster_left_boost.animation = "boosting"
		thruster_right_boost.animation = "boosting"
		lerp_speed = 12.0
		target_angle_l = - Vector3(_dir.x, _dir.y, 0).normalized()
		target_angle_r = target_angle_l
		target_vel = _dir.length() + THRUSTER_IDLE_VEL

	thruster_left_material.direction = lerp(thruster_left_material.direction, target_angle_l, lerp_speed * delta).normalized()
	thruster_right_material.direction = lerp(thruster_right_material.direction, target_angle_r, lerp_speed * delta).normalized()
	thruster_left_material.initial_velocity_min = lerp(thruster_left_material.initial_velocity_min, target_vel, lerp_speed * delta)
	thruster_left_material.initial_velocity_max = lerp(thruster_left_material.initial_velocity_max, target_vel, lerp_speed * delta)
	thruster_right_material.initial_velocity_min = lerp(thruster_right_material.initial_velocity_min, target_vel, lerp_speed * delta)
	thruster_right_material.initial_velocity_max = lerp(thruster_right_material.initial_velocity_max, target_vel, lerp_speed * delta)

func disableEffects():
	thruster_left.emitting = false
	thruster_right.emitting = false
	thruster_left_boost.visible = false
	thruster_right_boost.visible = false
	$StillSound.stop()

func enableEffects():
	thruster_left.emitting = true
	thruster_right.emitting = true
	thruster_left_boost.visible = true
	thruster_right_boost.visible = true
	$StillSound.startSound()


func getCarrySlowdown() -> float:
	return carrySlowdown

func kill():
	for c in carryLines.values():
		c.queue_free()
	carryLines.clear()
	super.kill()

func as_movement_dummy():
	isMovementDummy = true
	$Visuals.visible = false
	$DrillHitTestRay.enabled = false
	$CarryArea.monitoring = false
	for c in get_children():
		if c is Sound:
			c.baseVolume = -100
	set_collision_layer_value(CONST.LAYER_PLAYER, false)
