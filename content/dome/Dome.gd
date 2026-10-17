extends Node2D

class_name Dome

@onready var ArtifactDropPoint = get_node("ArtifactDropPoint")
@onready var RelicDropPoint = get_node("RelicDropPoint")
@onready var EggDropPoint = get_node("EggDropPoint")
@onready var PiercePoints = get_node("PiercePoints")
@onready var MeleeTargets = get_node("MeleeTargets")
@onready var ProjectileTargets = get_node("ProjectileTargets")
@onready var cracks_overlay = $CracksOverlay
@onready var _cellarContainers: Array[Node] = [$Cellar / ContainerLeft, $Cellar / ContainerRight]
@onready var _chargeOn: Sound = $ChargeOn
@onready var _chargeOff: Sound = $ChargeOff
@onready var goblins: Goblins = $Goblins

@export var petSynchronizer: PetSynchronizer

var primaryWeapon: String
@export var techId: String
@export var stations: Array[DomeStation]
var teamId: String
var collapsed: = false

var damageOnWave: float
var autohealOnWave: float
var remainingHeals: int
var lastEnvironmentalDamageFrame: int = -1

var autoRepairAmount: float = 0.0

var showcaseMode: = false

func _ready():
	Style.init(self)

	Level.addTutorial(self, "stationdefend", teamId)
	Level.addTutorial(self, "repair1", teamId)
	Level.addTutorial(self, "repair2", teamId)

	Achievements.addIfOpen(self, "RESOURCES_COBALTSTACK", teamId)
	Achievements.addIfOpen(self, "RESOURCES_COBALTRESCUE", teamId)
	Achievements.addIfOpen(self, "DOME_LOWHEALTH", teamId)

	if GameWorld.isLunarNewYear:
		for spot in get_tree().get_nodes_in_group("dome-decoration"):
			if is_ancestor_of(spot):
				var lantern: = Sprite2D.new()
				lantern.texture = preload("res://content/dome/fluffobjects/lunarlamp.png")
				spot.add_child(lantern)
				Style.init(lantern)

	$Shield.add_to_group(teamId + "-dome-shield")
	$Shield.init(teamId)
	$Shredder.teamId = teamId
	$RelicDropPoint.teamId = teamId
	$ArtifactDropPoint.teamId = teamId
	$ElectrifiedSurfaceSupplement.init(teamId)
	$CracksOverlay.init(teamId)
	$Shield / Invulnerable.init(teamId)

	for station in stations:
		station.init(teamId)

func init():
	$CupolaPath.visible = true
	$WeaponContainer.visible = true
	$CracksOverlay.visible = true
	$CollapseSprite.visible = false
	$CollapseParticles.emitting = false
	$Cellar / RelicActivation.play("none")
	$Cellar / SpinningRelic.play("none")

	$Station.teamId = teamId
	%OtherTeamBlocker.set_collision_layer_value(CONST.LAYER_BLOCKER_TEAM_1, teamId == "team2")
	%OtherTeamBlocker.set_collision_layer_value(CONST.LAYER_BLOCKER_TEAM_2, teamId == "team1")

	var domeData = Data.gadgets.get(techId)
	primaryWeapon = domeData.get("primaryweapon", "")
	if primaryWeapon != "":
		GameWorld.addUpgrade(primaryWeapon, teamId)


	$CupolaPath.curve = $CupolaPath.curve.duplicate()
	$CollapseShards.curve = $CollapseShards.curve.duplicate()

	for c in $MeleeTargets.get_children():
		c.curve = c.curve.duplicate()
		for i in range(0, c.curve.get_point_count()):
			c.curve.set_point_position(i, c.curve.get_point_position(i) + global_position)

	petSynchronizer.init()

	%SpyCam.init(teamId)
	%SpyCam.disable()

	goblins.teamId = teamId
	goblins.init()

	Data.listen(self, teamId + ".dome.baserepair")
	Data.listen(self, teamId + ".dome.healthfractionrepair")
	Data.listen(self, teamId + ".dome.reducedhealth")
	Data.listen(self, teamId + ".monsters.wavepresent")
	Data.listen(self, teamId + ".dome.secondarystation", true)
	Data.listen(self, teamId + ".dome.secondaryweapon", true)
	Data.listen(self, teamId + ".dome.mainweapons", true)
	Data.listen(self, teamId + ".versus.spycam", true)

func unlisten():
	Data.unlisten(self, teamId + ".dome.baserepair")
	Data.unlisten(self, teamId + ".dome.healthfractionrepair")
	Data.unlisten(self, teamId + ".monsters.wavepresent")
	Data.unlisten(self, teamId + ".dome.mainweapons")
	Data.unlisten(self, teamId + ".dome.secondarystation")
	Data.unlisten(self, teamId + ".dome.secondaryweapon")
	Data.unlisten(self, teamId + ".dome.reducedhealth")
	Data.unlisten(self, teamId + ".versus.spycam")
	Data.unlisten(self, teamId + ".inventory.iron")
	Data.unlisten(self, teamId + ".inventory.water")
	Data.unlisten(self, teamId + ".inventory.sand")

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".dome.secondaryweapon":
		if newValue:
			Data.apply(teamId + ".dome.mainweapons", Data.ofOr(teamId + ".dome.mainweapons", 0))
		else:
			var secondaryStation = stations[1]
			for weapon in secondaryStation.getControlledWeapons():
				weapon.remove()
			secondaryStation.controlledWeapons = []
	if property == teamId + ".dome.mainweapons":
		if not multiplayer.is_server():
			return
		for i in stations.size():
			var station = stations[i]
			if not station.visible:
				continue
			if i == 1 and not Data.ofOr(teamId + ".dome.secondaryweapon", false):
				continue
			var controlledWeapons = station.getControlledWeapons()
			var diff = newValue - station.getControlledWeapons().size()
			if diff > 0:
				for _i in diff:
					addWeapon(station)
			elif diff < 0:
				for j in abs(diff):
					controlledWeapons[j].remove()
	elif property == teamId + ".dome.secondarystation":
		if newValue:
			addSecondaryStation()
		else:
			removeSecondaryStation()
	elif property == teamId + ".dome.reducedhealth":
		if oldValue != null:
			var change = oldValue - newValue
			if change > 0:
				var maxhealth = Data.of(teamId + ".dome.maxhealth")
				Data.apply(teamId + ".dome.maxhealth", maxhealth + change)
				Data.changeDomeHealth(change, teamId)
				Data.apply(teamId + ".dome.reducedhealth", 0)
	elif property == teamId + ".dome.baserepair":
		if newValue != 0:
			Data.changeDomeHealth(newValue, teamId)
	elif property == teamId + ".dome.healthfractionrepair":
		if newValue != 0:
			Data.changeDomeHealth(newValue * Data.of(teamId + ".dome.maxHealth"), teamId)
	elif property == teamId + ".monsters.wavepresent":
		if newValue:
			GameWorld.incrementRunStat("damage_taken", teamId, damageOnWave)
			damageOnWave = 0.0
			autohealOnWave = 0.0
			remainingHeals = 1
	elif property == teamId + ".versus.spycam":
		if newValue:
			addSpyCam()
		else:
			removeSpyCam()
	elif multiplayer.is_server() and property.contains(teamId + ".inventory") and oldValue < newValue:
		var amount = newValue - oldValue
		var resource: = property.split(".")[-1]
		if Data.has(teamId + ".harmfuldrops." + resource):
			requestEnvironmentalDamage(Data.of(teamId + ".harmfuldrops." + resource) * amount, "HARMFUL_DROP", Vector2.ZERO, true)

func _process(delta):
	if GameWorld.paused:
		return

	if autoRepairAmount > 0.0:
		var repair = clamp(100 * delta, 0, autoRepairAmount)
		autoRepairAmount -= repair
		Data.changeDomeHealth(repair, teamId)

	var invlunerableTime = Data.of(teamId + ".dome.invulnerabletime")
	if invlunerableTime > 0:
		Data.apply(teamId + ".dome.invulnerabletime", invlunerableTime - delta)

func onGameLost():
	if collapsed:
		return

	goblins.notifyGameLost()
	collapsed = true
	$CollapseSprite.frame = 0
	$CollapseSprite.visible = true
	$CollapseShards.collapse()
	$Tween.interpolate_property($CollapseSprite, "frame", 0, 11, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.0)
	$Tween.interpolate_property($CollapseParticles, "emitting", false, true, 0.0, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.0)
	$Tween.start()
	$Background.visible = false
	$Foreground.visible = false
	$Shield.visible = false
	$WartContainer.visible = false
	$Station.visible = false
	$PrimaryGadgetContainer.visible = false
	$Shredder.visible = false
	$CupolaPath.visible = false
	$WeaponContainer.visible = false
	$CracksOverlay.hide()

	for spot in get_tree().get_nodes_in_group("dome-decoration"):
		if is_ancestor_of(spot):
			spot.visible = false

	for pet in get_tree().get_nodes_in_group("pets"):
		if pet.teamId == teamId:
			pet.visible = false

func getDropTarget(dropType: String):
	match dropType:
		CONST.POWERCORE:
			return ArtifactDropPoint
		CONST.GADGET:
			return ArtifactDropPoint
		CONST.RELIC:
			return RelicDropPoint
		CONST.EGG:
			return EggDropPoint
		CONST.IRON:
			return $Shredder
		CONST.WATER:
			return $Shredder
		CONST.SAND:
			return $Shredder
		CONST.PACK:
			return $Shredder

func getProjectileTargetProvider():
	return $ProjectileTargets

func getMeleeTarget(variant):
	match variant:
		CONST.LEFT: return $MeleeTargets / Left
		CONST.RIGHT: return $MeleeTargets / Right
		CONST.TOP: return $MeleeTargets / Top
		_:
			Logger.error("could not find a melee target for variant %s" % [variant])
			return null

func getFrontAttackPosition(variant) -> Vector2:
	var point: Vector2
	match variant:
		"left": point = $FrontAttackPoints / LeftPoint1.global_position
		"right": point = $FrontAttackPoints / RightPoint1.global_position
		_: point = $FrontAttackPoints / CenterPoint1.global_position
	var offset: = Vector2.RIGHT.rotated(randf() * TAU)
	return point + offset * 16 * randf()


func getCupolaPosition(offset: float, teamId: String) -> Vector3:
	var bl = $CupolaPath.curve.get_baked_length()
	var pos = $CupolaPath.curve.sample_baked(offset * bl)
	var p1 = $CupolaPath.curve.sample_baked((offset - 0.01) * bl)
	var p2 = $CupolaPath.curve.sample_baked((offset + 0.01) * bl)
	var angle = (p2 - p1).angle()
	pos = Utils.get_global_from_local_dome_position(pos, teamId)
	return Vector3(pos.x, pos.y, angle)

func getCupolaClosestPos(pos: Vector2, teamId: String) -> Vector2:
	return Utils.get_global_from_local_dome_position($CupolaPath.curve.get_closest_point(pos), teamId)

func getCupolaLength() -> float:
	return $CupolaPath.curve.get_baked_length()

func addWeapon(station: DomeStation):
	var weapon_scene: PackedScene = load("res://content/weapons/" + primaryWeapon + "/" + primaryWeapon.capitalize() + ".tscn")

	var w = weapon_scene.instantiate()
	w.teamId = teamId
	w.UID = randi()
	$WeaponContainer.add_child(w, true)
	w.showcaseMode = showcaseMode
	w.init($CupolaPath)
	station.addControlledWeapon(w)


	if station.getControlledWeapons().size() == 2:
		w.inverse = true
		w.pathProbe.progress_ratio = 1.0 - station.getControlledWeapons().front().pathProbe.progress_ratio
		w.remotePosition = w.pathProbe.progress_ratio

func remoteAddWeapon(UID: int, station: DomeStation) -> void :
	var weapon_scene: PackedScene = load("res://content/weapons/" + primaryWeapon + "/" + primaryWeapon.capitalize() + ".tscn")
	var w = weapon_scene.instantiate()
	w.teamId = teamId
	w.UID = UID
	$WeaponContainer.add_child(w, true)
	w.showcaseMode = showcaseMode
	w.init($CupolaPath)
	station.addControlledWeapon(w)

	if w is LaserWeapon and station.getControlledWeapons().size() == 2:
		w.inverse = true
		w.pathProbe.progress_ratio = 1.0 - station.getControlledWeapons().front().pathProbe.progress_ratio
		w.remotePosition = w.pathProbe.progress_ratio

func getWeapons():
	return $WeaponContainer.get_children()

func getCellarGadgets() -> Array[CellarGadget]:
	var cellarGadgets: Array[CellarGadget]
	for container: Node in _cellarContainers:
		for child in container.get_children():
			if child is CellarGadget:
				cellarGadgets.append(child)
	return cellarGadgets


func requestEnvironmentalDamage(rawDamage: int, damageSource: StringName, pos: = Vector2.ZERO, allow_multiple_per_frame: bool = false):
	var currentFrame = Engine.get_process_frames()
	if not allow_multiple_per_frame and lastEnvironmentalDamageFrame == currentFrame:
		return

	var damage: = rawDamage * float(Data.of(teamId + ".dome.incomingdamagemodifier"))
	if damage > 0.0:
		Data.changeDomeHealth( - damage, teamId)
		cracks_overlay.hit(pos, damage)
		handleSustainedDamage(damage)

	trackDamage(damageSource, damage)
	lastEnvironmentalDamageFrame = currentFrame


func requestProjectileDamage(rawDamage: int, pos: Vector2, requester):
	var remainingDamage = $Shield.absorbDamage(rawDamage * float(Data.of(teamId + ".dome.incomingdamagemodifier")), pos)
	var damage: float = remainingDamage * clamp((1.0 - Data.of(teamId + ".dome.projectiledamagereduction")), 0, 1)
	if damage > 0.0:
		Data.changeDomeHealth( - damage, teamId)
		cracks_overlay.hit(pos, damage)
		handleSustainedDamage(damage)
		requester.domeAcceptsDamage()
	elif damage == 0.0:
		requester.domeAbsorbsDamage()
	else:
		requester.domeReflectsDamage()

	trackDamage(requester.damageSource, damage)

func trackDamage(source, value):
	if source == "":
		push_error("Tried to track damage for monster but source was empty string.")
	if source != "":
		GameWorld.trackedDamageReceivedByTeamId[teamId][source] = GameWorld.trackedDamageReceivedByTeamId[teamId].get(source, 0) + value
	Level.monstersByTeamId[teamId].domeLostHealth(value)

func requestMeleeDamage(rawDamage: int, pos: Vector2, requester):
	var remainingDamage = $Shield.absorbDamage(rawDamage * float(Data.of(teamId + ".dome.incomingdamagemodifier")), pos)
	var damage: float = remainingDamage * clamp((1.0 - Data.of(teamId + ".dome.meleedamagereduction")), 0, 1)
	var thornDamage = Data.of(teamId + ".dome.meleethorndamage")
	if damage > 0.0:
		Data.changeDomeHealth( - damage, teamId)
		handleSustainedDamage(damage)
		cracks_overlay.hit(pos, damage)

	if thornDamage > 0.0 or damage <= 0.0:

		$Shield.zapMonsters([requester], 5.0)

		requester.domeReflectsDamage(thornDamage, 1.0, 1.0, 0.0)

		GameWorld.trackedDamageDealtByTeamId[teamId]["domesupplementelectrifiedsurface2"] = GameWorld.trackedDamageDealtByTeamId[teamId].get("domesupplementelectrifiedsurface2", 0) + thornDamage

	else:
		requester.domeAcceptsDamage()

	trackDamage(requester.damageSource, damage)

func requestBeamDamage(rawDamage: int, pos: Vector2, requester):
	var remainingDamage = $Shield.absorbDamage(rawDamage * float(Data.of(teamId + ".dome.incomingdamagemodifier")), pos)
	var reduction = 0.5 * (Data.of(teamId + ".dome.meleedamagereduction") + Data.of(teamId + ".dome.projectiledamagereduction"))
	var damage: float = remainingDamage * clamp((1.0 - reduction), 0, 1)
	if damage > 0.0:
		Data.changeDomeHealth( - damage, teamId)
		handleSustainedDamage(damage)
		cracks_overlay.hit(pos, damage)

	if damage > 0.0:
		requester.domeAcceptsDamage()
		trackDamage(requester.damageSource, damage)


func addGadget(gadget, teamId: String, slot: String):
	gadget.teamId = teamId
	if slot == teamId + ".primarygadget" or slot == "primarygadget":
		gadget.domeId = techId
		$PrimaryGadgetContainer.add_child(gadget, true)
	elif slot == teamId + ".cellar" or slot == "cellar":
		placeInCellar(gadget)
	elif slot == teamId + ".domesurface" or slot == "domesurface":
		$CupolaPath.add_child(gadget)
		gadget.init($CupolaPath)
	elif slot == teamId + ".domebackside" or slot == "domebackside":
		$BacksideContainer.add_child(gadget)
	else:
		Logger.error("cannost add gadget to dome, unknown slot", "Dome.addGadget", {"slot": slot, "gadget": str(gadget)})

func removePrimaryGadget():
	for c in $PrimaryGadgetContainer.get_children():
		c.remove()

func placeInCellar(gadget):
	var container
	if $Cellar / ContainerLeft.get_child_count() > 0:
		container = $Cellar / ContainerRight
	elif $Cellar / ContainerRight.get_child_count() > 0:
		container = $Cellar / ContainerLeft
	else:
		container = $Cellar / ContainerLeft


	if container.position.x < 0:
		gadget.flip()
	container.add_child(gadget)

@rpc("reliable")
func autoheal():
	$HealEffect.start()
	$Autoheal.startSound()

func handleSustainedDamage(damage: float):
	damageOnWave += damage
	if remainingHeals > 0:
		var threshold = Data.of(teamId + ".dome.autohealdamagethreshold")
		if threshold > 0.0 and (damageOnWave - autohealOnWave) >= threshold:
			autoRepairAmount = Data.of(teamId + ".dome.autohealamount")
			remainingHeals -= 1
			autohealOnWave += autoRepairAmount
			autoheal()

func ambience() -> AudioStreamPlayer:
	return $Ambience as AudioStreamPlayer

func uiRender():
	$Cellar.queue_free()

func _on_RelicDropPoint_relic_recovered():
	InputSystem.shake(80, 2, 5, $Cellar / RelicActivation.global_position)
	$Cellar / RelicActivation.play("activate")
	$Cellar / RelicActivation / Inserted.startSound()

func deactivate_relic():
	$Cellar / RelicActivation.play("deactivate")

func _on_relic_activation_animation_looped() -> void :
	_RelicActivationAnimationFinishedCheck()

func _on_RelicActivation_animation_finished() -> void :
	_RelicActivationAnimationFinishedCheck()

func _RelicActivationAnimationFinishedCheck() -> void :
	match $Cellar / RelicActivation.animation:
		"activate":
			$Cellar / RelicActivation / Ambience.startSound()
			$Cellar / RelicActivation.play("running")
			$Cellar / SpinningRelic.play("spinning")
		"deactivate":
			$Cellar / RelicActivation / Ambience.stop()
			$Cellar / RelicActivation.play("none")
			$Cellar / SpinningRelic.play("none")

@rpc("reliable", "any_peer")
func executeBattle1() -> void :
	for s in get_tree().get_nodes_in_group(teamId + "-dome_ability1"):
		var consumed = s.executeBattle1()
		if consumed:
			Network.rpc_if_state(s.remoteExecuteBattle1, Network.ConnectionState.LEVEL_STAGE_SYNC)
			break

@rpc("reliable", "any_peer")
func executeBattle2() -> void :
	for s in get_tree().get_nodes_in_group(teamId + "-dome_ability2"):
		var consumed = s.executeBattle2()
		if consumed:
			Network.rpc_if_state(s.remoteExecuteBattle2, Network.ConnectionState.LEVEL_STAGE_SYNC)
			break

@rpc("reliable", "any_peer")
func startWeapons(stationIndex: int) -> void :
	var station: = stations[stationIndex]
	var isLocalTeamDome: bool = not Keepers.local.getAllFromTeam(teamId).is_empty()
	if isLocalTeamDome:
		_chargeOn.startSound()

	for weapon in station.controlledWeapons:
		weapon.start()
	for listener in station.get_tree().get_nodes_in_group(teamId + "-battle-start-stop-listener"):
		listener.start()

@rpc("reliable", "any_peer")
func stopWeapons(stationIndex: int) -> void :
	var station: = stations[stationIndex]
	var isLocalTeamDome: bool = not Keepers.local.getAllFromTeam(teamId).is_empty()
	if isLocalTeamDome:
		_chargeOff.startSound()

	for weapon in station.controlledWeapons:
		weapon.inputs(Vector2.ZERO, 0.0, 0.0, Vector2(0, 0))
		weapon.stop()
	for listener in station.get_tree().get_nodes_in_group(teamId + "-battle-start-stop-listener"):
		listener.stop()

func getKeeperPosition() -> Vector2:
	return $KeeperPosition.global_position

static func weaponsStarted(teamId: String, count: int) -> bool:
	var started: = 0
	for station in Level.domesByTeamId[teamId].stations:
		for weapon: PrimaryWeapon in station.getControlledWeapons():
			if weapon.started:
				started += 1
			if started == count:
				return true
	return false

func removeSecondaryStation() -> void :
	if stations[1].keeperInStation:
		stations[1].forceKeeperExit()
	stations[1].disable()
	%LeftCellarCollider.disabled = false
	%LeftCellarSecondaryStationCollider.disabled = true
	setSecondCellarCollision(-1, false)

func addSecondaryStation():
	stations[1].enable()
	%LeftCellarCollider.disabled = true
	%LeftCellarSecondaryStationCollider.disabled = false
	setSecondCellarCollision(-1, true)

func removeSpyCam() -> void :
	%SpyCam.disable()
	%RightCellarCollider.disabled = false
	%RightCellarSpyCamCollider.disabled = true
	setSecondCellarCollision(1, false)

func addSpyCam():
	%SpyCam.enable()
	%RightCellarCollider.disabled = true
	%RightCellarSpyCamCollider.disabled = false
	setSecondCellarCollision(1, true)

func setSecondCellarCollision(side: int, open: bool):
	if Level.map:
		var baseX: int = position.x / GameWorld.TILE_SIZE
		for coord: Vector2 in [Vector2(baseX + side * 1, -1), Vector2(baseX + side * 2, -1)]:
			var tile = Level.map.getTile(coord)
			if tile:
				tile.set_collider_disabled(open)
			elif not StageManager.level_ready.is_connected(on_level_ready):
				StageManager.level_ready.connect(on_level_ready.bind(side, open), CONNECT_ONE_SHOT)

func on_level_ready(side: int, open: bool) -> void :


	Data.listen(self, teamId + ".inventory.iron")

	var baseX: int = position.x / GameWorld.TILE_SIZE
	for coord: Vector2 in [Vector2(baseX + side * 1, -1), Vector2(baseX + side * 2, -1)]:
		var tile = Level.map.getTile(coord)
		if tile:
			tile.set_collider_disabled(open)

func addPet(petId: String) -> void :
	petSynchronizer.network_spawn(petId)

func _on_keeper_projectiles_detector_area_entered(area: Area2D) -> void :
	if not area.get_parent() is KunaiCarrier:
		return
	area.get_parent().force_move_towards_shredder($Shredder)
