extends Tutorial

var lastKnownPosByKeeper = {}

func _ready():
	super._ready()
	lastKnownPosByKeeper[keeper] = keeper.position

func process_trigger(delta: float) -> bool:
	if keeper.isInsideDome and not keeper.isInsideStation:
		return true
	return false

func process_confirm(delta: float):


	if lastKnownPosByKeeper.has(keeper):
		lastKnownPosByKeeper[keeper] = keeper.position
	var d = lastKnownPosByKeeper[keeper].distance_to(keeper.position)
	if d > 50.0:
		confirm()
		return
	lastKnownPosByKeeper[keeper] = keeper.position
