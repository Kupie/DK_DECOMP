class_name Breeder
extends "res://content/monster/Monster.gd"

const MOVE_DURATION: float = 1.0

enum Phase{FALLING, APPEAR, BIRTH, IDLE, DIE, ARMOR, WAIT}

var phase: int = Phase.FALLING
var path: Path2D
var nextProtectionHealthThreshold: float

var cooldown: = 0.0
var cooldownFull: = 1.0
var fallingSplatterTick: = 0.0
var nextFallingSplatter: = 0.05
var damageTakenMultiplier: = 1.0

var variant: String
var pathIndex: int
var random: RandomNumberGenerator
var goalPos: Vector2
var nextCooldownFull: = cooldownFull
var nextSpawnCount: = 0
var nextArmorUpCooldown: = 0.0
var nextArmorDownCooldown: = 0.0
var hasNetworkData: = false
var _createdDueToFullSync: bool = false

@onready var eggs: = [ %Eggs1, %Eggs2, %Eggs3]
@onready var eggAttachers: = [
	$EggAttacher1, 
	$EggAttacher2, 
	$EggAttacher3, 
]
@onready var eggAttacherPositions: = [
	$EggAttacher1.position, 
	$EggAttacher2.position, 
	$EggAttacher3.position, 
]


func _ready():
	super._ready()
	for s in eggs:
		s.set_material($Sprite2D.material)

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	animation("falling")
	$LaunchSound.startSound()
	$Sprite2D.rotation = position.direction_to(goalPos).angle()
	moveTween.interpolate_property(self, "position", position, goalPos, MOVE_DURATION)
	moveTween.interpolate_callback(self, MOVE_DURATION, "appear")
	moveTween.start()
	nextProtectionHealthThreshold = maxHealth * 0.7

func appear():
	spawnSlime(12)
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)

	$Sprite2D.rotation = 0.0
	animation("appear")
	$LandSound.startSound()
	phase = Phase.APPEAR

func spawnSlime(amount, rotationRange: = 0.9, color: = Color("#0006B4"), pos: = position):
	if not Options.reducedParticles:
		for i in amount:
			var new_slime = preload("res://content/effects/monster/SlimeExplosion.tscn").instantiate()
			new_slime.styleColor = color
			new_slime.position = pos
			get_parent().add_child(new_slime)
			new_slime.apply_central_impulse(Vector2.UP.rotated(random.randf_range( - rotationRange, rotationRange)) * random.randf_range(80, 240))

func spawnTicks():
	$BirthSound.startSound()
	spawnSlime(24, 0.8, Color("#0006B4"), $TickSpawnPosition.position + position)
	spawnSlime(6, 0.6, Color("#10ECB4"), $TickSpawnPosition.position + position)
	for e in eggs:
		e.hide()

	if Level.monstersByTeamId[teamId].disabled:
		return

	if not multiplayer.is_server():
		return

	for i in nextSpawnCount:
		var monsterType: = Monster.Type.TICK
		var spawnData = Tick.get_spawn_data(variant, teamId, 0, Monster.Type.BREEDER, position, $TickSpawnPosition.position)
		Level.monstersByTeamId[teamId].monsterSynchronizer.network_spawn(monsterType, spawnData, teamId)

func subProcess(delta):
	if phase == Phase.FALLING:
		if fallingSplatterTick >= nextFallingSplatter:
			spawnSlime(random.randi() % 2 + 1, 0.5)
			fallingSplatterTick = 0.0
			nextFallingSplatter = random.randf_range(0.05, 0.1)
		else:
			fallingSplatterTick += delta



	if currentHealth <= nextProtectionHealthThreshold and (phase == Phase.IDLE or phase == Phase.BIRTH):
		cooldown = 999
		for e in eggs:
			e.hide()
		spawnSlime(8, 0.8, Color("#0006B4"), $TickSpawnPosition.position + position)
		spawnSlime(5, 0.6, Color("#10ECB4"), $TickSpawnPosition.position + position)
		animation("armor_up")
		$ArmorUpSound.startSound()
		phase = Phase.ARMOR
		damageTakenMultiplier = 0.2
		nextProtectionHealthThreshold = -1

	if cooldown > 0.0:
		if phase == Phase.IDLE:
			for e in eggs:
				e.size = abs(1.0 - cooldown / cooldownFull) * 0.7
				e.violence = ease(abs(1.0 - cooldown / cooldownFull), 4.5) * 15.0
				e.show()
			for i in eggAttachers.size():
				eggAttachers[i].position.y = eggAttacherPositions[i].y - abs(cooldownFull - cooldown) * 3.0
			animation("idle")
		cooldown -= delta * currentStunLevel
		return

	match phase:
		Phase.IDLE:
			cooldown = 999
			if multiplayer.is_server:
				prepareBirthData()
				startBirth()
				sendBirthData()
			elif hasNetworkData:
				startBirth()
			else:
				phase = Phase.WAIT
		Phase.ARMOR:
			cooldown = 999
			$ArmorDownSound.startSound()
			animation("armor_down")

func prepareBirthData() -> void :
	nextCooldownFull = Data.stabilizedRandomFloat(3, 5, "breeederbirth", 5)
	nextSpawnCount = Data.stabilizedRandomInt(Data.of("breeder.minspawn"), Data.of("breeder.maxspawn"), "breederspawn", 6)

func sendBirthData() -> void :
	var stream = PackedByteStream.new()
	stream.encode_float(nextCooldownFull)
	stream.encode_u8(nextSpawnCount)

	networkPhaseChanged.emit(Phase.BIRTH, stream.data)

func startBirth() -> void :
	animation("birth")
	phase = Phase.BIRTH
	hasNetworkData = false

func remote_set_phase(_phase: int, buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	match _phase:
		Phase.BIRTH:
			nextCooldownFull = stream.decode_float()
			hasNetworkData = true
			if phase == Phase.WAIT:
				startBirth()
		_:
			push_error("Breeder only supports setting birth phase remotely")

func animateDeath():
	for e in eggs:
		e.hide()
	spawnSlime(14, 0.8, Color("#0006B4"), Vector2(0.0, -5.0) + position)
	spawnSlime(14, 0.6, Color("#10ECB4"), Vector2(0.0, -5.0) + position)
	$DieSound.startSound()
	animation("die")
	phase = Phase.DIE

func handleFullStun():
	animation("hit")

func stagger():
	animation("hit")

func resumeAfterStagger():
	if phase == Phase.IDLE:
		animation("idle")
	elif phase == Phase.BIRTH:
		animation("idle")
		phase = Phase.IDLE
		cooldown += 5.0

func hit(source: String, damage: float, stun: float, immediateStun: = false):
	super.hit(source, damage * damageTakenMultiplier, stun, immediateStun)

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.animation == "appear":
		animation("idle")
		phase = Phase.IDLE
		cooldownFull = nextCooldownFull
		cooldown = cooldownFull


		hasNetworkData = false
	elif $Sprite2D.animation == "birth":
		animation("idle")
		phase = Phase.IDLE
		cooldownFull = nextCooldownFull
		cooldown = cooldownFull
	elif $Sprite2D.animation == "armor_up":
		animation("armor")
		cooldownFull = nextArmorUpCooldown
		cooldown = cooldownFull
	elif $Sprite2D.animation == "armor_down":
		phase = Phase.IDLE
		animation("idle")
		cooldownFull = nextArmorDownCooldown
		cooldown = cooldownFull
		damageTakenMultiplier = 1.0
	elif $Sprite2D.animation == "die":
		removeFreeBlocker()

func _on_Sprite_frame_changed():
	if $Sprite2D.animation == "appear" and $Sprite2D.frame == 9:
		setHittable(true)
	elif $Sprite2D.animation == "birth" and $Sprite2D.frame == 4:
		spawnTicks()
	elif $Sprite2D.animation == "armor_down" and $Sprite2D.frame == 1:
		damageTakenMultiplier = 1.0
		$ArmorDownSound.startSound()
	elif $Sprite2D.animation == "armor_down" and $Sprite2D.frame == 1:
		$ArmorUpSound.startSound()

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var moveType: String = Data.of("breeder.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)


	stream.encode_float(Data.stabilizedRandomFloat(0.2, 0.6, "breeder", 1.0))


	stream.encode_float(Data.stabilizedRandomFloat(3, 5, "breeederidle", 5))


	stream.encode_float(Data.stabilizedRandomFloat(8, 14, "breeederarmor", 14))
	stream.encode_float(Data.stabilizedRandomFloat(3, 5, "breeederidle", 5))

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())


	var moveType = Data.of("breeder.movetype")
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

	random = RandomNumberGenerator.new()
	random.seed = UID

	var stabilizedFloatSpawnPos: float = stream.decode_float()
	goalPos = path.curve.sample_baked(path.curve.get_baked_length() * stabilizedFloatSpawnPos) + path.global_position
	position = Vector2(goalPos.x + 10 - 20 * (random.randi() % 2), -550)

	nextCooldownFull = stream.decode_float()
	nextArmorUpCooldown = stream.decode_float()
	nextArmorDownCooldown = stream.decode_float()
	hasNetworkData = true

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_u8(phase)
	stream.encode_float(nextProtectionHealthThreshold)
	stream.encode_float(cooldown)
	stream.encode_float(cooldownFull)
	stream.encode_float(fallingSplatterTick)
	stream.encode_float(nextFallingSplatter)
	stream.encode_float(damageTakenMultiplier)
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_s32(pathIndex)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_vector2(goalPos)
	stream.encode_float(nextCooldownFull)
	stream.encode_s32(nextSpawnCount)
	stream.encode_float(nextArmorUpCooldown)
	stream.encode_float(nextArmorDownCooldown)
	stream.encode_bool(hasNetworkData)
	stream.encode_float(moveTween.tell())
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	phase = stream.decode_u8()
	nextProtectionHealthThreshold = stream.decode_float()
	cooldown = stream.decode_float()
	cooldownFull = stream.decode_float()
	fallingSplatterTick = stream.decode_float()
	nextFallingSplatter = stream.decode_float()
	damageTakenMultiplier = stream.decode_float()
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	pathIndex = stream.decode_s32()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	goalPos = stream.decode_vector2()
	nextCooldownFull = stream.decode_float()
	nextSpawnCount = stream.decode_s32()
	nextArmorUpCooldown = stream.decode_float()
	nextArmorDownCooldown = stream.decode_float()
	hasNetworkData = stream.decode_bool()
	var move_tell: float = stream.decode_float()
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	Utils.decode_animated_sprite2d_state(stream, sprite)

	var moveType = Data.of("breeder.movetype")
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

	if phase == Phase.FALLING:
		var move_left: float = MOVE_DURATION - move_tell
		moveTween.interpolate_property(self, "position", position, goalPos, move_left)
		moveTween.interpolate_callback(self, move_left, "appear")
		moveTween.start()
