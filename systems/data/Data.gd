extends Node

signal full_sync_received

@export var synchronizer: DataSynchronizer

var gameProperties: Dictionary
var upgrades: Dictionary
var gadgets: Dictionary
var supplements: Dictionary
var orderedUpgradeKeys: Array
var worldModifiers: Dictionary
var versusModifiers: Dictionary
var assignments: Dictionary
var rewards: Dictionary

var loadoutDomes: = ["dome1", "dome2", "dome3", "dome4"]
var loadoutKeepers: = ["keeper1", "keeper2", "keeper3", "keeper4"]
var loadoutGameModes: = [CONST.MODE_RELICHUNT, CONST.MODE_ASSIGNMENTS, CONST.MODE_PRESTIGE, CONST.MODE_VERSUS]
var loadoutGadgets: = ["shield", "repellent", "orchard", "droneyard"]
var loadoutPrestigeModeVariants: = [CONST.MODE_PRESTIGE_COUNTDOWN, CONST.MODE_PRESTIGE_ENDLESS, CONST.MODE_PRESTIGE_PROVOCATION, CONST.MODE_PRESTIGE_MINER]

var baseAssignments: = ["showdown", "ironcontribution", "inversegravity", "maze", "projectilehell", "denseiron", "bigmapsparseresources", "weapondefect", "heavyhitters", "superhardrockwithholes", "weakcarry", "weakwalls", "monstermasses", "rareiron", "weakmining", "cobaltcontribution"]
var baseGuildRewards: = ["rewardweaponsupplements", "rewardkeepersupplements", "rewardgadgetsupplements", "rewardpermanenthealthmeter", "rewardpermanentinventory", "rewardpermanentwavemeter", "rewardpermanentwavecount", "rewardfreerolls1", "rewardrerolloffers2", "rewardthreechoicesgadget", "rewardthreechoicessupplement", "rewardpostrunshowmonstercount", "rewardcentralmarker", "rewardautomatedweapons", "rewardfreerolls2"]


var keeperDlcAssignments: = ["minorvision", "acidrain", "treefarm", "megacreeps", "instagip", "harmfuliron", "unpredictable", "emergency", "logistics"]
var keeperDlcGuildRewards: = ["rewardkeeper1skin5", "rewardkeeper2skin5", "rewardkeeper3skin1", "rewardkeeper4skin3", "rewardpet12"]
var dlcKeepers: = ["keeper3", "keeper4"]
var keeperDlcPeets: = ["pet11"]

var values: Dictionary
var templates: Dictionary
var listeners: = {}

var recently_changed: Dictionary = {}

var DROP_TYPES: = [
	CONST.IRON, 
	CONST.WATER, 
	CONST.SAND, 
	CONST.GADGET, 
	CONST.RELIC, 
	CONST.POWERCORE, 
	CONST.SEED, 
	CONST.EGG, 
	CONST.TREAT, 
	CONST.CAVEBOMB, 
	CONST.SPORE, 
	CONST.MINE, 
	CONST.DRILLBOT, 
	CONST.EXTRACTOR, 
	CONST.TELEPORTER, 
	CONST.PACK
]

var DROP_SCENES: = {
	CONST.IRON: preload("res://content/drop/iron/IronDrop.tscn"), 
	CONST.WATER: preload("res://content/drop/water/WaterDrop.tscn"), 
	CONST.SAND: preload("res://content/drop/sand/SandDrop.tscn"), 
	CONST.GADGET: preload("res://content/drop/gadget/GadgetDrop.tscn"), 
	CONST.RELIC: preload("res://content/drop/relic/RelicDrop.tscn"), 
	CONST.POWERCORE: preload("res://content/drop/powercore/PowerCoreDrop.tscn"), 
	CONST.SEED: preload("res://content/drop/seed/Seed.tscn"), 
	CONST.EGG: preload("res://content/drop/egg/Egg.tscn"), 
	CONST.TREAT: preload("res://content/drop/treat/Treat.tscn"), 
	CONST.CAVEBOMB: preload("res://content/caves/bombcave/CaveBomb.tscn"), 
	CONST.SPORE: preload("res://content/drop/mushroomfarm/Spore.tscn"), 
	CONST.MINE: preload("res://content/gadgets/blastMining/Mine.tscn"), 
	CONST.DRILLBOT: preload("res://content/gadgets/drillbot/Drillbot.tscn"), 
	CONST.EXTRACTOR: preload("res://content/gadgets/extractor/Extractor.tscn"), 
	CONST.TELEPORTER: preload("res://content/gadgets/teleporter/Teleporter.tscn"), 
	CONST.PACK: preload("res://content/drop/packeddrop/PackedDrop.tscn")
}

var DROP_ICONS: = {
	CONST.IRON: preload("res://content/icons/icon_iron.png"), 
	CONST.WATER: preload("res://content/icons/icon_water.png"), 
	CONST.SAND: preload("res://content/icons/icon_sand.png"), 
}

var CAVE_SCENES: = {
	"mushroom": preload("res://content/caves/mushroomcave/MushroomCave.tscn"), 
	"bomb": preload("res://content/caves/bombcave/BombCave.tscn"), 
	"helmet": preload("res://content/caves/helmetextensioncave/HelmetCave.tscn"), 
	"seed": preload("res://content/caves/seedcave/SeedCave.tscn"), 
	"drone": preload("res://content/caves/dronecave/DroneCave.tscn"), 
	"scanner": preload("res://content/caves/scannercave/ScannerCave.tscn"), 
	"cobalt": preload("res://content/caves/cobaltcave/CobaltCave.tscn"), 
	"water": preload("res://content/caves/watercave/WaterCave.tscn"), 
	"iron": preload("res://content/caves/treecave/IronTreeCave.tscn"), 
	"portal": preload("res://content/caves/portalcave/PortalCave.tscn"), 
}

var SPECIAL_CAVE_SCENES: = {
	"drillbert": preload("res://content/caves/drillicave/DrillbertCave.tscn"), 
	"lunar": preload("res://content/caves/dragoncave/LunarNewYearDragonCave.tscn"), 
	"halloween": preload("res://content/caves/halloweencave/HalloweenSkeletonCave.tscn"), 
	"seed_assignment": preload("res://content/caves/seedcave/SeedCaveAssignment.tscn"), 
	"nest": preload("res://content/map/chamber/nest/NestCave.tscn")
}

var TUTORIAL_SCENES: = {
	"sword_intro": preload("res://content/weapons/sword/tutorial/SwordTutorial.tscn"), 
	"artillery_intro": preload("res://content/weapons/artillery/tutorial/ArtilleryTutorial.tscn"), 
	"tesla_intro": preload("res://content/weapons/tesla/tutorial/TeslaTutorial.tscn"), 
	"repair1": preload("res://content/dome/tutorials/RepairTutorial1.tscn"), 
	"repair2": preload("res://content/dome/tutorials/RepairTutorial2.tscn"), 
	"stationdefend": preload("res://content/dome/tutorials/StationTutorial.tscn"), 
	"keeper1_pickup": preload("res://content/keeper/keeper1/Keeper1PickupTutorial.tscn"), 
	"keeper1_drop": preload("res://content/keeper/keeper1/Keeper1DropTutorial.tscn"), 
	"orchard": preload("res://content/gadgets/orchard/FruitTutorial.tscn"), 
	"repellent": preload("res://content/gadgets/repellent/RepellentTutorial.tscn"), 
	"probe": preload("res://content/gadgets/probe/ProbeTutorial.tscn"), 
	"teleporter_take": preload("res://content/gadgets/teleporter/TeleporterTakeTutorial.tscn"), 
	"teleporter_teleport": preload("res://content/gadgets/teleporter/TeleporterTeleportTutorial.tscn"), 
	"teleporter_carry": preload("res://content/gadgets/teleporter/TeleporterCarryTutorial.tscn"), 
	"blastmining": preload("res://content/gadgets/blastMining/BlastMiningTutorial.tscn"), 
	"onewayteleporter": preload("res://content/caves/teleportcave/OneWayTeleporterTutorial.tscn"), 
	"drillbotcarry": preload("res://content/gadgets/drillbot/DrillbotCarryTutorial.tscn"), 
	"drillbothandling": preload("res://content/gadgets/drillbot/DrillbotHandlingTutorial.tscn"), 
	"drillbotsleeping": preload("res://content/gadgets/drillbot/DrillbotSleepingTutorial.tscn"), 
	"mineraltree": preload("res://content/caves/seedcave/MineralTreeTutorial.tscn"), 
	"assessor2_intro": preload("res://content/keeper/keeper2/tutorial/AssessorTutorial.tscn"), 
	"assessor2_reflect": preload("res://content/keeper/keeper2/tutorial/AssessorReflectTutorial.tscn"), 
	"assessor2_split": preload("res://content/keeper/keeper2/tutorial/AssessorSplitTutorial.tscn"), 
	"assessor2_explode": preload("res://content/keeper/keeper2/tutorial/AssessorExplodeTutorial.tscn"), 
	"assessor2_bundle": preload("res://content/keeper/keeper2/tutorial/AssessorBundleTutorial.tscn"), 
	"assessor2_guidance": preload("res://content/keeper/keeper2/tutorial/AssessorGuidanceTutorial.tscn"), 
	"ninja_intro": preload("res://content/keeper/keeper3/tutorial/NinjaTutorial.tscn"), 
	"infiltrator_carry": preload("res://content/keeper/keeper3/tutorial/InfiltratorCarryTutorial.tscn"), 
	"infiltrator_drop": preload("res://content/keeper/keeper3/tutorial/InfiltratorDropTutorial.tscn"), 
	"infiltrator_mining": preload("res://content/keeper/keeper3/tutorial/InfiltratorMiningTutorial.tscn"), 
	"infiltrator_jumping": preload("res://content/keeper/keeper3/tutorial/InfiltratorJumpTutorial.tscn"), 
	"infiltrator_pickup": preload("res://content/keeper/keeper3/tutorial/InfiltratorGadgetPickupTutorial.tscn"), 
	"infiltrator_rope": preload("res://content/keeper/keeper3/tutorial/InfiltratorRopeTutorial.tscn"), 
	"infiltrator_shuriken": preload("res://content/keeper/keeper3/tutorial/InfiltratorShurikenTutorial.tscn"), 
	"beastmaster_intro": preload("res://content/keeper/keeper4/tutorial/BeastmasterTutorial.tscn"), 
	"beastmaster_hole": preload("res://content/keeper/keeper4/tutorial/BeastmasterHoleTutorial.tscn"), 
	"beastmaster_squad": preload("res://content/keeper/keeper4/tutorial/BeastmasterSquadTutorial.tscn"), 
	"extractor": preload("res://content/gadgets/extractor/ExtractorTutorial.tscn"), 
	"suitblaster": preload("res://content/gadgets/suitblaster/SuitBlasterTutorial.tscn"), 
	"resourcepacker": preload("res://content/gadgets/ressourcepacker/ResourcePackerTutorial.tscn"), 
	"mushroomfarm": preload("res://content/gadgets/mushroomfarm/MushroomTutorial.tscn"), 
	"drillingrigsidedriller": preload("res://content/gadgets/minedriller/MineDrillerTutorial.tscn"), 
	"overcharge": preload("res://content/gadgets/orchard/OverchargeTutorial.tscn"), 
	}

const TILE_EMPTY: = -1
const TILE_BORDER: = 19
const TILE_IRON: = 0
const TILE_WATER: = 1
const TILE_SAND: = 2
const TILE_GADGET: = 3
const TILE_RELIC: = 4
const TILE_NEST: = 5
const TILE_RELIC_SWITCH: = 6
const TILE_SUPPLEMENT: = 7
const TILE_CAVE: = 9
const TILE_DIRT_START: = 10
const TILE_DIRT_MARK_BLOCKED_FOR_CHAMBER: = 11

const HARDNESS_VERY_SOFT: = 0
const HARDNESS_SOFT: = 1
const HARDNESS_MEDIUM: = 2
const HARDNESS_HARD: = 3
const HARDNESS_VERY_HARD: = 4
const HARDNESS_INDESTRUCTIBLE: = 5

const TILE_OVERLAY_ROOTS: = "roots"
const TILE_OVERLAY_MYZEL: = "myzel"
const TILE_OVERLAY_WORMS: = "worms"

var TILE_ID_TO_STRING_MAP: = {
	TILE_EMPTY: "", 
	TILE_BORDER: CONST.BORDER, 
	TILE_IRON: CONST.IRON, 
	TILE_WATER: CONST.WATER, 
	TILE_SAND: CONST.SAND, 
	TILE_GADGET: CONST.GADGET, 
	TILE_RELIC: CONST.RELIC, 
	TILE_NEST: CONST.NEST, 
	TILE_RELIC_SWITCH: CONST.RELICSWITCH, 
	TILE_SUPPLEMENT: CONST.POWERCORE, 
}

const PATH_PROBE: = preload("res://content/shared/PathProbe.tscn")
const TILE_BREAK_PARTICLES: = preload("res://content/map/tile/TileBreakParticles.tscn")
const KEEPER_SPARK = preload("res://content/keeper/Spark.tscn")
const TILE_DIRT_PARTICLE = preload("res://content/map/tile/DirtParticle.tscn")
const CARRYLINE_BREAK = preload("res://content/keeper/carryline/CarrylineBreak.tscn")
const PROBE = preload("res://content/gadgets/probe/Probe.tscn")
const ICON_FALLBACK = preload("res://content/icons/placeholder_icon.png")

var RUN_MODIFIERS: = ["hyperactive", "longtime", "maze", "doubleiron", "automateddefense", "drillbert", "domesupplements", "nomonsters", "strongmonsters", "shortcycles", "toughstart", "secondweapon"]

var COOP_RUN_MODIFIERS: = ["secondweapon"]

var LanguageNamesByCode: = {
	"ar_SA": "العربية الفصحى", 
	"bg_BG": "Български", 
	"ca_ES": "Català", 
	"cs_CZ": "čeština", 
	"da_DK": "Dansk", 
	"de_DE": "Deutsch", 
	"en_GB": "English", 
	"en_US": "English", 
	"es_ES": "Español", 
	"es_AR": "Español de América", 
	"et_EE": "Eesti Keel", 
	"eu_ES": "Euskara", 
	"fi_FI": "Suomi", 
	"fil_PH": "Tagalog", 
	"fr_FR": "Français", 
	"he_IL": "עברית", 
	"hu_HU": "Magyar", 
	"id_ID": "Bahasa Indonesia", 
	"it_IT": "Italiano", 
	"ja_JP": "日本語", 
	"ko_KR": "한국어", 
	"nl_NL": "Nederlands", 
	"nb_NO": "Norsk", 
	"pl_PL": "Polski", 
	"pt_BR": "Português Brasileiro", 
	"pt_PT": "Português", 
	"ro_RO": "Limba Română", 
	"ru_RU": "Русский язык", 
	"sk_SK": "Slovenčina", 
	"sv_SE": "Svenska", 
	"th_TH": "ภาษาไทย", 
	"tr_TR": "Türkçe", 
	"uk_UA": "Українська", 
	"vi_VN": "Tiếng Việt", 
	"zh_CN": "简体中文", 
	"zh_TW": "繁體中文"
}

var FontsByCode: = {
	"ja_JP": preload("res://gui/fonts/ja/Makinas-4-Flat.otf"), 
	"ko_KR": preload("res://gui/fonts/korean/NotoSansKR-Regular.otf"), 
	"th_TH": preload("res://gui/fonts/thai/Aksaramatee Regular.ttf"), 
	"vi_VN": preload("res://gui/fonts/roboto/Roboto-Regular.ttf"), 
	"zh_CN": preload("res://gui/fonts/simplified chinese/NotoSansSC-Regular.otf"), 
	"zh_TW": preload("res://gui/fonts/traditional chinese/NotoSansTC-Regular.otf"), 
	"he_IL": preload("res://gui/fonts/hebrew/VarelaRound-Regular.ttf"), 
}

var monsterIcons: = {
	"beast": [preload("res://content/monster/Beast/spriteframes.tres"), "run", Vector2(40, 35)], 
	"bigtick": [preload("res://content/monster/bigtick/spriteframes.tres"), "walk", Vector2(15, 14)], 
	"bloater": [preload("res://content/monster/bloater/spriteframes.tres"), "idle", Vector2(24, 36)], 
	"bolter": [preload("res://content/monster/bolter/spriteframes.tres"), "fly", Vector2(73, 53)], 
	"breeder": [preload("res://content/monster/breeder/spriteframes.tres"), "idle", Vector2(62, 29)], 
	"burrower": [preload("res://content/monster/burrower/spriteframes.tres"), "move", Vector2(25, 8)], 
	"butterfly": [preload("res://content/monster/butterfly/spriteframes.tres"), "fly", Vector2(55, 30)], 
	"diver": [preload("res://content/monster/diver/spriteframes.tres"), "fly", Vector2(37, 40)], 
	"driller": [preload("res://content/monster/driller/spriteframes.tres"), "walk", Vector2(95, 95)], 
	"flyer": [preload("res://content/monster/flyer/spriteframes.tres"), "fly", Vector2(30, 26)], 
	"hornet": [preload("res://content/monster/hornet/spriteframes.tres"), "fly", Vector2(38, 38)], 
	"mucker": [preload("res://content/monster/mucker/spriteframes.tres"), "walk", Vector2(35, 32)], 
	"phaser": [preload("res://content/monster/phaser/spriteframes.tres"), "idle", Vector2(25, 40)], 
	"rockman": [preload("res://content/monster/rockman/spriteframes.tres"), "walk", Vector2(25, 26)], 
	"scarab": [preload("res://content/monster/scarab/spriteframes.tres"), "idle", Vector2(88, 66)], 
	"scarabarm": [preload("res://content/monster/scarab/ScarabArm_spriteframes.tres"), "right", Vector2(80, 65)], 
	"shifter": [preload("res://content/monster/shifter/spriteframes.tres"), "idle", Vector2(27, 44)], 
	"stag": [preload("res://content/monster/stag/spriteframes.tres"), "walk", Vector2(45, 80)], 
	"stingray": [preload("res://content/monster/stingray/spriteframes.tres"), "idle", Vector2(37, 26)], 
	"tick": [preload("res://content/monster/tick/spriteframes.tres"), "walk", Vector2(10, 10)], 
	"tormentor": [preload("res://content/monster/tormentor/spriteframes.tres"), "walk", Vector2(48, 38)], 
	"walker": [preload("res://content/monster/walker/spriteframes.tres"), "walk", Vector2(33, 30)], 
	"worm": [preload("res://content/monster/worm/spriteframes.tres"), "idle", Vector2(65, 50)], 
}

var palette_rgby: = {
	"palette_1_1": [1, 2, 3, 4], 
	"palette_1_2": [1, 2, 3, 4], 
	"palette_1_3": [1, 2, 3, 4], 
	"palette_2_1": [2, 1, 3, 4], 
	"palette_2_2": [2, 3, 1, 4], 
	"palette_2_3": [3, 2, 1, 4], 
	"palette_3_1": [3, 2, 1, 4], 
	"palette_3_2": [3, 1, 2, 4], 
	"palette_3_3": [1, 3, 1, 4], 
	"palette_4_1": [2, 1, 3, 4], 
	"palette_4_2": [3, 1, 2, 4], 
	"palette_5_1": [2, 3, 1, 4], 
	"palette_5_2": [1, 2, 3, 4], 
	"palette_6_1": [2, 1, 3, 4], 
	"palette_6_2": [2, 3, 1, 4], 
	"palette_6_3": [2, 3, 1, 4], 
	"palette_6_4": [1, 2, 3, 4], 
	"palette_6_5": [2, 3, 1, 4], 
	"palette_6_6": [3, 1, 2, 4], 
	"palette_6_7": [1, 2, 3, 4], 
	"palette_7_1": [2, 4, 3, 1], 
	"palette_7_2": [1, 2, 3, 4], 
}

var changed_values: int = 0
var keeperSupplementSlots: = []

func _ready():

	gameProperties = {}
	parsePropertiesYaml("res://properties.yaml")


	upgrades = {}
	gadgets = {}
	supplements = {}
	parseUpgradesYaml("res://upgrades.yaml")

	parseAssignmentYaml("res://assignments.yaml")


	keeperSupplementSlots = []
	for gadget in Data.gadgets.values():
		if gadget.get("takeslots", []).has("keepersuit"):
			for slot in gadget.get("addslots", []):
				keeperSupplementSlots.append(slot)


func track_changes():
	recently_changed.clear()

func stop_tracking():
	recently_changed.clear()

func parseAssignmentYaml(filPath: String):
	var f = FileAccess.open(filPath, FileAccess.ModeFlags.READ)
	if f == null:
		Logger.error("Failed to open %s - Error: %s" % [filPath, str(FileAccess.get_open_error())])
		get_tree().quit()
		return

	var assignmentId = null
	var assignment: Assignment = null
	var parsingPropertyChanges: = false
	var parsingMultiplayerModifier: = false
	var parsingChallengePropertyChanges: = false
	while true:
		var line: String = f.get_line()
		if line.strip_edges().length() > 1:
			if line.begins_with(" "):
				if parsingPropertyChanges or parsingChallengePropertyChanges or parsingMultiplayerModifier:
					line = line.strip_edges()
					if line.begins_with("-"):
						var rawPropertyChange = line.substr(1, line.length() - 1).strip_edges()
						var change = PropertyChange.new(rawPropertyChange)
						if parsingPropertyChanges:
							assignment.propertyChanges.append(change)
						elif parsingChallengePropertyChanges:
							assignment.challengePropertyChanges.append(change)
						else:
							assignment.multiplayerModifier.append(change)
						continue
					else:
						parsingPropertyChanges = false
						parsingChallengePropertyChanges = false
						parsingMultiplayerModifier = false

				var split = line.split(":")
				var key: String = split[0].strip_edges().to_lower()
				var value: String = split[1].strip_edges()
				match key:
					"tier":
						assignment.tier = int(value)
					"hidden":
						assignment.hidden = value == "true"
					"challengepropertychanges":
						parsingChallengePropertyChanges = true
					"propertychanges":
						parsingPropertyChanges = true
					"multiplayermodifier":
						parsingMultiplayerModifier = true
					"upgradelimits":
						assignment.upgradeLimits = value.split(",", false)
						for i in assignment.upgradeLimits.size():
							assignment.upgradeLimits[i] = assignment.upgradeLimits[i].strip_edges()
					"worldmodifiers":
						assignment.worldModifiers = value.split(",", false)
						for i in assignment.worldModifiers.size():
							assignment.worldModifiers[i] = assignment.worldModifiers[i].strip_edges()
					"worldid":
						assignment.worldId = value
					"maparchetype":
						assignment.mapArchetype = value
					"freegadgets":
						assignment.freeGadgets = int(value)
					"goaltype":
						assignment.goaltype = value
					"goalvalue":
						if assignment.goaltype == "property":
							assignment.goalvalue = PropertyCheck.new(value)
						else:
							assignment.goalvalue = value
					"challengegoalvalue":
						assignment.challengeGoalValue = value
					"globalAreaOverrides":
						assignment.globalAreaOverrides = value
					"mod":
						assignment.isMod = value == "true"
			else:

				var key = line.substr(0, line.find(":")).to_lower()
				if assignmentId:
					for array in [assignment.upgradeLimits, assignment.worldModifiers]:
						for i in array.size():
							array[i] = array[i].strip_edges()
					assignments[assignmentId] = assignment
				assignmentId = key
				assignment = Assignment.new()
				assignment.id = key
		else:
			if assignmentId:
				assignments[assignmentId] = assignment

		if f.get_position() >= f.get_length() or f.eof_reached():
			break
	f.close()

func parseUpgradesYaml(upgradesPath: String):
	var f = FileAccess.open(upgradesPath, FileAccess.ModeFlags.READ)
	if f == null:
		Logger.error("Failed to open %s - Error: %s" % [upgradesPath, str(FileAccess.get_open_error())])
		get_tree().quit()
		return

	var currentKey = null
	var currentData = null
	var propertyChanges = null
	var subDictionary = null
	while true:
		var line: String = f.get_line()
		if line.strip_edges().length() > 1:
			if line.begins_with(" "):

				if propertyChanges != null:

					line = line.strip_edges()
					if line.begins_with("-"):
						var value = line.substr(1, line.length() - 1)
						var change = PropertyChange.new(value)
						propertyChanges.append(change)
						continue
					else:

						propertyChanges = null

				if subDictionary != null:

					if line.begins_with("    "):

						var split = line.split(":")
						var key = split[0].strip_edges().to_lower()
						var value = split[1].strip_edges()
						subDictionary[key] = BackwardCompatibilityUtils.str_to_var(value)
						continue
					else:

						currentData[subDictionary["_key"]] = subDictionary
						subDictionary.erase("_key")
						subDictionary = null

				var split = line.split(":")
				var key = split[0].strip_edges().to_lower()
				var value = split[1].strip_edges()
				if key == "propertychanges" or key == "repeatable":
					propertyChanges = []
					currentData[key] = propertyChanges
				elif value.begins_with("["):
					value = value.replace(" ", "")
					var a = []
					var values = value.substr(1, value.length() - 2).to_lower()
					for val in values.split(","):
						a.append(BackwardCompatibilityUtils.str_to_var(val))
					currentData[key] = a
				elif value.length() == 0:

					subDictionary = {"_key": key}
				else:
					currentData[key] = BackwardCompatibilityUtils.str_to_var(value)
			else:

				var key = line.substr(0, line.find(":")).to_lower()
				if currentKey:
					if subDictionary:
						currentData[subDictionary["_key"]] = subDictionary
						subDictionary.erase("_key")
						subDictionary = null
					storeUpgradeData(currentKey, currentData)
				currentKey = key
				currentData = {}
		else:
			if currentKey:
				if subDictionary:
					currentData[subDictionary["_key"]] = subDictionary
					subDictionary.erase("_key")
					subDictionary = null
				storeUpgradeData(currentKey, currentData)
				currentKey = null
				currentData = null

		if f.get_position() >= f.get_length() or f.eof_reached():
			break

	f.close()


	for u in upgrades:
		upgrades[u].erase("tier")


	for gk in gadgets:
		gadgets[gk]["id"] = gk
		gadgets[gk]["tier"] = 0
		upgrades[gk] = gadgets[gk]


	var deletedSomething: = true
	while deletedSomething:
		deletedSomething = false
		for uk in upgrades.keys().duplicate():
			var unknownPredecessors: = []
			var upgradeData = upgrades[uk]
			upgradeData["id"] = uk
			if upgradeData.has("predecessors"):
				var predecessors: Array = upgradeData.get("predecessors")
				for techId in predecessors:
					if not upgrades.has(techId):
						unknownPredecessors.append(techId)
				if unknownPredecessors.size() > 0:
					if predecessors.size() > unknownPredecessors.size():
						Logger.warn("Upgrade " + uk + " has an unknown predecessors " + str(unknownPredecessors) + ". Removing these from predecessors.")
						for unknownPredecessor in unknownPredecessors:
							predecessors.erase(unknownPredecessor)
					else:
						Logger.warn("Upgrade " + uk + " has only unknown predecessor . Removing it from upgrades.")
						upgrades.erase(uk)
						orderedUpgradeKeys.erase(uk)
						deletedSomething = true


	var openUpgrades: = orderedUpgradeKeys.duplicate()
	for gk in gadgets:
		openUpgrades.erase(gk)
	var currentTier: = 1
	var tieredUpgrades = []
	while true:
		for uk in openUpgrades:
			var maxTier: = 0
			for techId in upgrades[uk].get("predecessors", []):
				maxTier = upgrades[techId].get("tier", 9999)
			if maxTier < 9999:
				tieredUpgrades.append(uk)

		if tieredUpgrades.size() == 0:
			break
		else:
			for uk in tieredUpgrades:
				upgrades[uk]["tier"] = currentTier
				openUpgrades.erase(uk)
		currentTier += 1
		tieredUpgrades.clear()


	for uk in upgrades.keys():
		if upgrades[uk].tier > 0:
			var key = upgrades[uk].get("predecessors").front()
			if upgrades[uk].tier == 1 and upgrades[key].get("scenes", {}).has("keepersuit"):
				upgrades[uk]["followskeepergadget"] = true
			while upgrades[key].tier > 0:
				key = upgrades[key].get("predecessors").front()
			upgrades[uk]["root"] = key

	for uk in upgrades.keys():
		var u = upgrades[uk]
		var locks = upgrades.get(uk).get("locks", [])
		for l in locks:
			var uu = upgrades.get(l)
			u["tier"] = max(u["tier"], uu.get("tier", 0))

	for uk in upgrades.keys():
		if upgrades[uk].has("cost") and "=" in upgrades[uk]["cost"]:
			var costs: = {}
			var split1 = upgrades[uk].get("cost").split(",")
			for costString in split1:
				var split2 = costString.split("=")
				costs[str(split2[0]).strip_edges()] = int(split2[1])
			upgrades[uk]["cost"] = costs

func parsePropertiesYaml(propertiesFilePath: String):
	var f = FileAccess.open(propertiesFilePath, FileAccess.ModeFlags.READ)
	if f == null:
		Logger.error("Failed to open %s - Error: %s" % [propertiesFilePath, str(FileAccess.get_open_error())])
		get_tree().quit()
		return
	var currentId
	while f.get_position() < f.get_length():
		var line = f.get_line()
		var parts = line.split(":", false)
		match parts.size():
			0:
				currentId = null
			1:
				currentId = parts[0].strip_edges().to_lower()
			2:
				var key = currentId + "." + parts[0].strip_edges().to_lower()
				if parts[0].to_lower().find("template") != -1:
					templates[key.substr(0, key.length() - 8)] = parts[1].strip_edges()
				elif parts[1].find(",") != -1:
					var values: = []
					for v in parts[1].split(","):
						values.append(BackwardCompatibilityUtils.str_to_var(v.strip_edges()))

					gameProperties[key] = values
				else:
					gameProperties[key] = BackwardCompatibilityUtils.str_to_var(parts[1].strip_edges())
	f.close()

func storeUpgradeData(key: String, currentData: Dictionary):
	match currentData.get("type", ""):
		"gadget":
			gadgets[key] = currentData
			if not orderedUpgradeKeys.has(key):
				orderedUpgradeKeys.append(key)
		"primarygadget":
			gadgets[key] = currentData
			if not orderedUpgradeKeys.has(key):
				orderedUpgradeKeys.append(key)
		"keeper":
			gadgets[key] = currentData
			if not orderedUpgradeKeys.has(key):
				orderedUpgradeKeys.append(key)
		"dome":
			gadgets[key] = currentData
			if not orderedUpgradeKeys.has(key):
				orderedUpgradeKeys.append(key)
		"weapon":
			gadgets[key] = currentData
			if not orderedUpgradeKeys.has(key):
				orderedUpgradeKeys.append(key)
		"worldmodifier":
			worldModifiers[key] = currentData
		"versusmodifier":
			versusModifiers[key] = currentData
		"gamemode":
			gadgets[key] = currentData
			if not orderedUpgradeKeys.has(key):
				orderedUpgradeKeys.append(key)
		"supplement":
			supplements[key] = currentData
			if not orderedUpgradeKeys.has(key):
				orderedUpgradeKeys.append(key)
			supplements[key]["id"] = key
			upgrades[key] = supplements[key]
		"reward":
			currentData["id"] = key
			rewards[key] = currentData
		_:
			if currentData.has("predecessors"):
				upgrades[key] = currentData
				if not orderedUpgradeKeys.has(key):
					orderedUpgradeKeys.append(key)

func reset():
	changed_values += values.size()
	values.clear()
	for k in gameProperties:
		applyFromGamedata(k, 0)

func of(property: String):
	property = property.to_lower()
	if not values.has(property):
		Logger.error("Tried to access unknown data " + property)
		return -1
	return values[property]

func ofOr(property: String, default):
	property = property.to_lower()
	return values.get(property, default)

func has(property: String):
	return values.has(property.to_lower())

func default(property: String):
	property = property.to_lower()
	if not gameProperties.has(property):
		Logger.error("data is missing", "Data.default", property)
		return null
	var v = gameProperties.get(property)
	if v.size() == 0:
		Logger.error("invalid gameProperties index", "Data.default", {"property": property})
		return null
	return v[0]

func applyPropertyChange(propertyChange: PropertyChange):
	var oldValue = values.get(propertyChange.key, values.get(propertyChange.key.substr(propertyChange.key.find(".") + 1), propertyChange.value))
	var newVal = propertyChange.getChangedValue(oldValue)
	values[propertyChange.key] = newVal
	recently_changed[propertyChange.key] = true
	changed_values += 1
	var invalids: = []
	for l in listeners.get(propertyChange.key, []):
		if is_instance_valid(l):
			l.propertyChanged(propertyChange.key, oldValue, newVal)
		else:

			invalids.append(l)
	for i in invalids:
		listeners.erase(i)

func applyAdditionalFromGamedata(property: String, valueIndex: int):
	property = property.to_lower()
	if not gameProperties.has(property):
		Logger.error("data is missing", "Data.applyFromGamedata", property)
		return
	var v = gameProperties.get(property)
	if v.size() <= valueIndex:
		Logger.error("invalid gameProperties index", "Data.applyFromGamedata", {"property": property, "valueIndex": valueIndex})
		return

	var oldValue = values.get(property, null)
	var newValue = v[valueIndex] + oldValue
	values[property] = newValue
	recently_changed[property] = true
	changed_values += 1
	for l in listeners.get(property, []):
		l.propertyChanged(property, oldValue, newValue)

func applyFromGamedata(property: String, valueIndex: int):
	property = property.to_lower()
	if not gameProperties.has(property):
		Logger.error("data is missing", "Data.applyFromGamedata", property)
		return
	var v = gameProperties.get(property)
	var oldValue = values.get(property, null)
	var newValue
	if v is Array:
		if v.size() <= valueIndex:
			Logger.error("invalid gameProperties index", "Data.applyFromGamedata", {"property": property, "valueIndex": valueIndex})
			return
		newValue = v[valueIndex]
	else:
		newValue = v

	values[property] = newValue
	recently_changed[property] = true
	changed_values += 1
	for l in listeners.get(property, []):
		l.propertyChanged(property, oldValue, newValue)

func apply(property: String, newValue):
	if not is_multiplayer_authority():
		Logger.warn("Client is trying to apply to data.", "Data.apply", {"property": property})
		return

	property = property.to_lower()
	var oldValue = values.get(property, null)

	values[property] = newValue
	recently_changed[property] = true
	changed_values += 1
	var invalids: = []

	for l in listeners.get(property, []).duplicate():
		if is_instance_valid(l) and not l.is_queued_for_deletion():
			l.propertyChanged(property, oldValue, newValue)
		else:
			if GameWorld.dataDebug:
				Logger.error("listener was freed without unlistening", "Data.apply", {"property": property})
			invalids.append(l)
	for i in invalids:
		listeners.erase(i)

func server_apply(property: String, newValue):
	var oldValue = values.get(property, null)
	values[property] = newValue
	changed_values += 1
	var invalids: = []

	for l in listeners.get(property, []).duplicate():
		if is_instance_valid(l) and not l.is_queued_for_deletion():
			l.propertyChanged(property, oldValue, newValue)
		else:
			if GameWorld.dataDebug:
				Logger.error("listener was freed without unlistening", "Data.apply", {"property": property})
			invalids.append(l)
	for i in invalids:
		listeners.erase(i)

func applyInitial(propertyClass: String):
	for g in gameProperties:
		if g.begins_with(propertyClass):
			applyFromGamedata(g, 0)

func event(eventId: String, oldValue = null, newValue = null):
	if not is_inside_tree():

		return
	if not multiplayer.is_server():
		Logger.warn("Client is trying to trigger an event.", "Data.event", {"eventId": eventId})
		return
	Network.rpc_for_states(_internalEvent.bind(eventId, oldValue, newValue), [Network.ConnectionState.LOADOUT_STAGE_SYNC, Network.ConnectionState.LEVEL_STAGE_SYNC], true)

func localEvent(eventId: String, oldValue = null, newValue = null) -> void :
	_internalEvent(eventId, oldValue, newValue)

@rpc("reliable")
func _internalEvent(eventId: String, oldValue = null, newValue = null) -> void :
	var invalids: = []
	for l in listeners.get(eventId, []):
		if is_instance_valid(l):
			l.propertyChanged(eventId, oldValue, newValue)
		else:
			Logger.error("listener was freed without unlistening", "Data.event", {"eventId": eventId})
			invalids.append(l)
	for i in invalids:
		listeners.erase(i)







func listen(listener, property: String, immediateCallback: = false):

	property = property.to_lower()
	var list: Array
	if listeners.has(property):
		list = listeners[property]
	else:
		list = []
		listeners[property] = list

	if list.has(listener) and GameWorld.dataDebug:
		Logger.error("adding listener who is already listening", "Data.listen", {"listener": listener, "property": property})
		return
	list.append(listener)
	if immediateCallback and values.has(property):
		listener.propertyChanged(property, null, of(property))
	if not listener.is_connected("tree_exited", Callable(self, "unlistenAll")):
		listener.connect("tree_exited", Callable(self, "unlistenAll").bind(listener))

func isListening(listener, property):
	property = property.to_lower()
	var list: Array
	if not listeners.has(property):
		return false
	list = listeners[property]
	return list.has(listener)

func unlistenAll(listener):
	for prop in listeners:
		call_deferred("removeListener", listeners[prop], listener)

func unlisten(listener, property: String):

	property = property.to_lower()
	var list: Array = listeners.get(property, [])
	if not list.has(listener):
		Logger.error("removing listener who is not listening", "Data.unlisten", {"listener": listener, "property": property})
		return

	call_deferred("removeListener", list, listener)

func removeListener(list, listener):
	list.erase(listener)

func clearListeners():
	listeners.clear()

func makeInstancedUpgrade(upgradeData: Dictionary, prefix: String):
	upgradeData["tr_id"] = upgradeData["id"]
	if upgradeData["id"].find(".") == -1:
		upgradeData["id"] = prefix + "." + upgradeData["id"]
	for key in ["limit", "unlockslimits", "excludelimit", "addslots", "takeslots", "predecessors", "locks"]:
		for i in upgradeData.get(key, []).size():
			if upgradeData[key][i].find(".") == -1:
				upgradeData[key][i] = prefix + "." + upgradeData[key][i]

	for p: PropertyChange in upgradeData.get("propertychanges", []):
		if p.keyClass != "times" and p.keyClass != "cost":
			var instancedKey: String = prefix + "." + p.key
			if not values.has(instancedKey):
				if values.has(p.key):
					values[instancedKey] = values.get(p.key)


			p.key = instancedKey



func asKeeperGadget(upgradeData: Dictionary, playerId: String):
	if playerId == "":
		return
	var baseId: String = upgradeData["id"]
	if baseId.find(".") != -1:
		baseId = baseId.substr(baseId.find(".") + 1)
	upgradeData["id"] = playerId + "." + baseId

	for i in upgradeData.get("takeslots", []).size():
		if upgradeData["takeslots"][i].find("keepersuit") != -1:
			upgradeData["takeslots"][i] = playerId + ".keepersuit"
		if Data.keeperSupplementSlots.has(upgradeData["takeslots"][i]):
			upgradeData["takeslots"][i] = playerId + "." + upgradeData["takeslots"][i]
	for i in upgradeData.get("addslots", []).size():
		upgradeData["addslots"][i] = playerId + "." + upgradeData["addslots"][i]

	var teamId = Keepers.getKeeper(playerId).teamId
	var scenes: Dictionary = upgradeData.get("scenes", {})
	for slot in ["primary", "cellar", "mineshaft", "domesurface", "domebackside"]:

		if scenes.has(slot):
			for keeper in Keepers.getAllOfTeam(teamId):
				if keeper.playerId != playerId:
					if GameWorld.boughtUpgrades.has(keeper.playerId + "." + baseId):
						scenes.erase(slot)
						break

	var pred: = []
	for p in upgradeData.get("predecessors", []):
		var newPred = playerId + "." + p.substr(p.find(".") + 1)
		pred.append(newPred)
	upgradeData["predecessors"] = pred


	if upgradeData.get("type", "") == "gadget" and upgradeData.has("addslots"):
		var slotToAdd: String = upgradeData.get("addslots")[0].split(".")[1]
		for id: String in GameWorld.boughtUpgrades:
			var bId: = id.split(".")[1]
			if not Data.upgrades.has(bId):
				continue
			var boughtUpgradeData: Dictionary = Data.upgrades[bId]
			if boughtUpgradeData.has("takeslots") and boughtUpgradeData["takeslots"][0] == slotToAdd:
				upgradeData.erase("addslots")
				break

func asKeeperGadgetSupplement(upgradeData: Dictionary, playerId: String) -> void :


	for i in upgradeData.get("limit", []).size():
		if upgradeData["limit"][i] == "gadgetsupplements":
			continue
		upgradeData["limit"][i] = playerId + "." + upgradeData["limit"][i]

func removeAvailableTechSlotsForSupplement(upgradeData: Dictionary, playerId: String) -> void :
	var teamId = Keepers.getKeeper(playerId).teamId

	var baseId: String = upgradeData["takeslots"][0].split(".")[1]
	for keeper: Keeper in Keepers.getAllOfTeam(teamId):
		GameWorld.availableTechSlots.erase(keeper.playerId + "." + baseId)



func asKeeperGadgetUpgrade(upgrade: Dictionary, teamId: String):
	if upgrade.get("followskeepergadget", false):
		upgrade["predecessors"].clear()
		upgrade["predecessorsany"] = true
		upgrade["keepunavailablepredecessors"] = true
		for keeper in Keepers.getAllOfTeam(teamId):
			upgrade["predecessors"].append(keeper.playerId + "." + upgrade["root"])

func getInventory(type: String, teamId: String):
	return of(teamId + ".inventory." + type)

func changeByInt(property: String, change):
	var newVal = change + ofOr(property, 0)
	apply(property, newVal)
	return newVal

func changeDomeHealth(amount: float, teamId: String):
	if not multiplayer.is_server():
		return

	if Data.of(teamId + ".dome.healthlocked"):
		return

	if Data.of(teamId + ".dome.invulnerabletime") > 0:
		return

	var domeMaxHealth = Data.of(teamId + ".dome.maxHealth")
	var domeHealth = Data.of(teamId + ".dome.health")
	var newHealth = min(domeHealth + amount, float(Data.of(teamId + ".dome.maxHealth")))

	if newHealth <= 0.0:
		if Data.ofOr(teamId + ".dome.resurrectcharges", 0) > 0:
			apply(teamId + ".dome.health", Data.of(teamId + ".dome.maxhealth"))
			changeByInt(teamId + ".dome.resurrectcharges", -1)
			var dome = Level.domesByTeamId[teamId]
			if dome:
				dome.autoheal()
			var invulnerableTime = Data.ofOr(teamId + ".dome.resurrectinvulnerability", 0)
			if invulnerableTime > 0:
				Data.apply(teamId + ".dome.invulnerabletime", invulnerableTime)
			return

		if Data.ofOr(teamId + ".dome.autorepair", false):
			var upgrade: Dictionary
			if GameWorld.upgrades.has(teamId + ".domesandrepair"):
				upgrade = GameWorld.upgrades.get(teamId + ".domesandrepair")
			elif GameWorld.upgrades.has(teamId + ".domesandrepairstrong"):
				upgrade = GameWorld.upgrades.get(teamId + ".domesandrepairstrong")
			else:
				Logger.error("tried auto heal but no healing ability available", "Data.changeDomeHealth")
				return

			var cost = upgrade.get("cost", {})
			if GameWorld.canAfford(cost, teamId):
				for costType in cost:
					Data.changeByInt(teamId + ".inventory." + costType, - cost[costType])
				GameWorld.addUpgrade(upgrade["id"])
				var dome = Level.domesByTeamId[teamId]
				if dome:
					Network.rpc_if_state(dome.autoheal, Network.ConnectionState.LEVEL_STAGE_SYNC, true)




				amount = clamp(amount, - domeMaxHealth + 1, domeMaxHealth)
				changeDomeHealth(amount, teamId)
				return

	apply(teamId + ".dome.health", newHealth)

func worldScene(worldId: String):
	return load("res://content/worlds/" + worldId + "/" + startCaptialized(worldId) + ".tscn")

func startCaptialized(s: String):
	return s.substr(0, 1).to_upper() + s.substr(1, s.length() - 1)

func snapVectorToDirections(v: Vector2, rad: float) -> Vector2:
	var angle = atan2(v.y, v.x)

	if abs(angle) < rad:
		angle = 0
	elif abs(angle + CONST.PI_HALF) < rad:
		angle = - CONST.PI_HALF
	elif abs(angle - CONST.PI_HALF) < rad:
		angle = CONST.PI_HALF
	elif abs(angle - PI) < rad or abs(angle + PI) < rad:
		angle = PI

	return Vector2.RIGHT.rotated(angle)

func getKeyClass(propertyKey: String):
	return propertyKey.substr(propertyKey.find("."))

func serialize() -> Dictionary:
	return values.duplicate()

func deserialize(data: Dictionary):

	for d in data:
		values[d] = data[d]


	for d in data:
		if d.find("dome.healthfractionrepair") == -1:
			apply(d, data[d])

func deepDuplicateUpgrade(upgrade: Dictionary, generalPrefix: String = "", instancePrefix: String = "") -> Dictionary:
	var duplicatedUpgrade = upgrade.duplicate(true)
	if instancePrefix != "":
		if duplicatedUpgrade.has("predecessors"):
			for i in duplicatedUpgrade.get("predecessors").size():
				duplicatedUpgrade["predecessors"][i] = instancePrefix + "." + duplicatedUpgrade["predecessors"][i]
			duplicatedUpgrade["root"] = instancePrefix + "." + duplicatedUpgrade["root"]
		if not duplicatedUpgrade.has("shadowing"):
			duplicatedUpgrade["shadowing"] = duplicatedUpgrade["id"]
		duplicatedUpgrade["id"] = instancePrefix + "." + duplicatedUpgrade["id"]

		if upgrade.has("locks"):
			var locks: = []
			for lock in upgrade.get("locks"):
				locks.append(instancePrefix + "." + lock)
			duplicatedUpgrade["locks"] = locks

	if upgrade.has("followskeepergadget"):
		duplicatedUpgrade["followskeepergadget"] = upgrade["followskeepergadget"]

	if upgrade.has("repeatable"):
		var dup: = []
		for repeatable in upgrade.get("repeatable"):
			dup.append(repeatable.duplicate())
		duplicatedUpgrade["repeatable"] = dup

	if upgrade.has("scenes"):
		duplicatedUpgrade["scenes"] = upgrade.get("scenes").duplicate()

	if upgrade.has("propertychanges"):
		var dup: = []
		for propertychange in upgrade.get("propertychanges"):
			dup.append(propertychange.duplicate(generalPrefix, instancePrefix))
		duplicatedUpgrade["propertychanges"] = dup

	if upgrade.has("cost") and upgrade.get("type", "") != "reward":
		var costs = upgrade.get("cost")
		if not costs is int:
			var dupCost: = {}
			for res in costs:


				dupCost[res] = int(round(costs[res] * Data.ofOr("team1.upgrademodifiers.cost." + res, 1.0)))
			duplicatedUpgrade["cost"] = dupCost
	return duplicatedUpgrade

static func seedShuffle(oldArray: Array, seedInt: int):
	var array = oldArray.duplicate()
	var m: int = array.size()
	var rand: RandomNumberGenerator = RandomNumberGenerator.new()
	rand.seed = seedInt
	var t
	var i: int = m

	while m:

		i = int(floor(rand.randf() * float(m)))
		m -= 1

		t = array[m]
		array[m] = array[i]
		array[i] = t
		rand.seed += 1
	return array


func registerDome(domeId: String):
	if not loadoutDomes.has(domeId):
		loadoutDomes.append(domeId)

func registerKeeper(keeperId: String):
	if not loadoutKeepers.has(keeperId):
		loadoutKeepers.append(keeperId)

func registerGameMode(gameModeId: String):
	if not loadoutGameModes.has(gameModeId):
		loadoutGameModes.append(gameModeId)

func registerGadget(gadgetId: String):
	if not loadoutGadgets.has(gadgetId):
		loadoutGadgets.append(gadgetId)

func registerRunModifier(runModifierId: String):
	if not GameWorld.unlockedRunModifiers.has(runModifierId):
		GameWorld.unlockedRunModifiers.append(runModifierId)

func registerPet(petId: String):
	if not GameWorld.unlockedPets.has(petId):
		GameWorld.unlockedPets.append(petId)

func registerSkin(keeperId: String, skinId: String):
	GameWorld.unlockSkin(keeperId, skinId)

func stabilizedRandomInt(minBound: int, maxBound: int, deltaPropertyName: String, threshold: int) -> int:
	var output = minBound + randi() % (maxBound - minBound + 1)
	var mean = (minBound + maxBound) * 0.5
	var propertyKey = "delta." + deltaPropertyName
	var delta = Data.ofOr(propertyKey, 0)
	var change = output - mean
	delta += change
	if abs(delta) > threshold:
		var correction = round((threshold - abs(delta)) * sign(change))
		output += correction
		change += correction

	Data.changeByInt(propertyKey, change)
	assert (output >= minBound and output <= maxBound, "stabilizedRandomInt returned value out of bounds. This can happen if the same deltaPropertyName is used by different calls")
	return output

func stabilizedRandomFloat(minBound: float, maxBound: float, deltaPropertyName: String, threshold: float) -> float:
	var output = randf_range(minBound, maxBound)
	var mean = (minBound + maxBound) * 0.5
	var propertyKey = "delta." + deltaPropertyName
	var delta = Data.ofOr(propertyKey, 0)
	var change = output - mean
	delta += change
	if abs(delta) > threshold:
		var correction = (threshold - abs(delta)) * sign(change)
		output += correction
		change += correction

	Data.changeByInt(propertyKey, change)
	assert (output >= minBound and output <= maxBound, "stabilizedRandomFloat returned value out of bounds. This can happen if the same deltaPropertyName is used by different calls")
	return output

func loadIconOrFallback(path) -> Resource:
	var res = load(path)
	if res:
		return res
	return ICON_FALLBACK

func isDestructable(t) -> bool:
	return t.has_meta("destructable") and t.get_meta("destructable")

func sanitizeLoadout(loadout: Loadout):
	for dome: LoadoutDome in loadout.domes:
		if not Data.loadoutDomes.has(dome.domeId):
			dome.domeId = Data.loadoutDomes.front()

		if not Data.loadoutGadgets.has(dome.primaryGadgetId):
			dome.primaryGadgetId = Data.loadoutGadgets.front()

		if dome.petId != "" and dome.petId != "pet0" and not GameWorld.unlockedPets.is_empty()\
		and not GameWorld.unlockedPets.has(dome.petId):
			dome.petId = GameWorld.unlockedPets.front()

		for ag in dome.additionalGadgets.duplicate():
			if not Data.gadgets.has(ag):
				dome.additionalGadgets.erase(ag)

	var dlcCorrectedLoadoutKeepers: Array = []
	for keeper in loadout.keepers:
		if GameWorld.isUnlocked(keeper.keeperId):
			dlcCorrectedLoadoutKeepers.append(keeper)
	loadout.keepers = dlcCorrectedLoadoutKeepers

	var dlcCorrectedLoadoutKeeperTemplates: Array = []
	for keeper in loadout.keeperTemplates:
		if GameWorld.isUnlocked(keeper.keeperId):
			dlcCorrectedLoadoutKeeperTemplates.append(keeper)
	loadout.keeperTemplates = dlcCorrectedLoadoutKeeperTemplates

	if loadout.modeConfig.has("assignment"):
		var assignment = loadout.modeConfig["assignment"]
		var dlcAssignment: bool = Data.keeperDlcAssignments.has(assignment)
		var unavailableDlcAssignment = dlcAssignment and ( not GameWorld.isAssignmentUnlocked(assignment))
		if unavailableDlcAssignment:
			loadout.modeId = ""

	for x in loadout.keepers:
		if not Data.loadoutKeepers.has(x.keeperId):
			x.keeperId = Data.loadoutKeepers.front()

		if GameWorld.unlockedSkins.has(x.keeperId) and not GameWorld.unlockedSkins[x.keeperId].has(x.skinId):
			x.skinId = GameWorld.unlockedSkins[x.keeperId].front()

	for x in loadout.keeperTemplates:
		if not Data.loadoutKeepers.has(x.keeperId):
			x.keeperId = Data.loadoutKeepers.front()

		if GameWorld.unlockedSkins.has(x.keeperId) and not GameWorld.unlockedSkins[x.keeperId].has(x.skinId):
			x.skinId = GameWorld.unlockedSkins[x.keeperId].front()

	if not Data.loadoutGameModes.has(loadout.modeId):
		loadout.modeId = Data.loadoutGameModes.front()
