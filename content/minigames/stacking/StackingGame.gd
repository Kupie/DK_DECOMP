extends Node2D


func _ready():
	Style.init(self)
	Style.setPalette("palette_3_1")
	GameWorld.prepareCleanData()
	GameWorld.unlockGadget("keeper1")
	Level.map = $Map
	Level.stage = self



	var kip1 = preload("res://content/keeper/Keeper1InputProcessor.gd").new()
	kip1.keeper = $Keeper1
	kip1.integrate(self)
