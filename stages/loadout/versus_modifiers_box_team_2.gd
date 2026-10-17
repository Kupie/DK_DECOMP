extends VBoxContainer

signal modifiersUpdated
signal playSound(soundName: String)

@export var teamId: String

func _ready():
	var Mbox = find_child("Modifiers")
	var modifiers: Array = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_VERSUSMODIFIERS + teamId, [])
	updateCountLabel(modifiers)

	for x in Mbox.get_children():
		Mbox.remove_child(x)

	if Data.versusModifiers.size() > 0:
		for modifier in Data.versusModifiers:
			var e = preload("res://stages/loadout/LoadoutChoice.tscn").instantiate()
			e.custom_minimum_size.x = 290
			e.toggleable = true
			e.team_exclusive = teamId
			e.selected = modifiers.has(modifier)
			e.setChoice("loadout.versusmod." + modifier, modifier, null, "loadout.versusmod." + modifier + ".desc")
			Mbox.add_child(e)
			e.connect("toggled", modifierSelected.bind(modifier))
	else:
		visible = false

func modifierSelected(toggled: bool, modifier: String):
	var modifiers: Array = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_VERSUSMODIFIERS + teamId, [])
	if toggled:
		if not modifiers.has(modifier):
			if modifiers.size() >= 2:
				playSound.emit("gui_err")
				$CountLabel.pivot_offset = $CountLabel.size * 0.5
				var t: = create_tween()
				t.tween_property($CountLabel, "scale", Vector2.ONE * 1.7, 0.02)
				t.tween_interval(0.2)
				t.tween_property($CountLabel, "scale", Vector2.ONE * 1.0, 0.1)
			else:
				playSound.emit("loadout_modifier_selected")
				modifiers.append(modifier)
	else:
		playSound.emit("loadout_modifier_deselected")
		modifiers.erase(modifier)

	updateCountLabel(modifiers)

	Level.loadout.modeConfig[CONST.MODE_CONFIG_VERSUSMODIFIERS + teamId] = modifiers
	updateModifierLabels()
	modifiersUpdated.emit()

func updateCountLabel(modifiers: Array):
	$CountLabel.text = tr("loadout.versus.modifiers.limit") % [modifiers.size(), 2]

func updateModifierLabels():
	var modifiers: Array = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_VERSUSMODIFIERS + teamId, [])
	for c in find_child("Modifiers").get_children():
		if not c is Label:
			c.selected = modifiers.has(c.id)
	updateCountLabel(modifiers)
