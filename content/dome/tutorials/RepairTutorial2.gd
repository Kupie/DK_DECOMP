extends Tutorial

var lastHealth: int

func _ready():
	super._ready()
	lastHealth = Data.of("team1.dome.health")
	listen("team1.dome.health")

func propertyChanged(property: String, oldValue, newValue):
	match property:

		"team1.dome.health":
			if not oldValue or not lastHealth:
				lastHealth = newValue
				return
			if newValue > lastHealth:
				confirm()
			lastHealth = newValue

func process_trigger(delta: float) -> bool:
	return lastHealth < 400 and Data.of("team1.inventory.sand") > 0
