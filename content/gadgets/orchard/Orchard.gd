extends "res://content/gadgets/PrimaryGadget.gd"

@export var synchronizer: Synchronizer

enum Mode{NOTHING, ROOTS, SHIELD}
var mode: int = Mode.NOTHING

var battleAbilityActive: = false

var plantReady: = false
var producing: = false
var grownAfter: float
var addedBuffs: = {}

const FRUIT_OFFSETS: = {
	"dome1": Vector2(10, 8), 
	"dome2": Vector2(4, -5), 
	"dome3": Vector2(-5, 17), 
	"dome4": Vector2(-4, 14), 
}


var roots: = {}

var shields: = {}

@onready var _pickUpSound: Sound = $PickUpSound

func _ready():
	GameWorld.savegame_loaded.connect(_connect_active_roots)
	GameWorld.savegame_loaded.connect(_connect_active_shields)
	$Sprite2D / Fruit.visible = false
	$Sprite2D.play("growing_" + domeId)
	if multiplayer.is_server():
		Data.apply(teamId + ".orchard.currentgrowth", 0)

	Data.listen(self, teamId + ".monsters.wavepresent")
	Data.listen(self, teamId + ".orchard.battleshields", true)
	Data.listen(self, teamId + ".orchard.battleroots", true)
	Data.listen(self, teamId + ".orchard.overcharged")
	Data.listen(self, teamId + ".orchard.battleabilityuses")
	if multiplayer.is_server() and not SaveGame.currentLoadingSavegame:
		Data.apply(teamId + ".orchard.overcharged", false)
		Data.apply(teamId + ".orchard.remainingbattleuses", 0)

	if multiplayer.is_server():
		for keeper in Keepers.getAllOfTeam(teamId):
			Data.apply(keeper.playerId + ".orchard.remainingbuffduration", 0)

	match domeId:
		"dome1":
			pass
		"dome2":
			pass
		"dome3":
			pass
		"dome4":
			position += Vector2(-2, -5)

	Style.init(self)

	Level.addTutorial(self, "orchard", teamId)
	Level.addTutorial(self, "overcharge", teamId)

	Achievements.addIfOpen(self, "ORCHARD_LONG", teamId)

func serialize() -> Dictionary:
	var data = {
		"mode": mode, 
		"battleAbilityActive": battleAbilityActive, 
		"plantReady": plantReady, 
		"producing": producing, 
		"grownAfter": grownAfter, 
		"addedBuffs": addedBuffs, 
		"rootUids": roots.keys()
	}
	data["meta.priority"] = 200
	data["meta.kind"] = "station"
	return data

func deserialize(data: Dictionary):
	mode = data["mode"]
	battleAbilityActive = data["battleAbilityActive"]
	plantReady = data["plantReady"]
	producing = data["producing"]
	grownAfter = data["grownAfter"]
	addedBuffs = data["addedBuffs"]


	for uid: int in data.get("rootUids", {}):
		roots[uid] = null

	if producing:
		$Sprite2D.play("growing_" + domeId)
		$Center / OrchardActive.startSound()

	if plantReady:
		createFruit()

	for keeperInstance in Keepers.getAllOfTeam(teamId):
		var speedBuffKey = keeperInstance.playerId + ".keeper.speedbuff"
		if addedBuffs.has(speedBuffKey) and not keeperInstance.is_connected("mined", onKeeperMined):
			keeperInstance.connect("mined", onKeeperMined.bind(keeperInstance))

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".monsters.wavepresent":
		if not multiplayer.is_server():
			return
		if newValue:
			var uses = Data.of(teamId + ".orchard.battleabilityuses")
			if Data.of(teamId + ".orchard.overcharged"):
				uses += Data.of(teamId + ".orchard.overchargeabilityuses")
			Data.apply(teamId + ".orchard.remainingbattleuses", uses)
		elif not SaveGame.currentLoadingSavegame:
			Data.apply(teamId + ".orchard.remainingbattleuses", 0)
			Data.apply(teamId + ".orchard.overcharged", false)
	elif property == teamId + ".orchard.battleshields":
		if mode == Mode.NOTHING and newValue > 0:
			mode = Mode.SHIELD
			add_to_group(teamId + "-dome_ability1")
			$RootingSound.queue_free()
	elif property == teamId + ".orchard.battleroots":
		if mode == Mode.NOTHING and newValue > 0:
			mode = Mode.ROOTS
			add_to_group(teamId + "-dome_ability1")
			$ShieldSound.queue_free()
	elif property == teamId + ".orchard.overcharged":
		if plantReady:
			$Sprite2D.play("fruit_" + domeId)
		elif newValue:
			$Sprite2D.play("overcharged_" + domeId)
		else:
			$Sprite2D.play("growing_" + domeId)
	elif property == teamId + ".orchard.battleabilityuses":
		if not multiplayer.is_server():
			return
		if oldValue != null:
			var delta = newValue - oldValue
			if delta > 0 and Data.of(teamId + ".monsters.wavepresent"):
				Data.changeByInt(teamId + ".orchard.remainingbattleuses", delta)

func _process(delta):
	var softPaused: bool = GameWorld.softPaused(teamId)
	if softPaused:
		if Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SINGLEPLAYER:
			return
	if multiplayer.is_server():
		var keepers = Keepers.getAllOfTeam(teamId)
		for keeper in keepers:
			var key = keeper.playerId + ".orchard.remainingbuffduration"
			var remainingBuffDuration = Data.ofOr(key, 0)
			if remainingBuffDuration > 0.0:
				var moveLength = keeper.moveDirectionInput.length()
				if moveLength > 0.0:

					var buffConsumptionRate: float = GameWorld.cycleSpeed * 0.7 if softPaused else GameWorld.cycleSpeed
					remainingBuffDuration -= delta * moveLength * buffConsumptionRate
				if multiplayer.is_server():
					Data.apply(key, remainingBuffDuration)
				if remainingBuffDuration <= 0:
					removeBuff(keeper.playerId)

	if softPaused:
		return
	if plantReady:
		return

	if producing and GameWorld.runStarted:
		var d: float = delta * GameWorld.cycleSpeed * float(Keepers.getAllOfTeam(teamId).size())
		var plantGrowth = Data.of(teamId + ".orchard.currentgrowth") + d / grownAfter

		if multiplayer.is_server():
			Data.apply(teamId + ".orchard.currentgrowth", plantGrowth)
			if plantGrowth >= 1.0:
				synchronizer.network_rpc(createFruit, true)
	elif multiplayer.is_server() and not producing:
		synchronizer.network_rpc(startProducing, true)

@rpc("reliable")
func startProducing() -> void :
	producing = true
	grownAfter = GameWorld.getTimeBetweenWaves(teamId) * float(Data.of(teamId + ".orchard.growthTime"))
	if Data.of(teamId + ".orchard.overcharged"):
		$Sprite2D.play("overcharged_" + domeId)
	else:
		$Sprite2D.play("growing_" + domeId)
	$Center / OrchardActive.startSound()

func removeBuff(playerId):
	if not multiplayer.is_server():
		return

	var key = playerId + ".keeper.speedbuff"
	Data.changeByInt(key, - addedBuffs[key])
	key = playerId + ".keeper.drillbuff"
	Data.changeByInt(key, - addedBuffs[key])

func canFocusUse(keeper: Keeper) -> bool:
	if plantReady:
		return true
	if canOvercharge():
		return true
	return false

func useHold(keeper: Keeper) -> bool:
	if canOvercharge():
		return tryOvercharge()
	else:
		return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not canFocusUse:
		return false

	synchronizer.rpc_server(registerHit.bind(keeper.playerId))
	return true

@rpc("reliable", "any_peer")
func registerHit(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	if plantReady:
		var durationCycles: float = Data.of(teamId + ".orchard.buffduration")
		Data.changeByInt(teamId + ".orchard.buffedcycles", durationCycles)
		var duration = GameWorld.getTimeBetweenWaves(teamId) * durationCycles
		if Data.ofOr(keeper.playerId + ".orchard.remainingbuffduration", 0.0) > 0.0:
			removeBuff(keeper.playerId)

		var addedSpeedBuff = Data.of(teamId + ".orchard.speedbuff")
		var key = keeper.playerId + ".keeper.speedbuff"
		Data.changeByInt(key, addedSpeedBuff)
		addedBuffs[key] = addedSpeedBuff

		var addedDrillBuff = Data.of(teamId + ".orchard.drillbuff")
		key = keeper.playerId + ".keeper.drillbuff"
		Data.changeByInt(keeper.playerId + ".keeper.drillbuff", addedDrillBuff)
		addedBuffs[key] = addedDrillBuff

		Data.apply(keeper.playerId + ".orchard.remainingbuffduration", duration)
		Data.apply(teamId + ".orchard.currentgrowth", 0.0)

		Backend.event("gadget_used", {"gadget": "orchard"})

		for keeperInstance in Keepers.getAllOfTeam(teamId):
			if keeperInstance and not keeperInstance.is_connected("mined", onKeeperMined):
				keeperInstance.connect("mined", onKeeperMined.bind(keeperInstance))

		synchronizer.network_rpc(playHitVisuals, true)
	else:
		tryOvercharge()

@rpc("reliable")
func playHitVisuals() -> void :
	_pickUpSound.startSound()
	if Data.of(teamId + ".orchard.overcharged"):
		$Sprite2D.play("overcharged_" + domeId)
	else:
		$Sprite2D.play("growing_" + domeId)

	plantReady = false
	$Sprite2D / Fruit.visible = false
	$Sprite2D / Fruit.pause()
	$Timer.stop()

func onKeeperMined(amount: float, keeper: Keeper):
	var key = keeper.playerId + ".orchard.remainingbuffduration"
	var remainingBuffDuration = Data.of(key)
	if remainingBuffDuration > 0.0:
		remainingBuffDuration -= amount
		Data.apply(key, remainingBuffDuration)
		if remainingBuffDuration <= 0:
			removeBuff(keeper.playerId)

func overcharge():
	Data.apply(teamId + ".orchard.overcharged", true)
	if Data.of(teamId + ".monsters.wavepresent"):
		Data.changeByInt(teamId + ".orchard.remainingbattleuses", Data.of(teamId + ".orchard.overchargeabilityuses"))
	Data.changeByInt(teamId + ".inventory.water", -1)
	Backend.event("gadget_overcharged", {"gadget": "orchard"})

	synchronizer.network_rpc(playOverchargeSound, true)

@rpc("reliable")
func playOverchargeSound() -> void :
	$OverchargeSound.startSound()

func canOvercharge() -> bool:
	return Data.of(teamId + ".orchard.overchargeabilitystrength") > 0.0 and not Data.of(teamId + ".orchard.overcharged")

@rpc("reliable")
func createFruit():
	plantReady = true
	producing = false
	$Usable.updateFocus()
	$Sprite2D.play("fruit_" + domeId)
	$Sprite2D / Fruit.visible = false
	$Sprite2D / Fruit.play("shine_" + domeId)
	$Sprite2D / Fruit.position = FRUIT_OFFSETS.get(domeId, Vector2.ZERO)
	$Sprite2D / Fruit.show()
	_on_Timer_timeout()
	$FruitSpawnSound.startSound()
	$TreeTimer.start()
	$Center / OrchardActive.stop()

func _on_Timer_timeout():
	if not GameWorld.softPaused(teamId):
		$Sprite2D / Fruit.play("shine_" + domeId)
		$Sprite2D / Fruit.frame = 0
	$Timer.wait_time = 2.0 + randf() * 2.0
	$Timer.start()

func _on_TreeTimer_timeout():
	if not $Sprite2D.animation.begins_with("fruit"):
		return

	if not GameWorld.softPaused(teamId):
		$Sprite2D.frame = 0
	$TreeTimer.wait_time = 4.0 + randf() * 2.0
	$TreeTimer.start()

func deactivate():
	battleAbilityActive = false
	match mode:
		Mode.ROOTS:
			pass
		Mode.SHIELD:
			$ShieldEndSound.startSound()

func getBattleAbilityName() -> String:
	match mode:
		Mode.ROOTS:
			return tr("upgrades.orchardbattlerooting.title")
		Mode.SHIELD:
			return tr("upgrades.orchardbattleshield.title")
	return ""

func executeBattle1() -> bool:
	if not multiplayer.is_server():
		return false

	var additionalStrength: float = Data.of(teamId + ".orchard.overchargeabilitystrength")

	if mode == Mode.NOTHING:
		return false
	elif mode == Mode.ROOTS and Data.of(teamId + ".orchard.battlerootexplosion") > 0:
		var r = roots.values().duplicate()
		r.shuffle()
		var exploded: = false
		var i: = 0
		for root in r:
			if root.hasCatch():
				synchronizer.network_rpc(explodeRoot.bind(root.UID, i, additionalStrength), true)
				exploded = true
				i += 1
		if exploded:
			return true

	var remainingUses = Data.of(teamId + ".orchard.remainingbattleuses")
	if remainingUses <= 0:
		Audio.sound("gui_err")
		return false

	Data.apply(teamId + ".orchard.remainingbattleuses", remainingUses - 1)

	battleAbilityActive = true

	match mode:
		Mode.ROOTS:
			$RootingSound.startSound()
			synchronizer.network_rpc(spawnRoots.bind(randi()), true)
		Mode.SHIELD:
			$ShieldSound.startSound()
			synchronizer.network_rpc(spawnShields.bind(randi()), true)

	Backend.event("battle_ability_used", {"gadget": "orchard", "ability": Mode.keys()[mode]})
	return true

@rpc("reliable")
func remoteExecuteBattle1() -> void :
	var remainingUses = Data.of(teamId + ".orchard.remainingbattleuses")
	if remainingUses <= 0:
		return

	match mode:
		Mode.ROOTS:
			$RootingSound.startSound()
		Mode.SHIELD:
			$ShieldSound.startSound()

@rpc("reliable")
func spawnRoots(s: int):
	var additionalStrength: float = Data.of(teamId + ".orchard.overchargeabilitystrength")

	var random: = RandomNumberGenerator.new()
	random.seed = s

	var delay = 0.01
	var paths: Array = Level.worldsByTeamId[teamId].getDefensivePaths("walk_medium", "left")
	paths.append_array(Level.worldsByTeamId[teamId].getDefensivePaths("walk_medium", "right"))
	Utils.shuffle(paths, random)

	var amount = Data.of(teamId + ".orchard.battleroots")
	amount += round(amount * additionalStrength)
	for i in range(0, amount):
		var path = paths[i % paths.size()]
		var pos = Utils.get_global_from_local_dome_position(path.curve.sample_baked(path.curve.get_baked_length() * (0.5 + random.randf() * 0.3)) + path.position, teamId)
		$Tween.interpolate_callback(self, delay, "spawnRoot", random.randi(), pos)
		delay += 0.2 + random.randf() * 0.15
	$Tween.start()

func spawnRoot(uid: int, pos: Vector2) -> void :
	var root: = preload("res://content/gadgets/orchard/OrchardRoot.tscn").instantiate()
	root.UID = uid
	roots[uid] = root
	pos.y += 2
	root.position = pos
	root.teamId = teamId
	if multiplayer.is_server():
		root.caughtMonster.connect(onMonsterCaught.bind(root.UID))
	root.tree_exiting.connect(onRootFreed.bind(root.UID))
	Level.viewports.addMonster(root)

func onMonsterCaught(monster: Monster, rootUID: int) -> void :
	synchronizer.network_rpc(catchMonster.bind(monster.UID, rootUID), true)

func onRootFreed(rootUID: int) -> void :
	roots.erase(rootUID)

@rpc("reliable")
func catchMonster(monsterUID: int, rootUID: int) -> void :
	if not Level.monstersByTeamId[teamId].hasMonster(monsterUID) or not roots.has(rootUID):
		return

	var root = roots[rootUID]
	root.catchMonster(Level.monstersByTeamId[teamId].getMonster(monsterUID))

func pauseChanged():
	if GameWorld.paused:
		$Tween.stop_all()
	else:
		$Tween.resume_all()

func remove():
	queue_free()

@rpc("reliable")
func explodeRoot(uid: int, delay: int, additionalStrength: float) -> void :
	var root = roots[uid]
	root.explode(delay, additionalStrength)
	roots.erase(uid)

@rpc("reliable")
func spawnShields(s: int) -> void :
	var additionalStrength: float = Data.of(teamId + ".orchard.overchargeabilitystrength")

	var random: = RandomNumberGenerator.new()
	random.seed = s

	var delay = 0.01

	for existingShield in get_tree().get_nodes_in_group(teamId + "-orchard-shield"):
		existingShield.dissolve(delay)
		delay += random.randf() * 0.08

	var hp = Data.of(teamId + ".orchard.battleshieldhp")
	hp += round(hp * additionalStrength)

	var dome = Level.domesByTeamId[teamId]
	var cupolaLength = dome.getCupolaLength()
	var shieldSpacingPx: float = 50.0
	var shieldCount = ceil((cupolaLength - shieldSpacingPx) / shieldSpacingPx)
	var step = 0.66 / float(shieldCount - 1)
	var offsets = []
	for i in shieldCount:
		offsets.append(0.17 + step * i)
	Utils.shuffle(offsets, random)
	for offset in offsets:
		var pos = dome.getCupolaPosition(offset, teamId)
		var finalOffset = 5 * Vector2.UP.rotated(pos.z)
		var uid = random.randi()
		var spawn_position: = Vector2.ZERO
		spawn_position.x = (pos.x - dome.position.x) + finalOffset.x
		spawn_position.y = pos.y + finalOffset.y
		var spawn_rotation = pos.z
		delay += 0.1 + random.randf() * 0.15
		spawn_shield(uid, spawn_position, spawn_rotation, 35, hp, delay)

	if Data.of(teamId + ".orchard.battleshields") >= 2:
		step = 0.7 / float(shieldCount)
		offsets.clear()
		for i in shieldCount + 1:
			offsets.append(0.15 + step * i)
		Utils.shuffle(offsets, random)
		for offset in offsets:
			var pos = dome.getCupolaPosition(offset, teamId)
			var finalOffset = 18 * Vector2.UP.rotated(pos.z)
			var uid = random.randi()
			var spawn_position: = Vector2.ZERO
			spawn_position.x = (pos.x - dome.position.x) + finalOffset.x
			spawn_position.y = pos.y + finalOffset.y
			var spawn_rotation = pos.z
			delay += 0.1 + random.randf() * 0.15
			var shield = spawn_shield(uid, spawn_position, spawn_rotation, 48, hp, delay)
			shield.z_index -= 1

func spawn_shield(uid, position, rotation, offset, hp, delay = 0):
	var dome = Level.domesByTeamId[teamId]
	var shield = preload("res://content/gadgets/orchard/OrchardShield.tscn").instantiate()

	shield.teamId = teamId
	shield.position = position
	shield.rotation = rotation
	shield.UID = uid

	if multiplayer.is_server():
		shield.exhausted.connect(onShieldExhausted.bind(shield.UID))

	dome.add_child(shield)
	shield.init(delay, offset, hp)
	shields[shield.UID] = shield
	return shield


func onShieldExhausted(uid: int) -> void :
	synchronizer.network_rpc(dissolveShield.bind(uid), true)


@rpc("reliable")
func dissolveShield(uid: int) -> void :
	if not shields.has(uid):
		return

	shields[uid].playDissolveVisuals()
	shields.erase(uid)

func _connect_active_roots():
	for object in get_tree().get_nodes_in_group("saveable"):
		if not object is OrchardRoot:
			continue

		var uid = object.UID
		roots[uid] = object

	for root in roots.values():
		if multiplayer.is_server():
			root.caughtMonster.connect(onMonsterCaught.bind(root.UID))
		root.tree_exiting.connect(onRootFreed.bind(root.UID))

func _connect_active_shields():
	for object in get_tree().get_nodes_in_group("saveable"):
		if not object is OrchardShield:
			continue

		var uid = object.UID
		shields[uid] = object

	for shield in shields.values():
		if multiplayer.is_server():
			shield.exhausted.connect(onShieldExhausted.bind(shield.UID))

func get_initial_data(peer_id: int):
	var stream: = PackedByteStream.new()


	stream.encode_bool(plantReady)
	stream.encode_bool(producing)
	stream.encode_float(grownAfter)


	stream.encode_u16(roots.values().size())
	for root in roots.values():
		stream.encode_u32(root.UID)
		stream.encode_vector2(root.position)


	stream.encode_u16(shields.values().size())
	for shield in shields.values():
		stream.encode_u32(shield.UID)
		stream.encode_vector2(shield.position)
		stream.encode_float(shield.rotation)
		stream.encode_u8(shield.offsetY)
		stream.encode_u8(shield.remainingHp)
		stream.encode_s8(shield.z_index)

	return stream.data

func set_initial_data(data: PackedByteArray):
	var stream: = PackedByteStream.from_bytes(data)


	plantReady = stream.decode_bool()
	producing = stream.decode_bool()
	grownAfter = stream.decode_float()
	if plantReady:
		createFruit()
	elif producing:
		startProducing()


	var root_count = stream.decode_u16()
	for _i in range(root_count):
		var uid: = stream.decode_u32()
		var position = stream.decode_vector2()
		spawnRoot(uid, position)


	var shield_count = stream.decode_u16()
	for _i in range(shield_count):
		var uid: = stream.decode_u32()
		var position = stream.decode_vector2()
		var rotation = stream.decode_float()
		var offset = stream.decode_u8()
		var hp = stream.decode_u8()
		var z_index = stream.decode_s8()
		var shield = spawn_shield(uid, position, rotation, offset, hp)
		shield.z_index = z_index
