class_name Flyer
extends Monster

signal move_finished

const delayBetweenShots = 0.0

enum Phase{GROW, SHOOT, SHRINK, MOVE, DIE, WAIT}

var phase: int = Phase.MOVE

var remainingShots: = 0

var nextSide: String
var movePointProvider
var projetileTargetProvider
var currentMoveCurve: Curve2D

var applyInRotation: = false
var drawMovementLine: = false
var pathProgress: = 0.0
var curveRotationRadians: = 0.75
var curveRotationStrength: = 150

var targetPos: Vector2
var rotRandom: float
var dirRandom: float
var randomShotPositions: Array[Vector2]
var hasNetworkData: = false

var cooldown: = 0.0

func setProviders(movePointProvider, projetileTargetProvider, side: String):
	self.movePointProvider = movePointProvider
	self.projetileTargetProvider = projetileTargetProvider
	nextSide = side
	currentMoveCurve = Curve2D.new()

func init():
	supports_full_sync = true
	applyInRotation = true
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

	setHittable(phase == Phase.SHOOT)

func createNextPath():
	var direction = (targetPos - position).normalized()
	var rot: = direction.rotated(PI * 0.5 * curveRotationRadians - PI * curveRotationRadians * rotRandom) * curveRotationStrength if applyInRotation else Vector2.ZERO
	var targetRotatedDirection: = direction.rotated(PI * (1 + curveRotationRadians * 0.5) - PI * curveRotationRadians * dirRandom) * curveRotationStrength

	currentMoveCurve.clear_points()
	currentMoveCurve.add_point(position, Vector2.ZERO, rot)
	currentMoveCurve.add_point(targetPos, targetRotatedDirection)

func prepareMoveData() -> void :

	nextSide = Utils.get_other_side(nextSide)
	targetPos = movePointProvider.assignRandomPoint(nextSide, self).global_position
	rotRandom = randf()
	dirRandom = randf()

	remainingShots = Data.stabilizedRandomInt(Data.of("flyer.minshots"), Data.of("flyer.maxshots"), "flyershots", 5)
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

func createMoveTween():
	var pathLength = currentMoveCurve.get_baked_length()
	var duration = pathLength / Data.of("flyer.speed")
	moveTween.interpolate_property(self, "pathProgress", 0, pathLength, duration, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	moveTween.start()

func subProcess(delta):
	if cooldown > 0.0:
		cooldown -= delta
		return

	match phase:
		Phase.MOVE:
			var pathLength = currentMoveCurve.get_baked_length()
			var newPos = currentMoveCurve.sample_baked(pathProgress)
			setFlip(position.x - newPos.x > 0)
			position = newPos
			$Sprite2D.speed_scale = speedModifier
			if pathProgress >= pathLength:
				grow()
				emit_signal("move_finished")
		Phase.SHOOT:
			$Sprite2D.speed_scale = stunLevel() * speedModifier
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
		animation("fly")

func handleFullStun():
	animation("hit")

func stagger():
	if phase != Phase.MOVE:
		animation("hit")

func resumeAfterStagger():
	if phase != Phase.MOVE:
		shrink()

func spawnShot():
	var p = preload("res://content/monster/flyer/FlyerProjectile.tscn").instantiate()
	p.teamId = teamId
	p.damageSource = damageSource
	p.position = position + $ProjectilePosition.position
	p.origin = position

	var targetShotPosition: = randomShotPositions[remainingShots - 1]
	p.target = targetShotPosition
	p.damage = Data.of("flyer.damage") * damageModifier
	p.speed = Data.of("flyer.shotspeed")
	get_parent().add_child(p)
	$ShootSound.startSound()
	remainingShots -= 1

func shrink():
	animation("shrink")
	$ShrinkSound.startSound()
	phase = Phase.SHRINK

func grow():
	animation("grow")
	setFlip(position.x > projetileTargetProvider.global_position.x)
	$AppearSound.startSound()
	phase = Phase.GROW

func startShoot():
	phase = Phase.SHOOT
	updateShoot()

func updateShoot():
	if remainingShots > 0:
		animation("shoot")
		$Sprite2D.frame = 0
	else:
		shrink()

func animateDeath():
	$DieSound.startSound()
	animation("die")
	phase = Phase.DIE

func _on_sprite_2d_animation_looped() -> void :
	_animationEndCheck()

func _on_Sprite_animation_finished():
	_animationEndCheck()

func _animationEndCheck() -> void :
	if $Sprite2D.animation == "shoot":
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
		startShoot()

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "shrink" and $Sprite2D.frame == 3:
		setHittable(false)
	elif $Sprite2D.animation == "grow" and $Sprite2D.frame == 2:
		setHittable(true)
	elif $Sprite2D.animation == "shoot" and $Sprite2D.frame == 4:
		spawnShot()

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	var movePointProvider = Level.worldsByTeamId[teamId].getFlyerPathProvider()
	var projectileTargetProvider = Level.domesByTeamId[teamId].getProjectileTargetProvider()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var spawnType: String = Data.of("flyer.spawnpoint") + "_" + variant
	var spawnPosition: Vector2 = movePointProvider.getSpawn(spawnType).global_position
	stream.encode_vector2(spawnPosition)



	var nextSide: = Utils.get_other_side(variant)
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))


	var point: Marker2D = movePointProvider.getRandomPoint(nextSide)
	var targetPos: Vector2 = point.global_position
	stream.encode_vector2(targetPos)
	stream.encode_u8(movePointProvider.getPointIndex(point, nextSide))



	stream.encode_float(randf())

	stream.encode_float(randf())


	var remainingShots: int = Data.stabilizedRandomInt(Data.of("flyer.minshots"), Data.of("flyer.maxshots"), "flyershots", 5)
	stream.encode_u8(remainingShots)
	for i in range(remainingShots):
		var randomShotPosition = projectileTargetProvider.getRandom(targetPos) + Vector2(8 - randi() % 16, 8 - randi() % 16)
		stream.encode_vector2(randomShotPosition)

	return stream.data

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)


	var variant: = Utils.get_side_string_from_bool(stream.decode_bool())

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), Level.domesByTeamId[teamId].getProjectileTargetProvider(), variant)

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

	movePointProvider.assignPointOccupation(movePointProvider.getPoint(pointIndex, nextSide), self)

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
			push_error("Flyer only supports setting move phase remotely")


	if phase == Phase.WAIT:
		startMove()

func get_full_sync_data() -> PackedByteArray:
	var stream: PackedByteStream = _get_base_full_sync()
	stream.encode_vector2(global_position)
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))
	stream.encode_vector2(targetPos)
	stream.encode_float(rotRandom)
	stream.encode_float(dirRandom)
	stream.encode_float(pathProgress)

	stream.encode_u8(remainingShots)
	stream.encode_u8(randomShotPositions.size())
	for i: int in range(randomShotPositions.size()):
		stream.encode_vector2(randomShotPositions[i])

	stream.encode_u8(phase)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	var stream: PackedByteStream = _apply_base_full_sync(buffer)
	global_position = stream.decode_vector2()
	nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
	targetPos = stream.decode_vector2()
	rotRandom = stream.decode_float()
	dirRandom = stream.decode_float()
	pathProgress = stream.decode_float()

	remainingShots = stream.decode_u8()
	var randomShotCount = stream.decode_u8()
	for i: int in range(randomShotCount):
		randomShotPositions.append(stream.decode_vector2())

	phase = stream.decode_u8()

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), \
	Level.domesByTeamId[teamId].getProjectileTargetProvider(), nextSide)
