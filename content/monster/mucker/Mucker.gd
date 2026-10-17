class_name Mucker
extends "res://content/monster/Monster.gd"

@export var distanceToMeleePoint: = 10.0

var path: Path2D
var meleeTarget: Path2D
var walking: = true
var progress: = 0.0
var lastDelta: float
var variant: String
var pathIndex: int
var _createdDueToFullSync: bool = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	position = path.curve.sample_baked(0) + path.global_position
	var d = position.x - (path.curve.sample_baked(50).x + + path.global_position.x)
	lastDelta = - d
	setFlip(d > 0.0)
	resumeAnimation()
	updateHitboxState()

func subProcess(delta):
	if walking:
		progress += delta * Data.of("mucker.speed") * $Sprite2D.speed_scale
		var cp = meleeTarget.curve.get_closest_point($HitPosition.global_position)
		if sign(lastDelta) != sign(cp.x - $HitPosition.global_position.x):
			animation("start_attack")
			walking = false
		else:
			position = path.curve.sample_baked(progress) + path.global_position

func leave(delta: float):
	if progress > 0.0:
		progress = max(0, progress - delta * Data.of("mucker.speed") * $Sprite2D.speed_scale)
		position = path.curve.sample_baked(progress) + path.global_position

func onGameLost():
	if currentHealth > 0:
		leaving = true
		animation("walk")
		$Sprite2D.speed_scale = 0.9 + randf() * 0.5
		setFlip( not $Sprite2D.flip_h)

func handleFullStun():
	animation("hit")

func resumeAfterStagger():
	resumeAnimation()

func resumeAnimation() -> void :
	if walking:
		animation("walk")
	else:
		animation("attack")

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished():
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.animation == "die" or $Sprite2D.animation == "die_walk":
		super.removeFreeBlocker()
	if $Sprite2D.animation == "start_attack":
		animation("attack")

func applyDamage():
	Level.domesByTeamId[teamId].requestMeleeDamage(Data.of("mucker.damage") * damageModifier, $HitPosition.global_position, self)
	InputSystem.shake(40, 0.3, 8, $HitPosition.global_position)
	$PunchSound1.startSound()
	$PunchSound2.startSound()
	$PunchSound3.startSound()

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "attack" and $Sprite2D.frame == 5:
		applyDamage()






func animateDeath():
	if walking:
		animation("die_walk")
	else:
		animation("die")
	$DieSound.startSound()

static func get_spawn_data(variant: String, teamId: String, pathIndex: int = -1, progress: float = -1.0) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var moveType: String = Data.of("mucker.movetype")
	if pathIndex == -1:
		pathIndex = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)


	stream.encode_u32(randi())

	stream.encode_float(progress)

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())


	var moveType = Data.of("mucker.movetype")
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)


	var randomWalkFrameSeed: = stream.decode_u32()
	animation("walk")
	$Sprite2D.frame = randomWalkFrameSeed % $Sprite2D.sprite_frames.get_frame_count("walk")

	var incomingProgress: = stream.decode_float()
	if incomingProgress != -1:
		progress = incomingProgress

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()

	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_float(distanceToMeleePoint)
	stream.encode_bool(walking)
	stream.encode_float(progress)
	stream.encode_float(lastDelta)
	stream.encode_u32(pathIndex)

	Utils.encode_animated_sprite2d_state(stream, sprite)
	stream.encode_vector2(global_position)

	_encode_curve2D(stream, path.curve)
	_encode_curve2D(stream, meleeTarget.curve)
	stream.encode_bool(sprite.flip_h)

	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)

	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	distanceToMeleePoint = stream.decode_float()
	walking = stream.decode_bool()
	progress = stream.decode_float()
	lastDelta = stream.decode_float()
	pathIndex = stream.decode_u32()

	Utils.decode_animated_sprite2d_state(stream, sprite)
	global_position = stream.decode_vector2()
	var _fullSyncPathCurve: = Curve2D.new()
	var _fullSyncMeleeTargetCurve: = Curve2D.new()
	_decode_curve2D(stream, _fullSyncPathCurve)
	_decode_curve2D(stream, _fullSyncMeleeTargetCurve)
	setFlip(stream.decode_bool(), true)

	updateHitboxState()

	var moveType = Data.of("mucker.movetype")
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

	path.curve = _fullSyncPathCurve
	meleeTarget.curve = _fullSyncMeleeTargetCurve
