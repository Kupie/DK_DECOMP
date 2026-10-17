class_name Scarab
extends "res://content/monster/Monster.gd"

signal move_finished


enum Phase{ENTER, SHOOT, SHRINK, GROW, PROTECTED, ARMOFF, DIE}
var phase: int = Phase.ENTER

var movePointProvider
var projectileTargetProvider

var entering: = true

var cooldown: = 0.0
var nextProtectionHealthThreshold: float

var pathProgress: = 0.0
var currentMoveCurve: Curve2D

var goalPos: Vector2
var random: RandomNumberGenerator
var protectedDuration: = 0.0
var _variant: String
var _createdDueToFullSync: bool = false

func setProviders(movePointProvider, projectileTargetProvider, side: String):
	self.movePointProvider = movePointProvider
	self.projectileTargetProvider = projectileTargetProvider

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	currentMoveCurve = Curve2D.new()
	$EnterSound.startSound()
	currentMoveCurve.add_point(position)
	currentMoveCurve.add_point(goalPos)
	var pathLength = currentMoveCurve.get_baked_length()
	var time = pathLength / float(Data.of("scarab.speed"))
	moveTween.interpolate_property(self, "pathProgress", 0, pathLength, time, Tween.TRANS_QUAD, Tween.EASE_OUT)
	moveTween.start()
	phase = Phase.ENTER

	$Sprite2D.play("idle")
	updateHitboxState()
	setFlip(Utils.get_position_relative_to_dome(position, teamId).x > 0)
	nextProtectionHealthThreshold = 0.6 * maxHealth

func subProcess(delta):
	if phase == Phase.ARMOFF:
		return
	elif phase == Phase.SHOOT and currentHealth <= maxHealth * 0.33:
		armoff()

	if phase != Phase.SHRINK and phase != Phase.ENTER and currentHealth <= nextProtectionHealthThreshold:
		phase = Phase.SHRINK
		$Sprite2D.play("shrink")
		$InvulnerableStartSound.startSound()
		lowerProtectionThreshold()
		return

	if cooldown > 0.0:
		if phase != Phase.PROTECTED or timeSinceLastShotAt > 0.2:
			cooldown -= delta
		return

	match phase:
		Phase.ENTER:
			var newPos = currentMoveCurve.sample_baked(pathProgress)
			position = newPos
			if pathProgress >= currentMoveCurve.get_baked_length() - 1.0:
				startBigShot()
		Phase.PROTECTED:
			$Sprite2D.play("grow")
			$InvulnerableStopSound.startSound()
			phase = Phase.GROW
		Phase.SHOOT:
			startBigShot()
			if cooldown > 0.0:
				cooldown -= delta

func armoff():
	$SplitSound.startSound()
	animation("armoff")
	phase = Phase.ARMOFF
	nextProtectionHealthThreshold = -1

	if not multiplayer.is_server():
		return

	for side in ["left", "right"]:
		var monsterType: = Monster.Type.SCARABARM
		var spawnData: = ScarabArm.get_spawn_data(side, teamId, find_child(side.capitalize() + "Arm").global_position)
		Level.monstersByTeamId[teamId].monsterSynchronizer.network_spawn(monsterType, spawnData, teamId)

func lowerProtectionThreshold():

	nextProtectionHealthThreshold = -1

func leave(delta: float):
	position.y -= delta * 50
	position.x += delta * position.x * 0.1

func onGameLost():
	if currentHealth > 0:
		leaving = true
		animation("idle")

func stagger():
	moveTween.stop_all()

func resumeAfterStagger():
	moveTween.resume_all()

func animateDeath():
	$Sprite2D.play("die")
	$QuickShotSound.stop()
	$MassShootSound.stop()
	$DieSound.startSound()

func startBigShot():
	phase = Phase.SHOOT

	animation("shoot")

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	match $Sprite2D.animation:
		"armoff":
			animation("quickshot")
		"shrink":
			animation("protected")
			cooldown = protectedDuration
			phase = Phase.PROTECTED
		"shoot":
			animation("idle")
			cooldown = 1.2
		"grow":
			startBigShot()
		"die":
			super.removeFreeBlocker()
		"quickshot":
			$QuickShotSound.startSound()

func _on_Sprite_frame_changed():
	match $Sprite2D.animation:
		"grow":
			if $Sprite2D.frame == 8:
				invulnerable = false
				hitboxToDisable.append($HitboxQuickshot)
				hitboxToDisable.append($HitboxProtected)
				hitboxToEnable.append($HitboxDefault1)
				hitboxToEnable.append($HitboxDefault2)
				$InvulnerableHoldSound.stop()
		"shrink":
			if $Sprite2D.frame == 5:
				invulnerable = true
				stunIntensity = 0
				hitboxToDisable.append($HitboxDefault1)
				hitboxToDisable.append($HitboxDefault2)
				hitboxToDisable.append($HitboxQuickshot)
				hitboxToEnable.append($HitboxProtected)
				$InvulnerableHoldSound.startSound()
		"shoot":
			if $Sprite2D.frame == 12:
				spawnBigShot()
				$MassShootSound.startSound()
			elif $Sprite2D.frame == 2:
				$PreMassShootSound.startSound()
		"quickshot":
			if ($Sprite2D.frame == 3 or $Sprite2D.frame == 6 or $Sprite2D.frame == 9):
				spawnSmallShot(-1)
				spawnSmallShot(1)

func spawnBigShot():
	for offsetX in [-300, -250, -200, -150, 150, 200, 250, 300]:
		var p = preload("res://content/monster/scarab/ScarabProjectile.tscn").instantiate()
		p.teamId = teamId
		p.damageSource = damageSource
		p.damage = Data.of("scarab.damage") * damageModifier
		p.speed = Data.of("scarab.shotspeed") * random.randf_range(0.9, 1.1)
		offsetX *= random.randf_range(0.9, 1.1)
		get_parent().add_child(p)
		var path = Curve2D.new()
		var posRelativeToDome: = Utils.get_position_relative_to_dome(position, teamId)
		var shotDirection = Vector2(offsetX + posRelativeToDome.x * 0.5, - abs(offsetX))
		var target = projectileTargetProvider.getStableRandom(shotDirection, random)
		path.add_point(position + $PositionBigProjectile.position, Vector2.ZERO, shotDirection)
		path.add_point(target, shotDirection)
		p.start(path, Tween.TransitionType.TRANS_CUBIC, Tween.EASE_OUT_IN)

func spawnSmallShot(dir):
	var x = random.randf_range(100, 300)
	x *= dir
	var y = random.randf_range(-100, -300)
	var p = preload("res://content/monster/scarab/ScarabProjectile.tscn").instantiate()
	p.teamId = teamId
	p.damageSource = damageSource
	p.damage = Data.of("scarab.damage") * damageModifier
	p.speed = Data.of("scarab.shotspeed") * random.randf_range(0.9, 1.1)
	get_parent().add_child(p)
	var path = Curve2D.new()
	var shotDirection = Vector2(x, y)
	var target = projectileTargetProvider.getStableRandom(shotDirection, random)
	path.add_point(position + $PositionBigProjectile.position, Vector2.ZERO, shotDirection)
	path.add_point(target, shotDirection)
	$QuickShotSound.startSound()
	p.start(path, Tween.TRANS_CUBIC, Tween.EASE_OUT_IN)

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	var movePointProvider = Level.worldsByTeamId[teamId].getFlyerPathProvider()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var spawnType: String = Data.of("scarab.spawnpoint") + "_" + variant
	var spawnPosition: Vector2 = movePointProvider.getSpawn(spawnType).position
	stream.encode_vector2(Utils.get_global_from_local_dome_position(spawnPosition, teamId))


	var point: Marker2D = movePointProvider.getRandomPoint(CONST.CENTER)
	var targetPos: Vector2 = point.global_position
	stream.encode_vector2(targetPos)
	stream.encode_u8(movePointProvider.getPointIndex(point, CONST.CENTER))

	return stream.data

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)


	_variant = Utils.get_side_string_from_bool(stream.decode_bool())

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), Level.domesByTeamId[teamId].getProjectileTargetProvider(), _variant)

	position = stream.decode_vector2()
	goalPos = stream.decode_vector2()
	var pointIndex: = stream.decode_u8()
	movePointProvider.assignPointOccupation(movePointProvider.getPoint(pointIndex, CONST.CENTER), self)

	random = RandomNumberGenerator.new()
	random.seed = UID

	protectedDuration = random.randf_range(5.0, 7.0)


func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_u8(phase)
	stream.encode_bool(entering)
	stream.encode_float(cooldown)
	stream.encode_float(nextProtectionHealthThreshold)
	stream.encode_float(pathProgress)
	_encode_curve2D(stream, currentMoveCurve)
	stream.encode_vector2(goalPos)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_float(protectedDuration)
	stream.encode_bool(Utils.get_side_bool_from_string(_variant))
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	phase = stream.decode_u8()
	entering = stream.decode_bool()
	cooldown = stream.decode_float()
	nextProtectionHealthThreshold = stream.decode_float()
	pathProgress = stream.decode_float()
	currentMoveCurve = Curve2D.new()
	_decode_curve2D(stream, currentMoveCurve)
	goalPos = stream.decode_vector2()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	protectedDuration = stream.decode_float()
	_variant = Utils.get_side_string_from_bool(stream.decode_bool())
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	Utils.decode_animated_sprite2d_state(stream, sprite)

	setProviders(Level.worldsByTeamId[teamId].getFlyerPathProvider(), Level.domesByTeamId[teamId].getProjectileTargetProvider(), _variant)
