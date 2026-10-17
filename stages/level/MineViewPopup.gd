extends Container

signal stop_mine_view

@export var basePos: = 0
var isIn: = false

@onready var _action_move_up: Action = $PanelContainer / HBoxContainer / MoveContainer / ActionMoveUp
@onready var _action_move_left: Action = $PanelContainer / HBoxContainer / MoveContainer / ActionMoveLeft
@onready var _action_move_down: Action = $PanelContainer / HBoxContainer / MoveContainer / ActionMoveDown
@onready var _action_move_right: Action = $PanelContainer / HBoxContainer / MoveContainer / ActionMoveRight
@onready var _action_reveal_resources: Action = $PanelContainer / HBoxContainer / RevealResourcesContainer / ActionRevealResources
@onready var _action_auto_move: Action = $PanelContainer / HBoxContainer / AutoMoveContainer / ActionAutoMove
@onready var _action_exit: Action = $PanelContainer / HBoxContainer / ExitContainer / ActionExit
@onready var _all_actions: Array[Action] = [_action_move_up, _action_move_left, _action_move_down, 
	_action_move_right, _action_reveal_resources, _action_auto_move, _action_exit]

var _lastDevice: String

func _ready():
	if basePos == 0:
		position.y += size.y
	elif basePos == -1:
		position.x = - size.x
	elif basePos == 1:
		position.x = get_viewport_rect().size.x + size.x

	Style.init(self)

func updateDevice(inEvent: InputEvent) -> void :
	var isGamepad: bool = (inEvent is InputEventJoypadMotion) or (inEvent is InputEventJoypadButton)
	var isKeyboardMouse: bool = (inEvent is InputEventKey) or (inEvent is InputEventMouseButton)
	if isGamepad and _lastDevice == "gamepad":
		return
	if isKeyboardMouse and _lastDevice == "keyboard":
		return

	if isGamepad:
		_lastDevice = "gamepad"
		for action: Action in _all_actions:
			action.mode = "gamepad"
			action.forceMode = true
			action.updateGlyphs()
	elif isKeyboardMouse:
		_lastDevice = "keyboard"
		for action: Action in _all_actions:
			action.mode = "keyboard"
			action.forceMode = true
			action.updateGlyphs()

func moveIn(delay: = false):
	if isIn:
		return

	isIn = true
	$Tween.stop_all()
	$Tween.remove_all()
	var s = get_viewport_rect().size
	$Tween.interpolate_property(self, "position", position, Vector2(s.x * anchor_left - size.x * 0.5, s.y - size.y), 0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0.3 if delay else 0.0)
	$Tween.start()

func hideRevealResourcesContainer():
	find_child("RevealResourcesContainer").visible = false

func moveOut(dir: = 0):
	if not isIn:
		return

	isIn = false
	$Tween.stop_all()
	$Tween.remove_all()
	var s = get_viewport_rect().size
	if dir == 0:
		$Tween.interpolate_property(self, "position:y", position.y, s.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	elif dir == -1:
		$Tween.interpolate_property(self, "position:x", position.x, - size.x, 0.45, Tween.TRANS_CUBIC, Tween.EASE_IN)
	elif dir == 1:
		$Tween.interpolate_property(self, "position:x", position.x, s.x, 0.45, Tween.TRANS_CUBIC, Tween.EASE_IN)

	$Tween.interpolate_callback(self, 0.45, "emit_signal", "stop_mine_view")
	$Tween.start()

func updateForAutoMove():
	if GameWorld.autoMoveCameraInMineView:
		find_child("AutoMoveLabel").text = tr("level.gameover.automove")
	else:
		find_child("AutoMoveLabel").text = tr("level.gameover.manualmove")
