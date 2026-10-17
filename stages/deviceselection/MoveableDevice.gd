extends Node2D

signal selected
signal deselected

var enabled: = true

func _ready():
	Style.init(self)
	$ActionHint.visible = false














func asKeyboard():
	%Sprite2D.texture = preload("res://stages/loadout/keyboard.png")
	$ActionHint.visible = true
	$ActionHint / Action.mode = "keyboard"

func asGamepad():
	%Sprite2D.texture = preload("res://stages/loadout/gamepad.png")
	$ActionHint.visible = true
	$ActionHint / Action.mode = "gamepad"

func asRemoteSteam():
	%Sprite2D.texture = preload("res://gui/platform/Platform_icon_Steam.png")
	$ActionHint.visible = false

func asRemoteXbox():
	%Sprite2D.texture = preload("res://gui/platform/Platform_icon_Xbox.png")
	$ActionHint.visible = false

func asRemotePlaystation():
	%Sprite2D.texture = preload("res://gui/platform/Platform_icon_PlayStation.png")
	$ActionHint.visible = false

func asRemoteSwitch():
	%Sprite2D.texture = preload("res://gui/platform/Platform_icon_Switch.png")
	$ActionHint.visible = false
