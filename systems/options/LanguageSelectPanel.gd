extends Control

signal quit

var translationDesc: = {
	"ar_SA": false, 
	"bg_BG": false, 
	"ca_ES": false, 
	"cs_CZ": false, 
	"da_DK": false, 
	"de_DE": true, 
	"en_US": true, 
	"es_ES": true, 
	"es_AR": false, 
	"et_EE": false, 
	"eu_ES": false, 
	"fr_FR": true, 
	"fi_FI": false, 
	"he_IL": false, 
	"hu_HU": false, 
	"id_ID": false, 
	"it_IT": false, 
	"ja_JP": true, 
	"ko_KR": true, 
	"nb_NO": false, 
	"nl_NL": false, 
	"pl_PL": false, 
	"pt_BR": true, 
	"pt_PT": false, 
	"ro_RO": false, 
	"ru_RU": true, 
	"fil_PH": false, 
	"sk_SK": false, 
	"sv_SE": false, 
	"th_TH": false, 
	"tr_TR": false, 
	"uk_UA": false, 
	"vi_VN": false, 
	"zh_CN": true, 
	"zh_TW": true
}

var light_language_support_filter: = {
	"ar_SA": false, 
	"bg_BG": false, 
	"ca_ES": false, 
	"cs_CZ": false, 
	"da_DK": false, 
	"de_DE": true, 
	"en_US": true, 
	"es_ES": true, 
	"es_AR": false, 
	"et_EE": false, 
	"eu_ES": false, 
	"fr_FR": true, 
	"fi_FI": false, 
	"he_IL": false, 
	"hu_HU": false, 
	"id_ID": false, 
	"it_IT": true, 
	"ja_JP": true, 
	"ko_KR": true, 
	"nb_NO": false, 
	"nl_NL": false, 
	"pl_PL": true, 
	"pt_BR": true, 
	"pt_PT": true, 
	"ro_RO": false, 
	"ru_RU": true, 
	"fil_PH": false, 
	"sk_SK": false, 
	"sv_SE": false, 
	"th_TH": false, 
	"tr_TR": true, 
	"uk_UA": false, 
	"vi_VN": false, 
	"zh_CN": true, 
	"zh_TW": true
}

var lastFocusButton

func _ready():
	buildBindingUi()

	if BuildCustomization.has_feature("light_language_support"):
		%CrowdinButton.visible = false

	Style.init(self)

func buildBindingUi():
	var completionRates: = {}
	var compFile = FileAccess.open("res://systems/localization/translations/completion_rates.json", FileAccess.ModeFlags.READ)
	if compFile != null:
		var i = compFile.get_as_text()
		var test_json_conv = JSON.new()
		test_json_conv.parse(i)
		var parsed = test_json_conv.get_data()
		if parsed:
			completionRates = parsed
		compFile.close()

	var CommunityTranslations = find_child("CommunityTranslations")
	var ProfessionalTranslations = find_child("ProfessionalTranslations")
	for c in CommunityTranslations.get_children():
		c.queue_free()
	for c in ProfessionalTranslations.get_children():
		c.queue_free()

	var focusedLocale: String = ""
	for code in TranslationServer.get_loaded_locales():
		if BuildCustomization.has_feature("light_language_support") and not light_language_support_filter.get(code, false):
			continue

		var languageName = Data.LanguageNamesByCode.get(code, code)
		var languageFont = Data.FontsByCode.get(code, preload("res://gui/fonts/NotoSans-Regular.ttf"))
		var isProfessionalTranslation = translationDesc.get(code)
		var description: String
		if isProfessionalTranslation:
			description = ""
		else:
			var percentage = completionRates.get(code, 0)
			if percentage < 0:
				continue
			description = tr("options.translation.community").format({"completion": percentage})
			description = ""

		var translationEntry = preload("res://systems/options/LanguageOption.tscn").instantiate()
		translationEntry.init(languageName, languageFont, description)
		translationEntry.connect("request_change", Callable(self, "set_local_lang").bind(code))

		if isProfessionalTranslation:
			ProfessionalTranslations.add_child(translationEntry)
		else:
			CommunityTranslations.add_child(translationEntry)

		if code == TranslationServer.get_locale():
			InputSystem.grabFocus(translationEntry)
			focusedLocale = code

	if focusedLocale.is_empty():

		var firstLocaleButton: Control
		for localeButton in ProfessionalTranslations.get_children():
			if not localeButton.is_queued_for_deletion():
				firstLocaleButton = localeButton
				break
		InputSystem.grabFocus(firstLocaleButton)

func set_local_lang(languageCode):
	Options.transitionToLocale(languageCode)
	Audio.sound("gui_select")
	var languageSection = get_tree().get_nodes_in_group("lang").front()
	languageSection.set_Language_button_text(languageCode)
	emit_signal("quit")

func _on_CrowdinButton_pressed():
	OS.shell_open("https://crowdin.com/project/dome-keeper")
