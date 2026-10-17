extends PanelContainer

var currentlySelected = null
var firstOption = null

func init(is_server: bool):
	if not is_server:
		visible = false
		return

	var gadgets: = []
	for g: String in Data.gadgets:
		if Data.gadgets[g].get("type", "nope") == "gadget":
			for upgrade: String in GameWorld.boughtUpgrades:
				var baseUpgradeId: = upgrade.split(".")[1]
				if baseUpgradeId == g:
					gadgets.append(g)
					break

	for g in Level.loadout.domes.front().additionalGadgets:
		gadgets.erase(g)

	if gadgets.size() == 0:
		visible = false
		return

	for id in gadgets:
		var choice = preload("res://content/gamemode/gadgetchoice/GadgetOption.tscn").instantiate()
		choice.init(id)
		choice.connect("selected", gadgetSelected.bind(choice))
		find_child("GadgetContainer").add_child(choice)
		if GameWorld.gadgetToKeep == id:
			choice.select()
			firstOption = choice
			currentlySelected = choice
		if not firstOption:
			firstOption = choice

	if not currentlySelected:
		GameWorld.gadgetToKeep = ""

	updateKeepingLabel()
	GameWorld.keptGadgetUsed = false

	Style.init(self)

func updateKeepingLabel():
	var gadgetName: String
	if currentlySelected:
		gadgetName = tr("upgrades." + GameWorld.gadgetToKeep + ".title")
		find_child("SelectedGadgetLabel").text = tr("level.gameover.keepgadget.keeping").format({"gadget": gadgetName})
	else:
		gadgetName = tr("level.gameover.keepgadget.none")
		find_child("SelectedGadgetLabel").text = "[wave amp=20 freq=6]" + tr("level.gameover.keepgadget.keeping").format({"gadget": gadgetName}) + "[/wave]"

func gadgetSelected(gadgetPanel):
	Audio.sound("gui_select")

	if currentlySelected:
		currentlySelected.deselect()
		if currentlySelected == gadgetPanel:
			GameWorld.gadgetToKeep = ""
			currentlySelected = null
			updateKeepingLabel()
			return

	currentlySelected = gadgetPanel
	currentlySelected.select()
	GameWorld.gadgetToKeep = gadgetPanel.id
	GameWorld.keptGadgetUsed = false
	SaveGame.saveRollingMetaState()
	updateKeepingLabel()

func getFirstOption():
	return firstOption
