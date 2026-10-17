extends Node2D
class_name DomeStation

signal weaponsChanged
signal keeperExitForced

var teamId: String

var keeperInStation: Keeper
var keeperId: String

var controlledWeapons: Array

var remoteStation

@export_group("Internals")
@export var synchronizer: StationSynchronizer
@export var weapon_synchronizer: WeaponSynchronizer

func _ready():
	pass

func init(teamId: String) -> void :
	self.teamId = teamId
	Data.listen(self, teamId + ".monsters.wavepresent")

func getKeeperInStation() -> Keeper:
	if is_instance_valid(keeperInStation):
		return keeperInStation
	if remoteStation:
		if is_instance_valid(remoteStation.keeperInStation):
			return remoteStation.keeperInStation
	return null

func propertyChanged(property: String, oldValue, newValue):
	if newValue and not keeperInStation:
		waveAlertOn()
	else:
		waveAlertOff()

func getControlledWeapons() -> Array:
	return controlledWeapons

func addControlledWeapon(weapon):
	controlledWeapons.append(weapon)
	weaponsChanged.emit()

func canFocusUse(keeper: Keeper) -> bool:
	return not keeperInStation and ( not remoteStation or not remoteStation.keeperInStation)

func dropTarget() -> Vector2:
	return global_position

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not canFocusUse(keeper):
		return false

	if multiplayer.is_server():
		synchronizer.requestStationAuthority(keeper.playerId)
	else:
		synchronizer.requestStationAuthority.rpc_id(1, keeper.playerId)

	return true

func setWeaponAuthority(peerId: int) -> void :
	weapon_synchronizer.set_multiplayer_authority(peerId)
	for weapon in controlledWeapons:
		weapon.set_multiplayer_authority(peerId)

func exitStation():
	keeperInStation = null
	keeperExitedStation()

	synchronizer.network_rpc(synchronizer.releaseStationAuthority)

	setWeaponAuthority(1)

func getKeeperPosition() -> Vector2:
	return $KeeperPosition.global_position

func keeperEnteredStation():
	pass

func keeperExitedStation():
	pass

func waveAlertOn():
	pass

func waveAlertOff():
	pass

func getIndex() -> int:
	var stations: Array[DomeStation] = Level.domesByTeamId[teamId].stations
	return stations.find(self)

func forceKeeperExit():
	keeperExitForced.emit()

func getVisualGlobalPosition() -> Vector2:
	return global_position
