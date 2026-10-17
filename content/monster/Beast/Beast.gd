class_name Beast
extends "res://content/monster/Monster.gd"

enum Phase{WALK1, THREATEN, WALK2, JUMP, BASH, DIE}
var phase: int = Phase.WALK1

var path: Path2D
var meleeTarget: Path2D
var walking: = true
var progress: = 0.0
var targetProgress: float
var lastDelta: float
var targetOffset: float

var lastFrame: int

var variant: String
var pathIndex: int
var walk2TargetProgressRandom: float
var _createdDueToFullSync: bool = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	$Sprite2D.play("run")
	$Sprite2D.speed_scale = speedModifier

func subProcess(delta):
	match phase:
		Phase.WALK1:
			progress += delta * Data.of("beast.speed") * stunLevel() * speedModifier
			if progress >= targetProgress:
				animation("threaten")
				phase = Phase.THREATEN
				$ThreatenSound.startSound()
			else:
				position = path.curve.sample_baked(progress) + path.global_position
		Phase.WALK2:
			progress += delta * Data.of("beast.speed") * stunLevel() * speedModifier
			if progress >= targetProgress:
				phase = Phase.JUMP
				var target = meleeTarget.curve.sample_baked(targetOffset * meleeTarget.curve.get_baked_length()) - $HitPosition.position
				var peakY = target.y + position.y - 10 - 10 * randf()
				moveTween.stop_all()
				moveTween.remove_all()
				moveTween.interpolate_property(self, "position:x", position.x, target.x, 0.7, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.4)
				moveTween.interpolate_property(self, "position:y", position.y, peakY, 0.4, Tween.TRANS_QUAD, Tween.EASE_OUT, 0.4)
				moveTween.interpolate_property(self, "position:y", peakY, target.y, 0.3, Tween.TRANS_QUAD, Tween.EASE_IN, 0.8)
				moveTween.interpolate_callback(self, 1.4, "startBash")
				moveTween.start()
				$JumpSound.startSound()
				animation("jump")
			else:
				position = path.curve.sample_baked(progress) + path.global_position

func startBash():
	phase = Phase.BASH
	animation("attack")

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	match $Sprite2D.animation:
		"threaten":
			startWalk2()
		"die_attack":
			removeFreeBlocker()
		"die_run":
			removeFreeBlocker()

func startWalk2():
	phase = Phase.WALK2
	targetProgress = path.curve.get_baked_length() * (0.75 + walk2TargetProgressRandom * 0.1)
	animation("run")

func animateDeath():
	if $Sprite2D.animation == "attack":
		animation("die_attack")
	else:
		animation("die_run")
	phase = Phase.DIE
	$DieSound.startSound()

func resumeAfterStagger():
	if phase == Phase.BASH:
		animation("attack")
	elif phase == Phase.THREATEN:
		startWalk2()
	elif phase == Phase.JUMP:
		animation("jump")
		$Sprite2D.frame = lastFrame
	elif phase != Phase.DIE:
		animation("run")

func applyDamage():
	var dome = Level.domesByTeamId[teamId]
	dome.requestMeleeDamage(Data.of("beast.damage") * damageModifier, $HitPosition.global_position, self)
	InputSystem.shake(40, 0.3, 8, $HitPosition.global_position)
	$PunchSound1.startSound()
	$PunchSound2.startSound()
	$PunchSound3.startSound()

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "attack" and ($Sprite2D.frame == 3 or $Sprite2D.frame == 8):
		applyDamage()
	elif $Sprite2D.animation == "jump":
		lastFrame = $Sprite2D.frame

func handleFullStun():
	if phase == Phase.WALK1 or phase == Phase.THREATEN or phase == Phase.WALK2:
		animation("hit_run")
	else:
		animation("hit_attack")

func onGameLost():
	if phase == Phase.JUMP or phase == Phase.BASH:
		animation("die_attack")
	else:
		leaving = true
		animation("walk")
		$Sprite2D.speed_scale = 0.9 + randf() * 0.5
		setFlip( not $Sprite2D.flip_h)

func leave(delta: float):
	if progress > 0.0:
		progress = max(0, progress - delta * Data.of("beast.speed") * $Sprite2D.speed_scale)
		position = path.curve.sample_baked(progress) + path.global_position


static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var moveType: String = Data.of("beast.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)


	stream.encode_float(randf())


	stream.encode_u32(randi())


	stream.encode_float(randf())
	stream.encode_float(randf())

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())


	var moveType = Data.of("beast.movetype")
	var dome = Level.domesByTeamId[teamId]
	meleeTarget = dome.getMeleeTarget(Data.of("beast.meleetarget"))

	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]

	var targetOffsetRandom = stream.decode_float()
	position = path.curve.sample_baked(0) + path.global_position
	var d = position.x - (path.curve.sample_baked(50).x + + path.global_position.x)
	if d > 0.0:
		setFlip(true)
		targetOffset = 1.0 - targetOffsetRandom * 0.33
	else:
		targetOffset = 0.0 + targetOffsetRandom * 0.33
		setFlip(false)


	var randomWalkFrameSeed: = stream.decode_u32()
	$Sprite2D.frame = randomWalkFrameSeed % $Sprite2D.sprite_frames.get_frame_count("run")

	var targetProgressRandom = stream.decode_float()
	targetProgress = 80 + targetProgressRandom * 100
	walk2TargetProgressRandom = stream.decode_float()

	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_u8(phase)
	stream.encode_bool(walking)
	stream.encode_float(progress)
	stream.encode_float(targetProgress)
	stream.encode_float(lastDelta)
	stream.encode_float(targetOffset)
	stream.encode_s32(lastFrame)
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_s32(pathIndex)
	stream.encode_float(walk2TargetProgressRandom)
	stream.encode_bool(sprite.flip_h)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	phase = stream.decode_u8()
	walking = stream.decode_bool()
	progress = stream.decode_float()
	targetProgress = stream.decode_float()
	lastDelta = stream.decode_float()
	targetOffset = stream.decode_float()
	lastFrame = stream.decode_s32()
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	pathIndex = stream.decode_s32()
	walk2TargetProgressRandom = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip, true)
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	Utils.decode_animated_sprite2d_state(stream, sprite)

	var moveType = Data.of("beast.movetype")
	var dome = Level.domesByTeamId[teamId]
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	meleeTarget = dome.getMeleeTarget(Data.of("beast.meleetarget"))
