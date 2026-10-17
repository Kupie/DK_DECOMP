extends PanelContainer

signal request_change()

func init(language: String, font, description: String):
	var setting: LabelSettings = %Language.label_settings
	var inst: LabelSettings = setting.duplicate()
	inst.font = font
	%Language.label_settings = inst
	%Language.text = language
	if description == "":
		%TranslationProgress.visible = false
	else:
		%TranslationProgress.text = description
	$SelectedPanel.visible = false

func _on_LanguageOption_focus_entered():


	$SelectedPanel.visible = true

func _on_LanguageOption_focus_exited():


	$SelectedPanel.visible = false

func _on_LanguageOption_gui_input(event):


	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("request_change")
		return

	if Input.is_action_pressed("ui_accept"):
		emit_signal("request_change")

func _on_LanguageOption_mouse_entered():


	$SelectedPanel.visible = false

	set("theme_override_styles/panel", preload("res://gui/buttons/button_hover.tres"))

func _on_LanguageOption_mouse_exited():


	find_child("Language").set("theme_override_colors/font_color", null)
	modulate = Color.WHITE
	if not has_focus():



		set("theme_override_styles/panel", preload("res://gui/buttons/button_normal.tres"))
