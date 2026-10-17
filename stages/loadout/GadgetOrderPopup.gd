extends ColorRect

signal close

var gadgets: Array
var labels: Array
var textures: Array

func _ready():
	color = Style.OVERLAY_COLOR_IN

	var container = find_child("Gadgets")

	gadgets = GameWorld.customGadgetOrder.duplicate()

	for gadget in GameWorld.customGadgetOrder:
		if not gadgets.has(gadget) or Data.gadgets[gadget].get("type", "") != "gadget":
			gadgets.erase(gadget)


	for gadget in Data.gadgets:
		if gadgets.has(gadget):
			if Data.gadgets[gadget].get("type", "") != "gadget":
				gadgets.erase(gadget)
		elif Data.gadgets[gadget].get("type", "") == "gadget":
			gadgets.append(gadget)

	var i: = 0
	for gadget in gadgets:
		var li = Label.new()
		li.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		li.text = str(i + 1)
		container.add_child(li)

		var t = TextureRect.new()
		t.stretch_mode = TextureRect.STRETCH_KEEP
		t.texture = Data.loadIconOrFallback("res://content/icons/" + gadget + ".png")
		container.add_child(t)
		textures.append(t)

		var l = Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND
		l.text = tr("upgrades." + gadget + ".title")
		container.add_child(l)
		labels.append(l)

		if i > 0:
			var bfirst = Button.new()
			bfirst.icon = preload("res://gui/icons/up2.png")
			container.add_child(bfirst)
			bfirst.connect("pressed", Callable(self, "orderUpFirstPressed").bind(i))
		else:
			container.add_child(Control.new())
		if i > 0:
			var bup = Button.new()
			bup.icon = preload("res://gui/icons/up.png")
			container.add_child(bup)
			bup.connect("pressed", Callable(self, "orderUpPressed").bind(i))
		else:
			container.add_child(Control.new())
		if i < gadgets.size() - 1:
			var bdown = Button.new()
			bdown.icon = preload("res://gui/icons/down.png")
			container.add_child(bdown)
			bdown.connect("pressed", Callable(self, "orderDownPressed").bind(i))
		else:
			container.add_child(Control.new())
		if i < gadgets.size() - 1:
			var blast = Button.new()
			blast.icon = preload("res://gui/icons/down2.png")
			container.add_child(blast)
			blast.connect("pressed", Callable(self, "orderDownLastPressed").bind(i))
		else:
			container.add_child(Control.new())

		i += 1

	Style.init(self)

func orderUpFirstPressed(i):
	Audio.sound("gui_confirm")
	if i <= 0 or i >= labels.size():
		return

	var t_label = labels[i].text
	var t_texture = textures[i].texture
	var t_gadget = gadgets[i]

	for j in range(i, 0, -1):
		labels[j].text = labels[j - 1].text
		textures[j].texture = textures[j - 1].texture
		gadgets[j] = gadgets[j - 1]

	labels[0].text = t_label
	textures[0].texture = t_texture
	gadgets[0] = t_gadget

func orderUpPressed(i):
	Audio.sound("gui_confirm")
	var t = labels[i].text
	labels[i].text = labels[i - 1].text
	labels[i - 1].text = t

	var tex = textures[i].texture
	textures[i].texture = textures[i - 1].texture
	textures[i - 1].texture = tex

	var g = gadgets[i]
	gadgets[i] = gadgets[i - 1]
	gadgets[i - 1] = g

func orderDownPressed(i):
	Audio.sound("gui_confirm")
	var t = labels[i].text
	labels[i].text = labels[i + 1].text
	labels[i + 1].text = t

	var tex = textures[i].texture
	textures[i].texture = textures[i + 1].texture
	textures[i + 1].texture = tex

	var g = gadgets[i]
	gadgets[i] = gadgets[i + 1]
	gadgets[i + 1] = g

func orderDownLastPressed(i):
	Audio.sound("gui_confirm")
	if i < 0 or i >= labels.size() - 1:
		return

	var t_label = labels[i].text
	var t_texture = textures[i].texture
	var t_gadget = gadgets[i]

	for j in range(i, labels.size() - 1):
		labels[j].text = labels[j + 1].text
		textures[j].texture = textures[j + 1].texture
		gadgets[j] = gadgets[j + 1]

	labels[labels.size() - 1].text = t_label
	textures[textures.size() - 1].texture = t_texture
	gadgets[gadgets.size() - 1] = t_gadget

func open():
	if GameWorld.useCustomGadgetOrderSetting and GameWorld.customGadgetOrder.size() > 0:
		InputSystem.grabFocus(find_child("ButtonApplyGadgetOrder"))
		find_child("ButtonApplyGadgetOrder").button_pressed = true
		find_child("ButtonNoGadgetOrder").button_pressed = false
		showGadgetOrder()
	else:
		InputSystem.grabFocus(find_child("ButtonNoGadgetOrder"))
		find_child("ButtonNoGadgetOrder").button_pressed = true
		find_child("ButtonApplyGadgetOrder").button_pressed = false
		hideGadgetOrder()

func _on_ButtonNoGadgetOrder_pressed():
	Audio.sound("gui_confirm")
	hideGadgetOrder()
	GameWorld.useCustomGadgetOrderSetting = false

func _on_ButtonApplyGadgetOrder_pressed():
	Audio.sound("gui_confirm")
	showGadgetOrder()
	GameWorld.useCustomGadgetOrderSetting = true

func showGadgetOrder():
	find_child("ScrollContainer").visible = true

func hideGadgetOrder():
	find_child("ScrollContainer").visible = false

func _on_CloseButton_pressed():
	_close()
	emit_signal("close")

func _close():
	Audio.sound("gui_back")

	if find_child("ButtonApplyGadgetOrder").button_pressed:
		GameWorld.customGadgetOrder = gadgets

	queue_free()
