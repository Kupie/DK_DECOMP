class_name Butterfly
extends "res://content/monster/Monster.gd"

signal move_finished

enum Phase{TURN, TURNING, MOVE, DIE, WAIT}

var phase: int = Phase.MOVE

var remainingShots: = 0

var nextSide: String
var movePointProvider
var projetileTargetProvider
var currentMoveCurve: Curve2D

var pathProgress: = 0.0
var curveRotationRadians: = 0.5
var curveRotationStrength: = 80

var line: Line2D
var cooldown: = 0.0

var targetPos: Vector2
var hasNetworkData: = false

var turns: = 0
var random: RandomNumberGenerator
var _createdDueToFullSync: bool = false
var _variant: String

func setProviders(movePointProvider, projetileTargetProvider, side: String):
	self.movePointProvider = movePointProvider
	self.projetileTargetProvider = projetileTargetProvider
	currentMoveCurve = Curve2D.new()

func init():
	if _createdDueToFullSync:
		startMove()
		return
	supports_full_sync = true
	startMove()
	attackTween.interpolate_callback(self, 2.0, "set", "remainingShots", 3)
	attackTween.start()
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)

func createNextPath():
	pathProgress = 0
	var direction = (targetPos - position).normalized()
	currentMoveCurve.clear_points()
	var rot1 = direction.rotated(0.5 * PI * curveRotationRadians) * curveRotationStrength
	currentMoveCurve.add_point(position, Vector2.ZERO, rot1)
	currentMoveCurve.add_point(targetPos)

func startMove():
	animation("fly")
	createNextPath()
	var pathLength = currentMoveCurve.get_baked_length()

	var duration = pathLength / Data.of("butterfly.speed")
	moveTween.interpolate_property(self, "pathProgress", 0, pathLength, duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	moveTween.start()
	phase = Phase.MOVE

	random = RandomNumberGenerator.new()
	random.seed = UID + turns
	hasNetworkData = false

func subProcess(delta):
	if cooldown > 0.0:
		cooldown -= delta
		return

	match phase:
		Phase.MOVE:
			var pathLength = currentMoveCurve.get_baked_length()
			moveTween.playback_speed = 1.0 * stunLevel() * speedModifier
			var newPos = currentMoveCurve.sample_baked(pathProgress)
			position = newPos
			if pathProgress >= pathLength:
				phase = Phase.TURN
				emit_signal("move_finished")
		Phase.TURN:
			animation("turn")
			$TurnSound.startSound()
			turns += 1
			phase = Phase.TURNING

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
	$Sprite2D.play("hit")

func resumeAfterStagger():
	animation("fly")
	phase = Phase.MOVE

func shoot():
	var delay: = 0.01
	for _i in range(0, 3):
		attackTween.interpolate_callback(self, delay, "spawnProjectile")
		attackTween.start()
		delay += 0.15
	$ShootSound.startSound()
	remainingShots -= 1

func spawnProjectile():
	var p = preload("res://content/monster/butterfly/ButterflyProjectile.tscn").instantiate()
	p.teamId = teamId
	p.damageSource = damageSource
	p.position = position + $ProjectilePosition.position
	p.origin = position
	p.target = projetileTargetProvider.getStableRandom(position, random) + Vector2(8 - random.randi() % 16, 8 - random.randi() % 16)
	p.damage = Data.of("butterfly.damage") * damageModifier
	p.speed = Data.of("butterfly.shotspeed")
	get_parent().add_child(p)

func animateDeath():
	$DieSound.startSound()
	animation("die")
	phase = Phase.DIE

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.animation == "shoot":
		if remainingShots <= 0:
			animation("fly")
	elif $Sprite2D.animation == "fly" and remainingShots > 0:
		animation("shoot")
	elif $Sprite2D.animation == "die":
		super.removeFreeBlocker()
	elif $Sprite2D.animation == "turn":
		remainingShots = 6
		if multiplayer.is_server():
			prepareMoveData()
			startMove()
			sendMoveData()
		elif hasNetworkData:
			startMove()
		else:
			phase = Phase.WAIT
		animation("fly")
		setFlip( not $Sprite2D.flip_h)

func _on_Sprite_frame_changed():
	if leaving:
		return
	if $Sprite2D.animation == "shoot" and ($Sprite2D.frame == 4 or $Sprite2D.frame == 18 or $Sprite2D.frame == 25):
		shoot()

func prepareMoveData() -> void :
	nextSide = Utils.get_other_side(nextSide)
	targetPos = movePointProvider.assignRandomPoint(nextSide + "_high", self).global_position

func sendMoveData() -> void :
	var stream = PackedByteStream.new()
	stream.encode_vector2(targetPos)
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))

	networkPhaseChanged.emit(Phase.MOVE, stream.data)

func remote_set_phase(_phase: int, buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	match _phase:
		Phase.MOVE:
			targetPos = stream.decode_vector2()
			nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
			hasNetworkData = true
		_:
			push_error("Butterfly only supports setting move phase remotely")

	if phase == Phase.WAIT:
		startMove()

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	var movePointProvider = Level.worldsByTeamId[teamId].getFlyerPathProvider()

	var side: = variant.substr(0, variant.find("_"))


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var spawnType: String = Data.of("butterfly.spawnpoint") + "_" + side
	var spawnPosition: Vector2 = movePointProvider.getSpawn(spawnType).global_position
	stream.encode_vector2(spawnPosition)


	var nextSide: = Utils.get_other_side(side)
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))


	var nextSideHeight: = nextSide + "_high"
	var point: Marker2D = movePointProvider.getRandomPoint(nextSideHeight)
	var targetPos: Vector2 = point.global_position
	stream.encode_vector2(targetPos)
	stream.encode_u8(movePointProvider.getPointIndex(point, nextSideHeight))

	return stream.data

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)


	_variant = Utils.get_side_string_from_bool(stream.decode_bool())

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), Level.domesByTeamId[teamId].getProjectileTargetProvider(), _variant)

	position = stream.decode_vector2()
	nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
	targetPos = stream.decode_vector2()

	var pointIndex = stream.decode_u8()

	hasNetworkData = true

	movePointProvider.assignPointOccupation(movePointProvider.getPoint(pointIndex, nextSide + "_high"), self)

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_bool(Utils.get_side_bool_from_string(_variant))
	stream.encode_u8(phase)
	stream.encode_s32(remainingShots)
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))
	_encode_curve2D(stream, currentMoveCurve)
	stream.encode_float(pathProgress)
	stream.encode_float(curveRotationRadians)
	stream.encode_s16(curveRotationStrength)
	stream.encode_float(cooldown)
	stream.encode_vector2(targetPos)
	stream.encode_bool(hasNetworkData)
	stream.encode_s32(turns)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_bool(sprite.flip_h)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	_variant = Utils.get_side_string_from_bool(stream.decode_bool())
	phase = stream.decode_u8()
	remainingShots = stream.decode_s32()
	nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
	currentMoveCurve = Curve2D.new()
	_decode_curve2D(stream, currentMoveCurve)
	pathProgress = stream.decode_float()
	curveRotationRadians = stream.decode_float()
	curveRotationStrength = stream.decode_s16()
	cooldown = stream.decode_float()
	targetPos = stream.decode_vector2()
	hasNetworkData = stream.decode_bool()
	turns = stream.decode_s32()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	var flip: bool = stream.decode_bool()
	setFlip(flip, true)
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	Utils.decode_animated_sprite2d_state(stream, sprite)

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), Level.domesByTeamId[teamId].getProjectileTargetProvider(), _variant)
