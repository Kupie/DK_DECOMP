extends Node

enum PlayfabLeaderboardMode{
	STEAM = 0, 
	PLAYFAB_SOLO = 1, 
	PLAYFAB_MULTI = 2, 
	PLAYFAB_SOLO_MULTI = 3, 
}

var features: Dictionary
var forcePlayfab: = false

func _init() -> void :
	var xbox_series = OS.get_name() == "Seaven_XboxSeries"
	var xbox_one = OS.get_name() == "Seaven_XboxOne"
	var desktop = OS.get_name() == "Seaven_Desktop"
	var switch = OS.get_name() == "Seaven_Switch"
	var ps4 = OS.get_name() == "Seaven_PS4"
	var ps5 = OS.get_name() == "Seaven_PS5"
	var seaven = OS.has_feature("SEAVEN")
	var delivery = OS.has_feature("ZDELIVERY")
	var final = OS.has_feature("ZFINAL")

	var not_pc = xbox_series or xbox_one or switch or ps4 or ps5
	var seaven_platforms = xbox_series or xbox_one or switch or ps4 or ps5 or desktop


	features["disable_modding"] = seaven_platforms or OS.has_feature("disable_mods")
	features["disable_update_menu"] = seaven_platforms
	features["disable_lan_multiplayer"] = seaven_platforms or GameWorld.forcePlayfab
	features["disable_pc_options"] = not_pc
	features["disable_deadzone_option"] = switch or ps4 or ps5
	features["disable_input_rebinding"] = not_pc
	features["disable_multi"] = false
	features["disable_quit_on_save_error"] = seaven_platforms
	features["disable_allow_online_option"] = not_pc or features["disable_multi"]
	features["enable_qa_menu"] = seaven and (delivery or not final)
	features["enable_cheats"] = seaven and (delivery or not final)
	features["enable_gamer_tag"] = xbox_series or xbox_one or desktop
	features["enable_invite_friend_button"] = seaven_platforms
	features["enable_see_profile_buttons"] = xbox_series or xbox_one or desktop
	features["enable_gamertag_platform_logo"] = seaven_platforms
	features["enable_multiple_local_account"] = ps5
	features["enable_report"] = ps5
	features["enable_block"] = ps5 or switch
	features["enable_player_list"] = features["enable_see_profile_buttons"] or features["enable_report"] or features["enable_block"]
	features["force_xbox_controller_layout"] = xbox_series or xbox_one or desktop
	features["force_switch_controller_layout"] = switch
	features["force_ps_controller_layout"] = ps4 or ps5
	features["force_ps5_controller_layout"] = ps5
	features["light_language_support"] = seaven_platforms
	features["dlc_poll"] = seaven_platforms
	features["system_crossplay_option"] = xbox_series or xbox_one or desktop or GameWorld.forcePlayfab
	features["recent_player_update"] = xbox_series or xbox_one or desktop or ps4 or ps5
	features["porting_credits_splashscreen"] = seaven_platforms
	features["show_crossplay_on_join"] = seaven_platforms
	features["drop_player_fix"] = switch

	if not seaven_platforms:
		features["playfab_leaderboard_setup"] = PlayfabLeaderboardMode.STEAM
	elif xbox_series or xbox_one or desktop:
		features["playfab_leaderboard_setup"] = PlayfabLeaderboardMode.PLAYFAB_SOLO if features["disable_multi"] else PlayfabLeaderboardMode.PLAYFAB_SOLO_MULTI
	elif ps4 or ps5 or switch:
		features["playfab_leaderboard_setup"] = PlayfabLeaderboardMode.PLAYFAB_MULTI





func has_feature(tag: String):
	return features.get(tag, false)


func platform_has_feature(platform_id: String, tag: String):
	if tag == "system_crossplay_option" and platform_id == CONST.PLATFORM_ID_XBOX:
		return true

	return false
