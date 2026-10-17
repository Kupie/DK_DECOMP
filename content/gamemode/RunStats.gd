extends Container

var titles: = {
	"waves_survived": "level.gameover.stats.wavessurvived", 
	"monsters_killed": "level.gameover.stats.monsterskilled", 
	"time": "level.gameover.stats.timeplayed", 
	"tiles_destroyed": "level.gameover.stats.destroyedblocks", 
	"travelled_distance": "level.gameover.stats.distancetravelled", 
	"resources_mined": "level.gameover.stats.resourcesmined", 
	"difficulty": "level.gameover.stats.difficulty", 
	"mapsize": "level.gameover.stats.mapsize", 
	"additionalgadget": "level.gameover.stats.additionalgadget", 


}

var runFinishedPopup
var teamId: String

func init(runFinishedPopup, teamId: String, is_server: bool, single_column: = false):
	self.runFinishedPopup = runFinishedPopup
	self.teamId = teamId
	if not is_server and not GameWorld.clientRunStatsSet:
		return

	if is_server:
		for tid in Level.teams:
			GameWorld.runStats[tid + ".time"] = ("%.0f" % (GameWorld.runTime / 60)) + tr("level.gameover.stats.timeplayed.unit")
			GameWorld.runStats[tid + ".travelled_distance"] = ("%.1f" % (GameWorld.runStats.get(tid + ".travelledDistance", 0) * CONST.PixelPerKilometer)) + "km"
			if GameWorld.runStats.has(tid + ".monsters_killed"):
				GameWorld.runStats[tid + ".monsters_killed"] = round(GameWorld.runStats[tid + ".monsters_killed"])

	if Level.loadout.modeId == CONST.MODE_RELICHUNT:
		if is_server:
			GameWorld.runStats[teamId + ".mapsize"] = CONST.mapSizesStringsById.get(Level.loadout.modeConfig.get(CONST.MODE_CONFIG_MAP_ARCHETYPE, ""), "missing")
			GameWorld.runStats[teamId + ".difficulty"] = CONST.difficultyStringByInt.get(int(Level.difficulty(teamId)))
	else:
		titles.erase("mapsize")
		titles.erase("difficulty")

	if GameWorld.gadgetToKeep == "" or Level.loadout.modeId != CONST.MODE_RELICHUNT or Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER:
		titles.erase("additionalgadget")
	else:
		GameWorld.runStats[teamId + ".additionalgadget"] = "upgrades." + GameWorld.gadgetToKeep + ".title"

	var i: = 0
	for key in titles:
		var container = $GridContainerLeft
		if i < titles.size() * 0.5:

			container = $GridContainerRight
		var value = GameWorld.runStats.get(teamId + "." + key, 0)
		var l = Label.new()
		l.text = tr(titles[key]) + ": "
		container.add_child(l)
		l = Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.text = str(value)
		container.add_child(l)
		i += 1

	if single_column:

		var b: = %ButtonStats
		b.get_parent().remove_child(b)
		$GridContainerLeft.add_child(b)

	%ButtonStats.visible = Data.ofOr(teamId + ".postrun.additionalstats", false)
	%ButtonMap.visible = Data.ofOr("postrun.miningtimelapse", false)
	$VBoxContainer.visible = %ButtonStats.visible or %ButtonMap.visible

func pop_timelapse_button() -> Button:
	var b: = find_child("ButtonMap")
	if b:
		b.get_parent().hide()
		b.get_parent().remove_child(b)
		return b
	else:
		return null

func _on_button_monster_count_pressed() -> void :
	Audio.sound("gui_select")
	var i = preload("res://content/shared/ControllerScrollInputProcessor.gd").new()
	i.popup = preload("res://content/gamemode/DetailedStats.tscn").instantiate()
	i.popup.init(teamId)
	i.scrollTarget = i.popup.find_child("ScrollContainer").get_v_scroll_bar()
	i.stopping.connect(i.popup.queue_free)
	i.stopping.connect(runFinishedPopup.updateFocus)
	Level.stage.showPopup(i.popup)
	i.integrate(Level.stage)

func _on_button_map_pressed() -> void :
	runFinishedPopup.visible = false
	Audio.sound("gui_select")
	var i = preload("res://gui/PopupInput.gd").new()
	i.popup = preload("res://content/gamemode/summary/MiningSummary.tscn").instantiate()
	i.stopping.connect(i.popup.queue_free)
	i.stopping.connect(runFinishedPopup.updateFocus)
	i.stopping.connect( func(): runFinishedPopup.visible = true)
	Level.stage.showPopup(i.popup)
	i.integrate(Level.stage)
