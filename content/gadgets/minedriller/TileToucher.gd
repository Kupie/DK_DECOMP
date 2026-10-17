extends Area2D

signal tile_destroyed
signal is_blocked_changed

var teamId: String

var timeBetweenHits: = 0.5
var cooldown: = 0.0
var didDrill: = false
var timePerTile: = 6.0
var moveSpeed: = 0.0
var drillSpeed: = 0.0
var drillOffset: = 0.0
var passThroughIndestructibleRock: = false
var powerOffPlayed: = false
var powerOnPlayed: = false
var is_blocked = null

@export var large: = true
@export var direction: Vector2

func serialize(data: Dictionary):
	data["cooldown"] = cooldown
	data["didDrill"] = didDrill
	data["timePerTile"] = timePerTile
	data["moveSpeed"] = moveSpeed
	data["drillSpeed"] = drillSpeed
	data["drillOffset"] = drillOffset
	data["position"] = var_to_str(position)

func deserialize(data: Dictionary):
	cooldown = data["cooldown"]
	didDrill = data["didDrill"]
	timePerTile = data["timePerTile"]
	moveSpeed = data["moveSpeed"]
	drillSpeed = data["drillSpeed"]
	drillOffset = data["drillOffset"]
	position = str_to_var(data["position"])

func should_mine_tile(t) -> bool:
	if Data.isDestructable(t):
		return true
	if not large:
		return false
	return Level.map.isWithinBounds(t.coord)

func _physics_process(delta):
	if GameWorld.gameover:
		$DrillSprite.speed_scale = 0
		$DrillSprite / shadow.speed_scale = 0
		$DrillSprite / DrillHitParticles.emitting = false
		if large:
			$DrillSprite / ParticlesSmoke.emitting = false
		if $Sounds / DrillSound:
			$Sounds / DrillSound.stopIfPlaying()
		if $Sounds / MoveSound:
			$Sounds / MoveSound.stopIfPlaying()
		return
	if GameWorld.paused:
		return

	update_move_sound()

	var tiles = get_overlapping_bodies()
	var canDrill: = false
	for tile in tiles:
		if should_mine_tile(tile):
			canDrill = true

	set_blocked( !canDrill and tiles.size() > 0)

	if canDrill:
		drillSpeed = lerp(drillSpeed, 1.0, delta)
		if cooldown > 0.0:
			cooldown -= delta * drillSpeed
			return
	else:
		drillSpeed = lerp(drillSpeed, 0.0, delta * Data.of(teamId + ".drill.drillrampup"))
		powerOnPlayed = false
		$DrillSprite.speed_scale = drillSpeed
		$DrillSprite / shadow.speed_scale = drillSpeed
		if $Sounds / DrillSound:
			$Sounds / DrillSound.stopIfPlaying()
		if $Sounds / PowerOffSound and not powerOffPlayed:
			$Sounds / PowerOffSound.startIfNotPlaying()
			powerOffPlayed = true
		$DrillSprite / DrillHitParticles.emitting = false
		if large:
			$DrillSprite / ParticlesSmoke.emitting = false
		if cooldown > 0.0:
			cooldown -= delta
			return

	if tiles.size() == 0:
		passThroughIndestructibleRock = false
		if didDrill:
			drillOffset = 0.0
			if direction.x == 0:
				cooldown = Data.of(teamId + ".drill.maindrillcooldown")
			else:
				cooldown = max(0.2, Data.of(teamId + ".drill.sidedrillcooldown"))
			didDrill = false
			tile_destroyed.emit()
			powerOffPlayed = false
			return

		position += direction * delta * Data.ofOr(teamId + ".drill.extensionspeed", 10) * moveSpeed
		moveSpeed = lerp(moveSpeed, 1.0, delta * 0.3)
		return
	else:
		var tile = null
		for t in tiles:
			if should_mine_tile(t):
				tile = t
				break

		$DrillSprite.play("default")

		$DrillSprite / shadow.play("default")
		if not tile and passThroughIndestructibleRock:
			move(delta)
			return
		passThroughIndestructibleRock = false

		$DrillSprite.speed_scale = drillSpeed
		$DrillSprite / shadow.speed_scale = drillSpeed
		$DrillSprite / DrillHitParticles.emitting = true
		if $Sounds / DrillSound:
			$Sounds / DrillSound.startIfNotPlaying()
		if tile and $Sounds / PowerOnSound and not powerOnPlayed:
			$Sounds / PowerOnSound.startIfNotPlaying()
			powerOnPlayed = true
		$DrillSprite / DrillHitParticles.amount_ratio = drillSpeed

		if large:
			$DrillSprite / ParticlesSmoke.emitting = true
			$DrillSprite / ParticlesSmoke.amount_ratio = drillSpeed

		moveSpeed = 0.0
		if drillSpeed < 0.8:
			return

		didDrill = true
		cooldown = timeBetweenHits
		passThroughIndestructibleRock = false

		if not tile:
			return

		var hardnessMod = 1.0 / (1.0 + tile.hardness / 4.0)
		var damage = hardnessMod * tile.max_health * (timeBetweenHits / timePerTile)
		if damage > 0:
			if multiplayer.is_server():
				tile.hit(global_position - tile.global_position, damage, teamId)
			var offset = (1.0 - tile.relativeHealth()) * (14 if large else 6)
			var diff = offset - drillOffset
			position += diff * direction
			drillOffset = offset
			spawn_dust(tile)


func spawn_dust(tile):
	var spawn_position: Vector2 = Level.map.to_local($DrillSprite.global_position - drillOffset * direction)
	if not Tile.position_in_view(spawn_position, Level.map):
		return
	var dirt_color = Level.map.getBiomeColorByCoord(tile.coord)
	for _i in randi_range(1, 3):
		var t = Data.TILE_DIRT_PARTICLE.instantiate()
		t.modulate = dirt_color
		t.type = tile.type
		t.position = spawn_position
		t.apply_central_impulse(direction.rotated(PI + randf_range(-0.7, 0.7)) * randf_range(40, 60))
		Level.map.call_deferred("addDrop", t)

func update_move_sound():
	if not $Sounds / MoveSound:
		return

	if moveSpeed > 0.1:
		$Sounds / MoveSound.startIfNotPlaying()
	elif moveSpeed < 0.1:
		$Sounds / MoveSound.stopIfPlaying()


func move(delta: float):
	if passThroughIndestructibleRock:

		if direction.x == 0:
			position += direction * delta * 10 * moveSpeed
		else:
			position += direction * delta * Data.of(teamId + ".drill.extensionspeed") * moveSpeed
		moveSpeed = lerp(moveSpeed, 1.0, delta * 0.3)

func set_blocked(value):
	if value != is_blocked:
		is_blocked = value
		is_blocked_changed.emit(value)

func to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_float(cooldown)
	stream.encode_bool(didDrill)
	stream.encode_float(timePerTile)
	stream.encode_float(moveSpeed)
	stream.encode_float(drillSpeed)
	stream.encode_float(drillOffset)
	stream.encode_vector2(position)
	return stream.data

func from_bytes(data: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(data)
	cooldown = stream.decode_float()
	didDrill = stream.decode_bool()
	timePerTile = stream.decode_float()
	moveSpeed = stream.decode_float()
	drillSpeed = stream.decode_float()
	drillOffset = stream.decode_float()
	position = stream.decode_vector2()
