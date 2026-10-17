extends "res://content/gadgets/PrimaryGadget.gd"

@export var synchronizer: DroneYardSynchronizer

enum BATTLE_ABILITIES{NOTHING, BATTLEGRID, PARASITES}

var droneCurve: Curve2D
var targetsByDrones: = {}
var dronesByTarget: = {}
var cooldown: = 0.0
var spawningGridDrones: = false

var battle_ability

func _ready():
	$GridDroneNestBack.visible = false
	$GridDroneNestFront.visible = false
	$ParasiteDroneNestBack.visible = false
	$ParasiteDroneNestFront.visible = false

	Data.listen(self, teamId + ".droneyard.dronespeed", true)
	Data.listen(self, teamId + ".droneyard.overcharged", true)
	Data.listen(self, teamId + ".droneyard.battleability", true)
	Data.listen(self, teamId + ".monsters.wavepresent")
	Data.listen(self, teamId + ".droneyard.battleabilityuses")

	if multiplayer.is_server() and not SaveGame.currentLoadingSavegame:
		Data.apply(teamId + ".droneyard.overcharged", false)
		Data.apply(teamId + ".droneyard.remainingbattleabilityuses", 0)

	$DroneDispatcher.init(teamId)

	match domeId:
		"dome1":
			$Sprite.frame_coords.y = 0
			$Sprite.position.x = -4
			$Sprite.position.y = -19
		"dome2":
			$Sprite.frame_coords.y = 1
		"dome3":
			$Sprite.frame_coords.y = 2
		"dome4":
			$Sprite.frame_coords.y = 3

	match $Sprite.frame:
		0: $OverchargeSprite.position = Vector2(-4, -16)
		1: $OverchargeSprite.position = Vector2(-3, -19)
		2: $OverchargeSprite.position = Vector2(-2, -30)
		3: $OverchargeSprite.position = Vector2(-2, -23)
		4: $OverchargeSprite.position = Vector2(-4, -26)
		5: $OverchargeSprite.position = Vector2(-2, -35)
		6: $OverchargeSprite.position = Vector2(-4, -17)
		7: $OverchargeSprite.position = Vector2(-6, -20)
		8: $OverchargeSprite.position = Vector2(-5, -27)
		9: $OverchargeSprite.position = Vector2(-2, -22)
		10: $OverchargeSprite.position = Vector2(-3, -29)
		11: $OverchargeSprite.position = Vector2(0, -39)

	Style.init(self)

	Level.addTutorial(self, "overcharge", teamId)


	if SaveGame.currentLoadingSavegame:
		await GameWorld.savegame_loaded

	Data.listen(self, teamId + ".droneyard.transportdronecount", true)

func get_initial_data(peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	for drone in $DroneDispatcher.drones.values():
		stream.encode_u32(drone.UID)
		stream.encode_vector2(drone.position)
		stream.encode_u8(drone.state)
		stream.encode_float(drone.cooldown)
		stream.encode_var(drone.carriedResource)
		stream.encode_var(drone.dispatcherId)
		stream.encode_u8(drone.packedDropContent.size())
		for content: Array in drone.packedDropContent:
			stream.encode_var(content[0])
			stream.encode_float(content[1])
			stream.encode_float(content[2])

		var hasTargettedDrop: = is_instance_valid(drone.targettedDrop)
		stream.encode_bool(hasTargettedDrop)
		if hasTargettedDrop:
			stream.encode_u32(drone.targettedDrop.UID)
		stream.encode_vector2(drone.targetSpot)
		stream.encode_vector2(drone.linear_velocity)

	return stream.data

func set_initial_data(data: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(data)
	while stream.is_not_finished():
		var uid: = stream.decode_u32()
		spawnTransportDrone(uid)
		var drone: TransportDrone = $DroneDispatcher.drones[uid]
		drone.position = stream.decode_vector2()
		drone.state = stream.decode_u8()
		drone.cooldown = stream.decode_float()
		drone.carriedResource = stream.decode_var()
		drone.dispatcherId = stream.decode_var()
		var packedDropSize: = stream.decode_u8()
		for i in range(packedDropSize):
			var content: = []
			content.append(stream.decode_var())
			content.append(stream.decode_float())
			content.append(stream.decode_float())
			drone.packedDropContent.append(content)
		drone.setCarriedResource(drone.carriedResource)
		var hasTargettedDrop: = stream.decode_bool()
		if hasTargettedDrop:
			drone.targettedDrop = Level.drops.get_drop(stream.decode_u32())
		drone.targetSpot = stream.decode_vector2()
		drone.linear_velocity = stream.decode_vector2()

		match drone.state:
			TransportDrone.State.PICKUP:
				$DroneDispatcher.targetDrop(drone.UID, drone.targettedDrop.UID, drone.position)
			TransportDrone.State.RETRIEVE:
				$DroneDispatcher.assignDronePathHome(drone)


func spawnTransportDrone(uid: int) -> void :
	$DroneDispatcher.spawnDrone(uid)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".droneyard.dronespeed":
		$DroneDispatcher.setBaseSpeed(newValue)
	elif property == teamId + ".droneyard.transportdronecount":
		$DroneDispatcher.setAmount(newValue)
		if newValue >= 3:
			$Sprite.frame_coords.x = 2
		elif newValue >= 2:
			$Sprite.frame_coords.x = 1
		else:
			$Sprite.frame_coords.x = 0
	elif property == teamId + ".monsters.wavepresent":
		if newValue:
			var ability = Data.of(teamId + ".droneyard.battleability") as BATTLE_ABILITIES
			match ability:
				BATTLE_ABILITIES.BATTLEGRID:
					spawningGridDrones = true
					var totalCount = getSpawnCount()
					if multiplayer.is_server():
						Data.apply(teamId + ".droneyard.remainingbattledronecount", totalCount)
						Data.apply(teamId + ".droneyard.battledronecountthiswave", totalCount)
				BATTLE_ABILITIES.PARASITES:
					if multiplayer.is_server():
						var uses = Data.of(teamId + ".droneyard.battleabilityuses")
						Data.apply(teamId + ".droneyard.remainingbattleabilityuses", uses)

		else:
			var ability = Data.of(teamId + ".droneyard.battleability") as BATTLE_ABILITIES
			match ability:
				BATTLE_ABILITIES.BATTLEGRID:
					$GridDroneNestBack.speed_scale = 1.0
					$GridDroneNestFront.speed_scale = 1.0
					spawningGridDrones = false
				BATTLE_ABILITIES.PARASITES:
					if multiplayer.is_server():
						Data.apply(teamId + ".droneyard.remainingbattleabilityuses", 0)
			cooldown = 0
			removeDrones()
			if not SaveGame.currentLoadingSavegame:
				if multiplayer.is_server():
					Data.apply(teamId + ".droneyard.overcharged", false)
		targetsByDrones.clear()
		dronesByTarget.clear()
	elif property == teamId + ".droneyard.battleability":
		battle_ability = newValue as BATTLE_ABILITIES
		match battle_ability:
			BATTLE_ABILITIES.PARASITES:
				add_to_group(teamId + "-dome_ability1")
				droneCurve = $ParasiteDronePath.curve
				$ParasiteDroneNestBack.visible = true
				$ParasiteDroneNestFront.visible = true
			BATTLE_ABILITIES.BATTLEGRID:
				droneCurve = $BattleDronePath.curve
				$GridDroneNestBack.visible = true
				$GridDroneNestBack.play("idle")
				$GridDroneNestFront.visible = false
				if ( not oldValue or oldValue == 0) and Data.of(teamId + ".monsters.wavepresent"):
					spawningGridDrones = true
					if multiplayer.is_server():
						Data.apply(teamId + ".droneyard.remainingbattledronecount", getSpawnCount())
	elif property == teamId + ".droneyard.battleabilityuses":
		if oldValue != null and multiplayer.is_server():
			var delta = newValue - oldValue
			if delta > 0 and Data.of(teamId + ".monsters.wavepresent"):
				Data.changeByInt(teamId + ".droneyard.remainingbattleabilityuses", delta)
	elif property == teamId + ".droneyard.overcharged":
		if newValue:
			$OverchargeSprite.play("active")
			match battle_ability:
				BATTLE_ABILITIES.BATTLEGRID:
					if multiplayer.is_server():
						var newSpawnCount = getSpawnCount(false)
						var originallyPlannedDrones = Data.ofOr(teamId + ".droneyard.battledronecountthiswave", 0)
						var diff = newSpawnCount - originallyPlannedDrones
						Data.changeByInt(teamId + ".droneyard.remainingbattledronecount", diff)
						Data.changeByInt(teamId + ".droneyard.battledronecountthiswave", diff)
		else:
			$OverchargeSprite.play("inactive")

func _process(delta):
	if GameWorld.paused:
		return

	match battle_ability:
		BATTLE_ABILITIES.BATTLEGRID:
			if spawningGridDrones:
				if cooldown > 0.0:
					cooldown -= delta
					return

				if $GridDroneNestBack.animation == "idle":
					$GridDroneNestFront.visible = true
					$GridDroneNestFront.play("spawn_front")
					$GridDroneNestBack.play("spawn_back")
					cooldown = Data.of(teamId + ".droneyard.battledronespawntime")


					if cooldown < 2.0:
						$GridDroneNestBack.speed_scale = 2.0
						$GridDroneNestFront.speed_scale = 2.0

		BATTLE_ABILITIES.PARASITES:
			if cooldown > 0.0:
				cooldown -= delta
				return

			for drone in get_tree().get_nodes_in_group(teamId + "-battle_drones"):
				if drone.canTakeTarget() and not targetsByDrones.has(drone):
					var monsters = get_tree().get_nodes_in_group(teamId + "-monster")
					var bestMonster = null
					for m in monsters:
						if not dronesByTarget.has(m) and m.alive() and m.canBeHit():
							if not bestMonster or (5 * bestMonster.currentHealth + bestMonster.maxHealth) < (5 * m.currentHealth + m.maxHealth):
								bestMonster = m

					if bestMonster:
						drone.assignTarget(bestMonster)
						targetsByDrones[drone] = bestMonster
						dronesByTarget[bestMonster] = drone
						bestMonster.connect("died", monsterDied.bind(bestMonster))

					cooldown = randf_range(0.4, 0.8)
					return

func monsterDied(m):
	var drone = dronesByTarget[m]
	drone.targetDied()
	targetsByDrones.erase(drone)
	dronesByTarget.erase(m)

func spawnGridDrone():
	$ReleaseDroneSound.startSound()
	var drone = preload("res://content/gadgets/droneyard/BattleDrone.tscn").instantiate()
	drone.teamId = teamId
	drone.position = $BattleDroneSpawnPoint.global_position
	if Data.of(teamId + ".droneyard.overcharged"):
		var droneBuff = Data.of(teamId + ".droneyard.overchargebattledronestrength")
		drone.setBuff(droneBuff)
	Level.viewports.addElement(drone)
	updateGridDronePositions()

	var remaining = Data.ofOr(teamId + ".droneyard.remainingbattledronecount", 0)
	if remaining <= 1:
		spawningGridDrones = false
	Data.apply(teamId + ".droneyard.remainingbattledronecount", remaining - 1)

func getSpawnCount(subtractExistingDrones: = true) -> int:
	var overcharged = Data.of(teamId + ".droneyard.overcharged")
	var count = Data.of(teamId + ".droneyard.battledronecount")
	if overcharged:
		count += ceil(count * Data.of(teamId + ".droneyard.overchargebattledronecount"))
	if subtractExistingDrones:
		count -= get_tree().get_nodes_in_group(teamId + "-battle_drones").size()
	return count

func spawnParasiteDrones():
	$ReleaseParasiteDroneSound.startSound()
	var droneBuff: float
	if Data.of(teamId + ".droneyard.overcharged"):
		droneBuff = Data.of(teamId + ".droneyard.overchargebattledronestrength")
	for i in getSpawnCount(false):
		var drone = preload("res://content/gadgets/droneyard/ParasiteDrone.tscn").instantiate()
		drone.teamId = teamId
		drone.position = $BattleDroneSpawnPoint.global_position
		drone.buff = droneBuff
		drone.setCurve($ParasiteDronePath.curve)
		Level.viewports.addElement(drone)

func removeDrones():
	var drones = get_tree().get_nodes_in_group(teamId + "-battle_drones")
	if drones.size() > 0:
		var t = create_tween()
		t.set_parallel(true)
		for drone in drones:
			t.tween_callback(drone.returToOrigin).set_delay(randf_range(0, 1.0))

func canOvercharge() -> bool:
	return not Data.of(teamId + ".droneyard.overcharged") and Data.of(teamId + ".droneyard.overchargebattledronecount") > 0.0

func overcharge():
	$OverchargeSound.startSound()
	if multiplayer.is_server():
		Data.apply(teamId + ".droneyard.overcharged", true)
		Data.changeByInt(teamId + ".inventory.water", -1)
		Backend.event("gadget_overcharged", {"gadget": "droneyard"})

func canFocusUse(keeper: Keeper) -> bool:
	return canOvercharge()

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not canFocusUse:
		return false

	synchronizer.network_rpc(registerHit, true)
	return true

@rpc("reliable", "any_peer")
func registerHit() -> void :
	tryOvercharge()

func updateGridDronePositions():
	var drones = get_tree().get_nodes_in_group(teamId + "-battle_drones")
	if drones.is_empty() or not droneCurve:
		return

	var curveLength: float = droneCurve.get_baked_length()
	var step: float = minf(curveLength * 0.2, curveLength / float(drones.size()))
	var i: = 0

	var dome: Dome = Level.domesByTeamId[teamId]
	for drone in drones:
		var mod = ceil(i / 2.0) * step
		if i % 2 == 0:
			mod = - mod
		var pos = droneCurve.sample_baked(curveLength * 0.5 + mod)
		pos.x += dome.global_position.x
		drone.setGoalPosition(pos)
		i += 1

func executeBattle1() -> bool:
	var remainingUses = Data.of(teamId + ".droneyard.remainingbattleabilityuses")
	if remainingUses <= 0:
		Audio.sound("gui_err")
		return false

	Data.apply(teamId + ".droneyard.remainingbattleabilityuses", remainingUses - 1)

	spawnParasiteDrones()

	Backend.event("battle_ability_used", {"gadget": "droneyard", "ability": BATTLE_ABILITIES.keys()[BATTLE_ABILITIES.PARASITES]})
	return true

@rpc("reliable")
func remoteExecuteBattle1() -> void :
	pass

func getBattleAbilityName() -> String:
	var ability = Data.of(teamId + ".droneyard.battleability") as BATTLE_ABILITIES
	match ability:
		BATTLE_ABILITIES.BATTLEGRID:
			return tr("upgrades.droneyardbattlegrid.title")
		BATTLE_ABILITIES.PARASITES:
			return tr("upgrades.droneyardparasites.title")
	return ""

func remove():
	queue_free()
	for drone in get_tree().get_nodes_in_group(teamId + "-transport_drones"):
		drone.queue_free()


func _on_grid_drone_nest_back_animation_finished() -> void :
	$GridDroneNestBack.play("idle")
	$GridDroneNestFront.visible = false

func _on_grid_drone_nest_front_frame_changed() -> void :
	if spawningGridDrones and $GridDroneNestFront.frame == 7:
		spawnGridDrone()
