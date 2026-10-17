class_name BigTick
extends "res://content/monster/Monster.gd"

enum Phase{WALK, BURROW, EMERGE, JUMP, EXPLODE}
var phase: int = Phase.WALK

var path: Path2D
var target: Vector2

var pathBakedLength: float
var progress: = 0.0
var burrowProgress: = 0.0
var targetProgress: int
var burrowedCooldown: float
var offset: Vector2

var variant: String
var pathIndex: int
var random: RandomNumberGenerator
var _createdDueToFullSync: bool = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	position = path.curve.sample_baked(0) + path.global_position
	var d = position.x - (path.curve.sample_baked(50).x + + path.global_position.x)
	setFlip(d > 0.0)
	$Sprite2D.play("walk")
	updateHitboxState()
	speedModifier *= 0.9 + random.randf() * 0.2
	$Sprite2D.frame = random.randi() % $Sprite2D.sprite_frames.get_frame_count("walk")
	targetProgress = 100 + 30 * random.randf()
	pathBakedLength = path.curve.get_baked_length()
	burrowProgress = (0.1 + random.randf() * 0.4) * pathBakedLength
	offset = Vector2(0, random.randf_range(-3, 3))

func subProcess(delta):

	match phase:
		Phase.WALK:
			progress += delta * Data.of("bigtick.speed") * $Sprite2D.speed_scale
			if progress > burrowProgress:
				burrowProgress += (0.1 + random.randf() * 0.4) * pathBakedLength
				if burrowProgress > 0.8 * pathBakedLength:
					burrowProgress = pathBakedLength
				burrow()
				return
			if abs(target.x - global_position.x) < targetProgress:
				animation("jump")
				phase = Phase.JUMP
				var peakY = (target.y + position.y) * 0.5 - 50 - random.randf() * 20
				moveTween.interpolate_property(self, "position:x", position.x, target.x, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.4)
				moveTween.interpolate_property(self, "position:y", position.y, peakY, 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT, 0.4)
				moveTween.interpolate_property(self, "position:y", peakY, target.y, 0.5, Tween.TRANS_QUAD, Tween.EASE_IN, 0.9)
				moveTween.interpolate_callback(self, 1.4, "explode")
				moveTween.start()
				$JumpSound.startSound()
			else:
				position = path.curve.sample_baked(progress) + path.global_position + offset
		Phase.BURROW:
			burrowedCooldown -= delta
			if burrowedCooldown <= 0.0:
				emerge()

func explode():
	phase = Phase.EXPLODE
	animation("explode")
	$Sprite2D.speed_scale = 1.0
	$DieSoundExplode.startSound()

func burrow():
	phase = Phase.BURROW
	burrowedCooldown = Data.of("bigtick.burrowtime") + random.randf() * 1.0
	animation("burrow")

func emerge():
	phase = Phase.EMERGE
	animation("emerge")
	setHittable(true)

func leave(delta: float):
	if progress > 0.0 and phase == Phase.WALK:
		progress = max(0, progress - delta * Data.of("bigtick.speed") * $Sprite2D.speed_scale)
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
	if $Sprite2D.animation == "die":
		super.removeFreeBlocker()
	elif $Sprite2D.animation == "explode":
		super.removeFreeBlocker()
		die()
	elif $Sprite2D.animation == "burrow":
		setHittable(false)
	elif $Sprite2D.animation == "emerge":
		phase = Phase.WALK
		animation("walk")

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "explode" and $Sprite2D.frame == 1:
		applyDamage()






func resumeAfterStagger():

	if phase == Phase.JUMP:
		receiveDamage = 99
	setHittable(true)
	animation("walk")
	phase = Phase.WALK

func stagger():
	animation("hit")

func applyDamage():
	var dome = Level.domesByTeamId[teamId]
	dome.requestMeleeDamage(Data.of("bigtick.damage") * damageModifier, global_position, self)
	InputSystem.shake(40, 0.3, 8, global_position)

func animateDeath():
	$DieSound.startSound()
	animation("die")

static func get_spawn_data(variant: String, teamId: String, groupSize: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var moveType: String = Data.of("tick.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)


	stream.encode_float(1.0 / float(groupSize))


	var dome = Level.domesByTeamId[teamId]
	var target: Vector2 = dome.getFrontAttackPosition(variant)
	stream.encode_vector2(target)

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

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_u8(phase)
	_encode_curve2D(stream, path.curve)
	stream.encode_vector2(target)
	stream.encode_float(pathBakedLength)
	stream.encode_float(progress)
	stream.encode_float(burrowProgress)
	stream.encode_s32(targetProgress)
	stream.encode_float(burrowedCooldown)
	stream.encode_vector2(offset)
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_s32(pathIndex)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_vector2(global_position)
	stream.encode_bool(sprite.flip_h)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	phase = stream.decode_u8()
	var path_curve: Curve2D = Curve2D.new()
	_decode_curve2D(stream, path_curve)
	target = stream.decode_vector2()
	pathBakedLength = stream.decode_float()
	progress = stream.decode_float()
	burrowProgress = stream.decode_float()
	targetProgress = stream.decode_s32()
	burrowedCooldown = stream.decode_float()
	offset = stream.decode_vector2()
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	pathIndex = stream.decode_s32()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	global_position = stream.decode_vector2()
	var flip: bool = stream.decode_bool()
	setFlip(flip, true)
	var moveType: String = Data.of("tick.movetype")
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)
