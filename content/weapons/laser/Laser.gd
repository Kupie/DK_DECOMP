class_name LaserWeapon
extends PrimaryWeapon

var remotePosition: float

var move: Vector2

var inverse: = false
var skipFrame: = false
var inputReady: = false

var firing: = false
var hitState: = 0
var laser: Laser

var currentSpeed: = 0.0
var distanceMoved: = 0.0
var acceleration: = 0.0

var animation: String
var frame: = 0.0

var variant: = 0

var pathProbe

const FRAME_SHOOT_START: = 24
const FRAME_MOVE_START: = 12
const FRAME_COUNT: = 3

const LASER_MAX_LENGTH = 600.0
const DELTA_DATA_SIZE: int = 5

@onready var SpriteCannon = find_child("SpriteCannon")
@onready var SpriteBack = find_child("SpriteBack")

var raycasts: Array

func init(cupulaPath: Path2D):
	Style.init(self)
	raycasts = [$RayCast2D, $RayCastL1, $RayCastR1, $RayCastR2, $RayCastL2, $RayCastL3, $RayCastR3]
	for r in raycasts:
		r.enabled = false
	$RayCast2D.enabled = true



	$AimLine.visible = false


	SpriteCannon.play("stopped_" + str(variant))

	pathProbe = cupulaPath.createPathProbe(self)

	Data.listen(self, teamId + ".laser.variant", true)
	Data.listen(self, teamId + ".laser.hitprojectiles", true)
	Data.listen(self, teamId + ".laser.bend", true)

	Style.init(self)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".laser.variant":
		setLaserVariant(newValue)
	elif property == teamId + ".laser.hitprojectiles":
		if newValue:
			$RayCast2D.set_collision_mask_value(CONST.LAYER_MONSTER_PROJECTILES, true)
	elif property == teamId + ".laser.bend":
		for r in raycasts:
			r.enabled = r.enabled or newValue

func get_delta_data() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.resize(DELTA_DATA_SIZE)
	remotePosition = pathProbe.progress_ratio
	stream.encode_float(remotePosition)
	stream.encode_bool(firing)
	return stream.data

func set_delta_data(buffer: PackedByteArray) -> void :
	if buffer.size() != DELTA_DATA_SIZE:
		return

	var stream: = PackedByteStream.from_bytes(buffer)
	remotePosition = stream.decode_float()
	var nowFiring: = stream.decode_bool()

	if nowFiring != firing:
		if nowFiring:
			startFiring()
			startFiringAnimation()
		else:
			stopFiring()
			stopFiringAnimation()

func setLaserVariant(variant: int):
	if laser:
		laser.queue_free()

	variant = clamp(variant, 0, 4)

	var variation_path: String = "res://content/weapons/laser/laser_variations/laser" + str(variant) + ".tscn"
	laser = load(variation_path).instantiate()
	$LaserStart.add_child(laser)
	laser.visible = false

	self.variant = variant
	match int(variant):
		0:
			$SpriteBase.texture = preload("res://content/weapons/laser/laserbase_small_sheet.png")
			SpriteBack.texture = preload("res://content/weapons/laser/laser_small_bottomextension.png")
			SpriteBack.position.y = 6
			$SpriteBase.position.y = -5.5
			$SpriteBase / SpriteCannon.offset.y = 0
		1:
			$SpriteBase.texture = preload("res://content/weapons/laser/laserbase_small_mid_sheet.png")
			SpriteBack.texture = preload("res://content/weapons/laser/laser_bottomextension.png")
			SpriteBack.position.y = 10
			$SpriteBase.position.y = -6.5
			$SpriteBase / SpriteCannon.offset.y = -5
		2:
			$SpriteBase.texture = preload("res://content/weapons/laser/laserbase_sheet.png")
			SpriteBack.texture = preload("res://content/weapons/laser/laser_bottomextension.png")
			SpriteBack.position.y = 10
			$SpriteBase.position.y = -8.5
			$SpriteBase / SpriteCannon.offset.y = 0
		3:
			$SpriteBase.texture = preload("res://content/weapons/laser/laserbase_midbig_sheet.png")
			SpriteBack.texture = preload("res://content/weapons/laser/laser_big_bottomextension.png")
			SpriteBack.position.y = 13
			$SpriteBase.position.y = -12.5
			$SpriteBase / SpriteCannon.offset.y = 0
		4:
			$SpriteBase.texture = preload("res://content/weapons/laser/laserbase_big_sheet.png")
			SpriteBack.texture = preload("res://content/weapons/laser/laser_big_bottomextension.png")
			SpriteBack.position.y = 13
			$SpriteBase.position.y = -12.5
			$SpriteBase / SpriteCannon.offset.y = 0

	var c = $SpriteBase / SpriteCannon
	c.play(c.animation.substr(0, c.animation.find("_") + 1) + str(variant))

func inputs(moveValue: Vector2, fireValue: float, specialValue: float, mouseGlobal: Vector2 = Vector2()):
	if GameWorld.paused or not inputReady:
		return

	if not is_multiplayer_authority():
		return

	var hasMouseMovement: bool = not mouseGlobal.is_zero_approx()
	if Options.useMouseDomeGameplay and not Options.useGamepad(deviceId) and not showcaseMode and hasMouseMovement:
		if inverse:
			var domePos: Vector2 = Utils.get_dome_position(teamId)
			var deltaFromDomeToMouse: Vector2 = mouseGlobal - domePos
			var mirrowedGlobalMousePos: Vector2 = domePos - deltaFromDomeToMouse
			mouseGlobal.x = mirrowedGlobalMousePos.x
		var aimVector: Vector2 = mouseGlobal - global_position
		var angleDiff = aimVector.angle() - (rotation - CONST.PI_HALF)
		if angleDiff > PI:
			angleDiff -= 2 * PI
		elif angleDiff < - PI:
			angleDiff += 2 * PI

		if aimVector.x < 0 and angleDiff > CONST.PI_HALF:
			angleDiff -= 2 * PI
		elif aimVector.x > 0 and angleDiff < - CONST.PI_HALF:
			angleDiff += 2 * PI

		var newMove = clamp(angleDiff * 4, -1, 1)
		if newMove != 0 and sign(newMove) != sign(move.x):

			currentSpeed = 0
		move.x = newMove
	else:
		if inverse:
			moveValue.x = - moveValue.x
		move.x = moveValue.x

	if GameWorld.paused or not inputReady:
		return

	if fireValue > 0.0:

		if not firing:
			startFiring()
			startFiringAnimation()
	else:
		stopFiring()
		stopFiringAnimation()

func getMouseViewportPosition() -> Vector2:
	return Vector2()


func _physics_process(delta):
	if GameWorld.paused:
		return

	if not inputReady and is_multiplayer_authority():
		return

	var thisMove: float

	if is_multiplayer_authority():
		var laserMoveSpeed = Data.of(teamId + ".laser.movespeed") * Data.of(teamId + ".laser.movespeedmod")
		if abs(move.x) <= 0.01:
			distanceMoved = 0
			$MoveSound.stop()
			currentSpeed = 0
			acceleration = 0

		else:

			if not $MoveSound.playing:
				$MoveSound.startSound()
			acceleration = clamp(acceleration + (10.0 - 13.0 * laserMoveSpeed) * delta, 0.0, 1.0)

		var goalSpeed = laserMoveSpeed * move.x

		if firing:
			goalSpeed *= Data.of(teamId + ".laser.movespeedwhilefiring")
		if Options.useGamepad(deviceId):
			currentSpeed = goalSpeed
		else:
			currentSpeed += (goalSpeed - currentSpeed) * delta * 8.0 * acceleration
		$MoveSound.pitch_scale = 0.45 + abs(currentSpeed) * 0.5
		thisMove = pathProbe.moveBy(currentSpeed * delta)
		distanceMoved += abs(thisMove)
		remotePosition = pathProbe.progress_ratio
	else:
		if is_equal_approx(remotePosition, pathProbe.progress_ratio):
			distanceMoved = 0
			$MoveSound.stop()
			currentSpeed = 0
			acceleration = 0
		else:
			if not $MoveSound.playing:
				$MoveSound.startSound()

		thisMove = pathProbe.moveTo(remotePosition)
		distanceMoved += abs(thisMove)


	var c
	var collisionPoint: Vector2
	var laserEndPos: = Vector2(0, -1) * LASER_MAX_LENGTH
	var angleDelta: = 0.0
	for raycast in raycasts:
		if not raycast.enabled:
			continue
		var c2 = raycast.get_collider()
		if c2:
			c = c2
			collisionPoint = raycast.get_collision_point()
			angleDelta = (collisionPoint - $RayCast2D.global_position).angle() - rotation + CONST.PI_HALF
			if angleDelta > PI:
				angleDelta -= 2 * PI
			elif angleDelta < - PI:
				angleDelta += 2 * PI
			laserEndPos = Vector2(0, -1) * ((collisionPoint - global_position).length() + 5)
			break

	if inputReady and laser and Data.of(teamId + ".laser.aimLine"):
		$AimLine.visible = not firing
		if c and c.is_in_group("monster"):
			c.aim()
		$AimLine.set_point_position(1, laserEndPos)

	if firing:
		if c:
			if c.is_in_group("monster"):

				laser.rotation += (angleDelta - laser.rotation) * delta * 5.0
				laser.target(laserEndPos)
				laser.start_hit(laserEndPos)
				if c.currentHealth >= 5:
					laser.playHitBumpSound()

				var damage = Data.of(teamId + ".laser.dps") * Data.of(teamId + ".laser.dpsmod") * (1.0 / 60.0)
				hitMonster(c, "laser", damage, Data.of(teamId + ".laser.stun"))






				hitState = 1
			elif Data.of(teamId + ".laser.hitprojectiles") and c.is_in_group("projectile"):
				c.domeAbsorbsDamage()
		elif hitState >= 1:
			hitState -= 1
		elif hitState == 0:
			laser.rotation = 0
			hitState = -1

			laser.stop_hit()
			$AimLine.set_point_position(1, Vector2(0, -1) * LASER_MAX_LENGTH)
			laserEndPos = Vector2(0, -1) * LASER_MAX_LENGTH
			laser.target(laserEndPos)

	if SpriteCannon.animation.begins_with("shoot_" + str(variant)):
		frame += thisMove * 3000.0 * delta
		if frame < FRAME_SHOOT_START:
			frame += FRAME_COUNT
		elif frame > FRAME_SHOOT_START + FRAME_COUNT:
			frame -= FRAME_COUNT
	elif SpriteCannon.animation.begins_with("idle_" + str(variant)):
		frame += thisMove * 3000.0 * delta
		if frame < FRAME_MOVE_START:
			frame += FRAME_COUNT
		elif frame > FRAME_MOVE_START + FRAME_COUNT:
			frame -= FRAME_COUNT
	$SpriteBase.frame = clamp(int(frame), 0, 41)

	if skipFrame:
		skipFrame = false
		return


	if firing:
		laser.visible = true

func startFiring():
	skipFrame = not firing
	firing = true
	laser.start()
	laser.set_endpoint(Vector2.ZERO)
	laser.stop_hit()

func startFiringAnimation():
	if SpriteCannon.animation.begins_with("idle"):
		setFrame(FRAME_SHOOT_START + fmod(frame, FRAME_MOVE_START))
	SpriteCannon.play("shoot_" + str(variant))


func stopFiring():
	if firing:
		laser.stop()
		var end = (laser.get_endpoint() - laser.position).length()
		var amount = round(75 * (end / 300.0))
		if amount > 0:
			var particles = preload("res://content/weapons/laser/RayParticles.tscn").instantiate()
			particles.process_material.emission_box_extents.y = end * 0.5
			particles.position.y = -0.5 * end
			particles.amount = amount
			add_child(particles)
		if Data.of(teamId + ".laser.aimLine"):
			$AimLine.visible = true
		hitState = 0
	firing = false

func stopFiringAnimation():
	if SpriteCannon.animation.begins_with("shoot"):
		setFrame(FRAME_MOVE_START + fmod(frame, FRAME_SHOOT_START))
	SpriteCannon.play("idle_" + str(variant))

func start():
	started = true
	if Data.of(teamId + ".laser.aimLine"):
		$AimLine.visible = true
	animation = "start"
	SpriteCannon.frame = 0
	SpriteCannon.play("start_" + str(variant))
	setFrame(FRAME_MOVE_START)

func stop():
	started = false
	animation = "stop"
	if SpriteCannon.animation.begins_with("shoot"):
		SpriteCannon.play("stopped_" + str(variant))
	else:
		SpriteCannon.play("stop_" + str(variant))
	stopFiring()
	if Data.of(teamId + ".laser.aimLine"):
		$AimLine.visible = false
	setFrame(FRAME_MOVE_START)
	inputReady = false
	distanceMoved = 0
	$MoveSound.stop()

	$Tween.interpolate_callback($MoveSound, 0.1, "stop")
	$Tween.start()
	laser.stop_hit()

func setFrame(f: float):
	frame = f
	$SpriteBase.frame = int(f)

func _on_SpriteCannon_animation_finished():
	if SpriteCannon.animation.begins_with("start"):
		SpriteCannon.play("idle_" + str(variant))
		inputReady = true

func getFireName():
	return "level.station.battle.navbar.shoot"

func getSpecialName():
	return ""

func remove():
	pathProbe.queue_free()
	super.remove()
