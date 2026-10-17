extends Control

signal fuel_selected

var teamId: String

const transitionTime: = 0.3
var isIn: = false

func _ready():
	$Container.position.y += get_viewport_rect().size.y
	$ColorRect.color = Style.OVERLAY_COLOR_OUT
	$ColorRect.visible = false

	var container = find_child("FuelOptionsContainer")
	var maxIron = Data.of(teamId + ".furnace.maxironstack")
	if maxIron > 0:
		var option = preload("res://content/gadgets/furnace/FuelOption.tscn").instantiate()
		option.teamId = teamId
		option.setType("iron")
		container.add_child(option)
		option.connect("mouse_selected", emit_signal.bind("fuel_selected", option))
	var maxWater = Data.of(teamId + ".furnace.maxwaterstack")
	if maxWater > 0:
		var option = preload("res://content/gadgets/furnace/FuelOption.tscn").instantiate()
		option.teamId = teamId
		option.setType("water")
		container.add_child(option)
		option.connect("mouse_selected", emit_signal.bind("fuel_selected", option))

	Style.init(self)

func getFocussedOption():
	for c in find_child("FuelOptionsContainer").get_children():
		if c.has_focus():
			return c
	return null

func moveIn():
	if isIn:
		return

	isIn = true
	$OpenSound.startSound()
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property($ColorRect, "color", $ColorRect.color, Style.OVERLAY_COLOR_IN, transitionTime)
	$Tween.interpolate_property($Container, "position:y", $Container.position.y, 0, 0.6, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$Tween.start()

	find_child("CancelButton").grab_focus()

func moveOut():
	if not isIn:
		return

	for c in find_child("FuelOptionsContainer").get_children():
		if c.has_focus():
			c.release_focus()

	isIn = false
	$CloseSound.startSound()
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property($ColorRect, "color", $ColorRect.color, Style.OVERLAY_COLOR_OUT, transitionTime, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.interpolate_property($Container, "position:y", $Container.position.y, get_viewport_rect().size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	$Tween.interpolate_callback(self, transitionTime, "queue_free")
	$Tween.start()
