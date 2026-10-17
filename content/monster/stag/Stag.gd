class_name Stag
extends "res://content/monster/Monster.gd"

@export var distanceToMeleePoint: = 10.0

var path: Path2D
var meleeTarget: Path2D
var projectileTargetProvider
var walking: = true
var progress: = 0.0
var lastDelta: float
var goalProgress: float

var lastWalkFrame: = 0

var variant: String
var random: RandomNumberGenerator
var pathIndex: int
var _createdDueToFullSync: bool = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	goalProgress = path.curve.get_baked_length() * 0.6
	position = path.curve.sample_baked(progress) + path.global_position
	var d = position.x - (path.curve.sample_baked(progress + 50).x + path.global_position.x)
	lastDelta = - d
	setFlip(d > 0.0)
	$Sprite2D.play("walk")
	$StagEnters.startSound()
	updateHitboxState()
	$Sprite2D.speed_scale = speedModifier

func subProcess(delta):
	if walking:
		progress += delta * Data.of("stag.speed") * $Sprite2D.speed_scale
		if goalProgress <= progress:
			animation("ground")
			walking = false
		else:
			position = path.curve.sample_baked(progress) + path.global_position

func leave(delta: float):
	if progress > 0.0:
		progress = max(0, progress - delta * Data.of("stag.speed") * $Sprite2D.speed_scale)
		position = path.curve.sample_baked(progress) + path.global_position

func onGameLost():
	if currentHealth > 0:
		leaving = true
		animation("walk")
		$Sprite2D.speed_scale = 0.9 + random.randf() * 0.5
		setFlip( not $Sprite2D.flip_h)

func stagger():
	animation("hit")

func resumeAfterStagger():
	if walking:
		animation("walk")
		$Sprite2D.frame = lastWalkFrame
	else:
		animation("ground")

func _on_sprite_2d_animation_looped() -> void :
	_animationEndCheck()

func _on_Sprite_animation_finished() -> void :
	_animationEndCheck()

func _animationEndCheck() -> void :
	match $Sprite2D.animation:
		"walk":
			if abs(Utils.get_position_relative_to_dome(position, teamId).x) < 400 and not leaving:
				animation("shoot")


		"die":
			super.removeFreeBlocker()

func _on_Sprite_frame_changed():
	match $Sprite2D.animation:
		"walk":
			lastWalkFrame = $Sprite2D.frame
		"shoot":
			var spawnPos = get_node_or_null("Shot" + str($Sprite2D.frame))
			if spawnPos:
				spawnShot(spawnPos.global_position)
			if $Sprite2D.frame == 0:
				$BarrageSound.startSound()
		"ground":
			if $Sprite2D.frame == 16:
				spawnGroundProjectile()
			elif $Sprite2D.frame == 0:
				$StartPound.startSound()

func animateDeath():
	animation("die")
	$DieSound.startSound()

func spawnShot(startPos: Vector2):
	var x = random.randf_range(100, 400)
	var y = random.randf_range(-300, -500)
	if Utils.get_position_relative_to_dome(startPos, teamId).x > 0:
		x = - x

	var p = preload("res://content/monster/stag/StagAirProjectile.tscn").instantiate()
	p.teamId = teamId
	p.damageSource = damageSource
	p.damage = Data.of("stag.airprojectiledamage") * damageModifier
	p.speed = Data.of("stag.airprojectilespeed") * random.randf_range(0.9, 1.1)
	get_parent().add_child(p)
	var path = Curve2D.new()
	var shotDirection = Vector2(x, y)
	var globalShotDirection: Vector2 = Utils.get_global_from_local_dome_position(shotDirection, teamId)
	var target = projectileTargetProvider.getStableRandom(globalShotDirection, random) + Vector2(8 - random.randi() % 16, 8 - random.randi() % 16)
	path.add_point(startPos, shotDirection)
	path.add_point(target, shotDirection)
	$StagShot.startSound()
	p.start(path, Tween.TRANS_LINEAR, Tween.EASE_OUT_IN)

func spawnGroundProjectile():
	InputSystem.shake(100, 0.3, 8, $HitPosition.global_position)
	var p = preload("res://content/monster/stag/StagGroundProjectile.tscn").instantiate()
	p.teamId = teamId
	p.damageSource = damageSource
	p.position = get_node("Ground1").global_position
	p.origin = p.position
	p.target = meleeTarget.curve.get_closest_point(p.origin) + Vector2(4 - random.randi() % 8, 4 - random.randi() % 8)
	p.damage = Data.of("stag.groundprojectiledamage") * damageModifier
	p.speed = Data.of("stag.groundprojectilespeed")
	$GroundPoundSound.startSound()
	get_parent().add_child(p)

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var moveType: String = Data.of("stag.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())


	var moveType = Data.of("stag.movetype")
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

	random = RandomNumberGenerator.new()
	random.seed = UID
	projectileTargetProvider = Level.domesByTeamId[teamId].getProjectileTargetProvider()

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_float(distanceToMeleePoint)
	stream.encode_bool(walking)
	stream.encode_float(progress)
	stream.encode_float(lastDelta)
	stream.encode_float(goalProgress)
	stream.encode_s32(lastWalkFrame)
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_s32(pathIndex)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream = _apply_base_full_sync(buffer)
	distanceToMeleePoint = stream.decode_float()
	walking = stream.decode_bool()
	progress = stream.decode_float()
	lastDelta = stream.decode_float()
	goalProgress = stream.decode_float()
	lastWalkFrame = stream.decode_s32()
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	pathIndex = stream.decode_s32()
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	Utils.decode_animated_sprite2d_state(stream, sprite)

	projectileTargetProvider = Level.domesByTeamId[teamId].getProjectileTargetProvider()
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)

	var moveType: String = Data.of("stag.movetype")
	var l_pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[l_pathIndex]
