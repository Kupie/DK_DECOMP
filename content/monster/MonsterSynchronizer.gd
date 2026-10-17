class_name MonsterSynchronizer
extends Synchronizer

signal spawned(monster: Monster)

var monster_scenes = {
	Monster.Type.WALKER: preload("res://content/monster/walker/Walker.tscn"), 
	Monster.Type.FLYER: preload("res://content/monster/flyer/Flyer.tscn"), 
	Monster.Type.STINGRAY: preload("res://content/monster/stingray/Stingray.tscn"), 
	Monster.Type.MUCKER: preload("res://content/monster/mucker/Mucker.tscn"), 
	Monster.Type.BOLTER: preload("res://content/monster/bolter/Bolter.tscn"), 
	Monster.Type.DRILLER: preload("res://content/monster/driller/Driller.tscn"), 
	Monster.Type.SHIFTER: preload("res://content/monster/shifter/Shifter.tscn"), 
	Monster.Type.ROCKMAN: preload("res://content/monster/rockman/Rockman.tscn"), 
	Monster.Type.TORMENTOR: preload("res://content/monster/tormentor/Tormentor.tscn"), 
	Monster.Type.BUTTERFLY: preload("res://content/monster/butterfly/Butterfly.tscn"), 
	Monster.Type.BEAST: preload("res://content/monster/Beast/Beast.tscn"), 
	Monster.Type.WORM: preload("res://content/monster/worm/Worm.tscn"), 
	Monster.Type.DIVER: preload("res://content/monster/diver/Diver.tscn"), 
	Monster.Type.TICK: preload("res://content/monster/tick/Tick.tscn"), 
	Monster.Type.BIGTICK: preload("res://content/monster/bigtick/Bigticker.tscn"), 
	Monster.Type.SCARAB: preload("res://content/monster/scarab/Scarab.tscn"), 
	Monster.Type.STAG: preload("res://content/monster/stag/Stag.tscn"), 
	Monster.Type.BREEDER: preload("res://content/monster/breeder/Breeder.tscn"), 
	Monster.Type.PHASER: preload("res://content/monster/phaser/Phaser.tscn"), 
	Monster.Type.BURROWER: preload("res://content/monster/burrower/Burrower.tscn"), 
	Monster.Type.HORNET: preload("res://content/monster/hornet/Hornet.tscn"), 
	Monster.Type.BLOATER: preload("res://content/monster/bloater/Bloater.tscn"), 
	Monster.Type.SCARABARM: preload("res://content/monster/scarab/ScarabArm.tscn"), 
	Monster.Type.WORM_ROCK: preload("res://content/monster/worm/Rock.tscn")
}

var monsters: = {}

func _ready():
	super._ready()
	spawned.connect(_on_monster_spawned)

func _on_monster_spawned(monster: Monster) -> void :
	monsters[monster.UID] = monster
	if multiplayer.is_server():
		monster.networkPhaseChanged.connect(_on_monster_phase_changed.bind(monster))
	monster.died.connect(_on_monster_died.bind(monster))

func _on_monster_died(monster: Monster) -> void :
	monsters.erase(monster.UID)
	network_rpc(_remote_kill_monster.bind(monster.UID), false)

func _on_monster_phase_changed(phase: int, buffer: PackedByteArray, monster: Monster) -> void :
	network_rpc(_remote_set_phase.bind(monster.UID, phase, buffer), false)


@rpc("reliable")
func _remote_set_phase(UID: int, phase: int, buffer: PackedByteArray) -> void :
	if not monsters.has(UID):
		return

	if not is_instance_valid(monsters[UID]):
		return

	var monster: Monster = monsters[UID]
	monster.remote_set_phase(phase, buffer)

func get_delta_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	for monster: Monster in monsters.values():
		stream.encode_u32(monster.UID)
		stream.encode_float(monster.stunIntensity)
		stream.encode_float(monster.currentHealth)

	return stream.data

func set_delta_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	while stream.is_not_finished():
		var uid: = stream.decode_u32()
		var stunIntensity: = stream.decode_float()
		var health: = stream.decode_float()
		if monsters.has(uid):
			if is_monster_valid_or_erase(monsters[uid]):
				monsters[uid].stunIntensity = stunIntensity
				monsters[uid].currentStunLevel = monsters[uid].stunLevel()


				if health < monsters[uid].currentHealth:
					monsters[uid].currentHealth = health
					monsters[uid].handleDamage()

@rpc("reliable", "any_peer")
func _remote_kill_monster(UID: int) -> void :
	if monsters.has(UID):
		var monster: Monster = monsters[UID]
		if is_monster_valid_or_erase(monster):
			monster.died.disconnect(_on_monster_died.bind(monster))
			monster.die()
			monster.animateDeath()
			monsters.erase(UID)

func is_monster_valid_or_erase(monster: Monster) -> bool:
	if is_instance_valid(monster):
		return true
	else:
		monsters.erase(monster)
		return false




func network_spawn(type: Monster.Type, buffer: PackedByteArray, teamId: String, from_spawn_plan: = false):

	var spawn_bytes: = PackedByteStream.new()
	spawn_bytes.encode_u8(type)
	spawn_bytes.encode_u32(randi())
	spawn_bytes.encode_var(teamId)
	spawn_bytes.append_array(buffer)

	spawn_from_bytes(spawn_bytes.data, from_spawn_plan)
	network_rpc(spawn_from_bytes.bind(spawn_bytes.data), false)

@rpc("reliable")
func spawn_from_bytes(buffer: PackedByteArray, from_spawn_plan: = false):
	var stream: = PackedByteStream.from_bytes(buffer)
	var type: = stream.decode_u8()
	var monster: Monster = monster_scenes[type].instantiate()
	monster.UID = stream.decode_u32()
	monster.teamId = stream.decode_var()
	monster.type = type as Monster.Type
	monster.inOriginalSpawnPlan = from_spawn_plan
	if Level.worldsByTeamId.has(monster.teamId):
		monster.world = Level.worldsByTeamId.get(monster.teamId)
	else:
		Logger.error("tried to spawn a monster but Level.worldsByTeamId does not contain a world for team '%s'" % monster.teamId, "MonsterSynchronizer.spawn_from_bytes")
		monster.free()
		return
	monster.set_spawn_data(stream.remaining())
	spawned.emit(monster)

func get_initial_data(peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	for monster: Monster in monsters.values():
		stream.encode_bool(monster.supports_full_sync)
		if not monster.supports_full_sync:
			continue

		stream.encode_u32(monster.UID)
		stream.encode_var(monster.teamId)
		stream.encode_u8(monster.type)
		stream.encode_float(monster.stunIntensity)
		var sync_bytes: PackedByteArray = monster.get_full_sync_data()
		stream.encode_u32(sync_bytes.size())
		stream.append_array(sync_bytes)
	return stream.data

func set_initial_data(buffer: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(buffer)
	while stream.is_not_finished():
		var supports_full_sync: = stream.decode_bool()
		if not supports_full_sync:
			continue

		var UID: = stream.decode_u32()
		var teamId = stream.decode_var()
		var type = stream.decode_u8()
		var monster: Monster = monster_scenes[type].instantiate()
		monster.UID = UID
		monster.teamId = teamId
		monster.type = type as Monster.Type
		monster.stunIntensity = stream.decode_float()
		var size: int = stream.decode_u32()
		monster.set_full_sync_data(stream.slice(size).data)
		spawned.emit(monster)
