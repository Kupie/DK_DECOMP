extends PanelContainer

var loaded: = false
var last_network_status = true

func _ready():
	$Box / PrestigeLeaderboard.entryCount = 16
	$Box / PrestigeLeaderboard.connect("legacy_leaderboard_found", Callable($Box / PrestigeLeaderboard, "downloadLegacyLeaderboard"))

func loadData():
	if loaded:
		return
	loaded = true
	var mode = CONST.MODE_PRESTIGE_COUNTDOWN
	if Level.loadout and Level.loadout.modeConfig:
		mode = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT, CONST.MODE_PRESTIGE_COUNTDOWN)
	var display_seasons = true
	match BuildCustomization.features["playfab_leaderboard_setup"]:
		BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_SOLO, BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_MULTI:
			display_seasons = false
	$Box / PrestigeLeaderboard.start(mode, display_seasons, true)

func _process(delta: float) -> void :
	if visible:
		if not Network.is_network_ready(true) and GameWorld.is_allowOnlineMultiplayer():
			if last_network_status:
				StageManager.currentStage.openMessagePopup("network.error.offline", "", %CancelButton, false)
				last_network_status = false
		elif not last_network_status:
			last_network_status = true
			$Box / PrestigeLeaderboard.refresh_selection()
	else:
		last_network_status = true
