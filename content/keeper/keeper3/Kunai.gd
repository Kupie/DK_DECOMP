extends RigidBody2D

var playerId: String
var teamId: String
var exploded = false
var has_hit = false
var lastVelocity: Vector2
var radius = 1
var damage = 10
var phase: float = 0.0
var collideDelay = 0
var alwaysRemoveCenter = true

var charged = false
var alwayRemoveSides = false
var bounceCount: int = 0
var targetTile: Node = null
var has_damage_upgrade: = false
var has_fast_throw: = false
var shuriken_level: = 1


var lastPos: Vector2
var lastPosInitialized: = false
var spawnPosition: Vector2
var totalDistanceTraveled: float = 0.0

@onready var kunaiSprite: Node2D = $KunaiSprite
@onready var kunaiBlinkSprite: Node2D = $KunaiSprite / Blink
@onready var shurikenSprite: Node2D = $ShurikenSprite
@onready var shurikenBlinkSprite: Node2D = $KunaiSprite / Blink
@onready var light_node: Sprite2D = $LightNode

var _defaultZIndex: = 0
var _defaultSpriteZIndex: = 0
var _lastChargedState: = false


var hitPoint: Vector2
var hitNormal: Vector2
var hitTileCoord
var hitTile: Node

var bulletSmoke: Node2D = null
var bulletSmokeTween: Tween
var lastPoint: Vector2

var _explode_countdown: float = -1.0

var _was_paused: = false
var _saved_linear_velocity: Vector2
var _saved_angular_velocity: float
var _saved_rotation: float
var _saved_freeze: bool

func _ready() -> void :
	_defaultZIndex = Keeper3GameplaySettings.KUNAI_STICK_Z_INDEX
	_defaultSpriteZIndex = Keeper3GameplaySettings.KUNAI_STICK_Z_INDEX
	z_index = Keeper3GameplaySettings.KUNAI_STICK_Z_INDEX
	_set_sprite_z_index(Keeper3GameplaySettings.KUNAI_STICK_Z_INDEX)
	_lastChargedState = charged
	_update_charge_visuals()
	spawnPosition = global_position
	totalDistanceTraveled = 0.0
	start_bullet_smoke()
	shurikenSprite.as_thrown(radius)
	Level.map.lights.add_simple_light(self, light_node)
	light_node.scale.x = 0.4

func start_bullet_smoke():
	bulletSmoke = preload("res://content/weapons/artillery/BulletSmoke.tscn").instantiate()
	get_parent().add_child(bulletSmoke)
	bulletSmoke.material = preload("res://content/keeper/keeper3/effects/KunaiTrailMat.tres")
	bulletSmoke.top_level = true
	bulletSmoke.width = 8.0 if charged else 3.0
	bulletSmoke.points[0] = global_position
	bulletSmoke.points[1] = global_position
	bulletSmoke.modulate.r = randf()
	bulletSmoke.modulate.g = randf()
	self.connect("tree_exiting", bulletSmoke.queue_free, CONNECT_ONE_SHOT)
	bulletSmokeTween = bulletSmoke.create_tween()
	bulletSmokeTween.tween_property(bulletSmoke, "modulate:b", 0.4, 2.0).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.1)
	bulletSmokeTween.tween_property(bulletSmoke, "modulate:b", 1.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Style.init(bulletSmoke)

func update_bullet_smoke(delta):
	if bulletSmoke.points.is_empty():
		return
	if lastPoint.distance_to(global_position) > 5.0:
		lastPoint = global_position
		bulletSmoke.add_point(global_position)
	else:
		bulletSmoke.points[-1] = global_position
	if bulletSmoke.get_point_count() > 30:
		bulletSmoke.remove_point(0)

func remove_bullet_point():
	if bulletSmoke.get_point_count() > 0:
		bulletSmoke.remove_point(0)

func kill_bullet_trail():
	if bulletSmokeTween:
		bulletSmokeTween.kill()
	bulletSmokeTween = bulletSmoke.create_tween()
	bulletSmokeTween.tween_property(bulletSmoke, "modulate:b", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void :
	if not Level.initialized:
		return

	if GameWorld.paused:
		if not _was_paused:
			_was_paused = true
			_saved_linear_velocity = linear_velocity
			_saved_angular_velocity = angular_velocity
			_saved_freeze = freeze
			if not has_hit and lastVelocity.length_squared() > Keeper3GameplaySettings.KUNAI_ROTATION_VELOCITY_EPS:
				_saved_rotation = lastVelocity.angle() + PI * 0.5
			else:
				_saved_rotation = rotation
			freeze = true
		rotation = _saved_rotation
		return

	if _was_paused:
		_was_paused = false
		freeze = _saved_freeze
		rotation = _saved_rotation
		if not freeze:
			linear_velocity = _saved_linear_velocity
			angular_velocity = _saved_angular_velocity
	_update_charge_state()
	_spin_charged_sprite(delta)
	if not has_hit:
		_update_rotation_from_velocity()
	update_bullet_smoke(delta)
	light_node.rotation = rotation

	if not has_hit and not exploded:
		totalDistanceTraveled = spawnPosition.distance_to(global_position)
		if totalDistanceTraveled >= Keeper3GameplaySettings.KUNAI_MAX_DISTANCE:
			explode()
			return


	if has_hit and _explode_countdown >= 0.0:
		remove_bullet_point()
		_explode_countdown -= delta
		var explosion_progress: float = abs(1.0 - clampf(_explode_countdown / Keeper3GameplaySettings.KUNAI_EXPLODE_DELAY, 0.0, 1.0))
		var freq: float = 1.0 + (20.0) * pow(explosion_progress, 2.0)
		phase += freq * delta
		var is_active: = fmod(phase, 1.0) > 0.5
		light_node.modulate.a = 1.0 if is_active else 0.5
		if is_instance_valid(kunaiBlinkSprite):
			kunaiBlinkSprite.visible = is_active
		if is_instance_valid(shurikenBlinkSprite):
			shurikenBlinkSprite.visible = is_active
		if _explode_countdown <= 0.0 and not exploded:
			explode()
		return


	if has_hit:
		return


	if collideDelay > 0:
		collideDelay -= delta
		return


	if not lastPosInitialized:
		lastPos = global_position
		lastPosInitialized = true
		return



	var from: Vector2 = lastPos
	var to: Vector2 = global_position
	lastPos = global_position
	if from.distance_to(to) > 0.005:
		var res: = HighPrecisionCollision.sweep_and_snap(self, Keeper3GameplaySettings.KUNAI_COLLISION_RADIUS, from, to, [get_rid()])
		if res.get("collided", false) and not has_hit:

			if res.has("snap_position"):
				global_position = res.snap_position
				lastPos = global_position

			collideBody(res.get("collider", null), res.get("point", null), res.get("normal", null))

func _update_rotation_from_velocity() -> void :
	var velocity: Vector2 = linear_velocity
	if velocity.length_squared() > Keeper3GameplaySettings.KUNAI_ROTATION_VELOCITY_EPS:
		lastVelocity = velocity
	if lastVelocity.length_squared() > Keeper3GameplaySettings.KUNAI_ROTATION_VELOCITY_EPS:
		rotation = lastVelocity.angle() + PI * 0.5

func _spin_charged_sprite(delta: float) -> void :
	if not charged or has_hit:
		return
	if not is_instance_valid(shurikenSprite) or not shurikenSprite.visible:
		return
	if linear_velocity.length_squared() <= Keeper3GameplaySettings.KUNAI_ROTATION_VELOCITY_EPS:
		return
	shurikenSprite.rotation += delta * Keeper3GameplaySettings.KUNAI_STAR_SPIN_SPEED

func _update_charge_state() -> void :
	if charged == _lastChargedState:
		return
	var was_charged: = _lastChargedState
	_lastChargedState = charged
	_update_charge_visuals(was_charged)

func _update_charge_visuals(was_charged: bool = charged) -> void :
	if is_instance_valid(bulletSmoke):
		bulletSmoke.width = 8.0 if charged else 3.0
	var show_star: = charged and is_instance_valid(shurikenSprite)
	if is_instance_valid(kunaiSprite):
		kunaiSprite.visible = not show_star
	if is_instance_valid(shurikenSprite):
		shurikenSprite.visible = show_star
		if not show_star or (show_star and not was_charged):
			shurikenSprite.rotation = 0.0
	var target_z_index: = Keeper3GameplaySettings.KUNAI_STICK_Z_INDEX if has_hit else _defaultSpriteZIndex
	_set_sprite_z_index(target_z_index)

func _set_sprite_z_index(value: int) -> void :
	if is_instance_valid(kunaiSprite):
		kunaiSprite.z_index = value
	if is_instance_valid(shurikenSprite):
		shurikenSprite.z_index = value

func _hide_all_sprites() -> void :
	if is_instance_valid(kunaiSprite):
		kunaiSprite.visible = false
	if is_instance_valid(shurikenSprite):
		shurikenSprite.visible = false

func _apply_surface_stick_rotation(hit_normal: Vector2) -> void :
	var forward: Vector2 = lastVelocity
	if forward.length_squared() <= Keeper3GameplaySettings.KUNAI_ROTATION_VELOCITY_EPS:
		if hit_normal.length_squared() == 0.0:
			return
		forward = - hit_normal.normalized()
	else:
		forward = forward.normalized()
	var base_angle: = forward.angle() + PI * 0.5
	rotation = base_angle
	z_index = Keeper3GameplaySettings.KUNAI_STICK_Z_INDEX
	_set_sprite_z_index(Keeper3GameplaySettings.KUNAI_STICK_Z_INDEX)

func _spawn_tile_burst_vfx(hit_point: Vector2, normal: Vector2) -> void :
	var parent: = get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var effect: Node2D = Keeper3SecondarySettings.KUNAI_TILE_BURST_VFX.instantiate()
	var offset_normal: Vector2 = normal.normalized() if normal.length_squared() > 0.0 else Vector2.ZERO
	parent.add_child(effect)
	effect.global_position = hit_point + offset_normal * 2.0
	if effect.has_method("setup"):
		effect.setup(normal)
	_spawn_impact_particles(hit_point, normal, parent)

func _spawn_impact_particles(hit_point: Vector2, normal: Vector2, parent: Node) -> void :
	var impact_rotation: float = normal.angle() if normal.length_squared() > 0.0 else 0.0

	var spark_amount: = 4
	if Options.reducedParticles:
		spark_amount = 2
	for _i in range(spark_amount + randi() % 2):
		var s = Data.KEEPER_SPARK.instantiate()
		s.global_position = hit_point
		parent.add_child(s)
		s.apply_central_impulse(Vector2.RIGHT.rotated(impact_rotation + randf_range(-0.5, 0.5)) * randf_range(20, 100))

	var inward_normal: = - normal if normal.length_squared() > 0.0 else Vector2.ZERO
	var sample_point: = hit_point + inward_normal * Keeper3GameplaySettings.KUNAI_TILE_SAMPLE_EPS
	var tile_coord: Vector2 = Vector2(Level.map.getTileCoord(sample_point))
	var tile: Node = Level.map.getTile(tile_coord)

	var dirt_color: Color = Level.map.getBiomeColorByCoord(tile_coord)
	var tile_type = tile.type if tile != null and "type" in tile else ""

	var dirt_amount: = 2
	if Options.reducedParticles:
		dirt_amount = 1
	for _i in range(dirt_amount + randi() % 2):
		var t = Data.TILE_DIRT_PARTICLE.instantiate()
		t.modulate = dirt_color
		t.type = tile_type
		t.global_position = hit_point
		parent.add_child(t)
		t.apply_central_impulse(Vector2.RIGHT.rotated(impact_rotation + randf_range(-0.7, 0.7)) * randf_range(40, 100))


func _spawn_bounce_vfx(impact_point: Vector2, normal_dir: Vector2, travel_velocity: Vector2) -> void :
	var effect: Node2D = Keeper3SecondarySettings.KUNAI_BOUNCE_VFX.instantiate()
	get_parent().add_child(effect)
	effect.global_position = impact_point + normal_dir * 2.0
	if travel_velocity.length_squared() > 0.0:
		effect.rotation = travel_velocity.angle()
	var effect_sparks: Node2D = preload("res://content/keeper/keeper3/effects/KunaiBounce.tscn").instantiate()
	effect_sparks.position = effect.position
	effect_sparks.rotation = effect.rotation
	effect_sparks.scale = Vector2.ONE * 0.5
	get_parent().add_child(effect_sparks)


func _play_bounce_sound(impact_point: Vector2) -> void :
	var parent: = get_parent()
	if parent == null or not is_instance_valid(parent):
		parent = self

	var sound: Node
	if charged:
		sound = %KunaiChargedBounce
	elif has_fast_throw:
		sound = %KunaiQuickBounceSound
	else:
		sound = %KunaiBounceSound
	var s = sound.duplicate(DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
	s.setSimulatedPosition(impact_point)
	parent.add_child(s)
	s.startSound()

func _play_resource_reveal_sounds(impact_point: Vector2, found_types: Dictionary) -> void :
	var parent: = get_parent()
	if parent == null or not is_instance_valid(parent):
		parent = self

	for tile_type in found_types.keys():
		var sound_template: Node = null

		match tile_type:
			Data.TILE_IRON:
				sound_template = %KunaiBounceRevealIronSound
			Data.TILE_SAND:
				sound_template = %KunaiBounceRevealSandSound
			Data.TILE_WATER:
				sound_template = %KunaiBounceRevealWaterSound

		if sound_template == null:
			continue

		var s = sound_template.duplicate()
		s.simulatedPosition = impact_point
		parent.add_child(s)
		s.startSound()

func collideBody(collider, hit_position = null, hit_normal = null):
	if collider == null:
		return

	var impact_point: Vector2 = hit_position if hit_position is Vector2 else global_position
	var impact_normal: Vector2 = Vector2.ZERO
	if hit_normal != null:
		impact_normal = hit_normal.normalized()
	elif lastPosInitialized and global_position != lastPos:
		impact_normal = (lastPos - global_position).normalized()

	if _try_bounce(impact_point, impact_normal, collider):
		return


	has_hit = true
	light_node.scale.x = 1.0
	kill_bullet_trail()

	hitPoint = impact_point
	hitNormal = impact_normal

	_apply_surface_stick_rotation(hitNormal)
	_spawn_tile_burst_vfx(hitPoint, hitNormal)
	_play_impact_sound(hitPoint)


	lastPos = global_position


	var inwardNormal: = - hitNormal if hitNormal != Vector2.ZERO else Vector2.ZERO
	var samplePoint: = hitPoint + inwardNormal * Keeper3GameplaySettings.KUNAI_TILE_SAMPLE_EPS
	hitTileCoord = Vector2(Level.map.getTileCoord(samplePoint))
	var t = Level.map.getTile(hitTileCoord)
	if t == null:
		Level.map.revealTile(hitTileCoord)
		t = Level.map.getTile(hitTileCoord)

	if collider != null and collider.has_meta("destructable"):
		hitTile = collider
	else:
		hitTile = t


	sleeping = true
	freeze = true


	_defer_explode()

func _defer_explode() -> void :
	_explode_countdown = Keeper3GameplaySettings.KUNAI_EXPLODE_DELAY



func resetRigidBody():
	has_hit = false
	sleeping = false
	freeze = false
	z_index = _defaultZIndex
	bounceCount = 0
	_update_charge_visuals(false)
	spawnPosition = global_position
	totalDistanceTraveled = 0.0

func explode(direction: = Vector2.ZERO):
	if exploded:
		return
	exploded = true

	var tileCoord = hitTileCoord if hitTileCoord != null else Vector2(Level.map.getTileCoord(global_position))
	var tileNode = hitTile if hitTile != null else Level.map.getTile(tileCoord)

	_play_explosion_sound()
	_hide_all_sprites()
	var ex: Node2D
	if charged:
		InputSystem.shake(100, 0.35, 12, global_position)
		ex = load("res://content/effects/explosions/ExplosionNew.tscn").instantiate()
	else:
		if Options.shakeDrill:
			InputSystem.shake(40, 0.35, 16, global_position)
		ex = load("res://content/effects/explosions/ExplosionNewDirectional.tscn").instantiate()
		ex.scale *= 0.7
		ex.rotation = global_rotation - PI / 2.0
		var ex_slash = load("res://content/effects/explosions/ExplosionSlash.tscn").instantiate()
		ex_slash.position = global_position
		ex_slash.rotation = global_rotation - PI / 2.0
		ex_slash.scale = Vector2.ONE * 0.5
		get_parent().add_child(ex_slash)

	ex.position = global_position
	get_parent().add_child(ex)

	if is_multiplayer_authority():

		if charged and radius > 0:
			Level.map.damageTileCircleArea(global_position, radius, 1000, teamId)
		else:

			if tileNode != null and Data.isDestructable(tileNode):
				var v = global_position - tileNode.global_position
				var hardnessMod = 1.0
				if tileNode.hardness >= 3:
					hardnessMod += Data.of(playerId + ".keeper3.kunaiweaknessagainsthardrock") * pow(tileNode.hardness - 2, 2) / 4.0
				tileNode.hit(v, hardnessMod * damage, teamId, "keeper3")

	explosionCleanUp()

func _play_explosion_sound():
	var sound: Node
	if charged:
		match shuriken_level:
			3: sound = %ShurikenLevel3ExplodeSound
			2: sound = %ShurikenLevel2ExplodeSound
			_: sound = %Shurikenlevel1ExplodeSound
	elif has_damage_upgrade:
		sound = %KunaiUpgradedExplosionSound
	else:
		sound = %KunaiExplosionSound
	var s = sound.duplicate()
	get_parent().add_child(s)
	s.simulatedPosition = global_position
	s.startSound()

func _play_impact_sound(impact_point: Vector2) -> void :
	var parent: = get_parent()
	if parent == null or not is_instance_valid(parent):
		parent = self
	var sound = %ShurikenImpactSound if charged else %KunaiImpactSound
	var s = sound.duplicate()
	s.simulatedPosition = impact_point
	parent.add_child(s)
	s.startSound()

func explosionCleanUp():
	exploded = true
	queue_free()

func getTilesInRadius(centerCoord, radius) -> Array[Dictionary]:
	var tilesToHit: Array[Dictionary] = []
	var ceiled_radius = ceil(radius)
	var startCoord = Vector2(centerCoord.x - ceiled_radius, centerCoord.y - ceiled_radius)
	var endCoord = Vector2(centerCoord.x + ceiled_radius, centerCoord.y + ceiled_radius)
	var currentCoord = startCoord
	while (currentCoord.y <= endCoord.y):
		while (currentCoord.x <= endCoord.x):
			var dist = Vector2(centerCoord.x - currentCoord.x, centerCoord.y - currentCoord.y).length()
			if dist <= radius:

				var tile = Level.map.getTile(currentCoord)
				if tile == null:
					Level.map.revealTile(currentCoord)
					tile = Level.map.getTile(currentCoord)


				if tile != null and Data.isDestructable(tile):
					tilesToHit.append({
						"tile": tile, 
						"coord": currentCoord, 
						"distance": currentCoord.distance_to(centerCoord)
					})

			currentCoord.x += 1

		currentCoord.x = startCoord.x
		currentCoord.y += 1

	return tilesToHit

func isCarried():
	return false

func canFocusCarry() -> bool:
	return false

func _try_bounce(impact_point: Vector2, impact_normal: Vector2, collider = null) -> bool:
	if charged:
		return false
	if bounceCount >= Keeper3GameplaySettings.KUNAI_BOUNCE_MAX_COUNT:
		return false
	if impact_normal.length_squared() == 0.0:
		return false
	var incoming_velocity: Vector2 = linear_velocity
	if incoming_velocity.length_squared() <= Keeper3GameplaySettings.KUNAI_ROTATION_VELOCITY_EPS and lastVelocity.length_squared() > Keeper3GameplaySettings.KUNAI_ROTATION_VELOCITY_EPS:
		incoming_velocity = lastVelocity
	if incoming_velocity.length_squared() <= Keeper3GameplaySettings.KUNAI_MIN_BOUNCE_SPEED * Keeper3GameplaySettings.KUNAI_MIN_BOUNCE_SPEED:
		return false




	var motion_dir: Vector2 = incoming_velocity.normalized()
	var normal_dir: Vector2 = impact_normal.normalized()
	var dot: float = clamp( - motion_dir.dot(normal_dir), -1.0, 1.0)
	var incidence_angle: float = rad_to_deg(acos(dot))
	if incidence_angle < Keeper3GameplaySettings.KUNAI_BOUNCE_MIN_ANGLE_DEGREES:
		return false

	_process_bounce(impact_point, normal_dir, incoming_velocity, collider)
	return true

func _process_bounce(impact_point: Vector2, normal_dir: Vector2, incoming_velocity: Vector2, collider = null) -> void :
	bounceCount += 1
	var separation_distance: float = Keeper3GameplaySettings.KUNAI_COLLISION_RADIUS + Keeper3GameplaySettings.KUNAI_BOUNCE_SEPARATION
	global_position = impact_point + normal_dir * separation_distance
	var reflected_velocity: Vector2 = incoming_velocity.bounce(normal_dir) * Keeper3GameplaySettings.KUNAI_BOUNCE_DAMPING
	if reflected_velocity.length_squared() < Keeper3GameplaySettings.KUNAI_MIN_BOUNCE_SPEED * Keeper3GameplaySettings.KUNAI_MIN_BOUNCE_SPEED:
		if reflected_velocity.length_squared() > 0.0:
			reflected_velocity = reflected_velocity.normalized() * Keeper3GameplaySettings.KUNAI_MIN_BOUNCE_SPEED
		else:
			reflected_velocity = incoming_velocity.normalized() * Keeper3GameplaySettings.KUNAI_MIN_BOUNCE_SPEED
	_spawn_bounce_vfx(impact_point, normal_dir, reflected_velocity)
	_play_bounce_sound(impact_point)
	if reflected_velocity.length_squared() > 0.0 and Keeper3GameplaySettings.KUNAI_BOUNCE_FORWARD_OFFSET > 0.0:
		global_position += reflected_velocity.normalized() * Keeper3GameplaySettings.KUNAI_BOUNCE_FORWARD_OFFSET
	lastPos = global_position
	sleeping = false
	freeze = false
	has_hit = false
	linear_velocity = reflected_velocity
	angular_velocity = 0.0
	lastVelocity = reflected_velocity
	collideDelay = max(collideDelay, Keeper3GameplaySettings.KUNAI_BOUNCE_COLLIDE_DELAY)
	_update_rotation_from_velocity()

	var sonar_range = Data.of(playerId + ".keeper3.bouncesonarrange")
	if sonar_range > 0:
		add_sonar_vfx()
		reveal_tiles(sonar_range, normal_dir, collider)

func add_sonar_vfx():
	var sonar_vfx: = preload("res://content/keeper/keeper3/KunaiSonar.tscn").instantiate()
	sonar_vfx.position = position
	get_parent().add_child(sonar_vfx)

func reveal_tiles(sonar_range: int, normal_dir: Vector2, collider):
	var base_coord = Vector2(Level.map.getTileCoord(collider.global_position))
	base_coord += normal_dir.rotated(PI)
	sonar_range -= 1

	var found_types: Dictionary = {}

	for x in range( - sonar_range, sonar_range + 1):
		for y in range( - sonar_range, sonar_range + 1):
			var dist = abs(x) + abs(y)
			if abs(x) + abs(y) > sonar_range:
				continue
			var coord = Vector2(int(base_coord.x) + x, int(base_coord.y) + y)
			var resource_type = Level.map.getTileData().get_resource(coord.x, coord.y)
			if Level.map.isCaveTile(coord):
				continue

			var is_new_reveal = Level.map.getTile(coord) == null
			if is_new_reveal and (resource_type == Data.TILE_IRON or resource_type == Data.TILE_SAND or resource_type == Data.TILE_WATER):
				found_types[resource_type] = true

			var delay = dist * 0.12 * randf_range(0.6, 1.4)
			Level.map.networkRevealTile(coord, delay)

	_play_resource_reveal_sounds(collider.global_position, found_types)
