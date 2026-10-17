extends RigidBody2D

enum State{SEARCH, EAT, SCATTER}
var state: int = State.SEARCH
var tween: DeprecatedTween = DeprecatedTween.new()
var UID: int
var rng: RandomNumberGenerator

signal state_changed(state, direction)

const MIN_DISTANCE_FROM_KEEPER = 70
const MOVE_SPEED = 30

var direction: Vector2
var tile_normal: Vector2
var wall_normal: Vector2
var touching_wall = false
var touching_floor = false

func init():
	add_child(tween)
	Style.init(self)
	$deathTimer.wait_time = rng.randf_range(40, 120)
	$deathTimer.start()
	if multiplayer.is_server():
		$decisionTimer.start()
	$AnimatedSprite2D.play("appear")

func set_spawn_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	global_position = stream.decode_vector2()
	UID = stream.decode_u32()
	rng = RandomNumberGenerator.new()
	rng.seed = UID

func die():
	gravity_scale = 0
	$AnimatedSprite2D.play("disappear")

func _on_deathTimer_timeout():
	change_state(State.SCATTER)





func _physics_process(delta):
	var facing = Vector2.ZERO
	facing = linear_velocity if linear_velocity.length() > 1 else Vector2.ZERO
	if facing.length():
		$AnimatedSprite2D.global_rotation = 0
		$AnimatedSprite2D.flip_v = false
		$AnimatedSprite2D.flip_h = false

		if facing.x < 0:

			$AnimatedSprite2D.global_rotation = 0
			$AnimatedSprite2D.flip_v = false
			$AnimatedSprite2D.flip_h = true

		if facing.x >= 0:

			$AnimatedSprite2D.global_rotation = 0
			$AnimatedSprite2D.flip_v = false
			$AnimatedSprite2D.flip_h = false

		if facing.y <= 0:

			if wall_normal.x > 0:

				$AnimatedSprite2D.global_rotation = - PI / 2
				$AnimatedSprite2D.flip_v = false
				$AnimatedSprite2D.flip_h = false
			elif wall_normal.x < 0:

				$AnimatedSprite2D.global_rotation = - PI / 2
				$AnimatedSprite2D.flip_v = true
				$AnimatedSprite2D.flip_h = false

		if facing.y > 0:

			if wall_normal.x > 0:

				$AnimatedSprite2D.global_rotation = - PI / 2
				$AnimatedSprite2D.flip_v = false
				$AnimatedSprite2D.flip_h = true
			elif wall_normal.x < 0:

				$AnimatedSprite2D.global_rotation = - PI / 2
				$AnimatedSprite2D.flip_v = true
				$AnimatedSprite2D.flip_h = true


	if state != State.SCATTER:
		if linear_velocity.length() < 0.1:
			$AnimatedSprite2D.play("idle")
		else:
			$AnimatedSprite2D.play("crawl")

	match state:
		State.SEARCH:
			if linear_velocity.length() < rng.randf_range(5, 20):
				apply_central_impulse(direction * MOVE_SPEED)
			if touching_wall:
				for keeper in Keepers.getAll():
					if keeper.global_position.distance_to(global_position) < MIN_DISTANCE_FROM_KEEPER:
						change_state(State.SCATTER)
						return
		State.EAT:
			if touching_wall:
				for keeper in Keepers.getAll():
					if keeper.global_position.distance_to(global_position) < MIN_DISTANCE_FROM_KEEPER:
						change_state(State.SCATTER)
						return
		State.SCATTER:


			if linear_velocity.length() < 5:
				die()

func _on_decisionTimer_timeout():
	if state == State.SCATTER:
		return

	change_state(State.SEARCH)
	if wall_normal.y > 0 or tile_normal.y > 0:

		if rng.randf() < 0.2:
			change_state(State.EAT)
		elif rng.randf() < 0.5:
			direction = Vector2(1, 0)
		else:
			direction = Vector2(-1, 0)
	elif wall_normal.y < 0:

		direction = Vector2(0, 1)
	else:

		direction = Vector2(0, -1)

	state_changed.emit(state, direction)

func _integrate_forces(state):

	if state.get_contact_count():
		for i in range(state.get_contact_count()):
			tile_normal = - state.get_contact_local_normal(i)
			if abs(tile_normal.y) == 0:
				break
	else:
		if tile_normal.length():
			apply_central_impulse((tile_normal + Vector2(0, rng.randf_range(-0.5, 0))) * MOVE_SPEED)
		tile_normal = Vector2.ZERO


	var normals: = []
	wall_normal = Vector2.ZERO
	touching_floor = false
	if $RayCastUp.is_colliding():
		touching_wall = false
		direction = Vector2.ZERO
	else:
		if $RayCastRight.is_colliding():
			touching_wall = true
			normals.append(Vector2(1, 0))
		if $RayCastLeft.is_colliding():
			touching_wall = true
			normals.append(Vector2(-1, 0))
		if $RayCastFloor.is_colliding():
			touching_wall = true
			touching_floor = true
			normals.append(Vector2(0, 1))

	if normals.size() and touching_wall:
		normals.shuffle()
		wall_normal = normals[0]
	else:
		touching_wall = false
		wall_normal = Vector2.ZERO

	if tile_normal.length() == 0 and wall_normal.length() == 0:
		direction = Vector2.ZERO

func _on_Rat_body_entered(body):
	if state == State.SCATTER:

		die()

func change_state(new_state: int):
	if rng.randf() < 0.3:
		$Squeal.startSound()

	state = new_state
	match state:
		State.SEARCH:

			$AnimatedSprite2D.play("crawl")

		State.EAT:

			$AnimatedSprite2D.play("idle")

		State.SCATTER:
			$AnimatedSprite2D.play("idle")


func _on_animated_sprite_2d_animation_looped() -> void :
	_AnimatedSpriteAnimationFinishedCheck()

func _on_AnimatedSprite_animation_finished() -> void :
	_AnimatedSpriteAnimationFinishedCheck()

func _AnimatedSpriteAnimationFinishedCheck() -> void :
	if $AnimatedSprite2D.animation == "appear":
		change_state(State.SEARCH)

	if $AnimatedSprite2D.animation == "disappear":
		queue_free()
