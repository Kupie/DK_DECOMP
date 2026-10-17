class_name ScarabArm
extends "res://content/monster/Monster.gd"

var goalPos: Vector2
var variant: String
var path: Path2D
var progress
var speed: float
var delay: = 0.2

var random: RandomNumberGenerator
var pathIndex: int

func init():
	supports_full_sync = true

func subProcess(delta):
	if delay > 0.0:
		delay -= delta
		return

	var d = goalPos - position
	if d.length() < 3.0:
		grow()
		InputSystem.shake(80, 0.2, 8, global_position)
		set_physics_process(false)
		rotation = 0
		position += Vector2(-5, -5)
	else:
		var angle = d.angle()
		if angle > 0:
			rotation = d.angle() + PI * 1.6
		else:
			rotation = d.angle() - PI * 1.6
		position += (d.normalized() * delta * speed).limit_length(d.length())

func grow():
	$Sprite2D.play("grow")
	$GrowAndBurstSound.startSound()

func animateDeath():
	$Sprite2D.play("die")

func _on_Sprite_frame_changed():
	if not multiplayer.is_server():
		return

	if $Sprite2D.animation == "grow" and $Sprite2D.frame == 13:
		emit_signal("died")

		var monsterType: = Monster.Type.MUCKER
		var spawnData: = Mucker.get_spawn_data(variant, teamId, pathIndex, progress)
		Level.monstersByTeamId[teamId].monsterSynchronizer.network_spawn(monsterType, spawnData, teamId)

func _on_sprite_2d_animation_looped() -> void :
	_SpriteAnimationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_SpriteAnimationFinishedCheck()

func _SpriteAnimationFinishedCheck() -> void :
	if $Sprite2D.animation == "grow":
		queue_free()
	if $Sprite2D.animation == "die":
		removeFreeBlocker()

static func get_spawn_data(variant: String, teamId: String, spawnPosition: Vector2) -> PackedByteArray:
	var stream: = PackedByteStream.new()


	stream.encode_bool(Utils.get_side_bool_from_string(variant))


	var moveType: String = Data.of("walker.movetype")
	var pathIndex: int = Level.worldsByTeamId[teamId].getPathIndex(moveType, variant)
	stream.encode_u32(pathIndex)

	stream.encode_vector2(spawnPosition)

	return stream.data

func set_spawn_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)


	variant = Utils.get_side_string_from_bool(stream.decode_bool())


	var moveType = Data.of("walker.movetype")
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]

	position = stream.decode_vector2()

	random = RandomNumberGenerator.new()
	random.seed = UID

	$Sprite2D.play(variant)
	progress = random.randf_range(150, 250)
	goalPos = path.curve.sample_baked(progress) + path.global_position + Vector2(0, -10)
	speed = Data.of("scarabarm.speed") * random.randf_range(0.85, 1.15)


func get_full_sync_data() -> PackedByteArray:
	var stream: = _get_base_full_sync()
	stream.encode_vector2(goalPos)
	stream.encode_bool(Utils.get_side_bool_from_string(variant))
	stream.encode_float(progress)
	stream.encode_float(speed)
	stream.encode_float(delay)
	stream.encode_s64(random.seed)
	stream.encode_s64(random.state)
	stream.encode_s32(pathIndex)
	stream.encode_vector2(global_position)
	stream.encode_float(global_rotation)
	stream.encode_bool(sprite.flip_h)
	Utils.encode_animated_sprite2d_state(stream, sprite)
	return stream.data

func set_full_sync_data(buffer: PackedByteArray) -> void :
	var stream = _apply_base_full_sync(buffer)
	goalPos = stream.decode_vector2()
	variant = Utils.get_side_string_from_bool(stream.decode_bool())
	progress = stream.decode_float()
	speed = stream.decode_float()
	delay = stream.decode_float()
	random = RandomNumberGenerator.new()
	random.seed = stream.decode_s64()
	random.state = stream.decode_s64()
	pathIndex = stream.decode_s32()
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	var flip: bool = stream.decode_bool()
	setFlip(flip)
	Utils.decode_animated_sprite2d_state(stream, sprite)

	var moveType = Data.of("walker.movetype")
	pathIndex = stream.decode_u32()
	path = Level.worldsByTeamId[teamId].getPaths(moveType, variant)[pathIndex]
