extends Node2D

enum State{SEARCH, EAT, SCATTER, DIEING}
var state: int = State.SEARCH
var target = null
var target_position: Vector2
var target_origin: Vector2
var starting_position: Vector2
var scared: = false
var tween: DeprecatedTween = DeprecatedTween.new()

const MIN_DISTANCE_FROM_KEEPER = 50
const SCATTER_SPEED = 50
const SEARCH_SPEED = 10

var direction: Vector2
var UID: int
var rng: RandomNumberGenerator

func init():
	scale = Vector2(0.1, 0.1)

	add_child(tween)
	tween.interpolate_property(self, "scale", scale, Vector2(1, 1), 0.5, Tween.TRANS_CUBIC)
	tween.start()

	change_state(State.SEARCH)

	$deathTimer.wait_time = rng.randf_range(10, 20)
	$deathTimer.start()

	Style.init(self)

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	global_position = stream.decode_vector2()
	UID = stream.decode_u32()
	rng = RandomNumberGenerator.new()
	rng.seed = UID
	var target_drop: int = stream.decode_u32()
	if Level.drops.has_drop(target_drop):
		goto(Level.drops.get_drop(target_drop))
	else:
		queue_free()

func goto(t):
	starting_position = global_position
	if is_instance_valid(t):
		target = t
		target_position = target.global_position + Vector2(rng.randf_range(0, 5), 0).rotated(rng.randf() * TAU)
		target_origin = target.global_position

func die():
	if state != State.DIEING:
		state = State.DIEING
		tween.interpolate_property(self, "scale", scale, Vector2(0.0, 0.0), 0.2, Tween.TRANS_CUBIC)
		tween.interpolate_callback(self, 0.25, "queue_free")
		tween.start()

func _on_deathTimer_timeout():
	change_state(State.SCATTER)

func _physics_process(delta):
	if is_instance_valid(target):
		var current_origin = target_origin
		target_position = target.global_position + Vector2(rng.randf_range(0, 5), 0).rotated(rng.randf() * TAU)
		target_origin = target.global_position
		if current_origin.distance_to(target_origin) > 1:
			change_state(State.SCATTER)
	else:
		change_state(State.SCATTER)

	match state:
		State.SEARCH:
			if not is_instance_valid(target):
				die()

			direction = (target_position - global_position).rotated(rng.randf_range(-0.05, 0.05))
			global_position += direction.normalized() * SEARCH_SPEED * delta
			global_rotation = direction.angle()


			if global_position.distance_to(target_position) < 5:
				change_state(State.EAT)

			for keeper in Keepers.getAll():
				if keeper.global_position.distance_to(global_position) < MIN_DISTANCE_FROM_KEEPER:
					scared = true
					change_state(State.SCATTER)
					return

		State.EAT:
			direction += Vector2(5, 0).rotated(rng.randf() * TAU * 2) * delta
			if global_position.distance_to(target_position) > 5:
				direction = lerp(direction, (target_position - global_position).rotated(rng.randf_range(-0.1, 0.1)), delta * 5)
			global_position += direction.normalized() * SEARCH_SPEED * delta * 0.5
			global_rotation = direction.angle()
			for keeper in Keepers.getAll():
				if keeper.global_position.distance_to(global_position) < MIN_DISTANCE_FROM_KEEPER:
					scared = true
					change_state(State.SCATTER)
					return

		State.SCATTER:
			direction = (starting_position - global_position).rotated(rng.randf_range(-0.1, 0.1))
			var speed = SCATTER_SPEED if scared else SEARCH_SPEED * 2
			global_position += direction.normalized() * speed * delta
			global_rotation = direction.angle()
			if global_position.distance_to(starting_position) < 5:
				die()

func change_state(new_state: int):
	if rng.randf() < 0.3:
		$Nibble.startSound()

	state = new_state
	match state:
		State.SEARCH:

			$AnimatedSprite2D.play("crawl")

		State.EAT:

			$AnimatedSprite2D.play("eat")

		State.SCATTER:
			$AnimatedSprite2D.play("crawl")
			$AnimatedSprite2D.speed_scale = 3.0
