extends PanelContainer

signal mouse_selected

var teamId: String
var id: String
var from: String
var to: String
var resourcesIn: int
var resourcesOut: int
var time: float

var enoughResources: = false

func _ready():
	_on_Conversion_focus_exited()
	find_child("Label2").text = find_child("Label2").text
	$SelectedPanel.visible = false

	add_to_group(teamId + "-conversion_choices")

func canBeSelected() -> bool:
	return enoughResources

func setConversion(id, from, to, resourcesIn, resourcesOut, time):
	self.id = id
	self.from = from
	self.to = to
	self.resourcesIn = resourcesIn
	self.resourcesOut = resourcesOut
	self.time = time

	if resourcesIn < 1.0:
		var factor = 1.0 / float(resourcesIn)
		self.resourcesIn = 1
		self.resourcesOut = factor * resourcesOut

	find_child("LabelTime").text = tr("level.converter.popup.conversion.time").format({"time": "%.2f" % time})
	find_child("Res1").texture = Data.DROP_ICONS.get(from)
	find_child("Res2").texture = Data.DROP_ICONS.get(to)
	find_child("LabelAmount1").text = str(self.resourcesIn)
	find_child("LabelAmount2").text = str(self.resourcesOut)
	updateInventory(from, Data.getInventory(from, teamId))

func updateInventory(type: String, amount: int):
	if type == from:
		if amount >= resourcesIn:
			enoughResources = true
			find_child("LabelAmount1").set("theme_override_colors/font_color", null)
		else:
			enoughResources = false
			find_child("LabelAmount1").set("theme_override_colors/font_color", Style.FONT_COLOR_WARNING)
		updatePanel()

func _on_Conversion_focus_entered():
	$SelectedPanel.visible = true
	Audio.sound("gui_hover")

func _on_Conversion_focus_exited():
	$SelectedPanel.visible = false

func updatePanel():
	if enoughResources:
		set("theme_override_styles/panel", preload("res://gui/buttons/button_normal.tres"))
	else:
		set("theme_override_styles/panel", preload("res://gui/buttons/button_disabled.tres"))

func disable():
	enoughResources = false
	updatePanel()

func _on_Conversion_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_keeper: = Keepers.getLocalMouseUser()
		if is_instance_valid(mouse_keeper) and mouse_keeper.teamId == teamId:
			emit_signal("mouse_selected")

func _on_Conversion_mouse_entered():
	var mouse_keeper: = Keepers.getLocalMouseUser()
	if is_instance_valid(mouse_keeper) and mouse_keeper.teamId == teamId:
		InputSystem.grabFocus(self)
