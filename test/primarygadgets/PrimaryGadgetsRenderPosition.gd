extends Node2D

func _ready():
	Data.apply("team1.monsters.waveinterval", false)
	Data.apply("team1.monsters.wavebattle", false)
	Data.apply("team1.monsters.additionalcycletime", 0)
	Data.apply("team1.monsters.waveinterval", 0)
	Data.apply("team1.monsters.wavepresent", false)
	Data.apply("team1.monsters.wavedelay", 0)
	Level.map = $Mock

	GameWorld.addUpgrade("orchard")
	GameWorld.addUpgrade("repellent")
	GameWorld.addUpgrade("shield")

	$Dome1_1.find_child("Shield").queue_free()
	$Dome1_2.find_child("Shield").queue_free()
	$Dome2_1.find_child("Shield").queue_free()
	$Dome2_2.find_child("Shield").queue_free()
	$Dome3_1.find_child("Shield").queue_free()
	$Dome3_2.find_child("Shield").queue_free()
	$Dome4_1.find_child("Shield").queue_free()
	$Dome4_2.find_child("Shield").queue_free()

	$Dome1_1.unlockGadget(Data.gadgets.get("orchard"))
	$Dome1_2.unlockGadget(Data.gadgets.get("repellent"))
	$Dome1_3.unlockGadget(Data.gadgets.get("shield"))
	$Dome2_1.unlockGadget(Data.gadgets.get("orchard"))
	$Dome2_2.unlockGadget(Data.gadgets.get("repellent"))
	$Dome2_3.unlockGadget(Data.gadgets.get("shield"))
	$Dome3_1.unlockGadget(Data.gadgets.get("orchard"))
	$Dome3_2.unlockGadget(Data.gadgets.get("repellent"))
	$Dome3_3.unlockGadget(Data.gadgets.get("shield"))
	$Dome4_1.unlockGadget(Data.gadgets.get("orchard"))
	$Dome4_2.unlockGadget(Data.gadgets.get("repellent"))
	$Dome4_3.unlockGadget(Data.gadgets.get("shield"))
	Data.apply("team1.shield.stage", 1)
	Data.apply("team1.shield.strength", Data.of("team1.shield.maxStrength"))


func _process(delta: float) -> void :
	if Input.is_action_just_pressed("cheats"):
		Data.changeByInt("team1.shield.stage", -1)
	elif Input.is_action_just_pressed("f2"):
		Data.changeByInt("team1.shield.stage", 1)
