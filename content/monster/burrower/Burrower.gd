class_name Burrower
extends "res://content/monster/Monster.gd"


enum Phase{DROP, MOVE, BURROW, BURROWING, PUPATE, DIE, START_MOVING}

const DOWN_DURATION: float = 2.0

var phase: int = Phase.MOVE

var path: Path2D
var target: Vector2
var variant: String
var progress: = 0.0
var dropTargetPos: Vector2
var moveBeforeBurrowDuration: float
var minDistanceToDome: float
var offset: Vector2
var speedScale: float
var peakRange: = Vector2(70, 100)
var monsterWithin: = Monster.Type.TICK
var distanceSinceLastSlimeDrop: float
var nextSlimeDropDist: = 20.0
var lastPos: = Vector2.ZERO
var eggGrowth: = 0.0
var eggGrowthSpeed: float

var random: RandomNumberGenerator
var pathIndex: int
var _createdDueToFullSync: bool = false
var _initSyncMoveTell: float = 0.0
var _initSyncYDropTarget: float = 0.0

func init():
	if _createdDueToFullSync:
		_init_full_sync()
		return
	supports_full_sync = true
	if phase == Phase.DROP:
		animation("move")
		setFlip(dropTargetPos.x < position.x)
		var peakOffset: = random.randf_range(peakRange.x, peakRange.y)
		var peakY: = position.y - peakOffset
		var timeToPeak: = peakOffset * 0.005
		_initSyncYDropTarget = dropTargetPos.y + offset.y
		moveTween.interpolate_property(self, "position:x", position.x, dropTargetPos.x, DOWN_DURATION + timeToPeak, Tween.TRANS_LINEAR, Tween.EASE_IN)
		moveTween.interpolate_property(self, "position:y", position.y, peakY, timeToPeak, Tween.TRANS_QUAD, Tween.EASE_OUT)
		moveTween.interpolate_property(self, "position:y", peakY, _initSyncYDropTarget, DOWN_DURATION, Tween.TRANS_QUAD, Tween.EASE_IN, timeToPeak)
		moveTween.interpolate_callback(self, 0.5, "setFlip", position.x > 0)
		moveTween.interpolate_callback(self, 2.0, "hitGround")
		moveTween.start()
	else:
		startMoving()
		moveBeforeBurrowDuration = 9999
		offset = Vector2(0, random.randf_range(-5, 5))
		variant = CONST.LEFT if position.x < 0 else CONST.RIGHT
	speedScale = random.randf_range(0.8, 1.2)
	speedModifier *= speedScale
	minDistanceToDome = random.randf_range(180, 300)
	updateHitboxState()

func _init_full_sync() -> void :

	var time_left: float = DOWN_DURATION - _initSyncMoveTell
	if time_left >= 0.0 and phase == Phase.DROP:
		setFlip(position.x > 0)
		moveTween.interpolate_property(self, "position:x", position.x, dropTargetPos.x, time_left, Tween.TRANS_LINEAR, Tween.EASE_IN)
		moveTween.interpolate_property(self, "position:y", position.y, _initSyncYDropTarget, time_left, Tween.TRANS_QUAD, Tween.EASE_OUT)
		moveTween.interpolate_callback(self, time_left, "hitGround")
		moveTween.start()
	elif phase == Phase.MOVE:
		startMoving()

func _ready():
	super._ready()
	$Egg.set_material($Sprite2D.material)

func subProcess(delta: float):
	match phase:
		Phase.DROP:
			var dropAngle: float = lastPos.direction_to(position).angle()
			$Sprite2D.rotation = dropAngle if not $Sprite2D.flip_h else dropAngle + PI
			distanceSinceLastSlimeDrop += position.distance_to(lastPos)
			if distanceSinceLastSlimeDrop >= nextSlimeDropDist:
				nextSlimeDropDist = random.randf_range(20.0, 80.0)
				distanceSinceLastSlimeDrop = 0.0
				spawnSlime(1)
			lastPos = position
		Phase.MOVE:
			progress += delta * Data.of("burrower.speed") * $Sprite2D.speed_scale
			moveBeforeBurrowDuration -= delta
			if abs(Utils.get_position_relative_to_dome(global_position, teamId).x) <= minDistanceToDome or moveBeforeBurrowDuration <= 0:
				phase = Phase.BURROW
			else:
				position = path.curve.sample_baked(progress) + path.global_position + offset
		Phase.BURROW:
			phase = Phase.BURROWING
			$BurrowSound.startSound()
			animation("burrow")
		Phase.PUPATE:
			$Egg.show()
			eggGrowth += delta * eggGrowthSpeed
			if eggGrowth >= 0.7:
				var rotMin: float = -0.4 if position.x < 0 else -0.9
				var rotMax: float = 0.9 if position.x < 0 else 0.4
				spawnSlime(7, rotMin, rotMax, Color("#0006B4"), 70, 120, position, 4.0)
				spawnSlime(4, rotMin, rotMax, Color("#10ECB4"), 70, 180, position, 4.0)
				$Egg.hide()
				$ExplodeSound.startSound()
				$Sprite2D.hide()
				spawnMonster()
				removeFreeBlocker()
				die()
				phase = Phase.DIE
			else:
				$Egg.size = eggGrowth
		Phase.DIE:
			removeFreeBlocker()

func spawnSlime(amount, rotationMin: = -0.3, rotationMax: = 0.3, color: = Color("#0006B4"), speed_min: = 30.0, speed_max: = 70.0, pos: = position, randPos: = 0.0):
	for i in amount:
		var new_slime = preload("res://content/effects/monster/SlimeExplosion.tscn").instantiate()
		new_slime.styleColor = color
		new_slime.position = pos + Vector2.RIGHT.rotated(random.randf() * PI) * randPos
		get_parent().add_child(new_slime)
		new_slime.apply_central_impulse(Vector2.UP.rotated(random.randf_range(rotationMin, rotationMax)) * random.randf_range(speed_min, speed_max))

func hitGround():
	$Sprite2D.rotation = 0.0
	$LandSound.startSound()
	if abs(global_position.x) <= minDistanceToDome or moveBeforeBurrowDuration <= 0:
		phase = Phase.BURROW
	else:
		startMoving()

func animateDeath():
	$Egg.hide()
	$Sprite2D.hide()
	spawnSlime(8, -0.7, 0.7, Color("#0006B4"), 70, 180, position, 6.0)
	$DieSound.startSound()
	removeFreeBlocker()

func startMoving():
	phase = Phase.MOVE
	$Sprite2D.rotation = 0.0
	animation("move")
	position = path.curve.sample_baked(progress) + path.global_position + offset
	var d = position.x - (path.curve.sample_baked(progress + 50).x + path.global_position.x)
	setFlip(d > 0.0)
	$Sprite2D.frame = random.randi() % $Sprite2D.sprite_frames.get_frame_count("move")
	spawnSlime(6, -0.8, 0.8, Color("#0006B4"), 60.0, 180.0)

func onGameLost():
	if currentHealth > 0:
		leaving = true
		if phase == Phase.MOVE:
			animation("move")
			$Sprite2D.speed_scale = 0.9 + random.randf() * 0.5
			setFlip( not $Sprite2D.flip_h)
		else:
			if not dead:
				die()
				animateDeath()
				phase = Phase.DIE

func leave(delta: float):
	if phase == Phase.MOVE:
		if $Sprite2D.flip_h:
			position.x -= Data.of("burrower.speed") * delta
		else:
			position.x += Data.of("burrower.speed") * delta

func _on_Sprite_animation_finished():
	match $Sprite2D.animation:
		"burrow":
			animation("pupate")
			phase = Phase.PUPATE
		"die":
			removeFreeBlocker()
			die()
			phase = Phase.DIE

func spawnMonster():
	if not multiplayer.is_server():
		return

	match monsterWithin:
		Monster.Type.WALKER:
			var monsterType: = Monster.Type.WALKER
			var spawnData: = Walker.get_spawn_data(variant, teamId, pathIndex, progress, Monster.Type.BLOATER)
			Level.monstersByTeamId[teamId].monsterSynchronizer.network_spawn(monsterType, spawnData, teamId)
		_:
			push_warning("Burrower with an unexpected monster within tried to spawn.")
			return

func _on_explode_sound_sound_duration_elapsed() -> void :
	removeFreeBlocker()

static func get_spawn_data(variant: String, teamId: String, monsterWithin: int, damageSource: int, spawnFromMonsterPosition: Vector2, spawnPosition: Vector2, zIndex: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))

	var moveType: String = Data.of("burrower.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)

	stream.encode_u8(monsterWithin)
	stream.encode_u8(damageSource)
	stream.encode_vector2(spawnFromMonsterPosition)
	stream.encode_vector2(spawnPosition)
	stream.encode_u32(zIndex)

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())

	var moveType = Data.of("burrower.movetype")
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

	monsterWithin = stream.decode_u8() as Monster.Type
	var damageSourceInt = stream.decode_u8()
	var spawnFromMonsterPosition: = stream.decode_vector2()
	var spawnPosition: = stream.decode_vector2()
	z_index = stream.decode_u32()

	random = RandomNumberGenerator.new()
	random.seed = UID

	moveBeforeBurrowDuration = random.randf_range(3.0, 5.0)
	var dome = Level.domesByTeamId[teamId]
	progress = path.curve.get_baked_length() * clamp((1.0 - ((abs(Utils.get_position_relative_to_dome(spawnFromMonsterPosition, teamId).x)\
	- abs(Utils.get_position_relative_to_dome(dome.getMeleeTarget(variant).global_position, teamId).x)) / 550.0)), 0, 1)
	progress += random.randf_range(-70, 70)
	damageSource = "bloater" if damageSourceInt == Monster.Type.BLOATER else ""
	phase = Phase.DROP
	offset = Vector2(0, random.randf_range(-5, 5))
	variant = variant
	peakRange = Vector2(4, 100)
	setFlip(Utils.get_position_relative_to_dome(spawnFromMonsterPosition, teamId).x > 0)
	dropTargetPos = path.curve.sample_baked(progress) + path.global_position
	position = spawnFromMonsterPosition + spawnPosition
	distanceSinceLastSlimeDrop = random.randf() * 20.0
	eggGrowthSpeed = random.randf_range(0.35, 0.55)

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_u8(phase)
	_encode_curve2D(stream, path.curve)
	stream.encode_vector2(target)
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_float(progress)
	stream.encode_vector2(dropTargetPos)
	stream.encode_float(moveBeforeBurrowDuration)
	stream.encode_float(minDistanceToDome)
	stream.encode_vector2(offset)
	stream.encode_float(speedScale)
	stream.encode_vector2(peakRange)
	stream.encode_u8(monsterWithin)
	stream.encode_float(distanceSinceLastSlimeDrop)
	stream.encode_float(nextSlimeDropDist)
	stream.encode_vector2(lastPos)
	stream.encode_float(eggGrowth)
	stream.encode_float(eggGrowthSpeed)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_s32(pathIndex)
	stream.encode_float(moveTween.tell())
	Utils.encode_animated_sprite2d_state(stream, sprite)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	phase = stream.decode_u8()
	var curve: Curve2D = Curve2D.new()
	_decode_curve2D(stream, curve)
	if path == null:
		path = Path2D.new()
	path.curve = curve
	target = stream.decode_vector2()
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	progress = stream.decode_float()
	dropTargetPos = stream.decode_vector2()
	moveBeforeBurrowDuration = stream.decode_float()
	minDistanceToDome = stream.decode_float()
	offset = stream.decode_vector2()
	speedScale = stream.decode_float()
	peakRange = stream.decode_vector2()
	monsterWithin = stream.decode_u8() as Monster.Type
	distanceSinceLastSlimeDrop = stream.decode_float()
	nextSlimeDropDist = stream.decode_float()
	lastPos = stream.decode_vector2()
	eggGrowth = stream.decode_float()
	eggGrowthSpeed = stream.decode_float()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	pathIndex = stream.decode_s32()
	_initSyncMoveTell = stream.decode_float()
	Utils.decode_animated_sprite2d_state(stream, sprite)
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
