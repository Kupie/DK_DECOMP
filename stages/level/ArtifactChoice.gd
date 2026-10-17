extends PanelContainer

const BUTTON_DISABLED_STYLE = preload("res://gui/buttons/button_disabled.tres")

signal focussed
signal selected

var teamId: String
var playerId: String
var slots: Array
var gadgetId: String
var disabled: = false
var isShred: = false

func _ready():
	_on_GadgetChoice_focus_exited()
	Style.init(self)

func fillSupplement(gadgetData: Dictionary):
	if Keepers.getAllOfTeam(teamId).size() > 1 and (GameWorld._isKeeperGadgetSupplement(gadgetData) or GameWorld._isKeepersuitSupplement(gadgetData)):
		%ExclusiveLabel.visible = true
		%ExclusiveLabel.text = tr("multiplayer.techtree.keepersharedupgrades")
	elif gadgetData.id.begins_with("player") and Keepers.getAllOfTeam(teamId).size() > 1:
		%ExclusiveLabel.visible = true
		%ExclusiveLabel.text = tr("multiplayer.techtree.keeperexclusivesupplement")
	else:
		%ExclusiveLabel.visible = false

	fill_common(gadgetData)
	find_child("IconFrame").texture = preload("res://content/techtree/panels/square_bright.png")

func fillGadget(gadgetData: Dictionary):
	if gadgetData.id.begins_with("player") and Keepers.getAllOfTeam(teamId).size() > 1:
		%ExclusiveLabel.visible = true
		%ExclusiveLabel.text = tr("multiplayer.techtree.keeperexclusivegadget")
	else:
		%ExclusiveLabel.visible = false

	slots = gadgetData.get("takeslots", [])
	if slots.size() == 0:
		find_child("IconFrame").texture = preload("res://content/techtree/panels/big.png")
	else:
		find_child("IconFrame").texture = preload("res://content/techtree/panels/big_place.png")

	fill_common(gadgetData)

func fill_common(gadgetData: Dictionary):
	slots = gadgetData.get("takeslots", [])

	var slotVis = find_child("GadgetSlot")
	if slotVis:
		find_child("GadgetSlot").setSlots(slots)
	var s: = ""
	for slot: String in slots:
		if slot.count(".") == 1:
			slot = slot.substr(slot.find(".") + 1)
		if s != "":
			s += ", "
		var translation = tr("gadget.slot." + slot)
		if translation == "gadget.slot." + slot:

			slot = slot.replace("supplement", "")
			s += tr("upgrades." + slot + ".title") + " " + tr("gadget.slot.supplement")
		else:
			s += tr("gadget.slot." + slot)

	if s == "":
		find_child("SlotLabel").visible = false
		if find_child("GadgetSlot"):
			find_child("GadgetSlot").visible = false
	else:
		find_child("SlotLabel").text = tr("level.gadgetchoice.slot").format({"gadget_slot": s})

	gadgetId = gadgetData.get("id")

	var id: String = gadgetData.get("tr_id", gadgetId)
	find_child("TitleLabel").text = tr("upgrades." + id + ".title")
	var desc = tr("upgrades." + id + ".desc")
	if gadgetData.has("amount"):
		desc = desc.format({"amount": gadgetData.get("amount")})
	find_child("DescriptionLabel").text = desc
	var icon = find_child("IconTextureRect")
	match id:
		"shredgadgettoiron":
			icon.texture = load("res://content/icons/icon_iron.png")
			icon.custom_minimum_size *= 0.5
			icon.size *= 0.5
			icon.position += icon.size * 0.5
			isShred = true
		"shredgadgettocobalt":
			if not is_inside_tree():
				await (ready)
			icon.texture = load("res://content/icons/icon_sand.png")
			icon.custom_minimum_size *= 0.5
			icon.size *= 0.5
			icon.position += icon.size * 0.5
			icon.position.y -= icon.size.y * 0.1
			isShred = true
		"shredgadgettowater":
			if not is_inside_tree():
				await (ready)
			icon.texture = load("res://content/icons/icon_water.png")
			icon.custom_minimum_size *= 0.5
			icon.size *= 0.5
			icon.position += icon.size * 0.5
			isShred = true
		_:
			icon.texture = Data.loadIconOrFallback("res://content/icons/" + id + ".png")

func setFocus():
	if disabled:
		return
	set("theme_override_styles/panel", preload("res://gui/buttons/button_hover.tres"))

func _on_GadgetChoice_focus_entered():
	setFocus()
	emit_signal("focussed")

func _on_GadgetChoice_focus_exited():
	if disabled:
		return
	set("theme_override_styles/panel", preload("res://gui/buttons/button_normal.tres"))

func _on_GadgetChoice_gui_input(event):
	if disabled:
		return

	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var mouse_keeper: = Keepers.getLocalMouseUser()
		if is_instance_valid(mouse_keeper) and mouse_keeper.teamId == teamId:
			emit_signal("selected")

func _on_GadgetChoice_mouse_entered():
	var mouse_keeper: = Keepers.getLocalMouseUser()
	if is_instance_valid(mouse_keeper) and mouse_keeper.teamId == teamId:
		InputSystem.grabFocus(self)

func disable() -> void :
	disabled = true
	modulate.a = 0.5
	find_child("IconTextureRect").material = preload("res://stages/loadout/icon_grayscale_material.tres")
	set("theme_override_styles/panel", BUTTON_DISABLED_STYLE)
	focus_mode = FocusMode.FOCUS_NONE
