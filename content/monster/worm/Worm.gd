class_name Worm
extends "res://content/monster/Monster.gd"

enum Phase{APPEAR, EMERGE, SHOOT, BURROW, DIE, WAIT}

var phase: int = Phase.APPEAR
var projectileTargetProvider
var path: Path2D

var cooldown: = 0.0
var didShoot: = false

var variant: String
var pathIndex: int
var hasNetworkData: = false
var cooldowns: Array[float]
var remoteCooldowns: Array[float]
var randomShotPosition: Vector2
var _createdDueToFullSync: bool = false

func init():
	if _createdDueToFullSync:
		return
	$Sprite2D.play("appear")
	setHittable(false)
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)
	supports_full_sync = true

func subProcess(delta):
	if cooldown > 0.0:
		cooldown -= delta
		return

	match phase:
		Phase.APPEAR:
			cooldown = cooldowns[phase]
			phase = Phase.EMERGE
		Phase.EMERGE:
			if multiplayer.is_server():
				prepareNextCycleData()
				sendNextCycleData()
			if multiplayer.is_server() or hasNetworkData:
				startEmerge()
			else:
				phase = Phase.WAIT
		Phase.SHOOT:
			if multiplayer.is_server():
				sendShootData()
			animation("shoot")
			cooldown = cooldowns[phase]
			didShoot = false
		Phase.BURROW:
			animation("burrow")
			$BurrowSound.startSound()
			cooldown = cooldowns[phase]
			phase = Phase.EMERGE

func startEmerge() -> void :
	animation("emerge")
	$EmergeSound.startSound()

	if not multiplayer.is_server():
		cooldowns = remoteCooldowns.duplicate()

	cooldown = cooldowns[phase]
	phase = Phase.SHOOT
	hasNetworkData = false

func handleFullStun():
	animation("hit")

func stagger():
	animation("hit")

func resumeAfterStagger():
	cooldown = 0.0
	if didShoot and phase == Phase.SHOOT:
		phase = Phase.BURROW

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	match $Sprite2D.animation:
		"shoot":
			phase = Phase.BURROW
			animation("idle")
		"die":
			super.removeFreeBlocker()
		"emerge":
			animation("idle")

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "burrow" and $Sprite2D.frame == 9:
		setHittable(false)
	elif $Sprite2D.animation == "emerge" and $Sprite2D.frame == 4:
		setHittable(true)
	elif $Sprite2D.animation == "shoot" and $Sprite2D.frame == 7:
		$SpitSound.startSound()
		didShoot = true

		if not multiplayer.is_server():
			return

		var monsterType: = Monster.Type.WORM_ROCK
		var spawnData: = WormRock.get_spawn_data(variant, teamId, $Sprite2D.flip_h, $RockSpawnPosition.position + position, randomShotPosition, damageSource)
		Level.monstersByTeamId[teamId].monsterSynchronizer.network_spawn(monsterType, spawnData, teamId)

func leave(delta: float):
	if phase != Phase.DIE:
		phase = Phase.DIE
		animation("burrow")

func animateDeath():
	phase = Phase.DIE
	$DieSound.startSound()
	animation("die")

func prepareNextCycleData() -> void :
	setCooldownRandomFloats(cooldowns)
	randomShotPosition = projectileTargetProvider.getRandom(global_position)

func sendNextCycleData() -> void :
	var stream: = PackedByteStream.new()
	for cooldown in cooldowns:
		stream.encode_float(cooldown)
	stream.encode_vector2(randomShotPosition)

	networkPhaseChanged.emit(Phase.EMERGE, stream.data)

func sendShootData() -> void :
	var stream: = PackedByteStream.new()
	stream.encode_float(cooldowns[Phase.SHOOT])
	stream.encode_float(cooldowns[Phase.BURROW])
	stream.encode_vector2(randomShotPosition)

	networkPhaseChanged.emit(Phase.SHOOT, stream.data)

func remote_set_phase(_phase: int, buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	match _phase:
		Phase.EMERGE:
			for i: int in range(4):
				remoteCooldowns[i] = stream.decode_float()
			randomShotPosition = stream.decode_vector2()
			hasNetworkData = true
		Phase.SHOOT:
			remoteCooldowns[Phase.SHOOT] = stream.decode_float()
			remoteCooldowns[Phase.BURROW] = stream.decode_float()
			randomShotPosition = stream.decode_vector2()
			cooldown = 0
			phase = _phase

	if phase == Phase.WAIT:
		phase = Phase.EMERGE
		startEmerge()

static func setCooldownRandomFloats(cooldowns: Array[float]) -> void :
	cooldowns.resize(4)
	cooldowns[Phase.APPEAR] = Data.stabilizedRandomFloat(2, 4, "wormappear", 4)
	cooldowns[Phase.EMERGE] = Data.stabilizedRandomFloat(2, 4, "wormemerge", 4)
	cooldowns[Phase.SHOOT] = Data.stabilizedRandomFloat(2, 4, "wormshoot", 4)
	cooldowns[Phase.BURROW] = Data.stabilizedRandomFloat(3, 6, "wormburrow", 6)

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))

	var moveType: String = Data.of("worm.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)


	var randomPathPercent: = randf_range(0.2, 0.4)
	stream.encode_float(randomPathPercent)

	var cooldowns: Array[float]
	setCooldownRandomFloats(cooldowns)

	for cooldown: float in cooldowns:
		stream.encode_float(cooldown)

	var path: Path2D = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	var pos: Vector2 = path.curve.sample_baked(path.curve.get_baked_length() * randomPathPercent) + path.global_position
	var randomShotPosition: Vector2 = Level.domesByTeamId[teamId].getProjectileTargetProvider().getRandom(pos)
	stream.encode_vector2(randomShotPosition)

	return stream.data

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	projectileTargetProvider = Level.domesByTeamId[teamId].getProjectileTargetProvider()

	variant = Utils.get_side_string_from_bool(stream.decode_bool())

	pathIndex = stream.decode_u32()
	var moveType: String = Data.of("worm.movetype")
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

	var randomPathPercent: = stream.decode_float()
	global_position = path.curve.sample_baked(path.curve.get_baked_length() * randomPathPercent) + path.global_position

	cooldowns.resize(4)
	remoteCooldowns.resize(4)
	for i: int in range(4):
		var newCooldown: = stream.decode_float()
		cooldowns[i] = newCooldown
		remoteCooldowns[i] = newCooldown

	randomShotPosition = stream.decode_vector2()

	hasNetworkData = true

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_u8(phase)
	stream.encode_float(cooldown)
	stream.encode_bool(didShoot)
	stream.encode_s32(pathIndex)
	stream.encode_u8(cooldowns.size())
	for cooldown: float in cooldowns:
		stream.encode_float(cooldown)
	stream.encode_u8(remoteCooldowns.size())
	for cooldown: float in remoteCooldowns:
		stream.encode_float(cooldown)
	stream.encode_vector2(randomShotPosition)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream: PackedByteStream = _apply_base_full_sync(buffer)
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	phase = stream.decode_u8()
	cooldown = stream.decode_float()
	didShoot = stream.decode_bool()
	pathIndex = stream.decode_s32()
	var cooldowns_size: int = stream.decode_u8()
	cooldowns.clear()
	cooldowns.resize(cooldowns_size)
	for cooldown_idx in cooldowns_size:
		cooldowns.append(stream.decode_float())
	var remote_cooldowns_size: int = stream.decode_u8()
	remoteCooldowns.clear()
	remoteCooldowns.resize(remote_cooldowns_size)
	for cooldown_idx in remote_cooldowns_size:
		remoteCooldowns.append(stream.decode_float())
	randomShotPosition = stream.decode_vector2()
	Utils.decode_animated_sprite2d_state(stream, sprite)
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)
