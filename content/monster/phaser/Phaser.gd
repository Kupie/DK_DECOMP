class_name Phaser
extends "res://content/monster/Monster.gd"

const TELEPORTS_TO_ATTACK: = 7
const FLICKERS_PER_TELEPORT: = 1

signal move_finished

enum Phase{MOVE_IN, ATTACK, IDLE, DIE, WAIT}

var projetileTargetProvider
var movePointProvider
var phase: int
var cooldown: = 0.0
var nextSide: String
var teleportsLeft: = -1
var path: Path2D
var meleeTarget: Path2D
var targetPos: Vector2
var meleeTargetProvider

var offsetHigh: = true
var attacks: = 0

var offset: Vector2

var variant: String
var teleportPositions: Array[Vector2]
var pathIndex: int
var random: RandomNumberGenerator
var cooldownDurations: Array[float]
var hasNetworkData: = false
var _createdDueToFullSync: = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	teleportsLeft = TELEPORTS_TO_ATTACK * FLICKERS_PER_TELEPORT
	cooldown = 0.1
	phase = Phase.MOVE_IN
	setHittable(false)
	var dome: Dome = Level.domesByTeamId[teamId]
	position = dome.global_position + Vector2.UP * -2000
	$AppearSound.startSound()

func generateTeleportPositions() -> void :
	var count: = (TELEPORTS_TO_ATTACK * FLICKERS_PER_TELEPORT) + 1
	teleportPositions.clear()
	teleportPositions.resize(count)
	while (count >= 0):
		count -= 1
		offsetHigh = int(count / float(FLICKERS_PER_TELEPORT)) % 2 == 0
		var progress = 1.1 - float(snapped(count, FLICKERS_PER_TELEPORT)) / float(TELEPORTS_TO_ATTACK * FLICKERS_PER_TELEPORT)
		var pos: Vector2 = path.position + path.curve.sample_baked(progress * path.curve.get_baked_length()) - $HitPosition.position + offset

		pos.y -= random.randf_range(110, 160) if offsetHigh else random.randf_range(30, 90)
		pos.x += random.randf_range(-30, 30)
		pos.x = clamp(pos.x, -470, 470)
		teleportPositions[count] = pos

func moveToDome(side: String):
	if teleportsLeft <= 0:
		teleportsLeft = (TELEPORTS_TO_ATTACK * FLICKERS_PER_TELEPORT) + 1
	teleportsLeft -= 1
	var dome: Dome = Level.domesByTeamId[teamId]
	if teleportsLeft > 0:
		var teleportPosition: = teleportPositions[teleportsLeft]
		position = Vector2(dome.global_position.x + teleportPosition.x, teleportPosition.y)
		animation("appear")
		cooldown = 99
		phase = Phase.MOVE_IN
	else:
		var progress = 1.1 - float(snapped(teleportsLeft, FLICKERS_PER_TELEPORT)) / float(TELEPORTS_TO_ATTACK * FLICKERS_PER_TELEPORT)
		var newPosition: Vector2 = path.position + path.curve.sample_baked(progress * path.curve.get_baked_length()) - $HitPosition.position + offset
		position = Vector2(dome.global_position.x + newPosition.x, newPosition.y)
		startAttack()
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)
	if teleportsLeft % FLICKERS_PER_TELEPORT == FLICKERS_PER_TELEPORT - 1:
		$AppearSound.startSound()
	else:
		$AppearQuickSound.startSound()

func startAttack():
	attacks = 1
	phase = Phase.ATTACK
	animation("appear")

func subProcess(delta):
	if cooldown > 0.0:
		cooldown -= delta
		return

	match phase:
		Phase.MOVE_IN:
			moveToDome(nextSide)
		Phase.IDLE:
			playDisappearParticles()
			animation("disappear")
			if teleportsLeft % FLICKERS_PER_TELEPORT == 0:
				cooldown = Data.stabilizedRandomFloat(0.2, 0.4, "phasercooldown", 2)
			phase = Phase.MOVE_IN

func playDisappearParticles():
	$Sprite2D / DisappearParticlesR.emitting = true
	$Sprite2D / DisappearParticlesL.emitting = true
	$Sprite2D / DisappearParticlesR.restart()
	$Sprite2D / DisappearParticlesL.restart()

func leave(delta: float):
	pass

func onGameLost():
	if currentHealth > 0:
		leaving = true
		if phase == Phase.ATTACK:
			playDisappearParticles()
			animation("attack_disappear")
		else:
			playDisappearParticles()
			animation("disappear")

func handleFullStun():
	animation("hit")

func resumeAfterStagger():
	cooldown = 1.0
	playDisappearParticles()
	animation("disappear")

func animateDeath():
	$DieSound.startSound()
	animation("die")
	phase = Phase.DIE

func hitDome():
	var dome = Level.domesByTeamId[teamId]
	dome.requestMeleeDamage(Data.of("phaser.damage") * damageModifier, $HitPosition.global_position, self)
	InputSystem.shake(140, 0.3, 8, $HitPosition.global_position)
	$DomeHitSound.startSound()

func resetAfterAttack():
	teleportsLeft = 1
	phase = Phase.MOVE_IN
	setFlip(nextSide == CONST.RIGHT)

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.frame == 0:
		if not $Sprite2D.is_playing():
			$Sprite2D.play($Sprite2D.animation)
			return

	match $Sprite2D.animation:
		"appear":
			if phase == Phase.ATTACK:
				if attacks > 0:
					$Sprite2D.speed_scale = 1.0
					animation("attack_windup")
				else:
					playDisappearParticles()
					animation("attack_disappear")
			elif phase == Phase.MOVE_IN:
				animation("idle")
				cooldown = cooldownDurations[teleportsLeft - 1]
				phase = Phase.IDLE
		"attack_disappear":
			playDisappearParticles()
			if leaving:
				removeFreeBlocker()
				removeFreeBlocker()
				visible = false
			else:
				if multiplayer.is_server():
					prepareData()
					resetAfterAttack()
					sendData()
				elif hasNetworkData:
					resetAfterAttack()
				else:
					phase = Phase.WAIT
		"attack":
			if attacks > 0:
				$Sprite2D.speed_scale = 1.0
				animation("attack_windup")
			else:
				playDisappearParticles()
				animation("attack_disappear")
		"attack_windup":
			playDisappearParticles()
			animation("attack")
		"die":
			removeFreeBlocker()
		"disappear":
			if leaving:
				removeFreeBlocker()
				removeFreeBlocker()
				visible = false
			elif phase == Phase.ATTACK:
				playDisappearParticles()
				resetAfterAttack()


func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "attack" and $Sprite2D.frame == 1:
		hitDome()
		attacks -= 1
	elif $Sprite2D.animation == "attack_windup" and $Sprite2D.frame == 1:
		$WindupSound.startSound()
	elif $Sprite2D.animation == "attack_disappear" and $Sprite2D.frame == 11:
		setHittable(false)
	elif $Sprite2D.animation == "disappear" and $Sprite2D.frame == 2:
		setHittable(false)
	elif $Sprite2D.animation == "disappear" and $Sprite2D.frame == 0:
		if teleportsLeft % FLICKERS_PER_TELEPORT == 0:
			$DisappearSound.startSound()
	elif $Sprite2D.animation == "appear" and $Sprite2D.frame == 1:
		setHittable(true)
	elif $Sprite2D.animation == "appear" and $Sprite2D.frame == 0:
		$Sprite2D.speed_scale = 1.0 - pow((float(TELEPORTS_TO_ATTACK) / (teleportsLeft + 1)), 2)

func prepareData():
	nextSide = Utils.get_other_side(nextSide)
	cooldown = Data.stabilizedRandomFloat(0.2, 0.8, "phaserattack", 2.0)
	var world = Level.worldsByTeamId[teamId]
	world.freePathOccupation(Data.of("phaser.movetype"), path, self)

	var moveType: String = Data.of("phaser.movetype")
	pathIndex = world.getPathIndex(moveType, nextSide)
	path = world.getPaths(moveType, nextSide)[pathIndex]
	world.assignPathOccupation(moveType, path, self)

func sendData():
	var stream: = PackedByteStream.new()
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))
	stream.encode_float(cooldown)
	stream.encode_u32(pathIndex)

	networkPhaseChanged.emit(Phase.MOVE_IN, stream.data)

func remote_set_phase(_phase: int, buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	match _phase:
		Phase.MOVE_IN:
			nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
			cooldown = stream.decode_float()
			pathIndex = stream.decode_u32()
			var moveType: String = Data.of("phaser.movetype")
			path = Level.worldsByTeamId[teamId].getPaths(moveType, nextSide)[pathIndex]

			hasNetworkData = true
		_:
			push_error("Phaser only supports setting MOVE_IN phase remotely")

	if phase == Phase.WAIT:
		resetAfterAttack()

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))

	var moveType: String = Data.of("phaser.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)

	var count: = (TELEPORTS_TO_ATTACK * FLICKERS_PER_TELEPORT) + 1
	for i in range(count):
		stream.encode_float(Data.stabilizedRandomFloat(0.4, 1.0, "phaserteleport", 2.0))

	return stream.data

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)


	var variant: = Utils.get_side_string_from_bool(stream.decode_bool())

	var moveType = Data.of("phaser.movetype")
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

	var count: = (TELEPORTS_TO_ATTACK * FLICKERS_PER_TELEPORT) + 1
	cooldownDurations.resize(count)
	for i in range(count):
		cooldownDurations[i] = stream.decode_float()

	nextSide = variant

	random = RandomNumberGenerator.new()
	random.seed = UID
	offset = Vector2(0, random.randf_range(-30, 0))
	generateTeleportPositions()

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_u8(phase)
	stream.encode_float(cooldown)
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))
	stream.encode_s16(teleportsLeft)
	stream.encode_vector2(targetPos)
	stream.encode_bool(offsetHigh)
	stream.encode_s32(attacks)
	stream.encode_vector2(offset)
	stream.encode_bool(Utils.get_side_bool_from_string(variant))

	stream.encode_u32(teleportPositions.size())
	for pos in teleportPositions:
		stream.encode_vector2(pos)

	stream.encode_s32(pathIndex)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_u16(cooldownDurations.size())
	for duration in cooldownDurations:
		stream.encode_float(duration)
	stream.encode_bool(hasNetworkData)

	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	phase = stream.decode_u8()
	cooldown = stream.decode_float()
	nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
	teleportsLeft = stream.decode_s16()
	targetPos = stream.decode_vector2()
	offsetHigh = stream.decode_bool()
	attacks = stream.decode_s32()
	offset = stream.decode_vector2()
	variant = Utils.get_side_string_from_bool(stream.decode_bool())

	var tp_count: = stream.decode_u32()
	teleportPositions.clear()
	for i in tp_count:
		teleportPositions.append(stream.decode_vector2())

	pathIndex = stream.decode_s32()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	var cool_down_durations_size: int = stream.decode_u16()
	for duration_idx in cool_down_durations_size:
		cooldownDurations.append(stream.decode_float())
	hasNetworkData = stream.decode_bool()

	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	Utils.decode_animated_sprite2d_state(stream, sprite)

	var moveType = Data.of("phaser.movetype")
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
