class_name Driller
extends "res://content/monster/Monster.gd"

const damageUnit: = 2.0

var path: Path2D
var meleeTarget: Path2D
var phase: = 0
var progress: = 0.0
var damageSum: = 0.0
var variant: String
var pathIndex: int
var lastDelta: float
var _createdDueToFullSync: bool = false

func init():
	if _createdDueToFullSync:
		return
	supports_full_sync = true
	position = path.curve.sample_baked(0) + path.global_position
	var d = position.x - (path.curve.sample_baked(50).x + path.global_position.x)
	lastDelta = - d
	if d < 0.0:
		setFlip(true, true)
		$Particles1.process_material = preload("res://content/monster/driller/P1left.tres")
		$Particles2.process_material = preload("res://content/monster/driller/P2left.tres")
	else:
		$Particles1.process_material = preload("res://content/monster/driller/P1right.tres")
		$Particles2.process_material = preload("res://content/monster/driller/P2right.tres")

	if phase == 0:
		$Sprite2D.play("walk")
	else:
		_animationFinishedCheck()
	updateHitboxState()

func subProcess(delta):
	if phase == 0:
		progress += delta * Data.of("driller.speed") * $Sprite2D.speed_scale
		var cp = meleeTarget.curve.get_closest_point($HitPosition.global_position)
		if sign(lastDelta) != sign(cp.x - $HitPosition.global_position.x):
			animation("settle")
			moveTween.interpolate_callback(InputSystem, 0.6, "shake", 100, 1.0, 32, global_position)
			moveTween.interpolate_callback($SettleSound, 0.6, "startSound")
			moveTween.start()
			phase = 1
		else:
			position = path.curve.sample_baked(progress) + path.global_position
	elif phase == 5:
		damageSum += Data.of("driller.damage") * delta
		if damageSum >= damageUnit:
			damageSum -= damageUnit
			var dome = Level.domesByTeamId[teamId]
			dome.requestMeleeDamage(damageUnit * damageModifier, $HitPosition.global_position, self)
			InputSystem.shake(20, 0.2, 8, global_position)

func leave(delta: float):
	pass

func onGameLost():
	animateDeath()

func _on_sprite_2d_animation_looped() -> void :
	_animationFinishedCheck()

func _on_Sprite_animation_finished():
	_animationFinishedCheck()

func _animationFinishedCheck() -> void :
	if $Sprite2D.animation.begins_with("die_"):
		super.removeFreeBlocker()
	elif phase == 1:
		animation("attack_prepare")
		phase = 2
	elif phase == 2:
		animation("idle")
		phase = 3
	elif phase == 3:
		animation("attack_in")
		moveTween.interpolate_callback(InputSystem, 0.75, "shake", 100, 1.0, 32, global_position)
		moveTween.interpolate_callback($ImpactSound, 0.75, "startSound")
		moveTween.start()
		phase = 4
	elif phase == 4:
		phase = 5
		$Particles1.emitting = true
		$Particles2.emitting = true
		$PunchSound.startSound()
		animation("attack")

func _on_Sprite_frame_changed():
	pass






func animateDeath():
	$PunchSound.stop()
	if phase == 0:
		animation("die_walk")
	else:
		animation("die_attack")
	phase = 6
	$Particles1.emitting = false
	$Particles2.emitting = false
	$DieSound.startSound()
	$SettleSound.stop()


static func get_spawn_data(variant: String, teamId: String) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var moveType: String = Data.of("driller.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)


	stream.encode_u32(randi())

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())


	var moveType = Data.of("walker.movetype")
	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]

	Level.worldsByTeamId[teamId].assignPathOccupation(moveType, path, self)

func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_u32(pathIndex)
	stream.encode_float(progress)
	stream.encode_float(lastDelta)
	stream.encode_u8(phase)
	stream.encode_float(damageSum)
	stream.encode_bool(sprite.flip_h)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	stream.encode_vector2($HitPosition.global_position)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	_createdDueToFullSync = true
	var stream: = _apply_base_full_sync(buffer)
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	pathIndex = stream.decode_u32()
	progress = stream.decode_float()
	lastDelta = stream.decode_float()
	phase = stream.decode_u8()
	damageSum = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip, true)
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	Utils.decode_animated_sprite2d_state(stream, sprite)
	$HitPosition.global_position = stream.decode_vector2()

	meleeTarget = Level.domesByTeamId[teamId].getMeleeTarget(variant)
	if flip:
		$Particles1.process_material = preload("res://content/monster/driller/P1left.tres")
		$Particles2.process_material = preload("res://content/monster/driller/P2left.tres")
	else:
		$Particles1.process_material = preload("res://content/monster/driller/P1right.tres")
		$Particles2.process_material = preload("res://content/monster/driller/P2right.tres")

	var moveType = Data.of("walker.movetype")
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
	position = path.curve.sample_baked(progress) + path.global_position
	updateHitboxState()

func _set_animation_state_from_phase() -> void :
	if phase == 0:
		$Sprite2D.play("walk")
	if phase == 1:
		animation("settle")
		moveTween.interpolate_callback(InputSystem, 0.6, "shake", 100, 1.0, 32, global_position)
		moveTween.interpolate_callback($SettleSound, 0.6, "play")
		moveTween.start()
	if phase == 2:
		animation("attack_prepare")
	elif phase == 3:
		animation("idle")
	elif phase == 4:
		animation("attack_in")
		moveTween.interpolate_callback(InputSystem, 0.75, "shake", 100, 1.0, 32, global_position)
		moveTween.interpolate_callback($ImpactSound, 0.75, "play")
		moveTween.start()
	elif phase == 5:
		$Particles1.emitting = true
		$Particles2.emitting = true
		$PunchSound.startSound()
		animation("attack")
