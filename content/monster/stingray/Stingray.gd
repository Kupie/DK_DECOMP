class_name Stingray
extends "res://content/monster/Monster.gd"

signal move_finished

const delayBetweenShots = 0.0
const CURVE_ROTATION_RADIANS: = 0.5
const CURVE_ROTATION_STRENGTH: = 50

enum Phase{GROW, SHOOT, SHRINK, MOVE, DIE, WAIT}

var phase: int = Phase.MOVE

var remainingShots: = 0

var nextSide: String
var movePointProvider
var projetileTargetProvider
var currentMoveCurve: Curve2D

var entering: = true
var pathProgress: = 0.0

var targetPos: Vector2
var rotRandom: float
var dirRandom: float
var randomShotPositions: Array[Vector2]
var hasNetworkData: = false

var line: Line2D
var _variant: String

var _createdDueToFullSync: bool = false
var _moveTell: float = 0.0

func setProviders(movePointProvider, projetileTargetProvider, side: String):
	self.movePointProvider = movePointProvider
	self.projetileTargetProvider = projetileTargetProvider
	nextSide = side
	currentMoveCurve = Curve2D.new()

func init():
	if _createdDueToFullSync:
		if phase == Phase.MOVE:
			var pathLength = currentMoveCurve.get_baked_length()
			var duration = pathLength / (Data.of("stingray.speed") * speedModifier)
			moveTween.interpolate_property(self, "pathProgress", pathProgress, pathLength, duration - _moveTell, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
			moveTween.start()
		return
	supports_full_sync = true
	match phase:
		Phase.MOVE:
			animation("fly")
			createNextPath()
			createMoveTween()
		Phase.SHOOT:
			createNextPath()
			animation("shoot")
		Phase.GROW:
			grow()
		Phase.SHRINK:
			shrink()

	hasNetworkData = false

func createNextPath():
	var direction = (targetPos - position).normalized()
	var rot: = direction.rotated(PI * 0.5 * CURVE_ROTATION_RADIANS - PI * CURVE_ROTATION_RADIANS * rotRandom) * CURVE_ROTATION_STRENGTH
	var targetRotatedDirection: = direction.rotated(PI * (1 + CURVE_ROTATION_RADIANS * 0.5) - PI * CURVE_ROTATION_RADIANS * dirRandom) * CURVE_ROTATION_STRENGTH

	currentMoveCurve.clear_points()
	currentMoveCurve.add_point(position, Vector2.ZERO, rot)
	currentMoveCurve.add_point(targetPos, targetRotatedDirection)

func prepareMoveData() -> void :

	nextSide = Utils.get_other_side(nextSide)
	targetPos = movePointProvider.assignRandomPoint(nextSide + "_low", self).global_position
	rotRandom = randf()
	dirRandom = randf()

	remainingShots = Data.stabilizedRandomInt(Data.of("stingray.minshots"), Data.of("stingray.maxshots"), "stingrayshots", 4)
	randomShotPositions.clear()
	for i: int in range(remainingShots):
		var randomShotPosition = projetileTargetProvider.getRandom(targetPos) + Vector2(8 - randi() % 16, 8 - randi() % 16)
		randomShotPositions.append(randomShotPosition)

func startMove():
	pathProgress = 0
	animation("fly")
	createNextPath()
	createMoveTween()
	phase = Phase.MOVE
	hasNetworkData = false
	$Sprite2D.speed_scale = speedModifier

func createMoveTween():
	var pathLength = currentMoveCurve.get_baked_length()
	var duration = pathLength / (Data.of("stingray.speed") * speedModifier)
	moveTween.interpolate_property(self, "pathProgress", 0, pathLength, duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	moveTween.start()

func subProcess(delta):
	match phase:
		Phase.MOVE:
			var pathLength = currentMoveCurve.get_baked_length()
			var newPos = currentMoveCurve.sample_baked(pathProgress)
			var moveDelta = position - newPos
			if pathProgress > 0.0 and moveDelta.length() > 0:
				setFlip(moveDelta.x > 0)
				$Sprite2D.rotation = moveDelta.angle()
				if not $Sprite2D.flip_h:
					$Sprite2D.rotation += PI

				$Sprite2D.speed_scale *= 1.0 + 0.2 * moveDelta.length()
			position = newPos
			if pathProgress >= pathLength - 10:
				animation("grow")
			if pathProgress >= pathLength:
				grow()
				emit_signal("move_finished")
				$Sprite2D.rotation = 0
		Phase.SHOOT:
			pass
		Phase.SHRINK:
			pass
		Phase.GROW:
			pass
		Phase.WAIT:
			if hasNetworkData:
				startMove()

func leave(delta: float):
	position.y -= delta * 50
	position.x += delta * position.x * 0.1

func onGameLost():
	if currentHealth > 0:
		leaving = true
		animation("idle")

func handleFullStun():
	animation("hit")

func stagger():
	animation("hit")

func resumeAfterStagger():
	if phase != Phase.MOVE:
		shrink()
	else:
		animation("fly")

func spawnShot():
	var p = preload("res://content/monster/flyer/FlyerProjectile.tscn").instantiate()
	p.teamId = teamId
	p.damageSource = damageSource
	p.position = position + $ProjectilePosition.position
	p.origin = position

	var targetShotPosition: = randomShotPositions[remainingShots - 1]
	p.target = targetShotPosition
	p.damage = Data.of("stingray.damage") * damageModifier
	p.speed = Data.of("stingray.shotspeed")
	get_parent().add_child(p)
	$ShootSound.startSound()
	remainingShots -= 1

func shrink():
	animation("shrink")
	$ShrinkSound.startSound()
	phase = Phase.SHRINK

func grow():
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)
	$AppearSound.startSound()
	phase = Phase.GROW

func startShoot():
	phase = Phase.SHOOT
	updateShoot()

func updateShoot():
	if remainingShots > 0:
		animation("shoot" + str(1 + randi() % 3))
		$Sprite2D.frame = 0
	else:
		shrink()

func animateDeath():
	$DieSound.startSound()
	animation("die")
	phase = Phase.DIE

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.animation.begins_with("shoot"):
		updateShoot()
	elif $Sprite2D.animation == "die":
		super.removeFreeBlocker()
	elif $Sprite2D.animation == "shrink":
		if multiplayer.is_server():
			prepareMoveData()
			startMove()
			sendMoveData()
		elif hasNetworkData:
			startMove()
		else:
			animation("fly")
			phase = Phase.WAIT
	elif $Sprite2D.animation == "grow":
		animation("idle")
		entering = false
	elif $Sprite2D.animation == "idle" and not leaving:
		startShoot()

func _on_Sprite_frame_changed():
	match $Sprite2D.animation:
		"shoot1":
			if $Sprite2D.frame == 3:
				spawnShot()
		"shoot2":
			if $Sprite2D.frame == 3:
				spawnShot()
		"shoot3":
			if $Sprite2D.frame == 3:
				spawnShot()

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	var movePointProvider = Level.worldsByTeamId[teamId].getFlyerPathProvider()
	var projectileTargetProvider = Level.domesByTeamId[teamId].getProjectileTargetProvider()

	stream.encode_bool(Utils.get_side_bool_from_string(variant))

	var spawnType: String = Data.of("stingray.spawnpoint") + "_" + variant
	var spawnPosition: Vector2 = movePointProvider.getSpawn(spawnType).global_position
	stream.encode_vector2(spawnPosition)

	var nextSide: = variant
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))

	var nextSideHeight: = nextSide + "_low"
	var point: Marker2D = Level.worldsByTeamId[teamId].getFlyerPathProvider().getRandomPoint(nextSideHeight)
	var targetPos: Vector2 = point.global_position
	stream.encode_vector2(targetPos)
	stream.encode_u8(Level.worldsByTeamId[teamId].getFlyerPathProvider().getPointIndex(point, nextSideHeight))



	stream.encode_float(randf())

	stream.encode_float(randf())

	var remainingShots: int = Data.stabilizedRandomInt(Data.of("stingray.minshots"), Data.of("stingray.maxshots"), "stingrayshots", 4)
	stream.encode_u8(remainingShots)
	for i in range(remainingShots):
		var randomShotPosition = projectileTargetProvider.getRandom(targetPos) + Vector2(8 - randi() % 16, 8 - randi() % 16)
		stream.encode_vector2(randomShotPosition)

	return stream.data

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)


	_variant = Utils.get_side_string_from_bool(stream.decode_bool())

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), Level.domesByTeamId[teamId].getProjectileTargetProvider(), _variant)

	position = stream.decode_vector2()
	nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
	targetPos = stream.decode_vector2()

	var pointIndex = stream.decode_u8()
	rotRandom = stream.decode_float()
	dirRandom = stream.decode_float()
	remainingShots = stream.decode_u8()
	randomShotPositions.clear()
	for i: int in range(remainingShots):
		randomShotPositions.append(stream.decode_vector2())

	hasNetworkData = true

	movePointProvider.assignPointOccupation(movePointProvider.getPoint(pointIndex, nextSide + "_low"), self)

func sendMoveData() -> void :
	var stream: = PackedByteStream.new()
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))
	stream.encode_vector2(targetPos)
	stream.encode_float(rotRandom)
	stream.encode_float(dirRandom)

	stream.encode_u8(remainingShots)
	for i: int in range(remainingShots):
		stream.encode_vector2(randomShotPositions[i])

	networkPhaseChanged.emit(Phase.MOVE, stream.data)

func remote_set_phase(_phase: int, buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	match _phase:
		Phase.MOVE:
			nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
			targetPos = stream.decode_vector2()
			rotRandom = stream.decode_float()
			dirRandom = stream.decode_float()
			hasNetworkData = true
			remainingShots = stream.decode_u8()
			randomShotPositions.clear()
			for i: int in range(remainingShots):
				randomShotPositions.append(stream.decode_vector2())
		_:
			push_error("Stingray only supports setting move phase remotely")


	if phase == Phase.WAIT:
		startMove()

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_u8(phase)
	stream.encode_s32(remainingShots)
	stream.encode_bool(Utils.get_side_bool_from_string(_variant))
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))
	_encode_curve2D(stream, currentMoveCurve)
	stream.encode_bool(entering)
	stream.encode_float(pathProgress)
	stream.encode_vector2(targetPos)
	stream.encode_float(rotRandom)
	stream.encode_float(dirRandom)
	stream.encode_u8(randomShotPositions.size())
	for pos in randomShotPositions:
		stream.encode_vector2(pos)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	stream.encode_float(moveTween.tell())
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	phase = stream.decode_u8()
	remainingShots = stream.decode_s32()
	_variant = Utils.get_side_string_from_bool(stream.decode_bool())
	nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
	var hostMoveCurve: = Curve2D.new()
	_decode_curve2D(stream, hostMoveCurve)
	entering = stream.decode_bool()
	pathProgress = stream.decode_float()
	targetPos = stream.decode_vector2()
	rotRandom = stream.decode_float()
	dirRandom = stream.decode_float()
	var count: = stream.decode_u8()
	randomShotPositions.clear()
	for i in count:
		randomShotPositions.append(stream.decode_vector2())
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	Utils.decode_animated_sprite2d_state(stream, sprite)
	_moveTell = stream.decode_float()

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), \
	Level.domesByTeamId[teamId].getProjectileTargetProvider(), _variant)
	currentMoveCurve = hostMoveCurve
