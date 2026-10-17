extends Control


func _ready():
	GameWorld.boughtUpgrades.append("sword")
	GameWorld.boughtUpgrades.append("keeper1")
	GameWorld.boughtUpgrades.append("laserDome")
	GameWorld.boughtUpgrades.append("laser")
	GameWorld.boughtUpgrades.append("repellent")
	GameWorld.boughtUpgrades.append("stunLaser")
	GameWorld.boughtUpgrades.append("orchard")
	GameWorld.boughtUpgrades.append("repairBot")
	GameWorld.boughtUpgrades.append("blastMining")
	GameWorld.boughtUpgrades.append("lift")
	GameWorld.boughtUpgrades.append("condenser")
	GameWorld.boughtUpgrades.append("shield")
	GameWorld.boughtUpgrades.append("lift")
	GameWorld.boughtUpgrades.append("prospectionMeter")
	find_child("TechTree").build()
	find_child("TechTree").focus()


func _init():
	Data.apply("inventory." + CONST.IRON, 1)
	Data.apply("inventory." + CONST.SAND, 1)
	Data.apply("inventory." + CONST.WATER, 1)
	Options.init()


func _process(delta):
	if Input.is_action_just_pressed("ui_select"):
		find_child("TechTree").buyCurrentUpgrade()
		Data.apply("inventory." + CONST.IRON, 99)
		Data.apply("inventory." + CONST.SAND, 99)
		Data.apply("inventory." + CONST.WATER, 99)
