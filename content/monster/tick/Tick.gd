class_name Tick
extends "res://content/monster/Monster.gd"

const THROW_DURATION: = 1.0

enum Phase{THROWN, WALK, JUMP, EXPLODE}
var phase: int = Phase.WALK

var path: Path2D
var target: Vector2

var progress: = 0.0
var targetProgress: int
var speedScale: float
var offset: Vector2
var throwTargetPos: Vector2

var variant: String
var pathIndex: int
var random: RandomNumberGenerator
var _createdDueToFullSync: bool = false
var _fullSyncInitMoveTell: float = 0.0

func init():
	if _createdDueToFullSync:
		_full_sync_init()
		return
	supports_full_sync = true
	if phase == Phase.THROWN:
		throwTargetPos = Utils.get_global_from_local_dome_position(throwTargetPos, teamId)
		var delay: = random.randf_range(0.0, 0.1)
		animation("jump")
		phase = Phase.JUMP
		setFlip(position.x > throwTargetPos.x)
		var peakY = (throwTargetPos.y + position.y) * 0.5 - 30 - random.randf() * 20
		moveTween.interpolate_property(self, "position:x", position.x, throwTargetPos.x, THROW_DURATION, Tween.TRANS_LINEAR, Tween.EASE_IN, delay)
		moveTween.interpolate_property(self, "position:y", position.y, peakY, THROW_DURATION * 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT, delay)
		moveTween.interpolate_property(self, "position:y", peakY, throwTargetPos.y, THROW_DURATION * 0.5, Tween.TRANS_QUAD, Tween.EASE_IN, delay + THROW_DURATION * 0.5)
		moveTween.interpolate_callback(self, delay + THROW_DURATION, "finishThrow")
		moveTween.start()
	else:
		position = path.curve.sample_baked(0) + path.position
		startWalking()
		offset = Vector2(0, random.randf_range(-5, 5))

	setFlip(Utils.get_side_bool_from_string(variant))
	$Sprite2D.play("walk")
	updateHitboxState()
	speedScale = 0.9 + random.randf() * 0.2
	speedModifier *= speedScale
	targetProgress = 70 + 30 * random.randf()

func _full_sync_init() -> void :
	if phase == Phase.JUMP:
		moveTween.interpolate_property(self, "position", position, throwTargetPos, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN)
		moveTween.interpolate_callback(self, THROW_DURATION, "finishThrow")
		moveTween.start()

func startWalking():
	phase = Phase.WALK
	animation("walk")
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)
	$Sprite2D.frame = random.randi() % $Sprite2D.sprite_frames.get_frame_count("walk")

func finishThrow():
	var posRelativeToDome: = Utils.get_position_relative_to_dome(position, teamId)
	progress = path.curve.get_closest_offset(posRelativeToDome - path.position)
	offset = path.curve.get_closest_point(posRelativeToDome) - posRelativeToDome
	moveTween.interpolate_callback(self, random.randf_range(0.05, 0.2), "startWalking")
	moveTween.start()

func subProcess(delta):
	match phase:
		Phase.THROWN:
			animation("jump")
		Phase.WALK:
			progress += delta * Data.of("tick.speed") * $Sprite2D.speed_scale
			if abs(target.x - global_position.x) < targetProgress:
				animation("jump")
				phase = Phase.JUMP
				var peakY = (target.y + position.y) * 0.5 - 30 - random.randf() * 20
				moveTween.interpolate_property(self, "position:x", position.x, target.x, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.4)
				moveTween.interpolate_property(self, "position:y", position.y, peakY, 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT, 0.4)
				moveTween.interpolate_property(self, "position:y", peakY, target.y, 0.5, Tween.TRANS_QUAD, Tween.EASE_IN, 0.9)
				moveTween.interpolate_callback(self, 1.4, "set", "phase", Phase.EXPLODE)
				moveTween.start()
				$JumpSound.startSound()
			else:
				position = path.curve.sample_baked(progress) + path.global_position + offset
		Phase.EXPLODE:
			animation("explode")

func leave(delta: float):
	if progress > 0.0 and phase == Phase.WALK:
		progress = max(0, progress - delta * Data.of("tick.speed") * $Sprite2D.speed_scale)
		position = path.curve.sample_baked(progress) + path.global_position

func onGameLost():
	if currentHealth > 0:
		leaving = true
		if phase == Phase.WALK:
			animation("walk")
			$Sprite2D.speed_scale = 0.9 + random.randf() * 0.5
			setFlip( not $Sprite2D.flip_h)
		else:
			if not dead:
				die()
				animateDeath()

func handleFullStun():
	animation("hit")

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.animation == "die" or $Sprite2D.animation == "explode":
		super.removeFreeBlocker()

func resumeAfterStagger():

	receiveDamage = 99

func stagger():
	receiveDamage = 99

func applyDamage():
	Level.domesByTeamId[teamId].requestMeleeDamage(Data.of("tick.damage") * damageModifier, global_position, self)
	InputSystem.shake(40, 0.3, 8, global_position)

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "explode" and $Sprite2D.frame == 7:
		applyDamage()
		die()
		$DieSoundExplode.startSound()






func animateDeath():
	$DieSound.startSound()
	animation("die")

static func get_spawn_data(variant: String, teamId: String, groupSize: int, damageSource: int = Monster.Type.TICK, thrownFromPosition: Vector2 = Vector2.ZERO, tickSpawnPosition: Vector2 = Vector2.ZERO) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var moveType: String = Data.of("tick.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)


	if groupSize == 0:
		stream.encode_float(0.0)
	else:
		stream.encode_float(1.0 / float(groupSize))


	var target: Vector2 = Level.domesByTeamId[teamId].getFrontAttackPosition(variant)
	stream.encode_vector2(target)

	stream.encode_u8(damageSource)
	if damageSource != Monster.Type.TICK:
		stream.encode_vector2(thrownFromPosition)
		stream.encode_vector2(tickSpawnPosition)

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())


	var moveType = Data.of("tick.movetype")
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

	headCount = stream.decode_float()

	target = stream.decode_vector2()

	random = RandomNumberGenerator.new()
	random.seed = UID

	var damageSourceInt: = stream.decode_u8()
	if damageSourceInt != Monster.Type.TICK:
		match damageSourceInt:
			Monster.Type.BREEDER:
				damageSource = "breeder"
			_:
				damageSource = ""

		phase = Phase.THROWN
		var thrownFromPosition: = stream.decode_vector2()
		var tickSpawnPosition: = stream.decode_vector2()
		var relPos: = Utils.get_position_relative_to_dome(thrownFromPosition, teamId)
		throwTargetPos = path.curve.get_closest_point(relPos)
		progress = path.curve.get_closest_offset(relPos)
		progress += random.randf_range(-50, 50)
		throwTargetPos = path.curve.sample_baked(progress)
		position = tickSpawnPosition + thrownFromPosition + Vector2(random.randf_range(-6, 6), random.randf_range(-6, 6))

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_u8(phase)
	stream.encode_vector2(target)
	stream.encode_float(progress)
	stream.encode_s32(targetProgress)
	stream.encode_float(speedScale)
	stream.encode_vector2(offset)
	stream.encode_vector2(throwTargetPos)
	stream.encode_s32(pathIndex)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_vector2(global_position)
	stream.encode_bool(sprite.flip_h)
	stream.encode_float(moveTween.tell())
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream: PackedByteStream = _apply_base_full_sync(buffer)
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	phase = stream.decode_u8()
	target = stream.decode_vector2()
	progress = stream.decode_float()
	targetProgress = stream.decode_s32()
	speedScale = stream.decode_float()
	offset = stream.decode_vector2()
	throwTargetPos = stream.decode_vector2()
	pathIndex = stream.decode_s32()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	global_position = stream.decode_vector2()
	setFlip(stream.decode_bool(), true)
	_fullSyncInitMoveTell = stream.decode_float()
	Utils.decode_animated_sprite2d_state(stream, sprite)
	updateHitboxState()
	var moveType = Data.of("tick.movetype")
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
