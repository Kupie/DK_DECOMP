extends Node2D

@export var minimumWorldVolume: = -30.0

var runWorldAttenuation: = false

func init():
	Keepers.keepers_changed.connect(_onKeepersChanged)
	_refreshEventListening()
	var localTeams: PackedStringArray = Keepers.local.getRelatedTeams()
	for team: String in localTeams:
		updateBus(team)

func _onKeepersChanged():
	_refreshEventListening()

func _refreshEventListening() -> void :
	Data.unlistenAll(self)
	var localTeams: PackedStringArray = Keepers.local.getRelatedTeams()
	for teamid: String in localTeams:

		Data.listen.call_deferred(self, teamid + ".event.keepers.insidedome")
		Data.listen.call_deferred(self, teamid + ".event.keepers.virtuallyinsidedome")

func propertyChanged(property: String, oldValue, newValue):
	var is_inside_dome_event: bool = property.find("event.keepers.insidedome") > -1 or property.find("event.keepers.virtuallyinsidedome") > -1
	if is_inside_dome_event:
		var team: String = property.split(".")[0]
		updateBus(team)

func updateBus(updateForTeam: String):
	var teamBus: String = _getWorldBusForTeam(updateForTeam)
	var busIdx = AudioServer.get_bus_index(teamBus)
	var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(busIdx, 0)
	var lowpass: AudioEffectLowPassFilter = AudioServer.get_bus_effect(busIdx, 1)
	var localKeepersInTeam: Array[Keeper] = Keepers.local.getAllFromTeam(updateForTeam)
	var inAnyLocalKeeperFromTeamInsideDome: bool = false
	for keeper: Keeper in localKeepersInTeam:
		inAnyLocalKeeperFromTeamInsideDome = inAnyLocalKeeperFromTeamInsideDome or keeper.getIsInsideDome()

	if inAnyLocalKeeperFromTeamInsideDome:
		runWorldAttenuation = false
		amplify.volume_db = 0
		AudioServer.set_bus_effect_enabled(busIdx, 1, false)
	else:
		runWorldAttenuation = true
		lowpass.cutoff_hz = 2000
		lowpass.resonance = 0.5
		AudioServer.set_bus_effect_enabled(busIdx, 1, true)

func _getWorldBusForTeam(team: String) -> String:
	return Audio.BUS_WORLD_TEAM2 if team == "team2" else Audio.BUS_WORLD

func _process(delta):
	if runWorldAttenuation:
		_updateWorldAttenuation()

func _updateWorldAttenuation() -> void :
	var localTeams: PackedStringArray = Keepers.local.getRelatedTeams()
	for team: String in localTeams:
		var keepersInTeam: Array[Keeper] = Keepers.local.getAllFromTeam(team)

		var minY: = 0.0
		for keeper in keepersInTeam:
			minY = max(minY, keeper.global_position.y)

		var bus: String = _getWorldBusForTeam(team)
		var attenuation = $MineAttenuation.attenuate(minY)
		var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(AudioServer.get_bus_index(bus), 0)
		var lowpass: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index(bus), 1)
		amplify.volume_db = attenuation * minimumWorldVolume
		lowpass.cutoff_hz = 4000 - 3800 * attenuation
