extends Node

signal upgradeBought(id: String, teamId: String, playerId: String)
signal upgradeError(id: String, teamId: String, playerId: String)
signal upgradeAdded(id: String, teamId: String)

signal chamberIdsReceived

signal elementUnlocked


const TILE_SIZE: = 24
const HALF_TILE_SIZE: = 12
const HALF_TILE_DIAGONAL = 17
var worldEnv: WorldEnvironment = null


var buildType: int
var devMode: bool
var dataDebug: bool = false
var devModeActivated: bool = false
var qaOptions: bool
var unlockAllButton: bool
var resetBetweenRuns: bool
var forceBattleAmbienceEnabled: bool
var runCheatDetection: bool = true
var forcePlayfab: = false
var useRandomPort: = false


var tutorialStages: = {}
var assignmentProgress: = {}
var version: String
var version_sha: String
var lastVersion: String = ""
var runCount: int
var lastLoadoutsByMode: Dictionary = {}
var clientLastLoadoutsByMode: Dictionary = {}
var isFirstTimePlaying: bool
var fixedIpJoin: String = ""

var lastWorldIds: Array
var lastLeaderboardSection: String
var lastLeaderboardMultiplayer: String
var lastHostMode: String
var showMouse: = true
var gadgetToKeep: String
var keptGadgetUsed: = false
var isMultiplayerLoadout: bool

var useCustomGadgetOrderSetting: bool
var useCustomGadgetOrder: bool
var customGadgetOrder: Array
var useCustomSupplementOrderSetting: bool
var useCustomSupplementOrder: bool
var customSupplementOrder: Array
var useCustomCaveOrderSetting: bool
var useCustomCaveOrder: bool
var customCaveOrder: Array
var autoMoveCameraInMineView: = true
var usedAssigmentsGadgets: = {}
var assignmentRewardStatus: = {}
var lastChosenAssignmentDifficulty: = {}
var lastUploadedAssignmentScore: = -1
var goalCameraZoomLoadout: float
var figuredOutMovementInLoadout: bool

var ostKeeperId: String


var lastViewedOptionsCategory: String
var lastFocussedTechId: String
var runStats: = {}
var clientRunStatsSet: = false
var runTime: float
var paused: = false
var achievementStats: = {}


var softPauseCached: = {}
var cachedTimeBetweenWaves: = {}
var won: = false
var lost: = false
var gameover: = false
var runStarted: = false
var isHalloween: = false
var isAprilFools: = false
var isLunarNewYear: = false
var isChristmas: = false
var loadCount: = 0
var newSkinsToUnlock: = []
var runModifiersToUnlock: = []
var devState: = {}
var runId: String = ""
var sessionId: String
var notifyKeybindingsReset: = false
var notifyDamagedMetaFile: = false
var notifyAllMetaFileDamaged: = false
var trackedDamageDealtByTeamId: = {}
var trackedDamageReceivedByTeamId: = {}
var addedGadgetIds: Dictionary = {}

var leaderboardHandles: = {}


var cycleSpeed: float


var additionalRunWeight: = 0.0


var musicCountdown: int
var currentMusicIndex: int


var availableTechSlots: = []
var upgrades: = {}
var upgradeLimits: = []
var boughtUpgrades: = []
var lockedUpgrades: = []
var _clientUpgradePending: = false


var unlockedElements: = []
var unlockableElements: = []
var unlockedPets: = []
var unlockablePets: = []
var unlockedRunModifiers: = []
var unlockedSkins: = {}
var unlockedAssignments: = []
var unlockedRewards: = []

var unlocks: Unlocks


var chamberCoordToId: = {}


signal savegame_loaded

func _init():
	TranslationServer.set_locale("en_US")
	unlocks = Unlocks.new()
	add_child(unlocks)

func init() -> void :
	unlockedAssignments = Data.baseAssignments.duplicate()
	unlockedRewards = Data.baseGuildRewards.duplicate()

	SaveGame.loadRollingMetaState()
	if GameWorld.notifyDamagedMetaFile && GameWorld.notifyAllMetaFileDamaged:
		print("recognized all meta files damaged")
		StageManager.startStage("stages/saveerror/SaveError")
		return
	SaveGame.loadTutorialStages()
	sessionId = UUID.v4()

	match buildType:
		CONST.BUILD_TYPE.PLAYTEST:
			unlockEverything()
		CONST.BUILD_TYPE.FULL:
			pass
		CONST.BUILD_TYPE.EXHIBITION:
			unlockableElements.clear()
			unlockedElements.clear()
			unlockedElements.append("repellent")
			unlockedElements.append("shield")
			unlockedElements.append("orchard")
			unlockedElements.append("dome1")
			unlockedElements.append("keeper1")
			unlockedElements.append("relichunt")
		_:
			if not unlockedElements.has("repellent"):
				unlockableElements.append("repellent")
			if not unlockedElements.has("shield"):
				unlockableElements.append("shield")
			if not unlockedElements.has("dome2"):
				unlockableElements.append("dome2")
			if not unlockedElements.has("dome3"):
				unlockableElements.append("dome3")
			if not unlockedElements.has("keeper2"):
				unlockableElements.append("keeper2")

	updateSeasonalEvents()
	Achievements.checkAchievementsAndUnlocks()

	for modToInit in get_tree().get_nodes_in_group("mod_init"):
		modToInit.modInit()

	unlocks.update()
	elementUnlocked.connect(on_element_unlocked)

func _process(delta: float) -> void :
	if Level.stage and not paused:
		runTime += delta
		for team in Level.teams:
			if multiplayer.is_server():
				if Data.of(team + ".monsters.wavepresent"):
					Data.changeByInt(team + ".monsters.wavePresentTime", delta)
				if Data.of(team + ".monsters.wavedelay") <= 0.0 and Data.ofOr(team + ".monsters.waveCooldown", 1.0) > 0.0 and runStarted:
					Data.changeByInt(team + ".monsters.gameTimeWithoutDelay", delta)
			softPauseCached[team] = -1
	cachedTimeBetweenWaves.clear()

func prepareLevelStart(levelStartData: LevelStartData):


	prepareCleanData(levelStartData)

	_clientUpgradePending = false

	var keeperCountByTeam: = {}
	for dome: LoadoutDome in levelStartData.loadout.domes:
		Level.loadout.addDome(dome)
		keeperCountByTeam[dome.teamId] = 0
		setUpgradeLimitAvailable(dome.teamId + ".primaryweapon")
		setUpgradeLimitAvailable(dome.teamId + ".domehealth")
		setUpgradeLimitAvailable(dome.teamId + ".between_waves")

	for keeper: LoadoutKeeper in levelStartData.loadout.keepers:
		setUpgradeLimitAvailable(keeper.playerId + ".mining")
		setUpgradeLimitAvailable(keeper.playerId + ".carry")
		keeperCountByTeam[keeper.teamId] += 1

	for teamId in keeperCountByTeam:
		if keeperCountByTeam[teamId] > 1:
			setUpgradeLimitAvailable(teamId + ".multiplekeepers")
			Data.apply(teamId + ".dome.secondarystation", true)
		else:
			Data.apply(teamId + ".dome.secondarystation", false)

	match levelStartData.loadout.modeId:
		CONST.MODE_VERSUS:
			levelStartData.mapArchetype = preload("res://content/map/generation/archetypes/versus.tres").duplicate()
			prepareRegularLevelStart(levelStartData)
			levelStartData.mapArchetype.double_dome_map = true
		CONST.MODE_COOP:
			prepareRegularLevelStart(levelStartData)
			levelStartData.mapArchetype.depth *= 1.4
			levelStartData.mapArchetype.width *= 1.3
			levelStartData.mapArchetype.gadget_first_depth *= 1.5
			levelStartData.mapArchetype.gadget_depth_step *= 1.8
			levelStartData.mapArchetype.water_rate *= 0.9
		CONST.MODE_RELICHUNT:
			prepareRegularLevelStart(levelStartData)
		CONST.MODE_ASSIGNMENTS:
			var assignmentId = levelStartData.loadout.modeConfig.get(CONST.MODE_CONFIG_ASSIGNMENT)
			if not Data.assignments.has(assignmentId):
				Logger.info("unknown assignment, falling back", "GameWorld.prepareLevelStart", assignmentId)
				assignmentId = Data.assignments.keys().front()
			var assignment: Assignment = Data.assignments.get(assignmentId)

			useCustomCaveOrder = false
			useCustomGadgetOrder = false
			useCustomSupplementOrder = false
			var isChallengeMode = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_ASSIGNMENT_CHALLENGE_MODE, false)
			Data.apply("assignment.id", assignment.id)
			Data.apply("assignment.challengemode", isChallengeMode)

			if assignment.worldId:
				levelStartData.loadout.worldId = assignment.worldId
			else:
				if not levelStartData.loadout.worldId:
					levelStartData.loadout.worldId = getNextRandomWorldId()
				Data.apply("monsters.allowedtypes", Data.gameProperties.get("monstersbyworld." + levelStartData.loadout.worldId))

			for propertyChange: PropertyChange in assignment.propertyChanges:
				propertyChange.apply("team1")

			if isChallengeMode:
				for propertyChange: PropertyChange in assignment.challengePropertyChanges:
					propertyChange.apply("team1")


			for keeper in levelStartData.loadout.keepers.size() - 1:
				for propertyChange: PropertyChange in assignment.multiplayerModifier:
					propertyChange.apply("team1")

			setUpgradeLimitAvailable("team1.wavemeter")
			for limit: String in assignment.upgradeLimits:
				if not isUpgradeLimitAvailable("team1." + limit):
					setUpgradeLimitAvailable("team1." + limit)

			if assignment.mapArchetype:
				levelStartData.mapArchetype = load("res://content/map/generation/archetypes/" + assignment.mapArchetype + ".tres").duplicate()
			else:
				levelStartData.mapArchetype = preload("res://content/map/generation/archetypes/assignment-default.tres").duplicate()

			levelStartData.loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS] = assignment.worldModifiers
			prepareWorldModifiers(levelStartData)
			if assignment.goaltype == "relic":
				levelStartData.mapArchetype.relics = 1
			else:
				levelStartData.mapArchetype.relics = 0
		CONST.MODE_PRESTIGE:
			useCustomCaveOrder = useCustomCaveOrderSetting
			useCustomGadgetOrder = useCustomGadgetOrderSetting
			useCustomSupplementOrder = useCustomSupplementOrderSetting

			setUpgradeLimitAvailable("team1.wavemeter")
			setUpgradeLimitAvailable("team1.prestige")
			match levelStartData.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT):
				CONST.MODE_PRESTIGE_MINER:
					setUpgradeLimitAvailable("team1." + CONST.MODE_PRESTIGE_MINER)
					upgradeLimits.erase("team1.domehealth")
				CONST.MODE_PRESTIGE_PROVOCATION:
					setUpgradeLimitAvailable("team1.hostile")
					setUpgradeLimitAvailable("team1.wavemeter")
					setUpgradeLimitAvailable("team1.domehealth")
					setUpgradeLimitAvailable("team1." + CONST.MODE_PRESTIGE_PROVOCATION)
				CONST.MODE_PRESTIGE_COUNTDOWN:
					setUpgradeLimitAvailable("team1.hostile")
					setUpgradeLimitAvailable("team1.wavemeter")
					setUpgradeLimitAvailable("team1.domehealth")
					setUpgradeLimitAvailable("team1." + CONST.MODE_PRESTIGE_COUNTDOWN)
				CONST.MODE_PRESTIGE_ENDLESS:
					levelStartData.mapArchetype = preload("res://content/map/generation/archetypes/prestige-20k.tres").duplicate()
					setUpgradeLimitAvailable("team1.hostile")
					setUpgradeLimitAvailable("team1.wavemeter")
					setUpgradeLimitAvailable("team1.domehealth")
					setUpgradeLimitAvailable("team1." + CONST.MODE_PRESTIGE_ENDLESS)

			if not levelStartData.mapArchetype:
				levelStartData.mapArchetype = preload("res://content/map/generation/archetypes/prestige-10k.tres").duplicate()
			Data.apply("monsters.allowedtypes", Data.gameProperties.get("monstersbyworld.world6"))
			Data.apply("runID", randi())

			if isUnlocked(CONST.MODE_PRESTIGE_PRO):
				setUpgradeLimitAvailable("team1." + CONST.MODE_PRESTIGE_PRO)

			levelStartData.loadout.worldId = "world6"
		CONST.MODE_COLONIZATION:
			if not levelStartData.mapArchetype:
				levelStartData.mapArchetype = preload("res://content/map/generation/archetypes/regular-small.tres").duplicate()
				levelStartData.mapArchetype.cobalt_rate = 0.0
		_:
			Logger.info("unknown game mode", "GameWorld.prepareLevelStart", levelStartData.loadout.modeId)


	for gameMode in get_tree().get_nodes_in_group("gamemodes-prepare"):
		gameMode.prepareGameMode(levelStartData.loadout.modeId, levelStartData)

	for id in assignmentRewardStatus:
		if unlocks.get_reward_status(id) == 2:
			for dome in levelStartData.loadout.domes:
				addUpgrade(id, dome.teamId)

	if levelStartData.loadout.palette == "":
		var palettes: Array = Data.gameProperties.get("palettes." + levelStartData.loadout.worldId, [])
		var paletteName: String = str(palettes[Level.levelSeed % palettes.size()])
		levelStartData.loadout.palette = paletteName


	var supplementMaxCount: = 1
	if assignmentRewardStatus.get("rewardweaponsupplements", 0) == 2:
		supplementMaxCount += 1


	if assignmentRewardStatus.get("rewardkeepersupplements", 0) == 2:
		supplementMaxCount += 1
	if assignmentRewardStatus.get("rewardgadgetsupplements", 0) == 2:
		supplementMaxCount += 5
	levelStartData.mapArchetype.powercores = min(levelStartData.mapArchetype.powercores, supplementMaxCount)

	Level.loadout = levelStartData.loadout
	Audio.updateTrackList()

	prepareUnlockables()

	runCount += 1

	SaveGame.saveRollingMetaState()

	runId = UUID.v4()
	Backend.event("run_started", {
		"loadout": levelStartData.loadout.serialize(), 
		"runCount": runCount, 
		"unlockedElements": unlockedElements, 
		"release": (buildType == CONST.BUILD_TYPE.FULL and not qaOptions and not devMode), 
	})

func prepareRegularLevelStart(levelStartData: LevelStartData):
	useCustomCaveOrder = false
	useCustomGadgetOrder = false
	useCustomSupplementOrder = false

	for dome in levelStartData.loadout.domes:
		setUpgradeLimitAvailable(dome.teamId + ".hostile")
		setUpgradeLimitAvailable(dome.teamId + ".wavemeter")

	if not levelStartData.mapArchetype:
		var archetypeName: String = levelStartData.loadout.modeConfig.get(CONST.MODE_CONFIG_MAP_ARCHETYPE, "regular-medium")
		levelStartData.mapArchetype = load("res://content/map/generation/archetypes/" + archetypeName + ".tres").duplicate()
	levelStartData.mapArchetype.cobalt_rate *= 1.0 - 0.1 * levelStartData.loadout.difficultyByTeamId.get("map", 0)


	var player_counts: = {}
	var max_players: = 0
	for keeper: LoadoutKeeper in levelStartData.loadout.keepers:
		player_counts[keeper.teamId] = 1 + player_counts.get(keeper.teamId, 0)
		max_players = max(max_players, player_counts[keeper.teamId])
	if max_players > 1:
		var mod = clamp((max_players - 1) * 0.15, 0, 0.5)
		levelStartData.mapArchetype.max_tile_count_deviation += mod
		levelStartData.mapArchetype.tileCount *= 1.0 + mod
		levelStartData.mapArchetype.width *= 1.0 + mod * 0.6
		levelStartData.mapArchetype.depth *= 1.0 + mod * 1.2
		levelStartData.mapArchetype.first_biome_size *= 1.0 + mod * 2.0
		levelStartData.mapArchetype.biome_max_size *= 1.0 + mod
		levelStartData.mapArchetype.biome_size_multiplier *= 1.0 + mod * 0.5
		levelStartData.mapArchetype.biome_size_addition *= 1.0 + mod

	if not levelStartData.loadout.worldId or levelStartData.loadout.worldId == "":
		levelStartData.loadout.worldId = getNextRandomWorldId()
		Data.apply("monsters.allowedtypes", Data.gameProperties.get("monstersbyworld." + levelStartData.loadout.worldId))

	prepareWorldModifiers(levelStartData)

func getNextRandomWorldId() -> String:
	var worlds: = ["world1", "world2", "world3", "world4", "world5", "world7"]
	for w in worlds.duplicate():
		if not GameWorld.isUnlocked(w):
			worlds.erase(w)
	if worlds.size() > 1:
		if worlds.size() > GameWorld.lastWorldIds.size():
			for w in GameWorld.lastWorldIds:
				worlds.erase(w)
		else:
			var lastWorld = GameWorld.lastWorldIds.back()
			GameWorld.lastWorldIds.clear()
			GameWorld.lastWorldIds.append(lastWorld)
			worlds.erase(lastWorld)
	var worldId = "world1" if worlds.size() == 0 else worlds[randi() % worlds.size()]
	GameWorld.lastWorldIds.append(worldId)
	return worldId

func prepareWorldModifiers(levelStartData: LevelStartData):
	for modifierId in levelStartData.loadout.modeConfig.get(CONST.MODE_CONFIG_WORLDMODIFIERS, []):
		var modifier = Data.worldModifiers[modifierId] if Data.worldModifiers.has(modifierId) else Data.versusModifiers[modifierId]
		for propertyChange: PropertyChange in modifier.get("propertychanges", {}):
			if levelStartData.mapArchetype and propertyChange.keyClass == "archetype":
				if propertyChange.value is String and propertyChange.value.begins_with("res://"):
					levelStartData.mapArchetype.set(propertyChange.keyName, load(propertyChange.value))
				else:
					var oldValue = levelStartData.mapArchetype.get(propertyChange.keyName)
					var newValue = propertyChange.getChangedValue(oldValue)
					levelStartData.mapArchetype.set(propertyChange.keyName, newValue)
			else:
				if propertyChange.keyClass == "resourcemodifiers":
					Data.applyPropertyChange(propertyChange)
				elif propertyChange.keyClass == "world":
					Data.applyPropertyChange(propertyChange)
				else:
					for dome in levelStartData.loadout.domes:
						Data.applyPropertyChange(propertyChange.instanced(dome.teamId))


		for upgradeId in modifier.get("upgrades", {}):
			if Data.upgrades.has(upgradeId):
				for teamId in Level.teams:
					addUpgrade(upgradeId, teamId)


		for dome in levelStartData.loadout.domes:
			for slot in modifier.get("addslots", []):
				availableTechSlots.append(dome.teamId + "." + slot)
			for limit in modifier.get("upgradelimits", []):
				setUpgradeLimitAvailable(dome.teamId + "." + limit)
			for eraseLimit in modifier.get("eraseupgradelimits", []):
				if not ["mining", "carry"].has(eraseLimit):
					removeAvailableUpgradeLimit(dome.teamId + "." + eraseLimit)


		for lk: LoadoutKeeper in levelStartData.loadout.keepers:
			for eraseLimit in modifier.get("eraseupgradelimits", []):
				if ["mining", "carry"].has(eraseLimit):
					removeAvailableUpgradeLimit(lk.playerId + "." + eraseLimit)

		var globalAreaOverrides = modifier.get("globalareaoverrides", {})
		for areaOverride in globalAreaOverrides:
			levelStartData.loadout.globalAreaOverrides[areaOverride] = globalAreaOverrides[areaOverride]

func levelInitialized():
	if multiplayer.is_server():
		for teamId in Level.teams:
			Data.apply(teamId + ".dome.health", Data.of(teamId + ".dome.maxHealth"))

			if GameWorld.devMode:
				Data.apply(teamId + ".inventory.iron", 500)
				Data.apply(teamId + ".inventory.water", 50)
				Data.apply(teamId + ".inventory.sand", 20)



	var unlocked: = false
	for uk in Data.upgrades:
		if unlocked:
			break
		for pd in Data.upgrades[uk].get("predecessors", []):
			if pd == Level.loadout.modeId:
				for teamId in Level.teams:
					addUpgrade(Level.loadout.modeId, teamId)
				unlocked = true
				break


	for teamId in Level.teams:
		for u in unlockedElements:
			if u.find("-battle") != -1 and not upgradeLimits.has(u):
				upgradeLimits.append(teamId + "." + u)

	for teamId in Level.teams:
		updateAvailableUpgrades(teamId)


	if Level.loadout.modeId == CONST.MODE_RELICHUNT:
		for modifierId in Level.loadout.modeConfig.get(CONST.MODE_CONFIG_WORLDMODIFIERS, []):
			var modifier = Data.worldModifiers[modifierId]
			for gadgetId in modifier.get("gadgets", {}):
				if Data.gadgets.has(gadgetId):
					for teamId in Level.teams:
						addUpgrade(gadgetId, teamId)
			for upgradeId in modifier.get("upgrades", {}):
				if Data.upgrades.has(upgradeId):
					for teamId in Level.teams:
						addUpgrade(upgradeId, teamId)


	if multiplayer.is_server():
		addAssignmentRewardUpgrades()
	elif not Network.upgrades_set.is_connected(addAssignmentRewardUpgrades):
		Network.upgrades_set.connect(addAssignmentRewardUpgrades, CONNECT_ONE_SHOT)

	prepareUnlockables()

	if Level.mode:
		Level.mode.afterInitialized()

func addAssignmentRewardUpgrades() -> void :
	for id in assignmentRewardStatus:
		if unlocks.get_reward_status(id) == 2:
			for upgradeId in Data.rewards.get(id, {}).get("upgrades", []):
				if Data.upgrades.has(upgradeId):
					var upgrade: Dictionary = Data.upgrades[upgradeId]
					upgrade = Data.deepDuplicateUpgrade(upgrade)
					for teamId in Level.teams:
						Data.makeInstancedUpgrade(upgrade, teamId)
						if isUpgradeLimited(upgrade):
							continue
						addUpgrade(upgradeId, teamId)

func updateAvailableUpgrades(teamId: String):
	var potentialUpgrades: = {}
	for uk in Data.upgrades:
		var key = uk
		if teamId != "":
			key = teamId + "." + key
		if not upgrades.has(key):
			var upgrade: Dictionary = Data.upgrades[uk]
			upgrade = Data.deepDuplicateUpgrade(upgrade)
			Data.makeInstancedUpgrade(upgrade, teamId)
			Data.asKeeperGadgetUpgrade(upgrade, teamId)
			if not isUpgradeLimited(upgrade):
				potentialUpgrades[key] = upgrade

	var safeguard: = 1000
	while true:
		safeguard -= 1
		if safeguard <= 0:
			Logger.error("GameWorld.updateAvailableUpgrades", "Safeguard for upgrade calculation triggered. Something is wrong.")
			break

		var keysToAdd: = []
		for uk in potentialUpgrades:
			var upgrade = potentialUpgrades[uk]
			if upgrade["tier"] == 0:
				if uk in boughtUpgrades:
					keysToAdd.append(uk)

				continue

			var missingPredecessors = upgrade.get("predecessors", []).size()
			if missingPredecessors > 0 and upgrade.get("predecessorsany", false):
				missingPredecessors = 1

			for predecessor in upgrade.get("predecessors", []):
				if upgrades.has(predecessor):
					missingPredecessors -= 1
			if missingPredecessors <= 0:
				keysToAdd.append(uk)



		if keysToAdd.is_empty():
			break
		else:
			for uk in keysToAdd:
				upgrades[uk] = potentialUpgrades[uk]
				potentialUpgrades.erase(uk)
			keysToAdd.clear()


	for uk in upgrades.duplicate():
		if upgrades[uk].has("predecessors"):
			var predecessors = upgrades[uk].get("predecessors")
			for p in predecessors.duplicate():



				var idsToCheck: = [p]
				var split = p.split(".")
				for keeper in Keepers.getAllOfTeam(teamId):
					idsToCheck.append(keeper.playerId + "." + split[1])
				var hasAtLeastOne: = false
				for id in idsToCheck:
					if upgrades.has(id):
						hasAtLeastOne = true
						break

				if not hasAtLeastOne and not upgrades[uk].get("keepunavailablepredecessors", false):
					predecessors.erase(p)
			if predecessors.size() == 0 and upgrades[uk]["tier"] > 0:

				upgrades.erase(uk)


	for uk in upgrades:
		if upgrades[uk].has("predecessors"):
			var predecessors = upgrades[uk].get("predecessors")
			for pk in predecessors:
				if upgrades.has(pk):
					var predecessor = upgrades[pk]
					var successors = predecessor.get("successors", [])
					successors.append(uk)
					predecessor["successors"] = successors

func prepareCleanData(inLevelStartData: LevelStartData = null):
	Level.teams.clear()

	var hasStartData: bool = is_instance_valid(inLevelStartData)
	var domes: Array = inLevelStartData.loadout.domes if hasStartData else Level.loadout.domes
	for dome: LoadoutDome in domes:
		Level.teams.append(dome.teamId)

	if multiplayer.is_server():
		Data.reset()
		for teamId in Level.teams:
			Data.apply(teamId + ".dome.mainweapons", 1)
			Data.apply(teamId + ".dome.secondarystation", false)
			Data.apply(teamId + ".dome.secondaryweapon", false)
			Data.apply(teamId + ".dome.health", 0)
			Data.apply(teamId + ".dome.maxhealth", 0)
			Data.apply(teamId + ".dome.baserepair", 0)
			Data.apply(teamId + ".dome.healthfractionrepair", 0)
			Data.apply(teamId + ".dome.meleedamagereduction", 0.0)
			Data.apply(teamId + ".dome.projectiledamagereduction", 0.0)
			Data.apply(teamId + ".dome.autohealdamagethreshold", 0.0)
			Data.apply(teamId + ".dome.autohealamount", 0.0)
			Data.apply(teamId + ".dome.meleethorndamage", 0.0)
			Data.apply(teamId + ".dome.resurrectcharges", 0.0)
			Data.apply(teamId + ".dome.reducedhealth", 0.0)
			Data.apply(teamId + ".dome.healthbar", 0)
			Data.apply(teamId + ".dome.invulnerabletime", 0)
			Data.apply(teamId + ".dome.incomingdamagemodifier", 1.0)
			Data.apply(teamId + ".dome.healthlocked", false)
			Data.apply(teamId + ".wavemeter.showcounter", false)
			Data.apply(teamId + ".wavemeter.warner", false)
			Data.apply(teamId + ".wavemeter.pathtodome", false)

			Data.apply(teamId + ".monsters.wavepresent", false)
			Data.apply(teamId + ".monsters.wavebattle", false)
			Data.apply(teamId + ".monsters.wavedelay", 0)
			Data.apply(teamId + ".monstermodifiers.punishers", true)
			Data.apply(teamId + ".monsters.cycle", 0)
			Data.apply(teamId + ".monsters.additionalcycletime", 0)
			Data.apply(teamId + ".monsters.maximumTimingModAtRunWeight", 500)
			Data.apply(teamId + ".monsters.finalwavefixedstrength", 0)
			Data.apply(teamId + ".monsters.antistall", true)
			Data.apply(teamId + ".monsters.gameTimeWithoutDelay", 0)
			Data.apply(teamId + ".monsters.wavePresentTime", 0)

			Data.apply(teamId + ".inventory.iron", 0)
			Data.apply(teamId + ".inventory.water", 0)
			Data.apply(teamId + ".inventory.sand", 0)
			Data.apply(teamId + ".inventory.gadget", 0)
			Data.apply(teamId + ".inventory.powercore", 0)
			Data.apply(teamId + ".inventory.relic", 0)
			Data.apply(teamId + ".inventory.rest", 0)
			Data.apply("inventory.totalIron", 0)
			Data.apply("inventory.totalWater", 0)
			Data.apply("inventory.totalSand", 0)
			Data.apply("inventory.totalgadget", 0)
			Data.apply("inventory.totalpowercore", 0)
			Data.apply("inventory.totalrelic", 0)
			Data.apply("inventory.totalegg", 0)
			Data.apply("inventory.totalrest", 0)

			Data.apply(teamId + ".monstermodifiers.cyclesrunweightmodifier", 1.0)
			Data.apply(teamId + ".monstermodifiers.totalrunweightmodifier", 1.0)
			Data.apply(teamId + ".monstermodifiers.move_speed", 1.0)
			Data.apply(teamId + ".monstermodifiers.damagetaken", 1.0)
			Data.apply(teamId + ".monstermodifiers.health", 1.0)
			Data.apply(teamId + ".monstermodifiers.projectilespeed", 1.0)

			Data.apply(teamId + ".artifacts.gadgetChoicesPerArtifact", 2)
			Data.apply(teamId + ".artifacts.supplementChoicesPerArtifact", 2)

			Data.apply(teamId + ".gadgetselection.freererolls", 0)

		Data.apply("inventory.floatingIron", 0)
		Data.apply("inventory.floatingWater", 0)
		Data.apply("inventory.floatingSand", 0)
		Data.apply("inventory.floatinggadget", 0)
		Data.apply("inventory.floatingpowercore", 0)
		Data.apply("inventory.floatingrelic", 0)
		Data.apply("inventory.floatingegg", 0)
		Data.apply("inventory.floatingrest", 0)

		Data.apply("postrun.showmine", true)
		Data.apply("postrun.miningtimelapse", true)

		Data.apply("map.revealdistance", 1)
		Data.apply("map.ironrichness", 2)
		Data.apply("map.cobaltrichness", 2)
		Data.apply("map.waterrichness", 2.5)
		Data.apply("map.tileHealthMultiplierPerLayer", 2.1)

		Data.apply("upgrademodifiers.cost.iron", 1.0)

		Data.apply("game.over", "")


		Data.apply("team1.game.cyclespeed", 1.0)

	Keepers.isSplitScreen = true

	runStats.clear()
	achievementStats.clear()
	clientRunStatsSet = false
	trackedDamageDealtByTeamId.clear()
	trackedDamageReceivedByTeamId.clear()
	for teamId in Level.teams:
		GameWorld.trackedDamageDealtByTeamId[teamId] = {}
		GameWorld.trackedDamageReceivedByTeamId[teamId] = {}

	boughtUpgrades.clear()
	lockedUpgrades.clear()
	if resetBetweenRuns:
		resetTutorials()
	upgradeLimits.clear()
	upgrades.clear()
	newSkinsToUnlock.clear()
	availableTechSlots.clear()
	addedGadgetIds.clear()

	won = false
	lost = false
	gameover = false
	runStarted = false
	paused = false
	SaveGame.allow_saving = true
	musicCountdown = 1
	runTime = 0.0
	cycleSpeed = 1.0

func resetTutorials():
	tutorialStages.clear()
	SaveGame.persistTutorialStages()

func isUnlocked(id: String) -> bool:
	return unlockedElements.has(id)

func unlockElement(id: String) -> String:
	if isUnlocked(id):
		return ""
	else:
		unlockedElements.append(id)
		unlockableElements.erase(id)
		elementUnlocked.emit()
		return id

func addUnlockableElementIfOk(id: String):
	if isUnlocked(id):
		return
	if not unlockableElements.has(id):
		unlockableElements.append(id)

func prepareUnlockables():
	unlockableElements.clear()

	var openDomes: = []

	for domeId in ["dome2", "dome2", "dome3", "dome3", "dome4"]:
		if not isUnlocked(domeId):
			openDomes.append(domeId)
	if openDomes.size() > 0:
		unlockableElements.append(openDomes[randi() % openDomes.size()])

	addUnlockableElementIfOk("keeper2")

	match Level.loadout.modeId:
		CONST.MODE_RELICHUNT:
			addUnlockableElementIfOk(CONST.MODE_PRESTIGE)
		CONST.MODE_PRESTIGE:
			var openModes: = []
			for mode in [CONST.MODE_PRESTIGE_PROVOCATION, CONST.MODE_PRESTIGE_MINER, CONST.MODE_PRESTIGE_ENDLESS]:
				if not isUnlocked(mode):
					openModes.append(mode)
			if openModes.size() > 0:
				unlockableElements.append(openModes[randi() % openModes.size()])

	var openPrimarygadgets: = []
	for gadgetId in ["repellent", "orchard", "droneyard"]:
		if not isUnlocked(gadgetId):
			openPrimarygadgets.append(gadgetId)
	if openPrimarygadgets.size() > 0:
		unlockableElements.append(openPrimarygadgets[randi() % openPrimarygadgets.size()])

	match Level.loadout.domes.front().primaryGadgetId:
		"repellent":
			addUnlockableElementIfOk("orchard")
			if isUnlocked("repellent-battle2"):
				addUnlockableElementIfOk("repellent-battle3")
			else:
				addUnlockableElementIfOk("repellent-battle2")
		"shield":
			addUnlockableElementIfOk("repellent")
			if isUnlocked("shield-battle2"):
				addUnlockableElementIfOk("shield-battle3")
			else:
				addUnlockableElementIfOk("shield-battle2")
		"orchard":
			addUnlockableElementIfOk("orchard-battle2")
		"droneyard":
			if isUnlocked("droneyard-battle2"):
				addUnlockableElementIfOk("droneyard-battle3")
			else:
				addUnlockableElementIfOk("droneyard-battle2")

	unlockablePets = ["pet1"]
	if Platform.purchased_keeper_dlc():
		unlockablePets.append("pet9")
	for keeperLoadout in Level.loadout.keepers:
		match keeperLoadout.keeperId:
			"keeper1":
				unlockablePets.append("pet2")
			"keeper2":
				unlockablePets.append("pet6")
			"keeper3":
				if Platform.purchased_keeper_dlc():
					unlockablePets.append("pet10")
			"keeper4":
				if Platform.purchased_keeper_dlc():
					unlockablePets.append("pet13")
	if isHalloween:
		unlockablePets.append("pet4")
	for p in unlockedPets:
		unlockablePets.erase(p)

func updateSeasonalEvents():
	if not Options.enableSeasonalContent:
		isHalloween = false
		isAprilFools = false
		isChristmas = false
		isLunarNewYear = false
		return

	var date = Time.get_date_dict_from_system()
	isHalloween = (date["month"] == 10 and date["day"] >= 21) or (date["month"] == 11 and date["day"] <= 10)
	isAprilFools = date["month"] == 4
	isChristmas = date["month"] == 12 and date["day"] >= 1
	isLunarNewYear = date["month"] == 1 and date["day"] >= 28 or (date["month"] == 2 and date["day"] <= 10)

func nextUnlock(id: String):
	match id:
		"world1":
			return "world2"
		"world2":
			return "world3"
		"world3":
			return "world4"
		"world4":
			return "world5"
		"world5":
			return "world7"
		CONST.MAP_SMALL:
			return CONST.MAP_MEDIUM
		CONST.MAP_MEDIUM:
			return CONST.MAP_LARGE
		CONST.MAP_LARGE:
			return CONST.MAP_HUGE
		_:
			return null

func unlockEverything():
	GameWorld.unlockElement("keeper2")
	GameWorld.unlockElement("keeper3")
	GameWorld.unlockElement("keeper4")
	GameWorld.unlockElement("repellent-battle2")
	GameWorld.unlockElement("repellent-battle3")
	GameWorld.unlockElement("orchard-battle2")
	GameWorld.unlockElement("shield-battle2")
	GameWorld.unlockElement("shield-battle3")
	GameWorld.unlockElement("droneyard-battle2")
	GameWorld.unlockElement("droneyard-battle3")
	GameWorld.unlockElement("world1")
	GameWorld.unlockElement("world2")
	GameWorld.unlockElement("world3")
	GameWorld.unlockElement("world4")
	GameWorld.unlockElement("world5")
	GameWorld.unlockElement("world7")
	GameWorld.unlockElement(CONST.MODE_ASSIGNMENTS)
	GameWorld.unlockElement(CONST.MODE_RELICHUNT)
	GameWorld.unlockElement(CONST.MODE_PRESTIGE)
	GameWorld.unlockElement(CONST.MODE_PRESTIGE_COUNTDOWN)
	GameWorld.unlockElement(CONST.MODE_PRESTIGE_PROVOCATION)
	GameWorld.unlockElement(CONST.MODE_PRESTIGE_ENDLESS)
	GameWorld.unlockElement(CONST.MODE_PRESTIGE_MINER)
	GameWorld.unlockElement(CONST.MODE_PRESTIGE_PRO)
	GameWorld.unlockElement(CONST.MODE_VERSUS)
	GameWorld.unlockElement(CONST.MAP_MEDIUM)
	GameWorld.unlockElement(CONST.MAP_LARGE)
	GameWorld.unlockElement(CONST.MAP_HUGE)
	GameWorld.unlockElement(CONST.DIFFICULTY_YAFI)
	GameWorld.unlockElement(CONST.MODE_VERSUS)
	GameWorld.unlockedRunModifiers = Data.RUN_MODIFIERS.duplicate()
	for assignmentId in Data.assignments:
		GameWorld.assignmentProgress[assignmentId] = GameWorld.assignmentProgress.get(assignmentId, 1)
	for reward in Data.rewards:
		setAssignmentRewardStatus(reward, 2)
	for id in Data.gadgets:
		unlockElement(id)
	for gadget in Data.gadgets:
		if Data.gadgets[gadget].get("type", "") == "gadget" and not isUnlocked(gadget):
			unlockElement(gadget)
	for assignmentId in Data.keeperDlcAssignments:
		unlockAssignment(assignmentId)
	for rewardId in Data.keeperDlcGuildRewards:
		unlockReward(rewardId)

	GameWorld.unlockedSkins["keeper1"] = ["skin1", "skin2", "skin3", "skin4", "skin5"]
	GameWorld.unlockedSkins["keeper2"] = ["skin1", "skin2", "skin3", "skin4", "skin5"]
	GameWorld.unlockedSkins["keeper3"] = ["skin1", "skin2", "skin3"]
	GameWorld.unlockedSkins["keeper4"] = ["skin1", "skin2", "skin3", "skin4", "skin5"]
	GameWorld.unlockedPets = ["pet1", "pet2", "pet3", "pet4", "pet5", "pet6", "pet7", "pet8", "pet9", "pet10", "pet11", "pet12", "pet13"]
	unlocks.update()

func canAfford(costs: Dictionary, teamId: String) -> bool:
	for costType in costs:
		if Data.of(teamId + ".inventory." + costType) < costs[costType]:
			return false
	return true

func buyUpgrade(id: String, teamId: String, playerId: String):
	var domeRepairUpgrade: bool = id.find("domesandrepair") > -1
	var domeHealth = Data.of(teamId + ".dome.health")
	var maxHealth = Data.of(teamId + ".dome.maxHealth")
	var canRepair: bool = domeHealth < maxHealth
	if domeRepairUpgrade and ( not canRepair):
		return


	if multiplayer.is_server():
		if requestUpgrade(id, teamId):
			serverAddUpgrade(id, teamId)
			upgradeBought.emit(id, teamId, playerId)
			upgradeAdded.emit(id, teamId)
		else:
			upgradeError.emit(id, teamId, playerId)
	elif not _clientUpgradePending:
		_clientUpgradePending = true
		remoteBuyUpgrade.rpc_id(1, id, teamId, playerId)

@rpc("reliable", "any_peer")
func remoteBuyUpgrade(id: String, teamId: String, playerId: String) -> void :

	if requestUpgrade(id, teamId):
		serverAddUpgrade(id, teamId)
		remoteUpgradeBought.rpc_id(multiplayer.get_remote_sender_id(), id, teamId, playerId)
	else:
		remoteUpgradeError.rpc_id(multiplayer.get_remote_sender_id(), id, teamId, playerId)

@rpc("reliable")
func remoteUpgradeBought(id: String, teamId: String, playerId: String) -> void :
	_clientUpgradePending = false
	upgradeBought.emit(id, teamId, playerId)

func serverAddUpgrade(id: String, teamId: String) -> void :
	GameWorld.addUpgrade(id, teamId)
	upgradeAdded.emit(id, teamId)

	Data.synchronizer.manual_tick()

	Network.rpc_for_states(remoteAddUpgrade.bind(id, teamId), [
		Network.ConnectionState.LOADOUT_STAGE_SYNC, 
		Network.ConnectionState.LEVEL_STAGE_SYNC
	])

@rpc("reliable")
func remoteAddUpgrade(id: String, teamId: String) -> void :
	addUpgrade(id, teamId)
	upgradeAdded.emit(id, teamId)

@rpc("reliable")
func remoteUpgradeError(id: String, teamId: String, playerId: String) -> void :
	_clientUpgradePending = false
	upgradeError.emit(id, teamId, playerId)

func requestUpgrade(id: String, teamId: String) -> bool:
	var upgrade = GameWorld.upgrades.get(id)
	if upgrade == null or not GameWorld.canAfford(upgrade.get("cost", {}), teamId):
		return false

	var cost = upgrade.get("cost", {})
	for costType in cost:
		Data.changeByInt(teamId + ".inventory." + costType, - cost[costType])

	return true

func isUpgradeAddable(upgradeId, team: String = "") -> bool:
	var upgrade = GameWorld.upgrades.get(upgradeId, Data.deepDuplicateUpgrade(Data.gadgets.get(upgradeId, {})))
	if not team.is_empty():
		for slotIdx: int in upgrade.takeslots.size():
			var slotVal: String = upgrade.takeslots[slotIdx]
			if ["keepersuit", "keepersupplement"].has(slotVal):
				upgrade.takeslots[slotIdx] = "player1." + slotVal
			else:
				upgrade.takeslots[slotIdx] = team + "." + slotVal

	if (boughtUpgrades.has(upgradeId) and not upgrade.has("repeatable")) or lockedUpgrades.has(upgradeId):
		return false

	if not areUpgradeSlotsAvailable(upgrade):
		return false

	if upgrade.has("predecessors"):

		var count = 0
		var predecessors = upgrade.get("predecessors")
		for predecessor_upgradeId in predecessors:
			if GameWorld.boughtUpgrades.has(predecessor_upgradeId):
				count += 1
			else:
				var otherUp = GameWorld.upgrades.get(predecessor_upgradeId)
				if otherUp and otherUp.has("repeatable"):
					if isUpgradeAddable(predecessor_upgradeId):
						count += 1
					elif not upgrade.get("predecessorsany", false):
						count -= 1

		if upgrade.get("predecessorsany", false) and count > 0:
			return true
		elif count == predecessors.size():
			return true
		else:
			return false

	return true

func unlockSkin(keeperId: String, skinId: String):
	var skins = unlockedSkins.get(keeperId, [])
	if not skins.has(skinId):
		skins.append(skinId)
	unlockedSkins[keeperId] = skins

func removeSkin(keeperId: String, skinId: String):
	var skins = unlockedSkins.get(keeperId, [])
	skins.erase(skinId)

func unlockPet(petId: String):
	if not unlockedPets.has(petId):
		unlockedPets.append(petId)

func unlockAssignment(assignmentId: String):
	if not unlockedAssignments.has(assignmentId):
		unlockedAssignments.append(assignmentId)

func unlockReward(rewardId: String):
	if not unlockedRewards.has(rewardId):
		unlockedRewards.append(rewardId)

func isAssignmentUnlocked(assignmentId: String) -> bool:
	return unlockedAssignments.has(assignmentId)

func lockReward(rewardId: String):
	unlockedRewards.erase(rewardId)
	if assignmentRewardStatus.has(rewardId) and assignmentRewardStatus[rewardId] == RewardChoice.RewardStatus.ENABLED:
		assignmentRewardStatus[rewardId] = RewardChoice.RewardStatus.UNLOCKED

func addUpgrade(id: String, teamOrPlayerId: String = "") -> Dictionary:
	var createdScenes: Dictionary = {}
	var upgradeData: Dictionary
	var wasAlreadyPresent: = false
	var perPlayer: = ""




	var keeperAlreadyPresent: = false
	if StageManager.isInLevel() and StageManager.currentStage.presentPlayerIds.has(teamOrPlayerId) and id.begins_with("keeper") and teamOrPlayerId.begins_with("player") and not Keepers.hasKeeper(teamOrPlayerId):
		for keeper in Level.loadout.keeperTemplates:
			if keeper.playerId == teamOrPlayerId:
				keeperAlreadyPresent = true
				break



	var idToCheck: = id
	if not id.begins_with("player") and not id.begins_with("team") and teamOrPlayerId != "":
		idToCheck = teamOrPlayerId + "." + id

	if upgrades.has(idToCheck):
		upgradeData = upgrades.get(idToCheck)
		wasAlreadyPresent = true
	elif Data.gadgets.has(id):
		upgradeData = Data.deepDuplicateUpgrade(Data.gadgets.get(id))
	elif Data.supplements.has(id):
		upgradeData = Data.deepDuplicateUpgrade(Data.supplements.get(id))
	elif Data.rewards.has(id):
		upgradeData = Data.deepDuplicateUpgrade(Data.rewards.get(id))
	elif id.count(".") > 0:
		var id_team_id: String = id.substr(0, id.find("."))
		var base_id = id.substr(id.find(".") + 1)
		if id_team_id == teamOrPlayerId:
			id = base_id
			upgradeData = Data.upgrades.get(base_id).duplicate()
		elif id.begins_with("player"):
			perPlayer = extractPlayerIdFromItemId(id)
			upgradeData = Data.upgrades.get(base_id).duplicate()
		else:
			Logger.error("trying to add an upgrade where the passed team %s differs from the prefix %s in the upgrade id" % [id_team_id, teamOrPlayerId], "GameWorld.addUpgrade")
			return {}
	elif teamOrPlayerId != "" and Data.upgrades.has(id):
		upgradeData = Data.upgrades.get(id).duplicate()
	else:
		Logger.error("cannot add unknown upgrade or tech", "GameWorld.addUpgrade", {"id": id})
		return createdScenes

	if teamOrPlayerId != "" and not wasAlreadyPresent:
		if id.find(".") == -1:
			id = teamOrPlayerId + "." + id
		if not boughtUpgrades.has(id):
			upgradeData = Data.deepDuplicateUpgrade(upgradeData)
			if perPlayer != "":
				Data.asKeeperGadget(upgradeData, perPlayer)

			if _isKeeperGadgetSupplement(upgradeData):


				Data.removeAvailableTechSlotsForSupplement(upgradeData, perPlayer)
				Data.asKeeperGadgetSupplement(upgradeData, perPlayer)

			if perPlayer != "" and upgradeData["type"] == "supplement" and _isKeepersuitSupplement(upgradeData):

				Data.makeInstancedUpgrade(upgradeData, perPlayer)
			else:
				Data.makeInstancedUpgrade(upgradeData, teamOrPlayerId)

			upgrades[id] = upgradeData
	else:
		id = upgradeData["id"]
		upgrades[id] = upgradeData






	var otherPlayerOnTeamHasKeeperSuitUpgrade: = false
	if id.contains("."):
		var split: = id.split(".")
		if split[0].contains("player") and Data.upgrades[split[1]].get("takeslots", []).has("keepersuit"):
			for keeper in Keepers.getAllOfTeam(teamOrPlayerId):
				if boughtUpgrades.has(keeper.playerId + "." + split[1]):
					otherPlayerOnTeamHasKeeperSuitUpgrade = true
					break

	if not boughtUpgrades.has(id):

		boughtUpgrades.append(id)

		for limit in upgradeData.get("unlockslimits", []):
			setUpgradeLimitAvailable(limit)

		for l in upgradeData.get("locks", []):
			lockUpgrade(l)


		for slot in upgradeData.get("addslots", []):
			availableTechSlots.append(slot)


		for slot in upgradeData.get("takeslots", []):


			if otherPlayerOnTeamHasKeeperSuitUpgrade and slot.begins_with("team"):
				continue
			availableTechSlots.erase(slot)
		upgradeData.erase("takeslots")


	if multiplayer.is_server() and not keeperAlreadyPresent and not otherPlayerOnTeamHasKeeperSuitUpgrade:
		for propertyChange in upgradeData.get("propertychanges", []):
			Data.applyPropertyChange(propertyChange)

	var scenes = upgradeData.get("scenes", {})
	for slot in scenes:
		var instance
		var scene = load("res://" + scenes[slot])
		if scene:
			if slot == "hud":
				if perPlayer.is_empty():
					if id.begins_with("player") and id.find(".") > 0:
						perPlayer = extractPlayerIdFromItemId(id)
				Level.addHudElement(scene, teamOrPlayerId if perPlayer == "" else perPlayer)
			else:
				instance = scene.instantiate()
		else:
			Logger.error("scene of tech does not exist", "GameWorld.addUpgrade", upgradeData)
			return createdScenes

		createdScenes[slot] = instance

		match slot:
			"hud":
				pass
			"keeper":
				Level.stage.addKeeper(instance)
			"dome":
				instance.name = "%sDome" % teamOrPlayerId
				Level.stage.addDome(instance, teamOrPlayerId)
			"keepersuit":
				trackAdditionalGadget(id, teamOrPlayerId)
				perPlayer = perPlayer if perPlayer != "" else extractPlayerIdFromItemId(id)
				if perPlayer == "":
					if Keepers.hasKeeper(teamOrPlayerId):
						Keepers.getKeeper(teamOrPlayerId).addAddition(instance)
					elif Keepers.hasTeam(teamOrPlayerId):
						Keepers.getAllOfTeam(teamOrPlayerId).front().addAddition(instance)
				elif Keepers.hasKeeper(perPlayer):
					Keepers.getKeeper(perPlayer).addAddition(instance)
			"primarygadget":
				var dome = Level.domesByTeamId.get(teamOrPlayerId)
				if dome:
					dome.addGadget(instance, teamOrPlayerId, slot)
			"cellar":
				trackAdditionalGadget(id, teamOrPlayerId)
				var dome = Level.domesByTeamId[teamOrPlayerId]
				dome.addGadget(instance, teamOrPlayerId, slot)
			"domesurface":
				trackAdditionalGadget(id, teamOrPlayerId)
				var dome = Level.domesByTeamId[teamOrPlayerId]
				dome.addGadget(instance, teamOrPlayerId, slot)
			"domebackside":
				trackAdditionalGadget(id, teamOrPlayerId)
				var dome = Level.domesByTeamId[teamOrPlayerId]
				dome.addGadget(instance, teamOrPlayerId, slot)
			"mineshaft":
				trackAdditionalGadget(id, teamOrPlayerId)
				Level.map.addMineShaftGadget(instance, teamOrPlayerId)
			_:
				Logger.error("cannot apply tech, unknown scene target location", "GameWorld.addUpgrade", {"gadgetId": id, "sceneLocation": slot})


	if not SaveGame.currentLoadingSavegame:
		for change in upgradeData.get("repeatable", []):
			match change.keyClass:
				"times":
					change.value -= 1
				"cost":
					var oldValue = upgradeData["cost"].get(change.keyName, 0)
					var newValue = round(change.getChangedValue(oldValue))
					upgradeData["cost"][change.keyName] = newValue
				"maxcost":
					var oldValue = upgradeData["cost"].get(change.keyName, 0)
					var newValue = min(oldValue, change.value)
					upgradeData["cost"][change.keyName] = newValue
				"property":
					for p in upgradeData.get("propertychanges", []):
						if p.key.ends_with(change.keyName):
							var newValue = change.getChangedValue(p.value)
							if typeof(p.value) == TYPE_INT:
								p.value = round(newValue)
							else:
								p.value = newValue

	updateAvailableUpgrades(teamOrPlayerId)

	return createdScenes

func extractPlayerIdFromItemId(itemId: String) -> String:
	if itemId.begins_with("player"):
		return itemId.substr(0, itemId.find("."))
	return ""

func trackAdditionalGadget(id: String, teamId: String) -> void :
	if not addedGadgetIds.has(teamId):
		addedGadgetIds[teamId] = []
	if not addedGadgetIds[teamId].has(id):
		addedGadgetIds[teamId].append(id)

func lockUpgrade(uk):

	lockedUpgrades.append(uk)
	var lockedSomething: = true
	while lockedSomething:
		lockedSomething = false
		for u in GameWorld.upgrades:
			if u in boughtUpgrades or u in lockedUpgrades:
				continue

			if GameWorld.upgrades[u].has("predecessors"):
				var t = GameWorld.upgrades[u].get("predecessors")
				if lockedUpgrades.has(t):
					lockedUpgrades.append(u)
					lockedSomething = true

func setUpgradeLimitAvailable(limit: String):
	if upgradeLimits.has(limit):
		Logger.error("trying to add a tech limit that's already available", "GameWorld.setUpgradeLimitAvailable", limit)
		return
	upgradeLimits.append(limit)

func removeAvailableUpgradeLimit(limit: String):
	if not upgradeLimits.has(limit):
		Logger.error("trying to remove a tech limit that's not available", "GameWorld.removeAvailableUpgradeLimit", limit)
		return
	upgradeLimits.erase(limit)

func isUpgradeLimitAvailable(limit: String) -> bool:
	return upgradeLimits.has(limit)

func isUpgradeLimited(upgrade: Dictionary, ignoreSelf: = false) -> bool:
	return isUpgradeLimitedBy(upgrade, upgradeLimits, ignoreSelf)

func isUpgradeLimitedBy(upgrade: Dictionary, limits: Array, ignoreSelf: = false) -> bool:
	if upgrade.has("limit"):
		for limit in upgrade["limit"]:
			if not limits.has(limit) and not (ignoreSelf and limit == upgrade["id"]):
				return true
	if upgrade.has("excludelimit"):
		for limit in upgrade["excludelimit"]:
			if limits.has(limit) and not (ignoreSelf and limit == upgrade["id"]):
				return true
	return false

func areUpgradeSlotsAvailable(upgrade: Dictionary) -> bool:
	for slot in upgrade.get("takeslots", []):
		if not availableTechSlots.has(slot):
			return false
	return true

func isPetUnlockable() -> bool:
	var mapSize = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_MAP_ARCHETYPE, CONST.MAP_SMALL)
	var mapOk = mapSize != CONST.MAP_SMALL
	var modeOK = Level.loadout.modeId == CONST.MODE_RELICHUNT



	var up: = []
	for pet in unlockablePets:
		if not unlockedPets.has(pet):
			up.append(pet)
	var petUnlockable = up.size() > 0

	return mapOk and modeOK and petUnlockable

func getAvailableGadgetIds(teamId: String, playerId: String) -> Array[String]:
	var availableGadgetIds: Array[String] = []

	for gk in Data.gadgets:
		var data = Data.deepDuplicateUpgrade(Data.gadgets[gk])

		modifyUpgradeDataForGadgetPopup(data, teamId, playerId)

		var upgradeId: String = data["id"]
		if not isUpgradeLimited(data)\
		and areUpgradeSlotsAvailable(data)\
		and data.get("type", "") == "gadget"\
		and not boughtUpgrades.has(upgradeId):
			availableGadgetIds.append(upgradeId)

	return availableGadgetIds

func getAvailableSupplementIds(teamId: String, playerId: String) -> Array[String]:
	var availableSupplementIds: Array[String] = []

	for supplementId in Data.supplements:
		var data = Data.deepDuplicateUpgrade(Data.supplements[supplementId])
		modifyUpgradeDataForSupplementPopup(data, teamId, playerId)

		var upgradeId: String = data["id"]
		if not boughtUpgrades.has(supplementId)\
		and areUpgradeSlotsAvailable(data)\
		and not isUpgradeLimited(data, true):
			availableSupplementIds.append(upgradeId)
	return availableSupplementIds

func modifyUpgradeDataForSupplementPopup(data: Dictionary, teamId: String, playerId: String) -> void :
	var isKeepersuitSupplement: bool = _isKeepersuitSupplement(data)
	var isKeeperGadgetSupplement: = _isKeeperGadgetSupplement(data)

	if isKeepersuitSupplement:
		Data.asKeeperGadget(data, playerId)
		Data.makeInstancedUpgrade(data, playerId)
	else:
		if isKeeperGadgetSupplement:
			Data.asKeeperGadget(data, playerId)
			Data.asKeeperGadgetSupplement(data, playerId)
		Data.makeInstancedUpgrade(data, teamId)

func modifyUpgradeDataForGadgetPopup(data: Dictionary, teamId: String, playerId: String) -> void :
	var asKeeperGadget: bool = data.get("takeslots", []).has("keepersuit")
	Data.makeInstancedUpgrade(data, teamId)
	if asKeeperGadget:
		Data.asKeeperGadget(data, playerId)

func getAvailableArtifactIds(artifactType: String, teamId: String, playerId: String) -> Array[String]:
	match artifactType:
		CONST.POWERCORE:
			return GameWorld.getAvailableSupplementIds(teamId, playerId)
		CONST.GADGET:
			return GameWorld.getAvailableGadgetIds(teamId, playerId)
	push_error("Valid artifact type was not provided, so no available ids could be returned.")
	return []

func generateGadgets(teamId: String, playerId: String, excluded: Array[String] = []) -> Array[Dictionary]:
	var offer: Array[Dictionary] = []
	var availableGadgets: = []

	var order = Data.gadgets
	if useCustomGadgetOrder:
		order = customGadgetOrder


	for gk in order:
		var data = Data.deepDuplicateUpgrade(Data.gadgets[gk])

		modifyUpgradeDataForGadgetPopup(data, teamId, playerId)

		var upgradeId: String = data["id"]
		if not isUpgradeLimited(data)\
		and areUpgradeSlotsAvailable(data)\
		and not excluded.has(upgradeId)\
		and data.get("type", "") == "gadget"\
		and not boughtUpgrades.has(upgradeId):
			availableGadgets.append(data)


	if useCustomGadgetOrder:
		for x in availableGadgets:
			offer.append(x)
	else:
		while availableGadgets.size() > 0:
			var index = randi() % availableGadgets.size()
			var gadget = availableGadgets[index]
			availableGadgets.remove_at(index)
			offer.append(gadget)

	var offeredGadgetIds: = []
	for o in offer:
		offeredGadgetIds.append(o.get("id"))
	Backend.event("gadgets", {"status": "offered", "gadgets": offeredGadgetIds})
	return offer

func generateSupplements(teamId: String, playerId: String, excluded: Array[String] = []) -> Array[Dictionary]:
	var offer: Array[Dictionary] = []
	var order: Array = customSupplementOrder if useCustomSupplementOrder else Data.supplements.keys()
	var supplements: = []


	for supplementId in order:
		var data = Data.deepDuplicateUpgrade(Data.supplements[supplementId])
		modifyUpgradeDataForSupplementPopup(data, teamId, playerId)

		var upgradeId: String = data["id"]
		if not boughtUpgrades.has(upgradeId)\
		and areUpgradeSlotsAvailable(data)\
		and not excluded.has(upgradeId)\
		and not isUpgradeLimited(data, true):
			supplements.append(data)


	if useCustomSupplementOrder:
		offer.append_array(supplements)
	else:
		var lockedSlots: = []
		var overlappingSlotsSupplements: = []
		while supplements.size() > 0:
			var index = randi() % supplements.size()
			var supplement = supplements[index]
			supplements.remove_at(index)


			var valid: = true
			var takeslots = supplement.get("takeslots", [])
			for slot in takeslots:
				if lockedSlots.has(slot):
					valid = false
					break

			if valid:
				offer.append(supplement)
				lockedSlots.append_array(takeslots)
			else:
				overlappingSlotsSupplements.append(supplement)



		offer.append_array(overlappingSlotsSupplements)

	var offeredGadgetIds: = []
	for o in offer:
		offeredGadgetIds.append(o.get("id"))
	Backend.event("supplements", {"status": "offered", "supplements": offeredGadgetIds})
	return offer

func _isKeeperGadgetSupplement(data: Dictionary) -> bool:
	if data.get("type", "") != "supplement":
		return false

	for slot in data.get("takeslots"):
		if slot.find(".") != -1:
			slot = slot.split(".")[1]
		if Data.keeperSupplementSlots.has(slot):
			return true
	return false

func _isKeepersuitSupplement(data: Dictionary) -> bool:
	return data.get("type", "") == "supplement" and data.get("takeslots", []).has("keepersupplement")

func getGadgetOffer(id: String) -> Dictionary:
	var parts: = id.split(".", true, 1)
	var teamOrPlayerId: = parts[0]
	var gadgetId: = parts[1]
	if Data.gadgets.has(gadgetId):
		var data = Data.deepDuplicateUpgrade(Data.gadgets[gadgetId])
		Data.makeInstancedUpgrade(data, teamOrPlayerId)
		return data

	else:
		return {}

func getSupplementOffer(id: String) -> Dictionary:
	var parts: = id.split(".", true, 1)
	var teamOrPlayerId: = parts[0]
	var supplementId: = parts[1]
	if Data.supplements.has(supplementId):
		var data = Data.deepDuplicateUpgrade(Data.supplements[supplementId])
		Data.makeInstancedUpgrade(data, teamOrPlayerId)
		return data

	else:
		return {}

func handleGameWon(backendData: Dictionary = {}):
	if gameover:
		return

	SaveGame.delete_autosave()
	won = true
	gameover = true
	Data.apply("game.over", "won")

	Achievements.incrementStat("run_wins")

func handleGameLost(backendData: Dictionary = {}):
	if won:

		return

	SaveGame.delete_autosave()
	backendData["runTime"] = runTime
	backendData["runWeight"] = Level.mode.getRunWeight("team1")
	backendData["status"] = "lost"
	Backend.event("run_finished", backendData)
	Backend.sendBufferedEvents()
	lost = true
	gameover = true
	Data.apply("game.over", "lost")
	get_tree().call_group("lostL", "onGameLost")

	Achievements.incrementStat("run_losses")

func can_pause_game() -> bool:


	return Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SINGLEPLAYER

func pause(server_force: bool = false):
	if not can_pause_game() and not server_force:
		return

	if paused:
		return
	paused = true
	get_tree().call_group("pauseL", "pauseChanged")
	softPauseCached.clear()

func unpause():
	if not paused:
		return
	paused = false
	get_tree().call_group("pauseL", "pauseChanged")

func softPaused(teamId: String) -> bool:
	if not softPauseCached.has(teamId) or softPauseCached[teamId] == -1:
		softPauseCached[teamId] = int(paused or gameover or Data.of(teamId + ".monsters.wavebattle"))
	return bool(softPauseCached[teamId])

func incrementRunStat(type: String, teamId: String, amount = 1):
	if not teamId:
		Logger.error("TeamId should not be empty!", "GameWorld.incrementRunStat")
	type = teamId + "." + type
	runStats[type] = amount + runStats.get(type, 0)

func incrementAchievementStat(type: String, playerId: String, amount: = 1.0):
	type = playerId + "." + type
	achievementStats[type] = amount + achievementStats.get(type, 0)

func setShowMouse(showMouse: bool = true):
	if (showMouse and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE) or ( not showMouse and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN):
		return

	if showMouse and (Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER or not Options.singleplayerUseGamepad):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func iconify(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[(.*?)\\]")
	var result = regex.sub(text, "[img]res://content/icons/icon_$1.png[/img]", true)
	return result

func getTimeBetweenWaves(teamId: String) -> float:
	if cachedTimeBetweenWaves.has(teamId):
		return cachedTimeBetweenWaves[teamId]

	var v: float = Data.ofOr(teamId + ".monsters.waveinterval", Data.of("monsters.waveinterval")) + Data.of(teamId + ".monsters.additionalcycletime")
	if not can_pause_game():
		v += Data.ofOr("monsters.additionalWaveIntervalWithoutPause", 0)

	v *= 1.0 - Level.difficulty(teamId) * 0.1
	v *= Data.ofOr(teamId + ".monsters.wavetimemodifier", 1.0)

	cachedTimeBetweenWaves[teamId] = v
	return v

func getVersionPrint():
	if qaOptions or buildType == CONST.BUILD_TYPE.PLAYTEST:
		return "%s (%s)" % [version, version_sha]
	else:

		var split = version.split(".")
		if split.size() == 3:
			return split[0] + "." + split[1]
		elif split.size() == 4:
			return split[0] + "." + split[1] + "." + split[2]
		else:
			return version

func getMajorVersion() -> String:
	return version.split(".")[0].substr(1)

func handleVersionChange():
	var lastVersion: String = ""
	var save = FileAccess.open(SaveGame.VERSION_STATE_FILE, FileAccess.ModeFlags.READ)
	if save != null:
		lastVersion = save.get_as_text()
		save.close()

	isFirstTimePlaying = lastVersion == ""
	if lastVersion != version:

		Logger.info("trying migration from version '" + lastVersion + "' to '" + version + "'")

		save = FileAccess.open(SaveGame.VERSION_STATE_FILE, FileAccess.ModeFlags.WRITE)
		if save != null:
			save.store_string(version)
		save.close()

		var oldVersionParts = lastVersion.split(".")
		if oldVersionParts.size() < 3:
			return

		var majorVersion = int(oldVersionParts[0])
		var minorVersion = int(oldVersionParts[1])
		var patchVersion = int(oldVersionParts[2])

		if majorVersion == 3:
			Logger.info("Migration: Detected migration from godot3, creating backup and resetting keybindings")
			upgrade_progression_from_3_to_4()
			Options.resetKeyBindingsToDefault()
			notifyKeybindingsReset = true
		if majorVersion == 3 and minorVersion == 1 and patchVersion == 0:
			Options.loadOptions()
			Options.saveOptions(["twinStickControls"])
		if majorVersion == 4 and minorVersion == 0 and patchVersion < 2:
			figuredOutMovementInLoadout = true
		if (majorVersion < 5 and Options.hasOptionsSave())\
		or majorVersion == 5 and minorVersion == 0 and patchVersion == 0:
			Options.loadOptions()
			var keeper3_mouse_settings = KeeperInputSettings.new()
			keeper3_mouse_settings.from_dict({}, true, "keeper3")
			Options.setInputSettings("keeper3", true, keeper3_mouse_settings)

			var keeper3_gamepad_settings = KeeperInputSettings.new()
			keeper3_gamepad_settings.from_dict({}, false, "keeper3")
			Options.setInputSettings("keeper3", false, keeper3_gamepad_settings)

			Options.saveOptions(["keeperMouseSnapDirectionDegrees", "showKeeperAimIndicatorMouse", \
			"useMouseKeeperGameplay", "keeperGamepadSnapDirectionDegrees", \
			"showKeeperAimIndicatorGamepad", "twinStickControls"])

		if SaveGame.is_autosave_from_unsupported_version():
			Logger.warn("Migration: Unsupported autosave detected, creating backup and deleting")
			SaveGame.create_autosave_backup()
			SaveGame.delete_autosave()
		SaveGame.saveRollingMetaState()
	else:
		Logger.info("no new version detected")

func upgrade_progression_from_3_to_4():
	GameWorld.unlockElement(CONST.MODE_ASSIGNMENTS)
	for u: String in unlockedElements.duplicate():
		if u.begins_with("map-"):
			var new = u.replace("map", "regular")
			unlockedElements.append(new)
			unlockedElements.erase(u)

func requestActionClone(action, parent) -> Control:
	var clone = load("res://gui/buttons/Action.tscn").instantiate()
	clone.forceKeyboard = true
	clone.action = action.action
	clone.remove_from_group("gamepadListeners")
	clone.remove_from_group("keybindingListeners")
	Style.init(clone)
	action.call_deferred("add_sibling", clone)
	return clone

func getAssignmentProgress() -> int:
	var i: = 0
	for d in assignmentProgress.values():
		i += d
	return i

func sanitizeMetaState():
	for x in customCaveOrder.duplicate():
		if not Data.CAVE_SCENES.has(x):
			customCaveOrder.erase(x)

	for x in customGadgetOrder.duplicate():
		if not Data.gadgets.has(x):
			customGadgetOrder.erase(x)

	for x in customSupplementOrder.duplicate():
		if not Data.supplements.has(x):
			customSupplementOrder.erase(x)

	for x in assignmentRewardStatus.keys().duplicate():
		if not Data.rewards.has(x):
			assignmentRewardStatus.erase(x)

	for loadout: Loadout in lastLoadoutsByMode.values():
		Data.sanitizeLoadout(loadout)

	for x in unlockedRunModifiers.duplicate():
		if not Data.RUN_MODIFIERS.has(x):
			unlockedRunModifiers.erase(x)

func getUpgradeData() -> Dictionary:
	var data: Dictionary = {}
	data["upgrades"] = upgrades.duplicate(true)


	for techId in upgrades.keys():
		if upgrades[techId].has("propertychanges"):
			data["upgrades"][techId]["propertychanges"] = encode_property_changes(upgrades[techId]["propertychanges"])
		if upgrades[techId].has("repeatable"):
			data["upgrades"][techId]["repeatable"] = encode_property_changes(upgrades[techId]["repeatable"])

	data["upgradeLimits"] = upgradeLimits
	data["boughtUpgrades"] = boughtUpgrades
	data["lockedUpgrades"] = lockedUpgrades
	data["availableTechSlots"] = availableTechSlots

	return data

func setUpgradeData(upgradeData: Dictionary) -> void :
	upgrades = upgradeData["upgrades"]


	for techId in upgrades.keys():
		if upgrades[techId].has("propertychanges"):
			upgrades[techId]["propertychanges"] = decode_property_changes(upgrades[techId]["propertychanges"])
		if upgrades[techId].has("repeatable"):
			upgrades[techId]["repeatable"] = decode_property_changes(upgrades[techId]["repeatable"])

	upgradeLimits = upgradeData["upgradeLimits"]
	boughtUpgrades = upgradeData["boughtUpgrades"]
	lockedUpgrades = upgradeData["lockedUpgrades"]
	availableTechSlots = upgradeData["availableTechSlots"]

static func encode_property_changes(changes: Array) -> Array:
	var encoded: = Array()
	for change: PropertyChange in changes:
		encoded.append(change.source)
		encoded.append(change.value)

	return encoded

static func decode_property_changes(sourcesAndValues: Array) -> Array:
	var decoded: Array = []
	var i: = 0
	var currentPropertyChange: PropertyChange
	for sourceOrValue in sourcesAndValues:
		if i % 2 == 0:
			currentPropertyChange = PropertyChange.new(sourceOrValue)
		else:
			currentPropertyChange.value = sourceOrValue
			decoded.append(currentPropertyChange)
		i += 1

	return decoded

func registerChamberId(coord: Vector2, id: int) -> void :
	chamberCoordToId[coord] = id

func getChamberIds() -> Dictionary:
	return chamberCoordToId

func setChamberIds(chamberIds: Dictionary) -> void :
	chamberCoordToId = chamberIds
	chamberIdsReceived.emit()

func is_coop() -> bool:
	return Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER\
	and Level.loadout.modeId != CONST.MODE_VERSUS

func isSplitScreen() -> bool:
	return Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SPLITSCREEN or (Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER and Options.enableSplitScreen)

func getEffectiveLoadoutZoom() -> float:
	if Keepers.isSplitScreen:
		return goalCameraZoomLoadout * Options.splitscreen_font_scale
	return goalCameraZoomLoadout

func is_crossplay_enabled() -> bool:
	if BuildCustomization.has_feature("system_crossplay_option"):
		return forcePlayfab or Platform.is_crossplay_enabled()
	return Options.enableCrossplay

func is_allowOnlineMultiplayer() -> bool:
	return Options.allowOnlineMultiplayer or BuildCustomization.has_feature("disable_allow_online_option")


func is_current_stage_level_stage() -> bool:
	return Level.stage is LevelStage

func serializeCustomSettings() -> Dictionary:
	var data: = {}
	data["useCustomCaveOrderSetting"] = useCustomCaveOrderSetting
	data["useCustomCaveOrder"] = useCustomCaveOrder
	data["customCaveOrder"] = customCaveOrder

	data["useCustomGadgetOrderSetting"] = useCustomGadgetOrderSetting
	data["useCustomGadgetOrder"] = useCustomGadgetOrder
	data["customGadgetOrder"] = customGadgetOrder

	data["useCustomSupplementOrderSetting"] = useCustomSupplementOrderSetting
	data["useCustomSupplementOrder"] = useCustomSupplementOrder
	data["customSupplementOrder"] = customSupplementOrder

	return data

func deserializeCustomSettings(data: Dictionary) -> void :
	useCustomCaveOrderSetting = data["useCustomCaveOrderSetting"]
	useCustomCaveOrder = data["useCustomCaveOrder"]
	customCaveOrder = data["customCaveOrder"]

	useCustomGadgetOrderSetting = data["useCustomGadgetOrderSetting"]
	useCustomGadgetOrder = data["useCustomGadgetOrder"]
	customGadgetOrder = data["customGadgetOrder"]

	useCustomSupplementOrderSetting = data["useCustomSupplementOrderSetting"]
	useCustomSupplementOrder = data["useCustomSupplementOrder"]
	customSupplementOrder = data["customSupplementOrder"]

func update_pioneer_pack(pioneerPack: bool):
	if pioneerPack:
		if not GameWorld.unlockedPets.has("pet3"):
			GameWorld.unlockedPets.append("pet3")
		GameWorld.unlockSkin("keeper1", "skin1")
	else:
		if GameWorld.unlockedPets.has("pet3"):
			GameWorld.unlockedPets.erase("pet3")
		var skins = GameWorld.unlockedSkins.get("keeper1", [])
		if skins.has("skin1"):
			skins.erase("skin1")

func update_assessor_booster(assessorBooster: bool):
	if assessorBooster:
		if not GameWorld.unlockedPets.has("pet5"):
			GameWorld.unlockedPets.append("pet5")
		GameWorld.unlockSkin("keeper2", "skin1")
	else:
		if GameWorld.unlockedPets.has("pet5"):
			GameWorld.unlockedPets.erase("pet5")
		var skins = GameWorld.unlockedSkins.get("keeper2", [])
		if skins.has("skin1"):
			skins.erase("skin1")

func update_keeper_dlc(keeperDlc: bool):
	if keeperDlc:
		unlockElement("keeper3")
		unlockElement("keeper4")
		Options.includeInputGroup("keeper3")
		Options.includeInputGroup("keeper4")

		GameWorld.unlockSkin("keeper1", "skin4")
		GameWorld.unlockSkin("keeper2", "skin4")
		GameWorld.unlockSkin("keeper3", "skin0")
		GameWorld.unlockSkin("keeper4", "skin0")

		unlockPet("pet11")

		for assignmentId in Data.keeperDlcAssignments:
			unlockAssignment(assignmentId)

		for rewardId in Data.keeperDlcGuildRewards:
			unlockReward(rewardId)
	else:
		for dlcKeeper in Data.dlcKeepers:
			unlockedElements.erase(dlcKeeper)
		for keeperDlcPet in Data.keeperDlcPeets:
			unlockedPets.erase(keeperDlcPet)

		GameWorld.removeSkin("keeper1", "skin4")
		GameWorld.removeSkin("keeper1", "skin5")
		GameWorld.removeSkin("keeper2", "skin4")
		GameWorld.removeSkin("keeper2", "skin5")
		GameWorld.removeSkin("keeper3", "skin0")
		GameWorld.removeSkin("keeper3", "skin1")
		GameWorld.removeSkin("keeper3", "skin2")
		GameWorld.removeSkin("keeper3", "skin3")
		GameWorld.removeSkin("keeper4", "skin0")
		GameWorld.removeSkin("keeper4", "skin1")
		GameWorld.removeSkin("keeper4", "skin2")
		GameWorld.removeSkin("keeper4", "skin3")
		GameWorld.removeSkin("keeper4", "skin4")
		GameWorld.removeSkin("keeper4", "skin5")

		GameWorld.unlockedPets.erase("pet9")
		GameWorld.unlockedPets.erase("pet10")
		GameWorld.unlockedPets.erase("pet11")
		GameWorld.unlockedPets.erase("pet12")
		GameWorld.unlockedPets.erase("pet13")

		for assignmentId in Data.keeperDlcAssignments:
			unlockedAssignments.erase(assignmentId)

		for rewardId in Data.keeperDlcGuildRewards:
			lockReward(rewardId)

func run_stats_to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_u8(Level.teams.size())
	for teamId in Level.teams:
		stream.encode_var(GameWorld.runStats[teamId + ".time"])
		stream.encode_var(GameWorld.runStats[teamId + ".travelled_distance"])
		var is_relic_mode: bool = Level.loadout.modeId == CONST.MODE_RELICHUNT
		stream.encode_bool(is_relic_mode)
		if is_relic_mode:
			stream.encode_var(GameWorld.runStats[teamId + ".mapsize"])
			stream.encode_var(GameWorld.runStats[teamId + ".difficulty"])
		stream.encode_float(GameWorld.runStats.get(teamId + ".monsters_killed", 0.0))
		stream.encode_u32(GameWorld.runStats.get(teamId + ".waves_survived", 0))
		stream.encode_u32(GameWorld.runStats.get(teamId + ".resources_mined", 0))
		stream.encode_u32(GameWorld.runStats.get(teamId + ".tiles_destroyed", 0))

	return stream.data

func run_stats_from_bytes(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	var teamCount: = stream.decode_u8()
	for i in range(teamCount):
		var teamId: = Utils.decode_team_id(i + 1)
		GameWorld.runStats[teamId + ".time"] = stream.decode_var()
		GameWorld.runStats[teamId + ".travelled_distance"] = stream.decode_var()
		var is_relic_mode: = stream.decode_bool()
		if is_relic_mode:
			GameWorld.runStats[teamId + ".mapsize"] = stream.decode_var()
			GameWorld.runStats[teamId + ".difficulty"] = stream.decode_var()
		GameWorld.runStats[teamId + ".monsters_killed"] = stream.decode_float()
		GameWorld.runStats[teamId + ".waves_survived"] = stream.decode_u32()
		GameWorld.runStats[teamId + ".resources_mined"] = stream.decode_u32()
		GameWorld.runStats[teamId + ".tiles_destroyed"] = stream.decode_u32()
	clientRunStatsSet = true

func setLastLoadoutsByMode(id: String, loadout: Loadout) -> void :
	if multiplayer.is_server():
		var modeId: = id
		if id.contains("prestige"):
			modeId = "prestige"

		if id != "last" and modeId != loadout.modeId:
			push_error("Prevented saving loadout with incorrect id - id: %s, loadout.modeId: %s" % [modeId, loadout.modeId])
			return
		lastLoadoutsByMode[id] = loadout
	else:
		clientLastLoadoutsByMode[id] = loadout

func getLastLoadoutsByMode(id: String) -> Loadout:
	if multiplayer.is_server():
		return lastLoadoutsByMode.get(id)
	else:
		return clientLastLoadoutsByMode.get(id)

func hasLastLoadoutsByMode(id: String) -> bool:
	if multiplayer.is_server():


		var hasLoadout: = lastLoadoutsByMode.has(id)
		var modeId: = id
		if id.contains("prestige"):
			modeId = "prestige"

		if hasLoadout and id != "last" and modeId != lastLoadoutsByMode[id].modeId:
			push_warning("Existing loadout for id %s does not match the modeId %s from the loadout it returned." % [modeId, lastLoadoutsByMode[id].modeId])
			return false
		return hasLoadout
	else:
		return clientLastLoadoutsByMode.has(id)

func getFiguredOutMovementInLoadout() -> bool:
	if Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SINGLEPLAYER:
		var loadoutKeepers = Level.loadout.getLoadoutKeepers()
		for lk: LoadoutKeeper in loadoutKeepers:
			if lk["keeperId"] == "keeper3":


				GameWorld.figuredOutMovementInLoadout = true
		return GameWorld.figuredOutMovementInLoadout
	else:
		return true

func setAssignmentRewardStatus(rewardId: String, status: int):
	assignmentRewardStatus[rewardId] = status

	if Data.rewards[rewardId].has("unlocks"):
		var unlocks = Data.rewards[rewardId].unlocks
		for unlock in unlocks:
			if unlock.begins_with("keeper"):
				var split = unlock.split(".")
				if GameWorld.assignmentRewardStatus[rewardId] == 2:
					GameWorld.unlockSkin(split[0], split[1])

			elif unlock.begins_with("pet"):
				if GameWorld.assignmentRewardStatus[rewardId] == 2:
					if not GameWorld.unlockedPets.has(unlock):
						GameWorld.unlockedPets.append(unlock)

func getPossibleAdditionalGadgets(openerIndex: int, teamId: String, limits: Array = []) -> Dictionary:

	var gadgets: = []
	for gadget in Data.gadgets:
		if Data.gadgets[gadget].get("type", "") == "gadget":
			gadgets.append(gadget)


	var additional: = []
	var i: = 0
	for choice in get_tree().get_nodes_in_group("additional-gadget-choice"):
		if i != openerIndex and choice.id != "":
			additional.append(choice.id)
		i += 1

	var available_slots: Array = []
	for dome in Level.loadout.domes:
		if dome.teamId == teamId and Data.upgrades.has(dome.domeId):
			var upgrade: Dictionary = Data.upgrades.get(dome.domeId)
			for slot in upgrade.get("addslots", []):
				available_slots.append(slot)


	if not available_slots.has("keepersuit"):
		available_slots.append("keepersuit")

	for x in additional:
		gadgets.erase(x)
		for s in Data.gadgets[x]["takeslots"]:
			available_slots.erase(s)

	var available_gadgets = gadgets.duplicate()

	for x in gadgets:
		for s in Data.gadgets[x]["takeslots"]:
			if not available_slots.has(s):
				available_gadgets.erase(x)
				break

	var is_missing_gadgets: = false
	for gadget in gadgets.duplicate():
		if not unlocks.is_unlocked(gadget):
			is_missing_gadgets = true
			gadgets.erase(gadget)
			available_gadgets.erase(gadget)

		elif limits and isUpgradeLimitedBy:
			if isUpgradeLimitedBy(Data.gadgets[gadget], limits):
				available_gadgets.erase(gadget)

	var result: = {
		"is_missing_gadgets": is_missing_gadgets, 
		"gadgets": gadgets, 
		"available_gadgets": available_gadgets
	}
	return result

func on_element_unlocked() -> void :
	if multiplayer.is_server():
		unlocks.update()
	else:
		send_unlocks_to_host()

@rpc("reliable", "any_peer")
func add_client_unlocks(buffer: PackedByteArray) -> void :
	unlocks.client_unlocks[multiplayer.get_remote_sender_id()] = bytes_to_var(buffer)
	unlocks.update()

func send_unlocks_to_host() -> void :
	var buffer: = var_to_bytes({
		"unlockedElements": unlockedElements, 
		"unlockedPets": unlockedPets, 
		"unlockedRunModifiers": unlockedRunModifiers, 
		"unlockedSkins": unlockedSkins, 
	})
	Network.rpc_server(add_client_unlocks.bind(buffer))
