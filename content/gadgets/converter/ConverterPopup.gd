extends Control

signal conversion_selected
signal queue_selected(value: bool)

@export var autoQueueCheckBox: CheckBox

var teamId: String

const transitionTime: = 0.3
var isIn: = false
var currentConversionId: String

func setCurrentConversion(currentConversion: String, remainingTime):
	self.currentConversionId = currentConversion
	%LabelInProgress.text = tr("level.converter.popup.queue.block").format({"time": int(ceil(remainingTime))})

func _ready():
	$Container.position.y += get_viewport_rect().size.y
	$ColorRect.color = Style.OVERLAY_COLOR_OUT
	$ColorRect.visible = false
	autoQueueCheckBox.visible = Data.of(teamId + ".converter.queue")
	autoQueueCheckBox.set_pressed_no_signal(Data.of(teamId + ".converter.queueselected"))
	var container = find_child("ConversionsContainer")

	var ratio = Data.of(teamId + ".converter.watertoiron")
	if ratio > 0 and (currentConversionId == "" or currentConversionId == "watertoiron"):
		var con = preload("res://content/gadgets/converter/Conversion.tscn").instantiate()
		con.teamId = teamId
		con.setConversion("watertoiron", "water", "iron", 1, ratio, Data.of(teamId + ".converter.ironwatertime"))
		container.add_child(con)
		con.connect("mouse_selected", emit_signal.bind("conversion_selected", con))

	ratio = Data.of(teamId + ".converter.ironperwater")
	if ratio > 0 and (currentConversionId == "" or currentConversionId == "ironperwater"):
		var con = preload("res://content/gadgets/converter/Conversion.tscn").instantiate()
		con.teamId = teamId
		con.setConversion("ironperwater", "iron", "water", ratio, 1, Data.of(teamId + ".converter.ironwatertime"))
		container.add_child(con)
		con.connect("mouse_selected", emit_signal.bind("conversion_selected", con))

	ratio = Data.of(teamId + ".converter.ironpercobalt")
	if ratio > 0 and (currentConversionId == "" or currentConversionId == "ironpercobalt"):
		var con = preload("res://content/gadgets/converter/Conversion.tscn").instantiate()
		con.teamId = teamId
		con.setConversion("ironpercobalt", "iron", "sand", ratio, 1, Data.of(teamId + ".converter.ironcobalttime"))
		container.add_child(con)
		con.connect("mouse_selected", emit_signal.bind("conversion_selected", con))

	ratio = Data.of(teamId + ".converter.cobalttoiron")
	if ratio > 0 and (currentConversionId == "" or currentConversionId == "cobalttoiron"):
		var con = preload("res://content/gadgets/converter/Conversion.tscn").instantiate()
		con.teamId = teamId
		con.setConversion("cobalttoiron", "sand", "iron", 1, ratio, Data.of(teamId + ".converter.ironcobalttime"))
		container.add_child(con)
		con.connect("mouse_selected", emit_signal.bind("conversion_selected", con))

	ratio = Data.of(teamId + ".converter.irontoiron")
	if ratio > 0 and (currentConversionId == "" or currentConversionId == "irontoiron"):
		var con = preload("res://content/gadgets/converter/Conversion.tscn").instantiate()
		con.teamId = teamId
		con.setConversion("irontoiron", "iron", "iron", 1, ratio, Data.of(teamId + ".converter.ironirontime"))
		container.add_child(con)
		con.connect("mouse_selected", emit_signal.bind("conversion_selected", con))

	if currentConversionId == "":
		%LabelPick.visible = true
		%LabelInProgress.visible = false
	else:
		%LabelPick.visible = false
		%LabelInProgress.visible = true
		for c in get_tree().get_nodes_in_group(teamId + "-conversion_choices"):
			c.disable()

	Style.init(self)

	Data.listen(self, teamId + ".inventory.iron")
	Data.listen(self, teamId + ".inventory.water")
	Data.listen(self, teamId + ".inventory.sand")

func getFocussedOption():
	for c in find_child("ConversionsContainer").get_children():
		if c.has_focus():
			return c
	return null

func propertyChanged(property: String, oldValue, newValue):
	if currentConversionId != "":
		return
	if property == teamId + ".inventory.iron":
		for c in find_child("ConversionsContainer").get_children():
			c.updateInventory("iron", newValue)
	elif property == teamId + ".inventory.water":
		for c in find_child("ConversionsContainer").get_children():
			c.updateInventory("water", newValue)
	elif property == teamId + ".inventory.sand":
		for c in find_child("ConversionsContainer").get_children():
			c.updateInventory("sand", newValue)

func moveIn():
	if isIn:
		return

	isIn = true
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property($ColorRect, "color", $ColorRect.color, Style.OVERLAY_COLOR_IN, transitionTime)
	$Tween.interpolate_property($Container, "position:y", $Container.position.y, 0, 0.6, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$Tween.start()

	find_child("CancelButton").grab_focus()

func moveOut():
	if not isIn:
		return

	for c in find_child("ConversionsContainer").get_children():
		if c.has_focus():
			c.release_focus()

	Data.unlisten(self, teamId + ".inventory.iron")
	Data.unlisten(self, teamId + ".inventory.water")
	Data.unlisten(self, teamId + ".inventory.sand")

	isIn = false
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property($ColorRect, "color", $ColorRect.color, Style.OVERLAY_COLOR_OUT, transitionTime, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.interpolate_property($Container, "position:y", $Container.position.y, get_viewport_rect().size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	$Tween.interpolate_callback(self, transitionTime, "queue_free")
	$Tween.start()

func _on_auto_queue_check_box_toggled(toggled_on: bool) -> void :
	queue_selected.emit(toggled_on)
