extends Label

@export var action: String

func _ready():
	var keeper: Keeper = Keepers.first()
	if keeper:
		match action:
			"pickup":
				match keeper.techId:
					"keeper1":
						text = tr("options.keybindings.action.keeper.pickup")
					"keeper2":
						text = tr("options.keybindings.action.keeper.gravitycollect")
			"drop":
				match keeper.techId:
					"keeper1":
						text = tr("options.keybindings.action.keeper.drop")
					"keeper2":
						text = tr("options.keybindings.action.keeper.gravityball")
