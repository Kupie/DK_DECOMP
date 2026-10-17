extends PanelContainer

signal focussed
signal selected

@export var id: String

func _ready():
	find_child("TitleLabel").text = tr("versus.corruption" + id + ".title")
	find_child("DescriptionLabel").text = tr("versus.corruption" + id + ".desc")
	_on_GadgetChoice_focus_exited()
	%IconTextureRect.texture = load("res://content/icons/corruptions/" + id + ".png")
	Style.init(self)

func setFocus():
	set("theme_override_styles/panel", preload("res://gui/buttons/button_hover.tres"))

func _on_GadgetChoice_focus_entered():
	setFocus()
	emit_signal("focussed")

func _on_GadgetChoice_focus_exited():
	set("theme_override_styles/panel", preload("res://gui/buttons/button_normal.tres"))

func _on_GadgetChoice_gui_input(event):
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		emit_signal("selected")
