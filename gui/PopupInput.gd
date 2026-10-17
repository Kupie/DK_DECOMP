extends "res://systems/input/InputProcessor.gd"

signal stopping
signal confirmed

var popup
var blockAllKeys: = false
var animated: = false
var animationTime: = 0.3
var blockStickMove: = false

var _stopping: = false
var explicitName: = false
var canClose: = true
var tween: DeprecatedTween
var focusControlOnLeaf

func _ready():
	if not explicitName:
		name = "PopupInput"
	if animated:
		tween = DeprecatedTween.new()
		add_child(tween)
		popup.initAnimation()

func setName(n: String):
	explicitName = true
	name = n

func handleStart():
	if animated:
		popup.fadeIn(animationTime)
	var cb = popup.find_child("CancelButton")
	if cb:
		cb.connect("pressed", cancel)

func becameLeaf():
	if focusControlOnLeaf:
		InputSystem.grabFocus(focusControlOnLeaf)
	if not Options.useGamepad(deviceId):
		GameWorld.setShowMouse(Options.useMouseMenus)
		InputSystem.changeCursor("default")

func cancel():
	desintegrate()

func handleStop():
	emit_signal("stopping")

func buttonEvent(event) -> bool:
	if canClose and (justPressed(event, "ui_cancel") or justPressed(event, "escape")):
		close()
		return true
	elif justPressed(event, "ui_select"):
		emit_signal("confirmed")
		return true
	elif justPressed(event, "cheats"):

		return false

	return blockAllKeys

func close():
	if animated:
		if not _stopping:
			_stopping = true
			popup.fadeOut(animationTime)
			tween.interpolate_callback(self, animationTime, "desintegrate")
			tween.start()
	else:
		desintegrate()

func stick_move(event: InputEventJoypadMotion) -> bool:
	return blockStickMove
