extends Control

func _ready():
	Platform.init(false)
	GameWorld.version = "v1.1"
	GameWorld.init()
	Backend.init()
	Options.init()

	Data.apply("team1.prestige.baseperwave", 10)
	Data.apply("team1.prestige.multiplier", 1)
	Data.apply("team1.monsters.cycle", 1)
	Data.apply("team1.prestige.score", 1)
	Data.apply("team1.prestige.sentcobalt", 1)
	Data.apply("inventory.totalsand", 1)

	$RunFinishedPopup.startScoreCount()
