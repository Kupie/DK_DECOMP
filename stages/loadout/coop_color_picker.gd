extends GridContainer

signal playSound(soundName: String)

func _ready():
	for c in get_children():
		c.connect("on_selected", setColor)
		c.playSound.connect( func(soundName: String): playSound.emit(soundName))

func setColor(colorId: String, keeper: Keeper):
	Lobby.update_color.rpc(
		int(keeper.playerId.lstrip("player")), 
		int(colorId.lstrip("color"))
	)
