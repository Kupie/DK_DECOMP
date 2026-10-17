extends PanelContainer

signal mouse_selected

var teamId: String

var resource: String

func _ready():
	_on_Conversion_focus_exited()
	$SelectedPanel.visible = false

	Data.listen(self, teamId + ".furnace." + resource + "stack", true)
	Data.listen(self, teamId + ".inventory." + resource, true)
	Data.listen(self, teamId + ".furnace.remainingcycles" + resource + "fuel", true)

	find_child("Res1").texture = Data.DROP_ICONS.get(resource)

	var addRaw = tr("level.furnace.popup.fuel.add")
	var addsplit = addRaw.split("|")
	find_child("LabelAdd1").text = addsplit[0]
	find_child("LabelAdd2").text = addsplit[1]

	var burnRaw = tr("level.furnace.popup.fuel.burn")
	burnRaw = burnRaw.format({"cycles": Data.of(teamId + ".furnace." + resource + "duration"), "seconds": Data.of(teamId + ".furnace." + resource + "delay")})
	var burnsplit = burnRaw.split("|")
	find_child("LabelBurn1").text = burnsplit[0]
	find_child("LabelBurn2").text = burnsplit[1]
	find_child("Res2").texture = Data.DROP_ICONS.get(resource)

	for c in find_child("Stackview").get_children():
		c.texture = Data.DROP_ICONS.get(resource)

	connect("tree_exiting", Data.unlisten.bind(self, teamId + ".furnace." + resource + "stack"))
	connect("tree_exiting", Data.unlisten.bind(self, teamId + ".inventory." + resource))
	updatePanel()

func propertyChanged(property: String, oldValue, newValue):
	var stack: = teamId + ".furnace." + resource + "stack"
	var inventory: = teamId + ".inventory." + resource
	var cycles: = teamId + ".furnace.remainingcycles" + resource + "fuel"
	match property:

		cycles:
			var s = tr("level.furnace.popup.fuel.cycles")
			s = s.format({"cycles": Data.of(teamId + ".furnace.remainingcycles" + resource + "fuel")})
			find_child("LabelCycles").text = s
		stack:
			var i: = 0
			for c in find_child("Stackview").get_children():
				c.visible = i < newValue
				i += 1
			updatePanel()
		inventory:
			updatePanel()

func canBeSelected() -> bool:
	return Data.of(teamId + ".inventory." + resource) >= 1 and Data.of(teamId + ".furnace." + resource + "stack") < Data.of(teamId + ".furnace.max" + resource + "stack")

func setType(type: String):
	self.resource = type

func _on_Conversion_focus_entered():
	$SelectedPanel.visible = true
	Audio.sound("gui_hover")

func _on_Conversion_focus_exited():
	$SelectedPanel.visible = false

func updatePanel():
	if canBeSelected():
		set("theme_override_styles/panel", preload("res://gui/buttons/button_normal.tres"))
	else:
		set("theme_override_styles/panel", preload("res://gui/buttons/button_disabled.tres"))

func _on_Conversion_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_keeper: = Keepers.getLocalMouseUser()
		if is_instance_valid(mouse_keeper) and mouse_keeper.teamId == teamId:
			emit_signal("mouse_selected")

func _on_Conversion_mouse_entered():
	self_modulate.a = 0.5
	var mouse_keeper: = Keepers.getLocalMouseUser()
	if is_instance_valid(mouse_keeper) and mouse_keeper.teamId == teamId:
		InputSystem.grabFocus(self)


func _on_mouse_exited() -> void :
	self_modulate.a = 1.0
