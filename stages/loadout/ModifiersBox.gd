extends VBoxContainer

signal modifiersUpdated
signal playSound(soundName: String)

func initialize(unlockedRunModifiers: Array):
	var Mbox = find_child("Modifiers")
	var modifiers: Array = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_WORLDMODIFIERS, [])

	for x in Mbox.get_children():
		Mbox.remove_child(x)
		x.queue_free()

	if unlockedRunModifiers.size() > 0:
		for modifier in unlockedRunModifiers:
			var e = preload("res://stages/loadout/LoadoutChoice.tscn").instantiate()
			e.toggleable = true
			e.selected = modifiers.has("worldmodifier" + modifier)
			e.setChoice("loadout.mode." + modifier, "worldmodifier" + modifier, null, "loadout.mode." + modifier + ".desc")
			Mbox.add_child(e)
			e.connect("toggled", modifierSelected.bind("worldmodifier" + modifier))
	else:
		visible = false

func modifierSelected(toggled: bool, modifier: String):
	var modifiers: Array = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_WORLDMODIFIERS, [])
	if toggled:
		playSound.emit("loadout_modifier_selected")
		if not modifiers.has(modifier):
			modifiers.append(modifier)
	else:
		playSound.emit("loadout_modifier_deselected")
		modifiers.erase(modifier)

	Level.loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS] = modifiers
	updateModifierLabels()
	modifiersUpdated.emit()

func updateModifierLabels():
	var modifiers: Array = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_WORLDMODIFIERS, [])
	for c in find_child("Modifiers").get_children():
		if not c is Label:
			c.selected = modifiers.has(c.id)
