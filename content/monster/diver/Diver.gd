class_name Diver
extends "res://content/monster/Monster.gd"

enum Phase{ANNOUNCE, DIVE, STICK, RETREAT, RISE, GO_TO_DIVE_POSITION, LEAVE, DIE_DIVE}

var phase: int = Phase.DIVE
var domeTarget: Vector2 = Vector2.INF
var target: Vector2 = Vector2.INF

var retreatPosition: Vector2
var divePosition: Vector2

var cooldown: = 0.0
var yDiff: = 0

var variant: String
var random: RandomNumberGenerator

var _createdDueToFullSync: bool = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	position = divePosition
	$DeathFly.visible = false
	$DeathDive.visible = false
	$Sprite2D.play("dive")
	announce()

func dive():
	phase = Phase.DIVE
	target = domeTarget
	if target.x < global_position.x:
		rotation = (target - global_position).angle() - 0.74 * PI
	else:
		rotation = (target - global_position).angle() - 0.26 * PI
	animation("dive")
	$DiveSound.startSound()
	setHittable(true)

func retreat():
	phase = Phase.RETREAT
	target = retreatPosition
	target.y += 50 - 100 * random.randf()
	rotation = 0.0

func announce():
	setHittable(false)
	phase = Phase.ANNOUNCE
	cooldown = Data.of("diver.announcedelay")
	$AnnounceSound.startSound()
	var warner = preload("res://content/monster/diver/DiveWarner.tscn").instantiate()
	warner.process_material = warner.process_material.duplicate()
	get_parent().add_child(warner)
	(warner.process_material as ParticleProcessMaterial).color.r *= 3
	(warner.process_material as ParticleProcessMaterial).color.g *= 3
	(warner.process_material as ParticleProcessMaterial).color.b *= 3
	var d = domeTarget - global_position
	if domeTarget.x < global_position.x:
		warner.process_material.direction.x = d.x
		warner.process_material.direction.y = d.y
	else:
		warner.process_material.direction.x = d.x
		warner.process_material.direction.y = d.y
	warner.position = global_position

func _process(delta: float) -> void :
	if phase == Phase.DIE_DIVE:
		move(Data.of("diver.divespeed") * 0.3, delta)

func subProcess(delta):
	var dome: Dome = Level.domesByTeamId[teamId]
	setFlip(position.x - dome.global_position.x > 0)

	match phase:
		Phase.ANNOUNCE:
			cooldown -= delta
			if cooldown <= 0.0:
				dive()
		Phase.DIVE:
			if not move(Data.of("diver.divespeed"), delta):
				animation("dive_in")
				applyDamage()
		Phase.RETREAT:
			if not move(Data.of("diver.retreatspeed") * speedModifier, delta):
				phase = Phase.RISE
				target.y = divePosition.y
				setHittable(false)
				yDiff = 0
		Phase.RISE:
			if not move(Data.of("diver.risespeed"), delta):
				phase = Phase.GO_TO_DIVE_POSITION
				target = divePosition
		Phase.GO_TO_DIVE_POSITION:
			if not move(Data.of("diver.retreatspeed"), delta):
				announce()

func resumeAfterStagger():
	match phase:
		Phase.DIVE:
			animation("dive")
		Phase.RETREAT:
			animation("fly")
		Phase.STICK:
			retreat()
			animation("fly")

func move(speed: float, delta: float):
	if target == Vector2.INF:
		return false
	var d = target - global_position
	var m = (d.normalized() * speed * delta).limit_length(d.length()) * $Sprite2D.speed_scale
	position += m
	return d.length() > 2.0

func applyDamage():
	var dome = Level.domesByTeamId[teamId]
	dome.requestMeleeDamage(Data.of("diver.damage") * damageModifier, global_position, self)
	InputSystem.shake(100, 0.2, 8, global_position)

func domeAcceptsDamage():

	phase = Phase.STICK
	$ImpactSound.startSound()

func domeReflectsDamage(returnedDamage: = 0.0, returnedSpeed: = 1.0, damageModifier: = 1.0, duration: = 0.0):
	super.domeReflectsDamage(returnedDamage, returnedSpeed)
	retreat()
	animation("fly")

func domeAbsorbsDamage():
	retreat()
	animation("fly")

func leave(delta: float):
	position += delta * (retreatPosition - position).normalized() * 100.0
	animation("fly")

func animateDeath():
	$DeathFly.flip_h = $Sprite2D.flip_h
	$DeathDive.flip_h = $Sprite2D.flip_h
	$Sprite2D.visible = false
	if phase == Phase.STICK or phase == Phase.RETREAT:
		$DeathFly.visible = true
		$DeathFly.play("default")
		$DieSoundFly.startSound()
	else:
		$DeathDive.visible = true
		$DeathDive.play("default")
		phase = Phase.DIE_DIVE
		$DieSoundDive.startSound()

func handleDamage():
	if phase == Phase.DIVE:
		receiveDamage = 999

func handleFullStun():
	animation("hit")

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.animation == "dive_in":
		animation("dive_out")

		var dome: Dome = Level.domesByTeamId[teamId]
		var positionRelativeToDome = domeTarget - dome.global_position
		moveTween.interpolate_property(self, "position", global_position, global_position + positionRelativeToDome * 0.5, 1.2, Tween.TRANS_LINEAR, Tween.EASE_IN, 1.2)
		moveTween.interpolate_callback($RetreatSound, 0.9, "startSound")
		moveTween.start()
	elif $Sprite2D.animation == "dive_out":
		retreat()
		animation("fly")
	elif $Sprite2D.animation == "fly" and $Sprite2D.frame % 4 == 0:
		$FlapSound.startSound()

func _on_Death_animation_finished() -> void :
	super.removeFreeBlocker()

static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))

	return stream.data

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())

	random = RandomNumberGenerator.new()
	random.seed = UID

	var dome: Dome = Level.domesByTeamId[teamId]

	var pp = Level.domesByTeamId[teamId].PiercePoints
	domeTarget = pp.get_node("Left").global_position if variant == CONST.LEFT else pp.get_node("Right").global_position

	var retreatPositionString: = "DiverPaths/RetreatLeft" if variant == CONST.LEFT else "DiverPaths/RetreatRight"
	retreatPosition = Level.monstersByTeamId[teamId].get_node(retreatPositionString).global_position

	var pathString = "DiverPaths/StartLeft" if variant == CONST.LEFT else "DiverPaths/StartRight"
	var path: Path2D = Level.monstersByTeamId[teamId].get_node(pathString)

	var newDivePosition: Vector2 = path.curve.sample_baked(path.curve.get_baked_length() * random.randf())
	divePosition = Vector2(newDivePosition.x + dome.global_position.x, newDivePosition.y)

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_u16($Sprite2D.frame)
	stream.encode_u8(phase)
	stream.encode_vector2(domeTarget)
	stream.encode_vector2(target)
	stream.encode_vector2(retreatPosition)
	stream.encode_vector2(divePosition)
	stream.encode_float(cooldown)
	stream.encode_float(yDiff)
	stream.encode_vector2(global_position)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream: PackedByteStream = _apply_base_full_sync(buffer)
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	$Sprite2D.frame = stream.decode_u16()
	phase = stream.decode_u8()
	domeTarget = stream.decode_vector2()
	target = stream.decode_vector2()
	retreatPosition = stream.decode_vector2()
	divePosition = stream.decode_vector2()
	cooldown = stream.decode_float()
	yDiff = stream.decode_float()
	global_position = stream.decode_vector2()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	Utils.decode_animated_sprite2d_state(stream, sprite)
	updateHitboxState()
