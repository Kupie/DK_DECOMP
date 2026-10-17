extends InputProcessor

var popup

var station
var keeper
var stopped: = false

func _ready():
	stopSuccessors = false

func handleStart():
	popup.moveIn()
	Audio.sound("enter_station_" + Level.domesByTeamId.get(keeper.teamId).techId)
	keeper.tree_exiting.connect(onKeeperTreeExiting)

func onKeeperTreeExiting() -> void :

	handleStop()
	desintegrate()

func handleStop():
	if stopped:
		return
	stopped = true
	popup.moveOut(true)
	Level.stage.unpause()
	Audio.sound("exit_station_" + Level.domesByTeamId.get(keeper.teamId).techId)

	keeper.exitStation()
	station.exitStation()

func becameLeaf():
	popup.moveIn(true)
	Level.stage.pause()
	if not Options.useGamepad(deviceId):
		InputSystem.changeCursor("default")

func notLeaf():
	popup.moveOut()

func buttonEvent(event) -> bool:
	if Level.stage.pauseMenuOpen:
		return false
	if justPressed(event, "dome_battle"):
		Audio.sound("gui_move")
		popup.moveOut()
		Level.stage.startBattleInput(keeper, station)
	elif justPressed(event, "dome_upgrades"):
		Audio.sound("gui_move")
		popup.moveOut()
		Level.stage.startUpgradesInput(keeper)
	elif justPressed(event, "ui_cancel"):
		Audio.sound("gui_cancel")
		desintegrate()
	elif justPressed(event, "escape"):
		return false
	elif justPressed(event, "cheats"):

		return false
	elif justPressed(event, "escape"):
		return false

	return true
