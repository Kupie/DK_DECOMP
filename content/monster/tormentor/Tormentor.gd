class_name Tormentor
extends "res://content/monster/Monster.gd"

enum Phase{WALK, TRANSFORM_TO_BEAM, BEAM, DIE}

var phase: int = Phase.WALK
var walking: = true
var beaming: = false
var damageSum: = 0.0
const damageUnit: = 2.0

var path: Path2D
var meleeTarget: Path2D
var meleeTargetLength: float
var beamNoise: = FastNoiseLite.new()
var beamNoiseTime: = 0.0
var progress: = 0.0
var lastDelta: float
var goalProgress: float

var variant: String
var pathIndex: int

var lastWalkFrame: = 0

var random: RandomNumberGenerator

@onready var tormentorBeam = $TormentorBeam
@onready var beamEndParticle = $BeamEndParticle
@onready var beamStartParticle = $BeamStartParticle
var _createdDueToFullSync = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	beamNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	beamNoise.seed = UID
	position = path.curve.sample_baked(0) + path.global_position
	var d = position.x - (path.curve.sample_baked(50).x + path.global_position.x)
	lastDelta = - d
	setFlip(d > 0.0)
	$Sprite2D.play("walk")
	updateHitboxState()
	$Sprite2D.speed_scale = speedModifier
	$EnterSound.startSound()

	random = RandomNumberGenerator.new()
	random.seed = UID

func subProcess(delta):
	if walking:



		var speedMod: float



		if ($Sprite2D.frame >= 4 and $Sprite2D.frame <= 6) or ($Sprite2D.frame >= 9 and $Sprite2D.frame <= 11):
			speedMod = 1.5

		elif $Sprite2D.frame == 3 or $Sprite2D.frame == 8 or $Sprite2D.frame == 0:
			speedMod = 1.0
		else:
			speedMod = 0.0
		progress += delta * Data.of("tormentor.speed") * $Sprite2D.speed_scale * speedMod
		var cp = meleeTarget.curve.get_closest_point($HitPosition.global_position)
		if sign(lastDelta) != sign(cp.x - $HitPosition.global_position.x):
			phase = Phase.TRANSFORM_TO_BEAM
			animation("transform_to_beam")
			walking = false
		else:
			position = path.curve.sample_baked(progress) + path.global_position
	elif beaming:
		damageSum += Data.of("tormentor.damage") * delta
		if damageSum >= damageUnit:
			damageSum -= damageUnit
			Level.domesByTeamId[teamId].requestBeamDamage(damageUnit * damageModifier, beamEndParticle.global_position, self)
			InputSystem.teamShake(teamId, 20, 0.2, 8)

		var noiseSpeed = 50.0
		if random.randf() > 0.9:
			noiseSpeed = 1500.0
		beamNoiseTime += delta * noiseSpeed

		phase = Phase.BEAM
		var newTarget: Vector2 = meleeTarget.curve.sample_baked(meleeTargetLength * (beamNoise.get_noise_1d(beamNoiseTime) * 0.5 + 0.5))
		tormentorBeam.target = lerp(tormentorBeam.target, newTarget, delta * 24.0)
		tormentorBeam.show()
		beamEndParticle.global_transform = tormentorBeam.end.global_transform
		beamEndParticle.emitting = true
		beamStartParticle.emitting = true


func onGameLost():
	if currentHealth <= 0:
		return
	if walking:
		leaving = true
		animation("walk")
		$Sprite2D.speed_scale = 0.9 + random.randf() * 0.5
		setFlip( not $Sprite2D.flip_h)
	else:
		animateDeath()

func animateDeath():
	setBeaming(false)
	if phase == Phase.BEAM:
		animation("die_beam")
		phase = Phase.DIE
		return
	phase = Phase.DIE
	if walking:
		animation("die_walk")
	else:
		animation("die_upright")
	$DieSound.startSound()



func setBeaming(value: bool):
	beaming = value
	if beaming:
		animation("beam")
		$BeamSound.startSound()
		$BeamStartSound.startSound()
		meleeTargetLength = meleeTarget.curve.get_baked_length()
	else:
		tormentorBeam.hide()
		beamEndParticle.emitting = false
		beamStartParticle.emitting = false
		$BeamSound.stop()

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.animation == "die_beam":
		animateDeath()
	elif $Sprite2D.animation == "beam_hit" or $Sprite2D.animation == "transform_to_beam":
		setBeaming(true)
	elif $Sprite2D.animation == "die_upright":
		super.removeFreeBlocker()
	elif $Sprite2D.animation == "die_walk":
		super.removeFreeBlocker()


func _on_Sprite_frame_changed():
	match $Sprite2D.animation:
		"transform_to_beam":
			currentHealth = min(currentHealth, maxHealth * (1.0 - $Sprite2D.frame / 53.0))
			if $Sprite2D.frame == 5:
				$TransformSound.startSound()

				minStunLevel = 1.0
				stunPriority = 0
			elif $Sprite2D.frame == 10:
				hitboxToEnable.append($HitboxBeam)
			elif $Sprite2D.frame == 22:
				hitboxToDisable.append($HitboxDefault)

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var moveType: String = Data.of("tormentor.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())


	var moveType = Data.of("tormentor.movetype")
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]

	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_u8(phase)
	stream.encode_bool(walking)
	stream.encode_bool(beaming)
	stream.encode_float(damageSum)
	stream.encode_float(meleeTargetLength)
	stream.encode_float(beamNoiseTime)
	stream.encode_float(progress)
	stream.encode_float(lastDelta)
	stream.encode_float(goalProgress)
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_s32(pathIndex)
	stream.encode_s32(lastWalkFrame)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	phase = stream.decode_u8()
	walking = stream.decode_bool()
	beaming = stream.decode_bool()
	damageSum = stream.decode_float()
	meleeTargetLength = stream.decode_float()
	beamNoiseTime = stream.decode_float()
	progress = stream.decode_float()
	lastDelta = stream.decode_float()
	goalProgress = stream.decode_float()
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	pathIndex = stream.decode_s32()
	lastWalkFrame = stream.decode_s32()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	Utils.decode_animated_sprite2d_state(stream, sprite)

	var moveType = Data.of("tormentor.movetype")
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
	beamNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	beamNoise.seed = UID
