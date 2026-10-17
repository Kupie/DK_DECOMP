extends Node2D

var tween: DeprecatedTween = DeprecatedTween.new()
var tile = null
var UID: int
var rng: RandomNumberGenerator

const MIN_DISTANCE_FROM_KEEPER = 50

func init():
	add_child(tween)
	$AnimatedSprite2D.play("appear")

	$deathTimer.wait_time = rng.randf_range(5, 20)
	$deathTimer.start()

	Style.init(self)
	$Spawn.startSound()

	if is_instance_valid(tile):
		tile.destroyed.connect(_on_tile_destroyed)
	else:
		queue_free()

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	global_position = stream.decode_vector2()
	global_rotation = stream.decode_float()
	UID = stream.decode_u32()
	rng = RandomNumberGenerator.new()
	rng.seed = UID
	var coord: = stream.decode_vector2()
	tile = Level.map.tiles.get(coord, null)

func die():
	$AnimatedSprite2D.play("disappear")
	$Despawn.startSound()

func _on_tile_destroyed(_teamId: String = "", _keeperTechId: String = "") -> void :
	die()

func _on_deathTimer_timeout():
	die()

func _physics_process(delta):
	for keeper in Keepers.getAll():
		if keeper.global_position.distance_to(global_position) < MIN_DISTANCE_FROM_KEEPER:
			die()
			return

	if not is_instance_valid(tile):
		die()

func _on_animated_sprite_2d_animation_looped() -> void :
	_AnimatedSpriteAnimationFinishedCheck()

func _on_AnimatedSprite_animation_finished() -> void :
	_AnimatedSpriteAnimationFinishedCheck()

func _AnimatedSpriteAnimationFinishedCheck() -> void :
	if $AnimatedSprite2D.animation == "appear":
		$AnimatedSprite2D.play("idle")
		$AnimatedSprite2D.frame = rng.randi() % 8

	if $AnimatedSprite2D.animation == "disappear":
		queue_free()
