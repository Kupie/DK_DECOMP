extends Node

func _ready():
	GameWorld.pause()
	GameWorld.setShowMouse(true)
	InputSystem.grabFocus( %Button)
	Style.init(self)

func _on_Button_pressed():
	GameWorld.unpause()
	GameWorld.notifyDamagedMetaFile = false
	queue_free()
