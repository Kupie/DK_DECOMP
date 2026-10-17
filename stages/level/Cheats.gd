class_name Cheats
extends PanelContainer

var keeperSuitGadgets: = [
	"probe", 
	"prospectionmeter", 
	"suitblaster", 
	"resourcepacker", 
	"keeperonewayteleporter", 
	"keeper1powerdrill", 
	"keeper2pinballdestroyadjacenttiles", 
	"keeper3rocketcarrier", 
	"keeper4extraresource"
]

const CONTROL_IRON = [0, 
9.780403315600644, 
15.06615555830345, 
21.05662031817613, 
26.774104683195592, 
32.852919161676645, 
38.808969059250906, 
45.49246420497362, 
52.418723510346545, 
59.489219518345735, 
67.09701679618952, 
75.06459300137966, 
83.29991259832688, 
90.70904241808483, 
99.06180706002294, 
107.95286023697288, 
116.98955680081508, 
126.58775405854531, 
135.73220251863273, 
145.29207214220838, 
155.04659404121276, 
164.8573709419904, 
174.30872210953348, 
183.77616724738675, 
192.81092012133468, 
201.48103552077063, 
209.78266391490712, 
217.8871483914435, 
225.56021602160217, 
232.76331245105715, 
239.4901833872708, ]

const CONTROL_WEIGHT = [
	19.100000000000005, 
35.42844551282061, 
57.178763866877986, 
78.91399176954724, 
100.92172839506168, 
123.26561360874834, 
143.95177768696357, 
165.9558388157893, 
189.54888357256783, 
211.97460711331664, 
236.47157298827423, 
261.0809543065104, 
286.9573535273, 
309.591159299416, 
334.8395124001682, 
361.23398911678487, 
387.3503105590064, 
414.2661924686197, 
441.3518440016959, 
468.10795159896304, 
495.782589676288, 
523.686109870477, 
551.6156164383575, 
578.1790575916233, 
605.9854291417156, 
634.1624868282411, 
660.1989847715719, 
687.2044930176066, 
715.8183619550858, 
743.6017204301079, 
770.4297697368424, 
]


var targeted_team_id: = "team1"
var added_gadgets: = {}

func init():
	added_gadgets["team1"] = {}
	added_gadgets["team2"] = {}

	find_child("MonsterList").add_item("Walker")
	find_child("MonsterList").add_item("Walker")
	find_child("MonsterList").add_item("Flyer")
	find_child("MonsterList").add_item("Flyer")
	find_child("MonsterList").add_item("Driller")
	find_child("MonsterList").add_item("Driller")
	find_child("MonsterList").add_item("Diver")
	find_child("MonsterList").add_item("Diver")
	find_child("MonsterList").add_item("Tick")
	find_child("MonsterList").add_item("Tick")
	find_child("MonsterList").add_item("Worm")
	find_child("MonsterList").add_item("Worm")
	find_child("MonsterList").add_item("Bolter")
	find_child("MonsterList").add_item("Bolter")
	find_child("MonsterList").add_item("Mucker")
	find_child("MonsterList").add_item("Mucker")
	find_child("MonsterList").add_item("Shifter")
	find_child("MonsterList").add_item("Shifter")
	find_child("MonsterList").add_item("Big Tick")
	find_child("MonsterList").add_item("Big Tick")
	find_child("MonsterList").add_item("Butterfly")
	find_child("MonsterList").add_item("Butterfly")
	find_child("MonsterList").add_item("Beast")
	find_child("MonsterList").add_item("Beast")
	find_child("MonsterList").add_item("Rockman")
	find_child("MonsterList").add_item("Rockman")
	find_child("MonsterList").add_item("Stingray")
	find_child("MonsterList").add_item("Stingray")
	find_child("MonsterList").add_item("Stag")
	find_child("MonsterList").add_item("Stag")
	find_child("MonsterList").add_item("Hornet")
	find_child("MonsterList").add_item("Hornet")
	find_child("MonsterList").add_item("Breeder")
	find_child("MonsterList").add_item("Breeder")
	find_child("MonsterList").add_item("Tormentor")
	find_child("MonsterList").add_item("Tormentor")
	find_child("MonsterList").add_item("Phaser")
	find_child("MonsterList").add_item("Phaser")
	find_child("MonsterList").add_item("Bloater")
	find_child("MonsterList").add_item("Bloater")
	find_child("MonsterList").add_item("Scarab")

	var keys = Data.gadgets.keys()
	keys.sort()
	for g in keys:
		if not GameWorld.boughtUpgrades.has(g) and Data.gadgets[g].get("type", "").find("gadget") != -1:
			find_child("GadgetList").add_item(g)

	keys = Data.supplements.keys()
	keys.sort()
	for k in keys:
		find_child("SupplementList").add_item(k)

	for c in find_child("PaletteContainer").get_children():
		c.connect("pressed", Callable(self, "setPalette").bind(int(c.name.substr("ButtonPalette".length()))))
	for c in find_child("WorldContainer").get_children():
		c.connect("pressed", Callable(self, "setWorld").bind(int(c.name.substr("ButtonWorld".length()))))

	Data.listen(self, "team1.dome.health")
	Data.listen(self, "team1.monsters.wavepresent")
	Data.listen(self, "team2.dome.health")
	Data.listen(self, "team2.monsters.wavepresent")

	find_child("EnableCheatDetectionButton").button_pressed = GameWorld.runCheatDetection

	updatePaletteButtons()
	find_child("DisableWavesButton").button_pressed = GameWorld.devMode

func _process(delta):
	if not visible:
		return
	find_child("WaveCountDown").text = "%.0fs" % Data.of(targeted_team_id + ".monsters.waveCooldown")
	find_child("WaveIndex").text = str(Data.of(targeted_team_id + ".monsters.cycle"))
	for mm in get_tree().get_nodes_in_group("monster-manager"):
		find_child("WaveDamageLabel").text = "%.0fs" % mm.waveDamageCounter
		find_child("BattleIntensityLabel").text = "%.1f" % mm.battleIntensity
		if mm.currentWave:
			var w = mm.currentWave.getWeight()
			if w != -1.0:
				find_child("LastWaveLabel").text = str(w)
		break
	if Level.map:
		find_child("WaveIntervalLabel").text = "%.1f" % (100.0 * Level.map.getProgress()) + "%"
		find_child("WaveIntervalLabel").text = "%.1f" % (100 * Level.map.getProgress()) + "%"
	if Level.mode:
		find_child("RunWeightLabel").text = "%.0f" % Level.mode.getRunWeight(targeted_team_id)
	find_child("CycleLengthLabel").text = "%.0fs" % (GameWorld.getTimeBetweenWaves(targeted_team_id))
	find_child("FPSLabel").text = "%d" % Engine.get_frames_per_second()
	%RunTimeLabel.text = "%.0f" % GameWorld.runTime
	for keeper in Keepers.getAll():
		find_child("SpeedLabel").text = "%.0f" % keeper.move.length()
		var coord = Level.map.getTileCoord(keeper.global_position)
		find_child("DepthLabel").text = str(coord.x) + ":" + str(coord.y)
		find_child("LayerLabel").text = str(Level.map.getLayerOfCoord(coord))
		find_child("BiomeLabel").text = str(Level.map.getBiomeOfCoord(coord))

		break









func _on_Cheats_visibility_changed():
	InputSystem.singleFocus = visible
	if not visible:
		return
	find_child("LockSeedButton").text = "Unlock Seed" if GameWorld.devState.has("lockedSeed") else "Lock Seed"
	find_child("LockSeedButton").button_pressed = GameWorld.devState.has("lockedSeed")
	find_child("SeedIDLabel").text = "ID: " + str(Level.levelSeed)


func propertyChanged(property: String, oldValue, newValue):
	if property == targeted_team_id + ".dome.health":
		find_child("DomeHealthLabel").text = "%.0f" % newValue
	elif property == targeted_team_id + ".monsters.wavepresent":
		if newValue:
			find_child("LastWaveGoal").text = str(Level.mode.getRunWeight(targeted_team_id) * Data.of(targeted_team_id + ".monsters.waveStrengthModifier"))

func _on_AddIronButton_pressed():
	Data.changeByInt(targeted_team_id + ".inventory." + CONST.IRON, 30)

func _on_clear_iron_button_pressed():
	Data.apply(targeted_team_id + ".inventory." + CONST.IRON, 0)

func _on_AddWaterButton_pressed():
	Data.changeByInt(targeted_team_id + ".inventory." + CONST.WATER, 10)

func _on_clear_water_button_pressed():
	Data.apply(targeted_team_id + ".inventory." + CONST.WATER, 0)

func _on_AddSandButton_pressed():
	Data.changeByInt(targeted_team_id + ".inventory." + CONST.SAND, 10)

func _on_clear_sand_button_pressed():
	Data.apply(targeted_team_id + ".inventory." + CONST.SAND, 0)

func buyUpgrade(s: String, teamId: String):
	var prev = Data.getInventory("iron", teamId)
	GameWorld.buyUpgrade(s, teamId, Keepers.first().playerId)
	Data.changeByInt(targeted_team_id + ".inventory.iron", prev - Data.getInventory("iron", teamId))

func _on_ButtonHud_pressed():
	buyUpgrade("DomeWaveMeter".to_lower(), targeted_team_id)
	buyUpgrade("DomeWaveCount".to_lower(), targeted_team_id)
	buyUpgrade("DomeResourceCounters".to_lower(), targeted_team_id)
	buyUpgrade("domeHealthMeter".to_lower(), targeted_team_id)

func _on_ButtonDrill_pressed():
	for teamId in Level.teams:
		buyUpgrade("drill4".to_lower(), teamId)

func _on_ButtonMove_pressed():
	for teamId in Level.teams:
		buyUpgrade("jetpackSpeed4".to_lower(), teamId)
		buyUpgrade("jetpackStrength4".to_lower(), teamId)

func _on_ButtonDome_pressed():
	for teamId in Level.teams:
		buyUpgrade("laserStrength2".to_lower(), teamId)
		buyUpgrade("laserMove1".to_lower(), teamId)

func _on_ButtonAll_pressed():
	_on_ButtonHud_pressed()
	_on_ButtonDrill_pressed()
	_on_ButtonMove_pressed()
	_on_ButtonDome_pressed()

func _on_CloseButton_pressed():
	visible = false

func _on_NextWaveButton_pressed():
	for mm in get_tree().get_nodes_in_group("monster-manager"):
		mm.disabled = false
	Data.apply(targeted_team_id + ".monsters.waveCooldown", 0)

func _on_ButtonGameSpeed_pressed(speed):
	Engine.time_scale = speed

func _on_SkipWaveButton_pressed():
	Data.changeByInt(targeted_team_id + ".monsters.cycle", 1)

func _on_KillWaveButton_pressed():
	for mm in get_tree().get_nodes_in_group("monster-manager"):
		if mm.teamId != targeted_team_id:
			continue
		mm.instantlyKillWave()

func _on_HitAllMonsters_pressed():
	for m in get_tree().get_nodes_in_group("monster"):
		m.hit("cheat", 2000, 0)

func _on_WinButton_pressed():
	pass

func _on_LoseButton_pressed():
	pass

func _on_ButtonCam1x_pressed():
	for keeper in Keepers.getAll():
		keeper.goalCameraZoom = 6
		Data.apply(keeper.playerId + ".keeper.zoominmine", 6)

func _on_ButtonCam5px_pressed() -> void :
	for keeper in Keepers.getAll():
		keeper.goalCameraZoom = 5
		Data.apply(keeper.playerId + ".keeper.zoominmine", 5)

func _on_ButtonCam4px_pressed() -> void :
	for keeper in Keepers.getAll():
		keeper.goalCameraZoom = 4
		Data.apply(keeper.playerId + ".keeper.zoominmine", 4)

func _on_ButtonCam3x_pressed():


	for keeper in Keepers.getAll():
		keeper.goalCameraZoom = 3.05
		Data.apply(keeper.playerId + ".keeper.zoominmine", 3.05)

func _on_ButtonCam4x_pressed():
	for keeper in Keepers.getAll():
		keeper.goalCameraZoom = 2
		Data.apply(keeper.playerId + ".keeper.zoominmine", 2)

func _on_ButtonCam6x_pressed():
	for keeper in Keepers.getAll():
		keeper.goalCameraZoom = 1
		Data.apply(keeper.playerId + ".keeper.zoominmine", 1.5)

func _on_ButtonCam266x_pressed():
	for keeper in Keepers.getAll():
		keeper.goalCameraZoom = 1920.0 / 720.0
		Data.apply(keeper.playerId + ".keeper.zoominmine", 1920.0 / 720.0)

func _on_DisableWavesButton_pressed():
	for mm in Level.monstersByTeamId.values():
		mm.disabled = find_child("DisableWavesButton").button_pressed

func _on_0HealthButton_pressed():
	Data.changeDomeHealth( - Data.of(targeted_team_id + ".dome.health"), targeted_team_id)

func _on_1HealthButton_pressed():
	Data.changeDomeHealth(Data.of(targeted_team_id + ".dome.maxHealth") * 0.01 - Data.of(targeted_team_id + ".dome.health"), targeted_team_id)

func _on_50HealthButton_pressed():
	Data.changeDomeHealth(Data.of(targeted_team_id + ".dome.maxHealth") * 0.5 - Data.of(targeted_team_id + ".dome.health"), targeted_team_id)

func _on_100HealthButton_pressed():
	Data.changeDomeHealth(Data.of(targeted_team_id + ".dome.maxHealth") * 1.0 - Data.of(targeted_team_id + ".dome.health"), targeted_team_id)

func _on_GadgetList_item_selected(index):
	var il: ItemList = find_child("GadgetList")
	var text = il.get_item_text(index)
	if keeperSuitGadgets.has(text):
		for keeper in Keepers.getAll():
			if keeper.teamId != targeted_team_id:
				continue
			GameWorld.serverAddUpgrade(keeper.playerId + "." + text, keeper.teamId)
	else:
		GameWorld.serverAddUpgrade(text, targeted_team_id)
	added_gadgets[targeted_team_id][text] = true
	il.deselect(index)
	update_gadget_list_disabled()

func _on_supplement_list_item_selected(index):
	var il: ItemList = find_child("SupplementList")
	var text = il.get_item_text(index)
	if keeperSuitGadgets.has(text):
		for keeper in Keepers.getAll():
			if keeper.teamId != targeted_team_id:
				continue
			GameWorld.serverAddUpgrade(keeper.playerId + "." + text, keeper.teamId)
	else:
		GameWorld.serverAddUpgrade(text, targeted_team_id)
	added_gadgets[targeted_team_id][text] = true
	il.deselect(index)
	update_gadget_list_disabled()

func update_gadget_list_disabled() -> void :
	set_list_items_disabled("GadgetList")
	set_list_items_disabled("SupplementList")

func set_list_items_disabled(list_name: String) -> void :
	var il: ItemList = find_child(list_name)
	for idx in range(il.item_count):
		var text = il.get_item_text(idx)
		var should_be_disabled: bool = added_gadgets[targeted_team_id].has(text) and added_gadgets[targeted_team_id][text]
		il.set_item_selectable(idx, not should_be_disabled)
		il.set_item_disabled(idx, should_be_disabled)

func _on_MonsterList_item_selected(index):
	for mm in get_tree().get_nodes_in_group("monster-manager"):
		if mm.teamId != targeted_team_id:
			continue
		match index:
			0:
				mm._spawnMonster("walker", "left")
			1:
				mm._spawnMonster("walker", "right")
			2:
				mm._spawnMonster("flyer", "left")
			3:
				mm._spawnMonster("flyer", "right")
			4:
				mm._spawnMonster("driller", "left")
			5:
				mm._spawnMonster("driller", "right")
			6:
				mm._spawnMonster("diver", "left")
			7:
				mm._spawnMonster("diver", "right")
			8:
				mm._spawnMonster("tick", "left")
			9:
				mm._spawnMonster("tick", "right")
			10:
				mm._spawnMonster("worm", "left")
			11:
				mm._spawnMonster("worm", "right")
			12:
				mm._spawnMonster("bolter", "left")
			13:
				mm._spawnMonster("bolter", "right")
			14:
				mm._spawnMonster("mucker", "left")
			15:
				mm._spawnMonster("mucker", "right")
			16:
				mm._spawnMonster("shifter", "left")
			17:
				mm._spawnMonster("shifter", "right")
			18:
				mm._spawnMonster("bigtick", "left")
			19:
				mm._spawnMonster("bigtick", "right")
			20:
				mm._spawnMonster("butterfly", "left_high")
			21:
				mm._spawnMonster("butterfly", "right_high")
			22:
				mm._spawnMonster("beast", "left")
			23:
				mm._spawnMonster("beast", "right")
			24:
				mm._spawnMonster("rockman", "left")
			25:
				mm._spawnMonster("rockman", "right")
			26:
				mm._spawnMonster("stingray", "left")
			27:
				mm._spawnMonster("stingray", "right")
			28:
				mm._spawnMonster("stag", "left")
			29:
				mm._spawnMonster("stag", "right")
			30:
				mm._spawnMonster("hornet", "left")
			31:
				mm._spawnMonster("hornet", "right")
			32:
				mm._spawnMonster("breeder", "left")
			33:
				mm._spawnMonster("breeder", "right")
			34:
				mm._spawnMonster("tormentor", "left")
			35:
				mm._spawnMonster("tormentor", "right")
			36:
				mm._spawnMonster("phaser", "left")
			37:
				mm._spawnMonster("phaser", "right")
			38:
				mm._spawnMonster("bloater", "left")
			39:
				mm._spawnMonster("bloater", "right")
			40:
				mm._spawnMonster("scarab", "center")

func _on_AddArtifact1Button_pressed():
	var keeper: = Keepers.get_team(targeted_team_id).first()
	Level.stage.queueChoice(CONST.GADGET, targeted_team_id, keeper.playerId)

func _on_AddSupplementButton2_pressed():
	var keeper: = Keepers.get_team(targeted_team_id).first()
	Level.stage.queueChoice(CONST.POWERCORE, targeted_team_id, keeper.playerId)

func _on_UnlockAllGadgetsButton_pressed() -> void :
	for i in %GadgetList.item_count:
		GameWorld.addUpgrade( %GadgetList.get_item_text(i))

func _on_unlock_all_supplements_button_pressed():
	for i in %SupplementList.item_count:
		GameWorld.addUpgrade( %SupplementList.get_item_text(i))

func _on_LockHealthButton_pressed() -> void :
	for team in Level.teams:
		Data.apply(team + ".dome.healthlocked", find_child("LockHealthButton").button_pressed)

func _on_RevealAllTilesButton_pressed():
	var map = Level.map.tileData
	Level.map.tileCoordsToReveal.append_array(map.get_used_cells(MapData.LAYER_BIOME))
	Level.map.floodRevealTiles()

func _on_Clear1TilesButton_pressed():
	var t: = []
	for x in range(-100, 100):
		for y in range(0, 200):
			t.append(Vector2(x, y))
	Level.map.freeTiles(t)

func _on_Clear10TilesButton_pressed():
	var t: = []
	for x in range(-5, 5):
		for y in range(0, 10):
			t.append(Vector2(x, y))
	while Level.map.freeTiles(t) > 0:
		await get_tree().create_timer(0.2).timeout

func _on_Clear20TilesButton_pressed():
	var t: = []
	for x in range(-10, 10):
		for y in range(0, 20):
			t.append(Vector2(x, y))
	while Level.map.freeTiles(t) > 0:
		await get_tree().create_timer(0.2).timeout

func _on_Load0Button_pressed():

	SaveGame.loadRollingMetaState()

func _on_Save1Button_pressed():
	SaveGame.saveGame(SaveGame.get_run_folder(), 11)

func _on_Load1Button_pressed():
	SaveGame.loadGame(SaveGame.get_run_folder(), 11)

func _on_Save2Button_pressed():
	SaveGame.saveGame(SaveGame.get_run_folder(), 12)

func _on_Load2Button_pressed():
	SaveGame.loadGame(SaveGame.get_run_folder(), 12)

func _on_Save3Button_pressed():
	SaveGame.saveGame(SaveGame.get_run_folder(), 13)

func _on_Load3Button_pressed():
	SaveGame.loadGame(SaveGame.get_run_folder(), 13)

var i
func _on_ButtonCameraController_pressed():
	var cam = InputSystem.getCamera()
	if find_child("ButtonCameraController").button_pressed:
		cam.set_script(preload("res://systems/camera/ManualCamera.gd"))
		i = preload("res://systems/camera/ManualCameraInputProcessor.gd").new()
		i.connect("onStop", set.bind("i", null))
		cam.init()
		i.cam = cam
		i.integrate(Level.stage)
	else:
		i.desintegrate()
		cam.set_script(load("res://systems/camera/KeeperCamera.gd"))
		cam.init(Keepers.getAll().front())
	cam.set_process(true)

var oldVals: = {}
func _on_ButtonTempDigging_pressed():
	if find_child("ButtonTempDigging").button_pressed:
		for keeper in Keepers.getAll():
			match keeper.techId:
				"keeper1":
					if oldVals.is_empty():
						oldVals[keeper.playerId + ".keeper1.drillStrength"] = Data.of(keeper.playerId + ".keeper1.drillStrength")
						oldVals[keeper.playerId + ".keeper1.maxSpeed"] = Data.of(keeper.playerId + ".keeper1.maxSpeed")
						oldVals[keeper.playerId + ".keeper1.speedLossPerCarry"] = Data.of(keeper.playerId + ".keeper1.speedLossPerCarry")
						oldVals[keeper.playerId + ".keeper1.tileKnockback"] = Data.of(keeper.playerId + ".keeper1.tileKnockback")
						oldVals[keeper.playerId + ".keeper1.slowdownRecovery"] = Data.of(keeper.playerId + ".keeper1.slowdownRecovery")
					Data.apply(keeper.playerId + ".keeper1.drillStrength", 1000)
					Data.apply(keeper.playerId + ".keeper1.maxSpeed", 100)
					Data.apply(keeper.playerId + ".keeper1.speedLossPerCarry", 0.01)
					Data.apply(keeper.playerId + ".keeper1.tileKnockback", 2)
					Data.apply(keeper.playerId + ".keeper1.slowdownRecovery", 10)
				"keeper2":
					if oldVals.is_empty():
						oldVals[keeper.playerId + ".keeper2.maxSpeed"] = Data.of(keeper.playerId + ".keeper2.maxSpeed")
						oldVals[keeper.playerId + ".keeper2.acceleration"] = Data.of(keeper.playerId + ".keeper2.acceleration")
						oldVals[keeper.playerId + ".keeper2.totalspheres"] = Data.of(keeper.playerId + ".keeper2.totalspheres")
						oldVals[keeper.playerId + ".keeper2.spherereload"] = Data.of(keeper.playerId + ".keeper2.spherereload")
						oldVals[keeper.playerId + ".keeper2.spherebasedamage"] = Data.of(keeper.playerId + ".keeper2.spherebasedamage")
						oldVals[keeper.playerId + ".keeper2.spherebaselifetime"] = Data.of(keeper.playerId + ".keeper2.spherebaselifetime")
						oldVals[keeper.playerId + ".keeper2.spherefractiondamage"] = Data.of(keeper.playerId + ".keeper2.spherefractiondamage")
						oldVals[keeper.playerId + ".keeper2.directminingdamage"] = Data.of(keeper.playerId + ".keeper2.directminingdamage")
					Data.apply(keeper.playerId + ".keeper2.maxSpeed", 200)
					Data.apply(keeper.playerId + ".keeper2.acceleration", 80)
					Data.apply(keeper.playerId + ".keeper2.totalspheres", 4)
					Data.apply(keeper.playerId + ".keeper2.spherereload", 4)
					Data.apply(keeper.playerId + ".keeper2.spherebasedamage", 10)
					Data.apply(keeper.playerId + ".keeper2.directminingdamage", 100)
					Data.apply(keeper.playerId + ".keeper2.spherebaselifetime", 10)
					Data.apply(keeper.playerId + ".keeper2.spherefractiondamage", 0.5)
				"keeper3":
					if oldVals.is_empty():
						oldVals[keeper.playerId + ".keeper3.carrylimit"] = Data.of(keeper.playerId + ".keeper3.carrylimit")
						oldVals[keeper.playerId + ".keeper3.maxjumps"] = Data.of(keeper.playerId + ".keeper3.maxjumps")
						oldVals[keeper.playerId + ".keeper3.slidecontrol"] = Data.of(keeper.playerId + ".keeper3.slidecontrol")
						oldVals[keeper.playerId + ".keeper3.aircontrol"] = Data.of(keeper.playerId + ".keeper3.aircontrol")
						oldVals[keeper.playerId + ".keeper3.jumpamplification"] = Data.of(keeper.playerId + ".keeper3.jumpamplification")
						oldVals[keeper.playerId + ".keeper3.kunaidamage"] = Data.of(keeper.playerId + ".keeper3.kunaidamage")
						oldVals[keeper.playerId + ".keeper3.kunaiweaknessagainsthardrock"] = Data.of(keeper.playerId + ".keeper3.kunaiweaknessagainsthardrock")
						oldVals[keeper.playerId + ".keeper3.kunaicooldown"] = Data.of(keeper.playerId + ".keeper3.kunaicooldown")
						oldVals[keeper.playerId + ".keeper3.hasshuriken"] = Data.of(keeper.playerId + ".keeper3.hasshuriken")
						oldVals[keeper.playerId + ".keeper3.shurikenstrength"] = Data.of(keeper.playerId + ".keeper3.shurikenstrength")
						oldVals[keeper.playerId + ".keeper3.shurikencooldown"] = Data.of(keeper.playerId + ".keeper3.shurikencooldown")
					Data.apply(keeper.playerId + ".keeper3.carrylimit", 10)
					Data.apply(keeper.playerId + ".keeper3.maxjumps", 4)
					Data.apply(keeper.playerId + ".keeper3.slidecontrol", 1)
					Data.apply(keeper.playerId + ".keeper3.aircontrol", 1)
					Data.apply(keeper.playerId + ".keeper3.jumpamplification", 0.5)
					Data.apply(keeper.playerId + ".keeper3.kunaidamage", 1000)
					Data.apply(keeper.playerId + ".keeper3.kunaiweaknessagainsthardrock", 0)
					Data.apply(keeper.playerId + ".keeper3.kunaicooldown", 0.2)
					Data.apply(keeper.playerId + ".keeper3.hasshuriken", true)
					Data.apply(keeper.playerId + ".keeper3.shurikenstrength", 5)
					Data.apply(keeper.playerId + ".keeper3.shurikencooldown", 0.2)
				"keeper4":
					if oldVals.is_empty():
						oldVals[keeper.playerId + ".keeper4.movespeed"] = Data.of(keeper.playerId + ".keeper4.movespeed")
						oldVals[keeper.playerId + ".keeper4.punchStrength"] = Data.of(keeper.playerId + ".keeper4.punchStrength")
						oldVals[keeper.playerId + ".keeper4.maxSpeedupAtPunches"] = Data.of(keeper.playerId + ".keeper4.maxSpeedupAtPunches")
						oldVals[keeper.playerId + ".keeper4.maxpunchdelay"] = Data.of(keeper.playerId + ".keeper4.maxpunchdelay")
						oldVals[keeper.playerId + ".keeper4.minpunchdelay"] = Data.of(keeper.playerId + ".keeper4.minpunchdelay")
						oldVals[keeper.playerId + ".keeper4.catgoblincount"] = Data.of(keeper.playerId + ".keeper4.catgoblincount")
						oldVals[keeper.playerId + ".keeper4.catgoblincount"] = Data.of(keeper.playerId + ".keeper4.catgoblincount")
						oldVals[keeper.playerId + ".keeper4.autospawnminers"] = Data.of(keeper.playerId + ".keeper4.autospawnminers")
						oldVals[keeper.playerId + ".keeper4.holesquad"] = Data.of(keeper.playerId + ".keeper4.holesquad")
						oldVals[keeper.playerId + ".keeper4.squadcount"] = Data.of(keeper.playerId + ".keeper4.squadcount")
						oldVals[keeper.playerId + ".keeper4.holesquadduration"] = Data.of(keeper.playerId + ".keeper4.holesquadduration")
					Data.apply(keeper.playerId + ".keeper4.movespeed", 265)
					Data.apply(keeper.playerId + ".keeper4.punchStrength", 1000)
					Data.apply(keeper.playerId + ".keeper4.maxSpeedupAtPunches", 60)
					Data.apply(keeper.playerId + ".keeper4.maxpunchdelay", 0.42)
					Data.apply(keeper.playerId + ".keeper4.minpunchdelay", 0.1)
					Data.apply(keeper.playerId + ".keeper4.catgoblincount", 10)
					Data.apply(keeper.playerId + ".keeper4.autospawnminers", true)
					Data.apply(keeper.playerId + ".keeper4.holesquad", 8)
					Data.apply(keeper.playerId + ".keeper4.squadcount", 2)
					Data.apply(keeper.playerId + ".keeper4.holesquadduration", 30)

	else:
		for k in oldVals:
			Data.apply(k, oldVals[k])
		oldVals.clear()

func _on_VegetateButton_pressed():
	Level.map.border_deco.runDecoration()

func _on_VegetationSlider_value_changed(value):
	for d in get_tree().get_nodes_in_group("decoration"):
		d.visible = randf() < value

func _on_RunWeightLowerButton_pressed():
	GameWorld.additionalRunWeight -= 50

func _on_RunWeightRaiseButton_pressed():
	GameWorld.additionalRunWeight += 50

func _on_run_weight_raise_button_2_pressed() -> void :
	GameWorld.additionalRunWeight += 1000

func _on_StartFinaleButton_pressed():
	Data.changeByInt(targeted_team_id + ".inventory.relic", 1)

func _on_ButtonVignette_pressed():
	for keeper: Keeper in Keepers.local.getAll():
		var vignette: Vignette = Level.stage.getVignette(keeper)
		vignette.visible = find_child("ButtonVignette").button_pressed

func _on_LightningButton_pressed():
	setWeather(0)

func _on_FogButton_pressed():
	setWeather(1)

func _on_RainButton_pressed():
	setWeather(2)

func _on_StormButton_pressed():
	setWeather(3)

func _on_SnowButton_pressed():
	setWeather(4)

func _on_MeteorButton_pressed():
	setWeather(5)

func _on_SporesButton_pressed():
	setWeather(6)

func _on_WindstormButton_pressed():
	setWeather(7)

func setWeather(i):
	var w = Level.worldsByTeamId[targeted_team_id].find_child("WeatherSystem")
	if w:
		w.enabled = true
		w.synchronizer.network_rpc(w.update_weather.bind(i, randi()), true)

func _on_SpawnResourceSlider_value_changed(value):
	find_child("SpawnIronButton").text = str(value) + " iron"
	find_child("SpawnWaterButton").text = str(value) + " water"
	find_child("SpawnSandButton").text = str(value) + " cobalt"

func _on_SpawnIronButton_pressed():
	spawnResource(CONST.IRON)

func _on_SpawnWaterButton_pressed():
	spawnResource(CONST.WATER)

func _on_SpawnSandButton_pressed():
	spawnResource(CONST.SAND)

func spawnResource(type: String, amount: = -1):
	if amount == -1:
		amount = find_child("SpawnResourceSlider").value
	for keeper in Keepers.getAll():
		if targeted_team_id != keeper.teamId:
			continue

		for _i in range(0, amount):
			Level.drops.network_spawn({
				"type": type, 
				"position": keeper.global_position, 
				"impulse": Vector2(0, 40).rotated(randf() * TAU), 
				"team": keeper.teamId
			})

func _on_SpawnGadget_pressed():
	spawnResource(CONST.GADGET, 1)

func _on_SpawnSupplement_pressed():
	spawnResource(CONST.POWERCORE, 1)

func _on_SpawnRelic_pressed():
	spawnResource(CONST.RELIC, 1)

func _on_SpawnSeed_pressed():
	spawnResource(CONST.SEED, 1)

func _on_SpawnDrone_pressed():
	var dspc = get_tree().get_nodes_in_group(targeted_team_id + "-dronedispatcher")
	if dspc.size() > 0:
		dspc[0].spawnDrone()
	else:
		Logger.error("Drones can only be spawned when a dispatcher is present in the level (DroneYard, DroneCave)")

func _on_SpawnEgg_pressed():
	spawnResource(CONST.EGG, 1)

func _on_SpawnTreat_pressed():
	spawnResource(CONST.TREAT, 1)

func _on_PrestigeScoreButton_pressed():
	Data.changeByInt("prestige.score", 10000)

func setWorld(i: int):
	var w = load("res://content/worlds/world" + str(i) + "/World" + str(i) + ".tscn").instantiate()
	w.showSimpson = false
	for team in Level.worldsByTeamId:
		Level.worldsByTeamId[team].get_parent().add_child(w)
		Level.worldsByTeamId[team].queue_free()
		Level.worldsByTeamId[team] = w
	Level.loadout.worldId = "world" + str(i)
	updatePaletteButtons()
	setPalette(1)

func setPalette(i: int):
	var palettes: Array = Data.gameProperties.get("palettes." + Level.loadout.worldId, [])
	Style.setPalette(str(palettes[i - 1]))

func updatePaletteButtons():
	for b in find_child("PaletteContainer").get_children():
		b.disabled = true
	var i: = 0
	var palettes: Array = Data.gameProperties.get("palettes." + Level.loadout.worldId, [])
	for p in palettes:
		find_child("PaletteContainer").get_child(i).disabled = false
		i += 1

func _on_WaveAmbienceButton_pressed():
	GameWorld.forceBattleAmbienceEnabled = find_child("WaveAmbienceButton").button_pressed

func _on_UnlockAllButton_pressed():
	for a in ["dome2", "keeper2", "orchard", "orchard-battle2", "repellent", "repellent-battle2", "repellent-battle3", "shield-battle2", "shield-battle3", "prestige", CONST.MODE_PRESTIGE_PROVOCATION, CONST.MODE_PRESTIGE_COUNTDOWN, "world2", "world3", "world4", "world5", CONST.MAP_MEDIUM, CONST.MAP_LARGE, CONST.MAP_HUGE]:
		GameWorld.unlockElement(a)

func _on_DeleteLocalSave_pressed():
	SaveGame.deleteAllMetaState()

func _on_ResetAchievementsButton_pressed():
	Platform.resetAllStatsAndAchievements()

func _on_RelicBombButton_pressed():
	await get_tree().create_timer(2.0).timeout
	var bomb = load("res://content/gadgets/cobaltbomb/CobaltBomb.tscn").instantiate()
	bomb.teamId = "team1"
	Level.viewports.addElement(bomb)

func _on_ShowTileData_pressed():
	Level.map.toggleTileDataVisibility()

func _on_OrphanButton_pressed():
	PanelContainer.print_orphan_nodes()

func setTargetFPS(fps: int):
	Engine.max_fps = fps

func _on_SaveMapButton_pressed():
	ResourceSaver.save(Level.map.getTileData().pack(), "res://content/map/data/TileDataCurrent.tscn")

func _on_SpawnEyesButton_pressed():
	Level.map.find_child("Critters").spawnEyes(true)

func _on_SpawnWormButton_pressed():
	Level.map.find_child("Critters").spawnWorm(true)

func _on_SpawnRatButton_pressed():
	Level.map.find_child("Critters").spawnRat(true)

func _on_SpawnRoachButton_pressed():
	Level.map.find_child("Critters").spawnRoach(true)

func _on_ButtonViewRange1_pressed():
	Data.apply("map.revealdistance", 1)

func _on_ButtonViewRange2_pressed():
	Data.apply("map.revealdistance", 2)

	Level.map.tileCoordsToReveal.append(Vector2(0, -1))
	Level.map.floodRevealTiles(true)
	Level.map.removeAllEmptyBorderTilesVisually()

func _on_EnableCheatDetectionButton_pressed():
	GameWorld.runCheatDetection = find_child("EnableCheatDetectionButton").button_pressed

func _on_CopySeedIDButton_pressed():
	DisplayServer.clipboard_set(str(Level.levelSeed))

func _on_LockSeedButton_pressed():
	if find_child("LockSeedButton").button_pressed:
		find_child("LockSeedButton").text = "Unlock Seed"
		GameWorld.devState["lockedSeed"] = Level.levelSeed
	else:
		find_child("LockSeedButton").text = "Lock Seed"
		if GameWorld.devState.has("lockedSeed"):
			GameWorld.devState.erase("lockedSeed")

	var save = FileAccess.open(SaveGame.DEV_STATE_FILE, FileAccess.ModeFlags.WRITE)
	if save != null:
		save.store_string(JSON.stringify(GameWorld.devState))
		save.close()
	else:
		Logger.error("GameWorld.devState", "Failed to save dev state file with error code " + str(FileAccess.get_open_error()))

func _on_LoadSeedButton_pressed():
	var newSeedString: String = find_child("SeedLineEdit").text
	if newSeedString.is_valid_int():
		Level.setSeed(int(newSeedString))
	else:
		Level.setSeed(newSeedString.hash())
	var newLoadout: Loadout = Level.loadout.duplicate()
	newLoadout.worldId = ""
	newLoadout.palette = ""
	var startData = LevelStartData.new()
	startData.loadout = newLoadout
	StageManager.startStage("stages/landing/landing", [startData])

func _on_StopRecordingButton_pressed():
	Recorder.finishRecording()

func _on_ControlWaveIndexSlider_value_changed(value):
	value = int(value)
	find_child("ControlWaveIndex").text = str(value)
	find_child("ControlIron").text = str(round(CONTROL_IRON[value]))
	find_child("ControlWeight").text = str(round(CONTROL_WEIGHT[value]))


func _on_ControlOverrideButton_pressed():
	Data.apply(targeted_team_id + ".monsters.cycle", float(find_child("ControlWaveIndex").text))
	Data.apply(targeted_team_id + ".inventory." + CONST.IRON, int(find_child("ControlIron").text))
	if Level.mode.get("runWeightOverride"):
		Level.mode.runWeightOverride = int(find_child("ControlWeight").text)

		find_child("OverrideStatus").text = "(override ACTIVE)"
	else:
		find_child("OverrideStatus").text = "(override impossible)"



func _on_WeightOverrideResetButton_pressed():
	if Level.mode.get("runWeightOverride"):
		Level.mode.runWeightOverride = -1

		find_child("OverrideStatus").text = "(override inactive)"
	else:
		find_child("OverrideStatus").text = "(override impossible)"

func _on_ClearAllTilesButton_pressed():
	for i in 400:
		var t: = []
		for x in range(-100, 100):
			for y in range(0, 300):
				t.append(Vector2(x, y))
		Level.map.freeTiles(t)
		for d in get_tree().get_nodes_in_group("drops"):
			Level.map.drop_system.network_free_drop(d.UID)
		await get_tree().process_frame



	find_child("ButtonTempDigging").button_pressed = true
	_on_ButtonTempDigging_pressed()
	_on_ButtonGameSpeed_pressed(4)
	_on_ButtonCam6x_pressed()

func _on_ClearDrops_pressed():
	for d in get_tree().get_nodes_in_group("drops"):
		d.queue_free()


func _on_ButterMode_pressed():
	find_child("ButterMode").text = "butter mode" if find_child("ButterMode").button_pressed else "butter mode OFF"
	if find_child("ButterMode").button_pressed:
		for k in Keepers.getAll():
			var bmn = preload("res://content/keeper/DebugAutoDestructionArea.tscn").instantiate()
			k.add_child(bmn)
	else:
		for bmn in get_tree().get_nodes_in_group("debug_butter_mode_node"):
			bmn.queue_free()


func _on_spawn_cave_bomb_pressed():
	for keeper in Keepers.getAll():
		var drop = preload("res://content/caves/bombcave/CaveBomb.tscn").instantiate()
		drop.position = keeper.global_position
		keeper.attachCarry(drop)
		Level.map.call_deferred("addDrop", drop)

func _on_remove_all_drops_pressed() -> void :
	for d in get_tree().get_nodes_in_group("drops"):
		d.queue_free()

var disable_gui: = true
func _on_button_toggle_gui_pressed():

	for keeper in Keepers.getAll():
		if disable_gui:
			Level.stage.hideGUI()
		else:
			Level.stage.showGUI()
	disable_gui = not disable_gui


func _on_button_teleport_top_pressed():
	for x in Keepers.getAll():
		x.teleport(Vector2.ZERO)

func _on_run_time_minus_pressed():
	GameWorld.runTime = max(0.0, GameWorld.runTime - 60.0)

func _on_run_time_plus_pressed():
	GameWorld.runTime += 60.0


func _on_button_reveal_distance_2_pressed() -> void :
	Data.apply("map.revealdistance", 2)
	Level.map.tileCoordsToReveal.append(Vector2(0, -1))
	Level.map.floodRevealTiles(true)


func toggle_collision_shape_visibility() -> void :
	var tree: = get_tree()
	tree.debug_collisions_hint = not tree.debug_collisions_hint



	var node_stack: Array[Node] = [tree.get_root()]
	while not node_stack.is_empty():
		var node: Node = node_stack.pop_back()
		if is_instance_valid(node):
			if node is CollisionShape2D or node is CollisionPolygon2D:
				node.queue_redraw()
			if node is TileMap:
				node.collision_visibility_mode = TileMap.VISIBILITY_MODE_FORCE_HIDE
				node.collision_visibility_mode = TileMap.VISIBILITY_MODE_DEFAULT
			node_stack.append_array(node.get_children())


func _on_options_update_window_pressed():
	print("Options Update Window Mode")
	Options.updateWindowMode()

func _on_options_borderless_true_pressed():
	get_window().borderless = true

func _on_options_borderless_false_pressed():
	get_window().borderless = false

func _on_options_windowed_pressed():
	get_window().mode = Window.MODE_WINDOWED

func _on_options_maximized_pressed():
	get_window().mode = Window.MODE_MAXIMIZED

func _on_options_fullscreen_pressed():
	get_window().mode = Window.MODE_FULLSCREEN

func _on_options_fullscreen_exclusive_pressed():
	get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN

func _on_strip_mine_button_pressed() -> void :
	var strips: = []
	for x in [-12, -9, -6, -3, 0, 3, 6, 9, 12]:
		strips.append([])
		for y in range(0, 60):
			strips[-1].append(Vector2(x, y))
	for y in 20:
		strips.append([])
		for x in range(-12, 12):
			strips[-1].append(Vector2(x, y * 3))
	for i in 3:
		for strip in strips:
			while Level.map.freeTiles(strip) > 0:
				await get_tree().process_frame
		await await get_tree().process_frame

func _on_team_1_pressed() -> void :
	targeted_team_id = "team1"
	update_gadget_list_disabled()

func _on_team_2_pressed() -> void :
	targeted_team_id = "team2"
	update_gadget_list_disabled()
