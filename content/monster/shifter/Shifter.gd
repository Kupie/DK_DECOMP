class_name Shifter
extends "res://content/monster/Monster.gd"

signal move_finished

enum Phase{SHOOT, TELEPORT, DIE, WAIT}

var projectileTargetProvider
var movePointProvider
var phase: int
var cooldown: = 0.0
var nextSide: String
var teleportsLeft: int
var targetPos: Vector2
var hasNetworkData: = false
var randomShotPosition: Vector2
var nextPhase: int
var _variant: String
var _createdDueToFullSync: bool = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	teleportsLeft = Data.stabilizedRandomInt(2, 3, "shifterteleportations", 4)
	finishTeleport()

func setProviders(movePointProvider, projetileTargetProvider, side: String):
	self.movePointProvider = movePointProvider
	self.projectileTargetProvider = projetileTargetProvider

func subProcess(delta):
	if cooldown > 0.0:
		cooldown -= delta
		return

	match phase:
		Phase.SHOOT:
			pass
		Phase.TELEPORT:
			pass

func leave(delta: float):
	pass

func onGameLost():
	if currentHealth > 0:
		leaving = true
		animation("teleport_start")

func handleFullStun():
	animation("hit")

func stagger():
	$Sprite2D.play("hit")

func resumeAfterStagger():
	startTeleport()

func startTeleport():
	animation("teleport_start")
	phase = Phase.TELEPORT
	$TeleportAwaySound.startSound()

func finishTeleport():
	emit_signal("move_finished")
	animation("teleport_end")
	$TeleportAppearSound.startSound()

	position = targetPos
	lastPosition = position
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)
	teleportsLeft -= 1
	hasNetworkData = false

func spawnShot():
	var p = preload("res://content/monster/shifter/ShifterProjectile.tscn").instantiate()
	p.teamId = teamId
	p.damageSource = damageSource
	p.position = position + $ProjectilePosition.position
	p.origin = position
	p.target = randomShotPosition
	p.damage = Data.of("shifter.damage") * damageModifier
	p.speed = Data.of("shifter.shotspeed")
	get_parent().add_child(p)
	$ShootSound.startSound()

func shoot():
	animation("shoot")
	$ChargingSound.startSound()
	phase = Phase.SHOOT
	hasNetworkData = false

func animateDeath():
	$DieSound.startSound()
	animation("die")
	phase = Phase.DIE

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	match $Sprite2D.animation:
		"teleport_start":
			if leaving:
				removeFreeBlocker()
				removeFreeBlocker()
				visible = false
			else:
				finishTeleport()
		"die":
			removeFreeBlocker()
		"shoot":
			teleportsLeft = Data.stabilizedRandomInt(1, 3, "shifterteleportations", 4)
			networkStartTeleport()
		"teleport_end":
			if multiplayer.is_server():
				if teleportsLeft > 0:
					networkStartTeleport()
				else:
					networkShoot()
			elif hasNetworkData:
				match nextPhase:
					Phase.TELEPORT:
						startTeleport()
					Phase.SHOOT:
						shoot()
			else:
				phase = Phase.WAIT


func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "shoot" and $Sprite2D.frame == 28:
		spawnShot()

func networkStartTeleport() -> void :
	if multiplayer.is_server():
		prepareTeleportData()
		startTeleport()
		sendTeleportData()
	elif hasNetworkData:
		startTeleport()
	else:
		phase = Phase.WAIT

func prepareTeleportData() -> void :
	nextSide = Utils.get_other_side(nextSide)
	targetPos = movePointProvider.assignRandomPoint(nextSide, self).global_position

func sendTeleportData() -> void :
	var stream: = PackedByteStream.new()
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))
	stream.encode_vector2(targetPos)

	networkPhaseChanged.emit(Phase.TELEPORT, stream.data)

func networkShoot() -> void :
	if multiplayer.is_server():
		prepareShootData()
		shoot()
		sendShootData()
	elif hasNetworkData:
		shoot()
	else:
		phase = Phase.WAIT

func prepareShootData() -> void :
	randomShotPosition = projectileTargetProvider.getRandom(targetPos) + Vector2(8 - randi() % 16, 8 - randi() % 16)

func sendShootData() -> void :
	var stream: = PackedByteStream.new()
	stream.encode_vector2(randomShotPosition)

	networkPhaseChanged.emit(Phase.SHOOT, stream.data)

func remote_set_phase(_phase: int, buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	match _phase:
		Phase.TELEPORT:
			nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
			targetPos = stream.decode_vector2()
		Phase.SHOOT:
			randomShotPosition = stream.decode_vector2()

	nextPhase = _phase
	hasNetworkData = true

	if phase == Phase.WAIT:
		match _phase:
			Phase.TELEPORT:
				startTeleport()
			Phase.SHOOT:
				shoot()

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	var movePointProvider = Level.worldsByTeamId[teamId].getFlyerPathProvider()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var spawnType = Data.of("shifter.spawnpoint") + "_" + variant
	var spawnPosition: Vector2 = movePointProvider.getSpawn(spawnType).global_position
	stream.encode_vector2(spawnPosition)


	var nextSide: = Utils.get_other_side(variant)
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))

	var point: Marker2D = movePointProvider.getRandomPoint(nextSide)
	var targetPos: Vector2 = point.global_position
	stream.encode_vector2(targetPos)
	stream.encode_u8(movePointProvider.getPointIndex(point, nextSide))

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
	phase = Phase.TELEPORT
	nextPhase = Phase.TELEPORT

	movePointProvider.assignPointOccupation(movePointProvider.getPoint(pointIndex, nextSide), self)

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_bool(Utils.get_side_bool_from_string(_variant))
	stream.encode_u8(phase)
	stream.encode_float(cooldown)
	stream.encode_var(nextSide)
	stream.encode_s16(teleportsLeft)
	stream.encode_vector2(targetPos)
	stream.encode_vector2(randomShotPosition)
	stream.encode_var(nextPhase)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	_variant = Utils.get_side_string_from_bool(stream.decode_bool())
	phase = stream.decode_u8()
	cooldown = stream.decode_float()
	nextSide = stream.decode_var()
	teleportsLeft = stream.decode_s16()
	targetPos = stream.decode_vector2()
	randomShotPosition = stream.decode_vector2()
	nextPhase = stream.decode_var()
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	Utils.decode_animated_sprite2d_state(stream, sprite)
	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), Level.domesByTeamId[teamId].getProjectileTargetProvider(), _variant)
