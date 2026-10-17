extends ColorRect

signal close
signal selected(gadgetId: String)

var openerIndex = -1
var limits: Array
var playerId: String
var teamId: String

func setOpenerIndex(idx):
	self.openerIndex = idx

func setLimits(limits: Array):
	self.limits = limits

func _ready():
	color = Style.OVERLAY_COLOR_IN

	var container = find_child("Gadgets")

	var additionalGadgets: = GameWorld.getPossibleAdditionalGadgets(openerIndex, teamId, limits)
	var is_missing_gadgets: bool = additionalGadgets["is_missing_gadgets"]
	var available_gadgets: Array = additionalGadgets["available_gadgets"]
	var gadgets: Array = additionalGadgets["gadgets"]

	%LabelUnlock.visible = is_missing_gadgets


	gadgets.sort_custom( func(a, b): return tr("upgrades." + a + ".title").nocasecmp_to(tr("upgrades." + b + ".title")) < 0)


	var t = TextureRect.new()
	t.stretch_mode = TextureRect.STRETCH_KEEP
	container.add_child(t)
	var l = Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND
	l.text = tr("level.gameover.keepgadget.none")
	container.add_child(l)
	var bup = Button.new()
	bup.text = tr("loadout.select")
	container.add_child(bup)
	bup.connect("pressed", selectGadget.bind(""))
	InputSystem.grabFocus(bup)

	for gadget in gadgets:
		t = TextureRect.new()
		t.stretch_mode = TextureRect.STRETCH_KEEP
		t.texture = Data.loadIconOrFallback("res://content/icons/" + gadget + ".png")
		container.add_child(t)

		l = Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND
		l.text = tr("upgrades." + gadget + ".title")
		container.add_child(l)

		bup = Button.new()
		bup.text = tr("loadout.select")
		container.add_child(bup)
		bup.connect("pressed", selectGadget.bind(gadget))
		bup.disabled = not available_gadgets.has(gadget)

	Style.init(self)

func selectGadget(gadgetId: String):
	Audio.sound("gui_confirm")
	selected.emit(gadgetId)


func _on_cancel_button_pressed() -> void :
	Audio.sound("gui_back")
