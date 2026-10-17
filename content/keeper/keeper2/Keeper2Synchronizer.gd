extends KeeperSynchronizer

const SERIALIZED_KEEPER_BUFFER_SIZE = 34
const SERAILIZED_PINBALL_BUFFER_SIZE = 20

var pinballs: = {}
var pinball_position_buffers: = {}

func _ready() -> void :
	super._ready()
	keeper.pinballSpawned.connect(on_pinball_spawned)

func on_pinball_spawned(pinball: Pinball) -> void :
	pinballs[pinball.UID] = pinball
	if is_multiplayer_authority():
		pinball.destroyed.connect(on_pinball_destroyed.bind(pinball))
		pinball.exploded.connect(on_pinball_exploded.bind(pinball))
		pinball.hit_tile.connect(on_pinball_hit_tile.bind(pinball))
		pinball.bounce_sound_played.connect(on_pinball_bounce_sound_played.bind(pinball))
		pinball.reflected.connect(on_pinball_reflected.bind(pinball))

func on_pinball_destroyed(pinball: Pinball) -> void :
	network_rpc(destroy_pinball.bind(pinball.UID), true)

func on_pinball_exploded(playerId: String, pinball: Pinball) -> void :
	network_rpc(explode_pinball.bind(pinball.UID, playerId), true)

func on_pinball_bounce_sound_played(id: int, volume: float, pinball: Pinball) -> void :
	network_rpc(remote_play_bounce_sound.bind(pinball.UID, id, volume), false)

func on_pinball_reflected(pinball: Pinball) -> void :
	network_rpc(reflect_pinball.bind(pinball.UID), true)



@rpc("reliable", "any_peer")
func catch_pinball(UID: int) -> void :
	var pinball: Pinball = pinballs.get(UID)
	if pinball:
		pinballs.erase(UID)
		pinball.onPinballCaught()
	pinball_position_buffers.erase(UID)

@rpc("reliable")
func destroy_pinball(UID: int) -> void :
	var pinball: Pinball = pinballs.get(UID)
	if pinball:
		pinballs.erase(UID)
		pinball.onPinballDestroyed()
	pinball_position_buffers.erase(UID)

@rpc("reliable")
func explode_pinball(UID: int, playerId: String) -> void :
	var pinball: Pinball = pinballs.get(UID)
	if pinball:
		pinballs.erase(UID)
		pinball.onPinballExploded(playerId)
	pinball_position_buffers.erase(UID)

@rpc("reliable")
func remote_play_bounce_sound(UID: int, id: int, volume: float) -> void :
	var pinball: Pinball = pinballs.get(UID)
	if pinball:
		pinball.playBounceSound(id, volume)

@rpc("reliable")
func reflect_pinball(UID: int) -> void :
	var pinball: Pinball = pinballs.get(UID)
	if pinball:
		pinball.onPinballReflected()

func on_pinball_hit_tile(tile: Tile, pinballhit_scale: float, buffed: bool, position: Vector2, pinball: Pinball):
	network_rpc(show_remote_hit_effect.bind(pinball.UID, tile.coord, pinballhit_scale, buffed, position))

@rpc("reliable")
func show_remote_hit_effect(UID: int, tile_coord: Vector2, pinballhit_scale: float, buffed: bool, position: Vector2):
	var pinball: Pinball = pinballs.get(UID)
	if pinball:

		var tile: Tile = Level.map.getTile(tile_coord)
		if tile:
			pinball.showHitEffect(tile, pinballhit_scale, buffed, position)

func _physics_process(delta):
	super._physics_process(delta)

	if not is_multiplayer_authority():
		for pinball: Pinball in pinballs.values():
			var pinball_position_buffer: PositionBuffer = pinball_position_buffers.get(pinball.UID, null)
			if is_instance_valid(pinball_position_buffer):
				pinball_position_buffer.update_correction(delta)
				var sample: = pinball_position_buffer.sample(pinball.global_position)
				pinball.global_position = sample.position
				pinball.linear_velocity = sample.velocity

func get_delta_data(_peer_id: int) -> PackedByteArray:
	var buffer: = PackedByteStream.new()
	buffer.resize(SERIALIZED_KEEPER_BUFFER_SIZE)
	buffer.encode_vector2(keeper.global_position)
	buffer.encode_vector2(keeper.moveDirectionInput)
	buffer.encode_vector2(keeper.velocity)
	buffer.encode_bool(keeper.chargingCollect)
	buffer.encode_vector2(keeper.last_frame_vel)
	buffer.encode_u8(keeper.remainingSpheres)
	buffer.encode_vector2(keeper.get_camera_target_pos())

	for pinball: Pinball in pinballs.values():
		var pinball_buffer: = PackedByteStream.new()
		pinball_buffer.resize(SERAILIZED_PINBALL_BUFFER_SIZE)
		pinball_buffer.encode_u32(pinball.UID)
		pinball_buffer.encode_vector2(pinball.global_position)
		pinball_buffer.encode_vector2(pinball.linear_velocity)

		buffer.append_stream(pinball_buffer)

	return buffer.data

func set_delta_data(data: PackedByteArray) -> void :
	var buffer: = PackedByteStream.from_bytes(data)

	var network_position: = buffer.decode_vector2()
	keeper.moveDirectionInput = buffer.decode_vector2()
	var network_velocity: = buffer.decode_vector2()
	keeper.move = network_velocity
	keeper.chargingCollect = buffer.decode_bool()
	keeper.last_frame_vel = buffer.decode_vector2()
	keeper.setRemainingSpheres(buffer.decode_u8())
	keeper._remote_camera_target = buffer.decode_vector2()

	position_buffer.push_packet(server_tick, network_position, network_velocity)

	var packet_time: = Time.get_ticks_usec()


	var to_decode: int = floori(float(buffer.size() - SERIALIZED_KEEPER_BUFFER_SIZE) / float(SERAILIZED_PINBALL_BUFFER_SIZE))
	for i in range(to_decode):
		var pinball_buffer: = buffer.slice(SERAILIZED_PINBALL_BUFFER_SIZE)
		var UID: int = pinball_buffer.decode_u32()
		var pinball_position_buffer: PositionBuffer
		if pinball_position_buffers.has(UID):
			pinball_position_buffer = pinball_position_buffers[UID]
		else:
			pinball_position_buffer = PositionBuffer.new()
			pinball_position_buffers[UID] = pinball_position_buffer

		pinball_position_buffer.push_packet(server_tick, pinball_buffer.decode_vector2(), pinball_buffer.decode_vector2())

func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()

	var hasBallReflectArea: = is_instance_valid(keeper.ballReflectArea)
	stream.encode_bool(hasBallReflectArea)
	if hasBallReflectArea:
		var ballReflectArea: = keeper.ballReflectArea as BallReflectArea
		stream.encode_float(keeper.ballActionCooldown)
		stream.encode_vector2(ballReflectArea.position)
		stream.encode_float(ballReflectArea.lifetime)

	for pinball: Pinball in pinballs.values():
		stream.encode_u32(pinball.UID)
		stream.encode_vector2(pinball.global_position)
		stream.encode_vector2(pinball.linear_velocity)
		stream.encode_float(pinball.size)
		stream.encode_u8(pinball.generation)

	return stream.data

func set_initial_data(data: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(data)

	var hasBallReflectArea: = stream.decode_bool()
	if (hasBallReflectArea):

		match Data.of(keeper.playerId + ".keeper2.actionstage"):
			1: keeper.get_node("ReflectionOn").startSound()
			2: keeper.get_node("ReflectionOnUpgrade").startSound()
		keeper.reflect_cooldown_sprite.visible = true
		keeper.reflect_cooldown_sprite.play("active")
		var ballReflectArea: = preload("res://content/keeper/keeper2/BallReflectArea.tscn").instantiate() as BallReflectArea
		keeper.ballReflectArea = ballReflectArea
		keeper.ballActionCooldown = stream.decode_float()
		ballReflectArea.position = stream.decode_vector2()
		ballReflectArea.lifetime = stream.decode_float()
		ballReflectArea.set_multiplayer_authority(keeper.peerId)
		keeper.get_parent().add_child(ballReflectArea)
		ballReflectArea.ballReflected.connect(keeper.onBallReflected)

	while stream.is_not_finished():
		var pinball = preload("res://content/keeper/keeper2/Pinball.tscn").instantiate()
		pinball.UID = stream.decode_u32()
		pinball.name = "Pinball-%d" % pinball.UID
		pinball.global_position = stream.decode_vector2()
		pinball.linear_velocity = stream.decode_vector2()
		pinball.size = stream.decode_float()
		pinball.playerId = keeper.playerId
		pinball.generation = stream.decode_u8()
		pinball.set_multiplayer_authority(keeper.peerId)
		owner.get_parent().add_child(pinball)
		if pinball.generation > 1:
			pinball.lifeTime *= pinball.size
			pinball.modulate.b = 0.6
		pinballs[pinball.UID] = pinball
