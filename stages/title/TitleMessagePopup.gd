extends PanelContainer

@export var message_label: Label
@export var additional_message_label: Label
@export var close_button: Button

func _ready():
	Style.init(self)
	InputSystem.grabFocus(close_button)

func set_message(message: String, additional_message: String) -> void :
	message_label.text = message

	if additional_message != "":
		additional_message_label.text = additional_message
		additional_message_label.show()
