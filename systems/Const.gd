extends Node

class_name Const

enum BUILD_TYPE{FULL, DEMO, PLAYTEST, EXHIBITION}
enum ENTER_PLAY_MODE{Level, Title, Loadout}
enum ENTER_GAME_MODE{RELIC, VERSUS}
enum ENTER_PLAYERS_NMB{ONE_PLAYER, TWO_PLAYERS}
enum ENTER_DOME{DOME_1, DOME_2, DOME_3, DOME_4}
const ENTER_DOME_TO_STRING_ID: = {
	ENTER_DOME.DOME_1: "dome1", 
	ENTER_DOME.DOME_2: "dome2", 
	ENTER_DOME.DOME_3: "dome3", 
	ENTER_DOME.DOME_4: "dome4", 
}
enum DEV_ENTER_MULTIPLAYER_MODE{SINGLE, SPLIT, NETWORK}

var DIRECTIONS: = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
var DIAGONALS: = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
var DIRECTIONS_AND_DIAGONALS: = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
const PATHFINDING_OFFSETS: = [Vector2(), Vector2(0, 24), Vector2(0, -24), Vector2(24, 0), Vector2(-24, 0)]

const MAX_NMB_OF_PLAYERS: = 8

const BASE_RESOLUTION: = Vector2(1920, 1080)

const LEFT: = "left"
const RIGHT: = "right"
const TOP: = "top"
const CENTER: = "center"
const LEFT_LOW: = "left_low"
const RIGHT_LOW: = "right_low"
const LEFT_HIGH: = "left_high"
const RIGHT_HIGH: = "right_high"

const CANVAS_LAYER_BIT_ALL = 0
const CANVAS_LAYER_BIT_FIRST_LOCAL_PLAYER = 1
const CANVAS_LAYER_BIT_SECOND_LOCAL_PLAYER = 2
const CANVAS_LAYER_BIT_THIRD_LOCAL_PLAYER = 3
const CANVAS_LAYER_BIT_FOURTH_LOCAL_PLAYER = 4

const MONSTER_SPAWN_FLY_TOP: = "fly_top_center"
const MONSTER_SPAWN_FLY_TOP_CORNER_LEFT: = "fly_top_corner_left"
const MONSTER_SPAWN_FLY_TOP_CORNER_RIGHT: = "fly_top_corner_right"
const MONSTER_SPAWN_FLY_LOW_LEFT: = "fly_low_left"
const MONSTER_SPAWN_FLY_HIGH_LEFT: = "fly_high_left"
const MONSTER_SPAWN_FLY_LOW_LEFT_LOW: = "fly_low_left_low"
const MONSTER_SPAWN_FLY_LOW_RIGHT: = "fly_low_right"
const MONSTER_SPAWN_FLY_HIGH_RIGHT: = "fly_high_right"
const MONSTER_SPAWN_FLY_LOW_RIGHT_LOW: = "fly_low_right_low"
const MONSTER_SPAWN_FLY_LEFT: = "fly_onscreen_left"
const MONSTER_SPAWN_FLY_RIGHT: = "fly_onscreen_right"
const MONSTER_SPAWN_FLY_CENTER: = "fly_onscreen_center"

const BORDER: = "border"
const IRON: = "iron"
const WATER: = "water"
const SAND: = "sand"
const GADGET: = "gadget"
const RELIC: = "relic"
const RELICSWITCH: = "relicswitch"
const POWERCORE: = "powercore"
const NEST: = "nest"
const EGG: = "egg"
const SEED: = "seed"
const TREAT: = "treat"
const PACK: = "pack"
const CAVEBOMB: = "cavebomb"
const SPORE: = "spore"
const MINE: = "mine"
const DRILLBOT: = "drillbot"
const EXTRACTOR: = "extractor"
const TELEPORTER: = "teleporter"

const MONSTER_SMALL: = "small"
const MONSTER_MEDIUM: = "medium"
const MONSTER_LARGE: = "large"

const MODE_CONFIG_MAP_ARCHETYPE = "mapsize"
const MODE_CONFIG_WORLDMODIFIERS = "world-modifiers"
const MODE_CONFIG_PRESTIGE_VARIANT = "variant"
const MODE_CONFIG_PRESTIGE_FRIENDLY_MODE = "friendly-mode"
const MODE_CONFIG_ASSIGNMENT = "assignment"
const MODE_CONFIG_ASSIGNMENT_CHALLENGE_MODE = "challenge-mode"

const MODE_CONFIG_ADDITIONAL_GADGETS = "additional-gadgets"
const MODE_CONFIG_VERSUSMODIFIERS = "versus-modifiers-"
const MODE_CONFIG_VERSUS_WINCONDITION = "versus-wincondition"

const MAP_SMALL: = "regular-small"
const MAP_MEDIUM: = "regular-medium"
const MAP_LARGE: = "regular-large"
const MAP_HUGE: = "regular-huge"

const LOADOUT_DOME: = "dome"
const LOADOUT_KEEPER: = "keeper"
const LOADOUT_GAMEMODE: = "gamemode"
const LOADOUT_GADGET: = "gadget"

const LAYER_TILE_COLLISION = 1
const LAYER_DROP_COLLISION = 2
const LAYER_USABLES = 3
const LAYER_DROP_DOME_BORDER = 4
const LAYER_TUNNEL_PARTICLES = 5
const LAYER_CARRYABLES = 6
const LAYER_DOME_DROP = 7
const LAYER_WEAPONS = 8
const LAYER_MONSTER_PROJECTILES = 9
const LAYER_DOME_EXTERNAL = 10
const LAYER_LIFT_RIGID = 11
const LAYER_LIFT_KINEMATIC = 12
const LAYER_SWARM = 13
const LAYER_DRONES = 14
const LAYER_PLAYER = 15
const LAYER_TILE_COLLISION_GADGETS = 16
const LAYER_BACK_LAYER_COLLISIONS = 17
const LAYER_WEAPONS_ENVIRONMENT = 18
const LAYER_KEEPER_PROJECTILE = 21
const LAYER_BLOCKER_TEAM_1 = 28
const LAYER_BLOCKER_TEAM_2 = 29
const LAYER_CARRIED_DROP_COLLISION = 30
const LAYER_KUNAI_CARRIED_DROP_COLLISION = 31
const LAYER_TENTACLE_ATTACHABLE = 32

const DOME_CELLAR_ENTRANCE_Y = 33
const DOME_SECONDARY_STATION_ENTRANCE_Y = 63
const DOME_SECONDARY_STATION_ENTRANCE_X = -18
const DOME_CUPOLA_ENTRANCE_Y = -8

const VERSUS_IRONDELIVERY_WIN: = 200

const MODE_ASSIGNMENTS = "assignments"
const MODE_RELICHUNT = "relichunt"
const MODE_PRESTIGE = "prestige"
const MODE_COLONIZATION = "colonization"
const MODE_COOP = "coop"
const MODE_VERSUS = "versus"
const MODE_PRESTIGE_ENDLESS = "prestige-endless"
const MODE_PRESTIGE_COUNTDOWN = "prestige-countdown"
const MODE_PRESTIGE_MINER = "prestige-miner"
const MODE_PRESTIGE_PRO = "prestige-pro"
const MODE_PRESTIGE_PROVOCATION = "prestige-provocation"
const MODE_PRESTIGE_COBALT = "prestige-cobalt"

const MODE_ASSIGNMENT_MINOR_VISION = "minorvision"

const MODE_VERSUS_WINCONDITION_DEATHMATCH = "deathmatch"
const MODE_VERSUS_WINCONDITION_IRONDELIVERY = "irondelivery"

const DIFFICULTY_RELAXED = "difficulty-relaxed"
const DIFFICULTY_HARD = "difficulty-hard"
const DIFFICULTY_BRUTAL = "difficulty-brutal"
const DIFFICULTY_YAFI = "difficulty-yafi"

const TILE_OFFSET: = Vector2(0, 82)
const TILEMAP_INVALID_CELL: int = -1

const TUTORIAL_LISTENING: = 1
const TUTORIAL_DISPLAYING: = 2
const TUTORIAL_TIMEDOUT: = 3
const TUTORIAL_CONFIRMED: = 4

const PixelPerKilometer: = 0.00012

const PI_HALF: float = PI * 0.5

const EDITOR_CONF_PATH: = "res://addons/dome_editor_ext/dome_editor_conf.tres"

const INPUT_ACTIONS = {
	"ui": [
		"ui_select", 
		"ui_cancel", 
		"ui_up", 
		"ui_left", 
		"ui_down", 
		"ui_right", 
	], 
	"keeper": [
		"keeper_gadget1", 
		"keeper_gadget2", 
	], 
	"keeper1": [
		"keeper1_pickup", 
		"keeper1_drop", 
	], 
	"keeper2": [
		"keeper2_gravityball", 
		"keeper2_gravitycollect", 
	], 
	"dome": [
		"dome_fire", 
		"dome_special", 
		"dome_ability1", 
		"dome_ability2", 
		"dome_upgrades", 
		"dome_battle", 
	], 
}

const PRESTIGE_WHITELIST_MOD_IDS: = [
	"HelloWorld-RunLogger", 
	"Ste-Petmagotchi", 
	"Ste-PrestigeQuickRestart", 
	"nanimonull-TechTreeLoopSelect", 
	"KANA-HellowThere", 
	"AshAxolotl-AmongTick", 
	"hello_world-KillSwitch", 
	"hello_world-GadgetSelect", 
	"hello_world-SkinPack", 
	"TeamSpeed-Timer", 

	]

const difficultyStringByInt: = {
	2: "loadout.difficulty.hard", 
	0: "loadout.difficulty.medium", 
	-1: "loadout.difficulty.easy", 
	-2: "loadout.difficulty.veryeasy"}

const difficultyIdByInt: = {
	2: DIFFICULTY_YAFI, 
	0: DIFFICULTY_BRUTAL, 
	-1: DIFFICULTY_HARD, 
	-2: DIFFICULTY_RELAXED}

const mapSizesStringsById: = {
	MAP_SMALL: "loadout.mapsize.small", 
	MAP_MEDIUM: "loadout.mapsize.medium", 
	MAP_LARGE: "loadout.mapsize.large", 
	MAP_HUGE: "loadout.mapsize.huge"}


static func equal(a, b) -> bool:
	return a == b

static func not_equal(a, b) -> bool:
	return a != b

static func greater_than_equal(a, b) -> bool:
	return a >= b

static func less_than_equal(a, b) -> bool:
	return a <= b

static var COMPARISONS: = {
	"==" = equal, 
	"!=" = not_equal, 
	">=" = greater_than_equal, 
	"<=" = less_than_equal, 
}

const SHOW_MESSAGE: = "show-message"
const RESOURCE_PACKER_SPRITE_NAME: = "ResourceSprite"

const PLATFORM_ID_STEAM: = "steam"
const PLATFORM_ID_XBOX: = "XBL"
const PLATFORM_ID_PSN: = "psn"
const PLATFORM_ID_SWITCH: = "switch"
const PLATFORM_ID_DUMMY: = "dummy"
