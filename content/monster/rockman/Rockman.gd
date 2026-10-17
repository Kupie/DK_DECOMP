class_name Rockman
extends "res://content/monster/Monster.gd"

@export var distanceToMeleePoint: = 10.0

enum State{WALK, STANDUP, ATTACK, DIE}

var state: int = State.WALK

var path: Path2D
var meleeTarget: Path2D
var attacking: = false
var progress: = 0.0
var lastDelta: float
var variant: String
var pathIndex: int


var initialPunchSpeed: float
var additionalPunchSpeed: float
var speedupTime: float
var currentAttackTime: float
var _createdDueToFullSync: bool = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	position = path.curve.sample_baked(0) + path.global_position
	var d = position.x - (path.curve.sample_baked(50).x + + path.global_position.x)
	lastDelta = - d
	setFlip(d > 0.0)
	$Sprite2D.play("walk")
	updateHitboxState()

	initialPunchSpeed = Data.of("rockman.initialPunchSpeed")
	additionalPunchSpeed = Data.of("rockman.additionalPunchSpeed")
	speedupTime = Data.of("rockman.speedupTime")

func subProcess(delta):
	match state:
		State.WALK:
			progress += delta * Data.of("rockman.speed") * $Sprite2D.speed_scale
			var cp = meleeTarget.curve.get_closest_point($HitPosition.global_position)
			if sign(lastDelta) != sign(cp.x - $HitPosition.global_position.x):
				_setState(State.STANDUP)
			else:
				position = path.curve.sample_baked(progress) + path.global_position
		State.ATTACK:
			currentAttackTime += delta
			var progress = min(1.0, currentAttackTime / speedupTime)
			var speed = initialPunchSpeed + additionalPunchSpeed * progress
			$Sprite2D.speed_scale *= speed

func _setState(inState: State) -> void :
	if inState == State.STANDUP:
		animation("standup")
	if inState == State.ATTACK:
		animation("attack")
		$Sprite2D.play("attack")
	state = inState

func leave(delta: float):
	progress = max(0, progress - delta * Data.of("rockman.speed") * $Sprite2D.speed_scale)
	position = path.curve.sample_baked(progress) + path.global_position

func onGameLost():
	if currentHealth > 0:
		leaving = true
		animation("walk")
		$Sprite2D.speed_scale = 0.9 + randf() * 0.5
		setFlip( not $Sprite2D.flip_h)

func stagger():
	animation("hit")

func resumeAfterStagger():
	if state == State.WALK:
		animation("walk")
	elif state == State.ATTACK or state == State.STANDUP:
		animation("attack")

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.animation == "die":
		super.removeFreeBlocker()
	elif $Sprite2D.animation == "standup":
		_setState(State.ATTACK)

func applyDamage():
	var dome = Level.domesByTeamId[teamId]
	dome.requestMeleeDamage(Data.of("rockman.damage") * damageModifier, $HitPosition.global_position, self)
	InputSystem.shake(40, 0.3, 8, $HitPosition.global_position)
	$PunchSound1.startSound()
	$PunchSound2.startSound()
	$PunchSound3.startSound()

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "attack" and $Sprite2D.frame == 9:
		applyDamage()





func animateDeath():
	state = State.DIE
	animation("die")
	$DieSound.startSound()

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var moveType: String = Data.of("rockman.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)


	stream.encode_u32(randi())

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())


	var moveType = Data.of("rockman.movetype")
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]


	var randomWalkFrameSeed: = stream.decode_u32()
	$Sprite2D.frame = randomWalkFrameSeed % $Sprite2D.sprite_frames.get_frame_count("walk")

	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_float(distanceToMeleePoint)
	stream.encode_u8(state)
	stream.encode_bool(attacking)
	stream.encode_float(progress)
	stream.encode_float(lastDelta)
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_s32(pathIndex)
	stream.encode_float(initialPunchSpeed)
	stream.encode_float(additionalPunchSpeed)
	stream.encode_float(speedupTime)
	stream.encode_float(currentAttackTime)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream: = _apply_base_full_sync(buffer)
	distanceToMeleePoint = stream.decode_float()
	state = stream.decode_u8()
	attacking = stream.decode_bool()
	progress = stream.decode_float()
	lastDelta = stream.decode_float()
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	pathIndex = stream.decode_s32()
	initialPunchSpeed = stream.decode_float()
	additionalPunchSpeed = stream.decode_float()
	speedupTime = stream.decode_float()
	currentAttackTime = stream.decode_float()
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	Utils.decode_animated_sprite2d_state(stream, sprite)

	var moveType = Data.of("rockman.movetype")
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
