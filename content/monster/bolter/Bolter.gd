class_name Bolter
extends "res://content/monster/Monster.gd"

enum Phase{ENTER, SHOOT, DIE}

var phase: int = Phase.ENTER

var remainingShots: = 0

var movePointProvider
var projetileTargetProvider
var currentMoveCurve: Curve2D

var applyInRotation: = false
var pathProgress: = 0.0
var averagedMoveDelta: = 0.0
var curveRotationRadians: = 0.75
var curveRotationStrength: = 150

var targetPos: Vector2
var rotRandom: float

var line: Line2D
var cooldown: = 0.0

var random: RandomNumberGenerator
var _createdDueToFullSync: bool = false
var _move_tell: float

func setProviders(movePointProvider, projetileTargetProvider, side: String):
	self.movePointProvider = movePointProvider
	self.projetileTargetProvider = projetileTargetProvider
	currentMoveCurve = Curve2D.new()

func init():
	if _createdDueToFullSync:
		_full_sync_init()
		return

	supports_full_sync = true
	applyInRotation = true
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)

	var direction = (targetPos - position).normalized()
	currentMoveCurve.add_point(position, Vector2.ZERO)
	var rot = direction.rotated(PI * 1.25 * curveRotationRadians - 0.5 * PI * curveRotationRadians * rotRandom) * curveRotationStrength
	currentMoveCurve.add_point(targetPos, rot, Vector2.ZERO)

	var pathLength = currentMoveCurve.get_baked_length()

	var duration = pathLength / Data.of("bolter.speed")
	moveTween.interpolate_property(self, "pathProgress", 0, pathLength, duration, Tween.TRANS_QUAD, Tween.EASE_OUT)
	moveTween.interpolate_callback(self, duration, "startShooting")
	moveTween.start()

	$Bolt.play("default")
	resumeAnimation()

	random = RandomNumberGenerator.new()
	random.seed = UID

func _full_sync_init() -> void :

	if phase == Phase.ENTER:
		var pathLength = currentMoveCurve.get_baked_length()
		var duration = pathLength / Data.of("bolter.speed")
		var tween_time_left: float = duration - _move_tell
		var tween_percent: float = _move_tell / duration
		moveTween.interpolate_property(self, "pathProgress", pathLength * tween_percent, pathLength, tween_time_left, Tween.TRANS_QUAD, Tween.EASE_OUT)
		moveTween.interpolate_callback(self, tween_time_left, "startShooting")
		moveTween.start()

func subProcess(delta):
	if cooldown > 0.0:
		cooldown -= delta
		return

	match phase:
		Phase.ENTER:
			var oldPos: = position
			position = currentMoveCurve.sample_baked(pathProgress)
			if averagedMoveDelta == 0.0:
				averagedMoveDelta = (position - oldPos).length()
			else:
				averagedMoveDelta = averagedMoveDelta * (1.0 - delta) + (position - oldPos).length() * delta
		Phase.SHOOT:
			pass

func startShooting():
	phase = Phase.SHOOT
	animation("shoot2")
	$ChargingShotSound.startSound()

func leave(delta: float):
	position.y -= delta * 50
	position.x += delta * position.x * 0.1

func onGameLost():
	if currentHealth > 0:
		moveTween.stop_all()
		moveTween.remove_all()
		leaving = true
		setFlip( not $Sprite2D.flip_h)
		animation("fly")

func handleFullStun():
	animation("hit")

func resumeAfterStagger():
	resumeAnimation()

func resumeAnimation() -> void :
	if phase == Phase.SHOOT:
		animation("idle")
	else:
		animation("fly")

func hitDome():
	var dome = Level.domesByTeamId[teamId]
	dome.requestBeamDamage(Data.of("bolter.damage") * damageModifier, global_position, self)

func animateDeath():
	$DieSound.startSound()
	animation("die")
	phase = Phase.DIE

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.animation == "die":
		super.removeFreeBlocker()
	elif $Sprite2D.animation == "shoot2":
		animation("idle")
	elif $Sprite2D.animation == "idle":
		animation("shoot2")
		$ChargingShotSound.startSound()

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "shoot2":
		if $Sprite2D.frame == 9:
			hitDome()
		elif $Sprite2D.frame == 5:
			$ShootSound.startSound()
		elif $Sprite2D.frame == 8:
			InputSystem.shake(80, 0.2, 8, global_position)
		elif $Sprite2D.frame == 0:
			$Bolt.play("bolt" + str(1 + random.randi() % 3))

func _on_Bolt_animation_finished():
	$Bolt.play("default")

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	var movePointProvider = Level.worldsByTeamId[teamId].getFlyerPathProvider()
	var projectileTargetProvider = Level.domesByTeamId[teamId].getProjectileTargetProvider()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var spawnType = Data.of("bolter.spawnpoint") + "_" + variant
	var spawnPosition: Vector2 = movePointProvider.getSpawn(spawnType).global_position
	stream.encode_vector2(spawnPosition)


	var shot_sign: = 1 if variant == CONST.LEFT else -1
	var shotPosition: = Vector2(shot_sign * 116, 124.5)
	var targetPos: Vector2 = projectileTargetProvider.getRandom(spawnPosition) + Vector2(4 - randi() % 8, 4 - randi() % 8) - shotPosition
	stream.encode_vector2(targetPos)



	stream.encode_float(randf())

	return stream.data


func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)


	var variant: = Utils.get_side_string_from_bool(stream.decode_bool())

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), Level.domesByTeamId[teamId].getProjectileTargetProvider(), variant)

	position = stream.decode_vector2()
	targetPos = stream.decode_vector2()
	rotRandom = stream.decode_float()

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_u8(phase)
	stream.encode_u16(remainingShots)
	stream.encode_bool(applyInRotation)
	stream.encode_float(pathProgress)
	stream.encode_float(averagedMoveDelta)
	stream.encode_float(curveRotationRadians)
	stream.encode_s16(curveRotationStrength)
	stream.encode_vector2(targetPos)
	stream.encode_float(rotRandom)
	stream.encode_float(cooldown)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	_encode_curve2D(stream, currentMoveCurve)
	stream.encode_float(moveTween.tell())
	Utils.encode_animated_sprite2d_state(stream, sprite)
	stream.encode_vector2(global_position)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	phase = stream.decode_u8()
	remainingShots = stream.decode_u16()
	applyInRotation = stream.decode_bool()
	pathProgress = stream.decode_float()
	averagedMoveDelta = stream.decode_float()
	curveRotationRadians = stream.decode_float()
	curveRotationStrength = stream.decode_s16()
	targetPos = stream.decode_vector2()
	rotRandom = stream.decode_float()
	cooldown = stream.decode_float()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	currentMoveCurve = Curve2D.new()
	_decode_curve2D(stream, currentMoveCurve)
	_move_tell = stream.decode_float()
	Utils.decode_animated_sprite2d_state(stream, sprite)
	global_position = stream.decode_vector2()

	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)
