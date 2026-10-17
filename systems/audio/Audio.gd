extends Node






const BUS_MASTER: = "Master"
const BUS_MUSIC: = "Music"
const BUS_AMBIENCE: = "Ambience"
const BUS_UI: = "UI"
const BUS_SOUNDS: = "Sounds"
const BUS_SHIELD: = "Shield"
const BUS_CRITICAL: = "Critical"
const BUS_MINE: = "Mine"
const BUS_WORLD: = "World"
const BUS_WORLD_TEAM2: = "World-team2"
const BUS_KEEPER: = "Keeper"

const AMBIENCE_FADE_TIME: = 1.8

var gui_select = preload("res://content/sounds/UI/Select.wav")
var gui_select_upgrade = preload("res://content/sounds/UI/Gadgethcoose.wav")
var gui_hover = preload("res://content/sounds/UI/TechHover.wav")
var gui_back = preload("res://content/sounds/UI/Back.wav")
var gui_confirm = preload("res://content/sounds/UI/Confirm.wav")
var gui_cancel = preload("res://content/sounds/UI/Cancel.wav")
var gui_toggle = preload("res://content/sounds/UI/Toggle.wav")
var gui_err = preload("res://content/sounds/UI/Error.wav")
var gui_move = preload("res://content/sounds/UI/Cycle_short.wav")
var gui_apply = preload("res://content/sounds/UI/ApplySetting.wav")

var gui_tutorial_in = preload("res://content/sounds/UI/TutorialUI.wav")
var gui_cheats = preload("res://content/sounds/UI/plastic building_03.wav")

var gui_title_credits = preload("res://content/sounds/UI/Credits.wav")
var gui_title_continue = preload("res://content/sounds/UI/ContinueGame.wav")
var gui_title_newgame = preload("res://content/sounds/UI/NewGame.wav")
var gui_title_newgame_splitscreen = preload("res://content/sounds/UI/loadoutmenu/localmode_select.wav")
var gui_title_options = preload("res://content/sounds/UI/Settings.wav")

var gui_unlock_upgrade = preload("res://content/sounds/UI/UnlockUpgrade.wav")

var gui_start_game = preload("res://content/sounds/UI/StartGameConfirm.wav")

var gui_pause_start = preload("res://content/sounds/UI/Pause.wav")
var gui_pause_stop = preload("res://content/sounds/UI/Unpause.wav")

var gui_quit_ask = preload("res://content/sounds/UI/Quit.wav")
var gui_quit_confirm = preload("res://content/sounds/UI/QuitAreYouSure.wav")
var gui_quit_toggle = preload("res://content/sounds/UI/Toggle.wav")

var gui_tab = preload("res://content/sounds/UI/SettingsTab.wav")
var gui_slider = preload("res://content/sounds/UI/ui_slider.wav")
var upgrade = preload("res://content/sounds/UI/TechUpgrade.wav")
var tech_locked = preload("res://content/sounds/UI/loadoutmenu/team_close.wav")
var tech_hover = preload("res://content/sounds/UI/TechHover.wav")
var tech_maxed = preload("res://content/sounds/UI/TechMaxed.wav")

var stinger_relic_chamber_excavated_keeper1 = preload("res://content/sounds/stingers/ENGINEER Relic1.ogg")
var stinger_gadget_chamber_excavated_keeper1 = preload("res://content/sounds/stingers/ENGINEER Gadget1.ogg")
var stinger_relic_chamber_excavated_keeper2 = preload("res://content/sounds/stingers/ASSESSOR Relic.ogg")
var stinger_gadget_chamber_excavated_keeper2 = preload("res://content/sounds/stingers/ASSESSOR Gadget.ogg")
var stinger_relic_chamber_excavated_keeper3 = preload("res://content/sounds/stingers/keeper3_relic_chamber.ogg")
var stinger_gadget_chamber_excavated_keeper3 = preload("res://content/sounds/stingers/keeper3_gadget_chamber.ogg")
var stinger_relic_chamber_excavated_keeper4 = preload("res://content/sounds/stingers/keeper4_relic_chamber.ogg")
var stinger_gadget_chamber_excavated_keeper4 = preload("res://content/sounds/stingers/keeper4_gadget_chamber.ogg")

var enter_station_dome1 = preload("res://content/sounds/dome1/sfx_computer_01.wav")
var enter_station_dome2 = preload("res://content/sounds/dome2/Dome2_Enter2.wav")
var enter_station_dome3 = preload("res://content/sounds/Weapons/artillery/EnterDome.wav")
var enter_station_dome4 = preload("res://content/sounds/dome4/Tesla_Enter_2.wav")
var charge_on_dome1 = preload("res://content/sounds/dome1/Terminal01_BattleButton.wav")
var charge_on_dome2 = preload("res://content/sounds/dome2/DomeTerminal2_04.wav")
var charge_on_dome3 = preload("res://content/sounds/Weapons/artillery/ChargeOnDome3.wav")
var charge_on_dome4 = preload("res://content/sounds/dome4/Tesla_Arm_4.wav")
var charge_off_dome1 = preload("res://content/sounds/dome1/Terminal01_Open.wav")
var charge_off_dome2 = preload("res://content/sounds/dome2/DomeTerminal2_05.wav")
var charge_off_dome3 = preload("res://content/sounds/Weapons/artillery/ChargeOffDome3.wav")
var charge_off_dome4 = preload("res://content/sounds/dome4/Tesla_Disarm_3.wav")
var exit_station_dome1 = preload("res://content/sounds/dome1/Terminal01_Exitt.wav")
var exit_station_dome2 = preload("res://content/sounds/dome2/Dome2_Exit.wav")
var exit_station_dome3 = preload("res://content/sounds/Weapons/artillery/ExitDome.wav")
var exit_station_dome4 = preload("res://content/sounds/dome4/Tesla_Exit.wav")
var open_upgrades = preload("res://content/sounds/Weapons/tesla/upgrade_open.wav")
var close_upgrades = preload("res://content/sounds/Weapons/tesla/upgrade_close.wav")

var loadout_keeper1 = preload("res://content/sounds/UI/Keeper1Selection.wav")
var loadout_keeper2 = preload("res://content/sounds/UI/Keeper2Selection.wav")
var loadout_keeper3 = preload("res://content/sounds/UI/Keeper3Selection.wav")
var loadout_keeper4 = preload("res://content/sounds/UI/Keeper4Selection.wav")
var loadout_dome1 = preload("res://content/sounds/UI/SelectLaser_v2.wav")
var loadout_dome2 = preload("res://content/sounds/UI/SelectSword.wav")
var loadout_dome3 = preload("res://content/sounds/UI/ArtilleryLoadout.wav")
var loadout_dome4 = preload("res://content/sounds/UI/Teslaloadout.wav")
var loadout_orchard = preload("res://content/sounds/UI/SelectOrchard.wav")
var loadout_shield = preload("res://content/sounds/UI/SelectShield.wav")
var loadout_repellent = preload("res://content/sounds/UI/SelectRepellent.wav")
var loadout_prestige = preload("res://content/sounds/UI/SelectPrestige.wav")
var loadout_relichunt = preload("res://content/sounds/UI/SelectRelicHunt.wav")
var loadout_assignments = preload("res://content/sounds/UI/loadoutmenu/mode_assignment.wav")
var loadout_versus = preload("res://content/sounds/UI/loadoutmenu/mode_versus.wav")
var loadout_droneyard = preload("res://content/sounds/UI/SelectDrone.wav")
var loadout_pet = preload("res://content/sounds/UI/PetSelection.wav")
var loadout_skin = preload("res://content/sounds/UI/Keeperstyleselect.wav")
var loadout_modebasic = preload("res://content/sounds/UI/Mode_basic.wav")
var loadout_modecobolt = preload("res://content/sounds/UI/Mode_cobolt.wav")
var loadout_modecountdown = preload("res://content/sounds/UI/loadoutmenu/prestige_countdown.wav")
var loadout_modeminer = preload("res://content/sounds/UI/loadoutmenu/prestige_miner_1.wav")
var loadout_assignment_on = preload("res://content/sounds/UI/ChooseAssignmentOn.wav")
var loadout_cannot_start = preload("res://content/sounds/UI/loadoutmenu/press_start_while_keeper_is_out.wav")
var loadout_keeper_join = preload("res://content/sounds/UI/loadoutmenu/loadout_join.wav")
var loadout_keeper_leave = preload("res://content/sounds/UI/loadoutmenu/loadout_leave.wav")
var loadout_team_open = preload("res://content/sounds/UI/loadoutmenu/team_open.wav")
var loadout_team_close = preload("res://content/sounds/UI/loadoutmenu/team_close.wav")
var loadout_modifier_selected = preload("res://content/sounds/UI/loadoutmenu/trait_apply.wav")
var loadout_modifier_deselected = preload("res://content/sounds/UI/loadoutmenu/trait_remove.wav")
var loadout_versus_condition_iron = preload("res://content/sounds/UI/loadoutmenu/wincondition_iron.wav")
var loadout_versus_condition_lastteam = preload("res://content/sounds/UI/loadoutmenu/wincondition_lastteamstanding.wav")

var gui_loadout_startrun = preload("res://content/sounds/UI/StartRun.wav")

var alarm = preload("res://content/sounds/UI/Alarm.wav")
var wavestart = preload("res://content/sounds/UI/GongRiser.wav")
var wavedread = preload("res://content/sounds/UI/wave_Cave_amb.wav")
var gadgetinsert = preload("res://content/sounds/Locations/RelicRoom/GadgetInsert.wav")
var cobaltscavenge = preload("res://content/sounds/drops/Metaltest_03.wav")
var appleupgrade1 = preload("res://content/sounds/Locations/Orchard/Eat_apple_02.wav")
var appleupgrade2 = preload("res://content/sounds/Locations/Orchard/Eat_apple_03.wav")
var appleupgrade3 = preload("res://content/sounds/Locations/Orchard/Eat_apple_04.wav")
var lose = preload("res://content/sounds/UI/Defeat.wav")
var unlock_event = preload("res://content/sounds/Bastards/Achiemenet.wav")
var guild_reward_unlocked = preload("res://content/sounds/UI/guildrewardUnlock.wav")

var m_mining_keeper1 = [
	preload("res://content/music/ENGINEER Between the Waves.ogg"), 
	preload("res://content/music/ENGINEER Delving.ogg"), 
	preload("res://content/music/ENGINEER Lost in the Mines.ogg"), 
	preload("res://content/music/ENGINEER A Moment to Breathe.ogg"), 
	preload("res://content/music/ENGINEER Deeper and Deeper.ogg"), 
	preload("res://content/music/ENGINEER Further Underneath.ogg"), 
	preload("res://content/music/ENGINEER The Engineer.ogg"), 
	preload("res://content/music/ENGINEER Ancient Artifact.ogg"), 
	preload("res://content/music/ENGINEER Undiscovered Flora.ogg"), 
	preload("res://content/music/ENGINEER_Ode_to_Iron.ogg"), 
	]

var m_mining_keeper2 = [
	preload("res://content/music/ASSESSOR Alchemy.ogg"), 
	preload("res://content/music/ASSESSOR Caves Beyond.ogg"), 
	preload("res://content/music/ASSESSOR Claustrophobe.ogg"), 
	preload("res://content/music/ASSESSOR Eternal Dust.ogg"), 
	preload("res://content/music/ASSESSOR Layer By Layer.ogg"), 
	preload("res://content/music/ASSESSOR Lonely Job.ogg"), 
	preload("res://content/music/ASSESSOR Sombre.ogg"), 
	preload("res://content/music/ASSESSOR The Very Last Egg.ogg"), 
	preload("res://content/music/ASSESSOR Vestigial Eye.ogg"), 
	preload("res://content/music/ASSESSOR The Assessor.ogg"), 
]

var m_mining_keeper3 = [
	preload("res://content/music/keeper3/keeper3_mining01.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining02.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining03.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining04.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining05.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining06.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining07.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining08.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining09.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining10.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining11.ogg"), 
	preload("res://content/music/keeper3/keeper3_mining12.ogg")
]

var m_mining_keeper4 = [
	preload("res://content/music/keeper4/keeper4_mining01.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining02.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining03.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining04.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining05.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining06.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining07.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining08.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining09.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining10.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining11.ogg"), 
	preload("res://content/music/keeper4/keeper4_mining12.ogg")
]

var currentTrackList: = []
var intro_in_loop = false
var m_battle = [preload("res://content/music/BATTLE LASER.ogg")]

var m_intro_keeper1: = preload("res://content/music/keeper1_title_intro.ogg")
var m_intro_loop_keeper1: = preload("res://content/music/keeper1_title_loop.ogg")
var m_intro_keeper2: = preload("res://content/music/keeper2_title_intro.ogg")
var m_intro_loop_keeper2: = preload("res://content/music/keeper2_title_loop.ogg")
var m_intro_keeper3: = preload("res://content/music/keeper3/keeper3_title_intro.ogg")
var m_intro_loop_keeper3: = preload("res://content/music/keeper3/keeper3_title_loop.ogg")
var m_intro_keeper4: = preload("res://content/music/keeper4/keeper4_title_intro.ogg")
var m_intro_loop_keeper4: = preload("res://content/music/keeper4/keeper4_title_loop.ogg")
var m_intro_christmas: = preload("res://content/music/holiday_title_intro.ogg")
var m_intro_loop_christmas: = preload("res://content/music/holiday_title_loop.ogg")

var m_ending_keeper1: = preload("res://content/music/ENGINEER Laser Party [intro].ogg")
var m_ending_loop_keeper1: = preload("res://content/music/ENGINEER Laser Party [loop].ogg")
var m_ending_keeper2: = preload("res://content/music/ASSESSOR The Perfect Bounce [intro].ogg")
var m_ending_loop_keeper2: = preload("res://content/music/ASSESSOR The Perfect Bounce [loop].ogg")
var m_ending_keeper3: = preload("res://content/music/keeper3/keeper3_game_win01_intro.ogg")
var m_ending_loop_keeper3: = preload("res://content/music/keeper3/keeper3_game_win01_loop.ogg")
var m_ending_keeper4: = preload("res://content/music/keeper4/keeper4_game_win01_intro.ogg")
var m_ending_loop_keeper4: = preload("res://content/music/keeper4/keeper4_game_win01_loop.ogg")

var m_ending_2_keeper1: = preload("res://content/music/keeper1_game_win02_intro.ogg")
var m_ending_2_loop_keeper1: = preload("res://content/music/keeper1_game_win02_loop.ogg")
var m_ending_2_keeper2: = preload("res://content/music/keeper2_game_win02_intro.ogg")
var m_ending_2_loop_keeper2: = preload("res://content/music/keeper2_game_win02_loop.ogg")
var m_ending_2_keeper3: = preload("res://content/music/keeper3/keeper3_game_win02_intro.ogg")
var m_ending_2_loop_keeper3: = preload("res://content/music/keeper3/keeper3_game_win02_loop.ogg")
var m_ending_2_keeper4: = preload("res://content/music/keeper4/keeper4_game_win02_intro.ogg")
var m_ending_2_loop_keeper4: = preload("res://content/music/keeper4/keeper4_game_win02_loop.ogg")

var m_game_over_keeper1: = preload("res://content/music/ENGINEER Collapse [intro].ogg")
var m_game_over_loop_keeper1: = preload("res://content/music/ENGINEER Collapse [loop].ogg")
var m_game_over_keeper2: = preload("res://content/music/ASSESSOR All Too Familiar [intro].ogg")
var m_game_over_loop_keeper2: = preload("res://content/music/ASSESSOR All Too Familiar [loop].ogg")
var m_game_over_keeper3: = preload("res://content/music/keeper3/keeper3_game_fail_intro.ogg")
var m_game_over_loop_keeper3: = preload("res://content/music/keeper3/keeper3_game_fail_loop.ogg")
var m_game_over_keeper4: = preload("res://content/music/keeper4/keeper4_game_fail_intro.ogg")
var m_game_over_loop_keeper4: = preload("res://content/music/keeper4/keeper4_game_fail_loop.ogg")

var pitchStream: = AudioStreamRandomizer.new()

var soundPlayers: = []

var autoVolumeBattleMusic: = false
var ignoreHover: = false
var currentMineAmbience

var musicBaseAmplification: float

func _ready():




	for i in range(0, 8):
		var p = AudioStreamPlayer.new()
		p.bus = BUS_UI
		soundPlayers.append(p)
		add_child(p)
		p.connect("finished", Callable(self, "soundPlayerFinished").bind(i))

	get_viewport().gui_focus_changed.connect(playUiHoverSound)

	var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(AudioServer.get_bus_index(Audio.BUS_MUSIC), 0)
	musicBaseAmplification = amplify.volume_db

func ignoreNextHover():
	ignoreHover = true

func playUiHoverSound(v):
	if ignoreHover:
		ignoreHover = false
		return
	Audio.sound("gui_hover")

func _process(delta):
	if is_instance_valid(StageManager.currentStage) and StageManager.currentStage.stage_ending:
		return


	var world: Worldd
	if Level.worldsByTeamId.size() == 1:
		if is_instance_valid(Level.worldsByTeamId.values()[0]):
			world = Level.worldsByTeamId.values()[0]
	else:
		for w in Level.worldsByTeamId.values():
			w.ambience().stop()

	if Level.domesByTeamId.size() == 1:
		var dome = Level.domesByTeamId.values().front()
		if dome and world:
			if GameWorld.won or GameWorld.lost:
				stopAmbienceMine()
				dome.ambience().stop()
				world.ambience().stop()
			else:
				if Keepers.local.oneInsideDome():
					if InputSystem.getCamera().zoom.x < 3.0:
						dome.ambience().stop()
						world.ambience().start()
					else:
						dome.ambience().start()
						world.ambience().stop()
				else:
					dome.ambience().stop()
					world.ambience().stop()

				if Keepers.local.oneInsideMine():
					playAmbienceMine()
				else:
					stopAmbienceMine()
		else:
			stopAmbienceMine()
	else:
		for dome in Level.domesByTeamId.values():
			dome.ambience().stop()
		stopAmbienceMine()



	var minY = -99999
	for keeper in Keepers.local.getAll():
		minY = min(minY, keeper.global_position.y)
	if autoVolumeBattleMusic:
		var diff = (CONST.DOME_CELLAR_ENTRANCE_Y - minY) * 0.2
		$BattleMusic.volume_db = clamp(diff, -60, -6)

func playAmbienceMine():
	var coord = Level.map.getTileCoord(Keepers.first().global_position)
	var biome: String = Level.map.getBiomeOfCoord(coord)
	var biomeAmbience = find_child("AmbienceMine" + biome.capitalize())
	if currentMineAmbience and currentMineAmbience != biomeAmbience:
		currentMineAmbience.stop()
		currentMineAmbience = null
	if not currentMineAmbience and biomeAmbience:
		var layer: int = Level.map.getLayerOfCoord(coord)
		biomeAmbience.pitch_scale = 1.0 - layer * 0.02
		currentMineAmbience = biomeAmbience
		currentMineAmbience.start()

func stopAmbienceMine():
	if currentMineAmbience:
		currentMineAmbience.stop()
		currentMineAmbience = null

func sound(soundName: String):


	var s = get(soundName)
	if s:
		var p = getAudioStream()
		p.stream = s
		p.play()
	else:
		print("Sound \"" + soundName + "\" is not defined")

func stinger(soundName: String, inPostion: Vector2):
	const MAX_MUSIC_VOL_DROP: = 42.0
	const MIN_MUSIC_VOL_DROP: = 0.0
	const START_LOWERING_MUSIC_VOL_AT_DISTANCE: = 400.0
	const STOP_LOWERING_MUSIC_VOL_AT_DISTANCE: = 600.0
	var localKeeper: Keeper = Keepers.local.getClosest(inPostion)
	var distance: float = localKeeper.global_position.distance_to(inPostion)
	var musicLowerVolume: float = remap(distance, START_LOWERING_MUSIC_VOL_AT_DISTANCE, STOP_LOWERING_MUSIC_VOL_AT_DISTANCE, MAX_MUSIC_VOL_DROP, MIN_MUSIC_VOL_DROP)
	musicLowerVolume = clamp(musicLowerVolume, MIN_MUSIC_VOL_DROP, MAX_MUSIC_VOL_DROP)

	var s = get(soundName)
	if s:
		$Stinger.setSimulatedPosition(inPostion)
		$Stinger.stream = s
		var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(AudioServer.get_bus_index(Audio.BUS_MUSIC), 0)
		$StingerTween.interpolate_callback($Stinger, 0.15, "startSound")
		$StingerTween.interpolate_property(amplify, "volume_db", amplify.volume_db, musicBaseAmplification - musicLowerVolume, 0.25)
		$StingerTween.start()
	else:
		print("Sound \"" + soundName + "\" is not defined")

func getAudioStream() -> AudioStreamPlayer:

	for p in soundPlayers:
		if not p.playing:
			return p

	if soundPlayers.size() < 20:
		var p = AudioStreamPlayer.new()
		p.bus = BUS_UI
		soundPlayers.append(p)
		add_child(p)
		return p

	return soundPlayers.front()

func startMusic(i: int, delay: = 0.0):
	_cancelPendingIntroRetry()
	$Music.stop()
	if currentTrackList.is_empty():
		Logger.error("track list is empty", "Audio.startMusic")
		return
	$Music.stream = currentTrackList[i % currentTrackList.size()]
	$Music.volume_db = 0
	$MusicTween.stop_all()
	$MusicTween.remove_all()
	$MusicTween.interpolate_callback($Music, delay, "play")
	$MusicTween.start()

func stopMusic(delay: = 0.0, fade: = 6.0):
	_cancelPendingIntroRetry()
	$MusicTween.stop_all()
	$MusicTween.remove_all()
	$MusicTween.interpolate_property($Music, "volume_db", $Music.volume_db, -60, fade, Tween.TRANS_LINEAR, Tween.EASE_IN, delay)
	$MusicTween.interpolate_callback($Music, fade + delay, "stop")
	$MusicTween.start()

func isMusicPlaying() -> bool:
	return $Music.playing and $Music.volume_db > -40

func startBattleMusic():
	$BattleTween.stop_all()
	$BattleTween.remove_all()
	$BattleMusic.stop()





func stopBattleMusic():
	if not $BattleMusic.playing:
		return

	$BattleTween.stop_all()
	$BattleTween.remove_all()
	$BattleTween.interpolate_property($BattleMusic, "volume_db", $BattleMusic.volume_db, -60, 6.0, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$BattleTween.interpolate_callback($BattleMusic, 6.0, "stop")
	$BattleTween.start()
	autoVolumeBattleMusic = false

func startIntro():
	var title = _getTitleMusic()
	var loop = _getTitleLoop()
	var alreadyPlayingStream
	if $Music.stream == title:
		alreadyPlayingStream = title
	elif $Music.stream == loop:
		alreadyPlayingStream = loop

	if alreadyPlayingStream and isMusicPlaying():

		if $MusicTween.is_active() and not $MusicTween.tween_all_completed.is_connected(startIntro):
			$MusicTween.tween_all_completed.connect(startIntro, CONNECT_ONE_SHOT)
		return

	_cancelPendingIntroRetry()
	$Music.stop()
	$MusicTween.stop_all()
	$MusicTween.remove_all()
	$Music.stream = _getTitleMusic()
	$Music.volume_db = 0
	$Music.play(0.0)
	intro_in_loop = false

func _cancelPendingIntroRetry():
	if $MusicTween.tween_all_completed.is_connected(startIntro):
		$MusicTween.tween_all_completed.disconnect(startIntro)

func fadeIntro():
	_cancelPendingIntroRetry()
	var current_playback_position: float = $Music.get_playback_position()
	var stream = _getTitleLoop() if intro_in_loop else _getTitleMusic()
	$Music.fade_to(stream, current_playback_position)

func fadeMusic(i: int):
	_cancelPendingIntroRetry()
	if currentTrackList.is_empty():
		Logger.error("track list is empty", "Audio.fadeMusic")
		return
	var current_playback_position: float = $Music.get_playback_position()
	var stream = currentTrackList[i % currentTrackList.size()]
	$Music.fade_to(stream, current_playback_position)


func _getTitleMusic():
	if GameWorld.isChristmas:
		return m_intro_christmas
	else:
		var keeperId = get_music_keeperId()
		return get("m_intro_" + keeperId)

func _getTitleLoop():
	if GameWorld.isChristmas:
		return m_intro_loop_christmas
	else:
		var keeperId = get_music_keeperId()
		return get("m_intro_loop_" + keeperId)

func startEnding(delay: = 0.0, alternate_ending: bool = false):
	if $Music.playing:
		delay += 1.0

	if delay > 0.0:
		$MusicTween.stop_all()
		$MusicTween.remove_all()
		$MusicTween.interpolate_property($Music, "volume_db", $Music.volume_db, -60, delay * 0.9, Tween.TRANS_LINEAR, Tween.EASE_IN)
		$MusicTween.interpolate_callback($Music, delay * 0.9, "stop")
		$MusicTween.interpolate_callback(self, delay, "startEnding", delay, alternate_ending)
		$MusicTween.start()
		return

	$MusicTween.stop_all()
	$MusicTween.remove_all()
	if alternate_ending:
		$Music.stream = get("m_ending_2_%s" % get_music_keeperId())
	else:
		$Music.stream = get("m_ending_%s" % get_music_keeperId())
	$Music.volume_db = 0
	$Music.play()

func startGameOver(delay: = 0.0):
	if $Music.playing:
		delay += 1.0

	if delay > 0.0:
		$MusicTween.stop_all()
		$MusicTween.remove_all()
		$MusicTween.interpolate_property($Music, "volume_db", $Music.volume_db, -60, delay * 0.9, Tween.TRANS_LINEAR, Tween.EASE_IN)
		$MusicTween.interpolate_callback($Music, delay * 0.9, "stop")
		$MusicTween.interpolate_callback(self, delay, "startGameOver")
		$MusicTween.start()
		return
	$MusicTween.stop_all()
	$MusicTween.remove_all()
	$Music.stream = get("m_game_over_" + get_music_keeperId())
	$Music.volume_db = 0
	$Music.play()

func _on_Music_finished(player: AudioStreamPlayer) -> void :
	for keeperId in ["keeper1", "keeper2", "keeper3", "keeper4"]:
		if player.stream == get("m_intro_" + keeperId):
			player.stream = get("m_intro_loop_" + get_music_keeperId())
			intro_in_loop = true
			player.play()
		elif player.stream == get("m_ending_" + keeperId):
			player.stream = get("m_ending_loop_" + get_music_keeperId())
			intro_in_loop = true
			player.play()
		elif player.stream == get("m_ending_2_" + keeperId):
			player.stream = get("m_ending_2_loop_" + get_music_keeperId())
			intro_in_loop = true
			player.play()
		elif player.stream == get("m_game_over_" + keeperId):
			player.stream = get("m_game_over_loop_" + get_music_keeperId())
			intro_in_loop = true
			player.play()
	if player.stream == m_intro_christmas:
		player.stream = m_intro_loop_christmas
		intro_in_loop = true

func soundPlayerFinished(i) -> void :
	soundPlayers[i].stop()

func get_bus_volume(busname: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(busname))

func set_bus_volume(busname: String, volume: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(busname), clamp(volume, -80.0, 6.0))

func enableDelayEffect(bus_name: StringName, enabled: bool):
	var bus_index = AudioServer.get_bus_index(bus_name)
	for idx in AudioServer.get_bus_effect_count(bus_index):
		var effect = AudioServer.get_bus_effect(bus_index, idx)
		if effect is AudioEffectDelay:
			AudioServer.set_bus_effect_enabled(bus_index, idx, enabled)

func muteSoundAndUI():
	for bus in [BUS_SOUNDS, BUS_UI]:
		var busIdx = AudioServer.get_bus_index(bus)
		var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(busIdx, 0)
		amplify.volume_db = -60

func unmuteSoundAndUI():
	for bus in [BUS_SOUNDS, BUS_UI]:
		var busIdx = AudioServer.get_bus_index(bus)
		var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(busIdx, 0)
		amplify.volume_db = 0

func muteSounds():
	var busIdx = AudioServer.get_bus_index(BUS_SOUNDS)
	var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(busIdx, 0)
	$MuteSoundTween.remove_all()
	$MuteSoundTween.interpolate_property(amplify, "volume_db", amplify.volume_db, -60, 0.3)
	$MuteSoundTween.start()

func unmuteSounds():
	var busIdx = AudioServer.get_bus_index(BUS_SOUNDS)
	var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(busIdx, 0)
	$MuteSoundTween.remove_all()
	$MuteSoundTween.interpolate_property(amplify, "volume_db", amplify.volume_db, 0, 0.3)
	$MuteSoundTween.start()

func _on_stinger_sound_duration_elapsed():
	var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(AudioServer.get_bus_index(Audio.BUS_MUSIC), 0)
	$StingerTween.interpolate_property(amplify, "volume_db", amplify.volume_db, musicBaseAmplification, 2.0)
	$StingerTween.start()

func updateTrackList():
	if Options.adaptiveOst and GameWorld.ostKeeperId:
		currentTrackList.clear()
		for keeper: Keeper in Keepers.local.getAll():
			addTracksForTechId(keeper.techId)
		currentTrackList.shuffle()
	else:
		currentTrackList = []
		for id in Options.fixedOstTracks:
			var miningMusic = get("m_mining_" + id)
			if not miningMusic:
				Logger.error("no music found for keeper", "Audio.updateTrackList", "m_mining_" + id)
				return
			currentTrackList.append_array(miningMusic)
			_addBoosterTracks(id)
		currentTrackList.shuffle()

func addTracksForTechId(techId: String) -> void :
	var miningMusic = get("m_mining_" + techId)
	if not miningMusic:
		Logger.error("no music found for keeper", "Audio.updateTrackList", "m_mining_" + techId)
		return
	currentTrackList.append_array(miningMusic)
	_addBoosterTracks(techId)

func _addBoosterTracks(id: String):
	match id:
		"keeper1":
			if Platform.purchased_pioneer_pack():
				currentTrackList.append(preload("res://content/music/ENGINEER Glowworms.ogg"))
				currentTrackList.append(preload("res://content/music/ENGINEER Alone With Ones Thoughts.ogg"))
		"keeper2":
			if Platform.purchased_assessor_booster():
				currentTrackList.append(preload("res://content/music/ASSESSOR Gravity Waltz.ogg"))
				currentTrackList.append(preload("res://content/music/ASSESSOR Crooked Path.ogg"))

func get_music_keeperId() -> String:

	if not Options.adaptiveOst and Options.fixedOstTracks.size() > 0:
		return Options.fixedOstTracks.pick_random()
	return GameWorld.ostKeeperId

func get_closest_keeperId_or_music_override(position) -> String:
	if not Options.adaptiveOst and Options.fixedOstTracks.size() > 0:
		return Options.fixedOstTracks.pick_random()

	return Keepers.getClosestKeeper(position).techId
