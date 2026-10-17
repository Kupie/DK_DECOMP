extends HBoxContainer

@onready var action = $Action

func setup(action: String, label: String):
	$Action.set_action(action)
	$Label.text = tr(label)
	Style.init(self)
