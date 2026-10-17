extends Container

signal focus_changed
signal selected_by_mouse
signal reroll_requested

var teamId: String
var playerId: String

var isIn: = false
var animationDone: bool

var droptype: String = CONST.GADGET
var selectedGadget = null

var offersById: Dictionary = {}
var inputProcessor: InputProcessor

func _ready():
	visible = true
	position.y += get_parent().size.y

	Level.stage.offersGenerated.connect(onOffersGenerated)
	inputProcessor.justBecameLeaf.connect(_on_inputprocessor_becameLeaf)

	if droptype == CONST.POWERCORE:
		%TitleLabel.text = tr("level.supplementchoice.title")

	Data.listen(self, teamId + ".inventory.water")

	Style.init(self)

func _on_inputprocessor_becameLeaf() -> void :
	InputSystem.grabFocusIfNone( %Gadgets.get_children().front())

func on_reroll_focused():
	selectedGadget = null

func propertyChanged(property: String, oldValue, newValue):
	%RerollButton.disabled = Data.ofOr(teamId + ".inventory.water", 0) <= 0

func onOffersGenerated(forPlayerId: String, offers: Array[Dictionary], rerollPossible: bool, rerollCost: int, freeRerolls: int) -> void :
	if playerId != forPlayerId:
		return

	offersById.clear()
	%RerollButton.visible = rerollPossible
	if rerollCost == 0:
		%RerollButton.text = tr("level.supplementchoice.reroll.free") % [freeRerolls]
		%RerollButton.icon = null
	else:
		%RerollButton.text = "level.supplementchoice.reroll"
		%RerollButton.disabled = Data.ofOr(teamId + ".inventory.water", 0) <= 0
		%RerollButton.icon = preload("res://content/icons/icon_water.png")

	for c in %Gadgets.get_children():
		%Gadgets.remove_child(c)
		c.queue_free()

	var count = offers.size()

	if count % 2 == 0 and count <= 4 or Keepers.isSplitScreen:
		find_child("Gadgets").columns = 2
	else:
		find_child("Gadgets").columns = 3

	for g in offers:
		var id: String = g.get("id", "missing_id")
		var choice: PanelContainer
		if droptype == CONST.POWERCORE:
			choice = preload("res://stages/level/SupplementChoice.tscn").instantiate()
			choice.playerId = playerId
			choice.teamId = teamId
			choice.fillSupplement(g)
		else:
			choice = preload("res://stages/level/GadgetChoice.tscn").instantiate()
			choice.playerId = playerId
			choice.teamId = teamId
			choice.fillGadget(g)

		choice.name = id
		choice.teamId = teamId
		offersById[id] = choice
		%Gadgets.add_child(choice)

		choice.connect("focussed", optionFocussed.bind(g, choice))
		choice.connect("selected", emit_signal.bind("selected_by_mouse"))

	InputSystem.grabFocusIfNone( %Gadgets.get_children().front())

func optionFocussed(gadgetData: Dictionary, panel):
	if isIn:
		Audio.sound("gui_move")
	for g in %Gadgets.get_children():
		g._on_GadgetChoice_focus_exited()
	if panel:
		panel.setFocus()
	selectedGadget = gadgetData
	focus_changed.emit()

func _on_reroll_button_focus_entered() -> void :
	optionFocussed({"reroll": 1}, null)

func moveIn():
	if isIn:
		return

	isIn = true
	animationDone = false
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property(self, "position:y", position.y, 0, 0.6, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$Tween.interpolate_callback(self, 0.7, "set", "animationDone", true)
	$Tween.start()

func moveOut():
	if not isIn:
		return

	for c in %Gadgets.get_children():
		if c.has_focus():
			c.release_focus()

	isIn = false
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property(self, "position:y", position.y, get_viewport_rect().size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	if inputProcessor.desintegrating:
		$Tween.interpolate_callback(self, 0.3, "queue_free")
	$Tween.start()

func _on_reroll_button_pressed():
	Audio.sound("gui_select")
	Network.rpc_server(Level.stage.rerollOffers.bind(teamId, playerId))

func disableChoicesForSlots(availableGadgetIds: Array[String]) -> void :
	var needNewFocus: = false
	for c in %Gadgets.get_children():
		if c.isShred:
			continue
		if not availableGadgetIds.has(c.gadgetId):
			if c.has_focus():
				needNewFocus = true
			c.disable()

	if needNewFocus:
		for c in %Gadgets.get_children():
			if c.disabled:
				continue
			c.grab_focus()
			break
