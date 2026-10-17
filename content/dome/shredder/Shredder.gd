class_name Shredder extends Area2D

var teamId: String

var coolDown: = 0.0

var dropsArrived: = []
var dropsInRange: = []
var powerlevel: int = 0

func getDeliverableDrop(type: String):
	var p = get_parent()
	if not p.absorbed and p.type == type:
		return p
	else:
		return null

func _process(delta):
	if not multiplayer.is_server():
		return
	if StageManager.isSwitchingStage():
		return

	if coolDown > 0.0:
		coolDown -= delta

	if coolDown > 0.0:
		return

	if dropsArrived.size() == 0:
		if powerlevel != 0:
			update_power_level(0)
			Network.rpc_if_state(update_power_level.bind(0), Network.local_connection_state)
		return

	var closestDistance: float = 9999
	var closestDrop
	for drop in dropsArrived:
		if not drop.isCarried() and not drop.absorbed:


			var l = getDistance(drop)
			if l < closestDistance:
				closestDistance = l
				closestDrop = drop
	if closestDrop:
		var level: int = 1
		if dropsInRange.size() > 20:
			level = 3
		elif dropsInRange.size() > 6:
			level = 2
		else:
			level = 1


		level = maxi(level, powerlevel)

		update_power_level(level)
		Network.rpc_if_state(update_power_level.bind(level), Network.local_connection_state)
		coolDown = 1.0 / float(level)
		shredDrop(closestDrop, level)

@rpc("reliable")
func update_power_level(newlevel: int):
	if powerlevel == newlevel:
		return

	match powerlevel:
		2:
			$LoopOverdrive.stop()
		3:
			$LoopUberdrive.stop()

	match newlevel:
		0:
			$ShredStop.startSound()
		2:
			$LoopOverdrive.startSound()
			if powerlevel < newlevel:
				$transitionOverdrive.startSound()
		3:
			$LoopUberdrive.startSound()
			if powerlevel < newlevel:
				$transitionUberdrive.startSound()

	powerlevel = newlevel


func getDistance(drop) -> float:
	return (drop.global_position - $ShredPoint.global_position).length()

func shredDrop(drop, powerlevel: int):
	processDrop(drop)
	Level.drops.network_shred(drop, teamId)
	dropsArrived.erase(drop)
	dropsInRange.erase(drop)
	playShredVisuals()
	Network.rpc_if_state(playShredVisuals, Network.local_connection_state)

	if Data.ofOr(teamId + ".harmfuldrops." + drop.type, 0) != 0:
		playHarmfulShredAudio()
		Network.rpc_if_state(playHarmfulShredAudio, Network.local_connection_state)

@rpc("reliable")
func playShredVisuals() -> void :
	$Sprite2D.frame = 0
	$Sprite2D.play("running")
	$Sprite2D.speed_scale = powerlevel

	var copy = $ShredPoint / ShredSound.duplicate()

	copy.removeAfterPlaying = true
	add_child(copy)
	copy.startSound()

@rpc("reliable")
func playHarmfulShredAudio() -> void :
	var copy = $ShredPoint / HarmfulShredSound.duplicate()
	copy.removeAfterPlaying = true
	add_child(copy)
	copy.startSound()


func processDrop(drop):
	pass

func _on_Shredder_area_entered(area):
	for r in ["iron", "water", "sand", "pack"]:
		var drop = area.getDeliverableDrop(r)
		if drop:
			drop.floatToDropTarget(self)
			if not dropsInRange.has(drop):
				dropsInRange.append(drop)
			return

func dropTarget() -> Vector2:
	return $ShredPoint.global_position

func arrived(drop):
	if not dropsArrived.has(drop):
		dropsArrived.append(drop)
