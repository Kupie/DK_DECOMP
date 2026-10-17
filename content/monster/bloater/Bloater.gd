class_name Bloater
extends "res://content/monster/Monster.gd"

enum Phase{ENTER, BLOAT, DIE, SHRIVEL}

var phase: int = Phase.ENTER
var cooldown: = 0.0


var movePointProvider
var currentMoveCurve: Curve2D
var pathProgress: = 0.0
var averagedMoveDelta: = 0.0
var oldPos: = Vector2.ZERO
var targetPos: = Vector2.ZERO
var leaveDir: Vector2

var nextDamageThreshold: = 0.4
var firstShotHealthThreshold: = 0.95
var shotIntervalJitter: = 0.0
var firstShot: = true
var cameFromEnter: = true

var lastHealth: = maxHealth
var nextDripTimer: = 0.2
var dripTimer: = 0.0
var healthPercentageOnSpawn: float
var circularMoveCenter: Vector2
var bloatTimer: = 0.0
var growDeltaTimer: = 0.0
var eggHealthPercentage: = 0.0
var lastHitTime: = 0

var variant: String
var random: RandomNumberGenerator
var spawnCount: = 0
var _createdDueToFullSync: bool = false
var _fullSyncMoveTell: float = 0.0

@onready var bloaterEggs: = [ %BloaterEgg1, %BloaterEgg2, %BloaterEgg3, %BloaterEgg4, %BloaterEgg5, %BloaterEgg6, %BloaterEgg7]
@onready var bodyCovers: = [
	$Sprite2D / BodyCover1, 
	$Sprite2D / BodyCover2, 
	$Sprite2D / BodyCover3, 
	$Sprite2D / BodyCover4, 
	$Sprite2D / BodyCover5, 
	]
@onready var bodyCoverPositions: = [
	$Sprite2D / BodyCover1.position, 
	$Sprite2D / BodyCover2.position, 
	$Sprite2D / BodyCover3.position, 
	$Sprite2D / BodyCover4.position, 
	$Sprite2D / BodyCover5.position, 
	]
@onready var eggAttachers: = [
	$Sprite2D / EggAttacher1, 
	$Sprite2D / EggAttacher2, 
	$Sprite2D / EggAttacher3, 
	$Sprite2D / EggAttacher4, 
	$Sprite2D / SpriteHead / EggAttacher, 
	$Sprite2D / SpriteTail / EggAttacher4, 
	$Sprite2D / SpriteTail / EggAttacher5, 
]
@onready var eggAttacherPositions: = [
	$Sprite2D / EggAttacher1.position, 
	$Sprite2D / EggAttacher2.position, 
	$Sprite2D / EggAttacher3.position, 
	$Sprite2D / EggAttacher4.position, 
	$Sprite2D / SpriteHead / EggAttacher.position, 
	$Sprite2D / SpriteTail / EggAttacher4.position, 
	$Sprite2D / SpriteTail / EggAttacher5.position, 
]

@onready var dripParticles: = [$Sprite2D / SpriteHead / DripParticle1, $Sprite2D / DripParticle3, $Sprite2D / DripParticle4]

var eggHideThresholds: = []

func _ready():
	var healthOnHost: float = currentHealth
	super._ready()
	if _createdDueToFullSync:
		currentHealth = healthOnHost

	$Sprite2D / SpriteTail.material = $Sprite2D.material
	$Sprite2D / SpriteHead.material = $Sprite2D.material
	$HitboxDefault.shape = $HitboxDefault.shape.duplicate()
	for s in bloaterEggs:
		s.set_material($Sprite2D.material)
	for s in bodyCovers:
		s.set_material($Sprite2D.material)
	$ShrivelSound.connect("sound_duration_elapsed", Callable(self, "removeFreeBlocker"))
	for i in bloaterEggs:
		eggHideThresholds.append(random.randf_range(-1, -0.2))
	eggHealthPercentage = ease(abs(1.0 - currentHealth / maxHealth), 0.8)
	$Sprite2D.play()
	$Sprite2D / SpriteHead.play()
	$Sprite2D / SpriteTail.play()

func _process(_delta):
	if stunned:
		for p in dripParticles:
			p.emitting = false
		$Sprite2D / SpriteHead.speed_scale = 0.0
		$Sprite2D / SpriteTail.speed_scale = 0.0
		$Sprite2D.speed_scale = 0.0

func init():
	if _createdDueToFullSync:
		_full_sync_init()
		return
	supports_full_sync = true
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)

	pathProgress = 0
	var posRelativeToDome: = Utils.get_position_relative_to_dome(position, teamId)
	targetPos = position + Vector2(100 * (1 if posRelativeToDome.x < 0 else -1), random.randf_range(-20, 20))
	currentMoveCurve.add_point(position, Vector2.ZERO, Vector2.UP.rotated(PI * 0.3) if posRelativeToDome.x > 0 else Vector2.UP.rotated(PI * -0.3))
	currentMoveCurve.add_point(targetPos, Vector2.DOWN.rotated(PI * 0.3) if posRelativeToDome.x < 0 else Vector2.UP.rotated(PI * -0.3))

	circularMoveCenter = targetPos + Vector2(200 if posRelativeToDome.x < 0 else -200, 0)

	$EnterSound.startSound()
	var pathLength = currentMoveCurve.get_baked_length()

	var duration = pathLength / Data.of("bloater.speed")
	moveTween.interpolate_property(self, "pathProgress", 0, pathLength, duration, Tween.TRANS_LINEAR, Tween.EASE_IN)
	moveTween.interpolate_callback(self, duration, "moveCircular")
	moveTween.start()

	currentHealth = Data.of("bloater.healthonspawn")
	healthPercentageOnSpawn = Data.of("bloater.healthonspawn") / maxHealth

func _full_sync_init() -> void :
	var pathLength = currentMoveCurve.get_baked_length()
	var duration = pathLength / Data.of("bloater.speed")
	var percent_progress: float = _fullSyncMoveTell / duration
	var path_progress: float = percent_progress * pathLength
	var tween_time_left: float = duration - _fullSyncMoveTell
	moveTween.interpolate_property(self, "pathProgress", path_progress, pathLength, tween_time_left, Tween.TRANS_LINEAR, Tween.EASE_IN)
	moveTween.interpolate_callback(self, tween_time_left, "moveCircular")
	moveTween.start()

func setFlip(newFlip: bool, force: = false):
	if $Sprite2D.flip_h == newFlip and not force:
		return

	$Sprite2D.flip_h = newFlip
	$Sprite2D / SpriteHead.flip_h = newFlip
	$Sprite2D / SpriteTail.flip_h = newFlip
	for e in [$Sprite2D / SpriteHead, $Sprite2D / SpriteTail, $Sprite2D / SpriteHead / DripParticle1, $Sprite2D / DripParticle3, $Sprite2D / DripParticle4]:
		e.position.x = - e.position.x
	for e in [$Sprite2D / EggAttacher1, $Sprite2D / EggAttacher2, $Sprite2D / EggAttacher3, $Sprite2D / EggAttacher4, $Sprite2D / SpriteHead / EggAttacher, $Sprite2D / SpriteTail / EggAttacher4, $Sprite2D / SpriteTail / EggAttacher5]:
		e.position.x = - e.position.x
	for e in [$Sprite2D / BodyCover1, $Sprite2D / BodyCover2, $Sprite2D / BodyCover3, $Sprite2D / BodyCover4, $Sprite2D / BodyCover5]:
		e.position.x = - e.position.x

	for c in get_children():
		if c is Node2D:
			c.position.x = - c.position.x
			c.rotation = - c.rotation
		if c is CollisionPolygon2D:
			for i in range(0, c.polygon.size()):
				c.polygon[i].x *= -1


func moveCircular():
	moveTween.remove_all()
	pathProgress = 0
	var movePoints: = []
	var posRelativeToDome: = Utils.get_position_relative_to_dome(position, teamId)
	if posRelativeToDome.x < 0:
		movePoints.append(Vector2.LEFT)
		movePoints.append(Vector2.UP)
		movePoints.append(Vector2.RIGHT)
		movePoints.append(Vector2.DOWN)
		movePoints.append(Vector2.LEFT)
	else:
		movePoints.append(Vector2.RIGHT)
		movePoints.append(Vector2.UP)
		movePoints.append(Vector2.LEFT)
		movePoints.append(Vector2.DOWN)
		movePoints.append(Vector2.RIGHT)

	currentMoveCurve = Curve2D.new()

	for p in movePoints:
		var movePoint = circularMoveCenter + p * random.randf_range(40, 100)
		var inVec: Vector2
		var outVec: Vector2

		inVec = p.rotated( - PI * 0.5) * 30
		outVec = p.rotated(PI * 0.5) * 30

		if posRelativeToDome.x > 0:
			var swap = inVec
			inVec = outVec
			outVec = swap

		if currentMoveCurve.get_point_count() == 0:
			if cameFromEnter:
				currentMoveCurve.add_point(position, Vector2.ZERO, Vector2.DOWN.rotated(PI * 1.3) if posRelativeToDome.x < 0 else Vector2.UP.rotated(PI * -1.3))
				cameFromEnter = false
			else:
				currentMoveCurve.add_point(position, p * 300, outVec)
		else:
			currentMoveCurve.add_point(movePoint, inVec, outVec)

	var pathLength = currentMoveCurve.get_baked_length()
	var duration = pathLength / Data.of("bloater.speed")
	moveTween.interpolate_property(self, "pathProgress", 0, pathLength, duration)
	moveTween.interpolate_callback(self, duration, "moveCircular")
	moveTween.start()


func spawnSlime(amount, rotationRange: = 0.9, color: = Color("#0006B4"), speed_min: = 80.0, speed_max: = 240.0, pos: = position):
	if not Options.reducedParticles:
		for i in amount:
			var new_slime = preload("res://content/effects/monster/SlimeExplosion.tscn").instantiate()
			new_slime.styleColor = color
			new_slime.position = pos
			get_parent().add_child(new_slime)
			new_slime.apply_central_impulse(Vector2.UP.rotated(random.randf_range( - rotationRange, rotationRange)) * random.randf_range(speed_min, speed_max))


func subProcess(delta):
	match phase:
		Phase.ENTER:
			currentHealth = min(currentHealth + delta * 5.0, maxHealth)
			position = currentMoveCurve.sample_baked(pathProgress)
			dripTimer += delta
			for p in dripParticles:
				p.emitting = dripTimer > 0


		Phase.BLOAT:
			bloatTimer += delta
			if bloatTimer >= 1.0:
				finishBloating()
				for i in spawnCount:
					spawnBurrower()
			else:
				for egg in bloaterEggs:
					egg.violence = bloatTimer * 45.0

	lastHealth = currentHealth

	updateGrowFactor(delta)
	updateEggs(delta)

	if currentHealth == maxHealth and phase != Phase.DIE:
		animateDeathShrivel()

	if Time.get_ticks_msec() - lastHitTime > 250 and $HitLoopSound.shouldPlay:
		$HitLoopSound.stop()

func updateGrowFactor(delta):
	var growFactor: float
	if currentHealth <= Data.of("bloater.healthonspawn"):
		growFactor = 1.0 - (currentHealth / Data.of("bloater.healthonspawn"))
	else:
		growFactor = ((currentHealth - Data.of("bloater.healthonspawn")) / (maxHealth - Data.of("bloater.healthonspawn"))) * -1
		growFactor *= 0.8
	if $Sprite2D.flip_h:
		growFactor *= -1
	growDeltaTimer += delta
	$Sprite2D / SpriteHead.position = Vector2(growFactor * 8.0, 5.5)
	$Sprite2D / SpriteTail.position = Vector2(growFactor * -8.0, 7.5)
	$Sprite2D.position = Vector2(sin(growDeltaTimer * 5.0), 10.5 + sin(growDeltaTimer * 3.0) * 3.0)
	$Sprite2D / SpriteHead.position += Vector2(sin(0.5 - growDeltaTimer * 4.0) * 0.75, sin(0.5 + growDeltaTimer * 2.0) * 1.5)
	$Sprite2D / SpriteTail.position += Vector2(sin(0.5 + growDeltaTimer * 4.0) * 0.75, sin(0.5 + growDeltaTimer * 2.0) * 1.5)
	$HitboxDefault.shape.radius = 25 + (15 * abs(growFactor))
	$HitboxDefault.position.y = -10 - abs(growFactor) * 16

func updateEggs(delta):
	eggHealthPercentage = move_toward(eggHealthPercentage, ease(abs(1.0 - currentHealth / maxHealth), 0.8), delta * 0.5)

	for i in bloaterEggs.size():
		bloaterEggs[i].position.y = - eggHealthPercentage * 25.0
		bloaterEggs[i].size = eggHealthPercentage

	for i in bodyCovers.size():
		bodyCovers[i].position.y = bodyCoverPositions[i].y - eggHealthPercentage * 8.0
		bodyCovers[i].frame = round(eggHealthPercentage * 18.0)

	for i in eggAttachers.size():
		eggAttachers[i].position.y = eggAttacherPositions[i].y - eggHealthPercentage * 8.0

func handleDamage():
	dripTimer = -0.2
	$ShotSound.startSound()
	if not $HitLoopSound.shouldPlay:
		$HitLoopSound.startSound()
	lastHitTime = Time.get_ticks_msec()

	if currentHealth <= 0 and phase != Phase.BLOAT:
		startBloat()
	else:
		if currentStunLevel > 0.0:
			for egg in bloaterEggs:
				egg.hit()

func startBloat() -> void :
	if Level.monstersByTeamId[teamId].disabled:
		finishBloating()
	else:
		currentHealth = 1
		invulnerable = true
		$BlockerHitboxExplosion.disabled = false
		phase = Phase.BLOAT
		$BloatSound.startSound()

func onGameLost():
	super.onGameLost()
	leaveDir = Vector2(random.randf_range(-0.1, 0.1), -1).normalized()
	setFlip(leaveDir.x < 0)

func leave(delta: float):
	position += leaveDir * delta

func spawnBurrower():
	if not multiplayer.is_server():
		return
	var monsterType: = Monster.Type.BURROWER
	var spawnData: = Burrower.get_spawn_data(variant, teamId, Monster.Type.WALKER, Monster.Type.BLOATER, position, to_local(bloaterEggs[random.randi() % bloaterEggs.size()].global_position), z_index - 1)
	Level.monstersByTeamId[teamId].monsterSynchronizer.network_spawn(monsterType, spawnData, teamId)

func animateDeath() -> void :
	for b in bodyCovers:
		b.hide()
	animateDeathShrivel()

func animateDeathShrivel():
	for e in bloaterEggs:
		e.hide()
	for egg in bloaterEggs:
		spawnSlime(2, 0.9, Color("#0006B4"), 20.0, 40.0, position + to_local(egg.global_position))
	phase = Phase.DIE
	animation("shrivel")
	$Sprite2D / SpriteHead.play("shrivel")
	$Sprite2D / SpriteTail.modulate.a = 0.0
	$ShrivelSound.startSound()

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	match $Sprite2D.animation:
		"die":
			removeFreeBlocker()
		"shrivel":
			die()
			removeFreeBlocker()

func finishBloating():
	phase = Phase.DIE
	for e in bloaterEggs:
		spawnSlime(2, 0.9, Color("#0006B4"), 80.0, 240.0, to_local(e.global_position) + position)
		spawnSlime(2, 0.9, Color("#10ECB4"), 80.0, 240.0, to_local(e.global_position) + position)
		e.hide()
	die()
	animation("die")
	for b in bodyCovers:
		b.hide()
	for e in bloaterEggs:
		e.hide()

	$HitLoopSound.stop()
	$Sprite2D / SpriteHead.hide()
	$Sprite2D / SpriteTail.hide()
	$DieSound.startSound()

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	var movePointProvider = Level.worldsByTeamId[teamId].getFlyerPathProvider()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var spawnType: String = Data.of("bloater.spawnpoint") + "_" + variant
	var spawnPosition: Vector2 = movePointProvider.getSpawn(spawnType).global_position
	spawnPosition.y -= 20
	stream.encode_vector2(spawnPosition)


	stream.encode_u8(Data.stabilizedRandomInt(7, 10, "bloaterspawns", 4))

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())


	position = stream.decode_vector2()
	currentMoveCurve = Curve2D.new()

	random = RandomNumberGenerator.new()
	random.seed = UID

	spawnCount = stream.decode_u8()

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_u8(phase)
	stream.encode_float(cooldown)
	_encode_curve2D(stream, currentMoveCurve)
	stream.encode_float(pathProgress)
	stream.encode_float(averagedMoveDelta)
	stream.encode_vector2(oldPos)
	stream.encode_vector2(targetPos)
	stream.encode_vector2(leaveDir)
	stream.encode_float(nextDamageThreshold)
	stream.encode_float(firstShotHealthThreshold)
	stream.encode_float(shotIntervalJitter)
	stream.encode_bool(firstShot)
	stream.encode_bool(cameFromEnter)
	stream.encode_float(lastHealth)
	stream.encode_float(nextDripTimer)
	stream.encode_float(dripTimer)
	stream.encode_float(healthPercentageOnSpawn)
	stream.encode_vector2(circularMoveCenter)
	stream.encode_float(bloatTimer)
	stream.encode_float(growDeltaTimer)
	stream.encode_float(eggHealthPercentage)
	stream.encode_s32(lastHitTime)
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_s32(spawnCount)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	stream.encode_float(moveTween.tell())
	Utils.encode_animated_sprite2d_state(stream, sprite)
	Utils.encode_animated_sprite2d_state(stream, $Sprite2D / SpriteHead)
	Utils.encode_animated_sprite2d_state(stream, $Sprite2D / SpriteTail)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	phase = stream.decode_u8()
	cooldown = stream.decode_float()
	currentMoveCurve = Curve2D.new()
	_decode_curve2D(stream, currentMoveCurve)
	pathProgress = stream.decode_float()
	averagedMoveDelta = stream.decode_float()
	oldPos = stream.decode_vector2()
	targetPos = stream.decode_vector2()
	leaveDir = stream.decode_vector2()
	nextDamageThreshold = stream.decode_float()
	firstShotHealthThreshold = stream.decode_float()
	shotIntervalJitter = stream.decode_float()
	firstShot = stream.decode_bool()
	cameFromEnter = stream.decode_bool()
	lastHealth = stream.decode_float()
	nextDripTimer = stream.decode_float()
	dripTimer = stream.decode_float()
	healthPercentageOnSpawn = stream.decode_float()
	circularMoveCenter = stream.decode_vector2()
	bloatTimer = stream.decode_float()
	growDeltaTimer = stream.decode_float()
	eggHealthPercentage = stream.decode_float()
	lastHitTime = stream.decode_s32()
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	spawnCount = stream.decode_s32()
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	_fullSyncMoveTell = stream.decode_float()
	Utils.decode_animated_sprite2d_state(stream, sprite)
	Utils.decode_animated_sprite2d_state(stream, $Sprite2D / SpriteHead)
	Utils.decode_animated_sprite2d_state(stream, $Sprite2D / SpriteTail)
	movePointProvider = Level.worldsByTeamId[teamId].getFlyerPathProvider()
