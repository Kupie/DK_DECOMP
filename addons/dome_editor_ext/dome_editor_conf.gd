extends Resource
class_name DomeEditorConf

@export var custom_play_pressed: bool
@export var play_mode: Const.ENTER_PLAY_MODE
@export var nmb_of_players: Const.ENTER_PLAYERS_NMB
@export var p1_keeper: String = "keeper1"
@export var p2_keeper: String = "keeper1"
@export var p1_dome: Const.ENTER_DOME = Const.ENTER_DOME.DOME_1
@export var p2_dome: Const.ENTER_DOME = Const.ENTER_DOME.DOME_1
@export var p1_primaryGadgetid: String = "shield"
@export var p2_primaryGadgetid: String = "shield"
@export var game_mode: Const.ENTER_GAME_MODE
@export var multiplayer_mode: Const.DEV_ENTER_MULTIPLAYER_MODE
@export var restore_windows_upon_startup: bool = false
