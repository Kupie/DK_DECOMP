class_name LocaleFontRemap extends Node




const README: = "We encountered a problem with direct mapping of TTF files. This problem occurred on engine version\n\t\t\t\t4.3.1 and may have been fixed. The problem manifested itself through extremely long language changes and\n\t\t\t\terror flood during the change.\n\t\t\t\tThis class is a workaround that does what project settings -> localization -> remaps suppose to be doing\n\t\t\t\tIf you want to map ttf or otf directly you need to check performance impact of your changes, if it works fine\n\t\t\t\tfeel free to modify/replace this class.\n\t\t\t\tfor context: issue has been introduced for the first time by 52fe8e63d9e2216723a938563cdee62bb4b06242"







const KOLLEKTIF_FONT: Font = preload("res://gui/fonts/Kollektif.ttf")
const KOLLEKTIF_FONT_VARIANTS: Array = [
	preload("res://gui/fonts/FontButton.tres"), 
	preload("res://gui/fonts/FontHeading.tres"), 
	preload("res://gui/fonts/FontLarge.tres"), 
	preload("res://gui/fonts/FontLeaderboardPlayername.tres"), 
	preload("res://gui/fonts/FontNormal.tres"), 
	preload("res://gui/fonts/FontNumbers.tres"), 
	preload("res://gui/fonts/FontVeryLarge.tres"), 
]

const KOLLEKTIF_FONT_REMAP: Dictionary = {
	"bg_BG": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"cs_CZ": preload("res://gui/fonts/roboto/Roboto-Regular.ttf"), 
	"he_IL": preload("res://gui/fonts/hebrew/VarelaRound-Regular.ttf"), 
	"hu_HU": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"ja_JP": preload("res://gui/fonts/ja/Makinas-4-Flat.otf"), 
	"ko_KR": preload("res://gui/fonts/korean/NotoSansKR-Regular.otf"), 
	"pl_PL": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"ro_RO": preload("res://gui/fonts/roboto/Roboto-Regular.ttf"), 
	"ru_RU": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"fil_PH": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"sk_SK": preload("res://gui/fonts/roboto/Roboto-Regular.ttf"), 
	"th_TH": preload("res://gui/fonts/thai/Aksaramatee Regular.ttf"), 
	"uk_UA": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"vi_VN": preload("res://gui/fonts/roboto/Roboto-Regular.ttf"), 
	"zh_CN": preload("res://gui/fonts/simplified chinese/NotoSansSC-Regular.otf"), 
	"zh_TW": preload("res://gui/fonts/traditional chinese/NotoSansTC-Regular.otf")
}

const LOUIS_GEORGE_CAFE_FONT: Font = preload("res://gui/fonts/Louis George Cafe.ttf")

const LOUIS_GEORGE_CAFE_FONT_VARIANTS: Array = [
	preload("res://gui/fonts/FontSmall.tres"), 
]

const LOUIS_GEORGE_CAFE_FONT_REMAP: Dictionary = {
	"bg_BG": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"cs_CZ": preload("res://gui/fonts/roboto/Roboto-Regular.ttf"), 
	"he_IL": preload("res://gui/fonts/hebrew/VarelaRound-Regular.ttf"), 
	"hu_HU": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"ja_JP": preload("res://gui/fonts/ja/Makinas-4-Flat.otf"), 
	"ko_KR": preload("res://gui/fonts/korean/NotoSansKR-Regular.otf"), 
	"pl_PL": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"ro_RO": preload("res://gui/fonts/roboto/Roboto-Regular.ttf"), 
	"ru_RU": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"fil_PH": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"sk_SK": preload("res://gui/fonts/roboto/Roboto-Regular.ttf"), 
	"th_TH": preload("res://gui/fonts/thai/Aksaramatee Regular.ttf"), 
	"uk_UA": preload("res://gui/fonts/NotoSans-Regular.ttf"), 
	"vi_VN": preload("res://gui/fonts/roboto/Roboto-Regular.ttf"), 
	"zh_CN": preload("res://gui/fonts/simplified chinese/NotoSansSC-Regular.otf"), 
	"zh_TW": preload("res://gui/fonts/traditional chinese/NotoSansTC-Regular.otf")
}


func remap_fonts_to_language(new_language_code: String) -> void :
	_confirm_settings_correctness()
	_update_font_variations(KOLLEKTIF_FONT_VARIANTS, new_language_code, KOLLEKTIF_FONT_REMAP, KOLLEKTIF_FONT)
	_update_font_variations(LOUIS_GEORGE_CAFE_FONT_VARIANTS, new_language_code, LOUIS_GEORGE_CAFE_FONT_REMAP, 
		LOUIS_GEORGE_CAFE_FONT)
	ensure_font_oversampling()


func _confirm_settings_correctness() -> void :
	if not OS.is_debug_build():
		return
	var engine_provided_remap: Dictionary = get_remap_settings()
	for file: String in engine_provided_remap:
		var is_ttf: bool = file.find(".ttf") > -1
		var is_otf: bool = file.find(".otf") > -1
		assert (( not is_ttf) and ( not is_otf), README)


func _update_font_variations(out_font_variations: Array, new_lang_code: String, in_remap: Dictionary, in_font: Font) -> void :
	if in_remap.has(new_lang_code):
		for variant: FontVariation in out_font_variations:
			variant.base_font = in_remap[new_lang_code]
	else:
		for variant: FontVariation in out_font_variations:
			variant.base_font = in_font


func get_remap_settings() -> Dictionary:
	return ProjectSettings.get_setting("locale/translation_remaps")


func ensure_font_oversampling() -> void :
	var kollektif: = _get_current_kollektif_remap()
	var louis: = _get_current_louis_george_remap()
	kollektif.oversampling = 1.0
	louis.oversampling = 1.0


func _get_current_kollektif_remap() -> Font:
	var lang_code: String = TranslationServer.get_locale()
	var font: Font = KOLLEKTIF_FONT_REMAP[lang_code] if KOLLEKTIF_FONT_REMAP.has(lang_code) else\
	KOLLEKTIF_FONT
	return font


func _get_current_louis_george_remap() -> Font:
	var lang_code: String = TranslationServer.get_locale()
	var font: Font = LOUIS_GEORGE_CAFE_FONT_REMAP[lang_code] if LOUIS_GEORGE_CAFE_FONT_REMAP.has(lang_code) else\
	LOUIS_GEORGE_CAFE_FONT
	return font
