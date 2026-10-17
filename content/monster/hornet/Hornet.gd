class_name Hornet
extends "res://content/monster/Monster.gd"

enum Phase{ENTER, ATTACK, START_CHANGE_POSITION, CHANGE_POSITION, END_CHANGE_POSITION, DIE, IDLE, WAIT}

var movePointProvider
var meleeTargetProvider
var nextMovementPositions: = []
var currentMovementPositions: = []
var currentMovementProgress: = 0.0
var remainingStings: = 0
var remainingFlyCycles: = 0

var phase: int = Phase.ENTER
var averagedMoveDelta: = 0.0
var movePauseTimer: = 0.0

var movementNoise: = FastNoiseLite.new()
var move_noise_time: = randf() * 1000.0

var nextSide: String
var meleeTarget
var beforeAttack: = true

var random: RandomNumberGenerator
var movePauseDurations: Array[float]
var hasNetworkData: bool = false
var _variant: String
var _createdDueToFullSync: bool = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	movementNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	movementNoise.seed = UID
	move_noise_time = random.randf() * 1000.0
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)
	startMove()


func setProviders(movePointProvider, meleeTargetProvider, side: String):
	self.movePointProvider = movePointProvider
	self.meleeTargetProvider = meleeTargetProvider
	nextSide = side

func startMove(delayMod: = 1.0):
	var movePauseDuration: = movePauseDurations[nextMovementPositions.size() - 1]
	movePauseTimer = delayMod * movePauseDuration
	phase = Phase.START_CHANGE_POSITION
	var endPosition: Vector2 = nextMovementPositions.front()
	currentMovementPositions = [position, endPosition]
	currentMovementProgress = 0.0
	moveTween.interpolate_property(self, "currentMovementProgress", 0.0, -0.1, 0.1, Tween.TRANS_SINE, Tween.EASE_OUT)
	animation("change_position_start")
	hasNetworkData = false

func endMove():
	sprite.rotation = 0.0
	phase = Phase.END_CHANGE_POSITION
	animation("change_position_end")
	nextMovementPositions.pop_front()

func executeMove():
	phase = Phase.CHANGE_POSITION
	beforeAttack = true

	$Sprite2D.speed_scale = speedModifier
	var duration: float = (position.distance_to(currentMovementPositions[1]) / (Data.of("hornet.speed") * speedModifier)) * 0.3
	moveTween.interpolate_property(self, "currentMovementProgress", -0.1, 1.0, duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	moveTween.interpolate_callback(self, duration, "endMove")
	moveTween.start()

	phase = Phase.CHANGE_POSITION
	animation("change_position_loop")
	$StepSound.startSound()
	setFlip(nextSide == CONST.RIGHT)
	var dir_angle: float = currentMovementPositions[0].direction_to(currentMovementPositions[1]).angle()
	if sprite.flip_h:
		sprite.rotation = dir_angle - 2.6
	else:
		sprite.rotation = dir_angle - 0.7


func createMovementPositions(steps: int, switchSides: bool):
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(nextSide).curve
	var fixedStingPos = find_child("StingPosition").position
	fixedStingPos.x *= -1 if switchSides else 1
	var targetPos: Vector2 = meleeTarget.sample_baked(meleeTarget.get_baked_length() * random.randf_range(0.5, 1.0)) + Vector2(4 - random.randi() % 8, 4 - random.randi() % 8) - fixedStingPos
	var dir: float = position.direction_to(targetPos).angle()
	if steps == 0:
		nextMovementPositions.append(targetPos)
	else:
		for i in steps:
			var nextPosition = lerp(position, targetPos, float(i + 1) / float(steps))
			if i + 1 < steps:
				nextPosition += Vector2.UP.rotated(dir) * random.randf_range(-40, 40)
			nextMovementPositions.append(nextPosition)


func onGameLost():
	if currentHealth > 0:
		phase = Phase.ENTER
		moveTween.stop_all()
		moveTween.remove_all()
		leaving = true
		setFlip( not sprite.flip_h)

func leave(delta: float):
	position.y -= delta * 30
	var positionRelativeToDome: = Utils.get_position_relative_to_dome(position, teamId)
	position.x += delta * positionRelativeToDome.x * 0.2
	animation("fly")

func startAttacking():
	beforeAttack = false
	$PrepareSound.startSound()
	phase = Phase.ATTACK
	if remainingStings > 1:
		animation("sting_quick")
	else:
		animation("sting")

func animateDeath():
	$DieSound.startSound()
	animation("die")
	phase = Phase.DIE

func subProcess(delta):
	if phase == Phase.ENTER:
		movePauseTimer -= delta
	elif phase == Phase.IDLE:
		movePauseTimer -= delta
		move_noise_time += delta * 6.0
		var noise = Vector2(movementNoise.get_noise_1d(move_noise_time), sin(move_noise_time))
		sprite.position = lerp(sprite.position, noise * 3.0, delta * 5.0)
	else:
		sprite.position = lerp(sprite.position, Vector2.ZERO, delta * 5.0)

	if phase == Phase.ENTER or phase == Phase.CHANGE_POSITION or phase == Phase.START_CHANGE_POSITION:
		var oldPos: = position
		if not currentMovementPositions.is_empty():
			position = lerp(currentMovementPositions[0], currentMovementPositions[1], currentMovementProgress)
		if averagedMoveDelta == 0.0:
			averagedMoveDelta = (position - oldPos).length()
		else:
			averagedMoveDelta = averagedMoveDelta * (1.0 - delta) + (position - oldPos).length() * delta

func handleFullStun():
	animation("hit")
	moveTween.stop_all()
	moveTween.remove_all()

func stagger():
	animation("hit")

func resumeAfterStagger():
	match phase:
		Phase.ENTER:
			animation("fly")
		Phase.CHANGE_POSITION:
			currentMovementPositions[0] = position
			executeMove()
		_:
			remainingFlyCycles += 1
			phase = Phase.IDLE
			animation("fly")

func hitDome():
	remainingStings -= 1
	Level.domesByTeamId[teamId].requestMeleeDamage(Data.of("hornet.damage") * damageModifier, $StingPosition.global_position, self)
	InputSystem.shake(40, 0.3, 8, $StingPosition.global_position)


func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if sprite.animation == "die":
		removeFreeBlocker()
	elif sprite.animation == "sting" or sprite.animation == "sting_quick":
		if remainingStings > 1:
			animation("sting_quick")
		elif remainingStings == 1:
			animation("sting")
		else:
			phase = Phase.IDLE
			animation("fly")
	elif sprite.animation == "fly" and phase == Phase.IDLE:
		if not nextMovementPositions.is_empty():
			if movePauseTimer <= 0.0:
				startMove()
		else:
			if remainingFlyCycles <= 0 and beforeAttack:




				startAttacking()
			elif remainingFlyCycles <= 0 and not beforeAttack:
				if multiplayer.is_server():
					prepareMoveData()
					startMove(0.2)
					sendMoveData()
				elif hasNetworkData:
					startMove(0.2)
				else:
					phase = Phase.WAIT
			else:
				remainingFlyCycles -= 1
	elif sprite.animation == "change_position_start":
		executeMove()
	elif sprite.animation == "change_position_end":
		phase = Phase.IDLE
		animation("fly")

func _on_Sprite_frame_changed():
	if sprite.animation == "sting":
		if sprite.frame == 6:
			hitDome()
			InputSystem.shake(Data.of("hornet.damage") * damageModifier, 0.1)
			$StingSound.startSound()
	elif sprite.animation == "sting_quick":
		if sprite.frame == 3:
			hitDome()
			InputSystem.shake(Data.of("hornet.damage") * damageModifier, 0.1)
			$StingSound.startSound()

func prepareMoveData() -> void :
	nextSide = Utils.get_other_side(nextSide)
	createMovementPositions(1, true)
	movePauseDurations = [Data.stabilizedRandomFloat(0.6, 1.2, "hornetmove", 3.0)]
	remainingStings = getRandomRemainingStings()
	remainingFlyCycles = getRandomRemainingFlyCycles()

func sendMoveData() -> void :
	var stream: = PackedByteStream.new()

	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))
	stream.encode_vector2(nextMovementPositions[0])
	stream.encode_float(movePauseDurations[0])
	stream.encode_u8(remainingStings)
	stream.encode_u8(remainingFlyCycles)

	networkPhaseChanged.emit(Phase.START_CHANGE_POSITION, stream.data)

static func getRandomRemainingFlyCycles() -> int:
	return 1 + randi() % 2

static func getRandomRemainingStings() -> int:
	return Data.stabilizedRandomInt(3, 5, "hornetattacks", 10)

func remote_set_phase(_phase: int, buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	match _phase:
		Phase.START_CHANGE_POSITION:
			nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
			nextMovementPositions = [stream.decode_vector2()]
			movePauseDurations = [stream.decode_float()]
			remainingStings = stream.decode_u8()
			remainingFlyCycles = stream.decode_u8()
			hasNetworkData = true
		_:
			push_error("Hornet only supports setting start_change_position phase remotely")

	if phase == Phase.WAIT:
		startMove()

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	var movePointProvider = Level.worldsByTeamId[teamId].getFlyerPathProvider()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))

	var spawnType: String = Data.of("hornet.spawnpoint") + "_" + variant
	var spawnPosition: Vector2 = movePointProvider.getSpawn(spawnType).global_position
	stream.encode_vector2(spawnPosition)

	for i in range(5):
		stream.encode_float(Data.stabilizedRandomFloat(0.6, 1.2, "hornetmove", 3.0))

	stream.encode_u8(getRandomRemainingStings())
	stream.encode_u8(getRandomRemainingFlyCycles())

	return stream.data

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)


	var onRightSide: = stream.decode_bool()
	_variant = Utils.get_side_string_from_bool(onRightSide)

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), Level.domesByTeamId[teamId].getProjectileTargetProvider(), _variant)

	position = stream.decode_vector2()
	nextSide = _variant

	random = RandomNumberGenerator.new()
	random.seed = UID
	createMovementPositions(5, onRightSide)

	movePauseDurations.resize(5)
	for i in range(5):
		movePauseDurations[i] = stream.decode_float()

	remainingStings = stream.decode_u8()

	remainingFlyCycles = stream.decode_u8()

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()

	stream.encode_u16(nextMovementPositions.size())
	for pos in nextMovementPositions:
		stream.encode_vector2(pos)

	stream.encode_u16(currentMovementPositions.size())
	for pos in currentMovementPositions:
		stream.encode_vector2(pos)

	stream.encode_u16(movePauseDurations.size())
	for duration in movePauseDurations:
		stream.encode_float(duration)

	stream.encode_float(currentMovementProgress)
	stream.encode_s32(remainingStings)
	stream.encode_s32(remainingFlyCycles)
	stream.encode_u8(phase)
	stream.encode_float(averagedMoveDelta)
	stream.encode_float(movePauseTimer)
	stream.encode_float(move_noise_time)
	stream.encode_bool(Utils.get_side_bool_from_string(nextSide))
	stream.encode_bool(beforeAttack)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_bool(hasNetworkData)
	stream.encode_bool(Utils.get_side_bool_from_string(_variant))

	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)

	var next_count: = stream.decode_u16()
	nextMovementPositions.clear()
	for i in next_count:
		nextMovementPositions.append(stream.decode_vector2())

	var current_count: = stream.decode_u16()
	currentMovementPositions.clear()
	for i in current_count:
		currentMovementPositions.append(stream.decode_vector2())

	var move_pause_duration_size: int = stream.decode_u16()
	for duration_idx in move_pause_duration_size:
		movePauseDurations.append(stream.decode_float())

	currentMovementProgress = stream.decode_float()
	remainingStings = stream.decode_s32()
	remainingFlyCycles = stream.decode_s32()
	phase = stream.decode_u8()
	averagedMoveDelta = stream.decode_float()
	movePauseTimer = stream.decode_float()
	move_noise_time = stream.decode_float()
	nextSide = Utils.get_side_string_from_bool(stream.decode_bool())
	beforeAttack = stream.decode_bool()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	hasNetworkData = stream.decode_bool()
	_variant = Utils.get_side_string_from_bool(stream.decode_bool())
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	Utils.decode_animated_sprite2d_state(stream, sprite)

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), Level.domesByTeamId[teamId].getProjectileTargetProvider(), _variant)
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(nextSide).curve
	movementNoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	movementNoise.seed = UID
