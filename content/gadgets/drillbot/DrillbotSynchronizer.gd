class_name DrillbotSynchronizer
extends Synchronizer

var drillbots: = {}


func get_initial_data(_peer_id: int) -> PackedByteArray:
	var stream: = PackedByteStream.new()
	for drillbot in drillbots.values():
		stream.append_array(drillbot.get_drillbot_state())

	return stream.data

func set_initial_data(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	while stream.is_not_finished():
		var UID = stream.decode_u32()
		var drillbot: Drillbot = Level.drops.get_drop(UID) as Drillbot
		bind_drillbot(drillbot)
		drillbot.set_drillbot_state(stream)

func network_track_drillbot(drillbot: Drillbot) -> void :
	network_rpc(track_drillbot.bind(drillbot.UID), false)
	bind_drillbot(drillbot)

@rpc("reliable")
func track_drillbot(UID: int) -> void :
	var drillbot: Drillbot = Level.drops.get_drop(UID)
	bind_drillbot(drillbot)

func bind_drillbot(drillbot: Drillbot) -> void :
	drillbots[drillbot.UID] = drillbot
	drillbot.startedFalling.connect(network_drillbot_start_falling)
	drillbot.landed.connect(network_drillbot_land)
	drillbot.startedWalking.connect(network_drillbot_start_walking)
	drillbot.startedIdling.connect(network_drillbot_start_idling)
	drillbot.startedWorking.connect(network_drillbot_start_working)
	drillbot.wentToSleep.connect(network_drillbot_go_to_sleep)
	drillbot.directionWasSet.connect(network_drillbot_set_direction)
	drillbot.wokeUp.connect(network_drillbot_wake_up)
	drillbot.switchedDirection.connect(network_drillbot_switch_direction)
	drillbot.wasScared.connect(network_drillbot_set_scared)
	drillbot.stoppedBeingScared.connect(network_drillbot_stop_being_scared)
	drillbot.treatEaten.connect(network_drillbot_eat_treat)
	drillbot.startedDrilling.connect(network_drillbot_start_drilling)
	drillbot.usedHit.connect(network_drillbot_use_hit)


func network_drillbot_start_falling(UID: int) -> void :
	network_rpc(drillbot_start_falling.bind(UID), true)

@rpc("reliable")
func drillbot_start_falling(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].startFalling()

func network_drillbot_land(UID: int) -> void :
	network_rpc(drillbot_land.bind(UID), true)

@rpc("reliable")
func drillbot_land(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].land()

func network_drillbot_start_walking(UID: int) -> void :
	network_rpc(drillbot_start_walking.bind(UID), true)

@rpc("reliable")
func drillbot_start_walking(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].startWalking()

func network_drillbot_start_idling(UID: int) -> void :
	network_rpc(drillbot_start_idling.bind(UID), true)

@rpc("reliable")
func drillbot_start_idling(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].startIdling()

func network_drillbot_start_working(UID: int) -> void :
	network_rpc(drillbot_start_working.bind(UID), true)

@rpc("reliable")
func drillbot_start_working(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].startWorking()

func network_drillbot_go_to_sleep(UID: int) -> void :
	network_rpc(drillbot_go_to_sleep.bind(UID), true)

@rpc("reliable")
func drillbot_go_to_sleep(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].goToSleep()

func network_drillbot_set_direction(UID: int, dir: Vector2) -> void :
	network_rpc(drillbot_set_direction.bind(UID, dir), true)

@rpc("reliable")
func drillbot_set_direction(UID: int, dir: Vector2) -> void :
	if drillbots.has(UID):
		drillbots[UID].localSetDirection(dir)

func network_drillbot_use_hit(UID: int, playerId: String) -> void :
	rpc_server(drillbot_use_hit.bind(UID, playerId))

@rpc("reliable", "any_peer")
func drillbot_use_hit(UID: int, playerId: String) -> void :
	if drillbots.has(UID):
		drillbots[UID].registerHit(playerId)

func network_drillbot_wake_up(UID: int) -> void :
	network_rpc(drillbot_wake_up.bind(UID), true)

@rpc("reliable")
func drillbot_wake_up(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].wakeUp()

func network_drillbot_switch_direction(UID: int) -> void :
	network_rpc(drillbot_switch_direction.bind(UID), true)

@rpc("reliable")
func drillbot_switch_direction(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].switchDirection()

func network_drillbot_set_scared(UID: int) -> void :
	network_rpc(drillbot_set_scared.bind(UID), true)

@rpc("reliable")
func drillbot_set_scared(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].setScared()

func network_drillbot_stop_being_scared(UID: int) -> void :
	network_rpc(drillbot_stop_being_scared.bind(UID), true)

@rpc("reliable")
func drillbot_stop_being_scared(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].stopBeingScared()

func network_drillbot_eat_treat(UID: int) -> void :
	network_rpc(drillbot_eat_treat.bind(UID), true)

@rpc("reliable")
func drillbot_eat_treat(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].eatTreat()

func network_drillbot_start_drilling(UID: int) -> void :
	network_rpc(drillbot_start_drilling.bind(UID), false)

@rpc("reliable")
func drillbot_start_drilling(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].startDrilling()

func network_fade_in(UID: int) -> void :
	network_rpc(drillbot_fade_in.bind(UID), false)

@rpc("reliable")
func drillbot_fade_in(UID: int) -> void :
	if drillbots.has(UID):
		drillbots[UID].fadeIn()
