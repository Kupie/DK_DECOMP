extends HBoxContainer

func _ready():
	set_Language_button_text(TranslationServer.get_locale())

func set_Language_button_text(code):
	var language = Data.LanguageNamesByCode.get(code, code)
	find_child("LanguageSelectButton").text = language
